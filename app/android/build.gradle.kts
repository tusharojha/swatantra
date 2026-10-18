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

// Plugins write compileSdk 34 in their own android {} block. Force 36 after
// that block. evaluationDependsOn(":app") is omitted so afterEvaluate is legal.
subprojects {
    afterEvaluate {
        val android = extensions.findByName("android") ?: return@afterEvaluate
        for (name in listOf("setCompileSdk", "setCompileSdkVersion")) {
            val methods = android.javaClass.methods.filter { it.name == name && it.parameterCount == 1 }
            for (m in methods) {
                val p = m.parameterTypes[0]
                if (p == Int::class.javaPrimitiveType || p == Int::class.java || p == Integer::class.java) {
                    try {
                        m.invoke(android, 36)
                    } catch (_: Exception) {
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
