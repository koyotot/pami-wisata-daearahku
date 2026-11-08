plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services") version "4.4.2"
}

android {
    namespace = "com.example.wisata_daerahku"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "id.wisatadaerahku.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // HTTPS host of the Laravel API that serves /payment/return and /.well-known/assetlinks.json.
        // Set ORG_GRADLE_PROJECT_APP_LINK_HOST=api.example.com in the environment (flutter build does not accept -P) or
        // APP_LINK_HOST in android/gradle.properties; the default never matches a real host.
        manifestPlaceholders["appLinkHost"] =
            (project.findProperty("APP_LINK_HOST") as String?)?.takeIf { it.isNotBlank() } ?: "wisatadaerahku.invalid"
    }

    signingConfigs {
        create("wisataDebug") {
            storeFile = file("wisata-debug.keystore")
            storePassword = "android"
            keyAlias = "androiddebugkey"
            keyPassword = "android"
        }
    }

    buildTypes {
        getByName("debug") {
            signingConfig = signingConfigs.getByName("wisataDebug")
        }
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
