# Troubleshooting

This page will grow with reproducible fixes as the Android project and patch engine are implemented.

## Repository opens but Gradle cannot find Android SDK

Confirm the Android SDK is installed and configure the local SDK path/environment. Do not commit machine-specific `local.properties`.

## Wrong Java version

Use the JDK version documented in `docs/development-setup.md`. Check `java -version` and the JDK selected by the IDE/Gradle environment.

## Target version is reported unsupported

Do not force a patch. Record the package/version, analyse the new target structure, update compatibility/detection rules, add tests, and only then mark the version compatible.

## Patch target cannot be found

Treat this as a compatibility failure. Preserve diagnostic information but do not fall back to guessed offsets or locations.

## Rebuilt APK will not install

Check build output, package identity, signing status, device Android version and whether an existing installation is signed by a different key. Do not commit development or production signing keys while troubleshooting.
