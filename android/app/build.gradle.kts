import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release 签名:密码/keystore 路径存 android/key.properties(不进 git,见 .gitignore)。
// 弄丢 keystore 或密码 = 永远发不了 App 更新给已装用户,已备份到 ~/Desktop/velox-keystore-BACKUP。
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) load(FileInputStream(f))
}

android {
    namespace = "com.velox.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "28.2.13676358"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications 在 minSdk < 26 时需要 desugaring 才能用 Java 8+ time API。
        // 给 :app 开 coreLibraryDesugaring,Plugin AAR 才能编过。
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.velox.app"
        minSdk = 24  // Required for VPN service and libbox
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
            storePassword = keystoreProperties["storePassword"] as String?
            keyAlias = keystoreProperties["keyAlias"] as String?
            keyPassword = keystoreProperties["keyPassword"] as String?
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystoreProperties.isEmpty) {
                signingConfigs.getByName("debug")
            } else {
                signingConfigs.getByName("release")
            }
            // R8 混淆 + 收缩:release 版减小 APK 体积。必须配 proguard-rules.pro 保
            // Flutter/singbox JNI 反射调的类(否则 path_provider 崩 PathUtils 找不到)。
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }

    // Packaging options for sing-box native libraries
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
}

flutter {
    source = "../.."
}

// Include libbox.aar from plugin's libs directory
repositories {
    flatDir {
        dirs("${rootProject.projectDir}/../packages/singbox_flutter/android/libs")
    }
}

dependencies {
    // sing-box libbox library
    implementation(fileTree(mapOf("dir" to "${rootProject.projectDir}/../packages/singbox_flutter/android/libs", "include" to listOf("*.aar"))))

    // Core library desugaring(flutter_local_notifications 等 plugin 要求)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
