#!/usr/bin/env bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tool_root="${EYESORE_TOOL_ROOT:-${HOME}/.local/share/eyesore-tools/4.7.2}"
godot_bin="${GODOT_BIN:-${tool_root}/Godot_v4.7.2-stable_linux.x86_64}"
if [[ ! -x "$godot_bin" ]]; then
  echo 'Install the pinned Godot 4.7.2 Linux editor; see docs/FOUNDATION.md.' >&2
  exit 1
fi
version="$("$godot_bin" --version)"
if [[ "$version" != 4.7.2.stable.* ]]; then
  echo "Godot 4.7.2 stable is required; found ${version}." >&2
  exit 1
fi
mkdir -p -- "$project_dir/build"
cd -- "$project_dir"
exec "$godot_bin" --path "$project_dir" "$@"
