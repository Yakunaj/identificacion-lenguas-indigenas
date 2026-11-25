import org.gradle.api.tasks.Delete
import org.gradle.jvm.toolchain.JavaLanguageVersion
import org.gradle.api.tasks.compile.JavaCompile
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir = rootProject.layout.buildDirectory
    .dir("../../build")
    .get()

rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    project.layout.buildDirectory.value(
        newBuildDir.dir(project.name)
    )
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
// Toolchain and Kotlin compiler options should be configured per-module
// (e.g. in `app/build.gradle.kts`) to avoid compatibility issues
// with different Gradle/Kotlin plugin versions. If you need a global
// setting, reintroduce a compatible configuration here matching your
// Gradle and Kotlin plugin versions.