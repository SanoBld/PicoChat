package com.picochat.app.ui

import androidx.compose.animation.Crossfade
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Surface
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.picochat.app.data.store.ChatStore
import com.picochat.app.data.store.MemoryStore
import com.picochat.app.data.store.Prefs
import com.picochat.app.domain.ModelManager
import com.picochat.app.l10n.Strings
import com.picochat.app.ui.screens.home.HomeScreen
import com.picochat.app.ui.screens.intro.IntroScreen
import com.picochat.app.ui.theme.PicoMotion
import com.picochat.app.ui.theme.PicoTheme
import com.picochat.app.util.systemLanguage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

private enum class Stage { LOADING, INTRO, HOME }

/** Root composable shared by Android, desktop and iOS. */
@Composable
fun App() {
    var ready by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        withContext(Dispatchers.Default) {
            Prefs.load()
            ChatStore.load()
            MemoryStore.load()
            ModelManager.init()
        }
        Strings.load()
        Strings.setLanguage(Prefs.locale.value.ifEmpty { systemLanguage() })
        ready = true
    }
    val stage = when {
        !ready -> Stage.LOADING
        !Prefs.introDone.value -> Stage.INTRO
        else -> Stage.HOME
    }
    PicoTheme {
        Surface(Modifier.fillMaxSize()) {
            Crossfade(stage, animationSpec = PicoMotion.effects(), label = "stage") { s ->
                when (s) {
                    Stage.LOADING -> Box(Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
                    Stage.INTRO -> IntroScreen(onDone = { Prefs.introDone.set(true) })
                    Stage.HOME -> HomeScreen()
                }
            }
        }
    }
}
