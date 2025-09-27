import com.android.build.gradle.LibraryExtension
import org.gradle.kotlin.dsl.findByType
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

subprojects {
    if (name == "isar_flutter_libs") {
        plugins.withId("com.android.library") {
            extensions.findByType<LibraryExtension>()?.apply {
                if (namespace.isNullOrEmpty()) {
                    namespace = "com.isar.flutter.libs"
                }
                sourceSets.named("main") {
                    manifest.srcFile(rootProject.file("isar_flutter_libs_override/src/main/AndroidManifest.xml"))
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
