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
}
subprojects {
    project.evaluationDependsOn(":app")
}

// file_picker's own plugin module still resolves the Flutter tooling's
// default compileSdk (34), which is older than what its own
// flutter_plugin_android_lifecycle dependency requires (36+). Setting
// compileSdk on the :app module alone doesn't affect this separate plugin
// module, so it's forced here specifically.
subprojects {
    if (project.name == "file_picker") {
        afterEvaluate {
            val androidExt = project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension
            androidExt?.compileSdkVersion(36)
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
