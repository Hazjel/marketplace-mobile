import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing — key.properties is gitignored and points at a keystore
// stored outside this repo entirely. Both are absent on a fresh checkout
// (e.g. CI without the secret), so release signing falls back to the debug
// key rather than failing the build — matches this project's existing
// "debug build always works" guarantee. See README.md for what a real
// release build needs.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
val hasReleaseSigning = keystorePropertiesFile.exists()
if (hasReleaseSigning) {
    keystoreProperties.load(keystorePropertiesFile.inputStream())
}

android {
    namespace = "com.blukios.marketplace"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications (used by NotificationService for
        // foreground FCM display) needs Java 8+ APIs desugared for devices
        // below API 26 — without this the build fails at
        // :app:checkDebugAarMetadata.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.blukios.marketplace"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseSigning) {
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
            signingConfig = if (hasReleaseSigning) {
                signingConfigs.getByName("release")
            } else {
                // No key.properties on this machine (e.g. CI without the
                // secret) — fall back to the debug key so the build still
                // succeeds. Never ship a build signed this way.
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required by isCoreLibraryDesugaringEnabled above.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

// Applied only if the Firebase config file actually exists — the plugin
// itself hard-fails the build otherwise ("File google-services.json is
// missing"). Firebase isn't provisioned yet (see README.md); once
// google-services.json is added here, this activates automatically with
// no further gradle changes needed.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}
