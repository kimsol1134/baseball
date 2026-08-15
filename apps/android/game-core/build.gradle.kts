plugins {
    alias(libs.plugins.kotlin.jvm)
}

kotlin { jvmToolchain(17) }

dependencies {
    api(project(":game-model"))
    testImplementation(kotlin("test"))
    testImplementation(libs.junit)
}

tasks.register<org.gradle.api.tasks.JavaExec>("runProCareerDistribution") {
    group = "verification"
    description = "Run the real journey-enabled Pro Career distribution (use -PproCareerRelease=true for 1000x20)."
    dependsOn(tasks.named("classes"))
    classpath = sourceSets["main"].runtimeClasspath
    mainClass.set("com.solkim.baseball.core.pro.ProCareerDistributionRunnerKt")
    if (project.findProperty("proCareerRelease") == "true") args("--release")
}
