package com.picochat.app.ui.theme

import androidx.compose.animation.EnterTransition
import androidx.compose.animation.ExitTransition
import androidx.compose.animation.core.SpringSpec
import androidx.compose.animation.core.spring
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.shrinkVertically
import androidx.compose.animation.slideInVertically

/**
 * Material 3 Expressive motion: springs instead of fixed durations.
 * "spatial" springs move things (a little overshoot = playful), "effects" springs fade and recolour (no overshoot).
 */
object PicoMotion {
    fun <T> spatial(): SpringSpec<T> = spring(dampingRatio = 0.78f, stiffness = 380f)
    fun <T> spatialFast(): SpringSpec<T> = spring(dampingRatio = 0.85f, stiffness = 900f)
    fun <T> effects(): SpringSpec<T> = spring(dampingRatio = 1f, stiffness = 1600f)

    /** A new element (message, card) grows in softly. */
    val appear: EnterTransition
        get() = fadeIn(effects()) + slideInVertically(spatial()) { it / 10 } + scaleIn(spatial(), initialScale = 0.94f)

    val disappear: ExitTransition
        get() = fadeOut(effects())

    val expand: EnterTransition get() = fadeIn(effects()) + expandVertically(spatial())
    val collapse: ExitTransition get() = fadeOut(effects()) + shrinkVertically(spatialFast())
}
