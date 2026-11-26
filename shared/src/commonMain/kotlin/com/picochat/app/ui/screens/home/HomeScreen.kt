package com.picochat.app.ui.screens.home

import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.width
import androidx.compose.material3.DrawerValue
import androidx.compose.material3.ModalDrawerSheet
import androidx.compose.material3.ModalNavigationDrawer
import androidx.compose.material3.Surface
import androidx.compose.material3.rememberDrawerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.picochat.app.ui.screens.chat.ChatScreen
import com.picochat.app.ui.screens.models.ModelsScreen
import com.picochat.app.ui.screens.settings.SettingsScreen
import kotlinx.coroutines.launch

enum class Section { CHAT, MODELS, SETTINGS }

/** Wide windows: permanent sidebar. Phones: the sidebar slides in from the left. */
@Composable
fun HomeScreen() {
    var section by remember { mutableStateOf(Section.CHAT) }
    var chatId by remember { mutableStateOf<String?>(null) }
    val drawer = rememberDrawerState(DrawerValue.Closed)
    val scope = rememberCoroutineScope()

    BoxWithConstraints(Modifier.fillMaxSize()) {
        val wide = maxWidth >= 840.dp

        fun closeDrawer() = scope.launch { drawer.close() }

        val sidebar: @Composable (Modifier) -> Unit = { mod ->
            Sidebar(
                selectedChatId = chatId,
                section = section,
                onNewChat = { chatId = null; section = Section.CHAT; closeDrawer() },
                onOpenChat = { chatId = it; section = Section.CHAT; closeDrawer() },
                onOpenModels = { section = Section.MODELS; closeDrawer() },
                onOpenSettings = { section = Section.SETTINGS; closeDrawer() },
                modifier = mod,
            )
        }
        val content: @Composable () -> Unit = {
            val menu = { scope.launch { drawer.open() }; Unit }
            when (section) {
                Section.CHAT -> ChatScreen(
                    chatId = chatId,
                    showMenu = !wide,
                    onMenu = menu,
                    onOpenModels = { section = Section.MODELS },
                    onChatCreated = { chatId = it },
                )
                Section.MODELS -> ModelsScreen(showMenu = !wide, onMenu = menu)
                Section.SETTINGS -> SettingsScreen(showMenu = !wide, onMenu = menu)
            }
        }

        if (wide) {
            Row(Modifier.fillMaxSize()) {
                Surface(tonalElevation = 1.dp, modifier = Modifier.width(300.dp).fillMaxHeight()) { sidebar(Modifier) }
                Surface(Modifier.weight(1f).fillMaxHeight()) { content() }
            }
        } else {
            ModalNavigationDrawer(
                drawerState = drawer,
                drawerContent = { ModalDrawerSheet { sidebar(Modifier) } },
                content = content,
            )
        }
    }
}
