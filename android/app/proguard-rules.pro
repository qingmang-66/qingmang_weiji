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

# 保留行号：release 包默认会丢掉 LineNumberTable，线上崩溃栈只剩方法名，
# 无法定位到具体代码行。开启后配合 mapping.txt 可以还原完整堆栈
# （发版时请一并归档 build/app/outputs/mapping/release/mapping.txt）
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile
