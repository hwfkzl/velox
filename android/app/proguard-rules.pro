# Flutter 相关类通过 JNI 反射调用,R8 看不到引用会误删
-keep class io.flutter.util.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.plugins.** { *; }

# path_provider 走 JNI 找 PathUtils
-keep class io.flutter.util.PathUtils { *; }

# singbox_flutter plugin + mihomo gomobile bind 通过 JNI 调
-keep class com.velox.singbox_flutter.** { *; }
-keep class bind.** { *; }
-keep class go.** { *; }

# gomobile 生成的 Java bridge class 都要保留
-keep class **.*Bind* { *; }
-keepclassmembers class * {
    @io.flutter.plugin.common.MethodChannel$MethodCallHandler *;
}

# WebView(Chrome-tab in-app 浏览器)相关
-keep class * extends android.webkit.WebViewClient
-keep class * extends android.webkit.WebChromeClient

# Flutter deferred components 是可选特性,我们没用。R8 看到 Flutter 引擎里
# 引用 Play Core class 但没打包依赖会报错,-dontwarn 让 R8 忽略这些类。
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
