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
| `docs/wiki/operations.md:28` | "The backup requirement … is to capture the chunked world, Clan registry and character store together" as something still to be done | The character store is client-owned by decision (ADR-0010), so a server backup cannot capture it and should not claim to. The Clan registry is read from the world save by the mod, not a separate server file this project can enumerate. | Replaced by the implemented `#20` section, which states what is captured and what is deliberately not, with the measured restore result. |

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
