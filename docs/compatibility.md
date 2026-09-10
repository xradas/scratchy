# Compatibility

Compatibility data will be added only after a target version has been analysed and its detection/validation strategy tested.

## Policy

- Unknown target versions are unsupported by default.
- Compatibility must be determined per patch where appropriate rather than assuming every patch works on every supported application version.
- A target application update must not silently inherit compatibility from an older version.
- Compatibility changes require tests and documentation.

## Matrix

| Target | Version | Inspection | Benign POC patch | Notes |
|---|---|---:|---:|---|
| Android target application | TBD | Planned | Planned | Initial proof of concept |
