plugins {
id("com.android.application")
id("com.google.gms.google-services")
id("kotlin-android")
id("dev.flutter.flutter-gradle-plugin")
}

android {

namespace = "com.example.parentledger"
compileSdk = flutter.compileSdkVersion
ndkVersion = flutter.ndkVersion

// ⭐⭐⭐⭐⭐ PRODUCTION SIGNING CONFIG ⭐⭐⭐⭐⭐
signingConfigs {

create("release") {

storeFile = file("../parentledger-release.keystore")

storePassword = "Maggie122012!"
keyAlias = "parentledger"
keyPassword = "Maggie122012!"
}
}

compileOptions {
sourceCompatibility = JavaVersion.VERSION_17
targetCompatibility = JavaVersion.VERSION_17
}

kotlinOptions {
jvmTarget = JavaVersion.VERSION_17.toString()
}

defaultConfig {

applicationId = "com.parentledger.app"

minSdk = flutter.minSdkVersion
targetSdk = flutter.targetSdkVersion

versionCode = flutter.versionCode
versionName = flutter.versionName
}

buildTypes {

release {

signingConfig = signingConfigs.getByName("release")

isMinifyEnabled = false
isShrinkResources = false
}

debug {
signingConfig = signingConfigs.getByName("debug")
}
}
}

flutter {
source = "../.."
}
