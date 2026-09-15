# The mod stack

What the development candidate runs, at which version, and what we changed about each default.
This file records exact versions for reproducible tests, not a prelaunch freeze. The reasoning is
in [adr/](adr/) and the vocabulary in [../CONTEXT.md](../CONTEXT.md).

Adopted update candidates were checked against live Thunderstore package APIs on **2026-09-14**.
Development follows the latest public Valheim client/server and latest mod releases. The current
game candidate is **1.0.12 / network 40**; Groundwork is **1.1.12** and BossRules **1.0.10**. Older 1.0.7 results below
are historical, not current acceptance. Freeze only after full-pack gameplay and two-client
acceptance pass, before launch-world creation (ADR-0007, ADR-0009).

## Adopted upstream

Every mod here is intended for the server *and* client pack at exactly this version (BoneMod is
client-side). Candidate staging is not deployment or verification. "Enforced config" is a deliberate
deviation from the defaults and belongs in server-locked config rather than a player's file.

| Mod | Pin | Role | Enforced config |
| --- | --- | --- | --- |
| sighsorry/Clan | 1.0.10 | Clans, roles, clan chat, guest clans, clan pings | Friendly fire off; config locked |
| sighsorry/STU_Ward | 1.3.15 | Wards resolved against clan membership | — |
| sighsorry/PortalRules | 1.0.7 | Portal access control | Access modes only: no fares, no map picker, no admin portals, GlobalKey gates unset |
| sighsorry/BossRules | 1.0.10 | Boss lifecycle: despawn refunds, duplicate-summon block, boss stones | `BossRules.forsakenPowers.yml` left empty; remote power rotation off |
| MidnightMods/ProgressivePowers | 0.3.3 | Forsaken power mastery | Owns all power effects |
| RandyKnapp/EpicLoot | 0.14.5 | Gear tiers: magic drops, enchanting, bounties | Progression gating answered by the progression bridge |
| warpalicious/More_World_Locations_AIO | 5.1.0 | 185 locations, traders, waystones | Trader stock `requiredGlobalKey`/`notRequiredGlobalKey` left unset |
| Digitalroot/Max_Dungeon_Rooms | 2.0.39 | Larger dungeons | — |
| sighsorry/CreatureManager | 1.1.13 | Karma and Enforcer encounters | Creature cloning and customisation off |
| sighsorry/AdditiveDamageModifier | 1.2.4 | Additive resistances, player minimum-damage floor | — |
| turbero/PvPBiomeDominions | 1.7.8 | PvP death and retention rules | Biome-forced PvP off everywhere |
| sighsorry/CaptainValheim | 1.0.10 | Shields as active weapons | — |
| sighsorry/SecondaryAttacks | 1.2.8 | Secondary attacks for other weapon classes | — |
| sighsorry/Dive_In | 1.2.3 | Diving, water combat, underwater creature pursuit | — |
| sighsorry/Groundwork | 1.1.12 | Farming and terrain tools scaling with skill | — |
| sighsorry/RepairRequiresMaterials | 1.0.6 | Repairs cost materials; incinerator dismantling | — |
| sighsorry/VeiledRecipes | 1.1.5 | Recipes hidden until discovered | — |
| sighsorry/InventorySlots | 1.4.16 | Equipment and quick slots, comparison, multicraft | Keep-on-death off |
| turbero/DetailedLevels | 2.1.3 | Skill progress readout | — |
| sighsorry/AdminQoL | 1.1.3 | Admin console GUI and item sets | — |
| sighsorry/DataForge | 1.3.4 | Item, recipe and effect tuning | Tuning only: no cloned or custom items |
| sighsorry/SkadiNet | 1.1.5 | Peer-aware network pacing, dungeon-layer filtering | — |
| sighsorry/Blasted_Swimming_Tarred_Bug_Fix | 1.2.6 | Vanilla state and teardown bug fixes | — |
| sighsorry/Fast_AssetBundle_Loader | 1.0.7 | Startup asset-bundle caching | — |
| TOYNBEE/BoneMod | 1.0.2 | Cosmetic bone scaling (client-side) | — |
| WackyMole/WackyItemRequiresSkillLevel | 1.4.7 | Character-level gates on crafting, equipping and consuming | Curated rules in `WackyMole.ItemRequiresSkillLevel.yml` |
| team0/ValheimRAFT | 4.3.2 | Custom ships, anchoring and vehicle building | Server-synced `CannonPrefabs_Enabled = false` |
| ValheimModding/Jotunn | 2.30.0 | Library | Overrides the 2.29.2 pin declared by EpicLoot, ProgressivePowers and MWL AIO |
| ValheimModding/JsonDotNET | 13.0.4 | Library | — |
| ValheimModding/YamlDotNet | 16.3.1 | Library | — |

## Forks

These were forked because upstream had no verified working 1.0.7 build at the time. Each maintained
fork lives in `src/forks/<Name>/` with an `UPSTREAM.md` recording the exact commit, licence and
changes; see [build.md](build.md) and `../src/forks/README.md`.

**2026-09-12 update:** EpicMMOSystem now incorporates upstream 1.9.66. We retain the fork for
our integration removals, vanilla-fermenter behavior and pruned XP tables. Native creature additions
and database migration were imported; see its `UPSTREAM.md` for the complete comparison.

| Fork | Forked from | Why | Ticket |
| --- | --- | --- | --- |
| EpicMMOSystem | `Wacky-Mole/WackyEpicMMOSystem@e3de877` = 1.9.66, MIT-0 | Character level curve with project-specific integrations, fermenter and XP-table policy | #5 |
| MaxPlayerCount | `AzumattDev/MaxPlayerCount@4482e27` = 1.2.4 source, pinned release 1.2.5, MIT-0 | Player cap above 10, raised to 20 | #9 |

Enforced config the forks carry, for the same reason as the adopted table above: **EpicMMOSystem**
brews the XP meads in the vanilla fermenter (its own fermenter piece is not registered) and ships
only the mob-XP tables for creatures this stack can spawn; **MaxPlayerCount** defaults to 20.

**2026-09-14 adoption:** ItemRequiresSkillLevel 1.4.7 rebuilt against BepInEx 5.4.2350
and replaced its bundled ServerSync, removing the recompile justification for our fork (#64).
The adopted package keeps `config/enforced/WackyMole.ItemRequiresSkillLevel.yml`, gating
the four armour tiers past bronze on character level, not world progression (ADR-0005).
ValheimRAFT 4.3.2 is now pinned for disposable-world verification, not launch acceptance (#26).

`src/forks/ServerSync/` is a library fork rather than a mod: shared source compiled into our own
plugins (ADR-0002).

## Our plugins

| Plugin | What it owns | Ticket |
| --- | --- | --- |
| Personal keys | Boss and progression unlocks stored per character | #11 |
| Contribution credit | Who earned XP and keys from a kill | #12 |
| Boss health scaling | Flat per-tier boss health multipliers | #13 |
| PvP XP bonus | Extra XP while flagged | #14 |
| Banked XP | Offline pool and the level-gap multiplier | #15 |
| Trade Post | Contracts, escrow and mailbox delivery as server records | #16 |
| Discord relay | Joins, deaths, boss kills and contract activity over a webhook | #17 |
| Progression bridge | Answers EpicLoot's gating from personal keys; feeds character level into its rarity roll | #27 |
| Lembitu.Hello | Build-skew and ServerSync smoke test | #1, #2 |

## World-permanent mods

These write content into the world save, so they are installed before the launch world is created
and never removed during the run (ADR-0009): **More World Locations AIO**, **Max Dungeon Rooms**,
**ValheimRAFT**.

EpicLoot, ProgressivePowers and the Enchantment-style data our own plugins write are one-way for a
different reason: removing them destroys player gear or progress rather than corrupting the world.

## Upstream update and acceptance — 2026-09-13

All 33 tracked Thunderstore packages were checked. Fourteen adopted packages advanced;
BepInEx, the three maintained plugin forks and planned ValheimRAFT had no newer releases.
The three maintained plugin upstream heads and shared ServerSync source also remained unchanged.
Custom fork behavior is retained; ValheimRAFT remains planned, not newly installed.

| Package | Previous → current |
| --- | --- |
| MidnightMods/ProgressivePowers | 0.1.0 → 0.3.0 |
| RandyKnapp/EpicLoot | 0.14.4 → 0.14.5 |
| sighsorry/Blasted_Swimming_Tarred_Bug_Fix | 1.2.4 → 1.2.6 |
| sighsorry/BossRules | 1.0.9 → 1.0.10 |
| sighsorry/Clan | 1.0.7 → 1.0.10 |
| sighsorry/DataForge | 1.3.3 → 1.3.4 |
| sighsorry/Groundwork | 1.1.10 → 1.1.11 |
| sighsorry/InventorySlots | 1.4.10 → 1.4.15 |
| sighsorry/PortalRules | 1.0.5 → 1.0.7 |
| sighsorry/RepairRequiresMaterials | 1.0.4 → 1.0.6 |
| sighsorry/STU_Ward | 1.3.12 → 1.3.15 |
| sighsorry/SecondaryAttacks | 1.2.4 → 1.2.7 |
| sighsorry/SkadiNet | 1.1.3 → 1.1.4 |
| sighsorry/VeiledRecipes | 1.1.4 → 1.1.5 |

The installed public client build **25253764**, Linux depot manifest **6181039652481492267**,
was already current. Its disposable test copy was refreshed. Dedicated-server validation confirmed
public depot manifest **9055200629726788899**; runtime is **1.0.12 / network 40**.
All 28 packages staged with dependency closure, 14 new hashes and 14 verified existing hashes.

BossRules 1.0.10 includes the native-authority fix, replacing the temporary local plugin.
No enforced-config migration was required. Upstream defaults now include restock leave-one,
equipment changes while running and automatic last-shield equipment; these were not overridden.

The existing full-pack native runner passed **two fresh-world repetitions**, including rendered
Skills UI, movement, crafting, combat, natural death/respawn, password rejection and native quit.
Both Skills and combat screenshots were inspected. Evidence and repeat command are in
[build.md](build.md#full-pack-native-acceptance--2026-09-13). This does not establish simultaneous
two-client behavior or exhaustively verify every mod feature; the pack is not frozen.

## Upstream update check — 2026-09-12

Historical pre-update comparison: all 33 tracked Thunderstore packages were checked — the 28 lock
entries, three maintained plugin forks, planned ValheimRAFT, and BepInExPack. Eleven had newer
releases; 22 remained current. The [complete comparison](https://github.com/rakoort/valheim-lembitu/issues/10#issuecomment-5646354590)
is recorded on #10. The table preserves the old-pin → latest comparison; the adopted pins above
now include all ten adopted updates, which have not passed the runtime gate below.

| Package | Pin → latest | Relevant change |
| --- | --- | --- |
| WackyEpicMMOSystem | 1.9.62 → 1.9.66 | Official 1.0.7 update; compare our custom changes |
| BoneMod | 1.0.1 → 1.0.2 | Fixes save attempts before local-player creation during join/logout |
| EpicLoot | 0.14.2 → 0.14.4 | Linux config-sync and data-lookup fixes |
| PvPBiomeDominions | 1.7.6 → 1.7.7 | Fixes black screen on death |
| Clan | 1.0.5 → 1.0.7 | Chat, panel, HUD and map-marker fixes |
| InventorySlots | 1.4.8 → 1.4.10 | Container cursor capture and requirement-display fixes |
| DataForge | 1.3.2 → 1.3.3 | Build-category discovery and duplicate fixes |
| STU_Ward | 1.3.11 → 1.3.12 | UI fixes |
| VeiledRecipes | 1.1.3 → 1.1.4 | Hammer silhouette rendering fix |
| PortalRules | 1.0.4 → 1.0.5 | Fare calculation changes; fares disabled here |
| Groundwork | 1.1.8 → 1.1.9 | Targets a **1.0.12** field-to-property change; do not blindly adopt on 1.0.7 |

Fast_AssetBundle_Loader remains 1.0.7; no newer package fixes the observed Linux `DriveInfo` failure.
ServerSync v1.20 says “Recompile for 1.0” but tags our existing source commit, so no source update
is needed. Metadata came from Thunderstore package APIs; changes came from publisher changelogs.

### Historical public candidate — 2026-09-12

The initial check found Groundwork **1.1.10**; the other 27 adopted packages and maintained upstream
fork heads remained current then. Connection diagnosis subsequently found BossRules **1.0.9**; it
replaces 1.0.8 in the candidate. All 28 packages were staged with verified hashes and dependency
closure. Client/server use **1.0.12 / network 40**, and all plugins rebuilt successfully.

The initial latest-game run failed config generation because the native profile had no saved
language. Completing native Settings setup resolved that failure without modifying upstream mods.
Connection diagnosis then found premature server readiness and a BossRules authority race:
connecting clients scanned every MWL location before ServerSync established remote authority.
The runner was changed to wait for the native Steam listener; the temporary `Lembitu.BossRules`
plugin gated that reference scan on native world authority. Official BossRules 1.0.10 now includes
the same authority check, so the local plugin has been removed. Gameplay rules and network timeouts are unchanged.

Full-pack native joining passed in a fresh world with every mod enabled:
`join-probes/20260912T190318Z-3d4e6d45/`. The player reached control-ready at 25/25 health, the
server generated its altar reference, the client retained an empty reference template, and native
quit completed. The screenshot was visually inspected. Full gameplay and simultaneous two-client
acceptance remain open; do not freeze. See [connection diagnosis](build.md#native-connection-diagnosis--2026-09-12).

### Historical 1.0.7 candidate screening — 2026-09-12

The initial metadata check confirmed all ten adopted updates above as latest and active then.
`scripts/stage-stack.sh` fetched and staged all 28 packages, recorded ten new SHA-256 hashes,
verified the other 18 against the lock, and passed declared dependency closure with the existing
BepInEx and Jotunn overrides. This proves package staging, not game compatibility.

Groundwork 1.1.9 was included, but static screening with the ILSpy commands in
[build.md](build.md#screening-a-prebuilt-dll-against-the-game) found a concrete API mismatch:
`Groundwork.GameAccess.BypassCheatChecks` calls
`PlayerProfile.get_s_bypassCheatChecks()`, while the then-current 1.0.7 reference assembly exposed
`public static bool s_bypassCheatChecks` as a field, with no property getter. This matches the
publisher's [1.0.12 changelog](https://thunderstore.io/c/valheim/p/sighsorry/Groundwork/changelog/).
That placement path could not resolve the call on 1.0.7. The game has since been updated rather
than held back for this mismatch, and Groundwork updated to 1.1.10. Hoe/Cultivator placement still
requires runtime acceptance; this old mismatch alone does not establish a current-version blocker.

The final 1.0.7 full-pack run `20260912T161105Z-full-pack-03bc47f8` failed configuration generation:
the client never created `sighsorry.Clan.cfg` or `sighsorry.InventorySlots.cfg`. STU_Ward also
logged a Steamworks-before-initialization startup exception. No full-pack gameplay passed.
The runner shut down both owned processes with exit 0 and removed its disposable work.

The same permanent runner passed two fresh **minimal** repetitions in
`20260912T155719Z-minimal-27512e6b`, covering native movement/UI, pickup/crafting, club damage,
death/respawn, password rejection and graceful shutdown. This isolates the harness from mods;
it does not clear the full pack or simultaneous two-client acceptance. Full evidence and commands
are in [build.md](build.md#historical-updated-candidate-107-repeatable-verification--2026-09-12).

## Verification gate

No candidate mod is cleared for the launch pack until it has, on the current public test game:

1. loaded with no `MissingFieldException` or `MissingMethodException`,
2. broadcast its synced config without throwing — the failure mode ADR-0002 exists for,
3. survived a two-client session (#10).

Installing and verifying the current candidate is #25. Package hashes are recorded in
[modstack.lock.json](modstack.lock.json); `scripts/stage-stack.sh` verifies every download
against it and refuses a re-published zip under the same version number.

## Historical verification record

**2026-09-10, #25**: the whole stack installed from `scripts/stage-stack.sh` onto the 1.0.7 test
server on astral-bicep and booted twice. Result per mod — gate item 1 proven; gate item 2 proven
as far as a headless server can (every ServerSync construction and RPC registration clean, plus
Lembitu.Hello's startup broadcast probe), with the per-mod client handshake and item 3 (the
two-client session) remaining #10's:

| Mod | Pin | Loaded | Config sync | Notes |
| --- | --- | --- | --- | --- |
| sighsorry/Clan | 1.0.5 | yes | RPC registered | 96 emblem/emoji seeds deployed to `BepInEx/config/Clan/`; friendly fire enforced off, config locked |
| sighsorry/STU_Ward | 1.3.11 | yes | RPC registered | |
| sighsorry/PortalRules | 1.0.4 | yes | RPC registered | Portal map off, travel costs off (default), no GlobalKey gates; logs that gating falls back to shared world progression since YouAreNotWorthy is cut |
| sighsorry/BossRules | 1.0.8 | yes | RPC registered | `forsakenPowers.yml` emptied (shipped with modified powers); log confirms "0 entries"; remote power rotation off |
| MidnightMods/ProgressivePowers | 0.1.0 | yes | — | not ServerSync-based |
| RandyKnapp/EpicLoot | 0.14.2 | yes | — | runs against Jotunn 2.30.0 despite declaring 2.29.2; Deep North content loads |
| warpalicious/More_World_Locations_AIO | 5.1.0 | yes | RPC registered | 266 files staged; LootDB/CreatureDB initialized; trader stock carries no requiredGlobalKey/notRequiredGlobalKey anywhere in its config or MWL_Ports data (verified by search, and nothing to enforce as a result); Jotunn logs ambiguous-asset warnings for its props, none fatal |
| Digitalroot/Max_Dungeon_Rooms | 2.0.39 | yes | — | |
| sighsorry/CreatureManager | 1.1.13 | yes | RPC registered | creatures/attacks/ai/projectile yml verified empty and pinned in config/enforced/ so a future default that ships content is caught; config locked. Karma untouched |
| turbero/PvPBiomeDominions | 1.7.6 | yes | RPC registered | defaults to forced PvP in all nine biomes — all set to PlayerChoose; config locked. Position-sharing rules left at ShowPlayer for #8/#14 to review |
| sighsorry/CaptainValheim | 1.0.10 | yes | RPC registered | |
| sighsorry/SecondaryAttacks | 1.2.4 | yes | RPC registered | |
| sighsorry/Dive_In | 1.2.3 | yes | RPC registered | |
| sighsorry/Groundwork | 1.1.8 | yes | RPC registered | |
| sighsorry/RepairRequiresMaterials | 1.0.4 | yes | RPC registered | |
| sighsorry/VeiledRecipes | 1.1.3 | yes | RPC registered | |
| sighsorry/InventorySlots | 1.4.8 | yes | RPC registered | keep-on-death enforced off, config locked |
| turbero/DetailedLevels | 2.1.2 | yes | RPC registered | |
| sighsorry/AdminQoL | 1.1.3 | yes | — | loaded 48 YAML itemsets |
| sighsorry/DataForge | 1.3.2 | yes | RPC registered | items/pieces/effects yml verified empty and pinned in config/enforced/: tuning only, and any future tuning is committed there; config locked |
| sighsorry/SkadiNet | 1.1.3 | yes | RPC registered | |
| sighsorry/AdditiveDamageModifier | 1.2.4 | yes | RPC registered | |
| sighsorry/Fast_AssetBundle_Loader | 1.0.7 | yes (patcher) | — | deploys to `BepInEx/patchers/`; caches MWL's 200+ bundles on first boot |
| TOYNBEE/BoneMod | 1.0.1 | yes | — | client-side; assembly reports 1.0.0.0 |
| ValheimModding/Jotunn | 2.30.0 | yes | — | one copy; overrides the 2.29.2 three mods declare |
| ValheimModding/JsonDotNET | 13.0.4 | yes | — | loads as Newtonsoft.Json + detector |
| ValheimModding/YamlDotNet | 16.3.1 | yes | — | |

Zero `MissingFieldException`, `MissingMethodException` or `[Error]` lines across both boots;
vanilla noise only (`libparty.so`, intro cinematic). Enforced config applied via
`scripts/apply-enforced-config.sh` from `config/enforced/` and confirmed idempotent. The
per-mod client-side handshake of the synced configs is exercised in #10, which needs real
clients.

**2026-09-10, #4/#5/#8/#9**: the three forks built by `dotnet build`, installed with
`scripts/install-plugins.sh` beside the pinned stack, and booted on the same 1.0.7 test server.
Zero `MissingFieldException`, `MissingMethodException` or `[Error]` lines; the same vanilla noise
as above.

| Fork | Loaded | Config sync | Server-side evidence |
| --- | --- | --- | --- |
| EpicMMOSystem 1.9.62 | yes, both plugins (`EpicMMOSystem`, `EpicMMOSystemUI`) | `WackyMole.EpicMMOSystem` and its ItemManager channel registered | 2 mob-XP tables loaded covering 152 creatures, 151 of which match a prefab in this world (`Chick` does not and can never award XP); XP mead conversions added to the vanilla fermenter; `BepInEx/config/EpicMMOSystem/` holds only the two tables we ship |
| ItemRequiresSkillLevel 1.4.6 | yes | `WackyMole.ItemRequiresSkillLevel` registered | 12 rules read from `config/enforced/WackyMole.ItemRequiresSkillLevel.yml`, all 12 matching an item in the world database; the static constructor that threw on 1.0.7 through its bundled ServerSync now runs clean |
| MaxPlayerCount 1.2.5 | yes | not ServerSync-based | All three capacity surfaces patched and logged: `ZNet.RPC_PeerInfo` 10 → 20, `ZPlayFabMatchmaking.CreateLobby` and `.CreateAndJoinNetwork` 11 → 21, and `SteamGameServer.SetMaxPlayerCount` asked for 64 and given 20 |

PvPBiomeDominions' death and retention rules (#8) are enforced from
`config/enforced/Turbero.PvPBiomeDominions.cfg` and confirmed idempotent: flagged players keep
equipped and hotbar items, unflagged players take the vanilla penalty, only flagged players may
loot a grave, and the alert message that gates the loot restriction is pinned non-empty.

What these boots cannot show, because every one of these paths runs on a client — so all of it is
#10's, listed criterion by criterion so nothing looks skipped:

- **#5**: XP awarded for a kill, levelling granting attribute points, spending them, the attribute
  panel, the exp bar, nameplate level and XP-worth display, the 15-level PvP damage band, PvP kill
  XP, and levels surviving reconnect and restart. All of it keys off `Player.m_localPlayer`, and
  level and XP are stored in the character save, so a headless server never evaluates any of it.
- **#4**: the craft button disabling, the equip and consume refusals with their messages, the
  tooltip lines in their allowed/denied colours, a client with different local settings being
  overridden by the server, and a rule keyed on a key being confirmed — `IsAble` returns early
  when there is no local player, so the key branch cannot be exercised server-side either. The
  rule file our fork generates carries a key example for that test; the rules we enforce gate on
  character level only, deliberately, with the tiers themselves left to #18.
- **#8**: retention on a real death, one flagged player looting another's grave, and an unflagged
  player taking the vanilla penalty.
- **#9**: an eleventh simultaneous connection. Note the distinction the log makes: the admission
  literal is proven **rewritten**, and the inserted call is proven to execute only for the Steam
  surface, since the admission hook needs a peer to connect. MaxPlayerCount is server-only and
  stays out of the pack; `src/forks/MaxPlayerCount/UPSTREAM.md` shows why, per patched surface.

Open unknowns to settle in #10, recorded here so they are not rediscovered:

- **ProgressivePowers kill tracking.** Mastery levels are earned by boss kills; whether it counts
  per character or reads world keys decides if it needs the progression bridge.
- **EpicLoot's declared dependencies.** 0.14.2 ships Deep North content but still declares BepInEx
  5.4.2333 and Jotunn 2.29.2. It runs against our pins or it does not ship.
- **Jotunn 2.30.0 piece categories.** Upstream says categories are not updated for 1.0.7: custom
  pieces appear in the build menu without one. Affects MWL AIO, ValheimRAFT and VeiledRecipes.
- **Stacked damage output.** Character level attributes, EpicLoot effects and
  AdditiveDamageModifier's floor all land on one number; Harmony order decides the result.
- **Creature level authority.** Character level rewrites star levels; EpicLoot, CreatureManager's
  Karma and #13 all read them.
- **PieceManager's build categories.** The same breakage, hit directly: EpicMMOSystem's fermenter
  piece is not registered because PieceManager writes `Hud.m_buildCategoryNames` and treats
  `PieceTable.m_availablePieces` as a list of lists, neither of which exists on 1.0.7.
- **Retention is death-cause blind.** PvPBiomeDominions patches `Player.CreateTombStone`, which
  takes no killer, so a flagged player who drowns keeps their gear too. #8's premise — dying to a
  player costing less than dying to a troll — is only half achievable with this mod.
- **Character level lives in the character save.** EpicMMOSystem stores level and XP in
  `Player.m_knownTexts`, so a client owns its own progression; #12, #15 and #27 need to decide
  whether that is acceptable or whether the server has to hold it.

## Considered and cut

Kept out deliberately. Each line is a decision, not an oversight.

| Mod | Why not |
| --- | --- |
| MidnightMods/ImpactfulSkills | Third power curve (ADR-0004) |
| sighsorry/Valheim_Enchantment_System | Second enchanting path on the same items (ADR-0004) |
| MidnightMods/ValheimArmory | New base weapons need community EpicLoot patches to be enchantable (ADR-0004) |
| MidnightMods/StarLevelSystem | Character level owns creature levels; the bridge replaces it (ADR-0005) |
| Smoothbrain/Groups | Second membership authority (ADR-0008) |
| sighsorry/InventoryActions | Mutually exclusive with InventorySlots, and smaller |
| Nosferatu/SmoothServer | One pacing layer only; SkadiNet chosen |
| WackyMole/WackysDatabase | DataForge covers tuning without a fourth fork |
| Tristan/Valheim_PvP_Tweaks | Overlaps PvPBiomeDominions; oldest pins on the list |
| sighsorry/ServerManager | Its Discord and logging role is #17 |
| AWLGaming/DiscordBot_AWL, warpalicious/DiscordTools | Need an external bot host; #17 is a webhook |
| warpalicious/Discord_Screenshots | Client-only, nothing depends on it |
| sighsorry/YouAreNotWorthy | Gates on world keys; ItemRequiresSkillLevel gates on character level |
| shudnal/ProtectiveWards | STU_Ward covers wards |
| Therzie/Warfare | Untouched since March 2025 |
| Hex_Viking/HexResourceTracker, GChallenge/GCValheimStats, Tristan/Player_Activity, Eilif/EilifPaths | Client-only and unenforceable; EilifPaths also changes gameplay per player |
| KGvalheim/Marketplace_And_Server_NPCs_Revamped | Deprecated on Thunderstore and pre-1.0. Design reference for #16 only |

## Re-pinning

Pins are re-checked once, immediately before the launch world is created, and then frozen for the
run. Between now and then, a newer upstream version replaces a pin only if it passes the gate above
again — the whole stack was re-published on 2026-09-09, so a pin chosen today is hours old, not
months.
