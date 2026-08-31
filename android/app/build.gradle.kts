import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing material. `android/key.properties` is deliberately untracked
// (see .gitignore) and does not exist on a fresh clone, so every read of it is
// guarded: debug builds, `flutter test` and CI keep working without a keystore.
// A *release* build without this file is signed with nothing and will be
// rejected by Play — see the comment on the release build type below.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    FileInputStream(keystorePropertiesFile).use { keystoreProperties.load(it) }
}

android {
    namespace = "com.outabout.outabout"
    // Pinned rather than inherited from the Flutter SDK on the build machine:
    // Play requires new apps and updates to target Android 16 (API 36) as of
    // 31 August 2026.
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Immutable once the first bundle is uploaded to Play. Matches the iOS
        // bundle identifier and the iOS App Group.
        applicationId = "com.outabout.outabout"
        minSdk = 24
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Play rejects any bundle signed with the debug key. When
            // key.properties is missing the signing config is left unset, which
            // fails the *release* build loudly instead of silently producing an
            // unuploadable artefact — while leaving debug builds and the test
            // suite working on a machine with no keystore.
            if (hasReleaseKeystore) {
                signingConfig = signingConfigs.getByName("release")
            }
            isDebuggable = false
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

flutter {
    source = "../.."
}
