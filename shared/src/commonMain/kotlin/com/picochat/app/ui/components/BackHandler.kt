package com.picochat.app.ui.components

import androidx.compose.runtime.Composable

/** System back gesture / button (Android). Desktop and iOS use the back arrow in the top bar. */
@Composable
expect fun PlatformBackHandler(enabled: Boolean, onBack: () -> Unit)
