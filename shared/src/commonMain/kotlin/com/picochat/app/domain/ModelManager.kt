package com.picochat.app.domain

import com.picochat.app.data.hf.HfException
import com.picochat.app.data.hf.HfService
import com.picochat.app.data.model.AppJson
import com.picochat.app.data.model.HfFileInfo
import com.picochat.app.data.model.InstalledModel
import com.picochat.app.data.store.Prefs
import com.picochat.app.util.Disk
import com.picochat.app.util.Http
import com.picochat.app.util.nowIso
import com.picochat.app.util.nowMillis
import io.ktor.client.request.header
import io.ktor.client.request.prepareGet
import io.ktor.client.statement.bodyAsChannel
import io.ktor.http.HttpHeaders
import io.ktor.http.Url
import io.ktor.utils.io.readAvailable
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.serialization.builtins.ListSerializer
import okio.Path.Companion.toPath
import okio.buffer

enum class DownloadState { RUNNING, PAUSED, FAILED }

/** A download in progress (finished downloads move to the installed list). */
data class DownloadTask(
    val key: String,
    val repo: String,
    val fileName: String,
    val totalBytes: Long,
    val doneBytes: Long = 0,
    val state: DownloadState = DownloadState.RUNNING,
    val bytesPerSec: Long = 0,
    val error: String = "",
) {
    val progress: Float get() = if (totalBytes > 0) (doneBytes.toFloat() / totalBytes).coerceIn(0f, 1f) else 0f
}

/** Installed models and resumable downloads from Hugging Face. */
object ModelManager {
    private val _installed = MutableStateFlow<List<InstalledModel>>(emptyList())
    val installed: StateFlow<List<InstalledModel>> = _installed

    private val _tasks = MutableStateFlow<Map<String, DownloadTask>>(emptyMap())
    val tasks: StateFlow<Map<String, DownloadTask>> = _tasks

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val jobs = mutableMapOf<String, Job>()
    private val serializer = ListSerializer(InstalledModel.serializer())

    private fun modelsDir() = Disk.dir("models")
    private fun registry() = Disk.dir("data") + "/models.json"

    fun key(repo: String, file: String) = "$repo/$file"
    private fun localName(repo: String, file: String) = repo.replace('/', '_') + "__" + file.substringAfterLast('/')

    fun init() {
        val txt = Disk.readText(registry())
        val list = txt?.let { runCatching { AppJson.decodeFromString(serializer, it) }.getOrNull() } ?: emptyList()
        _installed.value = list.filter { Disk.exists(it.path) }
    }

    private fun saveRegistry() {
        runCatching { Disk.writeAtomic(registry(), AppJson.encodeToString(serializer, _installed.value)) }
    }

    fun activeModel(): InstalledModel? = _installed.value.firstOrNull { it.id == Prefs.activeModelId.value }

    fun setActive(id: String) = Prefs.activeModelId.set(id)

    fun delete(model: InstalledModel) {
        Disk.delete(model.path)
        _installed.value = _installed.value.filterNot { it.id == model.id }
        if (Prefs.activeModelId.value == model.id) Prefs.activeModelId.set(_installed.value.firstOrNull()?.id ?: "")
        saveRegistry()
    }

    fun isInstalled(repo: String, file: String): Boolean = _installed.value.any { it.id == key(repo, file) }

    /** Downloads the default file of a repo (used by the recommended list). */
    suspend fun downloadDefault(repo: String): HfFileInfo? {
        val file = HfService.pickDefault(HfService.listFiles(repo)) ?: return null
        download(repo, file)
        return file
    }

    fun download(repo: String, file: HfFileInfo) {
        val k = key(repo, file.name)
        if (jobs[k]?.isActive == true || isInstalled(repo, file.name)) return
        setTask(DownloadTask(k, repo, file.name, file.sizeBytes, Disk.size(partPath(repo, file.name))))
        jobs[k] = scope.launch { runDownload(k, repo, file) }
    }

    fun pause(k: String) {
        jobs[k]?.cancel()
        _tasks.value[k]?.let { setTask(it.copy(state = DownloadState.PAUSED, bytesPerSec = 0)) }
    }

    fun resume(k: String) {
        val t = _tasks.value[k] ?: return
        if (jobs[k]?.isActive == true) return
        setTask(t.copy(state = DownloadState.RUNNING, error = ""))
        jobs[k] = scope.launch { runDownload(k, t.repo, HfFileInfo(t.fileName, t.totalBytes)) }
    }

    fun cancel(k: String) {
        jobs[k]?.cancel()
        _tasks.value[k]?.let { Disk.delete(partPath(it.repo, it.fileName)) }
        _tasks.value = _tasks.value - k
    }

    private fun partPath(repo: String, file: String) = modelsDir() + "/" + localName(repo, file) + ".part"

    private fun setTask(t: DownloadTask) {
        _tasks.value = _tasks.value + (t.key to t)
    }

    private suspend fun runDownload(k: String, repo: String, file: HfFileInfo) {
        val part = partPath(repo, file.name)
        try {
            val total = fetchToPart(k, repo, file, part)
            finish(k, repo, file, part, total)
        } catch (e: CancellationException) {
            throw e
        } catch (e: HfException) {
            fail(k, e.kind)
        } catch (e: Exception) {
            fail(k, e.message ?: "other")
        }
    }

    private fun fail(k: String, message: String) {
        _tasks.value[k]?.let { setTask(it.copy(state = DownloadState.FAILED, error = message, bytesPerSec = 0)) }
    }

    /** Streams the file into [part] (resuming when it already exists). Returns the total size. */
    private suspend fun fetchToPart(k: String, repo: String, file: HfFileInfo, part: String): Long {
        var url = HfService.resolveUrl(repo, file.name)
        val hfHost = Url(HfService.endpoint()).host
        var redirects = 0
        while (true) {
            var start = Disk.size(part)
            var next: String? = null
            var total = file.sizeBytes
            Http.download.prepareGet(url) {
                // the token goes to Hugging Face only, never to the CDN it redirects to
                if (Url(url).host == hfHost) HfService.authHeader()?.let { header(HttpHeaders.Authorization, it) }
                if (start > 0) header(HttpHeaders.Range, "bytes=$start-")
            }.execute { resp ->
                val code = resp.status.value
                when {
                    code in listOf(301, 302, 303, 307, 308) -> {
                        val loc = resp.headers[HttpHeaders.Location] ?: throw HfException("other", code)
                        next = if (loc.startsWith("http")) loc else originOf(url) + loc
                    }
                    code == 416 -> total = start // already complete
                    code == 200 || code == 206 -> {
                        if (code == 200 && start > 0) {
                            Disk.delete(part)
                            start = 0
                        }
                        val len = resp.headers[HttpHeaders.ContentLength]?.toLongOrNull() ?: 0L
                        if (len > 0) total = start + len
                        writeBody(k, resp.bodyAsChannel(), part, start, total)
                    }
                    code == 401 || code == 403 -> throw HfException("auth", code)
                    code == 404 -> throw HfException("notFound", code)
                    code == 429 -> throw HfException("rateLimit", code)
                    code in 500..599 -> throw HfException("server", code)
                    else -> throw HfException("other", code)
                }
                Unit
            }
            val n = next
            if (n == null) return total
            if (++redirects > 8) throw HfException("other", 310)
            url = n
        }
    }

    /** "https://host[:port]" of a URL, used to resolve relative redirects. */
    private fun originOf(url: String): String {
        val u = Url(url)
        val port = if (u.port == u.protocol.defaultPort) "" else ":${u.port}"
        return "${u.protocol.name}://${u.host}$port"
    }

    private suspend fun writeBody(k: String, ch: io.ktor.utils.io.ByteReadChannel, part: String, start: Long, total: Long) {
        val path = part.toPath()
        val sink = (if (start > 0) Disk.fs.appendingSink(path) else Disk.fs.sink(path)).buffer()
        var done = start
        var lastTick = nowMillis()
        var lastDone = done
        val buf = ByteArray(64 * 1024)
        try {
            while (true) {
                currentCoroutineContext().ensureActive()
                val n = ch.readAvailable(buf, 0, buf.size)
                if (n < 0) break
                sink.write(buf, 0, n)
                done += n
                val now = nowMillis()
                if (now - lastTick >= 300) {
                    val speed = (done - lastDone) * 1000 / (now - lastTick)
                    _tasks.value[k]?.let { setTask(it.copy(doneBytes = done, totalBytes = if (total > 0) total else it.totalBytes, bytesPerSec = speed)) }
                    lastTick = now
                    lastDone = done
                }
            }
        } finally {
            sink.close()
        }
    }

    private fun finish(k: String, repo: String, file: HfFileInfo, part: String, total: Long) {
        val size = Disk.size(part)
        if (total > 0 && size != total) throw HfException("incomplete")
        val magic = Disk.fs.read(part.toPath()) { readUtf8(4) }
        if (magic != "GGUF") {
            Disk.delete(part)
            throw HfException("invalid")
        }
        val final = modelsDir() + "/" + localName(repo, file.name)
        Disk.fs.atomicMove(part.toPath(), final.toPath())
        val model = InstalledModel(
            id = key(repo, file.name),
            repo = repo,
            fileName = file.name.substringAfterLast('/'),
            path = final,
            sizeBytes = size,
            addedAt = nowIso(),
        )
        _installed.value = _installed.value.filterNot { it.id == model.id } + model
        _tasks.value = _tasks.value - k
        if (Prefs.activeModelId.value.isEmpty()) Prefs.activeModelId.set(model.id)
        saveRegistry()
    }
}
