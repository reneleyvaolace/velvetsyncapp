plugins {
    // Add the dependency for the Google services Gradle plugin
    // Keep this compatible with the Kotlin/AGP toolchain used by Flutter 3.29.
    id("com.google.gms.google-services") version "4.4.2" apply false
    // Kotlin Gradle Plugin para compilar código Kotlin (requerido por Firebase Auth 25+)
    id("org.jetbrains.kotlin.android") version "2.2.20" apply false
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.projectDirectory
        .dir("../build")
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
