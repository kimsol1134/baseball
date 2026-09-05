plugins { alias(libs.plugins.kotlin.jvm) }
kotlin { jvmToolchain(17) }
dependencies {
    api(project(":game-application"))
    testImplementation(kotlin("test"))
}
