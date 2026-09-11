plugins {
    alias(libs.plugins.android.application)
    alias(libs.plugins.compose.compiler)
    alias(libs.plugins.google.services) apply false
    alias(libs.plugins.firebase.crashlytics) apply false
}

val platformExternalSdkEnabled = sequenceOf("platformExternalSdks", "phase9ExternalSdks")
    .map { providers.gradleProperty(it).orNull }
    .firstOrNull { !it.isNullOrBlank() }
    .equals("true", ignoreCase = true)
val platformAmplitudeApiKey = sequenceOf("platformAmplitudeApiKey", "phase9AmplitudeApiKey")
    .map { providers.gradleProperty(it).orNull }
    .firstOrNull { !it.isNullOrBlank() }
    .orEmpty()
    .replace("\\", "\\\\")
    .replace("\"", "\\\"")
val phase10VersionCode = providers.gradleProperty("phase10VersionCode")
    .orElse("42")
    .get()
    .toIntOrNull()
    ?.also { require(it > 5) { "versionCode must be higher than the current Play baseline" } }
    ?: error("phase10VersionCode must be an integer")
val phase10VersionName = providers.gradleProperty("phase10VersionName").orElse("1.0.0").get()
val releaseDistribution = providers.gradleProperty("phase11Distribution").orElse("internal").get()
    .also { require(it in setOf("internal", "production")) { "phase11Distribution must be internal or production" } }

fun firstSecret(property: String, vararg environments: String): String? =
    providers.gradleProperty(property).orNull?.takeIf(String::isNotBlank)
        ?: environments.firstNotNullOfOrNull { name ->
            providers.environmentVariable(name).orNull?.takeIf(String::isNotBlank)
        }

val phase10KeystorePath = firstSecret(
    "phase10SigningKeystorePath",
    "BASEBALL_PHASE10_SIGNING_KEYSTORE_PATH",
    "BASEBALL_UPLOAD_KEYSTORE_PATH",
)
val phase10StorePassword = firstSecret(
    "phase10SigningStorePassword",
    "BASEBALL_PHASE10_SIGNING_STORE_PASSWORD",
    "BASEBALL_UPLOAD_KEYSTORE_PASSWORD",
)
val phase10KeyAlias = firstSecret(
    "phase10SigningKeyAlias",
    "BASEBALL_PHASE10_SIGNING_KEY_ALIAS",
    "BASEBALL_UPLOAD_KEY_ALIAS",
)
val phase10KeyPassword = firstSecret(
    "phase10SigningKeyPassword",
    "BASEBALL_PHASE10_SIGNING_KEY_PASSWORD",
    "BASEBALL_UPLOAD_KEY_PASSWORD",
)
val phase10SigningConfigured = listOf(
    phase10KeystorePath,
    phase10StorePassword,
    phase10KeyAlias,
    phase10KeyPassword,
).all { it != null }

if (platformExternalSdkEnabled) {
    apply(plugin = "com.google.gms.google-services")
    apply(plugin = "com.google.firebase.crashlytics")
}

android {
    sourceSets.getByName("androidTest").assets.srcDir("../game-application/src/test/resources/regression")
    namespace = "com.solkim.baseball.android"
    compileSdk = 36

    defaultConfig {
        // The package ID is production-stable. Debug keeps the Phase 9 fixture isolated via the
        // suffix below; release is the nativeAuthoritative Play/update package.
        applicationId = "com.solkim.baseball.android"
        minSdk = 26
        targetSdk = 36
        versionCode = phase10VersionCode
        versionName = phase10VersionName
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        buildConfigField("boolean", "PLATFORM_EXTERNAL_SDKS_ENABLED", platformExternalSdkEnabled.toString())
        buildConfigField("String", "PLATFORM_AMPLITUDE_API_KEY", "\"$platformAmplitudeApiKey\"")
        buildConfigField("String", "NATIVE_AUTHORITY_MODE", "\"nativeShadowReadOnly\"")
        buildConfigField("boolean", "PHASE10_PRODUCTION_BUILD", "false")
        buildConfigField("boolean", "QA_NATIVE_STORE", "false")
        buildConfigField("String", "RELEASE_DISTRIBUTION", "\"development\"")
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
            // Isolated launch QA leaves any existing development career untouched.
            applicationIdSuffix = when {
                providers.gradleProperty("baseballAuditQa").orNull == "true" -> ".audit.compose.qa"
                providers.gradleProperty("baseballResetQa").orNull == "true" -> ".reset.compose.qa"
                providers.gradleProperty("baseballCoreQa").orNull == "true" -> ".core.compose.qa"
                providers.gradleProperty("baseballLaunchQa").orNull == "true" -> ".compose.qa"
                else -> ".compose.dev"
            }
            versionNameSuffix = "-migration"
            // The release build is native-authoritative, so QA must be able to run in that mode too.
            // Reset QA especially: erasing progress is a write, and a shadow read-only store cannot do it.
            val nativeQa = providers.gradleProperty("baseballQaNativeStore").orNull == "true" &&
                (providers.gradleProperty("baseballLaunchQa").orNull == "true" ||
                    providers.gradleProperty("baseballResetQa").orNull == "true")
            buildConfigField("boolean", "QA_NATIVE_STORE", nativeQa.toString())
            buildConfigField("String", "NATIVE_AUTHORITY_MODE", if (nativeQa) "\"nativeAuthoritative\"" else "\"nativeShadowReadOnly\"")
            buildConfigField("boolean", "PHASE10_PRODUCTION_BUILD", "false")
            buildConfigField("String", "RELEASE_DISTRIBUTION", "\"development\"")
        }
        release {
            isMinifyEnabled = false
            buildConfigField("String", "NATIVE_AUTHORITY_MODE", "\"nativeAuthoritative\"")
            buildConfigField("boolean", "PHASE10_PRODUCTION_BUILD", "true")
            buildConfigField("String", "RELEASE_DISTRIBUTION", "\"$releaseDistribution\"")
            if (phase10SigningConfigured) signingConfig = signingConfigs.getByName("phase10")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    packaging {
        resources.excludes += "/META-INF/{AL2.0,LGPL2.1}"
        // Play's 16KB page-size gate needs uncompressed, aligned native libraries.
        jniLibs.useLegacyPackaging = false
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
    implementation(project(":game-model"))
    implementation(project(":platform"))
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.browser)
    implementation(libs.androidx.activity.compose)
    implementation(platform(libs.androidx.compose.bom))
    implementation(libs.androidx.compose.foundation)
    implementation(libs.androidx.compose.material3)
    implementation(libs.androidx.compose.ui)
    implementation(libs.androidx.compose.ui.tooling.preview)
    implementation(libs.kotlinx.coroutines.core)
    testImplementation(libs.junit)
    androidTestImplementation(testFixtures(project(":game-application")))
    androidTestImplementation(platform(libs.androidx.compose.bom))
    androidTestImplementation(libs.androidx.compose.ui.test.junit4)
    androidTestImplementation(libs.androidx.test.ext.junit)
    androidTestImplementation(libs.androidx.test.uiautomator)
    debugImplementation(libs.androidx.compose.ui.test.manifest)
}
