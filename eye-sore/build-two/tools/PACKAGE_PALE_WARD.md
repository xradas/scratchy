# Portable Pale Ward Linux package

Run from any directory with Python 3.10+ and the pinned Godot 4.7.2 editor and
standard Linux x86_64 release template installed (see `docs/FOUNDATION.md`).
Native graphics/audio must be available: the release smoke uses the actual
renderer from `/tmp`. It fails on a nonzero exit, errors/warnings, or either
missing release success marker. It does not substitute a headless smoke.

```bash
python3 tools/package_pale_ward.py \
  --build-dir /home/rikki/Builds/eyesore-pale-ward-new \
  --executable-name eyesore-pale-ward.x86_64 \
  --dry-run

python3 tools/package_pale_ward.py \
  --build-dir /home/rikki/Builds/eyesore-pale-ward-new \
  --executable-name eyesore-pale-ward.x86_64
```

`--dry-run` validates the destination, source commit, preset, engine version,
template, credits/provenance, and optional video; it prints source hashes and
the plan without exporting or writing destination files. `--source-commit`
defaults to HEAD and must resolve to HEAD because export uses the current
working tree. Commit/source metadata is never edited. Dirty Git state and exact
runtime source file hashes are recorded, so a dirty build is not represented as
an exact commit-only build. Finish imports before packaging: changes to source
inputs during export cause failure. Git reads do not modify the repository.

The workflow exports through `tools/godot.sh`, exercises `--smoke-test
--gore-smoke` in the release executable with isolated settings, writes licenses
through `tools/package_engine_licenses.gd`, and copies current credits and art
provenance byte-for-byte. Known limitations come from `verification/INTEGRATION.json`
(with its input hash recorded), with conservative defaults if absent. The
coordinator retains ownership of source verification and acceptance metadata.
Failed commands do not publish a new package; temporary staging is discarded.

Existing destination executables and package files are protected unless
`--replace` is explicit. Unrelated destination files remain in place and are
not included in the archive. Use a new directory for accepted checkpoints.
Symlink destinations and source symlinks are refused. Publication happens only
after the package and archive pass verification.

`--video /path/to/existing.mp4` optionally copies the unchanged MP4 and paired
same-stem `.avi`, records both hashes, and includes them in the archive. A sole
MP4 already in the destination is selected automatically. Multiple MP4s require
an explicit selection. No capture/transcoding occurs and originals are preserved.
Existing copied video files with matching hashes are allowed without `--replace`.

`BUILD.json` records relative executable paths, actual engine/template hashes,
source commit and dirty status, source/build checksums, smoke scope, and known
limitations. `SOURCE_SHA256SUMS` covers runtime export inputs, the packaging
scripts, credits and copied provenance. `SHA256SUMS` covers all archive payload
files except itself. The tar.gz contains only portable staged files; ordering,
timestamps, owners and modes are normalized. Timestamp defaults to the source
commit time; `SOURCE_DATE_EPOCH` can override it. This makes archiving the same
payload reproducible; platform-dependent Godot exports/logs are not promised
to be byte-identical across hosts. Archived payload checksums and the executable's
hash and `0755` permission are verified without unsafe extraction.

`ARCHIVE.json` is outside the archive and records the archive hash, avoiding a
circular checksum dependency. The command's final JSON prints this same record.
Run bounded packaging checks with:

```bash
python3 -m unittest discover -s tools -p 'test_package_pale_ward.py'
```
