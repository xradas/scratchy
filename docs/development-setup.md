# Development Setup

This document will track the reproducible Scratchy development environment.

## Planned toolchain

- Android Studio or VS Code with appropriate Android/Kotlin tooling
- JDK 17 or the version required by the selected Android Gradle Plugin
- Android SDK
- Kotlin
- Gradle wrapper committed to the repository
- Jetpack Compose

Exact Android Gradle Plugin, Gradle, Kotlin, compile SDK, target SDK and minimum SDK versions should be recorded here when the Android project skeleton is generated and successfully built.

## Initial setup checklist

1. Clone the repository.
2. Install the documented JDK.
3. Install the documented Android SDK/platform/build tools.
4. Configure `ANDROID_HOME`/SDK discovery as appropriate for the development environment.
5. Do not commit `local.properties`.
6. Run the Gradle wrapper build.
7. Run unit tests.

## Validation commands

Once the Gradle wrapper exists, this page should contain the exact commands used by both developers and CI.

## VS Code / Codex

Open the repository root as the workspace. Coding agents should read the root `AGENTS.md` before changing the project.
