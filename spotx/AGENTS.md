# Scratchy Agent Instructions

These rules apply to automated coding agents working in this repository.

## Architecture

- Android implementation: Kotlin.
- UI: Jetpack Compose.
- Keep the patch engine independent of Android UI code.
- Prefer small modules with explicit interfaces over one large patching script.
- Keep target/version detection separate from patch execution.

## Patch design

- Avoid hard-coded byte offsets when resilient structural/signature matching is practical.
- Every patch must have a stable ID and description.
- Every patch must declare its compatibility requirements.
- Every patch must detect whether its expected target exists before modifying anything.
- Every patch must validate its result after modification.
- Unsupported versions must fail closed with a useful diagnostic rather than attempting a best guess.

## Testing

- Add tests for patch-engine behaviour.
- Test detection, compatibility rejection, patch application and validation independently where possible.
- Build and run relevant tests before committing.
- Never add proprietary APKs or extracted proprietary application files as fixtures.

## Documentation

- Update documentation when architecture or developer setup changes.
- New patch mechanisms must be described in `docs/patch-format.md`.
- Compatibility changes must be reflected in `docs/compatibility.md`.
- Significant discoveries from reference-project analysis belong in `docs/spotx-bash-analysis.md`.

## Repository hygiene

Never commit:
- APK/AAB files from third parties
- signing keys or keystores
- passwords, tokens or credentials
- proprietary extracted application files
- local Android SDK configuration
- build outputs

## Git workflow

- Use descriptive commit messages.
- Prefer feature branches for substantial work.
- Keep commits scoped and reviewable.
- Do not rewrite shared history without explicit instruction.

## Scope

Scratchy may implement general APK inspection, version detection, benign UI/resource transformations, privacy-oriented changes and modular patching infrastructure. Do not implement mechanisms intended to defeat paid-access controls, licensing, authentication, DRM or service protections.
