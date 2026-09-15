#!/usr/bin/env bash
# Behaviour tests for scripts/backup-world.sh and scripts/restore-world.sh.
#
# These are the failure boundaries that made the container's own backup useless on this stack: a
# flat-file glob that captures nothing, a running server reaping a generation mid-copy, an archive
# with no world in it, and a restore that quietly eats the live world. Real fixture saves in
# isolated temp directories; no server, no network.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP="$REPO_ROOT/scripts/backup-world.sh"
RESTORE="$REPO_ROOT/scripts/restore-world.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0 fail=0
report() {
  printf '%s: %s\n' "$([ "$1" = ok ] && echo pass || echo FAIL)" "$2"
  [ "$1" = ok ] && pass=$((pass + 1)) || fail=$((fail + 1))
}
assert_eq() { [ "$2" = "$3" ] || { printf '  want: %s\n  got:  %s\n' "$3" "$2" >&2; return 1; }; }

# A world in the measured 1.0 shape: a directory with .fwl2/.db2/.chunks/.chunk and the .ok marker
# the game writes last. `generation` lets a case move the world on to a new save.
make_world() {  # make_world <dir> <name> <generation>
  local d="$1/worlds_local/$2" g=$3
  mkdir -p "$d"
  printf 'fwl2-%s-%s\n' "$2" "$g" > "$d/_main.$g.fwl2"
  printf 'db2-%s-%s\n' "$2" "$g"  > "$d/_main.$g.db2"
  printf 'chunks\n'                > "$d/_main.$g.chunks"
  printf 'chunk\n'                 > "$d/00_00__0_$g.chunk"
  printf ''                        > "$d/_main.$g.ok"
  mkdir -p "$1/cache"
  printf 'biome\n'                 > "$1/cache/${2}_biomedatacache.bin"
  printf '[Platform]_roster1\n'    > "$1/permittedlist.txt"
  printf '[Platform]_admin1\n'     > "$1/adminlist.txt"
}

# --- 1. a 1.0 world is captured, flat-file globbing would not --------------------------------

SAVE="$WORK/save"; OUT="$WORK/backups"
make_world "$SAVE" Midgard 1

if "$BACKUP" --savedir "$SAVE" --out "$OUT" > "$WORK/out" 2>&1; then
  archive="$(ls "$OUT"/lembitu-*.tar.gz 2>/dev/null | head -1)"
  if [[ -n "$archive" ]] \
     && tar tzf "$archive" | grep -q 'worlds_local/Midgard/_main.1.fwl2' \
     && tar tzf "$archive" | grep -q 'worlds_local/Midgard/_main.1.ok'; then
    report ok "captures the chunked world directory including its .ok marker"
  else
    report fail "captures the chunked world directory including its .ok marker"
  fi
else
  report fail "captures the chunked world directory including its .ok marker"
fi

# --- 2. the archive is self-describing -------------------------------------------------------

if [[ -n "${archive:-}" ]] && tar xzOf "$archive" ./MANIFEST.txt 2>/dev/null | grep -q '^generations_marker_set='; then
  report ok "writes a manifest naming the captured generation marker set"
else
  report fail "writes a manifest naming the captured generation marker set"
fi

# --- 3. client-owned stores are excluded -----------------------------------------------------
# Character level and personal keys live in the player's own character file (ADR-0010), so a
# server archive must not claim to hold them.

mkdir -p "$SAVE/characters"
printf 'a character\n' > "$SAVE/characters/Someone.fch"
"$BACKUP" --savedir "$SAVE" --out "$OUT" > "$WORK/out" 2>&1
newest="$(ls -t "$OUT"/lembitu-*.tar.gz | head -1)"
if tar tzf "$newest" | grep -q 'characters/'; then
  report fail "does not capture the client-owned character store"
else
  report ok "does not capture the client-owned character store"
fi

# --- 4. admission lists travel with the world ------------------------------------------------

if tar tzf "$newest" | grep -q 'permittedlist.txt'; then
  report ok "captures the Roster whitelist alongside the world"
else
  report fail "captures the Roster whitelist alongside the world"
fi

# --- 5. a save committing mid-copy is noticed and retried ------------------------------------
# The world advances a generation while the copy runs, which is what a live server does. The
# capture must not return a set stitched across two generations.

SAVE2="$WORK/save2"; OUT2="$WORK/backups2"
make_world "$SAVE2" Live 1
# A fake `cp` that bumps the source world once, exactly as a save landing mid-copy would.
faker="$WORK/bin"; mkdir -p "$faker"
cat > "$faker/cp" <<'CP'
#!/bin/bash
real=/usr/bin/cp
[ -x "$real" ] || real=/bin/cp
if [ "${BUMP_ONCE:-}" = 1 ] && [ ! -f "$BUMP_MARKER" ]; then
  : > "$BUMP_MARKER"
  printf 'fwl2-Live-2\n' > "$BUMP_WORLD/_main.2.fwl2"
  printf 'db2-Live-2\n'  > "$BUMP_WORLD/_main.2.db2"
  printf 'chunks\n'      > "$BUMP_WORLD/_main.2.chunks"
  printf 'chunk\n'       > "$BUMP_WORLD/00_00__0_2.chunk"
  printf ''              > "$BUMP_WORLD/_main.2.ok"
fi
exec "$real" "$@"
CP
chmod +x "$faker/cp"

if PATH="$faker:$PATH" BUMP_ONCE=1 BUMP_MARKER="$WORK/bumped" BUMP_WORLD="$SAVE2/worlds_local/Live" \
   "$BACKUP" --savedir "$SAVE2" --out "$OUT2" > "$WORK/out" 2>&1; then
  if grep -q 'a save committed during the copy' "$WORK/out"; then
    report ok "detects a save committing mid-copy and retries instead of returning a torn set"
  else
    report fail "detects a save committing mid-copy and retries instead of returning a torn set"
  fi
else
  report fail "detects a save committing mid-copy and retries instead of returning a torn set"
fi

# --- 6. a backup with no world in it is refused ----------------------------------------------
# This is the container's historical failure: 23 byte-identical archives of a directory the server
# never wrote to. Two distinct empty shapes, two distinct refusals.

SAVE3="$WORK/save3"; OUT3="$WORK/backups3"
mkdir -p "$SAVE3/worlds_local" "$SAVE3/cache"
printf 'stale\n' > "$SAVE3/cache/whatever_biomedatacache.bin"

if ! "$BACKUP" --savedir "$SAVE3" --out "$OUT3" > "$WORK/out" 2>&1 \
   && grep -q 'no world directories' "$WORK/out"; then
  report ok "refuses a save directory that holds no world directory at all"
else
  report fail "refuses a save directory that holds no world directory at all"
fi

# A world directory that exists but holds no world files: the world was created and never saved.
mkdir -p "$SAVE3/worlds_local/Empty"
if ! "$BACKUP" --savedir "$SAVE3" --out "$OUT3" > "$WORK/out" 2>&1 \
   && grep -q 'no world files' "$WORK/out" \
   && [ ! -e "$OUT3"/lembitu-*.tar.gz ]; then
  report ok "refuses a capture that contains no world files"
else
  report fail "refuses a capture that contains no world files"
fi

# --- 7. a save directory with no worlds_local is an error, not an empty backup ----------------

if ! "$BACKUP" --savedir "$WORK/nonexistent" --out "$WORK/backups4" > "$WORK/out" 2>&1; then
  report ok "rejects a --savedir that does not exist"
else
  report fail "rejects a --savedir that does not exist"
fi

# --- 8. restore puts the world back, and a dry run changes nothing ----------------------------

REST="$WORK/restored"
before="$(cd "$SAVE" && find worlds_local -type f -exec md5sum {} \; | sort -k2)"

if "$RESTORE" --archive "$newest" --savedir "$REST" --dry-run > "$WORK/out" 2>&1 \
   && [ ! -e "$REST/worlds_local/Midgard" ]; then
  report ok "--dry-run reports the plan and writes nothing"
else
  report fail "--dry-run reports the plan and writes nothing"
fi

"$RESTORE" --archive "$newest" --savedir "$REST" > "$WORK/out" 2>&1
after="$(cd "$REST" && find worlds_local -type f -exec md5sum {} \; | sort -k2)"
if [ "$before" = "$after" ]; then
  report ok "restores a world byte-identically to what was captured"
else
  report fail "restores a world byte-identically to what was captured"
fi

# --- 9. restoring over a live world moves it aside rather than deleting it --------------------

printf 'fwl2-Midgard-9\n' > "$REST/worlds_local/Midgard/_main.9.fwl2"
printf ''                 > "$REST/worlds_local/Midgard/_main.9.ok"

if "$RESTORE" --archive "$newest" --savedir "$REST" > "$WORK/out" 2>&1 \
   && ls -d "$REST"/worlds_local/Midgard.replaced-* >/dev/null 2>&1; then
  report ok "moves an existing world aside instead of deleting it"
else
  report fail "moves an existing world aside instead of deleting it"
fi

# --- 10. a pre-1.0 flat-file archive is refused ----------------------------------------------
# The whole point of #20's save-format note: an old-style backup must fail loudly, not be restored
# into a server that will then refuse to load it.

FLAT="$WORK/flat"; mkdir -p "$FLAT/worlds_local/Old"
printf 'flat\n' > "$FLAT/worlds_local/Old/Old.fwl"
printf 'flat\n' > "$FLAT/worlds_local/Old/Old.db"
( cd "$FLAT" && tar czf "$WORK/flat.tar.gz" . )

if ! "$RESTORE" --archive "$WORK/flat.tar.gz" --savedir "$WORK/restored-flat" > "$WORK/out" 2>&1 \
   && grep -q 'no _main.*.ok generation marker' "$WORK/out"; then
  report ok "refuses a flat-file archive with no committed-generation marker"
else
  report fail "refuses a flat-file archive with no committed-generation marker"
fi

# --- 11. rotation keeps the newest N and leaves foreign files alone --------------------------

ROT="$WORK/rot"; make_world "$ROT" Rota 1
for i in 1 2 3 4; do
  touch -d "2026-09-0${i} 00:00:00" "$ROT/.touch$i" 2>/dev/null || true
  "$BACKUP" --savedir "$ROT" --out "$WORK/backups5" --keep 2 > "$WORK/out" 2>&1
  sleep 1
done
printf 'operator copy\n' > "$WORK/backups5/hand-copy.tar.gz"
"$BACKUP" --savedir "$ROT" --out "$WORK/backups5" --keep 2 > "$WORK/out" 2>&1

kept="$(ls "$WORK/backups5"/lembitu-*.tar.gz 2>/dev/null | wc -l | tr -d ' ')"
if [ "$kept" -le 2 ] && [ -f "$WORK/backups5/hand-copy.tar.gz" ]; then
  report ok "rotation keeps the newest --keep archives and never removes a foreign file"
else
  report fail "rotation keeps the newest --keep archives and never removes a foreign file"
fi

# --- 12. selecting one world out of a multi-world archive ------------------------------------

MULTI="$WORK/multi"; make_world "$MULTI" Alpha 1; make_world "$MULTI" Beta 1
"$BACKUP" --savedir "$MULTI" --out "$WORK/backups6" > "$WORK/out" 2>&1
multi="$(ls -t "$WORK/backups6"/lembitu-*.tar.gz | head -1)"

if "$RESTORE" --archive "$multi" --savedir "$WORK/restored-multi" --world Beta > "$WORK/out" 2>&1 \
   && [ -d "$WORK/restored-multi/worlds_local/Beta" ] \
   && [ ! -d "$WORK/restored-multi/worlds_local/Alpha" ]; then
  report ok "restores only the named world from a multi-world archive"
else
  report fail "restores only the named world from a multi-world archive"
fi

# --- 13. a world that is not in the archive is named in the failure --------------------------

if ! "$RESTORE" --archive "$multi" --savedir "$WORK/restored-multi" --world Gamma > "$WORK/out" 2>&1 \
   && grep -q 'Gamma' "$WORK/out"; then
  report ok "names the missing world when asked for one the archive does not hold"
else
  report fail "names the missing world when asked for one the archive does not hold"
fi

# --- 14. derived snapshots beside a world are not captured as worlds -------------------------
# The game writes `<World>_backup_auto-<stamp>` and `<World>_backup_<stamp>` copies, and a restore
# moves a world aside as `<World>.replaced-<stamp>`. Capturing those would inflate the archive and,
# on a restore of every world, put a stale snapshot back beside the live one.

SNAP="$WORK/snap"; make_world "$SNAP" Real 1
mkdir -p "$SNAP/worlds_local/Real_backup_auto-20260101-000000"
printf 'old\n' > "$SNAP/worlds_local/Real_backup_auto-20260101-000000/_main.0.fwl2"
printf ''      > "$SNAP/worlds_local/Real_backup_auto-20260101-000000/_main.0.ok"
mkdir -p "$SNAP/worlds_local/Real_backup_20260101-000000"
printf 'old\n' > "$SNAP/worlds_local/Real_backup_20260101-000000/_main.0.fwl2"
printf ''      > "$SNAP/worlds_local/Real_backup_20260101-000000/_main.0.ok"
mkdir -p "$SNAP/worlds_local/Real.replaced-20260101T000000Z"
printf 'old\n' > "$SNAP/worlds_local/Real.replaced-20260101T000000Z/_main.0.fwl2"
printf ''      > "$SNAP/worlds_local/Real.replaced-20260101T000000Z/_main.0.ok"

"$BACKUP" --savedir "$SNAP" --out "$WORK/backups7" > "$WORK/out" 2>&1
snap_archive="$(ls -t "$WORK/backups7"/lembitu-*.tar.gz | head -1)"
if tar tzf "$snap_archive" | grep -q 'worlds_local/Real/_main.1.fwl2' \
   && ! tar tzf "$snap_archive" | grep -qE 'worlds_local/Real(_backup|\.replaced)'; then
  report ok "captures the live world and skips derived snapshots beside it"
else
  report fail "captures the live world and skips derived snapshots beside it"
fi

# --- 15. an off-host copy leaves the host's own archive in place -----------------------------

OFF="$WORK/offhost"; mkdir -p "$OFF"
if "$BACKUP" --savedir "$SNAP" --out "$WORK/backups8" --offhost "$OFF" > "$WORK/out" 2>&1 \
   && ls "$OFF"/lembitu-*.tar.gz >/dev/null 2>&1 \
   && ls "$WORK/backups8"/lembitu-*.tar.gz >/dev/null 2>&1; then
  report ok "writes a second copy to --offhost and keeps the local archive"
else
  report fail "writes a second copy to --offhost and keeps the local archive"
fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
