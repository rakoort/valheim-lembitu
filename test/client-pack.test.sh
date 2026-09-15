#!/usr/bin/env bash
# Behaviour tests for scripts/build-client-pack.sh (#21).
#
# The boundary this test defends is the server/client asymmetry: a client pack that carries a
# server-only plugin, or silently loses a client-side one, is a support problem for a non-technical
# player. Real zip fixtures in an isolated cache; no network.
#
#   test/client-pack.test.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILDER="$REPO_ROOT/scripts/build-client-pack.sh"
STAGER="$REPO_ROOT/scripts/stage-stack.sh"

# No jq here on purpose: the dev shell does not provide it (scripts/stage-stack.sh says so, and
# flake.nix does not list it), and docs/agents/check.conf runs every test/*.test.sh. A test that
# skips itself when jq is missing would silently stop defending the excluded-plugin boundary under
# the project's own check. The manifest is read with the same grep/sed idiom the scripts use.

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0 fail=0
report() {
  printf '%s: %s\n' "$([ "$1" = ok ] && echo pass || echo FAIL)" "$2"
  [ "$1" = ok ] && pass=$((pass + 1)) || fail=$((fail + 1))
}

# A JSON value from the manifest, and a crude but real structural check: a JSON object's braces and
# brackets must balance and it must not end a member with a comma. Trailing commas and doubled
# commas are the specific malformation this builder has produced, so they are checked directly
# rather than by pulling in a parser the dev shell does not have.
json_value() {  # json_value <manifest> <key>
  # A bracketed array value for the key, on its own line or inside one.
  sed -n "s/.*\"$2\": *\(\[[^]]*\]\).*/\1/p" "$1" | head -1
}

json_looks_valid() {  # json_looks_valid <manifest>
  local f=$1 text opens closes
  text="$(tr -d '\n' < "$f")"
  # A doubled or trailing comma is invalid JSON wherever it appears.
  grep -qE ', *,|,[[:space:]]*[}\]]' <<<"$text" && return 1
  # Braces and brackets must balance. `wc -c` pads its output, so compare numerically.
  opens="$(tr -cd '{' < "$f" | wc -c)"; closes="$(tr -cd '}' < "$f" | wc -c)"
  (( opens == closes )) || return 1
  opens="$(tr -cd '[' < "$f" | wc -c)"; closes="$(tr -cd ']' < "$f" | wc -c)"
  (( opens == closes )) || return 1
  return 0
}

pin_count() {  # pin_count <manifest>; entries inside the "pins" object
  sed -n '/"pins"/,/^  }/p' "$1" | grep -cE '^  "[^"]+@[^"]+": "[0-9a-f]{64}"'
}

# --- fixtures ----------------------------------------------------------------------------------
# A pin table with the two packages the asymmetry turns on: one client-side adopted package and one
# server-only plugin that is NOT in the adopted table (MaxPlayerCount is a fork, so it is staged by
# the build rather than by the pin list). The test injects the server-only plugin into the staged
# tree the way a mistaken pack would, and checks the builder refuses it.

cat > "$WORK/modstack.md" <<'MD'
# The mod stack

## Adopted upstream

| Mod | Pin | Role | Enforced config |
| --- | --- | --- | --- |
| acme/BoneMod | 1.0.2 | Cosmetic bone scaling (client-side) | — |
| acme/Clan | 1.0.10 | Clans | — |

## Forks

| Fork | Forked from | Why |
| --- | --- | --- |
| MaxPlayerCount | Azumatt | Player cap |
MD

CACHE="$WORK/cache"; mkdir -p "$CACHE"

make_zip() {  # make_zip <zip> <entry:content>...
  local zip=$1; shift
  local dir; dir="$(mktemp -d "$WORK/z.XXXXXX")"
  local spec entry content
  for spec in "$@"; do
    entry="${spec%%:*}"
    content="${spec#*:}"
    mkdir -p "$dir/$(dirname "$entry")"
    printf '%s\n' "$content" > "$dir/$entry"
  done
  rm -f -- "$zip"
  ( cd "$dir" && zip -qr "$zip" . )
  rm -rf "$dir"
}

make_zip "$CACHE/acme-BoneMod-1.0.2.zip" \
  'plugins/BoneMod.dll:BoneMod' \
  'manifest.json:{"name":"BoneMod","version_number":"1.0.2","dependencies":[]}'
make_zip "$CACHE/acme-Clan-1.0.10.zip" \
  'plugins/Clan.dll:Clan' \
  'BepInEx/config/Clan/emblem.png:emblem' \
  'manifest.json:{"name":"Clan","version_number":"1.0.10","dependencies":[]}'

LOCK="$WORK/lock.json"
{
  printf '{\n'
  printf '  "acme/BoneMod@1.0.2": "%s",\n' "$(shasum -a 256 "$CACHE/acme-BoneMod-1.0.2.zip" | cut -d' ' -f1)"
  printf '  "acme/Clan@1.0.10": "%s"\n'   "$(shasum -a 256 "$CACHE/acme-Clan-1.0.10.zip" | cut -d' ' -f1)"
  printf '}\n'
} > "$LOCK"

build() {  # build <out> [extra args...]
  local out=$1; shift
  "$BUILDER" --out "$out" --version t --pins "$WORK/modstack.md" --cache "$CACHE" --lock "$LOCK" "$@" \
    > "$WORK/out" 2>&1
}

# --- 1. the client-side adopted package is staged, with its config seed ------------------------

OUT1="$WORK/out1"
if build "$OUT1"; then
  archive="$OUT1/lembitu-client-pack-t.zip"
  listing="$(unzip -Z1 "$archive")"
  if grep -qx 'plugins/BoneMod/BoneMod.dll' <<<"$listing" \
     && grep -qx 'plugins/Clan/Clan.dll' <<<"$listing" \
     && grep -qx 'config/Clan/emblem.png' <<<"$listing"; then
    report ok "stages the client-side packages and their config seeds"
  else
    report fail "stages the client-side packages and their config seeds"
  fi
else
  report fail "stages the client-side packages and their config seeds"
fi

# --- 2. the manifest is valid JSON naming the exclusions and the pins -------------------------

manifest="$OUT1/lembitu-client-pack-t.manifest.json"
if json_looks_valid "$manifest"; then
  excluded="$(json_value "$manifest" excluded_server_only)"
  pins="$(pin_count "$manifest")"
  if [[ "$excluded" == *MaxPlayerCount* ]] && [ "$pins" -eq 2 ]; then
    report ok "manifest is valid JSON naming the server-only exclusions and the pin hashes"
  else
    report fail "manifest is valid JSON naming the server-only exclusions and the pin hashes"
  fi
else
  report fail "manifest is valid JSON naming the server-only exclusions and the pin hashes"
fi

# --- 3. the file inventory lists what a player installs, and nothing else --------------------

versions="$OUT1/lembitu-client-pack-t.versions.txt"
if grep -q 'plugins/BoneMod/BoneMod.dll' "$versions" && ! grep -q 'staged-dirs' "$versions"; then
  report ok "writes a per-file inventory with hashes and no builder bookkeeping"
else
  report fail "writes a per-file inventory with hashes and no builder bookkeeping"
fi

# The published directory holds exactly the three artifacts, and the archive holds none of them. A
# pack that ships its own manifest inside itself is the mistake this asserts against.
listing="$(unzip -Z1 "$OUT1/lembitu-client-pack-t.zip")"
published="$(ls "$OUT1" | wc -l | tr -d ' ')"
if [ "$published" -eq 3 ] && ! grep -qxE '\.?/(manifest\.json|versions\.txt|pack\.zip|stage\.log)' <<<"$listing"; then
  report ok "publishes exactly three artifacts and puts no builder file inside the archive"
else
  report fail "publishes exactly three artifacts and puts no builder file inside the archive"
fi

# --- 4. a server-only plugin in the staged tree is refused -----------------------------------
# The failure this test exists for. MaxPlayerCount is a fork, not an adopted pin, so simulating the
# mistake means putting it in the pin table as a naive pack build would. The builder's absence
# assertion must catch it, including when it is a stray DLL inside another package's tree.

cat > "$WORK/modstack-serveronly.md" <<'MD'
# The mod stack

## Adopted upstream

| Mod | Pin | Role | Enforced config |
| --- | --- | --- | --- |
| acme/BoneMod | 1.0.2 | Cosmetic (client-side) | — |
| acme/MaxPlayerCount | 1.2.5 | Player cap (server-only) | — |
MD

make_zip "$CACHE/acme-MaxPlayerCount-1.2.5.zip" \
  'plugins/MaxPlayerCount.dll:MaxPlayerCount' \
  'manifest.json:{"name":"MaxPlayerCount","version_number":"1.2.5","dependencies":[]}'
{
  printf '{\n'
  printf '  "acme/BoneMod@1.0.2": "%s",\n' "$(shasum -a 256 "$CACHE/acme-BoneMod-1.0.2.zip" | cut -d' ' -f1)"
  printf '  "acme/MaxPlayerCount@1.2.5": "%s"\n' "$(shasum -a 256 "$CACHE/acme-MaxPlayerCount-1.2.5.zip" | cut -d' ' -f1)"
  printf '}\n'
} > "$WORK/lock-serveronly.json"

if ! "$BUILDER" --out "$WORK/out4" --version t --pins "$WORK/modstack-serveronly.md" \
       --cache "$CACHE" --lock "$WORK/lock-serveronly.json" > "$WORK/out" 2>&1 \
   && grep -q "must not ship to players" "$WORK/out" \
   && [ ! -e "$WORK/out4/lembitu-client-pack-t.zip" ]; then
  report ok "refuses a pack containing a server-only plugin, and publishes no archive"
else
  report fail "refuses a pack containing a server-only plugin, and publishes no archive"
fi

# --- 5. a missing client-side package is refused, not silently dropped -----------------------

cat > "$WORK/modstack-noclient.md" <<'MD'
# The mod stack

## Adopted upstream

| Mod | Pin | Role | Enforced config |
| --- | --- | --- | --- |
| acme/Clan | 1.0.10 | Clans | — |
MD

{
  printf '{\n'
  printf '  "acme/Clan@1.0.10": "%s"\n' "$(shasum -a 256 "$CACHE/acme-Clan-1.0.10.zip" | cut -d' ' -f1)"
  printf '}\n'
} > "$WORK/lock-noclient.json"

if ! "$BUILDER" --out "$WORK/out5" --version t --pins "$WORK/modstack-noclient.md" \
       --cache "$CACHE" --lock "$WORK/lock-noclient.json" > "$WORK/out" 2>&1 \
   && grep -q "missing required client-side package" "$WORK/out"; then
  report ok "refuses a pack that lost a required client-side package"
else
  report fail "refuses a pack that lost a required client-side package"
fi

# --- 6. a tampered package is refused by the stager's hash check ------------------------------

printf 'tampered\n' > "$CACHE/acme-BoneMod-1.0.2.zip"
if ! build "$WORK/out6" && grep -qi "hash mismatch" "$WORK/out"; then
  report ok "refuses a package whose bytes do not match the lock"
else
  report fail "refuses a package whose bytes do not match the lock"
fi
make_zip "$CACHE/acme-BoneMod-1.0.2.zip" \
  'BoneMod/BoneMod.dll:BoneMod' \
  'BoneMod/manifest.json:{"name":"BoneMod","version_number":"1.0.2","dependencies":[]}'

# --- 7. --list prints the client pin list without downloading or writing ----------------------

if [[ -x "$STAGER" ]]; then
  listed="$("$BUILDER" --list --pins "$WORK/modstack.md" 2>/dev/null)"
  if grep -q 'BoneMod' <<<"$listed" && grep -q 'Clan' <<<"$listed"; then
    report ok "--list prints the client pin list"
  else
    report fail "--list prints the client pin list"
  fi
fi

# --- 8. a failure publishes nothing at all ----------------------------------------------------
# The three artifacts are one unit. A manifest without the zip it describes, or a zip without the
# inventory a player checks it against, is a partial pack that looks complete — and a release
# operator who sees files in the output directory will attach them. Simulated by removing the
# archiver from PATH, which is the failure that produced exactly this symptom.

OUT8="$WORK/out8"
if ! PATH="/usr/bin:/bin" "$BUILDER" --out "$OUT8" --version t --pins "$WORK/modstack.md" \
       --cache "$CACHE" --lock "$LOCK" > "$WORK/out" 2>&1 \
   && ! ls "$OUT8"/lembitu-client-pack-t.zip "$OUT8"/lembitu-client-pack-t.manifest.json \
        "$OUT8"/lembitu-client-pack-t.versions.txt >/dev/null 2>&1; then
  report ok "publishes no artifact at all when the build fails part-way"
else
  report fail "publishes no artifact at all when the build fails part-way"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
