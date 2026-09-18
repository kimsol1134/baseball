import org.gradle.api.initialization.resolve.RepositoriesMode

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
    ":game-core-api",
    ":game-core",
    ":game-application",
    ":game-persistence",
    ":platform",
)
