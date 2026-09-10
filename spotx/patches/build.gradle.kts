plugins {
    id("org.jetbrains.kotlin.jvm")
}

kotlin { jvmToolchain(17) }

dependencies {
    implementation(project(":patch-engine"))
    testImplementation("junit:junit:4.13.2")
}
