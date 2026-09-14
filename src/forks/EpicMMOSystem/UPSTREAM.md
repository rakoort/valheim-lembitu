# EpicMMOSystem

Character level and attributes: XP from kills, attribute points, level and XP-worth on nameplates,
and a level band that limits player-versus-player damage. This is the project's first power curve
(ADR-0004) and the mod the most other work leans on: #4 gates gear on its levels, #12/#14/#15
modify its XP, and the progression bridge (#27) feeds its creature levels into EpicLoot.

| | |
| --- | --- |
| Upstream | <https://github.com/Wacky-Mole/WackyEpicMMOSystem> |
| Forked at | `09d0e252862ddb03685052440070cf5d0504de86` (2026-09-06, "1.9.62"); updated through `e3de877cefbc3260ac8d1fe9410b3f221046b05e` (1.9.66) |
| Version | `1.9.66` — latest official `WackyMole/WackyEpicMMOSystem` release verified 2026-09-12; uploaded 2026-09-10 |
| Licence | MIT-0, `LICENSE.txt` in this directory (copied verbatim from upstream) |
| Built for | Valheim 1.0.7 (network version 39), BepInEx 5.4.23.5 |

Issue #5 was written on the belief that this mod had no public repository. It does; the GitHub
login is hyphenated (`Wacky-Mole`), which is why `WackyMole/WackyEpicMMOSystem` 404s and the ticket
concluded a decompile-fork was the only option. Thunderstore's own metadata links the repo.

The package ships **one** DLL containing **two** BepInEx plugins — `WackyMole.EpicMMOSystem` and
`WackyMole.EpicMMOSystemUI`, declared in the same file — which is what #5's "both plugins in the
package" means.

## Why this fork exists

Upstream 1.9.66 now targets Valheim 1.0.7, although its package still declares BepInEx
`5.4.2202`. We retain the fork for the integration removals, vanilla fermenter, curated XP
tables and source-built shared libraries below, not merely for a recompile.

## What upstream's git tree does not build

The original 1.9.62 git tree did not reproduce its shipped assembly. Two things the released
DLL contains are absent from the repository (still recovered locally for 1.9.66):

- `ColorUtil`, a global class the GUI calls. Recovered by decompiling the release; it lives at
  `ColorUtil.cs` in this directory.
- The config entry `Orb Boss Max Amount` (`OrdDropMaxAmountFromBoss`), which `DataMonsters` reads.
  Recovered the same way and re-declared beside the other orb settings in `Plugin.cs`.

Upstream also bundles its libraries as prebuilt DLLs under `Libs/`, several of them newer than the
public sources their authors publish (see below). Where the two disagreed, the released assembly
won: it is what the pin actually is.

## Our changes

1. **Ported to our toolchain.** Upstream's project is a legacy non-SDK `net4.8` file with a
   hard-coded Windows Steam path for `Splatform`, ~50 hand-listed Unity module references, an
   ILRepack step and PowerShell post-build steps. Replaced with an SDK-style `net472` project per
   `docs/build.md`, referencing everything `scripts/extract-refs.sh` extracted rather than a list
   to maintain. Identity comes from the generated `PluginInfo`; the GUID and assembly name are
   unchanged, and both are load-bearing:
   - `ItemManager` resolves asset bundles by `"<assembly name>.<folder>.<bundle>"`,
   - `ItemRequiresSkillLevel` finds this mod through `Type.GetType("API.EMMOS_API, EpicMMOSystem")`,
   - the config directory, the routed RPC names and the `m_knownTexts` keys that store a
     character's level are all built from `ModName`.
2. **No bundled binaries.** `Libs/*.dll` and `ILRepack.targets` are gone:
   - **ServerSync** → our shared source (`ServerSync.props`, ADR-0002).
   - **ItemManager, StatusEffectManager, LocalizationManager, AnimationSpeedManager** → vendored as
     source under `Libs/`, recovered from the shipped assembly because the authors' public
     repositories are older than the build upstream shipped (blaxxun-boop/ItemManager's master, for
     instance, has no `CraftingTable.MeadCauldron`, which this mod uses). Each keeps its author's
     MIT-0 licence text beside it. The decompiler's mangled `<guid>NullableAttribute` decorations
     were stripped; nothing else was rewritten.
   - **fastJSON** → replaced by `Newtonsoft.Json`, which the stack already pins and ships
     (`ValheimModding/JsonDotNET 13.0.4`). Four call sites. Adding a second JSON library to the
     server to parse four files was the alternative.
   - **YamlDotNet** → the pinned `ValheimModding/YamlDotNet` plugin, referenced at compile time
     only (`src/forks/ItemRequiresSkillLevel/UPSTREAM.md` records why the version reads 16.3.0).
   - **PieceManager** → dropped entirely, with the one build piece it registered; see change 4.
   - **Groups / GroupsAPI / EquipmentAndQuickSlots** → dropped with their integrations; see
     change 3.

   The prebuilt copies were not merely stale: checking each one's member references against
   `lib/valheim/` found `PieceManager.dll` and `ServerSync.dll` both reading `ZRoutedRpc.Everybody`,
   which 1.0 turned into a `const` — the exact runtime failure ADR-0002 documents. Recompiling from
   source inlines the value and the failure disappears. `ilspycmd -r lib/valheim -t ZRoutedRpc
   lib/valheim/assembly_valheim.dll` shows the declaration.
3. **Integrations for mods this server does not run are removed, not left dormant.**
   - **Smoothbrain Groups**: the group-XP share (`AddGroupExp`, its RPC registration and its
     receiver) and the friend list's "add to group" button. Clan is the only membership authority
     (ADR-0008); who a kill credits is #12's question, not a second membership system's. The
     `groupExp` and `groupRange` config entries are left declared so #12 can reuse them.
   - **KG Marketplace, Professions, DonatShop, Guilds, WackysDatabase** (`OtherApi/`): all cut in
     `docs/modstack.md`. Their navigation buttons are no longer activated; the GUI prefab still
     carries them, hidden.
   - **Creature Level and Loot Control**: soft dependency dropped, it is not in the stack.
   - `VersionHandshake.cs`: upstream's own version handshake, patching `ZNet.RPC_PeerInfo`,
     `ZNet.OnNewConnection`, `ZNet.Disconnect` and `FejdStartup.ShowConnectError`. Our ServerSync
     already enforces versions through `MinimumRequiredVersion` (which this fork sets), and two
     handshakes on one RPC is a bug waiting for a client to trip over it.
4. **The custom fermenter piece is dropped, and the XP meads brew in the vanilla fermenter.**
   The PieceManager bundled with the original 1.9.62 release does not work on 1.0.7: it treats
   `PieceTable.m_availablePieces` as a list of lists and writes `Hud.m_buildCategoryNames`, neither
   of which exists any more. That is the same piece-category breakage `docs/modstack.md` records as
   an open unknown for Jotunn 2.30.0, and fixing it is a third-party library port in its own right
   for one decorative station. So `mmo_fermenter` is not registered, `Use Regular Fermentor`
   defaults to **on** (upstream: off) so the meads stay brewable, and the "MMO Fermentor Can Ferment
   all Meads" setting is gone with the piece. `runSSvalues` was rewritten around that: it now bails
   out with a warning when no vanilla fermenter is found, where upstream indexed the first match of
   a list it never checked was non-empty — a latent `IndexOutOfRangeException` that this change
   would otherwise have made reachable on every boot.
5. **Mob-XP tables pruned to the creatures this server can spawn.** Upstream embeds 27 JSON tables
   and writes all of them into `BepInEx/config/EpicMMOSystem/`; 25 are for mods we do not run
   (RtD, Monstrum, MonsterLabZ, Jewelcrafting, Therzie, Bestiary, the animal packs …). We ship
   `Default.json` and `NonCombat.json`, plus `Players.json` — **emptied**, because upstream shipped
   it containing a named player with a 2000-point XP bonus. Adding a creature mod means adding its
   table back, and the log says when a table entry has no prefab. That log immediately earned
   itself: `Default.json` named the baby chicken `Chick`, and the prefab is `Chicken` (grep the
   game's asset files: `Chick` appears nowhere), so chicks were worth no XP. Corrected here.
6. **`EnvMan.m_currentBiome` is a `BiomeSector` on 1.0.7**, not a `Heightmap.Biome`; the orb-drop
   path reads `.Biome` from it and tolerates a null sector.
7. **Three diagnostics, all ours**, because this mod's failure modes are silent:
   - how many mob-XP tables loaded and how many creatures they cover;
   - which table entries have no prefab in this world (a table for an absent mod is otherwise
     invisible, and a creature missing from every table awards nothing);
   - how many fermenters got the XP-mead conversions.
   On a headless server these lines, plus the ServerSync RPC registration, are the only evidence
   this mod produces at all. Everything with a GUI — the attribute panel, the exp bar, nameplates,
   the PvP band — needs a real client, which is #10.
8. **`<Nullable>annotations</Nullable>`** rather than `disable`: upstream is `LangVersion 10` with
   partial annotations and the ServerSync source compiled in here is fully annotated, so `disable`
   would report every `?` in ServerSync as CS8632.
9. `UnityEngine.ImageConversionModule` is deliberately **not** referenced: it targets
   netstandard 2.1, which a net472 assembly cannot use. The only code that wanted it was
   `StatusEffectManager`'s "icon from an embedded PNG" path, which this fork has no PNG for — every
   icon comes from an asset bundle — so that one method is gone.

## Upstream 1.9.66 integration (2026-09-12)

Compared every file in `09d0e252862ddb03685052440070cf5d0504de86..e3de877cefbc3260ac8d1fe9410b3f221046b05e`,
including the packaged assemblies. The official Thunderstore DLL matches the repository
release DLL byte-for-byte: SHA-256
`bfe453b4a06e40b9a79122211fa23d0c57ea2f5aad7a370f6d67f51c19db4d89`.
The downloaded 1.9.66 ZIP SHA-256 is
`c9ce9bae2ea36115ea8a410ec5b5a0523a9e4b915373baf95b13d814be94b9fb`.

- **Imported `Data/Default.json`:** all 16 new native creature entries, including the Deep
  North creatures and FrozenKing; all upstream values unchanged. The table now has 95 entries.
  Retained our `Chick` → `Chicken` correction and empty `Players.json`.
- **Imported `LevelSystem/DataMonsters.cs` migration:** 1.9.60 and 1.9.65 table markers now
  upgrade to 1.9.66. Fresh installs write 1.9.66; current tables and NO/STOP opt-outs stay
  untouched. Still deploys only Default and NonCombat, leaving custom tables alone.
- **Retained our biome compatibility fix:** upstream now uses `GetCurrentBiome()`, whose
  pinned-game implementation is `return m_currentBiome.Biome`. Our existing null-safe sector
  read provides the same biome without losing its guard. No additional orb behavior changed.
- **Imported identity/release metadata:** the project version supplies both plugins and
  ServerSync versions through `PluginInfo`; upstream Plugin.cs/manifest version changes and
  changelog/README table-version notes are represented here rather than copied as packaging.
- **Excluded `Data/SeaAnimals.json`:** its sole change removes the modded Seal entry now
  superseded by the native Default entry. This mod-only table is already absent here.
- **Excluded `Libs/PieceManager.dll`:** 1.3.0 adds the new build-menu categories/usage tags,
  category refresh, queued snapshots, updated object searches and snap-point handling. These
  changes apply only to the custom station we deliberately removed; it remains removed even
  though upstream now ports its library. No binary or source from PieceManager is restored.
- **Excluded `Libs/ServerSync.dll`:** the release delta recompiles the broadcast constant for
  1.0. Our shared source already compiles against that constant; retain the shared import.
- **Excluded release binaries and archives:** inspected the changed 1.9.62 ZIP, new 1.9.63
  and 1.9.66 ZIPs and current DLL; deploy our source build, not upstream bundled binaries.
  Decompiling base and current DLLs found no behavioral changes to ItemManager,
  StatusEffectManager, LocalizationManager, AnimationSpeedManager or ColorUtil after ignoring
  generated nullable decorations. Additional game-call signature changes in the release
  (Message and ConsoleCommand optional arguments) are supplied by recompilation of our source.

Verification: `dotnet build src/forks/EpicMMOSystem/EpicMMOSystem.csproj` succeeds against
the extracted Valheim 1.0.7/network 39 references (13 warnings, no errors). A throwaway C#
smoke harness executed the actual table-deployment block for fresh, 1.9.60, 1.9.65, 1.9.66,
NO and stop markers, checking replacement/preservation and custom-table preservation. All
95 native records were compared with upstream, allowing only the Chicken correction. No
existing script tests reference this fork version; native server/client verification is
performed by the stack testing workflow, not by this isolated build.

## Warning cleanup (#39, 2026-09-14)

Removed the dead `playerdead` local left by our Groups integration removal, the unused
`Data/customlevel.cs` prototype classes, and disabled scroll-zoom fields/code in `Scripts/Drag.cs`.
The active drag handlers, saved positions and XP awards are unchanged. No discovery API was
replaced and no warning was suppressed. The full build moves from 13 warnings to eight;
`docs/wiki/building.md` classifies every diagnostic and explains the retained library defaults
and ordered container discovery. Native client preservation remains unverified.

## What this fork owes other tickets

- **`API.EMMOS_API` and the known-text keys are a contract.** `int GetLevel()`,
  `int GetAttribute(string)`, `void AddExp(int)`, and
  `Player.m_knownTexts["EpicMMOSystem_LevelSystem_<Name>"]`. `ItemRequiresSkillLevel` binds to all
  of it by reflection; renaming any of it silently disables the gear gate.
- **Character level and XP live in the character save**, `Player.m_knownTexts`, not in a server
  file — so the client owns its own level. #12, #15 and #27 need to know that.
- **`Enabled_creature_level` rewrites creature star levels.** It collides with CreatureManager's
  Karma, with #13's boss health scaling and with #27's creature-level authority. Left at upstream's
  default here; whoever settles ADR-0005's "creature level authority" question owns it.
- **The PvP band and PvP XP are upstream's, untouched.** `Player PVP Range` defaults to 15 levels
  (#5), and PvP kill XP is `level × 50 + days alive × 10` (#14's starting point).
- `LevelSystem.getCurrentExp` parses the stored XP with `int.Parse` inside a `catch` that resets a
  character's XP to `"2"`. It is upstream's, it is a real data-loss path on the only store of
  character progress, and it is deliberately left alone here: it belongs with #15, which rewrites
  how banked XP is stored and can fix it where the surrounding logic is already being changed.
  Recorded so it is not rediscovered as a mystery.

## Re-forking

1. Clone upstream at the new tag, and diff against this directory to see our changes in place.
2. Re-apply changes 1–9. The compiler finds most of them; the removals are listed above.
3. Check whether the release contains code the repository does not (the two items above), by
   decompiling it: `ilspycmd -p -o /tmp/emmo <EpicMMOSystem.dll>`.
4. Re-check the vendored libraries under `Libs/` against the new release's `Libs/*.dll` the same
   way, and against the game: a prebuilt copy that reads a member 1.0 turned into a `const` fails
   at runtime, not at build.
5. Boot the test server and read the log lines in change 7.
