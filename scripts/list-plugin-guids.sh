#!/usr/bin/env bash
# List every BepInEx plugin a BepInEx/plugins tree declares, and whether the dedicated server's
# chainloader loads it, from the assemblies' own metadata (#113). No game, no loader: each DLL is
# disassembled with ilspycmd and its [BepInPlugin] and [BepInProcess] attributes are decoded.
#
#   scripts/list-plugin-guids.sh <plugins-dir>
#
# Prints one sorted line per plugin class:
#   <guid><TAB>load                                    no process filter, or one naming the server
#   <guid><TAB>skip process filter <process,...>        BepInEx skips it on valheim_server
# A DLL that is not a managed assembly (ilspycmd refuses it) declares nothing and is passed over.
# Exit 2 if ilspycmd is missing or the directory is not one.
#
# The server image's lock (docs/server-inputs.lock.json, serverPlugins) records this list, and
# test/server-image.test.sh checks the running chainloader against it: two sources, the metadata
# and the loader, that must agree with each other and with the lock.

set -euo pipefail

die() { printf 'error: %s\n' "$*" >&2; exit 2; }
[[ $# -eq 1 && -d "$1" ]] || die "usage: scripts/list-plugin-guids.sh <plugins-dir>"
command -v ilspycmd >/dev/null 2>&1 || die "ilspycmd is required (nixpkgs#ilspycmd)"

# The process name BepInEx compares a filter with: the executable's name without its extension.
SERVER_PROCESS=valheim_server

# Decode the custom-attribute blob's leading serialized strings: prolog 01 00, then each string
# as a compressed length and its UTF-8 bytes (ECMA-335 II.23.3). Prints one string per line.
decode_strings() {  # decode_strings <count> <hex bytes...>
  local count=$1 i=2 n length byte text; shift
  local -a bytes=("$@")
  [[ "${bytes[0]:-}" == 01 && "${bytes[1]:-}" == 00 ]] || return 1
  for ((n = 0; n < count; n++)); do
    byte=$((16#${bytes[i]}))
    if ((byte < 0x80)); then length=$byte; i=$((i + 1))
    elif ((byte < 0xC0)); then length=$(((byte & 0x3F) << 8 | 16#${bytes[i + 1]})); i=$((i + 2))
    else return 1
    fi
    text=""
    for ((; length > 0; length--, i++)); do text+="\\x${bytes[i]}"; done
    printf '%b\n' "$text"
  done
}

# One record per plugin class, from ilspycmd's IL: the attribute lines and their hex blobs.
plugins_in() {  # plugins_in <dll>
  local il
  il="$(ilspycmd --disable-updatecheck -il "$1" 2>/dev/null)" || return 0
  awk '
    /^[\t ]*\.class / { if (guid != "") emit(); guid = ""; procs = ""; next }
    /\.custom instance void \[BepInEx\]BepInEx\.(BepInPlugin|BepInProcess)::\.ctor/ {
      kind = ($0 ~ /BepInPlugin/) ? "plugin" : "process"; hex = ""; collecting = 1
      sub(/.*= \(/, ""); 
    }
    collecting {
      line = $0; done = (line ~ /\)/); sub(/\).*/, "", line); hex = hex " " line
      if (done) {
        collecting = 0; gsub(/[^0-9a-f ]/, "", hex)
        if (kind == "plugin") guid = hex; else procs = procs "|" hex
      }
    }
    function emit() { print guid "\t" procs }
    END { if (guid != "") emit() }
  ' <<< "$il"
}

while IFS= read -r -d '' dll; do
  while IFS=$'\t' read -r guid_hex procs_hex; do
    # shellcheck disable=SC2086  # the hex bytes are meant to split into arguments
    guid="$(decode_strings 1 $guid_hex)" || { printf 'error: cannot decode BepInPlugin in %s\n' "$dll" >&2; exit 1; }
    filters=()
    IFS='|' read -r -a parts <<< "${procs_hex#|}"
    for part in "${parts[@]}"; do
      [[ -n "${part// /}" ]] || continue
      # shellcheck disable=SC2086
      filters+=("$(decode_strings 1 $part)")
    done
    status=load
    if ((${#filters[@]} > 0)); then
      status="skip process filter $(IFS=,; printf '%s' "${filters[*]}")"
      for filter in "${filters[@]}"; do
        [[ "${filter%.*}" == "$SERVER_PROCESS" || "$filter" == "$SERVER_PROCESS" ]] && status=load
      done
    fi
    printf '%s\t%s\n' "$guid" "$status"
  done < <(plugins_in "$dll")
done < <(find -L "$1" -type f -iname '*.dll' -print0) | LC_ALL=C sort
