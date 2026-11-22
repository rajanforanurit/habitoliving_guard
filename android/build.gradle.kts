allprojects {
    repositories {
        google()
        mavenCentral()
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

    if (project.name == "flutter_webrtc") {
        afterEvaluate {
            // The pinned WebRTC plugin declares SDK 31, but its AndroidX
            // dependencies require the same newer SDK used by the guard app.
            extensions.configure<com.android.build.gradle.LibraryExtension> {
                compileSdk = maxOf(compileSdk ?: 0, 36)
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
