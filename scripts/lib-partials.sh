# Shared rules for frontend/partials/. Sourced by build-index.sh and check-index.sh.
#
# Both scripts have to agree on what counts as a partial, down to the byte. If they
# drift, the writer can produce a tree the checker rejects — or worse, the checker
# can bless a tree the writer built from a different set of files. Keeping the rules
# in one place makes that agreement structural instead of a promise.
#
# Exit code 2 throughout: malformed input. That is a different failure from "the
# partials and the index disagree", which is exit 1 and belongs to check-index.sh.

# partials_collect <tool> <root> <dir>
#
# Validates frontend/partials/ and fills the global array PARTIALS in build order.
#
# Only plain `*.html` regular files directly inside the directory are accepted.
# Everything else is a hard error rather than something the glob quietly skips:
#
#   subdirectory   markup in partials/settings/ would never reach the document
#   symlink        the link target's bytes would land in a publicly served page
#   dotfile        an editor's backup would be invisible to review
#   .HTML / .htm   a typo would silently drop the file from the build
#
partials_collect() {
  local tool="$1" root="$2" dir="$3"
  local entry name rel bad=0

  if [ ! -d "$dir" ]; then
    echo "$tool: no partials directory at $dir" >&2
    return 2
  fi

  local entries=()
  shopt -s nullglob dotglob
  entries=("$dir"/*)
  shopt -u nullglob dotglob

  PARTIALS=()
  for entry in "${entries[@]}"; do
    name="${entry##*/}"
    rel="${entry#"$root/"}"

    # -L first: -d and -f follow symlinks, so a link to a directory or to a
    # regular .html file would otherwise pass as that thing.
    if [ -L "$entry" ]; then
      echo "$tool: symbolic link in partials: $rel (only plain files belong here)" >&2
      bad=1
      continue
    fi
    case "$name" in
      .*)
        echo "$tool: hidden entry in partials: $rel (remove it or move it out)" >&2
        bad=1
        continue
        ;;
    esac
    if [ -d "$entry" ]; then
      echo "$tool: subdirectory in partials: $rel (the build does not recurse)" >&2
      bad=1
      continue
    fi
    if [ ! -f "$entry" ]; then
      echo "$tool: not a regular file in partials: $rel" >&2
      bad=1
      continue
    fi
    case "$name" in
      *.html) ;;
      *)
        echo "$tool: not a .html file in partials: $rel (the extension is lowercase)" >&2
        bad=1
        continue
        ;;
    esac
    if [ ! -r "$entry" ]; then
      echo "$tool: partial is not readable: $rel" >&2
      bad=1
      continue
    fi

    PARTIALS+=("$entry")
  done

  if [ "$bad" -ne 0 ]; then
    echo "$tool: frontend/partials/ may contain only plain *.html files." >&2
    return 2
  fi

  if [ ${#PARTIALS[@]} -eq 0 ]; then
    echo "$tool: no partials found in $dir" >&2
    return 2
  fi
}

# partials_require_final_newline <tool> <root> <partial>...
#
# Concatenation is the whole build, so a partial that lost its final newline glues
# its last line onto the first line of the next one. A byte compare notices, but the
# resulting diff is thousands of shifted lines and unreadable, so this gets its own
# pass and its own message — and build-index.sh refuses to write such a file at all.
partials_require_final_newline() {
  local tool="$1" root="$2"
  shift 2
  local partial rel last bad=0

  for partial in "$@"; do
    rel="${partial#"$root/"}"
    if [ ! -s "$partial" ]; then
      echo "$tool: partial is empty: $rel (delete it, or put the markup back)" >&2
      bad=1
      continue
    fi
    # Command substitution strips trailing newlines, so an empty result means the
    # last byte was one. `if !` keeps a read failure from passing as "empty".
    if ! last="$(tail -c 1 -- "$partial")"; then
      echo "$tool: cannot read partial: $rel" >&2
      bad=1
      continue
    fi
    if [ -n "$last" ]; then
      echo "$tool: partial does not end with a newline: $rel" >&2
      echo "$tool:   its last line would be glued onto the start of the next partial" >&2
      bad=1
    fi
  done

  if [ "$bad" -ne 0 ]; then
    echo "$tool: fix the partials listed above, then re-run." >&2
    return 2
  fi
}
