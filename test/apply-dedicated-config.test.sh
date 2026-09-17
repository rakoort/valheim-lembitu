#!/usr/bin/env bash
# Behaviour tests for scripts/apply-dedicated-config.sh (#86): the applier for the one mod that
# keeps its config inside the game tree instead of BepInEx's config directory.
#
#   test/apply-dedicated-config.test.sh
#
# Everything happens in throwaway directories against a throwaway overlay; the repository's own
# config/dedicated/ is never read, so these tests do not change when its values are retuned.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPLIER="$REPO_ROOT/scripts/apply-dedicated-config.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
pass=0 fail=0
report() {
  printf '%s: %s\n' "$([ "$1" = ok ] && echo pass || echo FAIL)" "$2"
  [ "$1" = ok ] && pass=$((pass + 1)) || fail=$((fail + 1))
}

# The applier reads the repository overlay, so the tests run it against a copy of the tree with
# config/dedicated/ replaced. That is the only way to exercise it without depending on live values.
mkroot() {  # mkroot <overlay-content>
  local root="$WORK/repo"
  rm -rf "$root"
  mkdir -p "$root/scripts/lib" "$root/config/dedicated"
  cp "$REPO_ROOT/scripts/apply-dedicated-config.sh" "$root/scripts/"
  cp "$REPO_ROOT/scripts/lib/enforced-config.sh" "$root/scripts/lib/"
  printf '%s' "$1" > "$root/config/dedicated/mod.cfg"
  printf '%s\n' "$root/scripts/apply-dedicated-config.sh"
}

# --- 1. a drifted value is set in its own section ---------------------------------------------

A="$(mkroot '[Placement]
InnerRadius = 2400
')"
mkdir -p "$WORK/target1"
cat > "$WORK/target1/mod.cfg" <<'CFG'
[Layout]
InnerRadius = 9999

[Placement]
InnerRadius = 3000
MinStonesDistance = 1000
CFG
if "$A" "$WORK/target1" > "$WORK/out" 2>&1 \
   && grep -q 'set mod.cfg \[Placement\] InnerRadius = 2400' "$WORK/out" \
   && grep -A2 '^\[Placement\]' "$WORK/target1/mod.cfg" | grep -qx 'InnerRadius = 2400' \
   && grep -A1 '^\[Layout\]' "$WORK/target1/mod.cfg" | grep -qx 'InnerRadius = 9999'; then
  report ok "sets the key in its own section and leaves a same-named key elsewhere alone"
else
  report fail "sets the key in its own section and leaves a same-named key elsewhere alone"
fi

# --- 2. a second run changes nothing ----------------------------------------------------------

if "$A" "$WORK/target1" > "$WORK/out" 2>&1 \
   && grep -q 'already in effect' "$WORK/out"; then
  report ok "a second run reports nothing to do"
else
  report fail "a second run reports nothing to do"
fi

# --- 3. a key the mod never wrote is appended under its section -------------------------------

mkdir -p "$WORK/target2"
printf '[Placement]\nMinStonesDistance = 1000\n' > "$WORK/target2/mod.cfg"
if "$A" "$WORK/target2" > "$WORK/out" 2>&1 \
   && grep -q 'appended mod.cfg \[Placement\] InnerRadius = 2400' "$WORK/out" \
   && grep -qx 'InnerRadius = 2400' "$WORK/target2/mod.cfg"; then
  report ok "appends a key the mod has not generated"
else
  report fail "appends a key the mod has not generated"
fi

# --- 4. a target the mod has not written yet fails loudly -------------------------------------
# The mod writes its config on first boot. A fresh container has not booted, and the deploy has to
# be able to tell that apart from success, or it would carry on believing the values are in effect.

mkdir -p "$WORK/target3"
if ! "$A" "$WORK/target3" > "$WORK/out" 2>&1 \
   && grep -q 'absent: mod.cfg' "$WORK/out"; then
  report ok "an absent target exits non-zero and says to boot once first"
else
  report fail "an absent target exits non-zero and says to boot once first"
fi

# --- 5. a malformed overlay aborts instead of being partly applied ----------------------------

B="$(mkroot 'InnerRadius = 2400
')"
mkdir -p "$WORK/target4"
printf '[Placement]\nInnerRadius = 3000\n' > "$WORK/target4/mod.cfg"
if ! "$B" "$WORK/target4" > "$WORK/out" 2>&1 \
   && grep -q 'entry outside a section' "$WORK/out" \
   && grep -qx 'InnerRadius = 3000' "$WORK/target4/mod.cfg"; then
  report ok "an entry outside a section aborts and writes nothing"
else
  report fail "an entry outside a section aborts and writes nothing"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
