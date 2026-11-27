package com.picochat.app.ui.screens.settings

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChatBubble
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Psychology
import androidx.compose.material.icons.filled.Storage
import androidx.compose.material.icons.filled.Cloud
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import com.picochat.app.l10n.tr
import com.picochat.app.ui.components.PicoPage
import com.picochat.app.ui.components.PlatformBackHandler
import com.picochat.app.ui.components.SettingsNavRow
import com.picochat.app.ui.screens.about.AboutPage
import com.picochat.app.ui.theme.PicoMotion

private enum class SettingsPage(val titleKey: String, val subKey: String, val icon: ImageVector) {
    APPEARANCE("set_appearance", "set_appearance_sub", Icons.Default.Palette),
    LANGUAGE("set_language", "set_language_sub", Icons.Default.Language),
    CHAT("set_chat", "set_chat_sub", Icons.Default.ChatBubble),
    MEMORY("memory_title", "memory_sub", Icons.Default.Psychology),
    HF("set_hf", "set_hf_sub", Icons.Default.Cloud),
    STORAGE("set_storage", "set_storage_sub", Icons.Default.Storage),
    PRIVACY("set_privacy", "set_privacy_sub", Icons.Default.Lock),
    ABOUT("set_about", "set_about_sub", Icons.Default.Info),
}

/** Settings list; each entry opens a sub page with a slide transition. */
@Composable
fun SettingsScreen(showMenu: Boolean, onMenu: () -> Unit) {
    var page by remember { mutableStateOf<SettingsPage?>(null) }
    PlatformBackHandler(enabled = page != null) { page = null }

    AnimatedContent(
        targetState = page,
        transitionSpec = {
            val forward = targetState != null
            (fadeIn(PicoMotion.effects()) + slideInHorizontally(animationSpec = PicoMotion.spatial()) { if (forward) it / 8 else -it / 8 }) togetherWith
                (fadeOut(PicoMotion.effects()) + slideOutHorizontally(animationSpec = PicoMotion.spatial()) { if (forward) -it / 8 else it / 8 })
        },
        label = "settings",
    ) { current ->
        PicoPage(
            title = tr(current?.titleKey ?: "nav_settings"),
            onBack = if (current != null) ({ page = null }) else null,
            showMenu = showMenu && current == null,
            onMenu = onMenu,
        ) { padding ->
            Column(
                Modifier.padding(padding).verticalScroll(rememberScrollState()).padding(horizontal = 16.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                when (current) {
                    null -> SettingsPage.entries.forEach { p ->
                        SettingsNavRow(p.icon, tr(p.titleKey), tr(p.subKey).takeIf { it != p.subKey }, onClick = { page = p })
                    }
                    SettingsPage.APPEARANCE -> AppearancePage()
                    SettingsPage.LANGUAGE -> LanguagePage()
                    SettingsPage.CHAT -> ChatSettingsPage()
                    SettingsPage.MEMORY -> MemoryPage()
                    SettingsPage.HF -> HfPage()
                    SettingsPage.STORAGE -> StoragePage()
                    SettingsPage.PRIVACY -> PrivacyPage()
                    SettingsPage.ABOUT -> AboutPage()
                }
            }
        }
    }
}
