# shellcheck shell=bash
# Shared by scripts/stage-stack.sh and scripts/verify-server-inputs.sh: where each pinned mod
# downloads from, so the URL the stager fetches and the URL the server-input lock records cannot
# disagree. A pin downloads from Thunderstore unless docs/modstack.md's "### Download sources"
# table names another URL for it.

# Download-source overrides from the "### Download sources" table: "team/mod | URL" rows. The
# URL column is rejected unless it is an https URL ending in .zip, so prose and broken rows are
# ignored the same way parse_pins ignores non-pin rows. A source row cannot be mistaken for a
# pin: a URL never passes parse_pins' digit-first version check.
parse_sources() {  # parse_sources <modstack.md>; prints "team/mod<TAB>url" per row
  awk '
    /^## / { sources = 0; next }
    /^### / { sources = ($0 == "### Download sources"); next }
    !sources { next }
    {
      if (sub(/^\|/, "") == 0) next
      split($0, f, "|")
      if (length(f) < 3) next
      gsub(/^ +| +$/, "", f[1]); gsub(/^ +| +$/, "", f[2])
      split(f[1], id, "/")
      if (id[1] ~ /^[A-Za-z0-9_-]+$/ && id[2] ~ /^[A-Za-z0-9_.-]+$/ && f[2] ~ /^https:\/\// && f[2] ~ /\.zip$/)
        print id[1] "/" id[2] "\t" f[2]
    }
  ' "$1"
}

# The override URL for one pin, or nothing when the pin downloads from Thunderstore.
source_url() {  # source_url <team/mod> <sources-tsv>
  awk -F'\t' -v key="$1" '$1 == key { print $2; exit }' "$2"
}

# Thunderstore's download URL for a pin with no override.
thunderstore_url() {  # thunderstore_url <team> <mod> <version>
  printf 'https://thunderstore.io/package/download/%s/%s/%s/\n' "$1" "$2" "$3"
}
