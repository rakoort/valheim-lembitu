#!/usr/bin/env bash
# Behaviour tests for scripts/apply-enforced-config.sh: section-scoped merging of overlay entries
# into generated BepInEx configs, appending of keys a mod has not generated, wholesale replacement
# of data files, and idempotence.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPLIER="$REPO_ROOT/scripts/apply-enforced-config.sh"

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

write_file() {  # write_file <file> <bytes>
  printf '%s' "$2" > "$1"
}

OVERLAY="$WORK/enforced"
CFG="$WORK/config"
mkdir -p "$OVERLAY" "$CFG"

run_apply() { "$APPLIER" --overlay "$OVERLAY" "$CFG" > "$WORK/out" 2>&1; }

# --- 1. values change in their own section; same-named keys elsewhere are untouched -----------

cat > "$OVERLAY/mod.cfg" <<'EOF'
# comment in the overlay
[2 - PvP Settings]
Biome 1 - Meadows Rule = PlayerChoose
[1 - General]
Lock Configuration = true
EOF
cat > "$CFG/mod.cfg" <<'EOF'
## Settings file was created by plugin mod v1.0
[1 - General]
## If on, locked.
# Default value: true
Lock Configuration = false

[2 - PvP Settings]
# Default value: Pvp
Biome 1 - Meadows Rule = Pvp

[3 - Map Position]
Biome 1 - Meadows Rule = ShowPlayer
EOF

if run_apply \
   && grep -q '^Lock Configuration = true$' "$CFG/mod.cfg" \
   && grep -q '^Biome 1 - Meadows Rule = PlayerChoose$' "$CFG/mod.cfg" \
   && grep -A3 '^\[3 - Map Position\]' "$CFG/mod.cfg" | grep -q '^Biome 1 - Meadows Rule = ShowPlayer$' \
   && grep -q '^set mod.cfg \[2 - PvP Settings\] Biome 1 - Meadows Rule = PlayerChoose$' "$WORK/out" \
   && grep -q '^set mod.cfg \[1 - General\] Lock Configuration = true$' "$WORK/out" \
   && grep -q 'created by plugin mod v1.0' "$CFG/mod.cfg"; then
  report ok "entries change in their section, same-named keys elsewhere survive"
else
  report fail "entries change in their section, same-named keys elsewhere survive"
fi

# --- 2. a second run changes nothing and says so ----------------------------------------------

if run_apply && grep -q '^enforced config already in effect' "$WORK/out"; then
  report ok "an enforced config is idempotent and reports nothing to do"
else
  report fail "an enforced config is idempotent and reports nothing to do"
fi

# --- 3. a key the mod never generated is appended under its section ----------------------------

cat >> "$OVERLAY/mod.cfg" <<'EOF'
[1 - General]
New Key We Decided On = 7
EOF
rm "$OVERLAY/mod.cfg"  # rebuild the overlay: only the appended case
cat > "$OVERLAY/mod.cfg" <<'EOF'
[1 - General]
New Key We Decided On = 7
EOF

if run_apply \
   && tail -2 "$CFG/mod.cfg" | head -1 | grep -q '^\[1 - General\]$' \
   && tail -1 "$CFG/mod.cfg" | grep -q '^New Key We Decided On = 7$' \
   && grep -q '^appended mod.cfg \[1 - General\] New Key We Decided On = 7$' "$WORK/out"; then
  report ok "a missing key is appended under a re-declared section"
else
  report fail "a missing key is appended under a re-declared section"
fi

# --- 4. a target the mods never generated is an error ------------------------------------------

printf '[X]\nK = v\n' > "$OVERLAY/ghost.cfg"

if ! run_apply && grep -q 'never generated' "$WORK/out"; then
  report ok "an overlay with no generated target aborts"
else
  report fail "an overlay with no generated target aborts"
fi
rm "$OVERLAY/ghost.cfg"

# --- 5. data files replace wholesale, creating their directory ---------------------------------

mkdir -p "$OVERLAY/BossRules"
printf '# enforced empty\n' > "$OVERLAY/BossRules/powers.yml"
mkdir -p "$CFG/BossRules"
printf -- '- effect: GP_Eikthyr\n' > "$CFG/BossRules/powers.yml"

if run_apply \
   && [[ "$(cat "$CFG/BossRules/powers.yml")" == "# enforced empty" ]] \
   && grep -q '^replaced BossRules/powers.yml$' "$WORK/out"; then
  report ok "data files replace their target wholesale"
else
  report fail "data files replace their target wholesale"
fi

# --- 6. a bad overlay line is an error ----------------------------------------------------------

printf 'dangling = entry\n' > "$OVERLAY/bad.cfg"
printf '[1 - General]\nExisting = yes\n' > "$CFG/bad.cfg"
if ! run_apply && grep -q 'outside a section' "$WORK/out"; then
  report ok "an overlay entry outside a section aborts"
else
  report fail "an overlay entry outside a section aborts"
fi
rm "$OVERLAY/bad.cfg"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
