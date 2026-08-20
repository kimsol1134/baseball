plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.library) apply false
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.compose.compiler) apply false
    alias(libs.plugins.google.services) apply false
}

allprojects {
    group = "com.solkim.baseball"
    version = "0.1.0-migration"
}

subprojects {
    dependencyLocking {
        lockAllConfigurations()
        // Production RC pulls Firebase/Amplitude/Unity transitives that debug lock
        // generation never recorded (kotlin-stdlib-common on releaseRuntimeClasspath).
        if (findProperty("baseballIgnoreDependencyLocks") == "true") {
            lockMode.set(org.gradle.api.artifacts.dsl.LockMode.LENIENT)
        }
    }
}
