# Scratchy

Scratchy is an Android project for experimenting with modular APK analysis and patching workflows, inspired by ideas studied from SpotX-Bash.

## Project status

Early architecture and proof-of-concept stage.

## Goals

- Android application written in Kotlin with Jetpack Compose.
- Keep the patch engine independent from the UI.
- Detect target package/version before applying any transformation.
- Use version-aware, testable patch definitions.
- Validate outputs after patching.
- Keep project setup, architecture, compatibility and troubleshooting documented in-repo.

## Repository layout

- `app/` — Android UI/application layer.
- `patch-engine/` — target inspection, extraction/rebuild orchestration and patch execution abstractions.
- `patches/` — version-aware patch definitions.
- `tests/` — integration/test fixtures that do not contain proprietary APK content.
- `scripts/` — developer helpers.
- `docs/` — design, setup and compatibility documentation.
- `.github/workflows/` — CI configuration.

## First milestone

1. Create the Android/Kotlin project.
2. Select an APK using Android's file picker.
3. Read package name and version.
4. Reject unsupported/non-target APKs.
5. Apply one benign resource/UI proof-of-concept change.
6. Rebuild and sign with a development key.
7. Validate the resulting APK.
8. Document the entire workflow.

## Reference project

SpotX-Bash: https://github.com/SpotX-Official/SpotX-Bash

SpotX-Bash is treated as a reference implementation for concepts and workflow analysis. Do not copy third-party source code into this repository unless its licence and attribution requirements have been deliberately reviewed.

## Security / repository hygiene

Do not commit APK files, signing keys, passwords, tokens, proprietary application files or generated secrets.
