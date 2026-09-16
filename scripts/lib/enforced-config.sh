# Shared by scripts/apply-enforced-config.sh and scripts/verify-enforced-config.sh: one reading of
# what the enforced overlay says.
#
# The two scripts have to agree exactly, or the verification is worthless. A key the applier writes
# and the verifier does not read is enforcement nobody checks; a key the verifier reads and the
# applier never writes is a permanent failure. That is why the walk over the overlay, the parse of
# a `.cfg` overlay file and the lookup of a key in a generated target live here rather than being
# written twice (ADR-0011, #69).
#
# The format, stated once: a `.cfg` overlay holds section headers and `Key = value` entries and
# nothing else, and every entry is matched in the target by section *and* exact key text, because
# BepInEx files reuse key names across sections. Any other file is a data file with no merge
# semantics and is compared or copied whole.

enforced_die() { printf 'error: %s\n' "$*" >&2; exit 1; }

# Every file in the overlay, one relative path per line, in a stable order.
enforced_overlay_files() {  # enforced_overlay_files <overlay-dir>
  (cd "$1" && find . -type f | sed 's|^\./||' | LC_ALL=C sort)
}

# Parse a .cfg overlay file and hand each entry to a callback as `<section> <key> <value>`.
# Surrounding whitespace is stripped from the key and the value, so an overlay may be written with
# whatever spacing reads best and still matches a target the mod wrote differently. Anything that
# is not a comment, a blank line, a section header or an entry is a malformed overlay and aborts:
# silently skipping a line here would silently stop enforcing it.
enforced_cfg_each() {  # enforced_cfg_each <overlay-file> <callback>
  local overlay=$1 callback=$2
  local section="" key value line
  while IFS= read -r line || [[ -n "$line" ]]; do
    case "$line" in
      '#'*|'') continue ;;
      \[*\]) section="${line%\]}"; section="${section#\[}" ;;
      *=*)
        key="${line%%=*}"; value="${line#*=}"
        key="${key#"${key%%[![:space:]]*}"}"; key="${key%"${key##*[![:space:]]}"}"
        value="${value#"${value%%[![:space:]]*}"}"; value="${value%"${value##*[![:space:]]}"}"
        [[ -n "$section" && -n "$key" ]] || enforced_die "entry outside a section in $overlay: $line"
        "$callback" "$section" "$key" "$value"
        ;;
      *) enforced_die "not a section, comment or entry in $overlay: $line" ;;
    esac
  done < "$overlay"
}

# The value a generated target holds for one section+key, stripped of surrounding whitespace.
# Return code 3 is the "key absent" sentinel, distinct from any read failure, because the two mean
# opposite things: absent is a key the mod has not generated, which the applier appends and the
# verifier reports, while a failure to read must never be mistaken for either.
enforced_cfg_value() {  # enforced_cfg_value <target-file> <section> <key>
  local file=$1 section=$2 key=$3 rc=0
  awk -v sec="[$section]" -v key="$key" '
    /^\[/ { insec = ($0 == sec) ? 1 : 0; next }
    insec && index($0, "=") > 0 {
      lhs = substr($0, 1, index($0, "=") - 1)
      gsub(/^[ \t]+|[ \t]+$/, "", lhs)
      if (lhs == key) {
        val = substr($0, index($0, "=") + 1)
        gsub(/^[ \t]+|[ \t]+$/, "", val)
        print val
        found = 1
        exit
      }
    }
    END { exit found ? 0 : 3 }
  ' "$file" || rc=$?
  [[ $rc == 0 || $rc == 3 ]] || enforced_die "awk failed ($rc) reading $file"
  return $rc
}
