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

// file_picker pulls flutter_plugin_android_lifecycle 2.0.35, which requires
// compileSdk 36. Set it as each Android plugin is applied — afterEvaluate is
// too late because evaluationDependsOn(":app") already evaluated the tree.
fun Project.forceCompileSdk36() {
    val android = extensions.findByName("android") ?: return
    for (name in listOf("setCompileSdk", "setCompileSdkVersion")) {
        val methods = android.javaClass.methods.filter { it.name == name && it.parameterCount == 1 }
        for (m in methods) {
            val p = m.parameterTypes[0]
            if (p == Int::class.javaPrimitiveType || p == Int::class.java || p == Integer::class.java) {
                try {
                    m.invoke(android, 36)
                    return
                } catch (_: Exception) {
                }
            }
        }
    }
}

subprojects {
    val p = this
    p.pluginManager.withPlugin("com.android.library") { p.forceCompileSdk36() }
    p.pluginManager.withPlugin("com.android.application") { p.forceCompileSdk36() }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
