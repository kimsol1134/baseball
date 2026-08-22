plugins {
    alias(libs.plugins.android.library)
}

android {
    namespace = "com.solkim.baseball.platform"
    compileSdk = 36
    defaultConfig { minSdk = 26 }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

dependencies {
    api(project(":game-model"))
    implementation(libs.androidx.core.ktx)
    implementation(libs.kotlinx.coroutines.core)
    implementation(libs.firebase.analytics)
    implementation(libs.firebase.crashlytics)
    implementation(libs.amplitude.android)
    implementation(libs.okhttp)
    implementation(libs.play.review)
    testImplementation(kotlin("test"))
    testImplementation(libs.junit)
}
