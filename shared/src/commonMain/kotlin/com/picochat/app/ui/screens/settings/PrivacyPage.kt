package com.picochat.app.ui.screens.settings

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import com.picochat.app.l10n.tr
import com.picochat.app.ui.components.SectionCard
import com.picochat.app.util.appDataDir

@Composable
fun PrivacyPage() {
    SectionCard(tr("set_privacy")) {
        Text(tr("home_hint_local"), style = MaterialTheme.typography.titleMedium)
        Text(tr("priv_local"), style = MaterialTheme.typography.bodyMedium)
        Text(appDataDir(), style = MaterialTheme.typography.bodySmall, color = MaterialTheme.colorScheme.primary)
    }
    SectionCard {
        Text(tr("priv_net"), style = MaterialTheme.typography.bodyMedium)
        Text(tr("priv_token"), style = MaterialTheme.typography.bodyMedium)
    }
}
