plugins {
    alias(libs.plugins.android.application) apply false
    alias(libs.plugins.android.library) apply false
    alias(libs.plugins.kotlin.jvm) apply false
    alias(libs.plugins.compose.compiler) apply false
}

allprojects {
    group = "com.solkim.baseball"
    version = "0.1.0-migration"
}

subprojects {
    dependencyLocking {
        lockAllConfigurations()
    }
}
