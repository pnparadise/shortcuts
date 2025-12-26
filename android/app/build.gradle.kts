plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.devtools.ksp")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.shortcuts.shortcuts"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    buildFeatures {
        // compose = true // Removed
    }

    // composeOptions {
    //    kotlinCompilerExtensionVersion = "1.5.1"
    // }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.shortcuts.shortcuts"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // keyAlias, keyPassword, storeFile, and storePassword are read from environment variables
            // This allows the CI to inject them securely.
            // fallback to debug keys if not present (optional, but good for local release builds if desired)
             val keystorePath = System.getenv("KEYSTORE_FILE_PATH")
             if (keystorePath != null) {
                 storeFile = file(keystorePath)
                 storePassword = System.getenv("KEYSTORE_STORE_PASSWORD")
                 keyAlias = System.getenv("KEYSTORE_KEY_ALIAS")
                 keyPassword = System.getenv("KEYSTORE_KEY_PASSWORD")
             } else {
                 // Fallback or just leave empty which will fail build if signing is required but missing
                 // For now, let's just log or do nothing. If credentials are null, it might fail.
             }
        }
    }

    buildTypes {
        release {
            if (System.getenv("KEYSTORE_FILE_PATH") != null) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }
}

dependencies {
    // OkHttp for Logic Engine
    implementation("com.squareup.okhttp3:okhttp:4.12.0")

    val roomVersion = "2.6.1"
    implementation("androidx.room:room-runtime:$roomVersion")
    implementation("androidx.room:room-ktx:$roomVersion")
    ksp("androidx.room:room-compiler:$roomVersion")

    implementation("com.google.code.gson:gson:2.10.1")
    implementation("com.jayway.jsonpath:json-path:2.9.0")
}

flutter {
    source = "../.."
}
