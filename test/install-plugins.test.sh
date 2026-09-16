#!/usr/bin/env bash
# Behaviour tests for scripts/install-plugins.sh: deployment of the three dist/ BepInEx trees,
# pruning of what the manifest owns (and nothing else), migration of plugins/-era manifests, and
# the container-side replay of .lembitu-removed.
#
#   test/install-plugins.test.sh
#
# Everything happens in throwaway directories; the repo is only read. The prune-mirror tests run the
# installer against a fake `docker` shim so no container is needed.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$REPO_ROOT/scripts/install-plugins.sh"

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

fresh_dist() {
  rm -rf "$WORK/dist" "$WORK/bepinex"
  mkdir -p "$WORK/dist/plugins" "$WORK/bepinex"
}

write_file() {  # write_file <file> <bytes>
  printf '%s' "$2" > "$1"
}

run_install() { "$INSTALLER" --dist "$WORK/dist" "$WORK/bepinex" >"$WORK/out" 2>&1; }

# --- 1. fresh install: top-level DLLs and a whole tree, layout preserved ---------------------

fresh_dist
# One of our built DLLs at the plugins root, and a whole adopted package tree beside it: the shape
# ValheimRAFT actually stages, a DLL with an asset directory nested below it.
write_file "$WORK/dist/plugins/MaxPlayerCount.dll" dll
mkdir -p "$WORK/dist/plugins/ValheimRAFT/Assets/Sails/Patterns"
write_file "$WORK/dist/plugins/ValheimRAFT/ValheimRAFT.dll" dll
write_file "$WORK/dist/plugins/ValheimRAFT/ValheimVehicles.dll" dll
write_file "$WORK/dist/plugins/ValheimRAFT/Assets/Sails/sail.png" sail
write_file "$WORK/dist/plugins/ValheimRAFT/Assets/Sails/Patterns/stripe.png" pattern

if run_install \
   && expect_tree "$WORK/bepinex" \
      .lembitu-installed \
      plugins \
      plugins/MaxPlayerCount.dll \
      plugins/ValheimRAFT \
      plugins/ValheimRAFT/Assets \
      plugins/ValheimRAFT/Assets/Sails \
      plugins/ValheimRAFT/Assets/Sails/Patterns \
      plugins/ValheimRAFT/Assets/Sails/Patterns/stripe.png \
      plugins/ValheimRAFT/Assets/Sails/sail.png \
      plugins/ValheimRAFT/ValheimRAFT.dll \
      plugins/ValheimRAFT/ValheimVehicles.dll \
   && expect_lines "$WORK/bepinex/.lembitu-installed" \
      plugins/MaxPlayerCount.dll \
      plugins/ValheimRAFT/ValheimRAFT.dll \
      plugins/ValheimRAFT/ValheimVehicles.dll \
      plugins/ValheimRAFT/Assets/Sails/sail.png \
      plugins/ValheimRAFT/Assets/Sails/Patterns/stripe.png \
   && grep -q '^installed plugins/ValheimRAFT/ (4 files)$' "$WORK/out" \
   && grep -q '^installed plugins/MaxPlayerCount.dll$' "$WORK/out" \
   && [[ ! -e "$WORK/bepinex/.lembitu-removed" ]]; then
  report ok "fresh install deploys DLLs and trees, manifest lists every file"
else
  report fail "fresh install deploys DLLs and trees, manifest lists every file"
fi

# --- 2. prune: stale DLL and stale tree removed, directories cleaned up ----------------------

write_file "$WORK/dist/plugins/Replacement.dll" rep
rm "$WORK/dist/plugins/MaxPlayerCount.dll"
rm -rf "$WORK/dist/plugins/ValheimRAFT"

if run_install \
   && expect_tree "$WORK/bepinex" \
      .lembitu-installed .lembitu-removed plugins plugins/Replacement.dll \
   && expect_lines "$WORK/bepinex/.lembitu-installed" plugins/Replacement.dll \
   && expect_lines "$WORK/bepinex/.lembitu-removed" \
      plugins/MaxPlayerCount.dll \
      plugins/ValheimRAFT/ValheimRAFT.dll \
      plugins/ValheimRAFT/ValheimVehicles.dll \
      plugins/ValheimRAFT/Assets/Sails/sail.png \
      plugins/ValheimRAFT/Assets/Sails/Patterns/stripe.png \
   && grep -q '^removed stale plugins/ValheimRAFT/ (4 files)$' "$WORK/out"; then
  report ok "prune removes stale DLL and tree, ledger records them"
else
  report fail "prune removes stale DLL and tree, ledger records them"
fi

# --- 3. foreign files are never touched, even inside a tree we own ---------------------------

fresh_dist
mkdir -p "$WORK/dist/plugins/Tree"
write_file "$WORK/dist/plugins/Keeper.dll" k
write_file "$WORK/dist/plugins/Tree/ours.dll" o
mkdir -p "$WORK/bepinex/plugins/Tree/Bundles" "$WORK/bepinex/plugins/foreign-dir"
write_file "$WORK/bepinex/plugins/foreign-top.dll" f
write_file "$WORK/bepinex/plugins/Tree/foreign.dll" f
write_file "$WORK/bepinex/plugins/Tree/Bundles/foreign.bundle" f
write_file "$WORK/bepinex/plugins/foreign-dir/foreign.dll" f
run_install  # installs plugins/Tree/ours.dll
rm -rf "$WORK/dist/plugins/Tree"
run_install

if expect_tree "$WORK/bepinex" \
      .lembitu-installed \
      .lembitu-removed \
      plugins \
      plugins/Keeper.dll \
      plugins/foreign-top.dll \
      plugins/foreign-dir \
      plugins/foreign-dir/foreign.dll \
      plugins/Tree \
      plugins/Tree/Bundles \
      plugins/Tree/Bundles/foreign.bundle \
      plugins/Tree/foreign.dll; then
  report ok "prune leaves every foreign file and its directory alone"
else
  report fail "prune leaves every foreign file and its directory alone"
fi

# --- 4. a plugins/-era manifest is migrated, its files stay prunable --------------------------

fresh_dist
write_file "$WORK/dist/plugins/Current.dll" c
mkdir -p "$WORK/bepinex/plugins/Bundles"
write_file "$WORK/bepinex/plugins/Old.dll" o
write_file "$WORK/bepinex/plugins/Bundles/old.bundle" old
printf 'Old.dll\nBundles/old.bundle\n' > "$WORK/bepinex/plugins/.lembitu-installed"

if run_install \
   && expect_tree "$WORK/bepinex" \
      .lembitu-installed .lembitu-removed plugins plugins/Current.dll \
   && expect_lines "$WORK/bepinex/.lembitu-installed" plugins/Current.dll \
   && expect_lines "$WORK/bepinex/.lembitu-removed" plugins/Old.dll plugins/Bundles/old.bundle \
   && grep -q 'migrated the installer manifest' "$WORK/out"; then
  report ok "an old plugins/ manifest is migrated with the prefix and still prunes"
else
  report fail "an old plugins/ manifest is migrated with the prefix and still prunes"
fi

# --- 5. nothing stale: no ledger is created --------------------------------------------------

fresh_dist
write_file "$WORK/dist/plugins/Stable.dll" s
run_install
rm -f "$WORK/bepinex/.lembitu-removed"
run_install

if [[ ! -e "$WORK/bepinex/.lembitu-removed" ]]; then
  report ok "a no-op run writes no ledger"
else
  report fail "a no-op run writes no ledger"
fi

# --- 6. an updated file is recopied (contents, not just presence) ----------------------------

fresh_dist
write_file "$WORK/dist/plugins/Stable.dll" v1
run_install
write_file "$WORK/dist/plugins/Stable.dll" v2
run_install
if [[ "$(cat "$WORK/bepinex/plugins/Stable.dll")" == v2 ]]; then
  report ok "an updated file is recopied"
else
  report fail "an updated file is recopied"
fi

# --- 7. patchers/ and config/ deploy beside plugins/ and prune with them ---------------------

fresh_dist
# No pinned package ships a patcher since Fast_AssetBundle_Loader was cut, so the fixture uses a
# plainly-named one: the installer's patchers/ handling is what is under test, not any real mod.
mkdir -p "$WORK/dist/plugins/Root" "$WORK/dist/patchers/ExamplePatcher" "$WORK/dist/config/Clan/emblems"
write_file "$WORK/dist/plugins/Root/Root.dll" root
write_file "$WORK/dist/patchers/ExamplePatcher/ExamplePatcher.dll" patcher
write_file "$WORK/dist/config/Clan/emblems/cat.png" emblem
run_install

ok_so_far=0
expect_tree "$WORK/bepinex" \
   .lembitu-installed \
   config config/Clan config/Clan/emblems config/Clan/emblems/cat.png \
   patchers patchers/ExamplePatcher patchers/ExamplePatcher/ExamplePatcher.dll \
   plugins plugins/Root plugins/Root/Root.dll \
   && grep -q '^installed config/Clan/ (1 files)$' "$WORK/out" \
   && grep -q '^installed patchers/ExamplePatcher/ (1 files)$' "$WORK/out" \
   && ok_so_far=1
rm -rf "$WORK/dist/patchers" "$WORK/dist/config"
run_install
if [[ ${ok_so_far:-0} == 1 ]] \
   && expect_tree "$WORK/bepinex" \
      .lembitu-installed .lembitu-removed \
      plugins plugins/Root plugins/Root/Root.dll \
   && expect_lines "$WORK/bepinex/.lembitu-removed" \
      config/Clan/emblems/cat.png \
      patchers/ExamplePatcher/ExamplePatcher.dll; then
  report ok "patchers/ and config/ deploy from dist and prune when retired"
else
  report fail "patchers/ and config/ deploy from dist and prune when retired"
fi

# --- 8. the plugins subdirectory as target is refused -----------------------------------------

fresh_dist
write_file "$WORK/dist/plugins/Plain.dll" p
if ! "$INSTALLER" --dist "$WORK/dist" "$WORK/bepinex/plugins" >"$WORK/out" 2>&1 \
   && grep -q 'BepInEx directory itself' "$WORK/out"; then
  report ok "a plugins/ target is refused with the correct target named"
else
  report fail "a plugins/ target is refused with the correct target named"
fi

# --- 9. symlinks in dist are rejected, not silently skipped ---------------------------------

fresh_dist
write_file "$WORK/dist/plugins/Real.dll" r
ln -s Real.dll "$WORK/dist/plugins/Link.dll"

if ! run_install && grep -qi 'unexpected entry' "$WORK/out"; then
  report ok "a symlink in dist/plugins/ is an error"
else
  report fail "a symlink in dist/plugins/ is an error"
fi

# --- 10. empty dist is an error ----------------------------------------------------------------

fresh_dist
if ! run_install && grep -q 'run .dotnet build.' "$WORK/out"; then
  report ok "an empty dist/plugins/ is an error"
else
  report fail "an empty dist/plugins/ is an error"
fi

# --- 11. trailing slash on the target is fine --------------------------------------------------

fresh_dist
write_file "$WORK/dist/plugins/Plain.dll" p
if "$INSTALLER" --dist "$WORK/dist" "$WORK/bepinex/" >"$WORK/out" 2>&1 \
   && [[ -f "$WORK/bepinex/plugins/Plain.dll" ]]; then
  report ok "a trailing slash on the target directory is accepted"
else
  report fail "a trailing slash on the target directory is accepted"
fi

# --- 12. dotfiles and traversal-shaped names in dist are refused at install time ---------------

fresh_dist
write_file "$WORK/dist/plugins/Good.dll" g
write_file "$WORK/dist/plugins/.hidden" h

if ! run_install && grep -q 'refusing to deploy' "$WORK/out"; then
  report ok "a dotfile in dist/plugins/ is refused"
else
  report fail "a dotfile in dist/plugins/ is refused"
fi

# --- 13. taking over a foreign path of the same name says so ------------------------------------

fresh_dist
write_file "$WORK/dist/plugins/Adopted.dll" ours
mkdir -p "$WORK/bepinex/plugins"
write_file "$WORK/bepinex/plugins/Adopted.dll" foreign

if run_install \
   && grep -q '^warning: overwriting foreign file plugins/Adopted.dll$' "$WORK/out" \
   && [[ "$(cat "$WORK/bepinex/plugins/Adopted.dll")" == ours ]]; then
  report ok "adopting a foreign path of the same name warns and overwrites"
else
  report fail "adopting a foreign path of the same name warns and overwrites"
fi

# --- 14. prune-mirror replays the plugins portion of the ledger inside the container ----------

fresh_dist
mkdir -p "$WORK/dist/plugins/Tree/Bundles"
write_file "$WORK/dist/plugins/Tree/ours.dll" o
write_file "$WORK/dist/plugins/Tree/Bundles/ours.bundle" b
run_install
rm -rf "$WORK/dist/plugins/Tree"
write_file "$WORK/dist/plugins/New.dll" n
run_install   # ledger now holds the two Tree paths

# The fake docker pretends to be the container: it records its arguments, redirects the script's
# mirror directory to a local one, and runs the script it was fed on stdin.
FAKE_MIRROR="$WORK/mirror"
mkdir -p "$WORK/bin" "$FAKE_MIRROR/Tree/Bundles"
cat > "$WORK/bin/docker" <<SH
#!/bin/sh
printf '%s\n' "\$*" > "$WORK/docker-args"
sed "1s|^cd \"[^\"]*\"|cd \"$FAKE_MIRROR\"|" > "$WORK/docker-script"
mkdir -p "$FAKE_MIRROR"
sh "$WORK/docker-script"
SH
chmod +x "$WORK/bin/docker"
write_file "$FAKE_MIRROR/Tree/ours.dll" o
write_file "$FAKE_MIRROR/Tree/Bundles/ours.bundle" b
write_file "$FAKE_MIRROR/.lembitu-removed" stale
write_file "$FAKE_MIRROR/New.dll" n

if ( export PATH="$WORK/bin:$PATH"
     "$INSTALLER" prune-mirror "$WORK/bepinex" test-container ) >"$WORK/out" 2>&1 \
   && expect_tree "$FAKE_MIRROR" New.dll \
   && grep -q '^exec -i test-container sh -s$' "$WORK/docker-args" \
   && [[ ! -s "$WORK/bepinex/.lembitu-removed" ]]; then
  report ok "prune-mirror replays the ledger in the container and clears it"
else
  report fail "prune-mirror replays the ledger in the container and clears it"
fi

# --- 15. prune-mirror spends config/ and patchers/ entries without a replay -------------------

printf 'config/Clan/emblems/cat.png\npatchers/ExamplePatcher/ExamplePatcher.dll\n' \
  > "$WORK/bepinex/.lembitu-removed"
rm -f "$WORK/docker-args" "$WORK/docker-script"

if ( export PATH="$WORK/bin:$PATH"
     "$INSTALLER" prune-mirror "$WORK/bepinex" test-container ) >"$WORK/out" 2>&1 \
   && grep -q 'no plugins/ entries' "$WORK/out" \
   && [[ ! -s "$WORK/bepinex/.lembitu-removed" ]] \
   && [[ ! -e "$WORK/docker-args" ]]; then
  report ok "non-plugins ledger entries are spent without touching the container"
else
  report fail "non-plugins ledger entries are spent without touching the container"
fi

# --- 16. prune-mirror refuses a tampered ledger ----------------------------------------------

printf 'plugins/Tree/ours.dll\n../../etc/passwd\n' > "$WORK/bepinex/.lembitu-removed"
rm -f "$WORK/docker-args" "$WORK/docker-script"

if ! ( export PATH="$WORK/bin:$PATH"
     "$INSTALLER" prune-mirror "$WORK/bepinex" test-container ) >"$WORK/out" 2>&1 \
   && grep -q 'unsafe ledger entry' "$WORK/out" \
   && [[ ! -e "$WORK/docker-args" ]]; then
  report ok "a ledger entry outside the plugins directory aborts prune-mirror"
else
  report fail "a ledger entry outside the plugins directory aborts prune-mirror"
fi

# --- 17. prune-mirror with no ledger is a no-op ------------------------------------------------

rm -f "$WORK/bepinex/.lembitu-removed"
if ( export PATH="$WORK/bin:$PATH"
     "$INSTALLER" prune-mirror "$WORK/bepinex" test-container ) >"$WORK/out" 2>&1 \
   && grep -qi 'nothing to prune' "$WORK/out"; then
  report ok "prune-mirror without a ledger does nothing"
else
  report fail "prune-mirror without a ledger does nothing"
fi

# --- 18. a failed replay keeps the ledger --------------------------------------------------------

printf 'plugins/Tree/ours.dll\n' > "$WORK/bepinex/.lembitu-removed"
rm -f "$WORK/docker-args" "$WORK/docker-script"
rm -rf "$FAKE_MIRROR" && mkdir -p "$FAKE_MIRROR/Tree/ours.dll"   # ours.dll as a directory: rm -f fails

if ! ( export PATH="$WORK/bin:$PATH"
     "$INSTALLER" prune-mirror "$WORK/bepinex" test-container ) >"$WORK/out" 2>&1 \
   && grep -q 'plugins/Tree/ours.dll' "$WORK/bepinex/.lembitu-removed"; then
  report ok "a removal that fails inside the container keeps the ledger for retry"
else
  report fail "a removal that fails inside the container keeps the ledger for retry"
fi

# --- 19. an installed manifest entry outside the target refuses the whole run -------------------
#
# dist/ must not sit beside the target here. A `../outside.txt` entry is resolved against both
# $DIST_DIR and the target, so if dist were a sibling of the target then $DIST_DIR/../outside.txt
# would be the very file under test and the pre-removal "still in dist/?" guard would skip the
# entry before rm - the assertion would hold even with the check removed. Staging dist one level
# deeper keeps it load-bearing: against the unvalidated installer this manifest deletes the file.

rm -rf "$WORK/deep" "$WORK/bepinex"
mkdir -p "$WORK/deep/dist/plugins" "$WORK/bepinex"
write_file "$WORK/deep/dist/plugins/Good.dll" g
"$INSTALLER" --dist "$WORK/deep/dist" "$WORK/bepinex" >"$WORK/out" 2>&1
rm "$WORK/deep/dist/plugins/Good.dll"
write_file "$WORK/deep/dist/plugins/Current.dll" c
write_file "$WORK/outside.txt" precious        # outside the target; ../outside.txt reaches it
printf 'plugins/Good.dll\n../outside.txt\n' > "$WORK/bepinex/.lembitu-installed"

if ! "$INSTALLER" --dist "$WORK/deep/dist" "$WORK/bepinex" >"$WORK/out" 2>&1 \
   && grep -q 'unsafe entry' "$WORK/out" \
   && [[ "$(cat "$WORK/outside.txt")" == precious ]] \
   && [[ -f "$WORK/bepinex/plugins/Good.dll" ]] \
   && [[ ! -e "$WORK/bepinex/.lembitu-removed" ]]; then
  report ok "a manifest entry outside the target refuses the run before any removal"
else
  report fail "a manifest entry outside the target refuses the run before any removal"
fi
rm -rf "$WORK/deep" "$WORK/outside.txt"

# --- 20. a legacy manifest is validated before it is migrated and deleted ----------------------
#
# The plugins/-era manifest predates the path policy, so the migration is the one place the file is
# rewritten from an untrusted source. Refusing after the rm -f would delete the only copy the
# operator could correct and leave the run unrecoverable, so the check must run while the legacy
# file is still on disk and must not install anything.

rm -rf "$WORK/bepinex"
mkdir -p "$WORK/dist/plugins" "$WORK/bepinex/plugins"
write_file "$WORK/dist/plugins/Current.dll" c
write_file "$WORK/bepinex/plugins/Old Mod.dll" o          # legal for the old script, not this one
printf 'Old Mod.dll\n' > "$WORK/bepinex/plugins/.lembitu-installed"

if ! run_install \
   && grep -q 'unsafe entry in .*plugins/\.lembitu-installed' "$WORK/out" \
   && [[ -f "$WORK/bepinex/plugins/.lembitu-installed" ]] \
   && [[ ! -e "$WORK/bepinex/plugins/Current.dll" ]]; then
  report ok "a legacy manifest that fails the policy is refused with its original left to correct"
else
  report fail "a legacy manifest that fails the policy is refused with its original left to correct"
fi

# --- 21. a Pack-only package is withheld from the server, and pruned if it ever landed ---------
#
# The failure this exists for is silent and expensive: AzuHoverStats disconnects any peer that does
# not answer its version check, so installing a Pack-only mod on the server refuses exactly the
# players it was shipped for (#78). dist/ holds every adopted pin because the client Pack is built
# from the same table, so withholding is the installer's job - and a server that already has one
# must lose it rather than keep loading it.

fresh_dist
write_file "$WORK/dist/plugins/Clan.dll" clan
mkdir -p "$WORK/dist/plugins/AzuHoverStats" "$WORK/dist/plugins/AzuClock"
write_file "$WORK/dist/plugins/AzuHoverStats/AzuHoverStats.dll" hover
write_file "$WORK/dist/plugins/AzuClock/AzuClock.dll" clock
write_file "$WORK/dist/plugins/MouseTweaks.dll" mouse

if run_install \
   && expect_tree "$WORK/bepinex" .lembitu-installed plugins plugins/Clan.dll \
   && expect_lines "$WORK/bepinex/.lembitu-installed" plugins/Clan.dll \
   && grep -q '^withheld Pack-only plugins/AzuHoverStats/ (1 files)$' "$WORK/out" \
   && grep -q '^withheld Pack-only plugins/MouseTweaks.dll$' "$WORK/out"; then
  report ok "a Pack-only package is never installed on the server"
else
  report fail "a Pack-only package is never installed on the server"
fi

# The same dist, but the server already carries the mod under our manifest: the next run must take
# it away. Pruning is driven by the manifest, and its predicate used to be "still in dist", which
# would have kept this file loaded forever.
mkdir -p "$WORK/bepinex/plugins/AzuHoverStats"
write_file "$WORK/bepinex/plugins/AzuHoverStats/AzuHoverStats.dll" hover
printf 'plugins/Clan.dll\nplugins/AzuHoverStats/AzuHoverStats.dll\n' > "$WORK/bepinex/.lembitu-installed"

if run_install \
   && expect_tree "$WORK/bepinex" \
      .lembitu-installed .lembitu-removed plugins plugins/Clan.dll \
   && expect_lines "$WORK/bepinex/.lembitu-installed" plugins/Clan.dll \
   && expect_lines "$WORK/bepinex/.lembitu-removed" plugins/AzuHoverStats/AzuHoverStats.dll; then
  report ok "a Pack-only package already on the server is pruned, directory and all"
else
  report fail "a Pack-only package already on the server is pruned, directory and all"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
