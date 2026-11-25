package com.picochat.app.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.picochat.app.l10n.Strings
import com.picochat.app.l10n.tr
import com.picochat.app.util.nativeInfo
import com.picochat.app.util.platformName

/** Root composable shared by Android, desktop and iOS. HomeScreen replaces the placeholder in the next phase. */
@Composable
fun App() {
    var ready by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        Strings.load()
        ready = true
    }
    MaterialTheme {
        Surface(Modifier.fillMaxSize()) {
            if (ready) {
                Column(
                    Modifier.fillMaxSize().padding(24.dp),
                    verticalArrangement = Arrangement.Center,
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text("PicoChat ($platformName)", style = MaterialTheme.typography.headlineMedium)
                    Text(tr("app_tagline"))
                    Text(nativeInfo(), style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }
}
