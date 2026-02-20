import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

configurations.all {
    exclude(group = "com.google.android.gms", module = "play-services-ads-identifier")
}

android {
    ndkVersion = "28.2.13676358"
    namespace = "com.digitalnebi.allhabesha"

    // Compile against latest installed SDK; 35 is enough, 36 is fine if installed.
    compileSdk = 36

    defaultConfig {
        applicationId = "com.digitalnebi.allhabesha"
        minSdk = flutter.minSdkVersion
        targetSdk = 35

        // MUST increase every upload
        //versionCode = (System.getenv("BUILD_NUMBER") ?: "1").toInt()
        versionCode = (System.currentTimeMillis() / 1000).toInt()
        versionName = "0.1.0"
    }

    signingConfigs {
        create("release") {
            // Only set if key.properties exists + has values
            val storeFilePath = keystoreProperties["storeFile"] as String?
            if (!storeFilePath.isNullOrBlank()) {
                storeFile = file(storeFilePath)
                storePassword = keystoreProperties["storePassword"] as String?
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = false
            isShrinkResources = false
        }
        debug {
            // default debug config
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11"
    }
}

flutter {
    source = "../.."
}
