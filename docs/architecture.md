# Scratchy Architecture

## Design goals

Scratchy separates the Android user interface from target inspection and patch execution so that patching logic can be tested without Compose or Android screens.

## Planned modules

### app

Android application and Jetpack Compose UI. Responsibilities include file selection, displaying detected package/version information, compatible patch selection, progress, logs and output status.

### patch-engine

Core orchestration and abstractions for:

- target inspection
- package/version detection
- compatibility evaluation
- extraction/rebuild adapters
- patch execution
- result validation
- structured diagnostics

The engine must not depend on Compose UI classes.

### patches

Patch definitions. Each patch should provide metadata, compatibility rules, detection/preconditions, an application operation and post-application validation.

### tests

Unit and integration tests. Proprietary APKs and extracted proprietary application files must not be committed.

### scripts

Developer tooling that improves repeatability of local analysis/build/test tasks.

## Proposed processing flow

1. User selects an APK.
2. App passes a content/file abstraction to the inspection layer.
3. Engine reads package identity and version.
4. Compatibility layer determines available patches.
5. User selects supported transformations.
6. Engine creates a working copy and applies patches transactionally where practical.
7. Validation confirms expected changes and output integrity.
8. Build/signing adapter creates a development output.
9. App reports the result and detailed diagnostics.

## Failure model

Scratchy should fail closed. If a version, target structure or expected signature is unknown, it should stop that patch and explain why rather than making an uncertain modification.

## Version resilience

Prefer semantic/structural signatures over fixed offsets. Keep compatibility data separate enough that a target application update can be analysed and supported without rewriting unrelated UI or orchestration code.
