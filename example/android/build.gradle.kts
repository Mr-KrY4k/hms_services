import org.gradle.api.file.Directory

allprojects {
    repositories {
        google()
        mavenCentral()
        maven(url = "https://developer.huawei.com/repo/")
    }
}

buildscript {
    repositories {
        google()
        mavenCentral()
        maven(url = "https://developer.huawei.com/repo/")
        gradlePluginPortal()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.8.1")
        classpath("com.huawei.agconnect:agcp:1.9.1.303")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.1.0")
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


