package com.picochat.app.ui.screens.intro

import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.CloudDownload
import androidx.compose.material.icons.filled.Forum
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.picochat.app.data.model.recommendedModels
import com.picochat.app.data.store.Prefs
import com.picochat.app.domain.ModelManager
import com.picochat.app.l10n.tr
import com.picochat.app.ui.components.PicoButton
import com.picochat.app.ui.theme.PicoMotion
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

private const val PAGES = 4

/** First launch: four pages (welcome, privacy, first model, name). */
@Composable
fun IntroScreen(onDone: () -> Unit) {
    val pager = rememberPagerState(pageCount = { PAGES })
    val scope = rememberCoroutineScope()
    val last = pager.currentPage == PAGES - 1

    Column(Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 12.dp), horizontalArrangement = Arrangement.End) {
            if (!last) TextButton(onClick = onDone) { Text(tr("intro_skip")) }
        }
        HorizontalPager(pager, Modifier.weight(1f)) { page ->
            when (page) {
                0 -> Page(Icons.Default.Forum, tr("intro1_t"), tr("intro1_s"))
                1 -> Page(Icons.Default.Lock, tr("intro2_t"), tr("intro2_s"))
                2 -> ModelPage()
                else -> NamePage()
            }
        }
        Row(Modifier.fillMaxWidth().padding(24.dp), verticalAlignment = Alignment.CenterVertically) {
            TextButton(onClick = { scope.launch { pager.animateScrollToPage(pager.currentPage - 1) } }, enabled = pager.currentPage > 0) {
                Text(tr("intro_back"))
            }
            Row(Modifier.weight(1f), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) {
                repeat(PAGES) { i ->
                    val width by animateDpAsState(if (i == pager.currentPage) 28.dp else 8.dp, PicoMotion.spatial(), label = "dot")
                    Box(
                        Modifier.padding(3.dp).height(8.dp).width(width).clip(CircleShape).background(
                            if (i == pager.currentPage) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant,
                        ),
                    )
                }
            }
            PicoButton(onClick = {
                if (last) onDone() else scope.launch { pager.animateScrollToPage(pager.currentPage + 1) }
            }) { Text(if (last) tr("intro_start") else tr("intro_next")) }
        }
    }
}

@Composable
private fun Page(icon: ImageVector, title: String, subtitle: String, extra: @Composable () -> Unit = {}) {
    Column(
        Modifier.fillMaxSize().padding(32.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            Modifier.size(120.dp).clip(MaterialTheme.shapes.extraLarge).background(MaterialTheme.colorScheme.primaryContainer),
            contentAlignment = Alignment.Center,
        ) { Icon(icon, contentDescription = null, Modifier.size(56.dp), tint = MaterialTheme.colorScheme.onPrimaryContainer) }
        Text(title, style = MaterialTheme.typography.headlineMedium, textAlign = TextAlign.Center, modifier = Modifier.padding(top = 28.dp))
        Text(
            subtitle,
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 12.dp),
        )
        extra()
    }
}

/** Offers the smallest recommended model so a first chat works right away. */
@Composable
private fun ModelPage() {
    val installed by ModelManager.installed.collectAsState()
    val tasks by ModelManager.tasks.collectAsState()
    val scope = rememberCoroutineScope()
    val model = recommendedModels.minByOrNull { it.approxMb } ?: return
    val task = tasks.values.firstOrNull { it.repo == model.repo }
    val done = installed.any { it.repo == model.repo }
    Page(if (done) Icons.Default.CheckCircle else Icons.Default.CloudDownload, tr("intro3_t"), tr("intro3_s")) {
        Column(Modifier.padding(top = 24.dp), horizontalAlignment = Alignment.CenterHorizontally) {
            when {
                done -> Text(tr("intro3_done"), color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.titleMedium)
                task != null -> LinearProgressIndicator(progress = { task.progress }, modifier = Modifier.fillMaxWidth())
                else -> PicoButton(onClick = {
                    scope.launch {
                        try {
                            ModelManager.downloadDefault(model.repo)
                        } catch (e: CancellationException) {
                            throw e
                        } catch (_: Exception) {
                            // shown in the Downloads tab later; the intro stays calm
                        }
                    }
                }, tonal = true) { Text(tr("intro3_download")) }
            }
            Text(
                tr("intro3_later"),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 16.dp),
            )
        }
    }
}

@Composable
private fun NamePage() {
    Page(Icons.Default.CheckCircle, tr("intro4_t"), tr("intro4_s")) {
        OutlinedTextField(
            value = Prefs.userName.value,
            onValueChange = { Prefs.userName.set(it) },
            label = { Text(tr("onb_q_name")) },
            singleLine = true,
            shape = MaterialTheme.shapes.large,
            modifier = Modifier.fillMaxWidth().padding(top = 24.dp),
        )
        Text(
            tr("intro4_b_s"),
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 12.dp),
        )
    }
}
