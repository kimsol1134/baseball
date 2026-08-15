import org.gradle.api.initialization.resolve.RepositoriesMode
import java.io.FileInputStream
import java.util.Properties

pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}

rootProject.name = "baseball-android-compose"

include(
    ":app",
    ":design-system",
    ":game-model",
    ":game-core",
    ":game-application",
    ":game-persistence",
    ":platform",
    ":feature-shell",
    ":feature-career",
    ":feature-records",
    ":feature-settings",
    ":feature-pitch",
    ":unity-bridge",
    ":unity-runtime",
)

// The Unity export is generated, never hand-edited, and is intentionally absent from a
// shadow-read-only JVM/Compose build until the export wrapper has produced it.
val unityExport = rootDir
    .resolve("../..")
    .resolve("artifacts/android-compose/unity-export/current/unityLibrary")
if (unityExport.isDirectory) {
    include(":unityLibrary")
    project(":unityLibrary").projectDir = unityExport

    // Unity's exported gradle.properties lives beside unityLibrary. When the library is included
    // in this separate Compose build, Gradle does not load that file as a root properties file;
    // copy only its Unity build inputs into project extras so generated scripts remain portable.
    val unityPropertiesFile = unityExport.parentFile.resolve("gradle.properties")
    if (unityPropertiesFile.isFile) {
        val unityProperties = Properties()
        FileInputStream(unityPropertiesFile).use(unityProperties::load)
        gradle.beforeProject {
            unityProperties.stringPropertyNames()
                .filter { it == "unityStreamingAssets" || it.startsWith("unity.") }
                .forEach { key ->
                    extensions.extraProperties.set(key, unityProperties.getProperty(key))
                }
        }
    }
}
