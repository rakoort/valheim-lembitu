# The mod stack

What the development candidate runs, at which version, and what we changed about each default.
This file records exact versions for reproducible tests, not a prelaunch freeze. The reasoning is
in [adr/](adr/) and the vocabulary in [../CONTEXT.md](../CONTEXT.md).

Adopted pins were checked against live Thunderstore package APIs on **2026-10-03**, and the test
server booted the pack on **1.0.16 / network 40** with BepInExPack 5.4.2351 that day. Development
follows the latest public Valheim client/server and latest mod releases. The live server runs
**1.0.14 / network 40** as of 2026-09-17; it had been 1.0.12, and nobody chose the change — the
container's updater ran its first pass on an idle restart, re-synced the game from Steam and
re-extracted BepInEx over the plugin tree, which cost one boot with zero plugins loaded. The
network version did not move, so clients were unaffected. `config/launch/launch.env.example`
documents exactly this hole: `UPDATE_CRON` is empty, but the updater's startup call still fires
when the server is idle. Freeze only after the acceptance gate below passes, before launch-world
creation (ADR-0007, ADR-0009).

The stack was reduced from thirty packages to twenty-three on **2026-09-15**, and every planned
plugin of ours except the test harness was cancelled, because upstream mods now cover the
load-bearing behaviour (ADR-0010). What was removed and why is in [Considered and cut](#considered-and-cut).

**This table is the repository state.** It carries twenty-seven pins after the owner's
2026-10-03 removal of three packages. The lock records their exact package bytes.
The retired fork and plugins are deleted from `src/`, and `src/forks/` contains only
MaxPlayerCount. The dated measurements below established earlier packs, not this candidate.

## Adopted upstream

Every mod here is pinned at exactly this version; the side it runs on is in
[Where each mod runs](#where-each-mod-runs). Most are installed on the server *and* the client
pack, DiscordConnector is withheld from the Pack as server-only,
and three ride in the Pack alone: AzuHoverStats, AzuClock and MouseTweaks. Candidate staging is
not deployment or verification. "Enforced config" is a deliberate deviation from the defaults and
belongs in server-locked config rather than a player's file.

| Mod | Pin | Role | Enforced config |
| --- | --- | --- | --- |
| sighsorry/Clan | 1.1.3 | Clans, roles, clan chat, guest clans, clan pings | Friendly fire off; config locked |
| sighsorry/STU_Ward | 1.3.17 | Wards resolved against clan membership | — |
| VentureValheim/World_Advancement_Progression | 1.0.0 | Personal keys: private per-character progression, per-player raids, key-gated actions, vanilla skill caps | Private keys on, all global keys blocked; equipment, crafting, cooking, eating, guardian powers and boss summons locked; repairs, building, taming, boats and portals open; skill floor from boss keys with the ceiling at 100 |
| RandyKnapp/EpicLoot | 0.14.13 | Gear tiers: magic drops, rarities, enchanting, shardstones and Haldor's adventure trade | Rebuilt from package defaults 2026-10-04: `Item Drop Limits = PlayerMustKnowRecipe` and `Gated Freebuild Mode = Unlimited`, because both boss-kill modes read world keys this server blocks; drop rate 0.6; shardstones 0.1; failed tempering can destroy the item; Adventure Mode on with at most five bounties per player. Stock enchant counts per rarity already match the old #73 patch |
| WackyMole/WackyEpicMMOSystem | 1.9.71 | Character level: XP, attributes, level band, XP meads | XP curve and attributes at upstream values; XP loss band 0.05-0.15; its own creature-level control off, so CreatureManager owns levels. Restored 2026-09-17 (2026-09-17, owner's instruction) without its armour-gate companion, so no level gates gear. `altLevelUpSound = false` pinned 2026-09-18: the quieter of the two bundled level-up clips, and the mod has no volume key |
| sighsorry/CreatureManager | 1.2.4 | Fixed creature and boss multipliers, monster modifiers, and holding vanilla's headcount scaling at zero | Cloning and customisation off; `Biome Level Preset = Hard`; Karma at `KarmaLevelAndEnforcer` with the cap and four blocking switches pinned; modifiers on from 2026-10-04 at about 10 in 100 ordinary creatures, about one per boss and two per Enforcer, without deathward, regenerating, omen or blamer (`levels.yml`, `karma.yml`); headcount scaling pinned at 0 / 0 / 1 |
| sighsorry/Dive_In | 1.2.3 | Diving, water combat, underwater creature pursuit | — |
| Azumatt/AzuExtendedPlayerInventory | 2.4.14 | Equipment slots, quick slots, Wishbone and Demister slots | Extra rows 0, three quick slots, equipment and special slots on; the vanity button off, which is the only switch the mod has for it |
| Azumatt/AzuCraftyBoxes | 1.8.19 | Crafting and building pull materials from containers near the station | `Container Range` 20 m; `Leave One Item` off; `Mod Enabled` on; config locked; `Azumatt.AzuCraftyBoxes.yml` committed empty, so everything in range is pullable |
| Azumatt/AzuHoverStats | 1.1.10 | Hover readouts for creatures, pieces, items, chests and crafting timers | — Nothing in it is server-synced, so the server can pin nothing; client-only |
| Azumatt/AzuClock | 1.1.0 | On-screen clock and weather forecast | — Client-only |
| Azumatt/MouseTweaks | 1.0.4 | Inventory moving, stack splitting and quick-dropping with mouse and modifier | — Client-only |
| Azumatt/ProximityVoiceChat | 1.0.2 | Positional voice chat, quieter with distance, no external program | Voice ranges and the Opus codec pinned; microphone, playback, indicators and keybinds stay the player's |
| turbero/DetailedLevels | 2.1.3 | Skill progress readout | — |
| sighsorry/DataForge | 1.3.5 | Item, recipe and effect tuning | Tuning only: no cloned or custom items |
| sighsorry/SkadiNet | 1.1.6 | Peer-aware network pacing, dungeon-layer filtering | — |
| sighsorry/Blasted_Swimming_Tarred_Bug_Fix | 1.2.6 | Vanilla state and teardown bug fixes | — |
| nwesterhausen/DiscordConnector | 3.1.3 | Server-side Discord webhook relay: joins, deaths, events | Webhook URL is a secret, set per deployment |
| JereKuusela/Expand_World_Size | 1.43.0 | World radius, edge and stretch. World-permanent in the strongest sense: the values are baked into terrain at generation | `World radius` 12500, `Stretch world` 1.25, `Stretch biomes` 1.25 — about 1.56x vanilla area, chosen 2026-10-03 for the collaborative world (ADR-0018's 15000/1.5/1.25 was sized for rival clans) |
| Mushroom_Vikings/SeparateSpawns | 0.1.1 | Three start groups (Skadi, Fenrir, Muninn), each scored for a viable neighbourhood | `InnerRadius` 2400, starts 1 km apart. From 2026-10-03 the server is collaborative: the roster seeds three empty groups, the mod assigns each new player at random, and nobody curates it. Its config lives in the game tree rather than BepInEx's, so `config/dedicated/` and `scripts/apply-dedicated-config.sh` own it, not the enforced overlay |
| MidnightMods/ProgressivePowers | 0.3.4 | Forsaken power mastery: powers grow with use | A third power curve, adopted against ADR-0004's rule and recorded in ADR-0018 |
| Vapok/AdventureBackpacks | 2.2.5 | Backpacks with their own storage | One-way: the packs are registered items, so removing the mod deletes them and their contents |
| ishid4/BetterArchery | 2.0.2 | Quivers, draw and aiming changes for bows | — Declares BepInEx 5.4.1501, a documented override |
| OdinPlus/OdinArchitect | 1.7.9 | Larger and new building pieces | — Added 2026-10-03 (owner's instruction). One-way: its pieces live in the world save |
| MathiasDecrock/PlanBuild | 0.20.0 | Plan, copy and share builds; terrain tools | — Added 2026-10-03 (owner's instruction) |
| OdinPlus/OdinsKingdom | 1.6.2 | Castle building pieces with their own build tool | — Added 2026-10-03 (owner's instruction). One-way: its pieces live in the world save |
| RustyMods/Seasonality | 3.8.3 | Seasons that change textures and colours over time | — Added 2026-10-03 (owner's instruction) |
| ComfyMods/SearsCatalog | 1.9.0 | Resizable, movable build panel | — Added 2026-10-03 (owner's instruction). Declares BepInEx 5.4.2202, a documented override |
| SpikeHimself/XPortal | 1.2.25 | Pick a portal destination from a list | — Added 2026-10-03 (owner's instruction). The only portal mod since PortalRules left the same day |
| Marlthon/OdinShip | 0.8.7 | Seven cargo and war ships | — Added 2026-10-03 (owner's instruction). One-way: its ships live in the world save |
| blacks7ar/GlassPieces | 1.2.8 | Glass, iron and copper building pieces and a minable resource | — Added 2026-10-03 (owner's instruction). One-way: its pieces live in the world save |
| Marlthon/TheFisher | 0.3.9 | New fish, aquatic creatures and aquariums | — Added 2026-10-03 (owner's instruction) |
| Advize/PlantEverything | 1.21.3 | Cultivator plants berry bushes, flowers, mushrooms, extra trees and more | — Added 2026-10-04 (owner's instruction) |
| blacks7ar/MagicPlugin | 2.2.2 | Magic weapons, summoning totems, armour sets and accessories from early to end game | — Added 2026-10-04 (owner's instruction). A further power curve beside EpicLoot, character level and ProgressivePowers (ADR-0004, ADR-0018) |
| OdinPlus/OdinsFoodBarrels | 1.3.9 | Buildable storage barrels for seeds, fruit and vegetables | — Added 2026-10-04 (owner's instruction). One-way: its pieces live in the world save |
| OdinPlus/OdinCampsite | 1.6.5 | Camping-style building pieces | — Added 2026-10-04 (owner's instruction). One-way: its pieces live in the world save |
| blacks7ar/SeedBed | 1.2.9 | Plant seeds in a bed instead of cultivated ground | — Added 2026-10-04 (owner's instruction). One-way: its pieces live in the world save |
| Marlthon/SeaAnimals | 0.3.9 | Dangerous and rideable ocean creatures | — Added 2026-10-04 (owner's instruction) |
| Mydayyy/ServerSideMap | 1.3.14 | Shared explored map and pins, held on the server | — Added 2026-10-04 (owner's instruction). Incompatible with crossplay, which this server does not use |
| blacks7ar/Herbalist | 1.5.0 | Herbalism skill, a crafting station, tonics and recovery items | — Added 2026-10-04 (owner's instruction). One-way: its station lives in the world save |
| MSchmoecker/DynamicStoragePiles | 0.8.1 | Stack and pile containers that show their fill level | — Added 2026-10-04 (owner's instruction). One-way: its pieces live in the world save |
| seneaL/SeneaL_UI | 1.1.7 | Full UI redesign: HUD, inventory, chests, crafting, build menu, map | — Added 2026-10-04 (owner's instruction). Declares BepInEx 5.4.2202, a documented override |
| Searica/DodgeShortcut | 1.4.0 | A single dodge key | — Added 2026-10-04 (owner's instruction) |
| blacks7ar/BetterStations | 1.0.9 | Reworked smelter, blast furnace, kiln, spinning wheel, eitr refinery and windmill | — Added 2026-10-04 (owner's instruction) |
| OdinPlus/BlacksmithingExpanded | 1.2.4 | Blacksmithing skill that improves crafting, smelting and kiln output | — Added 2026-10-04 (owner's instruction) |
| xtavim/BetterMap | 1.1.0 | Creatures, boats, carts and resources on the map; automatic pins | — Added 2026-10-04 (owner's instruction) |
| MilkMediaProductions/ExpertExplorer | 1.7.0 | Exploration skill that grows as points of interest are found | — Added 2026-10-04 (owner's instruction) |
| ValheimModding/Jotunn | 2.30.2 | Library | Overrides the 2.29.2 pin declared by EpicLoot |
| ValheimModding/JsonDotNET | 13.0.4 | Library | — |
| ValheimModding/YamlDotNet | 16.3.1 | Library | Declared by ServersideQoL, and its own detector plugin loads it either way (#66 boot) |

## Where each mod runs

Four groups, decided by evidence rather than by the package descriptions. The first group is
observable: at every join the server announces a version for each mod that participates in the
config/version handshake, and refuses a client that answers with the wrong version or none. The
list below is the server's own announcement, read from the live log on 2026-09-16, except the one
row marked as read from the assembly instead. Every other row, AzuExtendedPlayerInventory
included, has been read from a join: the 14:48 UTC+2 join of a v7 client logged `Sending
AzuExtendedPlayerInventory version 2.4.14 and minimum version 2.4.14 to the client`, then
`Version check, local: 2.4.14, remote: 2.4.14` and `Adding peer to validated list`.

Enforcement comes in two shapes, and the difference decides whether installing a mod on the
server refuses the players who lack it. ServerSync's own `VersionCheck` only refuses a silent peer
when its `ConfigSync.ModRequired` is true, and every Azumatt mod in this pack leaves that false.
What makes those mods mandatory is a *hand-rolled* check they each carry: a `ZNet.OnNewConnection`
prefix registers and invokes `<Mod>_VersionCheck`, and a `ZNet.RPC_PeerInfo` prefix disconnects
any peer the server has not recorded in `ValidatedPeers`. A client without the mod never answers,
so it is refused. A mod with neither mechanism refuses nobody.

**Both sides, and the server enforces it.** A client missing any of these is refused at the
handshake with `doesn't have the correct <mod> version`. Jotunn is enforced separately and first:
without it the server logs `Jötunn is not installed on the client. Server has mandatory mods,
cancelling connection`.

| Mod | Announced as |
| --- | --- |
| sighsorry/Clan | `Clan`, and `Clan Media` as a second channel |
| sighsorry/STU_Ward | `STUWard` |
| sighsorry/CreatureManager | `CreatureManager` |
| sighsorry/DataForge | `DataForge` |
| sighsorry/Dive_In | `DiveIn` |
| Azumatt/AzuExtendedPlayerInventory | `AzuExtendedPlayerInventory` |
| sighsorry/SkadiNet | `SkadiNet` |
| sighsorry/Blasted_Swimming_Tarred_Bug_Fix | `BlastedSwimmingTarredBugFix` |
| turbero/DetailedLevels | `Detailed Levels` |
| WackyMole/WackyEpicMMOSystem | `EpicMMOSystem`, plus its `ItemManager` and `PieceManager` |
| Azumatt/AzuCraftyBoxes | `AzuCraftyBoxes`. **Read from `AzuCraftyBoxes.dll` 1.8.19, and loaded on the live server 2026-09-16** (`Loading [AzuCraftyBoxes 1.8.19]`, then `Registered 'Azumatt.AzuCraftyBoxes ConfigSync' RPC`), but not yet read from a join: ServerSync announces the version whenever `IsServer()`, and the hand-rolled `AzuCraftyBoxes_VersionCheck` refuses a client that never answers. The refusal itself is what the group's first v8 session confirms (#78) |
| ValheimModding/Jotunn | mandatory-mod check, not a version line |

**Both sides, but not enforced.** These need the client to work fully and will not refuse a join
without it, so a client that skips them looks connected and behaves wrongly — except
ProximityVoiceChat, where the failure is benign and deliberate.

| Mod | Why the client needs it |
| --- | --- |
| RandyKnapp/EpicLoot | Drops are rolled where the player is, and `PlayerMustKnowRecipe` reads `Player.m_localPlayer`. The server pushes `loottables.json` to every client at join, so the tables are the server's, but the rolling and the UI are the client's |
| VentureValheim/World_Advancement_Progression | Server-side alone it only blocks the world's global key list. Private keys, every lock, and the skill floor are client features (upstream README, "Server-Side Only?") |
| ValheimModding/JsonDotNET, ValheimModding/YamlDotNet | Libraries the above load on whichever side they run |
| Azumatt/ProximityVoiceChat | Voice is captured, encoded and played on the client; the server holds the ranges and the codec through `ConfigSync("Azumatt.ProximityVoiceChat")`. `ModRequired` is false and there is no hand-rolled check, so a friend without the mod joins and plays with no voice rather than being refused (read from `ProximityVoiceChat.dll` 1.0.2) |

**Server-only.** Installing these on a client changes nothing a player can see.

| Mod | Why |
| --- | --- |
| MaxPlayerCount (fork) | Every patched surface runs on the host; a client is told the capacity by the server. Already excluded from the client pack by an assertion in the builder |
| nwesterhausen/DiscordConnector | Reads server events and posts a webhook; there is no client half |

**Client-only — presentation only, reopened 2026-09-16 (#78).** The 2026-09-16 review had cut this
whole category, on the AdminQoL lesson: a mod the server cannot enforce is a mod whose behaviour
varies per player, and AdminQoL's gameplay defaults disabled durability loss for a full evening
with no server setting able to reach them. #78 narrows that rather than reversing it. A
presentation-only mod may ride in the Pack, because a player who removes it sees vanilla and no
rule changes. A gameplay-bearing mod the server cannot reach still does not ship.

| Mod | Decision |
| --- | --- |
| Azumatt/AzuHoverStats | **Adopted client-only.** Hover readouts for creatures, pieces, items and chests. Nothing in it is server-synced — every entry is a plain `Config.Bind` and there is no `ConfigSync` in the assembly — so the server could pin nothing even if it ran the mod, while installing it server-side *would* refuse every client that lacks it through its hand-rolled `AzuHoverStats_VersionCheck`. Its chest readout is not an information bypass: the `Container.GetHoverText` postfix bails on `m_checkGuardStone && !PrivateArea.CheckAccess(...)`, and STU_Ward prefixes exactly that method with clan-resolved trust, so another clan's warded chest shows nothing (#78) |
| Azumatt/AzuClock | **Adopted client-only.** Clock and weather forecast on screen. It bundles ServerSync but is not installed on the server, so nothing of it is synchronised; a player who removes it loses a readout |
| Azumatt/MouseTweaks | **Adopted client-only.** Mouse and modifier handling for moving, splitting and dropping stacks. Plain `Config.Bind` throughout, keybinds and thresholds only |
| sighsorry/AdminQoL | **Dropped.** All 29 settings are client-decided: none is marked `[Synced with Server]` and it takes no part in the handshake (#70) |
| TOYNBEE/BoneMod | **Dropped.** Cosmetic bone scaling, client-side, pointless on the server, and unenforceable by the same argument (#70) |
| Lembitu.Harness | **Kept in the repository, never in the Pack.** It is our test harness for future acceptance work, inert without `-lembitu-harness`, and the builder asserts it is absent from a player's pack |

**Client-only is a deployment rule, and it is enforced by the installer.** `scripts/stage-stack.sh`
stages every adopted pin into `dist/`, because the client Pack is built from the same table, so
`dist/` alone does not distinguish the sides. `scripts/install-plugins.sh` carries the server's
half — a `CLIENT_ONLY` list naming AzuHoverStats, AzuClock and MouseTweaks — and it withholds them
from a server install and prunes them from a server that already has one. That is not tidiness:
AzuHoverStats disconnects a peer that does not answer its version check, so deploying it would
refuse exactly the players the Pack shipped it for. The mirror-image list, for the server-only
packages a player's Pack must not carry, lives in `scripts/build-client-pack.sh` (#78).

Both drops are done. `scripts/build-client-pack.sh` asserts that a required client-side package is
present, to catch a pack that silently lost content, and BoneMod was the only entry in that list;
the assertion is repointed to Jotunn rather than deleted, because a client without Jotunn is
refused at the handshake outright, so its absence is a hard failure rather than a missing feature.
AzuCraftyBoxes joins it for the same reason from v8 on: once the server runs it, a Pack that lost
it would refuse every player who installed that Pack. `test/client-pack.test.sh` covers the
assertion.

**Historical client-pack trimming — 2026-09-16.** The v5 archive contained DiscordConnector
and Max_Dungeon_Rooms; both left the client pack in v6 (#70). This was client-side trimming,
not the 2026-10-03 removal of the dungeon mod from the stack.

## Forks

One fork remains. Adoption is the default (ADR-0003), and configuration reaches most
project-specific behaviour without owning someone else's source.

| Fork | Forked from | Why | Ticket |
| --- | --- | --- | --- |
| MaxPlayerCount | `AzumattDev/MaxPlayerCount@4482e27` = 1.2.4 source, pinned release 1.2.5, MIT-0 | Player cap above 10, raised to 20. Upstream 1.2.5 is binary-only and declares an older BepInEx pack, so there is nothing to recompile and no adopted package that does this | #9 |

MaxPlayerCount is server-only and stays out of the client pack: every surface it patches runs on the
host, and a client is told the server's capacity by the server. Its config default is 20.

## Our plugins

| Plugin | What it owns | Ticket |
| --- | --- | --- |
| Lembitu.Harness | Client-side test harness: joins the test server from a real client and drives a character through code | #10 |

The harness is test infrastructure, not pack content. It is inert unless the client is launched with
`-lembitu-harness`, and it ships to the disposable test client only.

## Deferred capability

The **Trade Post** — contracts, escrow and mailbox delivery as server records (ADR-0006, #16) — is
not built and not in the pack. It is deliberately safe to add mid-run: its state lives in server
records that never enter the world save, so only its buildable piece becomes one-way, and only from
the day it ships. DataForge therefore stays restricted to tuning, because a later ledger needs
stable item identity.

## World-permanent mods

No remaining mod writes the added dungeon-room or vehicle-prefab content covered by ADR-0009.
Expand_World_Size is world-permanent for terrain generation, as described in ADR-0018; its
settings must stay fixed while that world lives. The 2026-10-03 removal risk is recorded in
[Pack](wiki/pack.md).

EpicLoot and World Advancement Progression are one-way for a different reason: removing them
destroys player gear or per-character progress rather than corrupting the world. World Advancement
Progression additionally clears the world's global keys on startup, so it belongs in the pack before
the launch world is created rather than after.

## Acceptance gate

No pin is cleared for the launch pack until, on the current public test game:

1. the whole pack boots clean on a dedicated server — chainloader completion, the native Steam
   listener, and no `MissingFieldException` or `MissingMethodException`,
2. one manual two-client session covers a boss kill, personal keys surviving reconnect, a ward, a
   portal and a vanilla boat.

That is the whole bar. Per-feature single-client scenario coverage was cancelled with the plugins it
was written for: nothing in the pack is ours, so proving each mod's own features is upstream's job
and ours only where the pack combines them.

One question belongs to that boot rather than to argument:

- **One gate refuses crafting and equipping, and it has never been observed doing it.** World
  Advancement Progression refuses on personal keys, by the biome of an item's materials. Until #80
  there were two such gates and the boot had to separate them; character level is gone, so a single
  observed refusal is what the gate needs.

Package hashes are recorded in [modstack.lock.json](modstack.lock.json); `scripts/stage-stack.sh`
verifies every download against it and refuses a re-published zip under the same version number.

### Measured on a disposable host — 2026-09-15

The reduced pack was staged and booted once on astral-tricep from an off-repository copy of the
source, to answer questions the tables above depend on. This is a throwaway measurement, not the
acceptance run: no client joined, and the repository carried the old pins at the time. #66 then
landed the same pack in the repository and repeated the boot with the enforced overlay in effect,
which is the section after this one.

All twenty-three packages staged with verified hashes and passed dependency closure. The build
produced only MaxPlayerCount and Lembitu.Harness, with zero warnings and zero errors. The server
reached `Chainloader startup complete` and the native Steam listener with twenty-nine plugins
loaded and **no `MissingFieldException` or `MissingMethodException`**. Thirteen errors remained,
all of them the vanilla headless noise already documented: two `AsyncResourceUpload failed`, the
`Hidden/VideoDecode` and `Hidden/VideoComposite` material and shader-pass lines, and the failed
intro cinematic.

Four findings the tables above rest on:

- **The eight Jotunn `Ambiguous asset name` warnings are still there with MWL removed.** They come
  from Jotunn indexing the vanilla catalogue, not from any mod's reference, so cutting content does
  not silence them and no reference needs correcting.
- **YamlDotNet stays.** Its own detector plugin loads it (`YamlDotNet 16.0.0.0 loaded from
  plugins/YamlDotNet/YamlDotNet.dll`), so the missing declaration is a manifest gap, not a dead pin.
- **EpicMMOSystem 1.9.67 writes no `Players.json`.** It deploys twenty-seven tables and the
  version marker; the stranger's XP-bonus file the retired fork emptied is simply gone upstream,
  so that overlay is unnecessary.
- **Three adopted packages declare older dependency pins** — EpicLoot and DiscordConnector name
  BepInEx 5.4.2333, WackyEpicMMOSystem names 5.4.2202 — so `scripts/stage-stack.sh` records those
  as deliberate overrides; without them the closure check refuses to stage the pack. #66 added
  them.

Two of those four findings have since expired. EpicMMOSystem left the pack in #80, so its
`Players.json` behaviour no longer matters, and only two adopted packages now declare an older
BepInEx pack — EpicLoot and DiscordConnector, both at 5.4.2333 — because WackyEpicMMOSystem was the
one that named 5.4.2202.

### Config surfaces this pack uses

Read off the generated files in that boot, so the enforced overlays name real keys:

- **Personal keys** — `com.orianaventure.mod.WorldAdvancementProgression.cfg`, section `[Keys]`
  (`BlockAllGlobalKeys`, `UsePrivateKeys`), `[Locking]` (`LockEquipment`, `LockCrafting`, and the
  locks we leave off), `[Raids]` (`UsePrivateRaids`), `[Skills]` (`EnableSkillManager`, now *on*
  as a floor that follows private boss keys, with the ceiling left at vanilla; the 2026-09-16
  review reversed the earlier decision to leave it off).
- **Loot gating** — `randyknapp.mods.epicloot.cfg`, section `[2 - Balance]`, key
  `Item Drop Limits`, set to `PlayerMustKnowRecipe`. Caveat worth knowing before the session: the
  mode reads `Player.m_localPlayer.IsRecipeKnown`, and EpicLoot gates everything when there is no
  local player, so it only works where loot is rolled on a client. The two-client session must show
  real magic drops rather than universal downgrades; if it does not, the fallback is `Unlimited`.
- **Difficulty tier** — `sighsorry.CreatureManager.cfg`, section `[2 - Levels]`
  (`Biome Level Preset = Hard`, `Bosses Follow Biome Level Preset`). The preset is mostly about
  ordinary creatures: it sets the level distribution for every natural spawn in a biome, and `Hard`
  spawns roughly 40% stronger creatures than the `Easy` default. Bosses follow the same preset, so
  boss level and therefore boss health — through the `Boss` `healthPerLevel` default — rises by
  biome tier; expected boss health runs ×1.05 for Eikthyr to ×2.11 for Fader. `Hard` is not the
  package default, so it is pinned deliberately (#13). Section
  `[4 - Multiplayer Difficulty]` used to be left untouched, on the reasoning that extra players
  should help rather than inflate the boss. The 2026-09-16 review took the opposite decision and
  removed headcount from the question entirely: both percentages are zero and the cap is one, and
  difficulty is set in `levels.yml` instead, at `Global.health = 2` and `Boss.health = 8`. Ordinary
  health was 4 until 2026-09-17, when character level left the Pack and every character lost its
  attribute points (#80). That file is committed and replaced wholesale, with the cost the earlier
  note named — it grows fields with every release, so a package update is a review of this file
  (#68). Its modifier chances are also ours (2026-10-04): the mod rolls one modifier per group,
  four groups, so the tables are tuned per group to give about 10 in 100 ordinary creatures, one
  modifier per boss and, in `karma.yml`, two per Enforcer.

## Known interactions

Recorded so they are not rediscovered:

- **AzuEPI's vanity system has no off switch, and hiding its button is enough.** Established from
  `AzuExtendedPlayerInventory.dll` 2.4.14, sha256 `852dcde0…6840b6`, decompiled with ilspycmd 11,
  because the readme only claims the `Minimal` preset "turns off the vanity button". One key
  controls the surface — `[5 - UI Features] Show Vanity Button` — and its whole effect is
  `VanityButtonGo.SetActive(...)`. A second vanity key exists, `Hide Unknown Vanity Items`, but
  it only decides whether the panel lists undiscovered armour, so it changes nothing once the
  panel cannot be opened. Nothing gates the vanity system itself. It is sufficient
  anyway: that same GameObject carries the gamepad binding built from
  `Vanity Panel Toggle Key`, so an inactive button leaves no button, no gamepad route and no way
  to author a vanity set. Present and unreachable, which is what the run wants. The key is
  synchronised, so the server holds it for everyone
  (`config/enforced/Azumatt.AzuExtendedPlayerInventory.cfg`). The `Minimal` preset is not used:
  it would take loadouts and the stats panel with it, and both are kept deliberately (#74).
- **The Pack's inventory mod is part of the announced set, and that is the safe failure.**
  AzuExtendedPlayerInventory participates in the join-time version handshake, so any change to
  which slot mod the server runs refuses an older Pack outright rather than mismatching silently.
  Every player needs the current Pack before they can connect (#74).
- **Removal — 2026-10-03.** PvPBiomeDominions left at the owner's instruction. Its
  flagged-player retention and tombstone-looting rules no longer apply; deaths use vanilla rules.
- **Progression lives in the character save.** World Advancement Progression stores personal keys
  in the player's own character file, so a client owns its own progression. This is accepted, with
  no tamper resistance (ADR-0010). Character level used to live there too, in
  `Player.m_knownTexts`; #80 removed it, and those keys are now stranded text in every character
  file that ever had a level.
- **Creature level authority.** CreatureManager owns creature star levels outright: the biome
  preset rolls them and Karma raises them. EpicLoot's rarity rolls read that level, and boss level
  from the same preset sits on top of it. Until #80, character level rewrote those levels first,
  which is the claim ADR-0005 was written against.
- **Historical piece-category finding — September 2026.** Custom pieces from ValheimRAFT
  could appear without a build-menu category. That package left on 2026-10-03.
- **Current dependency skews are explicit.** EpicLoot runs against the Jotunn 2.30.2 pin;
  the staging script lists accepted older dependency declarations. Manifest closure is not
  proof that this refreshed combination passes gameplay acceptance.
- **AzuCraftyBoxes' restriction file is committed empty, and one API can rewrite it.** Read from
  `AzuCraftyBoxes.dll` 1.8.19, sha256 `5a191f9c…3084d`. `YamlUtils.ReadYaml` turns a blank file
  into an empty dictionary, and `CanItemBePulled` returns true for any container the dictionary
  does not name, so an empty `Azumatt.AzuCraftyBoxes.yml` means everything in range is pullable.
  The file must exist, because the plugin writes its bundled `Example.yml` when the path is
  missing. Two facts to keep: `Containers.AddContainerIfNotExists` is a public API that appends a
  container and rewrites the file, and `YamlUtils.WriteYaml` serialises the data twice into the
  same file, so anything that calls it leaves a doubled document. Nothing in this pack calls it,
  and the overlay is compared byte for byte on every restart, so a rewrite shows up as drift
  rather than as silence (#78).
- **Two Azumatt mods refuse a client on a per-mod RPC, not through ServerSync.** AzuCraftyBoxes
  and AzuHoverStats each patch `ZNet.OnNewConnection` to invoke `<Mod>_VersionCheck` and
  `ZNet.RPC_PeerInfo` to disconnect a peer that never answered. That is what makes a server-side
  install mandatory for players, independently of `ConfigSync.ModRequired`, which both leave
  false. It is also why AzuHoverStats is client-only: the mod would refuse clients while
  synchronising nothing (#78).

## Considered and cut

Kept out deliberately. Each line is a decision, not an oversight.

EpicLoot, ValheimRAFT and WackyEpicMMOSystem were removed and restored on 2026-09-17
(ADR-0017). Levels, magic item properties and vessels lost in that removal did not return.
On 2026-10-03 the owner removed ValheimRAFT again, along with Max Dungeon Rooms and
PvPBiomeDominions. EpicLoot and WackyEpicMMOSystem remain pinned above.

| Mod | Why not |
| --- | --- |
| sighsorry/BossRules | World Advancement Progression gates boss summons and guardian powers per key; its remaining refunds and stones did not justify the mod, its overlay and the altar-scan guard we had to write |
| MidnightMods/ProgressivePowers | Cut on 2026-09-15, then restored; currently adopted above |
| warpalicious/More_World_Locations_AIO | 185 locations at the cost of a world-permanent dependency and four open defect tickets; the stack now uses vanilla locations |
| sighsorry/Fast_AssetBundle_Loader | Existed for MWL's 200+ bundles, and produced Linux `DriveInfo` failures and a shared-cache isolation deviation |
| sighsorry/CaptainValheim, sighsorry/SecondaryAttacks, sighsorry/AdditiveDamageModifier | Three combat layers landing on one damage number; removed rather than tuned |
| sighsorry/VeiledRecipes | Recipe discovery is already what EpicLoot's `PlayerMustKnowRecipe` gating reads |
| sighsorry/RepairRequiresMaterials | Friction without a rule behind it |
| sighsorry/Groundwork | Tool scaling not worth another mod on the placement path it already broke once |
| MidnightMods/ImpactfulSkills | Third power curve (ADR-0004) |
| sighsorry/Valheim_Enchantment_System | Second enchanting path on the same items (ADR-0004) |
| MidnightMods/ValheimArmory | New base weapons need community EpicLoot patches to be enchantable (ADR-0004) |
| MidnightMods/StarLevelSystem | CreatureManager owns creature levels (ADR-0005, as amended) |
| Smoothbrain/Groups | Second membership authority (ADR-0008) |
| sighsorry/InventoryActions | Mutually exclusive with AzuExtendedPlayerInventory, which holds the slots for this run, and smaller |
| Nosferatu/SmoothServer | One pacing layer only; SkadiNet chosen |
| WackyMole/WackysDatabase | DataForge covers tuning |
| Tristan/Valheim_PvP_Tweaks | Excluded in September 2026 for overlapping PvPBiomeDominions and old pins; not adopted as a replacement after the 2026-10-03 removal |
| sighsorry/ServerManager | Its Discord and logging role is DiscordConnector's |
| AWLGaming/DiscordBot_AWL, warpalicious/DiscordTools, RustyMods/DiscordBot | Need an external bot host or two-way chat; the relay is a webhook |
| warpalicious/Discord_Screenshots | Client-only, nothing depends on it |
| sighsorry/YouAreNotWorthy | Gates on world keys, which this server does not write |
| shudnal/ProtectiveWards | STU_Ward covers wards |
| Therzie/Warfare | Untouched since March 2025 |
| ZenDragon/ZenBossStone | Per-player boss trophies, but pulls a second mod library into the closure |
| Hex_Viking/HexResourceTracker, GChallenge/GCValheimStats, Tristan/Player_Activity, Eilif/EilifPaths | Client-only and unenforceable; EilifPaths also changes gameplay per player |
| KGvalheim/Marketplace_And_Server_NPCs_Revamped | Deprecated on Thunderstore and pre-1.0. Design reference for the deferred Trade Post only |
| MSchmoecker/MultiUserChest | The only candidate that changes networked item movement, which is where duplication and item loss live. The vanilla "someone is in the chest" wait is an annoyance, not a problem. A risk judgement, not a conflict: its own incompatibility list — QuickStore, QuickStack, SimpleSort — touches nothing in this pack (#78) |
| Crystal/BetterChat | Clan owns the chat window: it patches `Chat.Awake`, `InputText`, `HasFocus`, `Update`, `RPC_ChatMessage` and `SendPing`, and BetterChat rewrites the same input handling and visibility, risking the clan channel's prefixes. It would also add `shudnal/ConditionalConfigSync` 1.0.6 to the closure purely to make its own settings enforceable (#78) |
| ArgusMagnus/ServersideQoL, ArgusMagnus/ServersideQoL_JustSleep | **Removed 2026-09-17, hours after adoption, without ever working.** The framework ships a BepInEx *preloader patcher* and aborts unless it sits in the game tree's `patchers/` directory. `scripts/install-plugins.sh` deploys `patchers/` into `/config/bepinex`, but the container mirrors only `plugins/` into `/opt/valheim`, so the mod logged `ServersideQoL.Patchers.dll was not installed correctly` on every boot and JustSleep never wrote a config. Fixing it needs a second bespoke deploy step, like the one SeparateSpawns already needs; the owner judged a night-skip not worth that and cut both. The patcher gap in our installer is real and outlives the mods (#86) |
| Smoothbrain/CreatureLevelAndLootControl | **Tried and rejected 2026-09-17, on the live server.** It was the obvious replacement for CreatureManager — plain percentages for creature and boss health, its own affix tables, and the same three multiplayer-scaling keys — but 4.6.4 is from May 2025 and cannot run on Valheim 1.0: its bundled ServerSync reads `ZRoutedRpc.Everybody`, a field the game turned into a const, so its type initializer throws `TypeInitializationException` at boot and the mod does nothing. `scripts/screen-bundled-libs.sh` reports five stale references, and it was not run before the swap — which is the whole reason that script exists (ADR-0002, #84) |
| WackyMole/WackyItemRequiresSkillLevel | **Removed 2026-09-17 and not restored**, unlike the level mod it accompanied (2026-09-17, owner's instruction). Its curated rules gated iron, wolf, padded and carapace armour at character levels 20, 35, 50 and 65, and nothing reads those thresholds once there are no levels. World Advancement Progression's material-biome locks are the whole gear gate now (#80) |

## Re-pinning

Pins are re-checked once, immediately before the launch world is created, and then frozen for the
run. Between now and then, a newer upstream version replaces a pin only if it passes the gate above
again — most of this catalogue was re-published within the last week, so a pin chosen today is hours
old, not months.
