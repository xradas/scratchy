# Patch Format

This is the initial contract for Scratchy patch definitions. The concrete Kotlin interfaces will be added after the core module is generated.

Each patch should define:

- stable patch ID
- human-readable name and description
- target package/application
- supported version rule or compatibility predicate
- prerequisites
- target detection/signature logic
- transformation operation
- post-patch validation
- meaningful failure diagnostics

## Behaviour

A patch must not execute if its compatibility or target detection checks fail. Unknown versions should be treated as unsupported until analysed.

## First proof of concept

`fixture.replace-welcome-label.v1` is a deliberately non-proprietary test patch. It supports only the fixture package/version declared in the compatibility matrix, requires one exact text occurrence, and validates that the original value is absent and the replacement occurs once. It demonstrates the failure model without targeting a third-party application.

## Testing expectations

Each patch should have tests for at least:

- supported target detection
- unsupported target rejection
- already-applied detection where applicable
- successful transformation using non-proprietary fixtures
- validation failure behaviour
