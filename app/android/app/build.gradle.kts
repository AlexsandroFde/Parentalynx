import java.util.Properties

plugins {
    id("com.android.application")
    // O plugin Gradle do Flutter precisa vir depois dos plugins Android e Kotlin.
    id("dev.flutter.flutter-gradle-plugin")
}

// Assinatura de producao: lida de android/key.properties quando o arquivo existe.
// Sem ele, o build de release usa a chave de debug (serve so para testes locais).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
if (hasReleaseKeystore) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}

android {
    namespace = "com.parentalynx.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.parentalynx.app"
        // Android 9: primeira versao com eventos de tela no registro de uso do sistema.
        minSdk = 28
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = rootProject.file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig =
                if (hasReleaseKeystore) {
                    signingConfigs.getByName("release")
                } else {
                    signingConfigs.getByName("debug")
                }
        }
    }

    testOptions {
        unitTests {
            // Os testes de JVM exercitam so a logica pura. Chamadas acidentais ao framework
            // devolvem valores padrao em vez de lancar excecao.
            isReturnDefaultValues = true
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.core:core-ktx:1.17.0")
    implementation("androidx.work:work-runtime:2.11.2")
    implementation("com.squareup.okhttp3:okhttp:4.12.0")
    // Exigido pelo codigo gerado pelo Pigeon (metodos @async) e usado na ponte.
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.10.2")

    testImplementation("junit:junit:4.13.2")
    // org.json do framework e so um esqueleto na JVM: os testes usam a implementacao real.
    testImplementation("org.json:json:20250517")
    testImplementation("com.squareup.okhttp3:mockwebserver:4.12.0")
}
