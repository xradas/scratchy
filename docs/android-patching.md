# Android Patching Notes

## Proof-of-concept scope

The first implementation should prove the complete pipeline using a benign resource/UI transformation:

1. Select an APK supplied by the developer/user.
2. Inspect package identity and version.
3. Reject unexpected targets.
4. Work on a temporary copy.
5. Extract/decode only as required by the chosen implementation.
6. Locate a known benign test target.
7. Apply the transformation.
8. Rebuild.
9. Sign with a development key that is not committed to the repository.
10. Validate package integrity and expected modification.
11. Return structured success/failure diagnostics.

## Design constraints

- Do not assume desktop SpotX targets exist on Android.
- Do not commit third-party APKs or extracted proprietary assets.
- Avoid destructive in-place operations on the user's source APK.
- Treat signing as a separate stage from transformation.
- Keep tooling adapters replaceable so the core patch model is not coupled to one external APK utility.

## Out of scope

Mechanisms intended to defeat paid-access controls, authentication, DRM, licensing or service protections are not part of Scratchy's implementation scope.
