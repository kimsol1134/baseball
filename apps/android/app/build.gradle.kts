plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.compose.compiler)
}

val phase9ExternalSdkEnabled = providers.gradleProperty("phase9ExternalSdks")
    .map { it.equals("true", ignoreCase = true) }
    .orElse(false)
    .get()
val phase9AmplitudeApiKey = providers.gradleProperty("phase9AmplitudeApiKey").orElse("").get()
    .replace("\\", "\\\\")
    .replace("\"", "\\\"")
val phase10VersionCode = providers.gradleProperty("phase10VersionCode")
    .orElse("32")
    .get()
    .toIntOrNull()
    ?.also { require(it > 31) { "phase10VersionCode must be higher than the current internal baseline" } }
    ?: error("phase10VersionCode must be an integer")
val phase10VersionName = providers.gradleProperty("phase10VersionName").orElse("1.0.0").get()

fun phase10Input(property: String, environment: String): String? =
    providers.gradleProperty(property)
        .orElse(providers.environmentVariable(environment))
        .orNull
        ?.takeIf(String::isNotBlank)

val phase10KeystorePath = phase10Input("phase10SigningKeystorePath", "BASEBALL_PHASE10_SIGNING_KEYSTORE_PATH")
val phase10StorePassword = phase10Input("phase10SigningStorePassword", "BASEBALL_PHASE10_SIGNING_STORE_PASSWORD")
val phase10KeyAlias = phase10Input("phase10SigningKeyAlias", "BASEBALL_PHASE10_SIGNING_KEY_ALIAS")
val phase10KeyPassword = phase10Input("phase10SigningKeyPassword", "BASEBALL_PHASE10_SIGNING_KEY_PASSWORD")
val phase10SigningConfigured = listOf(
    phase10KeystorePath,
    phase10StorePassword,
    phase10KeyAlias,
    phase10KeyPassword,
).all { it != null }

android {
    namespace = "com.solkim.baseball.android"
    compileSdk = 36

    defaultConfig {
        // The package ID is production-stable. Debug keeps the Phase 9 fixture isolated via the
        // suffix below; release is the Phase 10 nativeAuthoritative rehearsal package.
        applicationId = "com.solkim.baseball.android"
        minSdk = 26
        targetSdk = 36
        versionCode = phase10VersionCode
        versionName = phase10VersionName
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        buildConfigField("boolean", "PHASE9_EXTERNAL_SDKS_ENABLED", phase9ExternalSdkEnabled.toString())
        buildConfigField("String", "PHASE9_AMPLITUDE_API_KEY", "\"$phase9AmplitudeApiKey\"")
        buildConfigField("String", "NATIVE_AUTHORITY_MODE", "\"nativeShadowReadOnly\"")
        buildConfigField("boolean", "PHASE10_PRODUCTION_BUILD", "false")
    }

    buildFeatures { buildConfig = true }

    if (phase10SigningConfigured) {
        signingConfigs {
            create("phase10") {
                storeFile = file(requireNotNull(phase10KeystorePath))
                storePassword = requireNotNull(phase10StorePassword)
                keyAlias = requireNotNull(phase10KeyAlias)
                keyPassword = requireNotNull(phase10KeyPassword)
            }
        }
    }

    buildTypes {
        debug {
            applicationIdSuffix = ".compose.dev"
            versionNameSuffix = "-migration"
            buildConfigField("String", "NATIVE_AUTHORITY_MODE", "\"nativeShadowReadOnly\"")
            buildConfigField("boolean", "PHASE10_PRODUCTION_BUILD", "false")
        }
        release {
            isMinifyEnabled = false
            buildConfigField("String", "NATIVE_AUTHORITY_MODE", "\"nativeAuthoritative\"")
            buildConfigField("boolean", "PHASE10_PRODUCTION_BUILD", "true")
            if (phase10SigningConfigured) signingConfig = signingConfigs.getByName("phase10")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    packaging {
        resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
        jniLibs.useLegacyPackaging = true
    }
}

// Never let a locally produced unsigned release artifact masquerade as a cutover candidate.
tasks.matching { it.name == "assembleRelease" || it.name == "bundleRelease" }.configureEach {
    doFirst {
        check(phase10SigningConfigured) {
            "Phase 10 release signing inputs are required; no signing values are checked into the repository"
        }
    }
}

dependencies {
    implementation(project(":design-system"))
    implementation(project(":game-application"))
    implementation(project(":game-core"))
    implementation(project(":game-model"))
    implementation(project(":unity-bridge"))
    implementation(project(":unity-runtime"))
    implementation(project(":platform"))
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.foundation)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.kotlinx.coroutines.core)
    testImplementation(libs.junit)
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.test.ext.junit)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
}

// The generated Unity export is optional for pure JVM contract tests, but mandatory for a real
// pitch-host APK. This conditional keeps the shadow-read-only scaffold buildable before export.
if (project.findProject(":unityLibrary") != null) {
    dependencies {
        implementation(project(":unityLibrary"))
    }
}
