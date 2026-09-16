#!/usr/bin/env bash
# Behaviour tests for scripts/verify-enforced-config.sh: the command that decides whether the
# enforced overlay is actually in effect (#69, ADR-0011).
#
# The question every case below asks is the one the silent 2026-09-16 revert failed: would this
# have caught it? A pinned key sitting at the mod's default, a key the mod stopped generating, a
# data file the mod rewrote, and a target file that is not there at all are the four ways
# enforcement disappears without anybody being told.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERIFIER="$REPO_ROOT/scripts/verify-enforced-config.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0 fail=0

report() {
  printf '%s: %s\n' "$([ "$1" = ok ] && echo pass || echo FAIL)" "$2"
  [ "$1" = ok ] && pass=$((pass + 1)) || fail=$((fail + 1))
}

OVERLAY="$WORK/enforced"
CFG="$WORK/config"
mkdir -p "$OVERLAY" "$CFG"

run_verify() { "$VERIFIER" --overlay "$OVERLAY" "$CFG" > "$WORK/out" 2>&1; }

# The tree every case starts from: two sections that reuse a key name, exactly as BepInEx files do.
reset_tree() {
  rm -rf "$OVERLAY" "$CFG"
  mkdir -p "$OVERLAY" "$CFG"
  cat > "$OVERLAY/mod.cfg" <<'EOF'
# a comment the target does not have
[2 - PvP Settings]
Biome 1 - Meadows Rule = PlayerChoose

[1 - General]
Lock Configuration = true
EOF
  cat > "$CFG/mod.cfg" <<'EOF'
## Settings file was created by plugin mod v1.0
[1 - General]
# Default value: false
Lock Configuration = true

[2 - PvP Settings]
Biome 1 - Meadows Rule = PlayerChoose

[3 - Map Position]
Biome 1 - Meadows Rule = ShowPlayer
EOF
}

# --- 1. a tree that matches passes, and says how much it checked -------------------------------

reset_tree
if run_verify && grep -q '^enforced config verified: 2 entries match$' "$WORK/out"; then
  report ok "a matching tree exits 0 and reports what it checked"
else
  report fail "a matching tree exits 0 and reports what it checked"
fi

# --- 2. one reverted value fails, and the message names that key -------------------------------
# This is the 2026-09-16 revert in miniature: a pinned key back at the mod's default.

reset_tree
sed -i.bak 's/^Lock Configuration = true$/Lock Configuration = false/' "$CFG/mod.cfg"
if ! run_verify \
   && grep -q 'mod.cfg :: \[1 - General\] :: Lock Configuration' "$WORK/out" \
   && grep -q 'expected "true", live "false"' "$WORK/out"; then
  report ok "a single changed value exits non-zero and names that key"
else
  report fail "a single changed value exits non-zero and names that key"
fi

# --- 3. the same key name in another section is not our key ------------------------------------
# The applier matches on section and key together; a verifier that matched on key text alone would
# read [3 - Map Position]'s ShowPlayer and pass a server whose PvP rule had reverted.

reset_tree
sed -i.bak '/^\[2 - PvP Settings\]$/,/^$/s/^Biome 1 - Meadows Rule = PlayerChoose$/Biome 1 - Meadows Rule = Pvp/' "$CFG/mod.cfg"
if ! run_verify && grep -q '\[2 - PvP Settings\] :: Biome 1 - Meadows Rule' "$WORK/out"; then
  report ok "a reverted key is found in its own section, not a same-named key elsewhere"
else
  report fail "a reverted key is found in its own section, not a same-named key elsewhere"
fi

# --- 4. a key the overlay sets and the target does not have is a failure -----------------------
# A mod that renames a key leaves the old name unenforced. The applier appends it, which is
# visible at review; a verifier that treated absence as "nothing to compare" would call that pass.

reset_tree
printf 'A Key The Mod Never Generated = 7\n' >> "$OVERLAY/mod.cfg"
if ! run_verify && grep -q 'absent: mod.cfg :: \[1 - General\] :: A Key The Mod Never Generated' "$WORK/out"; then
  report ok "a key the overlay sets but the target lacks fails rather than passing"
else
  report fail "a key the overlay sets but the target lacks fails rather than passing"
fi

# --- 5. spacing is not drift --------------------------------------------------------------------
# Mods write `Key = value`; an overlay may be written with any spacing. Reporting that as drift
# would train the operator to ignore the command's output, which is worse than not running it.

reset_tree
printf '[1 - General]\nLock Configuration    =     true   \n' > "$OVERLAY/mod.cfg"
if run_verify; then
  report ok "a value differing only by surrounding whitespace passes"
else
  report fail "a value differing only by surrounding whitespace passes"
fi

# --- 6. a data file is compared whole -----------------------------------------------------------
# CreatureManager's yml files carry no merge semantics: the overlay is the file. A mod that
# rewrites one on boot has undone the decision entirely.

reset_tree
mkdir -p "$OVERLAY/CreatureManager" "$CFG/CreatureManager"
printf 'Boss:\n  health: 8\n' > "$OVERLAY/CreatureManager/levels.yml"
printf 'Boss:\n  health: 1\n' > "$CFG/CreatureManager/levels.yml"
if ! run_verify && grep -q 'drift:  CreatureManager/levels.yml - live file content differs' "$WORK/out"; then
  report ok "a data-file overlay whose target content differs fails"
else
  report fail "a data-file overlay whose target content differs fails"
fi

# --- 7. a data file that matches byte for byte passes -------------------------------------------

reset_tree
mkdir -p "$OVERLAY/CreatureManager" "$CFG/CreatureManager"
printf 'Boss:\n  health: 8\n' > "$OVERLAY/CreatureManager/levels.yml"
cp "$OVERLAY/CreatureManager/levels.yml" "$CFG/CreatureManager/levels.yml"
if run_verify && grep -q 'verified: 3 entries match' "$WORK/out"; then
  report ok "a matching data file counts as a checked entry and passes"
else
  report fail "a matching data file counts as a checked entry and passes"
fi

# --- 8. a target file that is not there at all is a failure that names it -----------------------
# Enforcing into a filename no mod reads is the silence this command exists to break, so it can
# never be a pass - and the operator needs the name to tell a renamed mod from an unloaded one.

reset_tree
printf '[X]\nK = v\n' > "$OVERLAY/ghost.cfg"
if ! run_verify && grep -q '^missing: ghost.cfg' "$WORK/out"; then
  report ok "a missing target file fails with a message naming the file"
else
  report fail "a missing target file fails with a message naming the file"
fi

# --- 9. every difference is reported, not only the first ----------------------------------------
# An operator reading a failed restart wants the list. Stopping at the first difference turns one
# restart into as many restarts as there are drifted keys.

reset_tree
sed -i.bak 's/^Lock Configuration = true$/Lock Configuration = false/' "$CFG/mod.cfg"
sed -i.bak '/^\[2 - PvP Settings\]$/,/^$/s/^Biome 1 - Meadows Rule = PlayerChoose$/Biome 1 - Meadows Rule = Pvp/' "$CFG/mod.cfg"
if ! run_verify \
   && grep -q 'Lock Configuration' "$WORK/out" \
   && grep -q '\[2 - PvP Settings\] :: Biome 1 - Meadows Rule' "$WORK/out" \
   && grep -q '2 of 2 entries differ' "$WORK/out"; then
  report ok "every drifted entry is reported, with a count"
else
  report fail "every drifted entry is reported, with a count"
fi

# --- 10. the applier's output is what this command verifies -------------------------------------
# The two read one parser, and this is the assertion that keeps them honest: apply, then verify,
# on a target that started entirely at mod defaults.

reset_tree
cat > "$CFG/mod.cfg" <<'EOF'
## Settings file was created by plugin mod v1.0
[1 - General]
Lock Configuration = false

[2 - PvP Settings]
Biome 1 - Meadows Rule = Pvp

[3 - Map Position]
Biome 1 - Meadows Rule = ShowPlayer
EOF
if ! run_verify \
   && "$REPO_ROOT/scripts/apply-enforced-config.sh" --overlay "$OVERLAY" "$CFG" > /dev/null \
   && run_verify; then
  report ok "a tree the applier has just written verifies"
else
  report fail "a tree the applier has just written verifies"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
