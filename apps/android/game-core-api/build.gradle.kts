plugins {
    alias(libs.plugins.kotlin.jvm)
}

kotlin { jvmToolchain(17) }

dependencies {
    api(project(":game-model"))
    testImplementation(kotlin("test"))
    testImplementation(libs.junit)
}
