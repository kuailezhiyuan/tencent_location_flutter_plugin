group = "com.tencent.map.geolocation.tencent_location_flutter_plugin"
version = "1.0-SNAPSHOT"

buildscript {
    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.11.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

plugins {
    id("com.android.library")
    jacoco
}

jacoco {
    toolVersion = "0.8.12"
}

android {
    namespace = "com.tencent.map.geolocation.tencent_location_flutter_plugin"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/java")
        }
        getByName("test") {
            java.srcDirs("src/test/java")
        }
    }

    defaultConfig {
        minSdk = 21
    }

    testOptions {
        unitTests {
            isIncludeAndroidResources = true
            // 让 android.* stub jar 中未实现的方法返回默认值（false / 0 / null），
            // 例如 TextUtils.isEmpty()，否则会抛 RuntimeException。
            isReturnDefaultValues = true
            all {
                it.useJUnit()

                it.outputs.upToDateWhen { false }

                it.testLogging {
                    events("passed", "skipped", "failed", "standardOut", "standardError")
                    showStandardStreams = true
                }

                it.extensions.configure(JacocoTaskExtension::class) {
                    isIncludeNoLocationClasses = true
                    excludes = listOf("jdk.internal.*")
                }
            }
        }
    }
}

dependencies {
    // 腾讯定位 SDK（Maven Central 发布坐标）
    implementation("com.tencent.map.geolocation:TencentLocationSdk-openplatform:7.6.1.8")

    // 前台服务 Notification 构造
    implementation("androidx.core:core:1.13.1")
    implementation("androidx.annotation:annotation:1.9.1")

    testImplementation("junit:junit:4.13.2")
    testImplementation("org.mockito:mockito-core:5.14.2")
    // mockito-inline 提供 final 类 / static 方法 mock 能力（用于 TencentLocation / TencentPoi 等）
    testImplementation("org.mockito:mockito-inline:5.2.0")
}

// ---------- JaCoCo 报告 ----------
tasks.register<JacocoReport>("jacocoTestReport") {
    group = "verification"
    description = "Generates JaCoCo coverage report for the debug unit tests."

    dependsOn("testDebugUnitTest")

    reports {
        xml.required.set(true)
        html.required.set(true)
        csv.required.set(false)
    }

    val excludeFilter = listOf(
        // Android / 框架 / 依赖生成代码
        "**/R.class",
        "**/R$*.class",
        "**/BuildConfig.*",
        "**/Manifest*.*",
        "**/*\$ViewInjector*.*",
        "**/*\$ViewBinder*.*"
    )

    val javaClasses = fileTree("${layout.buildDirectory.get()}/intermediates/javac/debug/compileDebugJavaWithJavac/classes") {
        exclude(excludeFilter)
    }

    val sourceDirs = files(
        "src/main/java"
    )

    val executionDataFiles = fileTree(layout.buildDirectory.get()) {
        include(
            "outputs/unit_test_code_coverage/debugUnitTest/testDebugUnitTest.exec",
            "jacoco/testDebugUnitTest.exec"
        )
    }

    classDirectories.setFrom(javaClasses)
    sourceDirectories.setFrom(sourceDirs)
    executionData.setFrom(executionDataFiles)
}
