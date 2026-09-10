# The mod stack

What the server runs, at which version, and what we changed about each one's defaults. This file is
the source of truth for pins; the reasoning behind the shape is in [adr/](adr/) and the vocabulary
in [../CONTEXT.md](../CONTEXT.md).

Versions below were verified against Thunderstore on **2026-09-10 07:46 UTC**. Re-run the check
before the launch world is created (ADR-0009), then freeze: the pack does not move during the run
(ADR-0007).

## Adopted upstream

Every mod here is installed on the server *and* in the pack, at exactly this version. "Enforced
config" is a deliberate deviation from the mod's default, and each one belongs in server-locked
config rather than a player's file.

| Mod | Pin | Role | Enforced config |
| --- | --- | --- | --- |
| sighsorry/Clan | 1.0.5 | Clans, roles, clan chat, guest clans, clan pings | Friendly fire off; config locked |
| sighsorry/STU_Ward | 1.3.11 | Wards resolved against clan membership | — |
| sighsorry/PortalRules | 1.0.4 | Portal access control | Access modes only: no fares, no map picker, no admin portals, GlobalKey gates unset |
| sighsorry/BossRules | 1.0.8 | Boss lifecycle: despawn refunds, duplicate-summon block, boss stones | `BossRules.forsakenPowers.yml` left empty; remote power rotation off |
| MidnightMods/ProgressivePowers | 0.1.0 | Forsaken power mastery | Owns all power effects |
| RandyKnapp/EpicLoot | 0.14.2 | Gear tiers: magic drops, enchanting, bounties | Progression gating answered by the progression bridge |
| warpalicious/More_World_Locations_AIO | 5.1.0 | 185 locations, traders, waystones | Trader stock `requiredGlobalKey`/`notRequiredGlobalKey` left unset |
| Digitalroot/Max_Dungeon_Rooms | 2.0.39 | Larger dungeons | — |
| sighsorry/CreatureManager | 1.1.13 | Karma and Enforcer encounters | Creature cloning and customisation off |
| sighsorry/AdditiveDamageModifier | 1.2.4 | Additive resistances, player minimum-damage floor | — |
| turbero/PvPBiomeDominions | 1.7.6 | PvP death and retention rules | Biome-forced PvP off everywhere |
| sighsorry/CaptainValheim | 1.0.10 | Shields as active weapons | — |
| sighsorry/SecondaryAttacks | 1.2.4 | Secondary attacks for other weapon classes | — |
| sighsorry/Dive_In | 1.2.3 | Diving, water combat, underwater creature pursuit | — |
| sighsorry/Groundwork | 1.1.8 | Farming and terrain tools scaling with skill | — |
| sighsorry/RepairRequiresMaterials | 1.0.4 | Repairs cost materials; incinerator dismantling | — |
| sighsorry/VeiledRecipes | 1.1.3 | Recipes hidden until discovered | — |
| sighsorry/InventorySlots | 1.4.8 | Equipment and quick slots, comparison, multicraft | Keep-on-death off |
| turbero/DetailedLevels | 2.1.2 | Skill progress readout | — |
| sighsorry/AdminQoL | 1.1.3 | Admin console GUI and item sets | — |
| sighsorry/DataForge | 1.3.2 | Item, recipe and effect tuning | Tuning only: no cloned or custom items |
| sighsorry/SkadiNet | 1.1.3 | Peer-aware network pacing, dungeon-layer filtering | — |
| sighsorry/Blasted_Swimming_Tarred_Bug_Fix | 1.2.4 | Vanilla state and teardown bug fixes | — |
| sighsorry/Fast_AssetBundle_Loader | 1.0.7 | Startup asset-bundle caching | — |
| TOYNBEE/BoneMod | 1.0.1 | Cosmetic bone scaling (client-side) | — |
| ValheimModding/Jotunn | 2.30.0 | Library | Overrides the 2.29.2 pin declared by EpicLoot, ProgressivePowers and MWL AIO |
| ValheimModding/JsonDotNET | 13.0.4 | Library | — |
| ValheimModding/YamlDotNet | 16.3.1 | Library | — |

## Forks

Upstream has no working 1.0.7 build, so we own these. Each lives in `src/forks/<Name>/` with an
`UPSTREAM.md`; see [build.md](build.md) and `../src/forks/README.md`.

| Fork | Forked from | Why | Ticket |
| --- | --- | --- | --- |
| WackyEpicMMOSystem | 1.9.62, BepInEx 5.4.2202 | Character level curve; upstream last touched 2026-09-06 with no 1.0 work | #5 |
| WackyItemRequiresSkillLevel | 1.4.6, BepInEx 5.4.2333 | Gates equipping on character level; upstream stale since May | #4 |
| MaxPlayerCount | 1.2.5, BepInEx 5.4.2333 | Player cap above 10; ours to patch if the fork will not carry it | #9 |
| ValheimRAFT | 4.2.2, Jotunn 2.27.0, no pack pin | Ships and anchoring; cannons and their projectile system disabled | #26 |

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

## Verification gate

No mod enters the pack until it has, on our own 1.0.7 test server:

1. loaded with no `MissingFieldException` or `MissingMethodException`,
2. broadcast its synced config without throwing — the failure mode ADR-0002 exists for,
3. survived a two-client session (#10).

Installing and verifying the pinned stack is #25. Package hashes are pinned in
[modstack.lock.json](modstack.lock.json); `scripts/stage-stack.sh` verifies every download
against it and refuses a re-published zip under the same version number.

## Verification record

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
