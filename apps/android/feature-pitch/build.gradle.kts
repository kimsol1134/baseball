plugins { alias(libs.plugins.kotlin.jvm) }
kotlin { jvmToolchain(17) }
dependencies {
    api(project(":game-application"))
    api(project(":unity-bridge"))
    testImplementation(kotlin("test"))
}
