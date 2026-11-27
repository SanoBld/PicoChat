package com.picochat.app.ui.screens.settings

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.picochat.app.data.store.Prefs
import com.picochat.app.l10n.Strings
import com.picochat.app.l10n.supportedLocales
import com.picochat.app.l10n.tr
import com.picochat.app.ui.components.PicoButton
import com.picochat.app.ui.components.SectionCard
import com.picochat.app.util.systemLanguage

@Composable
fun LanguagePage() {
    SectionCard(tr("set_language")) {
        supportedLocales.forEach { (code, name) ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(
                    selected = Prefs.locale.value == code,
                    onClick = {
                        Prefs.locale.set(code)
                        Strings.setLanguage(code)
                    },
                    label = { Text(name) },
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
        PicoButton(onClick = {
            Prefs.locale.set("")
            Strings.setLanguage(systemLanguage())
        }, tonal = true) { Text(tr("lang_follow_system")) }
    }
}
