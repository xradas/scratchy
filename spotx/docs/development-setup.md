# Development Setup

This document will track the reproducible Scratchy development environment.

## Planned toolchain

- Android Studio or VS Code with appropriate Android/Kotlin tooling
- JDK 17 or the version required by the selected Android Gradle Plugin
- Android SDK
- Kotlin
- Gradle wrapper committed to the repository
- Jetpack Compose

Current skeleton: Android Gradle Plugin 8.7.3, Gradle 8.10.2, Kotlin 2.0.21, compile/target SDK 35, and minimum SDK 26. The project builds successfully with JDK 17.

## Initial setup checklist

1. Clone the repository.
2. Install the documented JDK.
3. Install the documented Android SDK/platform/build tools.
4. Configure `ANDROID_HOME`/SDK discovery as appropriate for the development environment.
5. Do not commit `local.properties`.
6. Run the Gradle wrapper build.
7. Run unit tests.

## Validation commands

Use `./gradlew test assembleDebug`. CI should use the same wrapper command so local and hosted builds run against Gradle 8.10.2.

## VS Code / Codex

Open the repository root as the workspace. Coding agents should read the root `AGENTS.md` before changing the project.
