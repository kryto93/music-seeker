#!/usr/bin/env bash
#
# Gate: frontend/partials/*.html and static/index.html are in sync.
#
# Builds the partials into a TEMPORARY file and compares. It never writes
# static/index.html — a gate that regenerates its own target would pass
# unconditionally and guard nothing. Use scripts/build-index.sh to regenerate.
#
# ---------------------------------------------------------------------------
# WHAT A GREEN RESULT MEANS, AND WHAT IT DOES NOT
#
# Green means: the partials on disk concatenate to exactly the committed
# static/index.html. The two representations agree.
#
# Green does NOT mean the document is intact. Delete a partial, rebuild, and
# this gate goes green again on the shorter document:
#
#     rm frontend/partials/90-full-player.html
#     scripts/build-index.sh     # "wrote ... from 15 partials"
#     scripts/check-index.sh     # "matches 15 partials", exit 0
#                                # ...and #fullPlayer is gone from the page
#
# That is not a hole to be plugged here: once both sides agree, no comparison
# between them can tell you a third thing is missing. What catches a deleted
# partial is the diff — a file disappears and ~157 lines vanish from
# static/index.html, which is loud in review. Read the diff. Do not let a green
# gate stand in for reading it.
#
# (A manifest of expected partials was considered and deliberately rejected: it
# would be a third copy of the same truth, and would drift from the other two.)
# ---------------------------------------------------------------------------
#
# Exit codes: 0 in sync, 1 out of sync, 2 malformed input.
#
set -euo pipefail

# Locale affects glob ordering; pin it so the check matches the build.
LC_ALL=C
export LC_ALL

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib-partials.sh
. "$root/scripts/lib-partials.sh"

partials_dir="$root/frontend/partials"
index="$root/static/index.html"

if [ ! -f "$index" ]; then
  echo "check-index: no ${index#"$root/"}" >&2
  exit 2
fi

# Step 1 — the partials directory holds only plain *.html files, each ending in a
# newline. Same rules build-index.sh enforces; both come from lib-partials.sh.
PARTIALS=()
partials_collect check-index "$root" "$partials_dir"
partials_require_final_newline check-index "$root" "${PARTIALS[@]}"

# Step 2 — concatenation must equal the committed index, byte for byte.
tmp="$(mktemp "${TMPDIR:-/tmp}/check-index.XXXXXX")"
trap 'rm -f "$tmp"' EXIT
cat -- "${PARTIALS[@]}" >"$tmp"

if cmp -s "$tmp" "$index"; then
  echo "check-index: ${index#"$root/"} agrees with ${#PARTIALS[@]} partials" \
       "(agreement only — a deleted partial also agrees; see the header)"
  exit 0
fi

echo "check-index: ${index#"$root/"} does NOT match frontend/partials/" >&2
echo "check-index: run scripts/build-index.sh if the partials are the source of truth." >&2
echo >&2
diff -u "$index" "$tmp" \
  --label "a/${index#"$root/"} (committed)" \
  --label "b/${index#"$root/"} (built from partials)" >&2 || true
exit 1
