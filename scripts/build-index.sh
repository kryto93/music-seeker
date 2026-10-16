#!/usr/bin/env bash
#
# Build static/index.html from frontend/partials/*.html.
#
# The partials are a line-for-line decomposition of the document, in document
# order, so the build is a plain concatenation and the result is byte-identical
# by construction. Run this after editing any partial.
#
# This script is the ONLY thing that writes static/index.html.
#
# It applies exactly the rules check-index.sh applies (both source
# scripts/lib-partials.sh), so it cannot write a file the gate would then reject.
#
set -euo pipefail

# Locale affects glob ordering; pin it so the build is the same everywhere.
LC_ALL=C
export LC_ALL

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Exit 1 is reserved for "partials and index disagree"; a missing library is bad
# input, so check before sourcing rather than letting `.` fail with exit 1.
lib="$root/scripts/lib-partials.sh"
if [ ! -r "$lib" ]; then
  echo "build-index: cannot read ${lib#"$root/"}" >&2
  exit 2
fi
# shellcheck source=lib-partials.sh
. "$lib"

partials_dir="$root/frontend/partials"
index="$root/static/index.html"

PARTIALS=()
partials_collect build-index "$root" "$partials_dir"
partials_require_final_newline build-index "$root" "${PARTIALS[@]}"

# Write through a temporary file in the target directory so a failed or
# interrupted build cannot leave a truncated index.html behind.
tmp="$(mktemp "$index.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
cat -- "${PARTIALS[@]}" >"$tmp"
chmod 644 "$tmp"
mv "$tmp" "$index"
trap - EXIT

echo "build-index: wrote ${index#"$root/"} from ${#PARTIALS[@]} partials"
