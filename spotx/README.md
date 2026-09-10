# Scratchy — SpotX for Android

Scratchy is a Kotlin Android project for modular APK inspection and safe, version-aware transformation workflows. It is inspired by workflow ideas studied from SpotX-Bash; it does not copy its source or assume its desktop targets apply to Android.

## Project layout

- `app/` — Jetpack Compose Android user interface and APK picker
- `patch-engine/` — Android-independent inspection, compatibility, and diagnostic contracts
- `patches/` — patch metadata and benign transformation definitions
- `docs/` — architecture, compatibility, patch format, and research notes
- `scripts/` — repeatable developer tooling

## Current milestone

The app can select an APK and inspect package/version metadata using a disposable cache copy. The policy currently identifies `com.spotify.music` for inspection only; it rejects every other package and enables no transformations. The next milestone is a benign, fully validated UI/resource proof of concept.

## Development

Open the repository in Android Studio with JDK 17, allow Gradle to sync, then run the `app` configuration on Android 8.0 or later. Do not commit APKs, signing material, credentials, or extracted proprietary files.

See [architecture](docs/architecture.md), [development setup](docs/development-setup.md), and [patch format](docs/patch-format.md) for the project rules.
