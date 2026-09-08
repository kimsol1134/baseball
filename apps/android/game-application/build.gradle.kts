plugins {
    `java-test-fixtures`
    alias(libs.plugins.kotlin.jvm)
}

kotlin { jvmToolchain(17) }

dependencies {
    api(project(":game-model"))
    api(project(":game-core"))
    implementation(project(":game-persistence"))
    implementation(libs.kotlinx.coroutines.core)
    testFixturesApi(project(":game-core"))
    testImplementation(kotlin("test"))
    testImplementation(libs.junit)
}
