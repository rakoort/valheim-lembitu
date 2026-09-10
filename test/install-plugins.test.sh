#!/usr/bin/env bash
# Behaviour tests for scripts/install-plugins.sh: deployment of DLLs and whole mod trees, pruning of
# what the manifest owns (and nothing else), and the container-side replay of .lembitu-removed.
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
  rm -rf "$WORK/dist" "$WORK/target"
  mkdir -p "$WORK/dist" "$WORK/target"
}

write_file() {  # write_file <file> <bytes>
  printf '%s' "$2" > "$1"
}

run_install() { "$INSTALLER" --dist "$WORK/dist" "$WORK/target" >"$WORK/out" 2>&1; }

# --- 1. fresh install: top-level DLLs and a whole tree, layout preserved ---------------------

fresh_dist
write_file "$WORK/dist/Lembitu.Hello.dll" hello
mkdir -p "$WORK/dist/More_World_Locations_AIO/Bundles/sub"
write_file "$WORK/dist/More_World_Locations_AIO/More_World_Locations_AIO.dll" dll
write_file "$WORK/dist/More_World_Locations_AIO/assetBundleManifest_full" manifest
write_file "$WORK/dist/More_World_Locations_AIO/Bundles/mwl_ruins1" bundle1
write_file "$WORK/dist/More_World_Locations_AIO/Bundles/sub/mwl_ruins2" bundle2

if run_install \
   && expect_tree "$WORK/target" \
      .lembitu-installed \
      Lembitu.Hello.dll \
      More_World_Locations_AIO \
      More_World_Locations_AIO/Bundles \
      More_World_Locations_AIO/Bundles/sub \
      More_World_Locations_AIO/Bundles/mwl_ruins1 \
      More_World_Locations_AIO/Bundles/sub/mwl_ruins2 \
      More_World_Locations_AIO/More_World_Locations_AIO.dll \
      More_World_Locations_AIO/assetBundleManifest_full \
   && expect_lines "$WORK/target/.lembitu-installed" \
      Lembitu.Hello.dll \
      More_World_Locations_AIO/More_World_Locations_AIO.dll \
      More_World_Locations_AIO/assetBundleManifest_full \
      More_World_Locations_AIO/Bundles/mwl_ruins1 \
      More_World_Locations_AIO/Bundles/sub/mwl_ruins2 \
   && grep -q '^installed More_World_Locations_AIO/ (4 files)$' "$WORK/out" \
   && grep -q '^installed Lembitu.Hello.dll$' "$WORK/out" \
   && [[ ! -e "$WORK/target/.lembitu-removed" ]]; then
  report ok "fresh install deploys DLLs and trees, manifest lists every file"
else
  report fail "fresh install deploys DLLs and trees, manifest lists every file"
fi

# --- 2. prune: stale DLL and stale tree removed, directories cleaned up ----------------------

write_file "$WORK/dist/Replacement.dll" rep
rm "$WORK/dist/Lembitu.Hello.dll"
rm -rf "$WORK/dist/More_World_Locations_AIO"

if run_install \
   && expect_tree "$WORK/target" .lembitu-installed .lembitu-removed Replacement.dll \
   && expect_lines "$WORK/target/.lembitu-installed" Replacement.dll \
   && expect_lines "$WORK/target/.lembitu-removed" \
      Lembitu.Hello.dll \
      More_World_Locations_AIO/More_World_Locations_AIO.dll \
      More_World_Locations_AIO/assetBundleManifest_full \
      More_World_Locations_AIO/Bundles/mwl_ruins1 \
      More_World_Locations_AIO/Bundles/sub/mwl_ruins2 \
   && grep -q '^removed stale More_World_Locations_AIO/ (4 files)$' "$WORK/out"; then
  report ok "prune removes stale DLL and tree, ledger records them"
else
  report fail "prune removes stale DLL and tree, ledger records them"
fi

# --- 3. foreign files are never touched, even inside a tree we own ---------------------------

fresh_dist
mkdir -p "$WORK/dist/Tree"
write_file "$WORK/dist/Keeper.dll" k
write_file "$WORK/dist/Tree/ours.dll" o
write_file "$WORK/target/foreign-top.dll" f
mkdir -p "$WORK/target/Tree/Bundles" "$WORK/target/foreign-dir"
write_file "$WORK/target/Tree/foreign.dll" f
write_file "$WORK/target/Tree/Bundles/foreign.bundle" f
write_file "$WORK/target/foreign-dir/foreign.dll" f
run_install  # installs Tree/ours.dll
rm -rf "$WORK/dist/Tree"
run_install

if expect_tree "$WORK/target" \
      .lembitu-installed \
      .lembitu-removed \
      Keeper.dll \
      foreign-top.dll \
      foreign-dir \
      foreign-dir/foreign.dll \
      Tree \
      Tree/Bundles \
      Tree/Bundles/foreign.bundle \
      Tree/foreign.dll; then
  report ok "prune leaves every foreign file and its directory alone"
else
  report fail "prune leaves every foreign file and its directory alone"
fi

# --- 4. a manifest from the DLL-only era (bare filenames) still prunes -----------------------

fresh_dist
write_file "$WORK/dist/Current.dll" c
write_file "$WORK/target/Old.dll" o
printf 'Old.dll\n' > "$WORK/target/.lembitu-installed"

if run_install \
   && expect_tree "$WORK/target" Current.dll .lembitu-installed .lembitu-removed \
   && grep -q '^Old.dll$' "$WORK/target/.lembitu-removed"; then
  report ok "old bare-filename manifests are honoured"
else
  report fail "old bare-filename manifests are honoured"
fi

# --- 5. nothing stale: no ledger is created --------------------------------------------------

fresh_dist
write_file "$WORK/dist/Stable.dll" s
run_install
rm -f "$WORK/target/.lembitu-removed"
run_install

if [[ ! -e "$WORK/target/.lembitu-removed" ]]; then
  report ok "a no-op run writes no ledger"
else
  report fail "a no-op run writes no ledger"
fi

# --- 6. an updated file is recopied (contents, not just presence) ----------------------------

fresh_dist
write_file "$WORK/dist/Stable.dll" v1
run_install
write_file "$WORK/dist/Stable.dll" v2
run_install
if [[ "$(cat "$WORK/target/Stable.dll")" == v2 ]]; then
  report ok "an updated file is recopied"
else
  report fail "an updated file is recopied"
fi

# --- 7. prune-mirror replays the ledger inside the container ---------------------------------

fresh_dist
mkdir -p "$WORK/dist/Tree/Bundles"
write_file "$WORK/dist/Tree/ours.dll" o
write_file "$WORK/dist/Tree/Bundles/ours.bundle" b
run_install
rm -rf "$WORK/dist/Tree"
write_file "$WORK/dist/New.dll" n
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
     "$INSTALLER" prune-mirror "$WORK/target" test-container ) >"$WORK/out" 2>&1 \
   && expect_tree "$FAKE_MIRROR" New.dll \
   && grep -q '^exec -i test-container sh -s$' "$WORK/docker-args" \
   && [[ ! -s "$WORK/target/.lembitu-removed" ]]; then
  report ok "prune-mirror replays the ledger in the container and clears it"
else
  report fail "prune-mirror replays the ledger in the container and clears it"
fi

# --- 8. prune-mirror refuses a tampered ledger ----------------------------------------------

printf 'Tree/ours.dll\n../../etc/passwd\n' > "$WORK/target/.lembitu-removed"
rm -f "$WORK/docker-args" "$WORK/docker-script"

if ! ( export PATH="$WORK/bin:$PATH"
     "$INSTALLER" prune-mirror "$WORK/target" test-container ) >"$WORK/out" 2>&1 \
   && grep -q 'unsafe ledger entry' "$WORK/out" \
   && [[ ! -e "$WORK/docker-args" ]]; then
  report ok "a ledger entry outside the plugins directory aborts prune-mirror"
else
  report fail "a ledger entry outside the plugins directory aborts prune-mirror"
fi

# --- 9. prune-mirror with no ledger is a no-op ------------------------------------------------

rm -f "$WORK/target/.lembitu-removed"
if ( export PATH="$WORK/bin:$PATH"
     "$INSTALLER" prune-mirror "$WORK/target" test-container ) >"$WORK/out" 2>&1 \
   && grep -qi 'nothing to prune' "$WORK/out"; then
  report ok "prune-mirror without a ledger does nothing"
else
  report fail "prune-mirror without a ledger does nothing"
fi

# --- 10. symlinks in dist are rejected, not silently skipped ---------------------------------

fresh_dist
write_file "$WORK/dist/Real.dll" r
ln -s Real.dll "$WORK/dist/Link.dll"

if ! run_install && grep -qi 'unexpected entry' "$WORK/out"; then
  report ok "a symlink in dist/plugins/ is an error"
else
  report fail "a symlink in dist/plugins/ is an error"
fi

# --- 11. empty dist is an error ----------------------------------------------------------------

fresh_dist
if ! run_install && grep -q 'run .dotnet build.' "$WORK/out"; then
  report ok "an empty dist/plugins/ is an error"
else
  report fail "an empty dist/plugins/ is an error"
fi

# --- 12. trailing slash on the target is fine --------------------------------------------------

fresh_dist
write_file "$WORK/dist/Plain.dll" p
if "$INSTALLER" --dist "$WORK/dist" "$WORK/target/" >"$WORK/out" 2>&1 \
   && [[ -f "$WORK/target/Plain.dll" ]]; then
  report ok "a trailing slash on the target directory is accepted"
else
  report fail "a trailing slash on the target directory is accepted"
fi

# --- 13. dotfiles and traversal-shaped names in dist are refused at install time ---------------

fresh_dist
write_file "$WORK/dist/Good.dll" g
write_file "$WORK/dist/.hidden" h

if ! run_install && grep -q 'refusing to deploy' "$WORK/out"; then
  report ok "a dotfile in dist/plugins/ is refused"
else
  report fail "a dotfile in dist/plugins/ is refused"
fi

# --- 14. taking over a foreign path of the same name says so ------------------------------------

fresh_dist
write_file "$WORK/dist/Adopted.dll" ours
write_file "$WORK/target/Adopted.dll" foreign

if run_install \
   && grep -q '^warning: overwriting foreign file Adopted.dll$' "$WORK/out" \
   && [[ "$(cat "$WORK/target/Adopted.dll")" == ours ]]; then
  report ok "adopting a foreign path of the same name warns and overwrites"
else
  report fail "adopting a foreign path of the same name warns and overwrites"
fi

# --- 15. a failed replay keeps the ledger --------------------------------------------------------

printf 'Tree/ours.dll\n' > "$WORK/target/.lembitu-removed"
rm -f "$WORK/docker-args" "$WORK/docker-script"
rm -rf "$FAKE_MIRROR" && mkdir -p "$FAKE_MIRROR/Tree/ours.dll"   # ours.dll as a directory: rm -f fails

if ! ( export PATH="$WORK/bin:$PATH"
     "$INSTALLER" prune-mirror "$WORK/target" test-container ) >"$WORK/out" 2>&1 \
   && grep -q 'Tree/ours.dll' "$WORK/target/.lembitu-removed"; then
  report ok "a removal that fails inside the container keeps the ledger for retry"
else
  report fail "a removal that fails inside the container keeps the ledger for retry"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
