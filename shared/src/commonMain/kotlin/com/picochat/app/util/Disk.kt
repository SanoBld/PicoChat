package com.picochat.app.util

import okio.FileSystem
import okio.Path.Companion.toPath

/** Small file helpers on top of okio (works on Android, desktop and iOS). */
object Disk {
    val fs: FileSystem = FileSystem.SYSTEM

    /** Absolute path of a sub folder of the app data dir (created if missing). */
    fun dir(sub: String): String {
        val p = "${appDataDir()}/$sub".toPath()
        fs.createDirectories(p)
        return p.toString()
    }

    fun exists(path: String): Boolean = fs.exists(path.toPath())

    fun size(path: String): Long = fs.metadataOrNull(path.toPath())?.size ?: 0L

    fun readText(path: String): String? {
        val p = path.toPath()
        return if (fs.exists(p)) fs.read(p) { readUtf8() } else null
    }

    /** Writes through a temp file so a crash never leaves a half-written file. */
    fun writeAtomic(path: String, text: String) {
        val p = path.toPath()
        p.parent?.let { fs.createDirectories(it) }
        val tmp = "$path.tmp".toPath()
        fs.write(tmp) { writeUtf8(text) }
        fs.atomicMove(tmp, p)
    }

    fun delete(path: String) = fs.delete(path.toPath(), mustExist = false)

    fun listNames(dirPath: String): List<String> =
        if (fs.exists(dirPath.toPath())) fs.list(dirPath.toPath()).map { it.name } else emptyList()
}
