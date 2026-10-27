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

# --- 3. authoritative characters and mod state travel together ------------------------------
mkdir -p "$SAVE/ServerManager/characters/76561198000000000" "$WORK/state/Guilds" "$WORK/state/Marketplace" "$WORK/state/Lembitu.Guilds"
printf 'character bytes\n' > "$SAVE/ServerManager/characters/76561198000000000/profile"
cp "$REPO_ROOT/config/launch/servermanager-cron.yml" "$SAVE/ServerManager/cron.yml"
printf 'executed checkpoint\n' > "$SAVE/ServerManager/cron_last.yml"
printf 'guild vault\n' > "$WORK/state/Guilds/Midgard.dat"
printf 'market orders\n' > "$WORK/state/Marketplace/Midgard.dat"
printf 'claim owner\n' > "$WORK/state/Lembitu.Guilds/Midgard.claims.json"
printf 'not state\n' > "$WORK/state/mod.cfg"
"$BACKUP" --savedir "$SAVE" --bepinex "$WORK/state" --out "$OUT" > "$WORK/out" 2>&1
newest="$(ls -t "$OUT"/lembitu-*.tar.gz | head -1)"
"$RESTORE" --archive "$newest" --savedir "$WORK/full/save" --bepinex "$WORK/full/state" > "$WORK/out" 2>&1
if diff -r "$SAVE/ServerManager" "$WORK/full/save/ServerManager" && diff -r "$WORK/state/Guilds" "$WORK/full/state/Guilds" && diff -r "$WORK/state/Marketplace" "$WORK/full/state/Marketplace" && diff -r "$WORK/state/Lembitu.Guilds" "$WORK/full/state/Lembitu.Guilds" && diff -r "$SAVE/cache" "$WORK/full/save/cache" && cmp "$SAVE/adminlist.txt" "$WORK/full/save/adminlist.txt" && [[ ! -e "$WORK/full/state/mod.cfg" ]]; then
  report ok "restores characters, guild vault, market, claims, cache and admission byte-identically without configuration"
else
  report fail "restores the complete server state"
fi
mkdir -p "$WORK/partial"
tar xzf "$newest" -C "$WORK/partial"
rm -rf "$WORK/partial/bepinex-state/Marketplace"
(cd "$WORK/partial" && tar czf "$WORK/partial.tar.gz" .)
if ! "$RESTORE" --archive "$WORK/partial.tar.gz" --savedir "$WORK/no-write" > "$WORK/out" 2>&1 && [[ ! -e "$WORK/no-write" ]]; then
  report ok "refuses a missing market before any destination writes"
else report fail "refuses a partial archive"; fi
if ! "$RESTORE" --archive "$newest" --savedir "$WORK/no-write" --world Midgard > "$WORK/out" 2>&1; then
  report ok "refuses world-only restore with global characters"
else report fail "refuses world-only restore with global characters"; fi
mv "$SAVE/ServerManager/characters" "$SAVE/ServerManager/missing"
if ! "$BACKUP" --savedir "$SAVE" --out "$WORK/refused" > "$WORK/out" 2>&1 && [[ ! -e "$WORK/refused" ]]; then
  report ok "refuses installed ServerManager without characters"
else report fail "refuses installed ServerManager without characters"; fi
mv "$SAVE/ServerManager/missing" "$SAVE/ServerManager/characters"
for missing in ServerManager bepinex-state/Guilds bepinex-state/Lembitu.Guilds INVENTORY.txt; do
  rm -rf "$WORK/partial"
  mkdir -p "$WORK/partial"
  tar xzf "$newest" -C "$WORK/partial"
  rm -rf "$WORK/partial/$missing"
  (cd "$WORK/partial" && tar czf "$WORK/partial.tar.gz" .)
  if ! "$RESTORE" --archive "$WORK/partial.tar.gz" --savedir "$WORK/no-write" > "$WORK/out" 2>&1 && [[ ! -e "$WORK/no-write" ]]; then
    report ok "refuses missing $missing before writes"
  else report fail "refuses missing $missing before writes"; fi
done
printf 'later admin\n' > "$WORK/full/save/adminlist.txt"
printf 'later cached biome\n' > "$WORK/full/save/cache/Midgard_biomedatacache.bin"
"$RESTORE" --archive "$newest" --savedir "$WORK/full/save" --bepinex "$WORK/full/state" --force > "$WORK/out" 2>&1
if cmp "$SAVE/adminlist.txt" "$WORK/full/save/adminlist.txt" && diff -r "$SAVE/cache" "$WORK/full/save/cache"; then
  report ok "replaces later admission and cache instead of mixing backup ages"
else report fail "replaces later admission and cache"; fi
"$RESTORE" --archive "$newest" --savedir "$WORK/full/save" --bepinex "$WORK/full/state" --dry-run > "$WORK/plan" 2>&1
plan_ok=true
for store in ServerManager cache adminlist.txt permittedlist.txt; do
  grep -Fq "would move aside: $WORK/full/save/$store" "$WORK/plan" || plan_ok=false
done
for store in Guilds Marketplace Lembitu.Guilds; do
  grep -Fq "would move aside: $WORK/full/state/$store" "$WORK/plan" || plan_ok=false
done
if $plan_ok; then report ok "dry run lists every present store including characters"; else report fail "dry run lists every present store"; fi
mkdir -p "$WORK/full/save/bannedlist.txt" 
printf 'later ban\n' > "$WORK/full/save/bannedlist.txt/entry"
"$RESTORE" --archive "$newest" --savedir "$WORK/full/save" --bepinex "$WORK/full/state" > "$WORK/out" 2>&1
if [[ ! -e "$WORK/full/save/bannedlist.txt" ]] && compgen -G "$WORK/full/save/bannedlist.txt.replaced-*" >/dev/null; then
  report ok "moves aside later admission store recorded absent"
else report fail "moves aside later admission store recorded absent"; fi
make_world "$WORK/absent/save" NoMods 1
"$BACKUP" --savedir "$WORK/absent/save" --out "$WORK/absent/backups" > "$WORK/absent/archive" 2>/dev/null
absent_archive="$(cat "$WORK/absent/archive")"
mkdir -p "$WORK/absent-target/state/Marketplace"
printf later > "$WORK/absent-target/state/Marketplace/NoMods.dat"
"$RESTORE" --archive "$absent_archive" --savedir "$WORK/absent-target/save" --bepinex "$WORK/absent-target/state" > "$WORK/out" 2>&1
if [[ ! -e "$WORK/absent-target/state/Marketplace" ]] && compgen -G "$WORK/absent-target/state/Marketplace.replaced-*" >/dev/null; then
  report ok "moves aside later market store recorded absent"
else report fail "moves aside later market store recorded absent"; fi
printf 'jobs: [one-off-save-and-stop]\n' > "$SAVE/ServerManager/cron.yml"
"$BACKUP" --savedir "$SAVE" --bepinex "$WORK/state" --out "$WORK/cron-backup" > "$WORK/cron-archive" 2>/dev/null
"$RESTORE" --archive "$(cat "$WORK/cron-archive")" --savedir "$WORK/cron/save" --bepinex "$WORK/cron/state" > "$WORK/out" 2>&1
if cmp "$REPO_ROOT/config/launch/servermanager-cron.yml" "$WORK/cron/save/ServerManager/cron.yml" && cmp "$SAVE/ServerManager/cron_last.yml" "$WORK/cron/save/ServerManager/cron_last.yml"; then
  report ok "restores idle cron instead of archived one-off jobs while preserving cron_last"
else report fail "restores idle cron and preserves cron_last"; fi

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

# --- 16. rotation keeps the newest by time, not by world label --------------------------------
# The archive name is `lembitu-<label>-<stamp>.tar.gz`, so sorting whole names compares labels first.
# With two labels in one directory that would delete the newest alpha archive while keeping an older
# zulu one. The newest two must survive regardless of what the labels sort like.

ROT2="$WORK/rot2"; mkdir -p "$ROT2"
# Fabricate the four archives directly: this case is about the rotation key, not about capturing.
touch -t 202609010000 "$ROT2/lembitu-alpha-20260901T000000Z.tar.gz"
touch -t 202609040000 "$ROT2/lembitu-zulu-20260904T000000Z.tar.gz"
touch -t 202609020000 "$ROT2/lembitu-alpha-20260902T000000Z.tar.gz"
touch -t 202609030000 "$ROT2/lembitu-zulu-20260903T000000Z.tar.gz"

if "$BACKUP" --savedir "$SNAP" --out "$ROT2" --keep 3 > "$WORK/out" 2>&1; then
  # Five archives exist once the run's own new one lands: the fabricated 0901, 0902, 0903, 0904 and
  # today's. The newest three by stamp are today's, zulu-0904 and zulu-0903; both alphas must go.
  # A label-first sort would instead have kept an alpha archive and deleted zulu-0904.
  if [ -e "$ROT2/lembitu-zulu-20260904T000000Z.tar.gz" ] \
     && [ -e "$ROT2/lembitu-zulu-20260903T000000Z.tar.gz" ] \
     && [ ! -e "$ROT2/lembitu-alpha-20260902T000000Z.tar.gz" ] \
     && [ ! -e "$ROT2/lembitu-alpha-20260901T000000Z.tar.gz" ]; then
    report ok "rotation keeps the newest archives by timestamp across different world labels"
  else
    report fail "rotation keeps the newest archives by timestamp across different world labels"
  fi
else
  report fail "rotation keeps the newest archives by timestamp across different world labels"
fi

# --- 17. the web map's data and the bounty ledgers travel with the other stores ----------------
# Both sit in the live server's bepinex config directory beside Guilds/ (the 2026-10-27 read of
# bicep). EpicLoot/BountySaves/ is a store inside a directory that is otherwise configuration, so
# only BountySaves/ is state.

PS="$WORK/plugin-stores"; PSTATE="$PS/state"
make_world "$PS/save" Run 1
mkdir -p "$PSTATE/Guilds" "$PSTATE/ValheimWebMap/Run" "$PSTATE/EpicLoot/BountySaves"
printf 'guild vault\n'           > "$PSTATE/Guilds/Run.dat"
printf 'explored mask \001\002\n' > "$PSTATE/ValheimWebMap/Run/explored.bin"
printf '{"sessions":[]}\n'       > "$PSTATE/ValheimWebMap/Run/history.json"
printf 'base map cache\n'        > "$PSTATE/ValheimWebMap/Run/map.png"
printf 'ledger one\n'            > "$PSTATE/EpicLoot/BountySaves/76561198000000001.json"
printf 'ledger two\n'            > "$PSTATE/EpicLoot/BountySaves/76561198000000002.json"
printf 'loot tables\n'           > "$PSTATE/EpicLoot/loottables.json"
plugin_files=(ValheimWebMap/Run/explored.bin ValheimWebMap/Run/history.json ValheimWebMap/Run/map.png
              EpicLoot/BountySaves/76561198000000001.json EpicLoot/BountySaves/76561198000000002.json)

ps_archive=""
if "$BACKUP" --savedir "$PS/save" --bepinex "$PSTATE" --out "$PS/backups" > "$PS/archive" 2> "$WORK/out"; then
  ps_archive="$(cat "$PS/archive")"
fi
captured_ok=false
if [[ -n "$ps_archive" ]]; then
  mkdir -p "$PS/x"
  tar xzf "$ps_archive" -C "$PS/x"
  captured_ok=true
  for f in "${plugin_files[@]}"; do
    sum="$(shasum -a 256 "$PSTATE/$f" | cut -d' ' -f1)"
    grep -Fxq "$sum  ./bepinex-state/$f" "$PS/x/INVENTORY.txt" || captured_ok=false
    cmp -s "$PSTATE/$f" "$PS/x/bepinex-state/$f" || captured_ok=false
  done
  [[ ! -e "$PS/x/bepinex-state/EpicLoot/loottables.json" ]] || captured_ok=false
  grep -Fxq 'store_bepinex-state/ValheimWebMap=present' "$PS/x/MANIFEST.txt" || captured_ok=false
  grep -Fxq 'store_bepinex-state/EpicLoot/BountySaves=present' "$PS/x/MANIFEST.txt" || captured_ok=false
  grep -q '^contents=.*,bepinex-state/ValheimWebMap,bepinex-state/EpicLoot/BountySaves$' "$PS/x/MANIFEST.txt" || captured_ok=false
fi
if $captured_ok; then
  report ok "captures ValheimWebMap and EpicLoot/BountySaves with their SHA-256 in INVENTORY, not EpicLoot's config"
else report fail "captures ValheimWebMap and EpicLoot/BountySaves into the archive and INVENTORY"; fi

for f in ValheimWebMap/Run/explored.bin EpicLoot/BountySaves/76561198000000001.json; do
  rm -rf "$PS/flip" "$PS/flip.tar.gz" "$PS/no-write"
  # One byte changed in place: same size, so only the hash can tell.
  if [[ -f "$PS/x/bepinex-state/$f" ]] && cp -a "$PS/x" "$PS/flip" \
     && printf 'X' | dd of="$PS/flip/bepinex-state/$f" bs=1 seek=0 conv=notrunc 2>/dev/null \
     && (cd "$PS/flip" && tar czf "$PS/flip.tar.gz" .) \
     && ! "$RESTORE" --archive "$PS/flip.tar.gz" --savedir "$PS/no-write/save" --bepinex "$PS/no-write/state" > "$WORK/out" 2>&1 \
     && grep -q 'inventory mismatch' "$WORK/out" && [[ ! -e "$PS/no-write" ]]; then
    report ok "inventory check catches a changed byte in $f before any write"
  else report fail "inventory check catches a changed byte in $f"; fi
done

# A fresh server: the map has not written its data yet and EpicLoot has config but no bounties.
mkdir -p "$PS/fresh/state/Guilds" "$PS/fresh/state/EpicLoot"
printf 'guild vault\n' > "$PS/fresh/state/Guilds/Run.dat"
printf 'loot tables\n' > "$PS/fresh/state/EpicLoot/loottables.json"
fresh_ok=false
if "$BACKUP" --savedir "$PS/save" --bepinex "$PS/fresh/state" --out "$PS/fresh/backups" > "$PS/fresh/archive" 2> "$WORK/out"; then
  fresh_manifest="$(tar xzOf "$(cat "$PS/fresh/archive")" ./MANIFEST.txt)"
  grep -Fxq 'store_bepinex-state/ValheimWebMap=absent' <<<"$fresh_manifest" \
    && grep -Fxq 'store_bepinex-state/EpicLoot/BountySaves=absent' <<<"$fresh_manifest" \
    && "$RESTORE" --archive "$(cat "$PS/fresh/archive")" --savedir "$PS/fresh/target/save" --bepinex "$PS/fresh/target/state" > "$WORK/out" 2>&1 \
    && cmp -s "$PS/fresh/state/Guilds/Run.dat" "$PS/fresh/target/state/Guilds/Run.dat" \
    && fresh_ok=true
fi
if $fresh_ok; then
  report ok "a fresh server without map data or bounty ledgers backs up, records them absent and restores"
else report fail "a missing ValheimWebMap or EpicLoot/BountySaves is tolerated"; fi

# Round trip into an empty target, then over a target holding later copies of both stores.
roundtrip_ok=false
if [[ -n "$ps_archive" ]] && "$RESTORE" --archive "$ps_archive" --savedir "$PS/empty/save" --bepinex "$PS/empty/state" > "$WORK/out" 2>&1 \
   && diff -r "$PSTATE/ValheimWebMap" "$PS/empty/state/ValheimWebMap" > /dev/null \
   && diff -r "$PSTATE/EpicLoot/BountySaves" "$PS/empty/state/EpicLoot/BountySaves" > /dev/null; then
  roundtrip_ok=true
fi
if $roundtrip_ok; then report ok "restores ValheimWebMap and EpicLoot/BountySaves into an empty target"
else report fail "restores ValheimWebMap and EpicLoot/BountySaves into an empty target"; fi

LATER="$PS/later/state"
mkdir -p "$LATER/ValheimWebMap/Run" "$LATER/EpicLoot/BountySaves"
printf 'later mask\n'         > "$LATER/ValheimWebMap/Run/explored.bin"
printf 'later ledger\n'       > "$LATER/EpicLoot/BountySaves/76561198000000009.json"
printf 'target loot tables\n' > "$LATER/EpicLoot/loottables.json"
aside_ok=false
if [[ -n "$ps_archive" ]] && "$RESTORE" --archive "$ps_archive" --savedir "$PS/later/save" --bepinex "$LATER" > "$WORK/out" 2>&1 \
   && diff -r "$PSTATE/ValheimWebMap" "$LATER/ValheimWebMap" > /dev/null \
   && diff -r "$PSTATE/EpicLoot/BountySaves" "$LATER/EpicLoot/BountySaves" > /dev/null \
   && map_aside="$(find "$LATER" -maxdepth 1 -name 'ValheimWebMap.replaced-*')" \
   && bounty_aside="$(find "$LATER/EpicLoot" -maxdepth 1 -name 'BountySaves.replaced-*')" \
   && grep -Fxq 'later mask' "$map_aside/Run/explored.bin" \
   && grep -Fxq 'later ledger' "$bounty_aside/76561198000000009.json" \
   && grep -Fxq 'target loot tables' "$LATER/EpicLoot/loottables.json"; then
  aside_ok=true
fi
if $aside_ok; then
  report ok "restore over later copies moves both stores aside and leaves EpicLoot's config alone"
else report fail "restore over later ValheimWebMap and EpicLoot/BountySaves moves them aside"; fi

# --- 18. an archive made before the two stores existed leaves the live copies alone -------------
# Every archive taken before #131 lacks ValheimWebMap and EpicLoot/BountySaves and has no MANIFEST
# line for them: the backup never looked. Restoring one (even with --force) must not move aside or
# remove the live map data and ledgers. Only a recorded `=absent` replaces a target with nothing.

# shellcheck source=../scripts/lib/save-format.sh
. "$REPO_ROOT/scripts/lib/save-format.sh"

# The pre-#131 shape, from section 17's archive: the two stores, their MANIFEST lines and their
# `contents=` entries gone, and INVENTORY.txt recomputed, as the restore checks it.
OLD="$PS/old"; old_archive=""
if [[ -n "$ps_archive" ]]; then
  mkdir -p "$OLD"
  cp -a "$PS/x" "$OLD/tree"
  rm -rf "$OLD/tree/bepinex-state/ValheimWebMap" "$OLD/tree/bepinex-state/EpicLoot"
  grep -v -e '^store_bepinex-state/ValheimWebMap=' -e '^store_bepinex-state/EpicLoot/BountySaves=' "$PS/x/MANIFEST.txt" \
    | sed 's|,bepinex-state/ValheimWebMap,bepinex-state/EpicLoot/BountySaves$||' > "$OLD/tree/MANIFEST.txt"
  store_inventory "$OLD/tree" > "$OLD/inventory"
  mv "$OLD/inventory" "$OLD/tree/INVENTORY.txt"
  (cd "$OLD/tree" && tar czf "$OLD/old.tar.gz" .) && old_archive="$OLD/old.tar.gz"
fi

make_live_state() {  # make_live_state <bepinex dir>: later copies of both stores and of Guilds
  mkdir -p "$1/ValheimWebMap/Run" "$1/EpicLoot/BountySaves" "$1/Guilds"
  printf 'live mask\n'   > "$1/ValheimWebMap/Run/explored.bin"
  printf 'live ledger\n' > "$1/EpicLoot/BountySaves/76561198000000009.json"
  printf 'later guild\n' > "$1/Guilds/Run.dat"
}
# Both live stores are exactly as they were, nothing of them moved aside, and Guilds came from the archive.
live_stores_kept() {  # live_stores_kept <bepinex dir>
  grep -Fxq 'live mask' "$1/ValheimWebMap/Run/explored.bin" \
    && grep -Fxq 'live ledger' "$1/EpicLoot/BountySaves/76561198000000009.json" \
    && [[ "$(find "$1/ValheimWebMap" "$1/EpicLoot/BountySaves" -type f | wc -l)" -eq 2 ]] \
    && [[ -z "$(find "$1" -name 'ValheimWebMap.replaced-*' -o -name 'BountySaves.replaced-*')" ]] \
    && grep -Fxq 'guild vault' "$1/Guilds/Run.dat"
}

OT="$OLD/target"; make_live_state "$OT/state"
if [[ -n "$old_archive" ]] && ! grep -q 'ValheimWebMap\|BountySaves' "$OLD/tree/MANIFEST.txt" \
   && "$RESTORE" --archive "$old_archive" --savedir "$OT/save" --bepinex "$OT/state" --dry-run > "$WORK/out" 2>&1 \
   && grep -Fxq "not in this archive (older format): would leave as is: $OT/state/ValheimWebMap" "$WORK/out" \
   && grep -Fxq "not in this archive (older format): would leave as is: $OT/state/EpicLoot/BountySaves" "$WORK/out" \
   && ! grep -Fq -e "would move aside: $OT/state/ValheimWebMap" -e "would move aside: $OT/state/EpicLoot/BountySaves" "$WORK/out" \
   && grep -Fq "would move aside: $OT/state/Guilds" "$WORK/out"; then
  report ok "dry run of an archive older than the two stores says it leaves them as is"
else report fail "dry run of an archive older than the two stores says it leaves them as is"; fi

if [[ -n "$old_archive" ]] && "$RESTORE" --archive "$old_archive" --savedir "$OT/save" --bepinex "$OT/state" > "$WORK/out" 2>&1 \
   && grep -Fxq "not in this archive (older format): left as is: $OT/state/ValheimWebMap" "$WORK/out" \
   && grep -Fxq "not in this archive (older format): left as is: $OT/state/EpicLoot/BountySaves" "$WORK/out" \
   && live_stores_kept "$OT/state"; then
  report ok "restoring an archive older than the two stores leaves the live map data and ledgers in place"
else report fail "restoring an archive older than the two stores leaves the live map data and ledgers in place"; fi

OF="$OLD/forced"; make_live_state "$OF/state"
if [[ -n "$old_archive" ]] && "$RESTORE" --archive "$old_archive" --savedir "$OF/save" --bepinex "$OF/state" --force > "$WORK/out" 2>&1 \
   && live_stores_kept "$OF/state"; then
  report ok "a forced restore of an archive older than the two stores leaves them in place"
else report fail "a forced restore of an archive older than the two stores leaves them in place"; fi

# The contrast: section 17's fresh-server archive records both `=absent`, so a restore replaces the
# live copies with nothing, moving them aside.
OA="$OLD/recorded-absent"; make_live_state "$OA/state"
if [[ -s "$PS/fresh/archive" ]] && "$RESTORE" --archive "$(cat "$PS/fresh/archive")" --savedir "$OA/save" --bepinex "$OA/state" > "$WORK/out" 2>&1 \
   && [[ ! -e "$OA/state/ValheimWebMap" && ! -e "$OA/state/EpicLoot/BountySaves" ]] \
   && [[ -n "$(find "$OA/state" -maxdepth 1 -name 'ValheimWebMap.replaced-*')" ]] \
   && [[ -n "$(find "$OA/state/EpicLoot" -maxdepth 1 -name 'BountySaves.replaced-*')" ]]; then
  report ok "an archive recording both stores absent still moves the live copies aside"
else report fail "an archive recording both stores absent still moves the live copies aside"; fi

# --- 19. --root: the Workload's volume ---------------------------------------------------------
# The Pod's volume is <root>/save (the -savedir), <root>/bepinex (the plugin stores), <root>/dedicated
# (SeparateSpawns' root) and <root>/bepinex/SeparateSpawns/reports, and on astral-bicep after the
# cutover it is /state/lembitu/world. --root reads exactly what the four options name.

RT="$WORK/root"; VOL="$RT/volume"
make_world "$VOL/save" Run 1
mkdir -p "$VOL/bepinex/Guilds" "$VOL/bepinex/ValheimWebMap/Run" "$VOL/bepinex/EpicLoot/BountySaves" \
  "$VOL/bepinex/SeparateSpawns/reports/1" "$VOL/dedicated/SeparateSpawns/worlds"
printf 'guild vault\n'  > "$VOL/bepinex/Guilds/Run.dat"
printf 'mask\n'         > "$VOL/bepinex/ValheimWebMap/Run/explored.bin"
printf 'ledger\n'       > "$VOL/bepinex/EpicLoot/BountySaves/76561198000000001.json"
printf 'report\n'       > "$VOL/bepinex/SeparateSpawns/reports/1/summary.txt"
printf '{}\n'           > "$VOL/dedicated/SeparateSpawns/worlds/1.json"
listing() {  # listing <archive>: its paths, without the two files that name the capture's time
  tar tzf "$1" | grep -v -e '^\./MANIFEST\.txt$' -e '^\./STATE-TIMES\.txt$' | LC_ALL=C sort
}
root_ok=false
if "$BACKUP" --root "$VOL" --out "$RT/by-root" > "$RT/root-archive" 2> "$WORK/out" \
   && "$BACKUP" --savedir "$VOL/save" --bepinex "$VOL/bepinex" --dedicated "$VOL/dedicated" \
        --reports "$VOL/bepinex/SeparateSpawns/reports" --out "$RT/by-dirs" > "$RT/dirs-archive" 2> "$WORK/out" \
   && diff <(listing "$(cat "$RT/root-archive")") <(listing "$(cat "$RT/dirs-archive")") > /dev/null \
   && tar xzOf "$(cat "$RT/root-archive")" ./bepinex-state/Guilds/Run.dat | grep -Fxq 'guild vault' \
   && tar xzOf "$(cat "$RT/root-archive")" ./bepinex-state/EpicLoot/BountySaves/76561198000000001.json | grep -Fxq 'ledger' \
   && tar xzOf "$(cat "$RT/root-archive")" ./dedicated/SeparateSpawns/worlds/1.json | grep -Fxq '{}' \
   && tar xzOf "$(cat "$RT/root-archive")" ./bepinex-state/SeparateSpawns/reports/1/summary.txt | grep -Fxq 'report'; then
  root_ok=true
fi
if $root_ok; then report ok "--root captures the volume's save, plugin and SeparateSpawns stores: the same archive as the four options"
else report fail "--root captures the volume's save, plugin and SeparateSpawns stores: the same archive as the four options"; fi

if [[ -s "$RT/root-archive" ]] && "$RESTORE" --archive "$(cat "$RT/root-archive")" --root "$RT/restored" > "$WORK/out" 2>&1 \
   && diff -r "$VOL/save/worlds_local" "$RT/restored/save/worlds_local" > /dev/null \
   && cmp -s "$VOL/bepinex/Guilds/Run.dat" "$RT/restored/bepinex/Guilds/Run.dat" \
   && diff -r "$VOL/bepinex/ValheimWebMap" "$RT/restored/bepinex/ValheimWebMap" > /dev/null; then
  report ok "restore --root puts the world in <root>/save and the stores in <root>/bepinex"
else report fail "restore --root puts the world in <root>/save and the stores in <root>/bepinex"; fi

refused_both() {  # refused_both <extra option> <its value>: --root with it is refused by both scripts
  ! "$BACKUP" --root "$VOL" "$1" "$2" --out "$RT/both" > "$WORK/out" 2>&1 \
    && grep -q -- '--root replaces --savedir, --bepinex, --dedicated and --reports' "$WORK/out" && [[ ! -e "$RT/both" ]] \
    && ! "$RESTORE" --archive "$(cat "$RT/root-archive")" --root "$RT/both" "$1" "$2" > "$WORK/out" 2>&1 \
    && grep -q -- '--root replaces --savedir, --bepinex, --dedicated and --reports' "$WORK/out" && [[ ! -e "$RT/both" ]]
}
if refused_both --savedir "$VOL/save" && refused_both --bepinex "$RT/elsewhere" \
   && refused_both --dedicated "$RT/elsewhere" && refused_both --reports "$RT/elsewhere"; then
  report ok "--root with --savedir, --bepinex, --dedicated or --reports is refused, by both scripts"
else report fail "--root with --savedir, --bepinex, --dedicated or --reports is refused, by both scripts"; fi

# --- 20. SeparateSpawns' roster, world layouts and reports (#133) ------------------------------
# Its root holds the roster (who belongs to which start region) and each world's layout (the start
# regions and Eikthyr altars; without it the mod lays out new ones), and its reports sit beside its
# plugin. On today's container both are in the game tree (~/lembitu/data/bepinex/config/bepinex and
# .../BepInEx/plugins/SeparateSpawns/reports), named by --dedicated and --reports; on the Pool they
# are <root>/dedicated and <root>/bepinex/SeparateSpawns/reports. The root's .cfg is configuration
# and stays out.

SP="$WORK/spawns"
make_spawns() {  # make_spawns <dedicated dir> <reports dir> <tag>
  mkdir -p "$1/SeparateSpawns/worlds" "$2/2270623796"
  printf '{"Skadi": ["%s"]}\n' "$3"        > "$1/SeparateSpawns.groups.json"
  printf '{"Frozen": true, "tag": "%s"}\n' "$3" > "$1/SeparateSpawns/worlds/2270623796.json"
  printf 'layout report %s\n' "$3"          > "$2/2270623796/summary.txt"
  printf '[General]\nInnerRadius = 1200\n'  > "$1/abortipus.separatespawns.cfg"
}
spawn_files=(dedicated/SeparateSpawns.groups.json dedicated/SeparateSpawns/worlds/2270623796.json
             bepinex-state/SeparateSpawns/reports/2270623796/summary.txt)
spawn_lines=(store_dedicated/SeparateSpawns.groups.json store_dedicated/SeparateSpawns/worlds
             store_bepinex-state/SeparateSpawns/reports)
# Today's container: the save and plugin stores under ~/lembitu/config, SeparateSpawns in the game tree.
LIVE="$SP/live"; LIVE_DED="$LIVE/data/bepinex/config/bepinex"; LIVE_REP="$LIVE/data/bepinex/BepInEx/plugins/SeparateSpawns/reports"
make_world "$LIVE/config/save" Run 1
mkdir -p "$LIVE/config/bepinex/Guilds"; printf 'guild vault\n' > "$LIVE/config/bepinex/Guilds/Run.dat"
make_spawns "$LIVE_DED" "$LIVE_REP" live
live_source() {  # live_source <archive path>: where the live tree keeps it
  case "$1" in
    dedicated/*) printf '%s/%s\n' "$LIVE_DED" "${1#dedicated/}" ;;
    bepinex-state/SeparateSpawns/reports/*) printf '%s/%s\n' "$LIVE_REP" "${1#bepinex-state/SeparateSpawns/reports/}" ;;
  esac
}
sp_archive=""
"$BACKUP" --savedir "$LIVE/config/save" --dedicated "$LIVE_DED" --reports "$LIVE_REP" --out "$SP/backups" > "$SP/archive" 2> "$WORK/out" \
  && sp_archive="$(cat "$SP/archive")"
captured_ok=false
if [[ -n "$sp_archive" ]]; then
  mkdir -p "$SP/x"; tar xzf "$sp_archive" -C "$SP/x"
  captured_ok=true
  for f in "${spawn_files[@]}"; do
    sum="$(shasum -a 256 "$(live_source "$f")" | cut -d' ' -f1)"
    grep -Fxq "$sum  ./$f" "$SP/x/INVENTORY.txt" || captured_ok=false
    cmp -s "$(live_source "$f")" "$SP/x/$f" || captured_ok=false
  done
  for l in "${spawn_lines[@]}"; do grep -Fxq "$l=present" "$SP/x/MANIFEST.txt" || captured_ok=false; done
  [[ -z "$(find "$SP/x" -name '*.cfg')" ]] || captured_ok=false
  grep -q '^contents=.*,dedicated/SeparateSpawns.groups.json,dedicated/SeparateSpawns/worlds,bepinex-state/SeparateSpawns/reports$' "$SP/x/MANIFEST.txt" || captured_ok=false
  ! grep -q '^not_captured=' "$SP/x/MANIFEST.txt" || captured_ok=false
fi
if $captured_ok; then
  report ok "captures today's SeparateSpawns roster, layout and reports with their SHA-256 in INVENTORY and MANIFEST, not its .cfg"
else report fail "captures today's SeparateSpawns roster, layout and reports into the archive, INVENTORY and MANIFEST"; fi

for f in dedicated/SeparateSpawns.groups.json dedicated/SeparateSpawns/worlds/2270623796.json \
         bepinex-state/SeparateSpawns/reports/2270623796/summary.txt; do
  rm -rf "$SP/flip" "$SP/flip.tar.gz" "$SP/no-write"
  if [[ -f "$SP/x/$f" ]] && cp -a "$SP/x" "$SP/flip" \
     && printf 'X' | dd of="$SP/flip/$f" bs=1 seek=0 conv=notrunc 2>/dev/null \
     && (cd "$SP/flip" && tar czf "$SP/flip.tar.gz" .) \
     && ! "$RESTORE" --archive "$SP/flip.tar.gz" --root "$SP/no-write" > "$WORK/out" 2>&1 \
     && grep -q 'inventory mismatch' "$WORK/out" && [[ ! -e "$SP/no-write" ]]; then
    report ok "inventory check catches a changed byte in $f before any write"
  else report fail "inventory check catches a changed byte in $f"; fi
done

# The Pool's layout: today's archive restores into a new volume, and the volume's own archive is
# the same stores again.
POD="$SP/pod"
pod_ok=false
if [[ -n "$sp_archive" ]] && "$RESTORE" --archive "$sp_archive" --root "$POD" > "$WORK/out" 2>&1 \
   && cmp -s "$LIVE_DED/SeparateSpawns.groups.json" "$POD/dedicated/SeparateSpawns.groups.json" \
   && diff -r "$LIVE_DED/SeparateSpawns/worlds" "$POD/dedicated/SeparateSpawns/worlds" > /dev/null \
   && diff -r "$LIVE_REP" "$POD/bepinex/SeparateSpawns/reports" > /dev/null \
   && [[ ! -e "$POD/dedicated/abortipus.separatespawns.cfg" ]] \
   && "$BACKUP" --root "$POD" --out "$SP/pod-backups" > "$SP/pod-archive" 2> "$WORK/out" \
   && diff <(tar xzOf "$sp_archive" ./INVENTORY.txt | grep -e '  \./dedicated/' -e '  \./bepinex-state/SeparateSpawns/') \
           <(tar xzOf "$(cat "$SP/pod-archive")" ./INVENTORY.txt | grep -e '  \./dedicated/' -e '  \./bepinex-state/SeparateSpawns/') > /dev/null; then
  pod_ok=true
fi
if $pod_ok; then report ok "today's archive restores the roster, layout and reports into the Pool's layout (--root), and backs up from there the same"
else report fail "today's archive restores the roster, layout and reports into the Pool's layout (--root), and backs up from there the same"; fi

# The rollback: the Pool's archive restores into today's paths, over later copies, which move aside.
make_spawns "$SP/back/dedicated" "$SP/back/reports" later
make_world "$SP/back/save" Run 1
back_ok=false
if [[ -s "$SP/pod-archive" ]] \
   && "$RESTORE" --archive "$(cat "$SP/pod-archive")" --savedir "$SP/back/save" --dedicated "$SP/back/dedicated" \
        --reports "$SP/back/reports" > "$WORK/out" 2>&1 \
   && grep -Fq '"live"' "$SP/back/dedicated/SeparateSpawns.groups.json" \
   && grep -Fq '"live"' "$SP/back/dedicated/SeparateSpawns/worlds/2270623796.json" \
   && grep -Fxq 'layout report live' "$SP/back/reports/2270623796/summary.txt" \
   && grep -Fq '"later"' "$(find "$SP/back/dedicated" -maxdepth 1 -name 'SeparateSpawns.groups.json.replaced-*')" \
   && grep -Fq '"later"' "$(find "$SP/back/dedicated/SeparateSpawns" -maxdepth 1 -name 'worlds.replaced-*')/2270623796.json" \
   && [[ -n "$(find "$SP/back" -maxdepth 1 -name 'reports.replaced-*')" ]] \
   && grep -Fxq 'InnerRadius = 1200' "$SP/back/dedicated/abortipus.separatespawns.cfg"; then
  back_ok=true
fi
if $back_ok; then report ok "the Pool's archive restores into today's paths, moving the later roster, layout and reports aside, the .cfg untouched"
else report fail "the Pool's archive restores into today's paths, moving the later roster, layout and reports aside"; fi

# Missing: a volume where SeparateSpawns has written nothing yet backs up, records all three absent,
# and restores.
EMPTY="$SP/empty"; make_world "$EMPTY/save" Run 1
absent_ok=false
if "$BACKUP" --root "$EMPTY" --out "$SP/empty-backups" > "$SP/empty-archive" 2> "$WORK/out"; then
  manifest="$(tar xzOf "$(cat "$SP/empty-archive")" ./MANIFEST.txt)"
  absent_ok=true
  for l in "${spawn_lines[@]}"; do grep -Fxq "$l=absent" <<< "$manifest" || absent_ok=false; done
  "$RESTORE" --archive "$(cat "$SP/empty-archive")" --root "$SP/empty-target" > "$WORK/out" 2>&1 || absent_ok=false
  [[ ! -e "$SP/empty-target/dedicated/SeparateSpawns.groups.json" ]] || absent_ok=false
fi
if $absent_ok; then report ok "a volume without SeparateSpawns' stores backs up, records the three absent and restores"
else report fail "a volume without SeparateSpawns' stores backs up, records the three absent and restores"; fi

# Today's unit, not told where SeparateSpawns keeps its state: the archive says so, records no store
# line, and a restore leaves the target's copies as they are, --force included (#131's rule).
untold_ok=false
keep_target() {  # keep_target <dir>: a Pool volume whose SeparateSpawns stores must survive
  make_world "$1/save" Run 1; make_spawns "$1/dedicated" "$1/bepinex/SeparateSpawns/reports" kept
}
kept() {  # kept <dir>: its three stores as keep_target made them, nothing moved aside
  grep -Fq '"kept"' "$1/dedicated/SeparateSpawns.groups.json" \
    && grep -Fq '"kept"' "$1/dedicated/SeparateSpawns/worlds/2270623796.json" \
    && grep -Fxq 'layout report kept' "$1/bepinex/SeparateSpawns/reports/2270623796/summary.txt" \
    && [[ -z "$(find "$1/dedicated" "$1/bepinex/SeparateSpawns" -name '*.replaced-*')" ]]
}
if "$BACKUP" --savedir "$LIVE/config/save" --out "$SP/untold-backups" > "$SP/untold-archive" 2> "$WORK/out"; then
  untold="$(cat "$SP/untold-archive")"
  manifest="$(tar xzOf "$untold" ./MANIFEST.txt)"
  keep_target "$SP/untold-target"; keep_target "$SP/untold-forced"
  grep -Fxq 'not_captured=dedicated (no --dedicated),bepinex-state/SeparateSpawns/reports (no --reports)' <<< "$manifest" \
    && ! grep -q -e '^store_dedicated/' -e '^store_bepinex-state/SeparateSpawns/' <<< "$manifest" \
    && ! tar tzf "$untold" | grep -q -e '^\./dedicated' -e 'SeparateSpawns' \
    && "$RESTORE" --archive "$untold" --root "$SP/untold-target" > "$WORK/out" 2>&1 \
    && grep -Fq "not in this archive (older format): left as is: $SP/untold-target/dedicated/SeparateSpawns/worlds" "$WORK/out" \
    && kept "$SP/untold-target" \
    && "$RESTORE" --archive "$untold" --root "$SP/untold-forced" --force > "$WORK/out" 2>&1 \
    && kept "$SP/untold-forced" && untold_ok=true
fi
if $untold_ok; then report ok "an archive not told where SeparateSpawns' stores are says so, and a restore (--force too) leaves the target's copies"
else report fail "an archive not told where SeparateSpawns' stores are says so, and a restore (--force too) leaves the target's copies"; fi

# An archive from before #133 has neither the stores nor their lines.
old_ok=false
if [[ -n "$sp_archive" ]]; then
  rm -rf "$SP/old"; cp -a "$SP/x" "$SP/old"
  rm -rf "$SP/old/dedicated" "$SP/old/bepinex-state/SeparateSpawns"
  grep -v -e '^store_dedicated/' -e '^store_bepinex-state/SeparateSpawns/' "$SP/x/MANIFEST.txt" > "$SP/old/MANIFEST.txt"
  store_inventory "$SP/old" > "$SP/old-inventory"; mv "$SP/old-inventory" "$SP/old/INVENTORY.txt"
  (cd "$SP/old" && tar czf "$SP/old.tar.gz" .)
  keep_target "$SP/old-target"; keep_target "$SP/old-forced"
  "$RESTORE" --archive "$SP/old.tar.gz" --root "$SP/old-target" --dry-run > "$WORK/out" 2>&1 \
    && grep -Fxq "not in this archive (older format): would leave as is: $SP/old-target/dedicated/SeparateSpawns.groups.json" "$WORK/out" \
    && "$RESTORE" --archive "$SP/old.tar.gz" --root "$SP/old-target" > "$WORK/out" 2>&1 && kept "$SP/old-target" \
    && "$RESTORE" --archive "$SP/old.tar.gz" --root "$SP/old-forced" --force > "$WORK/out" 2>&1 && kept "$SP/old-forced" \
    && old_ok=true
fi
if $old_ok; then report ok "an archive from before #133 leaves the target's roster, layout and reports in place, --force included"
else report fail "an archive from before #133 leaves the target's roster, layout and reports in place, --force included"; fi

# An archive that holds them, restored with no destination for them, leaves them out and says so.
leftout_ok=false
if [[ -n "$sp_archive" ]] \
   && "$RESTORE" --archive "$sp_archive" --savedir "$SP/nodest/config/save" > "$WORK/out" 2>&1 \
   && grep -Fq 'left out: dedicated/SeparateSpawns/worlds (the archive records it' "$WORK/out" \
   && grep -Fq 'give --reports to restore it' "$WORK/out" \
   && [[ -z "$(find "$SP/nodest" -path '*SeparateSpawns*')" ]]; then
  leftout_ok=true
fi
if $leftout_ok; then report ok "with no --dedicated or --reports a restore leaves SeparateSpawns' stores out and names the options"
else report fail "with no --dedicated or --reports a restore leaves SeparateSpawns' stores out and names the options"; fi

# As root on the volume, the restore gives what it wrote to the volume's owner (the server's uid):
# tar and cp -a keep the archive's owner, the backup's user. id and chown are stubbed.
mkdir -p "$SP/stub"
cat > "$SP/stub/id" <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == -u ]]; then echo 0; else exec $(command -v id) "\$@"; fi
EOF
cat > "$SP/stub/chown" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$SP/chown.log"
EOF
chmod +x "$SP/stub/id" "$SP/stub/chown"
owner_ok=false
if [[ -n "$sp_archive" ]] \
   && PATH="$SP/stub:$PATH" "$RESTORE" --archive "$sp_archive" --root "$SP/owned" > "$WORK/out" 2>&1 \
   && [[ "$(cat "$SP/chown.log")" == "-R --reference=$SP/owned -- $SP/owned/save $SP/owned/bepinex $SP/owned/dedicated" ]] \
   && rm -f "$SP/chown.log" \
   && PATH="$SP/stub:$PATH" "$RESTORE" --archive "$sp_archive" --savedir "$SP/owned-savedir/save" > "$WORK/out" 2>&1 \
   && [[ ! -e "$SP/chown.log" ]] \
   && "$RESTORE" --archive "$sp_archive" --root "$SP/owned-user" > "$WORK/out" 2>&1 \
   && ! grep -q '^gave: ' "$WORK/out"; then
  owner_ok=true
fi
if $owner_ok; then report ok "as root, restore --root gives save/, bepinex/ and dedicated/ to the volume's owner; not otherwise"
else report fail "as root, restore --root gives save/, bepinex/ and dedicated/ to the volume's owner; not otherwise"; fi

# The mod writes its roster and layouts while the server runs: a change during the copy is noticed
# and the copy taken again, as for the plugin stores. A fake cp changes the store right after
# copying it, once.
mkdir -p "$SP/cpstub"
cat > "$SP/cpstub/cp" <<EOF
#!/usr/bin/env bash
if [[ " \$* " == *" \$SPAWN_BUMP_SRC "* && ! -e "\$SPAWN_BUMP_MARKER" ]]; then
  rc=0; $(command -v cp) "\$@" || rc=\$?
  : > "\$SPAWN_BUMP_MARKER"; printf 'bumped\n' >> "\$SPAWN_BUMP_FILE"
  exit \$rc
fi
exec $(command -v cp) "\$@"
EOF
chmod +x "$SP/cpstub/cp"
bumped() {  # bumped <source as cp is given it> <file it changes> <that file's archive path>
  local tree="$SP/bump-$RANDOM"
  make_world "$tree/save" Run 1; make_spawns "$tree/ded" "$tree/rep" live
  local src="$tree/$1" file="$tree/$2"
  SPAWN_BUMP_SRC="$src" SPAWN_BUMP_FILE="$file" SPAWN_BUMP_MARKER="$tree/bumped" PATH="$SP/cpstub:$PATH" \
    "$BACKUP" --savedir "$tree/save" --dedicated "$tree/ded" --reports "$tree/rep" --out "$tree/out" > "$tree/archive" 2> "$WORK/out" \
    && [[ -e "$tree/bumped" ]] && grep -q 'a save committed during the copy' "$WORK/out" \
    && tar xzOf "$(cat "$tree/archive")" "./$3" | grep -Fxq bumped
}
if bumped ded/SeparateSpawns.groups.json ded/SeparateSpawns.groups.json dedicated/SeparateSpawns.groups.json \
   && bumped ded/SeparateSpawns/worlds ded/SeparateSpawns/worlds/2270623796.json dedicated/SeparateSpawns/worlds/2270623796.json \
   && bumped rep rep/2270623796/summary.txt bepinex-state/SeparateSpawns/reports/2270623796/summary.txt; then
  report ok "a roster, layout or report changed during the copy is noticed, and the capture taken again"
else report fail "a roster, layout or report changed during the copy is noticed, and the capture taken again"; fi

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]
