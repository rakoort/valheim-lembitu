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
# A pin table with the packages the asymmetry turns on: two client-side adopted packages the
# builder asserts are present - the handshake library and the container mod the server refuses a
# client for lacking - one further client-side package, and one server-only plugin that is NOT in
# the adopted table (MaxPlayerCount is a fork, so it is staged by the build rather than by the pin
# list). The test injects the server-only plugin into the staged tree the way a mistaken pack
# would, and checks the builder refuses it.

cat > "$WORK/modstack.md" <<'MD'
# The mod stack

## Adopted upstream

| Mod | Pin | Role | Enforced config |
| --- | --- | --- | --- |
| acme/Jotunn | 1.0.2 | Library the handshake requires | — |
| acme/Clan | 1.0.10 | Clans | — |
| acme/AzuCraftyBoxes | 1.8.19 | Container pulls; the server refuses a client without it | — |

## Forks

| Fork | Forked from | Why |
| --- | --- | --- |
| MaxPlayerCount | Azumatt | Player cap |
MD

CACHE="$WORK/cache"; mkdir -p "$CACHE"

# A BepInEx loader fixture. The builder copies the loader from lib/bepinex/pack/, which a clean
# checkout does not have (it is gitignored and reproduced by scripts/extract-refs.sh), so the tests
# point the builder at a fixture pack through the same variable the builder uses.
BEPINEX_PACK="$WORK/bepinex-pack/BepInExPack_Valheim"
mkdir -p "$BEPINEX_PACK/BepInEx/core" "$BEPINEX_PACK/doorstop_libs"
printf 'preloader\n' > "$BEPINEX_PACK/BepInEx/core/BepInEx.Preloader.dll"
printf 'bepinex\n'   > "$BEPINEX_PACK/BepInEx/core/BepInEx.dll"
printf 'harmony\n'   > "$BEPINEX_PACK/BepInEx/core/0Harmony.dll"
printf 'doorstop\n'  > "$BEPINEX_PACK/doorstop_config.ini"
printf 'winhttp\n'   > "$BEPINEX_PACK/winhttp.dll"
# The launcher fixture carries the one upstream line the builder rewrites: its architecture probe.
# A bare stub would make every build in this file die on the builder's precondition, which is
# exercised on its own below.
printf '%s\n' '#!/bin/sh' 'file_out="$(LD_PRELOAD="" file -b "${executable_path}")"' \
  'exec "$executable_path" "$@"' > "$BEPINEX_PACK/start_game_bepinex.sh"
printf 'so\n'        > "$BEPINEX_PACK/doorstop_libs/libdoorstop_x64.so"
printf 'dylib\n'     > "$BEPINEX_PACK/doorstop_libs/libdoorstop_x64.dylib"
mkdir -p "$BEPINEX_PACK/BepInEx/config"

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

make_zip "$CACHE/acme-Jotunn-1.0.2.zip" \
  'plugins/Jotunn.dll:Jotunn' \
  'manifest.json:{"name":"Jotunn","version_number":"1.0.2","dependencies":[]}'
make_zip "$CACHE/acme-Clan-1.0.10.zip" \
  'plugins/Clan.dll:Clan' \
  'BepInEx/config/Clan/emblem.png:emblem' \
  'manifest.json:{"name":"Clan","version_number":"1.0.10","dependencies":[]}'
make_zip "$CACHE/acme-AzuCraftyBoxes-1.8.19.zip" \
  'plugins/AzuCraftyBoxes.dll:AzuCraftyBoxes' \
  'manifest.json:{"name":"AzuCraftyBoxes","version_number":"1.8.19","dependencies":[]}'

LOCK="$WORK/lock.json"
{
  printf '{\n'
  printf '  "acme/Jotunn@1.0.2": "%s",\n' "$(shasum -a 256 "$CACHE/acme-Jotunn-1.0.2.zip" | cut -d' ' -f1)"
  printf '  "acme/Clan@1.0.10": "%s",\n'   "$(shasum -a 256 "$CACHE/acme-Clan-1.0.10.zip" | cut -d' ' -f1)"
  printf '  "acme/AzuCraftyBoxes@1.8.19": "%s"\n' "$(shasum -a 256 "$CACHE/acme-AzuCraftyBoxes-1.8.19.zip" | cut -d' ' -f1)"
  printf '}\n'
} > "$LOCK"

build() {  # build <out> [extra args...]
  local out=$1; shift
  BEPINEX_PACK="$BEPINEX_PACK" \
  "$BUILDER" --out "$out" --version t --pins "$WORK/modstack.md" --cache "$CACHE" --lock "$LOCK" "$@" \
    > "$WORK/out" 2>&1
}

# --- 1. the client-side adopted package is staged, with its config seed ------------------------

OUT1="$WORK/out1"
if build "$OUT1"; then
  archive="$OUT1/lembitu-client-pack-t.zip"
  listing="$(unzip -Z1 "$archive")"
  if grep -qx 'BepInEx/plugins/Jotunn/Jotunn.dll' <<<"$listing" \
     && grep -qx 'BepInEx/plugins/Clan/Clan.dll' <<<"$listing" \
     && grep -qx 'BepInEx/config/Clan/emblem.png' <<<"$listing"; then
    report ok "stages the client-side packages and their config seeds"
  else
    report fail "stages the client-side packages and their config seeds"
  fi
else
  report fail "stages the client-side packages and their config seeds"
fi

# --- 1b. our own client seeds ship, and beat a package's copy ----------------------------------
# The rarity palette and the HUD colours are "Not Synced with Server", so the Pack is the only
# place they can be set. A seed that does not reach BepInEx/config, or that a package's own file
# overwrites, is a decision that silently did not happen.

SEEDS="$WORK/client-seeds"
mkdir -p "$SEEDS/Clan"
printf 'ours\n' > "$SEEDS/Clan/emblem.png"
printf '[7 - Item Colors]\nMagic Rarity Color = #8a9ba8\n' > "$SEEDS/randyknapp.mods.epicloot.cfg"

OUTS="$WORK/out-seeds"
if CLIENT_SEEDS="$SEEDS" build "$OUTS"; then
  seeded="$WORK/seeded"; rm -rf "$seeded"; mkdir -p "$seeded"
  unzip -qo "$OUTS/lembitu-client-pack-t.zip" -d "$seeded"
  if grep -q 'Magic Rarity Color = #8a9ba8' "$seeded/BepInEx/config/randyknapp.mods.epicloot.cfg" \
     && [[ "$(cat "$seeded/BepInEx/config/Clan/emblem.png")" == "ours" ]]; then
    report ok "a repository config seed ships and overrides the package's own copy"
  else
    report fail "a repository config seed ships and overrides the package's own copy"
  fi
else
  report fail "a repository config seed ships and overrides the package's own copy"
fi

# A seed the build fails to place is a silent loss, so the builder asserts each one landed rather
# than trusting the copy. Point it at a seed directory it cannot read to prove the assertion runs.
if CLIENT_SEEDS="$WORK/no-such-seeds" build "$WORK/out-noseed"; then
  listing="$(unzip -Z1 "$WORK/out-noseed/lembitu-client-pack-t.zip")"
  if ! grep -q 'randyknapp' <<<"$listing"; then
    report ok "an absent seed directory is not an error, and seeds nothing"
  else
    report fail "an absent seed directory is not an error, and seeds nothing"
  fi
else
  report fail "an absent seed directory is not an error, and seeds nothing"
fi

# --- 1c. mods are nested under BepInEx, not at the game root ----------------------------------
# The second half of the same defect: a `plugins/` directory at the game root extracts cleanly,
# contains every mod, and loads nothing at all, because the loader only reads BepInEx/plugins/.
if build "$OUT1"; then
  listing="$(unzip -Z1 "$OUT1/lembitu-client-pack-t.zip")"
  if ! grep -qE '^(plugins|patchers|config)/' <<<"$listing" \
     && grep -qE '^BepInEx/plugins/' <<<"$listing"; then
    report ok "nests the mods under BepInEx/ instead of the game root"
  else
    report fail "nests the mods under BepInEx/ instead of the game root"
  fi
else
  report fail "nests the mods under BepInEx/ instead of the game root"
fi

# --- 1b. the archive is a complete, runnable install ------------------------------------------
# The defect this guards: a zip of mods with no BepInEx loader. It extracts cleanly, contains every
# mod, and produces a vanilla client — which this server refuses at the handshake. Every required
# piece is asserted, including a doorstop library per platform, because shipping one platform's
# library silently breaks the others.

if build "$OUT1"; then
  listing="$(unzip -Z1 "$OUT1/lembitu-client-pack-t.zip")"
  missing=""
  for f in BepInEx/core/BepInEx.Preloader.dll BepInEx/core/BepInEx.dll BepInEx/core/0Harmony.dll \
           doorstop_config.ini winhttp.dll doorstop_libs/libdoorstop_x64.so \
           doorstop_libs/libdoorstop_x64.dylib; do
    grep -qx "$f" <<<"$listing" || missing="$missing $f"
  done
  if [ -z "$missing" ]; then
    report ok "ships the BepInEx loader so the archive is a complete install"
  else
    report fail "ships the BepInEx loader so the archive is a complete install (missing:$missing)"
  fi
else
  report fail "ships the BepInEx loader so the archive is a complete install"
fi

# --- 2. the manifest is valid JSON naming the exclusions and the pins -------------------------

manifest="$OUT1/lembitu-client-pack-t.manifest.json"
if json_looks_valid "$manifest"; then
  excluded="$(json_value "$manifest" excluded_server_only)"
  pins="$(pin_count "$manifest")"
  if [[ "$excluded" == *MaxPlayerCount* ]] && [ "$pins" -eq 3 ]; then
    report ok "manifest is valid JSON naming the server-only exclusions and the pin hashes"
  else
    report fail "manifest is valid JSON naming the server-only exclusions and the pin hashes"
  fi
else
  report fail "manifest is valid JSON naming the server-only exclusions and the pin hashes"
fi

# --- 3. the file inventory lists what a player installs, and nothing else --------------------

versions="$OUT1/lembitu-client-pack-t.versions.txt"
if grep -q 'BepInEx/plugins/Jotunn/Jotunn.dll' "$versions" && ! grep -q 'staged-dirs' "$versions"; then
  report ok "writes a per-file inventory with hashes and no builder bookkeeping"
else
  report fail "writes a per-file inventory with hashes and no builder bookkeeping"
fi

# The inventory is what a player runs `sha256sum -c` against, so it must name exactly the files the
# archive installs. It listed the builder's staging log once, and a byte-correct install then
# reported a failure - the false alarm the inventory exists to rule out.
inv_paths="$(cut -c67- "$versions" | LC_ALL=C sort)"
zip_paths="$(unzip -Z1 "$OUT1/lembitu-client-pack-t.zip" | grep -v '/$' | LC_ALL=C sort)"
if [ "$inv_paths" = "$zip_paths" ]; then
  report ok "the inventory names exactly the files the archive installs"
else
  report fail "the inventory names exactly the files the archive installs"
fi

# The Linux Steam path. Steam resolves the launch option `./start_game_bepinex.sh %command%`
# against valheim_Data, so the shim shipped there must hand off to the root launcher with `$0`
# pointing at the game root: the launcher derives BepInEx/, doorstop_libs/ and every plugin path
# from it, and a handoff that kept valheim_Data would look for all of them one level too deep.
# Checked against a stub root launcher that reports the base it computed and the arguments it got.
game="$WORK/game"
mkdir -p "$game"
unzip -qo "$OUT1/lembitu-client-pack-t.zip" -d "$game"
cat > "$game/start_game_bepinex.sh" <<'STUB'
#!/bin/sh
a="/$0"; a=${a%/*}; a=${a#/}; a=${a:-.}
printf 'basedir=%s args=%s\n' "$(cd "$a" && pwd -P)" "$*"
STUB
chmod +x "$game/start_game_bepinex.sh" "$game/valheim_Data/start_game_bepinex.sh"
handoff="$(cd / && "$game/valheim_Data/start_game_bepinex.sh" SteamLaunch -- valheim.x86_64)"
if [ "$handoff" = "basedir=$(cd "$game" && pwd -P) args=SteamLaunch -- valheim.x86_64" ]; then
  report ok "the Steam shim runs the root launcher with the game root as its base"
else
  report fail "the Steam shim runs the root launcher with the game root as its base (got: $handoff)"
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
| acme/Jotunn | 1.0.2 | Library | — |
| acme/MaxPlayerCount | 1.2.5 | Player cap (server-only) | — |
MD

make_zip "$CACHE/acme-MaxPlayerCount-1.2.5.zip" \
  'plugins/MaxPlayerCount.dll:MaxPlayerCount' \
  'manifest.json:{"name":"MaxPlayerCount","version_number":"1.2.5","dependencies":[]}'
{
  printf '{\n'
  printf '  "acme/Jotunn@1.0.2": "%s",\n' "$(shasum -a 256 "$CACHE/acme-Jotunn-1.0.2.zip" | cut -d' ' -f1)"
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

# --- 5b. an upstream launcher without the arch probe is refused -------------------------------
# The build rewrites one line of upstream's launcher: the `file(1)` probe that aborts on hosts
# without that binary, NixOS among them. If a newer BepInEx pack changes that line, the rewrite
# would silently do nothing and the pack would ship a launcher that cannot start the game on those
# hosts. The builder must stop instead.

printf '%s\n' '#!/bin/sh' 'arch=x64' > "$BEPINEX_PACK/start_game_bepinex.sh"
if ! build "$WORK/out7b" && grep -q "no longer contains the .file. probe" "$WORK/out" \
   && [ ! -e "$WORK/out7b/lembitu-client-pack-t.zip" ]; then
  report ok "refuses an upstream launcher whose architecture probe it can no longer patch"
else
  report fail "refuses an upstream launcher whose architecture probe it can no longer patch"
fi
printf '%s\n' '#!/bin/sh' 'file_out="$(LD_PRELOAD="" file -b "${executable_path}")"' \
  'exec "$executable_path" "$@"' > "$BEPINEX_PACK/start_game_bepinex.sh"

# --- 6. a tampered package is refused by the stager's hash check ------------------------------

printf 'tampered\n' > "$CACHE/acme-Jotunn-1.0.2.zip"
if ! build "$WORK/out6" && grep -qi "hash mismatch" "$WORK/out"; then
  report ok "refuses a package whose bytes do not match the lock"
else
  report fail "refuses a package whose bytes do not match the lock"
fi
make_zip "$CACHE/acme-Jotunn-1.0.2.zip" \
  'Jotunn/Jotunn.dll:Jotunn' \
  'Jotunn/manifest.json:{"name":"Jotunn","version_number":"1.0.2","dependencies":[]}'

# --- 7. --list prints the client pin list without downloading or writing ----------------------

if [[ -x "$STAGER" ]]; then
  listed="$("$BUILDER" --list --pins "$WORK/modstack.md" 2>/dev/null)"
  if grep -q 'Jotunn' <<<"$listed" && grep -q 'Clan' <<<"$listed"; then
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
