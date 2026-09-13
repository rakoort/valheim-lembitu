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
write_file "$WORK/dist/plugins/Lembitu.Hello.dll" hello
mkdir -p "$WORK/dist/plugins/More_World_Locations_AIO/Bundles/sub"
write_file "$WORK/dist/plugins/More_World_Locations_AIO/More_World_Locations_AIO.dll" dll
write_file "$WORK/dist/plugins/More_World_Locations_AIO/assetBundleManifest_full" manifest
write_file "$WORK/dist/plugins/More_World_Locations_AIO/Bundles/mwl_ruins1" bundle1
write_file "$WORK/dist/plugins/More_World_Locations_AIO/Bundles/sub/mwl_ruins2" bundle2

if run_install \
   && expect_tree "$WORK/bepinex" \
      .lembitu-installed \
      plugins \
      plugins/Lembitu.Hello.dll \
      plugins/More_World_Locations_AIO \
      plugins/More_World_Locations_AIO/Bundles \
      plugins/More_World_Locations_AIO/Bundles/sub \
      plugins/More_World_Locations_AIO/Bundles/mwl_ruins1 \
      plugins/More_World_Locations_AIO/Bundles/sub/mwl_ruins2 \
      plugins/More_World_Locations_AIO/More_World_Locations_AIO.dll \
      plugins/More_World_Locations_AIO/assetBundleManifest_full \
   && expect_lines "$WORK/bepinex/.lembitu-installed" \
      plugins/Lembitu.Hello.dll \
      plugins/More_World_Locations_AIO/More_World_Locations_AIO.dll \
      plugins/More_World_Locations_AIO/assetBundleManifest_full \
      plugins/More_World_Locations_AIO/Bundles/mwl_ruins1 \
      plugins/More_World_Locations_AIO/Bundles/sub/mwl_ruins2 \
   && grep -q '^installed plugins/More_World_Locations_AIO/ (4 files)$' "$WORK/out" \
   && grep -q '^installed plugins/Lembitu.Hello.dll$' "$WORK/out" \
   && [[ ! -e "$WORK/bepinex/.lembitu-removed" ]]; then
  report ok "fresh install deploys DLLs and trees, manifest lists every file"
else
  report fail "fresh install deploys DLLs and trees, manifest lists every file"
fi

# --- 2. prune: stale DLL and stale tree removed, directories cleaned up ----------------------

write_file "$WORK/dist/plugins/Replacement.dll" rep
rm "$WORK/dist/plugins/Lembitu.Hello.dll"
rm -rf "$WORK/dist/plugins/More_World_Locations_AIO"

if run_install \
   && expect_tree "$WORK/bepinex" \
      .lembitu-installed .lembitu-removed plugins plugins/Replacement.dll \
   && expect_lines "$WORK/bepinex/.lembitu-installed" plugins/Replacement.dll \
   && expect_lines "$WORK/bepinex/.lembitu-removed" \
      plugins/Lembitu.Hello.dll \
      plugins/More_World_Locations_AIO/More_World_Locations_AIO.dll \
      plugins/More_World_Locations_AIO/assetBundleManifest_full \
      plugins/More_World_Locations_AIO/Bundles/mwl_ruins1 \
      plugins/More_World_Locations_AIO/Bundles/sub/mwl_ruins2 \
   && grep -q '^removed stale plugins/More_World_Locations_AIO/ (4 files)$' "$WORK/out"; then
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
mkdir -p "$WORK/dist/plugins/Root" "$WORK/dist/patchers/Fast_AssetBundle_Loader" "$WORK/dist/config/Clan/emblems"
write_file "$WORK/dist/plugins/Root/Root.dll" root
write_file "$WORK/dist/patchers/Fast_AssetBundle_Loader/FastAssetBundleLoader.dll" patcher
write_file "$WORK/dist/config/Clan/emblems/cat.png" emblem
run_install

ok_so_far=0
expect_tree "$WORK/bepinex" \
   .lembitu-installed \
   config config/Clan config/Clan/emblems config/Clan/emblems/cat.png \
   patchers patchers/Fast_AssetBundle_Loader patchers/Fast_AssetBundle_Loader/FastAssetBundleLoader.dll \
   plugins plugins/Root plugins/Root/Root.dll \
   && grep -q '^installed config/Clan/ (1 files)$' "$WORK/out" \
   && grep -q '^installed patchers/Fast_AssetBundle_Loader/ (1 files)$' "$WORK/out" \
   && ok_so_far=1
rm -rf "$WORK/dist/patchers" "$WORK/dist/config"
run_install
if [[ ${ok_so_far:-0} == 1 ]] \
   && expect_tree "$WORK/bepinex" \
      .lembitu-installed .lembitu-removed \
      plugins plugins/Root plugins/Root/Root.dll \
   && expect_lines "$WORK/bepinex/.lembitu-removed" \
      config/Clan/emblems/cat.png \
      patchers/Fast_AssetBundle_Loader/FastAssetBundleLoader.dll; then
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

printf 'config/Clan/emblems/cat.png\npatchers/Fast_AssetBundle_Loader/FastAssetBundleLoader.dll\n' \
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

# --- 19. dedicated installation works without programmable completion -------------------------

SERVER_REPO="$WORK/server checkout"
mkdir -p "$SERVER_REPO/scripts/lib" "$SERVER_REPO/cache" "$SERVER_REPO/server" \
  "$SERVER_REPO/lib/bepinex/pack/BepInExPack_Valheim/doorstop_libs" \
  "$SERVER_REPO/lib/bepinex/pack/BepInExPack_Valheim/BepInEx"
cp "$REPO_ROOT/scripts/test-server.sh" "$INSTALLER" "$SERVER_REPO/scripts/"
cp "$REPO_ROOT/scripts/lib/ledger.sh" "$SERVER_REPO/scripts/lib/"
# Only downloading and reference extraction are fixtures; deploy through the real installer.
printf '#!/usr/bin/env bash\nexit 0\n' > "$SERVER_REPO/cache/DepotDownloader"
printf '#!/usr/bin/env bash\nexit 0\n' > "$SERVER_REPO/scripts/extract-refs.sh"
chmod +x "$SERVER_REPO/cache/DepotDownloader" "$SERVER_REPO/scripts/extract-refs.sh"
PACK="$SERVER_REPO/lib/bepinex/pack/BepInExPack_Valheim"
touch "$PACK/doorstop_config.ini" "$PACK/.doorstop_version" "$PACK/start_server_bepinex.sh" \
  "$SERVER_REPO/server/valheim_server.x86_64"
printf 'enable -n compgen\n' > "$SERVER_REPO/no-completion.bash"
server_install() {
  BASH_ENV="$SERVER_REPO/no-completion.bash" VALHEIM_TEST_CACHE="$SERVER_REPO/cache" \
    VALHEIM_TEST_DIR="$SERVER_REPO/server" bash "$SERVER_REPO/scripts/test-server.sh" install
}
mkdir -p "$SERVER_REPO/dist/plugins/FixtureBundle"
printf 'fixture payload' > "$SERVER_REPO/dist/plugins/FixtureBundle/plugin.dll"
if server_install >"$WORK/server-out" 2>&1 \
   && cmp -s "$SERVER_REPO/dist/plugins/FixtureBundle/plugin.dll" \
     "$SERVER_REPO/server/BepInEx/plugins/FixtureBundle/plugin.dll"; then
  report ok "dedicated install deploys built plugins without compgen"
else
  cat "$WORK/server-out" >&2
  report fail "dedicated install deploys built plugins without compgen"
fi
rm -rf "$SERVER_REPO/dist" "$SERVER_REPO/server/BepInEx/plugins"
if server_install >"$WORK/server-out" 2>&1 \
   && [[ ! -e "$SERVER_REPO/server/BepInEx/plugins" ]]; then
  report ok "dedicated install without built plugins still succeeds"
else
  cat "$WORK/server-out" >&2
  report fail "dedicated install without built plugins still succeeds"
fi


printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
