# Flutter / 插件保留规则
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# 本地通知 / 反序列化
-dontwarn com.google.android.gms.**
-keep class com.dexterous.** { *; }

# Play Core (Flutter deferred components，未使用)
-dontwarn com.google.android.play.core.**

# 避免 R8 误删插件反射入口
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
