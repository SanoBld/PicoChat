package com.picochat.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp

private sealed interface Block {
    data class Para(val text: String) : Block
    data class Heading(val level: Int, val text: String) : Block
    data class Item(val marker: String, val text: String) : Block
    data class Code(val text: String) : Block
}

private val bulletRegex = Regex("^\\s*([-*+]|\\d+[.)])\\s+(.*)$")

private fun parseBlocks(src: String): List<Block> {
    val out = mutableListOf<Block>()
    val para = StringBuilder()
    fun flushPara() {
        if (para.isNotBlank()) out += Block.Para(para.toString().trim())
        para.clear()
    }
    var inCode = false
    val code = StringBuilder()
    for (line in src.split("\n")) {
        if (line.trimStart().startsWith("```")) {
            if (inCode) {
                out += Block.Code(code.toString().trimEnd('\n'))
                code.clear()
            } else {
                flushPara()
            }
            inCode = !inCode
            continue
        }
        if (inCode) {
            code.append(line).append('\n')
            continue
        }
        val heading = Regex("^(#{1,3})\\s+(.*)$").find(line)
        val bullet = bulletRegex.find(line)
        when {
            line.isBlank() -> flushPara()
            heading != null -> {
                flushPara()
                out += Block.Heading(heading.groupValues[1].length, heading.groupValues[2])
            }
            bullet != null -> {
                flushPara()
                val m = bullet.groupValues[1]
                out += Block.Item(if (m[0].isDigit()) m else "•", bullet.groupValues[2])
            }
            else -> {
                if (para.isNotEmpty()) para.append(' ')
                para.append(line.trim())
            }
        }
    }
    if (inCode) out += Block.Code(code.toString().trimEnd('\n')) // unclosed fence while streaming
    flushPara()
    return out
}

/** **bold**, *italic*, _italic_ and `code` inside one line of text. */
private fun inline(text: String, codeBg: Color): AnnotatedString = buildAnnotatedString {
    var i = 0
    while (i < text.length) {
        when {
            text.startsWith("**", i) && text.indexOf("**", i + 2) > 0 -> {
                val end = text.indexOf("**", i + 2)
                withStyle(SpanStyle(fontWeight = FontWeight.Bold)) { append(text.substring(i + 2, end)) }
                i = end + 2
            }
            text[i] == '`' && text.indexOf('`', i + 1) > 0 -> {
                val end = text.indexOf('`', i + 1)
                withStyle(SpanStyle(fontFamily = FontFamily.Monospace, background = codeBg)) { append(text.substring(i + 1, end)) }
                i = end + 1
            }
            (text[i] == '*' || text[i] == '_') && i + 1 < text.length && text[i + 1] != ' ' && text.indexOf(text[i], i + 1) > i + 1 -> {
                val end = text.indexOf(text[i], i + 1)
                withStyle(SpanStyle(fontStyle = FontStyle.Italic)) { append(text.substring(i + 1, end)) }
                i = end + 1
            }
            else -> {
                append(text[i])
                i++
            }
        }
    }
}

/** Small Markdown renderer for chat answers: headings, lists, code blocks and inline styles. */
@Composable
fun MarkdownLite(text: String, modifier: Modifier = Modifier) {
    val blocks = remember(text) { parseBlocks(text) }
    val codeBg = MaterialTheme.colorScheme.surfaceVariant
    Column(modifier, verticalArrangement = Arrangement.spacedBy(8.dp)) {
        blocks.forEach { b ->
            when (b) {
                is Block.Para -> Text(inline(b.text, codeBg), style = MaterialTheme.typography.bodyLarge)
                is Block.Heading -> Text(
                    inline(b.text, codeBg),
                    style = when (b.level) {
                        1 -> MaterialTheme.typography.headlineSmall
                        2 -> MaterialTheme.typography.titleLarge
                        else -> MaterialTheme.typography.titleMedium
                    },
                    fontWeight = FontWeight.SemiBold,
                )
                is Block.Item -> Row {
                    Text(b.marker, modifier = Modifier.padding(end = 8.dp, start = 4.dp), style = MaterialTheme.typography.bodyLarge)
                    Text(inline(b.text, codeBg), style = MaterialTheme.typography.bodyLarge)
                }
                is Block.Code -> Text(
                    b.text,
                    fontFamily = FontFamily.Monospace,
                    style = MaterialTheme.typography.bodyMedium,
                    modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(codeBg)
                        .horizontalScroll(rememberScrollState()).padding(12.dp),
                )
            }
        }
    }
}
