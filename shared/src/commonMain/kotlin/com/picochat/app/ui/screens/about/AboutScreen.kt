package com.picochat.app.ui.screens.about

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.style.TextAlign
import com.picochat.app.domain.ChatService
import com.picochat.app.l10n.tr
import com.picochat.app.ui.components.PicoButton
import com.picochat.app.ui.components.SectionCard
import com.picochat.app.util.AppInfo
import com.picochat.app.util.Disk
import com.picochat.app.util.nativeInfo

@Composable
fun AboutPage() {
    val uri = LocalUriHandler.current
    SectionCard {
        Column(Modifier.fillMaxWidth()) {
            Text("PicoChat", style = MaterialTheme.typography.headlineMedium)
            Text(tr("app_tagline"), style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
    }
    SectionCard(tr("about_info")) {
        Text("v${AppInfo.VERSION}", style = MaterialTheme.typography.titleMedium)
        Text(tr("about_engine"), style = MaterialTheme.typography.labelLarge)
        Text(
            if (ChatService.isDemo()) tr("about_engine_demo") else ChatService.engineName(),
            style = MaterialTheme.typography.bodyMedium,
        )
        Text(nativeInfo().take(140), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Text(tr("about_models_dir"), style = MaterialTheme.typography.labelLarge)
        Text(Disk.dir("models"), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.primary)
    }
    SectionCard(tr("about_links")) {
        PicoButton(onClick = { uri.openUri(AppInfo.REPO_URL) }, tonal = true) { Text("GitHub") }
        PicoButton(onClick = { uri.openUri(AppInfo.HF_URL) }, tonal = true) { Text("Hugging Face") }
        PicoButton(onClick = { uri.openUri(AppInfo.LLAMA_URL) }, tonal = true) { Text("llama.cpp") }
    }
    SectionCard(tr("about_licenses")) {
        Text(
            "llama.cpp (MIT) · Kotlin, Compose Multiplatform, kotlinx.serialization, kotlinx.coroutines, Ktor, okio (Apache-2.0) · " +
                "Google Sans Flex (OFL)",
            style = MaterialTheme.typography.bodySmall,
            textAlign = TextAlign.Start,
        )
    }
}
