package com.picochat.app.ui.screens.models

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Download
import androidx.compose.material.icons.filled.Menu
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Tab
import androidx.compose.material3.TabRow
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.picochat.app.data.hf.HfException
import com.picochat.app.data.hf.HfService
import com.picochat.app.data.model.HfFileInfo
import com.picochat.app.data.model.HfModelSummary
import com.picochat.app.data.model.InstalledModel
import com.picochat.app.data.model.RecommendedModel
import com.picochat.app.data.model.formatBytes
import com.picochat.app.data.model.recommendedModels
import com.picochat.app.data.store.Prefs
import com.picochat.app.domain.DownloadState
import com.picochat.app.domain.DownloadTask
import com.picochat.app.domain.ModelManager
import com.picochat.app.l10n.Strings
import com.picochat.app.l10n.tr
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ModelsScreen(showMenu: Boolean, onMenu: () -> Unit) {
    var tab by remember { mutableStateOf(0) }
    val tasks by ModelManager.tasks.collectAsState()
    Scaffold(topBar = {
        TopAppBar(
            title = { Text(tr("nav_models")) },
            navigationIcon = { if (showMenu) IconButton(onClick = onMenu) { Icon(Icons.Default.Menu, contentDescription = null) } },
        )
    }) { padding ->
        Column(Modifier.fillMaxSize().padding(padding)) {
            TabRow(selectedTabIndex = tab) {
                listOf(tr("tab_discover"), tr("tab_installed"), tr("tab_downloads")).forEachIndexed { i, label ->
                    Tab(selected = tab == i, onClick = { tab = i }, text = { Text(if (i == 2 && tasks.isNotEmpty()) "$label (${tasks.size})" else label) })
                }
            }
            when (tab) {
                0 -> DiscoverTab()
                1 -> InstalledTab()
                else -> DownloadsTab()
            }
        }
    }
}

private fun errorText(e: Exception): String = if (e is HfException) tr("err_${e.kind}") else (e.message ?: tr("err_t_other"))

@Composable
private fun DiscoverTab() {
    val scope = rememberCoroutineScope()
    val installed by ModelManager.installed.collectAsState()
    val tasks by ModelManager.tasks.collectAsState()
    var query by remember { mutableStateOf("") }
    var results by remember { mutableStateOf<List<HfModelSummary>>(emptyList()) }
    var loading by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf("") }
    var files by remember { mutableStateOf<Map<String, List<HfFileInfo>>>(emptyMap()) }

    fun search() = scope.launch {
        loading = true
        error = ""
        try {
            results = HfService.search(query)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            error = errorText(e)
        }
        loading = false
    }

    LazyColumn(Modifier.fillMaxSize(), contentPadding = androidx.compose.foundation.layout.PaddingValues(12.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        item { Text(tr("rec_title"), style = MaterialTheme.typography.titleLarge) }
        items(recommendedModels, key = { it.repo }) { rec ->
            RecommendedCard(
                rec,
                installed = installed.any { it.repo == rec.repo },
                task = tasks.values.firstOrNull { it.repo == rec.repo },
                onDownload = {
                    scope.launch {
                        try {
                            ModelManager.downloadDefault(rec.repo)
                        } catch (e: CancellationException) {
                            throw e
                        } catch (e: Exception) {
                            error = errorText(e)
                        }
                    }
                },
            )
        }
        item {
            Text(tr("hf_popular"), style = MaterialTheme.typography.titleLarge, modifier = Modifier.padding(top = 8.dp))
            Row(Modifier.fillMaxWidth().padding(top = 8.dp), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                OutlinedTextField(
                    value = query,
                    onValueChange = { query = it },
                    placeholder = { Text(tr("hf_search_hint")) },
                    singleLine = true,
                    shape = RoundedCornerShape(20.dp),
                    modifier = Modifier.weight(1f),
                )
                OutlinedButton(onClick = { search() }, enabled = !loading) { Text(tr("search")) }
            }
            if (error.isNotEmpty()) Text(error, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(top = 8.dp))
        }
        items(results, key = { it.id }) { r ->
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(12.dp)) {
                    Text(r.name, style = MaterialTheme.typography.titleMedium)
                    Text("${r.author} · ↓ ${r.downloads}", style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    val list = files[r.id]
                    if (list == null) {
                        TextButton(onClick = {
                            scope.launch {
                                try {
                                    files = files + (r.id to HfService.listFiles(r.id))
                                } catch (e: CancellationException) {
                                    throw e
                                } catch (e: Exception) {
                                    error = errorText(e)
                                }
                            }
                        }) { Text(tr("files_hint")) }
                    } else {
                        list.forEach { f ->
                            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                                Column(Modifier.weight(1f)) {
                                    Text(f.name, style = MaterialTheme.typography.bodyMedium, maxLines = 1)
                                    Text(formatBytes(f.sizeBytes), style = MaterialTheme.typography.bodySmall)
                                }
                                if (!f.isProjector && !ModelManager.isInstalled(r.id, f.name)) {
                                    IconButton(onClick = { ModelManager.download(r.id, f) }) { Icon(Icons.Default.Download, contentDescription = tr("download")) }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun RecommendedCard(rec: RecommendedModel, installed: Boolean, task: DownloadTask?, onDownload: () -> Unit) {
    val about = rec.about[Strings.lang] ?: rec.about["en"] ?: ""
    Card(Modifier.fillMaxWidth(), colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainer)) {
        Column(Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(rec.title, style = MaterialTheme.typography.titleMedium)
                    Text("${rec.maker} · ${rec.params} · ~${formatBytes(rec.approxMb * 1024L * 1024L)} · ${rec.minRamGb} GB RAM",
                        style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
            }
            Text(tr(rec.blurbKey), style = MaterialTheme.typography.bodyMedium)
            if (about.isNotEmpty()) Text(about, style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                rec.tags.forEach { AssistChip(onClick = {}, label = { Text(tr(it)) }) }
            }
            when {
                installed -> Text(tr("tab_installed"), color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.labelLarge)
                task != null -> {
                    LinearProgressIndicator(progress = { task.progress }, modifier = Modifier.fillMaxWidth())
                    Text("${formatBytes(task.doneBytes)} / ${formatBytes(task.totalBytes)}", style = MaterialTheme.typography.bodySmall)
                }
                else -> OutlinedButton(onClick = onDownload) {
                    Icon(Icons.Default.Download, contentDescription = null)
                    Text(tr("download"), Modifier.padding(start = 8.dp))
                }
            }
        }
    }
}

@Composable
private fun InstalledTab() {
    val installed by ModelManager.installed.collectAsState()
    var toDelete by remember { mutableStateOf<InstalledModel?>(null) }
    if (installed.isEmpty()) {
        Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
            Text(tr("no_installed"), style = MaterialTheme.typography.bodyLarge)
        }
        return
    }
    LazyColumn(Modifier.fillMaxSize(), contentPadding = androidx.compose.foundation.layout.PaddingValues(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        items(installed, key = { it.id }) { m ->
            Card(Modifier.fillMaxWidth()) {
                Row(Modifier.padding(8.dp), verticalAlignment = Alignment.CenterVertically) {
                    RadioButton(selected = Prefs.activeModelId.value == m.id, onClick = { ModelManager.setActive(m.id) })
                    Column(Modifier.weight(1f)) {
                        Text(m.displayName, style = MaterialTheme.typography.titleSmall, maxLines = 2)
                        Text("${m.quant} · ${formatBytes(m.sizeBytes)}", style = MaterialTheme.typography.bodySmall)
                    }
                    IconButton(onClick = { toDelete = m }) { Icon(Icons.Default.Delete, contentDescription = tr("delete")) }
                }
            }
        }
    }
    toDelete?.let { m ->
        AlertDialog(
            onDismissRequest = { toDelete = null },
            title = { Text(tr("delete_model_q")) },
            text = { Text(tr("delete_model_body")) },
            confirmButton = { TextButton(onClick = { ModelManager.delete(m); toDelete = null }) { Text(tr("delete")) } },
            dismissButton = { TextButton(onClick = { toDelete = null }) { Text(tr("cancel")) } },
        )
    }
}

@Composable
private fun DownloadsTab() {
    val tasks by ModelManager.tasks.collectAsState()
    if (tasks.isEmpty()) {
        Column(Modifier.fillMaxSize().padding(24.dp), verticalArrangement = Arrangement.Center, horizontalAlignment = Alignment.CenterHorizontally) {
            Text(tr("no_downloads"), style = MaterialTheme.typography.bodyLarge)
        }
        return
    }
    LazyColumn(Modifier.fillMaxSize(), contentPadding = androidx.compose.foundation.layout.PaddingValues(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        items(tasks.values.toList(), key = { it.key }) { t ->
            Card(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(t.fileName, style = MaterialTheme.typography.titleSmall, maxLines = 2)
                    LinearProgressIndicator(progress = { t.progress }, modifier = Modifier.fillMaxWidth())
                    val status = when (t.state) {
                        DownloadState.RUNNING -> "${formatBytes(t.doneBytes)} / ${formatBytes(t.totalBytes)} · ${formatBytes(t.bytesPerSec)}/s"
                        DownloadState.PAUSED -> tr("paused")
                        DownloadState.FAILED -> tr("err_${t.error}").let { if (it == "err_${t.error}") t.error else it }
                    }
                    Text(status, style = MaterialTheme.typography.bodySmall)
                    Row {
                        if (t.state == DownloadState.RUNNING) {
                            IconButton(onClick = { ModelManager.pause(t.key) }) { Icon(Icons.Default.Pause, contentDescription = tr("pause")) }
                        } else {
                            IconButton(onClick = { ModelManager.resume(t.key) }) { Icon(Icons.Default.PlayArrow, contentDescription = tr("resume")) }
                        }
                        IconButton(onClick = { ModelManager.cancel(t.key) }) { Icon(Icons.Default.Close, contentDescription = tr("cancel")) }
                    }
                }
            }
        }
    }
}
