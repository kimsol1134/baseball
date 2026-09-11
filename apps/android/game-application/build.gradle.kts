plugins {
    `java-test-fixtures`
    alias(libs.plugins.kotlin.jvm)
}

kotlin { jvmToolchain(17) }

dependencies {
    api(project(":game-model"))
    // State/command types only. Kernels stay implementation so :app cannot call them.
    api(project(":game-core-api"))
    implementation(project(":game-core"))
    implementation(project(":game-persistence"))
    implementation(libs.kotlinx.coroutines.core)
    testFixturesApi(project(":game-core-api"))
    testFixturesImplementation(project(":game-core"))
    testImplementation(kotlin("test"))
    testImplementation(libs.junit)
}
