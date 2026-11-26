package com.picochat.app.util

/** Milliseconds since 1970-01-01 UTC. */
expect fun nowMillis(): Long

/** Local date and time for the system prompt, as "yyyy-MM-dd HH:mm". */
expect fun localDateTimeString(): String

/** ISO-8601 UTC ("2026-11-26T10:15:30.123Z"): same format as the Flutter app's files. */
fun isoFromMillis(ms: Long): String {
    val days = ms.floorDiv(86_400_000L)
    val rem = ms.mod(86_400_000L)
    // civil date from day count (Howard Hinnant's algorithm)
    val z = days + 719_468
    val era = z.floorDiv(146_097L)
    val doe = z - era * 146_097
    val yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365
    val doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
    val mp = (5 * doy + 2) / 153
    val d = doy - (153 * mp + 2) / 5 + 1
    val m = if (mp < 10) mp + 3 else mp - 9
    val y = yoe + era * 400 + if (m <= 2) 1 else 0
    fun p(n: Long, w: Int = 2) = n.toString().padStart(w, '0')
    return "${p(y, 4)}-${p(m)}-${p(d)}T${p(rem / 3_600_000)}:${p(rem / 60_000 % 60)}:${p(rem / 1000 % 60)}.${p(rem % 1000, 3)}Z"
}

fun nowIso(): String = isoFromMillis(nowMillis())
