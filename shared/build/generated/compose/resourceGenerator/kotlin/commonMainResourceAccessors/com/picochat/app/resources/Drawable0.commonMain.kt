@file:OptIn(InternalResourceApi::class)

package com.picochat.app.resources

import kotlin.OptIn
import kotlin.String
import kotlin.collections.MutableMap
import org.jetbrains.compose.resources.DrawableResource
import org.jetbrains.compose.resources.InternalResourceApi
import org.jetbrains.compose.resources.ResourceItem

private const val MD: String = "composeResources/com.picochat.app.resources/"

public val Res.drawable.app_logo: DrawableResource by lazy {
      DrawableResource("drawable:app_logo", setOf(
        ResourceItem(setOf(), "${MD}drawable/app_logo.svg", -1, -1),
      ))
    }

public val Res.drawable.chatgpt: DrawableResource by lazy {
      DrawableResource("drawable:chatgpt", setOf(
        ResourceItem(setOf(), "${MD}drawable/chatgpt.svg", -1, -1),
      ))
    }

public val Res.drawable.claude: DrawableResource by lazy {
      DrawableResource("drawable:claude", setOf(
        ResourceItem(setOf(), "${MD}drawable/claude.svg", -1, -1),
      ))
    }

public val Res.drawable.deepseek: DrawableResource by lazy {
      DrawableResource("drawable:deepseek", setOf(
        ResourceItem(setOf(), "${MD}drawable/deepseek.svg", -1, -1),
      ))
    }

public val Res.drawable.duckduckgo: DrawableResource by lazy {
      DrawableResource("drawable:duckduckgo", setOf(
        ResourceItem(setOf(), "${MD}drawable/duckduckgo.svg", -1, -1),
      ))
    }

public val Res.drawable.gemini: DrawableResource by lazy {
      DrawableResource("drawable:gemini", setOf(
        ResourceItem(setOf(), "${MD}drawable/gemini.svg", -1, -1),
      ))
    }

public val Res.drawable.github: DrawableResource by lazy {
      DrawableResource("drawable:github", setOf(
        ResourceItem(setOf(), "${MD}drawable/github.svg", -1, -1),
      ))
    }

public val Res.drawable.google: DrawableResource by lazy {
      DrawableResource("drawable:google", setOf(
        ResourceItem(setOf(), "${MD}drawable/google.svg", -1, -1),
      ))
    }

public val Res.drawable.grok: DrawableResource by lazy {
      DrawableResource("drawable:grok", setOf(
        ResourceItem(setOf(), "${MD}drawable/grok.svg", -1, -1),
      ))
    }

public val Res.drawable.huggingface: DrawableResource by lazy {
      DrawableResource("drawable:huggingface", setOf(
        ResourceItem(setOf(), "${MD}drawable/huggingface.svg", -1, -1),
      ))
    }

public val Res.drawable.mistral: DrawableResource by lazy {
      DrawableResource("drawable:mistral", setOf(
        ResourceItem(setOf(), "${MD}drawable/mistral.svg", -1, -1),
      ))
    }

public val Res.drawable.mojeek: DrawableResource by lazy {
      DrawableResource("drawable:mojeek", setOf(
        ResourceItem(setOf(), "${MD}drawable/mojeek.svg", -1, -1),
      ))
    }

@InternalResourceApi
internal fun _collectCommonMainDrawable0Resources(map: MutableMap<String, DrawableResource>) {
  map.put("app_logo", Res.drawable.app_logo)
  map.put("chatgpt", Res.drawable.chatgpt)
  map.put("claude", Res.drawable.claude)
  map.put("deepseek", Res.drawable.deepseek)
  map.put("duckduckgo", Res.drawable.duckduckgo)
  map.put("gemini", Res.drawable.gemini)
  map.put("github", Res.drawable.github)
  map.put("google", Res.drawable.google)
  map.put("grok", Res.drawable.grok)
  map.put("huggingface", Res.drawable.huggingface)
  map.put("mistral", Res.drawable.mistral)
  map.put("mojeek", Res.drawable.mojeek)
}
