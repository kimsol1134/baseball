plugins {
    alias(libs.plugins.kotlin.jvm)
}

kotlin { jvmToolchain(17) }

dependencies {
    api(project(":game-model"))
    implementation(project(":game-core"))
    implementation(project(":game-persistence"))
    implementation(project(":unity-bridge"))
    implementation(libs.kotlinx.coroutines.core)
    testImplementation(kotlin("test"))
    testImplementation(libs.junit)
}
