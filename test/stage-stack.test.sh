#!/usr/bin/env bash
# Behaviour tests for scripts/stage-stack.sh: pin parsing from docs/modstack.md, the dist/ layout
# each package shape stages into, retire-on-unpin, hash verification against the lock file, and the
# dependency-closure check.
#
#   test/stage-stack.test.sh
#
# Everything happens in throwaway directories; the repo is only read. The staging tests build real
# zip files and pre-seed a fake download cache, so no network is touched. They need `zip`, which
# the dev shell provides; without it they are skipped with a notice rather than failed.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STAGER="$REPO_ROOT/scripts/stage-stack.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0 fail=0

report() {
  printf '%s: %s\n' "$([ "$1" = ok ] && echo pass || echo FAIL)" "$2"
  [ "$1" = ok ] && pass=$((pass + 1)) || fail=$((fail + 1))
}

# assert_eq <want> <got> <description>
assert_eq() {
  if [[ "$1" == "$2" ]]; then return 0; fi
  printf '  want: %s\n  got:  %s\n' "$1" "$2" >&2
  return 1
}

# expect_tree <dir> <path>...  — dir must contain exactly these paths, nothing else.
expect_tree() {
  local dir=$1; shift
  local want got
  want="$(printf '%s\n' "$@" | sort)"
  got="$(cd "$dir" && find . -mindepth 1 | sed 's|^\./||' | sort)"
  assert_eq "$want" "$got" "contents of $dir"
}

# expect_lines <file> <line>...  — file must contain exactly these lines.
expect_lines() {
  local file=$1; shift
  local want got
  want="$(printf '%s\n' "$@" | sort)"
  got="$(sort "$file")"
  assert_eq "$want" "$got" "contents of $file"
}

write_file() {  # write_file <file> <bytes>
  printf '%s' "$2" > "$1"
}

# replace <file> <from> <to> — bash-native so the strings may contain | and /.
replace() { local c; c="$(cat "$1")"; printf '%s\n' "${c//"$2"/"$3"}" > "$1"; }

# A modstack with every shape the parser has to tell apart: the adopted table itself (header,
# separator, padded cells), prose inside the section, and version-looking rows in other sections
# that must be ignored.
cat > "$WORK/modstack.md" <<'MD'
# The mod stack

Prose before any section, including a | pipe, must be ignored.

## Adopted upstream

| Mod | Pin | Role | Enforced config |
| --- | --- | --- | --- |
| acme/Alpha | 1.0.0 | role | — |
| acme/Beta_2 | 2.3.4-beta | role | — |

Between the table and the next section a bare `| acme/Ghost | 9.9.9 |` line is not a table row.

## Considered and cut

| acme/Rejected | 3.0.0 | a version-looking row outside the adopted section |

## Forks

| Fork | Forked from | Why |
MD

# --- 1. --list reads only the Adopted upstream table ------------------------------------------

got="$("$STAGER" --list --pins "$WORK/modstack.md")"
want="$(printf 'acme\tAlpha\t1.0.0\nacme\tBeta_2\t2.3.4-beta')"
if assert_eq "$want" "$got" "--list output"; then
  report ok "--list parses the adopted table and ignores every other section"
else
  report fail "--list parses the adopted table and ignores every other section"
fi

# --- 2. the real docs/modstack.md still parses as the whole stack ------------------------------

if assert_eq 28 "$("$STAGER" --list | wc -l | tr -d ' ')" "pin count" \
   && "$STAGER" --list | grep -qxF "$(printf 'sighsorry\tClan\t1.0.5')" \
   && "$STAGER" --list | grep -qxF "$(printf 'ValheimModding\tJotunn\t2.30.0')"; then
  report ok "docs/modstack.md parses to the 28 pinned packages"
else
  report fail "docs/modstack.md parses to the 28 pinned packages"
fi

# --- staging -----------------------------------------------------------------------------------

if ! command -v zip >/dev/null 2>&1; then
  echo "skip: staging tests need zip (nix develop provides it)"
  printf '\n%d passed, %d failed\n' "$pass" "$fail"
  [[ $fail -eq 0 ]]
  exit 0
fi

CACHE="$WORK/cache"
DIST="$WORK/dist"
LOCK="$WORK/lock.json"
mkdir -p "$CACHE" "$DIST"

run_stage() { "$STAGER" --pins "$WORK/modstack.md" --cache "$CACHE" --dist "$DIST" --lock "$LOCK" \
                > "$WORK/out" 2>&1; }

# new_tree — empty $WORK/pkg-src for building the next package. make_pkg does not wipe it: the
# caller writes the package tree first, so an accidental wipe inside make_pkg would zip nothing.
new_tree() { rm -rf "$WORK/pkg-src"; mkdir -p "$WORK/pkg-src"; }

# make_pkg <team> <mod> <version> — zips $WORK/pkg-src into the cache as <team>-<mod>-<version>.zip,
# adding a manifest.json whose dependencies are the lines of $WORK/pkg-deps.
make_pkg() {
  local team=$1 mod=$2 version=$3
  local src="$WORK/pkg-src" zip="$CACHE/$team-$mod-$version.zip"
  rm -f "$zip"
  ( cd "$src" && zip -q -r "$zip" . -x 'manifest.json' )
  {
    printf '{\n  "name": "%s",\n  "version_number": "%s",\n  "dependencies": [\n' "$mod" "$version"
    local first=1 dep
    while IFS= read -r dep; do
      [[ -n "$dep" ]] || continue
      [[ $first == 1 ]] && first=0 || printf ',\n'
      printf '    "%s"' "$dep"
    done < "$WORK/pkg-deps"
    printf '\n  ]\n}\n'
  } > "$src/manifest.json"
  ( cd "$src" && zip -q "$zip" manifest.json )
}

# --- 3. every package shape lands in its dist tree, metadata dropped ---------------------------

cat > "$WORK/modstack.md" <<'MD'
## Adopted upstream

| Mod | Pin |
| --- | --- |
| acme/Root | 1.0.0 |
| acme/BepInExTree | 1.1.0 |
MD
printf 'denikson-BepInExPack_Valheim-5.4.2350\n' > "$WORK/pkg-deps"
new_tree
write_file "$WORK/pkg-src/Root.dll" root-dll
write_file "$WORK/pkg-src/Root.English.yml" root-yml
write_file "$WORK/pkg-src/LICENSE.txt" licence
write_file "$WORK/pkg-src/README.md" readme
write_file "$WORK/pkg-src/CHANGELOG.md" changelog
 write_file "$WORK/pkg-src/icon.png" icon
mkdir -p "$WORK/pkg-src/patchers"   # Fast_AssetBundle_Loader ships patchers/ at the zip root
write_file "$WORK/pkg-src/patchers/RootPatch.dll" root-patch
 make_pkg acme Root 1.0.0

new_tree
mkdir -p "$WORK/pkg-src/BepInEx/plugins/BepInExTree" "$WORK/pkg-src/BepInEx/patchers" "$WORK/pkg-src/BepInEx/config/TreeAssets/emoji"
write_file "$WORK/pkg-src/BepInEx/plugins/BepInExTree/BepInExTree.dll" tree-dll
write_file "$WORK/pkg-src/BepInEx/patchers/Patcher.dll" patcher
write_file "$WORK/pkg-src/BepInEx/config/TreeAssets/emoji/dance.gif" emoji
make_pkg acme BepInExTree 1.1.0

mkdir -p "$DIST/plugins"
write_file "$DIST/plugins/Ours.dll" ours   # build output must survive staging untouched

if run_stage \
   && expect_tree "$DIST" \
      .staged-dirs \
      plugins \
      plugins/Ours.dll \
      plugins/Root \
      plugins/Root/LICENSE.txt \
      plugins/Root/Root.English.yml \
       plugins/Root/Root.dll \
      patchers/Root \
      patchers/Root/RootPatch.dll \
      plugins/BepInExTree \
      plugins/BepInExTree/BepInExTree \
      plugins/BepInExTree/BepInExTree/BepInExTree.dll \
      patchers \
      patchers/BepInExTree \
      patchers/BepInExTree/Patcher.dll \
      config \
      config/TreeAssets \
      config/TreeAssets/emoji \
      config/TreeAssets/emoji/dance.gif \
   && expect_lines "$DIST/.staged-dirs" \
       plugins/Root \
      patchers/Root \
      plugins/BepInExTree \
      patchers/BepInExTree \
      config/TreeAssets \
   && grep -q 'staged plugins/Root (3 files)' "$WORK/out" \
   && grep -q 'recorded 2 new hash(es)' "$WORK/out" \
   && [[ "$(cat "$DIST/plugins/Root/Root.dll")" == root-dll ]]; then
  report ok "root, plugins/, patchers/ and config/ shapes stage into per-package dist trees"
else
  report fail "root, plugins/, patchers/ and config/ shapes stage into per-package dist trees"
fi

# --- 4. a version bump leaves nothing from the older package behind ---------------------------

new_tree
mkdir -p "$WORK/pkg-src/sub"
write_file "$WORK/pkg-src/Root.dll" root-dll-v2
write_file "$WORK/pkg-src/sub/extra.yml" extra
make_pkg acme Root 2.0.0
replace "$WORK/modstack.md" 'acme/Root | 1.0.0' 'acme/Root | 2.0.0'

if run_stage \
   && expect_tree "$DIST/plugins/Root" \
      Root.dll \
      sub \
      sub/extra.yml \
   && [[ "$(cat "$DIST/plugins/Root/Root.dll")" == root-dll-v2 ]]; then
  report ok "restaging wipes the package directory first"
else
  report fail "restaging wipes the package directory first"
fi

# --- 5. retiring a pin removes its tree --------------------------------------------------------

grep -v 'acme/BepInExTree' "$WORK/modstack.md" > "$WORK/modstack.2" && mv "$WORK/modstack.2" "$WORK/modstack.md"

if run_stage \
   && [[ ! -e "$DIST/plugins/BepInExTree" && ! -e "$DIST/patchers/BepInExTree" && ! -e "$DIST/config/TreeAssets" ]] \
   && expect_lines "$DIST/.staged-dirs" plugins/Root \
   && grep -q 'retired plugins/BepInExTree' "$WORK/out" \
   && grep -q 'retired config/TreeAssets' "$WORK/out"; then
  report ok "a dropped pin retires its staged trees"
else
  report fail "a dropped pin retires its staged trees"
fi

# --- 6. the lock file: recorded once, verified after, tampering refused ------------------------

if grep -q '"acme/Root@2.0.0": "[0-9a-f]\{64\}"' "$LOCK" \
   && ! grep -q 'BepInExTree' "$LOCK"; then
  report ok "the lock mirrors the current pin set and drops retired pins"
else
  report fail "the lock mirrors the current pin set and drops retired pins"
fi

before="$(cat "$LOCK")"
if run_stage && grep -q 'verified 1 package hashes' "$WORK/out" && [[ "$(cat "$LOCK")" == "$before" ]]; then
  report ok "a recorded lock verifies matching zips and stays byte-identical"
else
  report fail "a recorded lock verifies matching zips and stays byte-identical"
fi

printf 'tampered bytes' >> "$CACHE/acme-Root-2.0.0.zip"
if ! run_stage && grep -q 'hash mismatch for acme/Root@2.0.0' "$WORK/out"; then
  report ok "a zip whose bytes moved under a pinned version is refused"
else
  report fail "a zip whose bytes moved under a pinned version is refused"
fi

# --- 7. dependency closure: unknown package refused, pin and override accepted -----------------

cat > "$WORK/modstack.md" <<'MD'
## Adopted upstream

| Mod | Pin |
| --- | --- |
| acme/Root | 2.0.0 |
| ValheimModding/Jotunn | 2.30.0 |
MD
new_tree
write_file "$WORK/pkg-src/Jotunn.dll" jotunn
printf 'ValheimModding-Jotunn-2.29.2\ndenikson-BepInExPack_Valheim-5.4.2333\nacme-Root-2.0.0\n' > "$WORK/pkg-deps"
make_pkg ValheimModding Jotunn 2.30.0

new_tree
write_file "$WORK/pkg-src/Root.dll" root
printf 'acme-Root-2.0.0\n' > "$WORK/pkg-deps"
make_pkg acme Root 2.0.0

rm -f "$LOCK"
if run_stage && grep -q 'staged 2 packages' "$WORK/out"; then
  report ok "pinned dependencies and documented overrides satisfy the closure"
else
  report fail "pinned dependencies and documented overrides satisfy the closure"
fi

printf 'weird-Team-Missing-1.0\n' > "$WORK/pkg-deps"
rm -f "$LOCK"   # same version, different bytes: the lock would refuse it before the closure check
make_pkg acme Root 2.0.0
if ! run_stage && grep -q 'declares weird-Team-Missing-1.0' "$WORK/out"; then
  report ok "a dependency outside the pin list and the overrides aborts staging"
else
  report fail "a dependency outside the pin list and the overrides aborts staging"
fi

printf 'acme-Root-2.0\n' > "$WORK/pkg-deps"   # a prefix of pin 2.0.0, not the pin
make_pkg acme Root 2.0.0
if ! run_stage && grep -q 'declares acme-Root-2.0,' "$WORK/out"; then
  report ok "a dependency version that is only a prefix of a pin is refused"
else
  report fail "a dependency version that is only a prefix of a pin is refused"
fi

# --- 8. unexpected package shapes abort before anything is staged ------------------------------

cat > "$WORK/modstack.md" <<'MD'
## Adopted upstream

| Mod | Pin |
| --- | --- |
| acme/Root | 2.0.0 |
MD
printf 'denikson-BepInExPack_Valheim-5.4.2350\n' > "$WORK/pkg-deps"
new_tree
mkdir -p "$WORK/pkg-src/BepInEx/core"
write_file "$WORK/pkg-src/BepInEx/core/evil.dll" evil
write_file "$WORK/pkg-src/Root.dll" root
make_pkg acme Root 2.0.0
rm -f "$LOCK"
rm -rf "$DIST"

if ! run_stage && grep -q 'unexpected package shape in Root 2.0.0: BepInEx/core/evil.dll' "$WORK/out" && [[ ! -e "$DIST/plugins" ]]; then
  report ok "an unexpected package shape aborts before staging anything"
else
  report fail "an unexpected package shape aborts before staging anything"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
