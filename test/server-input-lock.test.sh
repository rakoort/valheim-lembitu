#!/usr/bin/env bash
# Behaviour tests for scripts/verify-server-inputs.sh: the offline check that the live server's
# locked inputs (#112) are the bytes in hand.
#
# The fixtures are compact stand-ins, never the game: a three-file "server", a "BepInExPack" zip
# and two "mods". The case that matters most is #112's own: a DLL whose bytes changed while its
# name and size stayed the same must be refused, with the component named. Every other case is a
# way the lock and its sources could drift apart unnoticed.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERIFIER="$REPO_ROOT/scripts/verify-server-inputs.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0 fail=0

report() {
  printf '%s: %s\n' "$([ "$1" = ok ] && echo pass || echo FAIL)" "$2"
  [ "$1" = ok ] && pass=$((pass + 1)) || fail=$((fail + 1))
}

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1
  else shasum -a 256 "$1" | cut -d' ' -f1
  fi
}

# Flip one bit of one byte in place: same name, same size, different bytes.
flip_byte() {  # flip_byte <file> <offset>
  local byte
  byte="$(od -An -tu1 -j "$2" -N1 "$1" | tr -d ' ')"
  printf "$(printf '\\%03o' $(( byte ^ 1 )))" \
    | dd of="$1" bs=1 seek="$2" count=1 conv=notrunc status=none
}

F="$WORK/fixture"

# The tree every case starts from: inputs, and a lock and sources that agree with them.
reset_fixture() {
  rm -rf "$F"
  mkdir -p "$F/server/valheim_server_Data/Managed" "$F/mods" "$F/docs" "$F/scripts"
  printf 'ELF stand-in\n' > "$F/server/valheim_server.x86_64"
  head -c 4096 /dev/zero | tr '\0' 'v' > "$F/server/valheim_server_Data/Managed/assembly_valheim.dll"
  printf 'a manual\n' > "$F/server/Valheim Dedicated Server Manual.pdf"
  (cd "$F/server" && for rel in "Valheim Dedicated Server Manual.pdf" valheim_server.x86_64 \
     valheim_server_Data/Managed/assembly_valheim.dll; do
     printf '%s  %s\n' "$(sha256 "$rel")" "$rel"
   done) > "$F/docs/server-files.sha256"

  printf 'loader stand-in\n' > "$F/pack.zip"
  printf 'mod one\n' > "$F/mods/Alice-One-1.0.0.zip"
  printf 'mod two\n' > "$F/mods/Bob-Two-2.1.0.zip"
  local one two pack
  one="$(sha256 "$F/mods/Alice-One-1.0.0.zip")"
  two="$(sha256 "$F/mods/Bob-Two-2.1.0.zip")"
  pack="$(sha256 "$F/pack.zip")"

  cat > "$F/docs/modstack.lock.json" <<EOF
{
  "Alice/One@1.0.0": "$one",
  "Bob/Two@2.1.0": "$two"
}
EOF
  cat > "$F/docs/modstack.md" <<'EOF'
## Adopted upstream

| Mod | Version |
| --- | --- |
| Alice/One | 1.0.0 |
| Bob/Two | 2.1.0 |

### Download sources

| Mod | Download URL |
| --- | --- |
| Bob/Two | https://cdn.example/upload/7/2.1.0.zip |
EOF
  cat > "$F/scripts/extract-refs.sh" <<EOF
BEPINEX_PACK_VERSION="5.4.2351"
BEPINEX_PACK_SHA256="$pack"
EOF
  cat > "$F/docs/server-inputs.lock.json" <<EOF
{
  "server": { "app": 896660, "depot": 896661, "manifest": "1", "build": 1,
              "narHash": "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=", "files": "docs/server-files.sha256" },
  "bepinexPack": { "package": "denikson/BepInExPack_Valheim", "version": "5.4.2351",
                   "url": "https://thunderstore.io/package/download/denikson/BepInExPack_Valheim/5.4.2351/",
                   "sha256": "$pack" },
  "mods": {
    "Alice/One@1.0.0": { "url": "https://thunderstore.io/package/download/Alice/One/1.0.0/", "sha256": "$one" },
    "Bob/Two@2.1.0": { "url": "https://cdn.example/upload/7/2.1.0.zip", "sha256": "$two" }
  }
}
EOF
}

# Edit the fixture lock with a jq filter.
edit_lock() {  # edit_lock <jq-filter>
  jq "$1" "$F/docs/server-inputs.lock.json" > "$F/lock.tmp"
  mv "$F/lock.tmp" "$F/docs/server-inputs.lock.json"
}

run_verify() {
  "$VERIFIER" --lock "$F/docs/server-inputs.lock.json" --files "$F/docs/server-files.sha256" \
    --modstack-lock "$F/docs/modstack.lock.json" --modstack "$F/docs/modstack.md" \
    --extract-refs "$F/scripts/extract-refs.sh" \
    --server "$F/server" --bepinex "$F/pack.zip" --mods "$F/mods" > "$WORK/out" 2>&1
}

# Refused with exit 1 (not a usage error) and the expected line in the output.
refused_with() {  # refused_with <fixed-string>
  local rc=0
  run_verify || rc=$?
  [[ $rc -eq 1 ]] && grep -qF -- "$1" "$WORK/out"
}

check() {  # check <description> <command...>
  local what=$1; shift
  if "$@"; then report ok "$what"; else report fail "$what"; sed 's/^/    /' "$WORK/out"; fi
}

# --- 1. the committed lock agrees with the repository ------------------------------------------

committed() { "$VERIFIER" > "$WORK/out" 2>&1 && grep -q '^lock agrees: 72 mods' "$WORK/out"; }
check "the committed lock agrees with docs/modstack.lock.json, modstack.md and extract-refs.sh" committed

# --- 2. locked bytes pass ------------------------------------------------------------------------

reset_fixture
accepted() { run_verify && grep -q '^server verified: 3 files' "$WORK/out" \
  && grep -q '^loader verified' "$WORK/out" && grep -q '^mods verified: 2 zips' "$WORK/out"; }
check "inputs that match the lock pass, and it says what it checked" accepted

# --- 3. #112's case: a changed byte under an unchanged name -------------------------------------

reset_fixture
flip_byte "$F/server/valheim_server_Data/Managed/assembly_valheim.dll" 2048
check "a server DLL with one changed byte is refused, naming the server and the file" \
  refused_with "refused: server: valheim_server_Data/Managed/assembly_valheim.dll changed"

reset_fixture
flip_byte "$F/pack.zip" 3
check "a BepInExPack with one changed byte is refused, naming the loader" \
  refused_with "refused: loader: BepInExPack 5.4.2351"

reset_fixture
flip_byte "$F/mods/Bob-Two-2.1.0.zip" 0
check "a mod zip with one changed byte is refused, naming the mod" \
  refused_with "refused: mod: Bob/Two@2.1.0 (Bob-Two-2.1.0.zip) changed"

# --- 4. files that come or go -------------------------------------------------------------------

reset_fixture
rm "$F/server/valheim_server.x86_64"
check "a missing server file is refused" refused_with "refused: server: valheim_server.x86_64 is missing"

reset_fixture
printf 'extra\n' > "$F/server/valheim_server_Data/Managed/Extra.dll"
check "a server file the list lacks is refused" \
  refused_with "refused: server: valheim_server_Data/Managed/Extra.dll is not in server-files.sha256"

reset_fixture
rm "$F/mods/Alice-One-1.0.0.zip"
check "a missing mod zip is refused" refused_with "refused: mod: Alice/One@1.0.0 (Alice-One-1.0.0.zip) is missing"

reset_fixture
printf 'stray\n' > "$F/mods/Eve-Three-3.0.0.zip"
check "a mod zip the lock does not name is refused" refused_with "refused: mod: Eve-Three-3.0.0.zip is not a locked mod"

# --- 4b. symlinks and other non-files -------------------------------------------------------------
# The depot ships regular files only. A symlink's bytes are its target's, which can sit outside the
# tree and change after the check, so the server tree refuses every symlink, listed or not. The mods
# directory is the exception: Nix's linkFarm supplies each locked zip as a symlink, so a listed name
# is judged by the bytes it reaches, and anything unlisted is refused.

reset_fixture
printf 'payload\n' > "$F/outside.dll"
ln -s ../../../outside.dll "$F/server/valheim_server_Data/Managed/Extra.dll"
check "an unlisted symlink in the server tree is refused" \
  refused_with "refused: server: valheim_server_Data/Managed/Extra.dll is a symlink (-> ../../../outside.dll), not in server-files.sha256"

reset_fixture
ln -s /nonexistent "$F/server/dangling"
check "an unlisted dangling symlink in the server tree is refused" \
  refused_with "refused: server: dangling is a symlink (-> /nonexistent), not in server-files.sha256"

reset_fixture
mv "$F/server/valheim_server.x86_64" "$F/outside.x86_64"
ln -s ../outside.x86_64 "$F/server/valheim_server.x86_64"
check "a listed file replaced by a symlink to the same bytes is refused" \
  refused_with "refused: server: valheim_server.x86_64 is a symlink (-> ../outside.x86_64), not a file"

reset_fixture
mv "$F/server/valheim_server_Data" "$F/outside-data"
ln -s ../outside-data "$F/server/valheim_server_Data"
check "a directory replaced by a symlink to the same files is refused" \
  refused_with "refused: server: valheim_server_Data is a symlink (-> ../outside-data), not in server-files.sha256"

reset_fixture
mkfifo "$F/server/pipe"
check "a fifo in the server tree is refused" refused_with "refused: server: pipe is not a regular file"

reset_fixture
cp "$F/mods/Alice-One-1.0.0.zip" "$F/alice-copy.zip"
ln -s ../alice-copy.zip "$F/mods/Eve-Three-3.0.0.zip"
check "an unlisted symlink in the mods directory is refused" \
  refused_with "refused: mod: Eve-Three-3.0.0.zip is not a locked mod"

reset_fixture
mv "$F/mods/Alice-One-1.0.0.zip" "$F/alice-store.zip"
ln -s ../alice-store.zip "$F/mods/Alice-One-1.0.0.zip"
linked_mod() { run_verify && grep -q '^mods verified: 2 zips' "$WORK/out"; }
check "a listed mod supplied as a symlink to its locked bytes passes, as Nix's linkFarm supplies it" linked_mod

# --- 5. the lock drifting from its sources ------------------------------------------------------

reset_fixture
edit_lock 'del(.mods["Alice/One@1.0.0"])'
check "a pin missing from the lock is refused" \
  refused_with "refused: lock: Alice/One@1.0.0 is pinned in modstack.lock.json but missing from the lock"

reset_fixture
edit_lock '.mods["Carol/Four@4.0.0"] = {url: "https://thunderstore.io/package/download/Carol/Four/4.0.0/", sha256: .mods["Bob/Two@2.1.0"].sha256}'
check "a lock entry that is no pin is refused" \
  refused_with "refused: lock: Carol/Four@4.0.0 is not a pin in modstack.lock.json"

reset_fixture
edit_lock '.mods["Alice/One@1.0.0"].sha256 = .bepinexPack.sha256'
check "a mod sha256 that differs from modstack.lock.json is refused" \
  refused_with "refused: lock: Alice/One@1.0.0: sha256"

reset_fixture
edit_lock '.mods["Bob/Two@2.1.0"].url = "https://thunderstore.io/package/download/Bob/Two/2.1.0/"'
check "a mod URL that is not the one stage-stack.sh downloads is refused" \
  refused_with "refused: lock: Bob/Two@2.1.0: URL https://thunderstore.io/package/download/Bob/Two/2.1.0/, but scripts/stage-stack.sh downloads https://cdn.example/upload/7/2.1.0.zip"

reset_fixture
edit_lock '.bepinexPack.version = "5.4.2350"'
check "a BepInExPack version extract-refs.sh does not compile against is refused" \
  refused_with "refused: lock: BepInExPack 5.4.2350, but extract-refs.sh compiles against 5.4.2351"

reset_fixture
edit_lock '.bepinexPack.sha256 = .mods["Alice/One@1.0.0"].sha256'
check "a BepInExPack sha256 extract-refs.sh does not pin is refused" \
  refused_with "refused: lock: BepInExPack sha256"

reset_fixture
printf 'not a hash line\n' >> "$F/docs/server-files.sha256"
check "a malformed line in the server's file list is refused" \
  refused_with "refused: lock: server-files.sha256 line 4 is not"

# --- 6. every refusal is reported, not just the first -------------------------------------------

reset_fixture
flip_byte "$F/server/valheim_server.x86_64" 0
flip_byte "$F/mods/Alice-One-1.0.0.zip" 0
all_reported() { refused_with "2 refused" && grep -q '^refused: server:' "$WORK/out" \
  && grep -q '^refused: mod:' "$WORK/out"; }
check "two changed components are both reported" all_reported

# --- 7. a missing prerequisite is never a pass --------------------------------------------------

reset_fixture
missing_input() { local rc=0; "$VERIFIER" --lock "$F/docs/server-inputs.lock.json" \
  --server "$F/no-such-dir" > "$WORK/out" 2>&1 || rc=$?; [[ $rc -eq 2 ]]; }
check "a server directory that does not exist exits 2" missing_input

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
