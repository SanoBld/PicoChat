package com.picochat.app.ui.theme

import androidx.compose.material3.Shapes
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.unit.dp

/** Expressive shape scale: rounder than the Material 3 baseline. */
val PicoShapes = Shapes(
    extraSmall = RoundedCornerShape(10.dp),
    small = RoundedCornerShape(14.dp),
    medium = RoundedCornerShape(20.dp),
    large = RoundedCornerShape(28.dp),
    extraLarge = RoundedCornerShape(40.dp),
)

/** The user's message: a big rounded bubble with a small tail corner. */
val UserBubbleShape = RoundedCornerShape(topStart = 26.dp, topEnd = 26.dp, bottomStart = 26.dp, bottomEnd = 6.dp)

/** The assistant's boxed answer: small corner at the top left, where the answer starts. */
val AnswerBoxShape = RoundedCornerShape(topStart = 8.dp, topEnd = 28.dp, bottomStart = 28.dp, bottomEnd = 28.dp)
