plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")   // ← agrégalo explícito, AGP 8.x no trae Kotlin integrado
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.Uuy"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.Uuy"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.annotation:annotation:1.7.0")
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("androidx.core:core:1.12.0")

    implementation("com.google.ai.edge.litert:litert:1.4.0")
    implementation("com.google.ai.edge.litert:litert-api:1.4.0")

    implementation("com.google.ai.edge.litert:litert-support:1.4.0") {
        exclude(group = "com.google.ai.edge.litert", module = "litert-support-api")
    }

    implementation("com.github.wendykierp:JTransforms:3.1")
}