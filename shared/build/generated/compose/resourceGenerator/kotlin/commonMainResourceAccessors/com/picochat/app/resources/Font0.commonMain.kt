@file:OptIn(InternalResourceApi::class)

package com.picochat.app.resources

import kotlin.OptIn
import kotlin.String
import kotlin.collections.MutableMap
import org.jetbrains.compose.resources.FontResource
import org.jetbrains.compose.resources.InternalResourceApi
import org.jetbrains.compose.resources.ResourceItem

private const val MD: String = "composeResources/com.picochat.app.resources/"

public val Res.font.betania_patmos_gdl_regular: FontResource by lazy {
      FontResource("font:betania_patmos_gdl_regular", setOf(
        ResourceItem(setOf(), "${MD}font/betania_patmos_gdl_regular.ttf", -1, -1),
      ))
    }

public val Res.font.dancing_script_bold: FontResource by lazy {
      FontResource("font:dancing_script_bold", setOf(
        ResourceItem(setOf(), "${MD}font/dancing_script_bold.ttf", -1, -1),
      ))
    }

public val Res.font.dancing_script_medium: FontResource by lazy {
      FontResource("font:dancing_script_medium", setOf(
        ResourceItem(setOf(), "${MD}font/dancing_script_medium.ttf", -1, -1),
      ))
    }

public val Res.font.dancing_script_regular: FontResource by lazy {
      FontResource("font:dancing_script_regular", setOf(
        ResourceItem(setOf(), "${MD}font/dancing_script_regular.ttf", -1, -1),
      ))
    }

public val Res.font.dancing_script_semi_bold: FontResource by lazy {
      FontResource("font:dancing_script_semi_bold", setOf(
        ResourceItem(setOf(), "${MD}font/dancing_script_semi_bold.ttf", -1, -1),
      ))
    }

public val Res.font.google_sans_flex_24pt_bold: FontResource by lazy {
      FontResource("font:google_sans_flex_24pt_bold", setOf(
        ResourceItem(setOf(), "${MD}font/google_sans_flex_24pt_bold.ttf", -1, -1),
      ))
    }

public val Res.font.google_sans_flex_24pt_light: FontResource by lazy {
      FontResource("font:google_sans_flex_24pt_light", setOf(
        ResourceItem(setOf(), "${MD}font/google_sans_flex_24pt_light.ttf", -1, -1),
      ))
    }

public val Res.font.google_sans_flex_24pt_medium: FontResource by lazy {
      FontResource("font:google_sans_flex_24pt_medium", setOf(
        ResourceItem(setOf(), "${MD}font/google_sans_flex_24pt_medium.ttf", -1, -1),
      ))
    }

public val Res.font.google_sans_flex_24pt_regular: FontResource by lazy {
      FontResource("font:google_sans_flex_24pt_regular", setOf(
        ResourceItem(setOf(), "${MD}font/google_sans_flex_24pt_regular.ttf", -1, -1),
      ))
    }

public val Res.font.google_sans_flex_24pt_semi_bold: FontResource by lazy {
      FontResource("font:google_sans_flex_24pt_semi_bold", setOf(
        ResourceItem(setOf(), "${MD}font/google_sans_flex_24pt_semi_bold.ttf", -1, -1),
      ))
    }

public val Res.font.inter_24pt_bold: FontResource by lazy {
      FontResource("font:inter_24pt_bold", setOf(
        ResourceItem(setOf(), "${MD}font/inter_24pt_bold.ttf", -1, -1),
      ))
    }

public val Res.font.inter_24pt_semi_bold: FontResource by lazy {
      FontResource("font:inter_24pt_semi_bold", setOf(
        ResourceItem(setOf(), "${MD}font/inter_24pt_semi_bold.ttf", -1, -1),
      ))
    }

public val Res.font.inter_light: FontResource by lazy {
      FontResource("font:inter_light", setOf(
        ResourceItem(setOf(), "${MD}font/inter_light.otf", -1, -1),
      ))
    }

public val Res.font.inter_medium: FontResource by lazy {
      FontResource("font:inter_medium", setOf(
        ResourceItem(setOf(), "${MD}font/inter_medium.otf", -1, -1),
      ))
    }

public val Res.font.inter_regular: FontResource by lazy {
      FontResource("font:inter_regular", setOf(
        ResourceItem(setOf(), "${MD}font/inter_regular.ttf", -1, -1),
      ))
    }

public val Res.font.inter_variable_italic: FontResource by lazy {
      FontResource("font:inter_variable_italic", setOf(
        ResourceItem(setOf(), "${MD}font/inter_variable_italic.ttf", -1, -1),
      ))
    }

public val Res.font.mynerve_regular: FontResource by lazy {
      FontResource("font:mynerve_regular", setOf(
        ResourceItem(setOf(), "${MD}font/mynerve_regular.ttf", -1, -1),
      ))
    }

public val Res.font.open_sans_bold: FontResource by lazy {
      FontResource("font:open_sans_bold", setOf(
        ResourceItem(setOf(), "${MD}font/open_sans_bold.ttf", -1, -1),
      ))
    }

public val Res.font.open_sans_italic: FontResource by lazy {
      FontResource("font:open_sans_italic", setOf(
        ResourceItem(setOf(), "${MD}font/open_sans_italic.ttf", -1, -1),
      ))
    }

public val Res.font.open_sans_light: FontResource by lazy {
      FontResource("font:open_sans_light", setOf(
        ResourceItem(setOf(), "${MD}font/open_sans_light.ttf", -1, -1),
      ))
    }

public val Res.font.open_sans_medium: FontResource by lazy {
      FontResource("font:open_sans_medium", setOf(
        ResourceItem(setOf(), "${MD}font/open_sans_medium.ttf", -1, -1),
      ))
    }

public val Res.font.open_sans_regular: FontResource by lazy {
      FontResource("font:open_sans_regular", setOf(
        ResourceItem(setOf(), "${MD}font/open_sans_regular.ttf", -1, -1),
      ))
    }

public val Res.font.open_sans_semi_bold: FontResource by lazy {
      FontResource("font:open_sans_semi_bold", setOf(
        ResourceItem(setOf(), "${MD}font/open_sans_semi_bold.ttf", -1, -1),
      ))
    }

public val Res.font.roboto_bold: FontResource by lazy {
      FontResource("font:roboto_bold", setOf(
        ResourceItem(setOf(), "${MD}font/roboto_bold.ttf", -1, -1),
      ))
    }

public val Res.font.roboto_italic: FontResource by lazy {
      FontResource("font:roboto_italic", setOf(
        ResourceItem(setOf(), "${MD}font/roboto_italic.ttf", -1, -1),
      ))
    }

public val Res.font.roboto_light: FontResource by lazy {
      FontResource("font:roboto_light", setOf(
        ResourceItem(setOf(), "${MD}font/roboto_light.ttf", -1, -1),
      ))
    }

public val Res.font.roboto_medium: FontResource by lazy {
      FontResource("font:roboto_medium", setOf(
        ResourceItem(setOf(), "${MD}font/roboto_medium.ttf", -1, -1),
      ))
    }

public val Res.font.roboto_regular: FontResource by lazy {
      FontResource("font:roboto_regular", setOf(
        ResourceItem(setOf(), "${MD}font/roboto_regular.ttf", -1, -1),
      ))
    }

public val Res.font.roboto_slab_bold: FontResource by lazy {
      FontResource("font:roboto_slab_bold", setOf(
        ResourceItem(setOf(), "${MD}font/roboto_slab_bold.ttf", -1, -1),
      ))
    }

public val Res.font.roboto_slab_light: FontResource by lazy {
      FontResource("font:roboto_slab_light", setOf(
        ResourceItem(setOf(), "${MD}font/roboto_slab_light.ttf", -1, -1),
      ))
    }

public val Res.font.roboto_slab_medium: FontResource by lazy {
      FontResource("font:roboto_slab_medium", setOf(
        ResourceItem(setOf(), "${MD}font/roboto_slab_medium.ttf", -1, -1),
      ))
    }

public val Res.font.roboto_slab_regular: FontResource by lazy {
      FontResource("font:roboto_slab_regular", setOf(
        ResourceItem(setOf(), "${MD}font/roboto_slab_regular.ttf", -1, -1),
      ))
    }

public val Res.font.single_day_regular: FontResource by lazy {
      FontResource("font:single_day_regular", setOf(
        ResourceItem(setOf(), "${MD}font/single_day_regular.ttf", -1, -1),
      ))
    }

public val Res.font.space_grotesk_regular: FontResource by lazy {
      FontResource("font:space_grotesk_regular", setOf(
        ResourceItem(setOf(), "${MD}font/space_grotesk_regular.otf", -1, -1),
      ))
    }

public val Res.font.space_mono_regular: FontResource by lazy {
      FontResource("font:space_mono_regular", setOf(
        ResourceItem(setOf(), "${MD}font/space_mono_regular.otf", -1, -1),
      ))
    }

public val Res.font.spirax_regular: FontResource by lazy {
      FontResource("font:spirax_regular", setOf(
        ResourceItem(setOf(), "${MD}font/spirax_regular.ttf", -1, -1),
      ))
    }

@InternalResourceApi
internal fun _collectCommonMainFont0Resources(map: MutableMap<String, FontResource>) {
  map.put("betania_patmos_gdl_regular", Res.font.betania_patmos_gdl_regular)
  map.put("dancing_script_bold", Res.font.dancing_script_bold)
  map.put("dancing_script_medium", Res.font.dancing_script_medium)
  map.put("dancing_script_regular", Res.font.dancing_script_regular)
  map.put("dancing_script_semi_bold", Res.font.dancing_script_semi_bold)
  map.put("google_sans_flex_24pt_bold", Res.font.google_sans_flex_24pt_bold)
  map.put("google_sans_flex_24pt_light", Res.font.google_sans_flex_24pt_light)
  map.put("google_sans_flex_24pt_medium", Res.font.google_sans_flex_24pt_medium)
  map.put("google_sans_flex_24pt_regular", Res.font.google_sans_flex_24pt_regular)
  map.put("google_sans_flex_24pt_semi_bold", Res.font.google_sans_flex_24pt_semi_bold)
  map.put("inter_24pt_bold", Res.font.inter_24pt_bold)
  map.put("inter_24pt_semi_bold", Res.font.inter_24pt_semi_bold)
  map.put("inter_light", Res.font.inter_light)
  map.put("inter_medium", Res.font.inter_medium)
  map.put("inter_regular", Res.font.inter_regular)
  map.put("inter_variable_italic", Res.font.inter_variable_italic)
  map.put("mynerve_regular", Res.font.mynerve_regular)
  map.put("open_sans_bold", Res.font.open_sans_bold)
  map.put("open_sans_italic", Res.font.open_sans_italic)
  map.put("open_sans_light", Res.font.open_sans_light)
  map.put("open_sans_medium", Res.font.open_sans_medium)
  map.put("open_sans_regular", Res.font.open_sans_regular)
  map.put("open_sans_semi_bold", Res.font.open_sans_semi_bold)
  map.put("roboto_bold", Res.font.roboto_bold)
  map.put("roboto_italic", Res.font.roboto_italic)
  map.put("roboto_light", Res.font.roboto_light)
  map.put("roboto_medium", Res.font.roboto_medium)
  map.put("roboto_regular", Res.font.roboto_regular)
  map.put("roboto_slab_bold", Res.font.roboto_slab_bold)
  map.put("roboto_slab_light", Res.font.roboto_slab_light)
  map.put("roboto_slab_medium", Res.font.roboto_slab_medium)
  map.put("roboto_slab_regular", Res.font.roboto_slab_regular)
  map.put("single_day_regular", Res.font.single_day_regular)
  map.put("space_grotesk_regular", Res.font.space_grotesk_regular)
  map.put("space_mono_regular", Res.font.space_mono_regular)
  map.put("spirax_regular", Res.font.spirax_regular)
}
