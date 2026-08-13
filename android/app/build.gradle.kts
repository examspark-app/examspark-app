import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
} // Aapka yeh bracket miss ho gaya tha!

android {
    namespace = "com.sonialabs.sonaxia"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // Sonia Labs — Play Store / Firebase package id.
        applicationId = "com.sonialabs.sonaxia"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Yeh block add karna bohot zaroori hai
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias") as String? ?: ""
            keyPassword = keystoreProperties.getProperty("keyPassword") as String? ?: ""
            storeFile = file(keystoreProperties.getProperty("storeFile") as String? ?: "")
            storePassword = keystoreProperties.getProperty("storePassword") as String? ?: ""
        }
    }

    buildTypes {
        release {
            // Yahan humne "debug" ki jagah "release" set kar diya hai 👇
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}