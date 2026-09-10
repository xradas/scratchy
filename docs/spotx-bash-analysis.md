# SpotX-Bash Reference Analysis

Reference: https://github.com/SpotX-Official/SpotX-Bash

## Purpose

SpotX-Bash is being studied as a reference for patching workflow concepts. Scratchy is not a direct port: SpotX-Bash targets desktop Spotify installations on Linux/macOS, while Scratchy targets Android architecture and therefore requires Android-specific inspection and implementation.

## Concepts worth studying

- environment and installation detection
- application version detection
- compatibility gating
- backup/rollback concepts
- patch selection and options
- pattern/signature based target discovery
- validation after modification
- useful diagnostic output
- separation of platform-specific handling

## Desktop-specific concepts not directly transferable

SpotX-Bash contains logic tied to desktop installation layouts and desktop application assets such as `xpui.spa`. Android APK packaging, resources, DEX bytecode, manifests, signatures and native libraries require a different implementation.

## Analysis rule

Before implementing an Android equivalent, document:

1. What the reference behaviour accomplishes.
2. Which desktop component it modifies.
3. Whether an Android equivalent exists.
4. How that equivalent can be detected safely.
5. How compatibility will be versioned.
6. How the resulting change will be validated.

Do not copy third-party source code into Scratchy merely because it is technically reusable. Review licensing/attribution and prefer independently implemented Android-specific abstractions.
