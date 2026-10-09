#!/usr/bin/env bash
# Behaviour tests for scripts/install-client-pack.sh: a clean swap of the Pack in a game folder,
# with game files untouched, the old Pack kept as a backup, --without, and the refusals that must
# happen before anything moves.
#
#   test/install-client-pack.test.sh
#
# Everything happens in throwaway directories, from a local archive (--zip); nothing is downloaded.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$REPO_ROOT/scripts/install-client-pack.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0 fail=0

report() {
  printf '%s: %s\n' "$([ "$1" = ok ] && echo pass || echo FAIL)" "$2"
  [ "$1" = ok ] && pass=$((pass + 1)) || fail=$((fail + 1))
}

assert_eq() {
  if [[ "$1" == "$2" ]]; then return 0; fi
  printf '  want: %s\n  got:  %s\n' "$1" "$2" >&2
  return 1
}

tree_of() { (cd "$1" && find . -mindepth 1 | sed 's|^\./||' | LC_ALL=C sort); }

with_parents() {  # every path and each of its parent directories, sorted
  local p
  for p in "$@"; do
    while [[ "$p" != . ]]; do printf '%s\n' "$p"; p="$(dirname "$p")"; done
  done | LC_ALL=C sort -u
}

sha_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# A Pack shaped like scripts/build-client-pack.sh's output: archive plus inventory beside it.
PACK_FILES=(.doorstop_version doorstop_config.ini winhttp.dll start_game_bepinex.sh
  valheim_Data/start_game_bepinex.sh doorstop_libs/libdoorstop.so
  BepInEx/core/BepInEx.dll BepInEx/config/seed.cfg
  BepInEx/plugins/Jotunn/Jotunn.dll BepInEx/plugins/Fancy/Fancy.dll BepInEx/plugins/Fancy/assets/a.bin)

make_pack() {  # make_pack <name>
  local src="$WORK/src" path
  rm -rf "$src" && mkdir -p "$src" "$WORK/pack"
  for path in "${PACK_FILES[@]}"; do
    mkdir -p "$src/$(dirname "$path")"
    printf 'new %s\n' "$path" > "$src/$path"
  done
  chmod +x "$src/start_game_bepinex.sh" "$src/valheim_Data/start_game_bepinex.sh"
  rm -f "$WORK/pack/$1.zip"
  (cd "$src" && zip -qr "$WORK/pack/$1.zip" .)
  (cd "$src" && for path in "${PACK_FILES[@]}"; do printf '%s  %s\n' "$(sha_of "$path")" "$path"; done) \
    > "$WORK/pack/$1.versions.txt"
}

fresh_game() {
  rm -rf "$WORK/game" "$WORK/backups" "$WORK/cache"
  mkdir -p "$WORK/game/valheim_Data" "$WORK/game/BepInEx/plugins/Stale" "$WORK/game/BepInEx/config"
  printf 'game\n' > "$WORK/game/valheim.x86_64"
  printf 'data\n' > "$WORK/game/valheim_Data/globalgamemanagers"
  printf 'old\n' > "$WORK/game/BepInEx/plugins/Stale/Stale.dll"
  printf 'my keys\n' > "$WORK/game/BepInEx/config/player.cfg"
  printf 'old\n' > "$WORK/game/doorstop_config.ini"
}

run() {
  LEMBITU_PACK_CACHE="$WORK/cache" LEMBITU_PACK_BACKUPS="$WORK/backups" \
    LEMBITU_NATIVE_LOCK="$WORK/native.lock" \
    "$INSTALLER" --game-dir "$WORK/game" --zip "$WORK/pack/t.zip" "$@" >"$WORK/out" 2>&1
}

make_pack t

# --- 1. the swap ------------------------------------------------------------------------------------

fresh_game
if run \
  && assert_eq "$(with_parents "${PACK_FILES[@]}" valheim.x86_64 valheim_Data/globalgamemanagers)" \
      "$(tree_of "$WORK/game")" \
  && assert_eq "new BepInEx/config/seed.cfg" "$(cat "$WORK/game/BepInEx/config/seed.cfg")" \
  && [[ -x "$WORK/game/start_game_bepinex.sh" && -x "$WORK/game/valheim_Data/start_game_bepinex.sh" ]] \
  && assert_eq "my keys" "$(cat "$WORK/backups"/game-*/BepInEx/config/player.cfg)" \
  && [[ -f "$(echo "$WORK/backups"/game-*/BepInEx/plugins/Stale/Stale.dll)" ]] \
  && assert_eq "old" "$(cat "$WORK/backups"/game-*/doorstop_config.ini)"; then
  report ok "the old Pack leaves whole for a backup, the new one is installed exactly, game files stay"
else
  cat "$WORK/out" >&2
  report fail "the old Pack leaves whole for a backup, the new one is installed exactly, game files stay"
fi

# --- 2. --without ------------------------------------------------------------------------------------

fresh_game
if run --without Fancy \
  && [[ ! -e "$WORK/game/BepInEx/plugins/Fancy" && -f "$WORK/game/BepInEx/plugins/Jotunn/Jotunn.dll" ]] \
  && grep -q 'left out: Fancy' "$WORK/out"; then
  report ok "--without leaves one plugin directory out and still verifies everything else"
else
  cat "$WORK/out" >&2
  report fail "--without leaves one plugin directory out and still verifies everything else"
fi

# --- 3-4. refusals before anything moves -----------------------------------------------------------

fresh_game
before="$(tree_of "$WORK/game")"
if ! run --without Fanc \
  && grep -q 'has no BepInEx/plugins/Fanc/' "$WORK/out" \
  && assert_eq "$before" "$(tree_of "$WORK/game")" && [[ ! -d "$WORK/backups" ]]; then
  report ok "a --without name the Pack does not ship is refused and nothing moves"
else
  cat "$WORK/out" >&2
  report fail "a --without name the Pack does not ship is refused and nothing moves"
fi

cp "$WORK/pack/t.versions.txt" "$WORK/pack/t.versions.good"
sed 's/^[0-9a-f]\{64\}  BepInEx\/core\/BepInEx.dll$/0000000000000000000000000000000000000000000000000000000000000000  BepInEx\/core\/BepInEx.dll/' \
  "$WORK/pack/t.versions.good" > "$WORK/pack/t.versions.txt"
fresh_game
before="$(tree_of "$WORK/game")"
if ! run && grep -q 'fails its inventory; nothing was changed' "$WORK/out" \
  && assert_eq "$before" "$(tree_of "$WORK/game")" && [[ ! -d "$WORK/backups" ]]; then
  report ok "an archive whose files do not match its inventory is refused and nothing moves"
else
  cat "$WORK/out" >&2
  report fail "an archive whose files do not match its inventory is refused and nothing moves"
fi
mv "$WORK/pack/t.versions.good" "$WORK/pack/t.versions.txt"

# --- 5. backups are pruned to --keep-backups ------------------------------------------------------

fresh_game
if run --keep-backups 2 && run --keep-backups 2 && run --keep-backups 2 \
  && assert_eq 2 "$(find "$WORK/backups" -mindepth 1 -maxdepth 1 -name 'game-*' | wc -l | tr -d ' ')"; then
  report ok "only the newest --keep-backups backups are kept"
else
  cat "$WORK/out" >&2
  report fail "only the newest --keep-backups backups are kept"
fi

# --- 6. a native session's lock ---------------------------------------------------------------------

if command -v flock >/dev/null 2>&1; then
  fresh_game
  before="$(tree_of "$WORK/game")"
  exec 8>"$WORK/native.lock"
  flock 8
  if ! run && grep -q 'native test session holds' "$WORK/out" && assert_eq "$before" "$(tree_of "$WORK/game")"; then
    report ok "a held native-session lock refuses the install and nothing moves"
  else
    cat "$WORK/out" >&2
    report fail "a held native-session lock refuses the install and nothing moves"
  fi
  exec 8>&-
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
((fail == 0))
