package com.picochat.app.util

import platform.Foundation.NSDate
import platform.Foundation.NSDateFormatter
import platform.Foundation.timeIntervalSince1970

actual fun nowMillis(): Long = (NSDate().timeIntervalSince1970 * 1000).toLong()

actual fun localDateTimeString(): String {
    val f = NSDateFormatter()
    f.dateFormat = "yyyy-MM-dd HH:mm"
    return f.stringFromDate(NSDate())
}
