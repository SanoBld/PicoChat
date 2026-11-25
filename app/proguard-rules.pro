# JNI bridge: keep the native method owners
-keep class com.picochat.llama.** { *; }
-keepclassmembers class * { native <methods>; }
# kotlinx.serialization
-keepattributes *Annotation*, InnerClasses
-dontwarn kotlinx.serialization.**
