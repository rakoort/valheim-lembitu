# Documentation reconciliation record

Date: 2026-09-15
Scope: `docs/rules.md`, `CONTEXT.md`, `docs/modstack.md`, `docs/modstack.lock.json`,
`docs/build.md`, `docs/adr/`, and the four wiki pages (`pack.md`, `building.md`,
`native-testing.md`, `operations.md`), reconciled against the shipped source, configuration and
recorded evidence at commit `90fd9be` plus this change set (#22).

This is a record, not a rewrite. Where a document disagreed with the shipped stack, either the
document was corrected here or the disagreement is listed as open. Historical test records keep
their dates and scope; nothing that failed became a success because the prose changed.

## Corrections made in this change set

| Document | Claim | Shipped reality | Action |
| --- | --- | --- | --- |
| `README.md:15` | `scripts/install-plugins.sh ~/.cache/valheim-lembitu/server/BepInEx/plugins` | The installer refuses a `plugins/` target: `the target is the BepInEx directory itself, not its plugins subdirectory` (`scripts/install-plugins.sh:100-102`). Verified by running it. `docs/build.md:56` already had the correct `…/BepInEx`. | Corrected to `…/BepInEx`. |
| `docs/wiki/operations.md` | The Roster is fifteen invited, whitelisted players; the backup requirement is to capture the chunked world, Clan registry and character store together | The owner replaced admission with a public, password-protected server, and the character store is client-owned by decision (ADR-0010), so a server backup cannot capture it. | Admission rewritten and recorded as ADR-0007's 2026-09-15 amendment; the backup section states what is captured and what deliberately is not. |
| `config/launch/launch.env.example` | World rules came from `-preset hard` with three rules left implicit, and the freeze used `UPDATE_CRON=0 0 1 1 * 2100` | Both were wrong. `-preset` assigns the whole modifier set, so the three implicit rules took the preset's values, not vanilla. A six-field cron line is invalid: busybox cron takes five fields, so `2100` became the command word, and `valheim-bootstrap` gates the line on `[ -n "$UPDATE_CRON" ]`, making an empty value the container's real disable. | All five rules are now explicit `-modifier` arguments and were verified from the game's own parse lines; `UPDATE_CRON` is empty. |
| `docs/wiki/building.md` | ValheimRAFT's stale `ServerSync.dll` reference is inert because nothing registers a synced config entry | Falsified on the client: a real session logged eight `MissingFieldException: Field not found: .ZRoutedRpc.Everybody` from `ConfigEntry<T>.<ctor>b__10_0` via `ConfigFile.OnSettingChanged`. BepInEx swallows them, so the session was unaffected and the server log showed none. | Corrected in place; severity left unmeasured and handed to #26. |

## Second reconciliation — 2026-09-16

Scope: the whole enforced-configuration surface, read key-by-key against the running server, plus
the mod assemblies where a claim depended on behaviour rather than on a config file. This round
found more falsified claims than the first, because the first compared documents to documents and
this one compared documents to a live server.

| Document | Claim | Reality | Action |
| --- | --- | --- | --- |
| `docs/wiki/operations.md`, `docs/rules.md` | The enforced overlay's values are the server's behaviour | Ten of forty-six pinned keys were at mod defaults on the live server, including the difficulty tier. The overlay had been applied once by hand and nothing ever compared the result | Drift recorded as a dated measurement; ADR-0011 decides assert-on-boot plus verification; #68 applies, #69 builds the check |
| `docs/adr/0005`, `docs/wiki/operations.md` | "Nothing else is key-locked: building, cooking, eating, repairs, portals and boats stay open" | Still true of the mod's capability, no longer true of the decision: cooking and eating are now key-locked. The earlier text also omitted that every lock is material-scoped, which is what makes locking food acceptable | ADR-0005 carries a dated 2026-09-16 amendment; the wiki and rules pages updated |
| `docs/wiki/operations.md` | "the mod's own skill manager off because character level owns progression" | The skill manager is not a power curve: it governs vanilla skill drain and caps. It is now on, with the ceiling pinned at 100 and the floor driven by boss keys | Corrected in place; the mechanism is recorded in `docs/research.md` from `SkillsManager.UpdateCache` |
| `docs/rules.md:150` (pre-edit) | The tombstone-looting row was presented as a property of the dead player | PvPBiomeDominions' rules are area-scoped, and with every biome on `PlayerChoose` the effective area is the *acting* player's flag, so a flagged player may loot an unflagged grave. Observed by the owner | Corrected, and the intended rule moved to #67, which needs a plugin |
| `docs/build.md:41`, `scripts/build-client-pack.sh` comments | The client pack's doorstop dylib loads the pack for a Mac player | True only under Rosetta. The shipped dylib is x86_64 only and Valheim 1.0's macOS client is arm64, so native injection fails; the community route is forcing the x86_64 slice | Corrected; both Mac players are playing through that route |
| `docs/modstack.md` | The pin table described the stack, with no statement of which side each mod runs on | Fifteen mods are enforced on clients by the server's own version exchange, three more are needed client-side without being enforced, three are server-only and three client-only. Nothing recorded it, and the client Pack shipped four packages a client cannot use | New "Where each mod runs" section, derived from the live version announcements; client-only mods dropped; #70 trims the Pack |
| `docs/wiki/pack.md` | Effect thinning and the rarity palette are both client-side concerns | Half right. The palette is client-side, but `loottables.json` is pushed to every client at join, so the effect patch must be server-side | Corrected; #73 carries the verified patch format and placement |
| `docs/modstack.md`, `docs/adr/0004` | Gear tier includes bounties | Adventure Mode is off as of 2026-09-16, removing bounties, treasure maps, gambling and the secret stash | Recorded in `docs/rules.md` and the EpicLoot overlay comment; the ADR keeps its original text as history |

One claim was strengthened rather than corrected: personal keys were previously *Intended*, and the
first boss kill left the live world with no global keys while a client's character file held its
own, so blocking and per-character storage are now observed. The award radius and the locks
themselves remain unobserved.

## Claims corrected during code review

The two-axis review of this change set (`/code-review`, both axes run as independent sub-agents)
found defects that had already been committed. They are recorded here because they changed shipped
behaviour and documentation, not just prose.

| Finding | Reality | Action |
| --- | --- | --- |
| `test/client-pack.test.sh` gated itself on `jq` | `flake.nix` does not provide jq and `scripts/stage-stack.sh` documents its absence, so under `docs/agents/check.conf` all seven client-pack checks silently skipped. | jq dependency removed; the manifest is read with the scripts' own grep/sed idiom, and the validity check was verified to reject the doubled-comma and trailing-comma malformations it exists for. |
| `scripts/backup-world.sh` captured derived directories as worlds | The game's `<World>_backup_*` snapshots and `restore-world.sh`'s `<World>.replaced-<stamp>` leftovers were captured as separate worlds, and a restore of every world would have put a stale snapshot back beside the live one. | Derived directories excluded, with two regression tests. |
| Rotation sorted archives by whole filename | The name is `lembitu-<label>-<stamp>`, so labels were compared before timestamps and `--keep` could delete the newest archive of one world while keeping an older one of another. | Rotation now keys on the trailing timestamp; regression test added. |
| `launch-server.sh` published ports from the caller's shell | The file the wiki calls authoritative set `SERVER_PORT`, but `do_run` expanded the shell's `SERVER_PORT`. | The port is read from the launch configuration, and the script gained the `usage()`/`--help` surface its siblings have. |
| `scripts/build-client-pack.sh` wrote `stage.log` beside the published pack | The directory an operator hands to players gained builder bookkeeping, and on failure it survived the aborted run. | The log lives in the private staging tree; a failure copies it to `stage-failed.log` for diagnosis. |
| Save-format knowledge duplicated across backup and restore | `world_dirs`, `generations`, the generation check and the admission-list triple were written twice, so the format contract could drift between the two scripts. | Extracted to `scripts/lib/save-format.sh`, following the existing `lib/ledger.sh` precedent. |

## Contradictions found and left open

| Document | Claim | Status |
| --- | --- | --- |
| `docs/wiki/building.md:43` | The bundled-library screen "found this in 1 of 33 libraries" | **Stale count.** The measured result itself is right and reproducible (`scripts/screen-bundled-libs.sh --dir dist/plugins` still reports `1 of 33 library(ies)`, re-run 2026-09-15), but the screened set is now the reduced pack, whose staged tree holds 25 packages. The "33" is a historical measurement from the thirty-package era and should be re-stated as such, or re-measured against the reduced tree. Not corrected here because the correct number depends on how the screen counts libraries inside package trees, which is the screen's own question (#26's area). |
| `docs/wiki/building.md:43` | ValheimRAFT's stale `ServerSync.dll` reference is "inert because `ValheimVehicles.dll` never calls `AddConfigEntry`, `AddLockingConfigEntry` or `AddCustomValue`" | **Falsified on the client, corrected here.** A client running the published pack reached the world and played normally, yet its BepInEx log carries eight `MissingFieldException: Field not found: .ZRoutedRpc.Everybody` raised from `ConfigEntry<T>.<.ctor>b__10_0` through `ConfigFile.OnSettingChanged` — the config-change callback, which is reachable when a ValheimRAFT config value changes on disk. BepInEx swallows it inside a `try`/`catch`, so the session is unaffected; the server log and the ticket-66 server boot show zero occurrences. The claim "nothing registers a synced entry, so those methods never run" was argued from source and is wrong for the client. Corrected in place, with the severity left as unmeasured and handed to #26. |
| `docs/build.md:704-745` | "Full-pack native acceptance — 2026-09-13": fourteen adopted updates, official BossRules 1.0.10, two passing repetitions | **Historically accurate, currently inapplicable.** Those runs predate the pack reduction (#66) and cover a thirty-package stack that no longer exists. The section is dated and scoped, so it is not false — but a reader must not read it as current. `docs/wiki/pack.md` records the 2026-09-15 reduced-pack boot separately. Left in place, dated. |
| `docs/build.md:646-706` | BossRules stall diagnosis, `Lembitu.BossRules` guard, MWL interaction | **Historical.** BossRules and More World Locations AIO are both cut (ADR-0010), and the local guard plugin is deleted. The passage explains why they were cut and is labelled as historical, so it is retained deliberately. |
| `docs/wiki/native-testing.md:126` | Chainload is proven by "the BepInEx banner, plugin loading and its own runtime lines, plus chainloader completion" | **Consistent for chainload, but insufficient as a clean-bill claim.** Re-verified on this change set: a pack-running client reaches `Chainloader startup complete` and joins. It also emits eight swallowed `MissingFieldException`s, so "no missing-member errors" is not what a passing client log looks like — the errors must be read for blast radius, not merely counted. See the row above. |
| `docs/adr/0004-two-power-curves.md` | The original decision keeps AdditiveDamageModifier | **Superseded in-document.** The 2026-09-15 amendment records the cut, so the ADR is self-consistent; the original text is not corrected, which is the ADR convention. |
| `CONTEXT.md:105-115` | Karma and Enforcer definitions | **Unverified.** The definitions match CreatureManager's role in `docs/modstack.md:36`, but neither Karma behaviour nor an Enforcer encounter has been observed on this pack. `docs/rules.md` states them in the *Intended* register. |

## Intended behaviour recorded as such

`docs/rules.md` separates Proven / Intended / Unresolved deliberately, because most gameplay rules
in this pack are configured and enforced but not yet observed. The following are *Intended* there
and in the wiki, not measured:

- The whole difficulty tier (#13): CreatureManager loads the `Hard` preset and the boot logs
  `12 level rule definition(s)`; observed creature and boss health in play is #10/#13's.
- Personal keys and their gates (ADR-0005): enforced in
  `config/enforced/com.orianaventure.mod.WorldAdvancementProgression.cfg`; a boss kill awarding a
  key to a present player has not been observed.
- PvP flags, death retention and grave looting (#8): pinned in
  `config/enforced/Turbero.PvPBiomeDominions.cfg`; behaviour unobserved, and death-cause blindness
  is the mod's limit rather than a setting.
- ValheimRAFT vehicles (#26): cannons are disabled and proven; build, sail, anchor and persistence
  are not.
- The launch world itself (#19/#23): the launch configuration is committed and its world rules were
  verified to parse, but no launch world exists and no server has been provisioned on the operator's
  host.

## Unresolved policy referenced, not invented

These belong to tickets that remain open. `docs/rules.md` says so rather than writing a desired
behaviour as current fact:

| Policy | Ticket | State |
| --- | --- | --- |
| Whether the `Hard` difficulty tier is the right one | #13 | Tier committed; playtest confirmation open. |
| Trade Post contract, escrow, expiry and permission semantics | #16 | Not built; ADR-0006 deferred it. Nothing exists. |
| Actual simultaneous capacity above ten players | #9 | Configured value, rewritten literals and advertised capacity are recorded; an eleventh admitted peer is unproven and #9 says so. |
| Discord relay event selection and webhook | #17 | Package pinned and loading; event choice and secret are operator decisions. |
| ValheimRAFT's remaining vehicle behaviour | #26 | Open. |
| Launch approval and roster onboarding | #23 | Open; requires operator-held inputs this record does not have. |

## Verification of the replacements

Every claim added by this change set was exercised, not read:

- The launch modifier set was booted on a disposable server and read from the game's own parse lines
  (`Setting world modifier preset: hard`, `Setting world modifier: Portals->hard`), and the invalid
  `normal` token was caught by its error line.
- The backup and restore were run end to end against a real 1.0 world, byte-compared, and the
  restored world loaded by a server (`ZNet.LoadWorld: launch (launch), save number 1`).
- The client pack was built from the real pin table, extracted into an emptied client tree, and
  compared file-by-file against its emitted inventory (176 files, zero mismatches).
- The README correction was verified by running the corrected command's predecessor and reading the
  installer's refusal.

Claims that remain *Intended* were not exercised and are not written as if they were.
