package com.picochat.app.ui.screens.settings

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalUriHandler
import com.picochat.app.data.store.DEFAULT_HF_ENDPOINT
import com.picochat.app.data.store.Prefs
import com.picochat.app.l10n.tr
import com.picochat.app.ui.components.PicoButton
import com.picochat.app.ui.components.SectionCard

@Composable
fun HfPage() {
    val uri = LocalUriHandler.current
    SectionCard(tr("hf_token")) {
        OutlinedTextField(
            value = Prefs.hfToken.value,
            onValueChange = { Prefs.hfToken.set(it.trim()) },
            singleLine = true,
            shape = MaterialTheme.shapes.large,
            modifier = Modifier.fillMaxWidth(),
        )
        PicoButton(onClick = { uri.openUri("https://huggingface.co/settings/tokens") }, tonal = true) { Text(tr("hf_get_token")) }
        if (Prefs.hfToken.value.isNotEmpty()) PicoButton(onClick = { Prefs.hfToken.set("") }, tonal = true) { Text(tr("hf_remove_token")) }
    }
    SectionCard(tr("hf_endpoint")) {
        OutlinedTextField(
            value = Prefs.hfEndpoint.value,
            onValueChange = { Prefs.hfEndpoint.set(it.trim()) },
            singleLine = true,
            shape = MaterialTheme.shapes.large,
            modifier = Modifier.fillMaxWidth(),
        )
        PicoButton(onClick = { Prefs.hfEndpoint.set(DEFAULT_HF_ENDPOINT) }, tonal = true) { Text(tr("inst_reset")) }
    }
}
