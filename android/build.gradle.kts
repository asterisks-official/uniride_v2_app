// On the classpath rather than in settings' `plugins` block, because app/
// applies it imperatively behind an existence check and a `plugins { }` entry
// -- even one declared `apply false` -- is not visible to `apply(plugin = ...)`.
// Declaring it there instead makes the apply silently do nothing: the build
// succeeds, and the APK ships with no Firebase resources in it at all.
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.4.2")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Kotlin 2.2+ dropped support for language version ≤1.6.
// Force all plugin subprojects (sentry_flutter, etc.) to use at least 1.9.
subprojects {
    afterEvaluate {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile>().configureEach {
            compilerOptions {
                languageVersion.set(
                    org.jetbrains.kotlin.gradle.dsl.KotlinVersion.KOTLIN_1_9
                )
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
