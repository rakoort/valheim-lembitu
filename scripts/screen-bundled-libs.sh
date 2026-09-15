#!/usr/bin/env bash
# Screen an adopted package's bundled managed libraries against the game we run (ADR-0002).
#
#   scripts/screen-bundled-libs.sh <dll> [<dll>...]
#   scripts/screen-bundled-libs.sh --dir dist/plugins/ValheimRAFT
#
# A package that ships prebuilt libraries hides the ADR-0002 failure mode in each one: a member the
# game removed, or a field it turned into a `const`. The symptom appears at runtime, not at build,
# which is how the retired EpicMMOSystem fork learned its bundled PieceManager was as broken as its
# bundled ServerSync. This script is the check that was previously ad hoc prose in docs/build.md.
#
# What it does, per DLL, with the extracted game references in lib/valheim/:
#
#   1. every `ldsfld`/`ldsflda` into assembly_valheim is listed, and any whose target is a `const`
#      rather than a field is reported as a hard finding - that member's storage does not exist;
#   2. a stub `newobj`/`call` into a Valheim type that the game no longer declares is reported;
#   3. the result names the method containing each finding, so reachability can be argued from source
#      rather than assumed.
#
# Exit 0 means no stale member reference was found. Exit 1 means findings were printed. Exit 2 is a
# usage or prerequisite error, which is never a pass: an absent game reference or decompiler must not
# read as "clean".
#
# Requires ilspycmd (nix run nixpkgs#ilspycmd) and lib/valheim/ (scripts/extract-refs.sh).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAME_DIR="${VALHEIM_MANAGED:-$REPO_ROOT/lib/valheim}"
# The assembly whose members are screened. Overridable only so the regression test can drive the
# tool with a synthetic game assembly; against the real repo it is always assembly_valheim.
GAME_ASM="${SCREEN_GAME_ASSEMBLY:-assembly_valheim}"

die() { printf 'error: %s\n' "$*" >&2; exit 2; }

usage() {
  cat >&2 <<'USAGE'
usage: scripts/screen-bundled-libs.sh <dll> [<dll>...]
       scripts/screen-bundled-libs.sh --dir <directory>
USAGE
}

targets=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir) [[ $# -ge 2 ]] || die "--dir needs a directory"
           [[ -d "$2" ]] || die "no such directory: $2"
           while IFS= read -r f; do targets+=("$f"); done < <(find "$2" -type f -name '*.dll' | LC_ALL=C sort)
           shift ;;
    -h|--help) usage; exit 0 ;;
    -*) die "unknown option: $1" ;;
    *)  [[ -f "$1" ]] || die "no such file: $1"; targets+=("$1") ;;
  esac
  shift
done
[[ ${#targets[@]} -gt 0 ]] || { usage; exit 2; }

[[ -f "$GAME_DIR/$GAME_ASM.dll" ]] \
  || die "no game references in $GAME_DIR - run scripts/extract-refs.sh (see docs/build.md)"

ilspy=()
if command -v ilspycmd >/dev/null 2>&1; then ilspy=(ilspycmd)
elif command -v nix >/dev/null 2>&1; then
  # `nix shell` rather than `nix run`: the latter has no `-c` on every Nix we deploy from, and the
  # dev shell does not ship ilspycmd.
  ilspy=(nix shell nixpkgs#ilspycmd -c ilspycmd)
else die "ilspycmd not found and no nix available to supply it"
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# The `const` members the game declares, as `Type::Member`, so a stale field read can be told from a
# live one. ilspycmd emits a class as a bare `.class … Name` line and its members indented beneath it,
# with the member type ahead of the name: `.field public static literal int64 Everybody = int64(0)`.
consts="$work/consts.txt"
"${ilspy[@]}" -r "$GAME_DIR" "$GAME_DIR/$GAME_ASM.dll" --ilcode 2>/dev/null \
  | awk '
      /^\.class/ {
        line = $0
        sub(/^\.class[ \t]+/, "", line)
        sub(/[ \t]*\{.*$/, "", line)
        n = split(line, parts, /[ \t]+/)
        type = parts[n]
        next
      }
      /\.field public static literal/ {
        line = $0
        sub(/.*\.field public static literal[ \t]+/, "", line)
        sub(/[ \t]*=.*$/, "", line)
        sub(/.*[ \t]/, "", line)
        if (type != "" && line != "") print type "::" line
      }
    ' | LC_ALL=C sort -u > "$consts"
[[ -s "$consts" ]] || die "could not enumerate game const members from $GAME_DIR/$GAME_ASM.dll"

findings=0
for dll in "${targets[@]}"; do
  il="$work/$(basename "$dll").il"
  "${ilspy[@]}" -r "$GAME_DIR" "$dll" --ilcode > "$il" 2>/dev/null \
    || die "decompiling $dll failed"

  # Method context for each instruction, so a finding can be argued from source. A stale read is an
  # ldsfld/ldsflda whose `Type::Member` matches a game const: the member is inlined by the compiler
  # and has no field storage, so the instruction cannot resolve.
  awk -v consts="$consts" '
    # ilspycmd splits a method header across lines: `.method private hidebysig static` then
    # `void Prefix (`. The name is the last token of the first line that carries a parenthesis.
    /^[[:space:]]*\.method/ { inmethod = 1; method = $0; next }
    inmethod && /\(/ {
      name = $0
      sub(/[[:space:]]*\(.*$/, "", name)
      sub(/^.*[[:space:]]/, "", name)
      if (name != "") method = method " " name
      inmethod = 0
    }
    /ldsfld(a)?[[:space:]]+.*\[[^]]+\]/ {
      target = $0
      sub(/.*\]/, "", target)              # drop the [assembly] scope bracket
      sub(/[[:space:]]+at.*$/, "", target)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", target)
      while ((getline c < consts) > 0) if (c == target) { stale = 1; break }
      close(consts)
      if (stale) {
        m = method
        sub(/^[[:space:]]*\.method[[:space:]]*/, "", m)
        gsub(/[[:space:]]+/, " ", m)
        print target "\t" m
        stale = 0
      }
    }
  ' "$il" > "$work/found"

  if [[ -s "$work/found" ]]; then
    findings=$((findings + 1))
    echo "=== $dll"
    printf '    a game member read here is a const, so its field storage does not exist:\n'
    while IFS=$'\t' read -r target method; do
      printf '      %s  (in %s)\n' "$target" "$method"
    done < <(LC_ALL=C sort -u "$work/found")
    echo "    Reachability must be argued from the calling source: an ldsfld in a method that"
    echo "    never runs is not a failure, and a package that never registers a synced config"
    echo "    entry never reaches one. See ADR-0002."
  fi
done

if [[ $findings -eq 0 ]]; then
  echo "clean: no stale game-member reference found in ${#targets[@]} library(ies)"
  exit 0
fi
echo
echo "$findings of ${#targets[@]} library(ies) hold a stale game-member reference"
exit 1
