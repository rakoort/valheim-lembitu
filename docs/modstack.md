# The mod stack

What the development candidate runs, at which version, and what we changed about each default.
This file records exact versions for reproducible tests, not a prelaunch freeze. The reasoning is
in [adr/](adr/) and the vocabulary in [../CONTEXT.md](../CONTEXT.md).

Adopted pins were checked against live Thunderstore package APIs on **2026-09-15**. Development
follows the latest public Valheim client/server and latest mod releases. The current game candidate
is **1.0.12 / network 40**. Freeze only after the acceptance gate below passes, before launch-world
creation (ADR-0007, ADR-0009).

The stack was reduced from thirty packages to twenty-three on **2026-09-15**, and every planned
plugin of ours except the test harness was cancelled, because upstream mods now cover the
load-bearing behaviour (ADR-0010). What was removed and why is in [Considered and cut](#considered-and-cut).

**This table is now the repository state** (#66). `modstack.lock.json` carries exactly these
twenty-three pins, the retired fork and plugins are deleted from `src/`, `config/enforced/` holds
the overlays below, and `src/forks/` contains only MaxPlayerCount. The dated measurements further
down are the runs that established the pack, not a prediction of it.

## Adopted upstream

Every mod here is intended for the server *and* client pack at exactly this version (BoneMod is
client-side). Candidate staging is not deployment or verification. "Enforced config" is a deliberate
deviation from the defaults and belongs in server-locked config rather than a player's file.

| Mod | Pin | Role | Enforced config |
| --- | --- | --- | --- |
| sighsorry/Clan | 1.0.10 | Clans, roles, clan chat, guest clans, clan pings | Friendly fire off; config locked |
| sighsorry/STU_Ward | 1.3.15 | Wards resolved against clan membership | — |
| sighsorry/PortalRules | 1.0.7 | Portal access control | Access modes only: no fares, no map picker, no admin portals, GlobalKey gates unset; access-mode limits pinned at upstream values |
| VentureValheim/World_Advancement_Progression | 1.0.0 | Personal keys: private per-character progression, per-player raids, key-gated actions, vanilla skill caps | Private keys on, all global keys blocked; equipment, crafting, cooking, eating, guardian powers and boss summons locked; repairs, building, taming, boats and portals open; skill floor from boss keys with the ceiling at 100 |
| RandyKnapp/EpicLoot | 0.14.5 | Gear tiers: magic drops, rarities, enchanting and socketed shardstones | `Item Drop Limits` and `Gated Freebuild Mode` both `PlayerMustKnowRecipe`, so gating reads the player, not world keys; Adventure Mode off; drop rate 0.6, shardstones 0.05; effect counts thinned by patch (#73) |
| WackyMole/WackyEpicMMOSystem | 1.9.67 | Character level: XP, attributes, level band, XP meads | XP curve and attributes pinned at upstream values to be measured first; XP loss band 0.05-0.15; its own creature-level control off, so CreatureManager owns levels; non-combat and PvP XP undecided (#72) |
| WackyMole/WackyItemRequiresSkillLevel | 1.4.7 | Character-level gates on crafting, equipping and consuming | Curated rules in `WackyMole.ItemRequiresSkillLevel.yml` |
| sighsorry/CreatureManager | 1.1.14 | Karma and Enforcer encounters; creature and boss difficulty tier, spawn level, health and damage scaling | Creature cloning and customisation off; `Biome Level Preset = Hard`, so biome tier sets spawn and boss level |
| Digitalroot/Max_Dungeon_Rooms | 2.0.39 | Larger dungeons | — |
| team0/ValheimRAFT | 4.3.2 | Custom ships, anchoring and vehicle building | Server-synced `CannonPrefabs_Enabled = false` |
| turbero/PvPBiomeDominions | 1.7.8 | PvP death and retention rules | Biome-forced PvP off everywhere |
| sighsorry/Dive_In | 1.2.3 | Diving, water combat, underwater creature pursuit | — |
| sighsorry/InventorySlots | 1.4.17 | Equipment and quick slots, comparison, multicraft | Keep-on-death off |
| turbero/DetailedLevels | 2.1.3 | Skill progress readout | — |
| sighsorry/AdminQoL | 1.1.3 | Admin console GUI and item sets | **Dropped 2026-09-16** — client-decided, unenforceable (#70) |
| sighsorry/DataForge | 1.3.4 | Item, recipe and effect tuning | Tuning only: no cloned or custom items |
| sighsorry/SkadiNet | 1.1.5 | Peer-aware network pacing, dungeon-layer filtering | — |
| sighsorry/Blasted_Swimming_Tarred_Bug_Fix | 1.2.6 | Vanilla state and teardown bug fixes | — |
| nwesterhausen/DiscordConnector | 3.1.3 | Server-side Discord webhook relay: joins, deaths, events | Webhook URL is a secret, set per deployment |
| TOYNBEE/BoneMod | 1.0.2 | Cosmetic bone scaling (client-side) | **Dropped 2026-09-16** — client-only, unenforceable (#70) |
| ValheimModding/Jotunn | 2.30.0 | Library | Overrides the 2.29.2 pin declared by EpicLoot |
| ValheimModding/JsonDotNET | 13.0.4 | Library | — |
| ValheimModding/YamlDotNet | 16.3.1 | Library | Nothing declares it since the EpicMMOSystem fork was retired; the acceptance boot decides whether it stays |

## Where each mod runs

Three groups, decided by evidence rather than by the package descriptions. The first group is
observable: at every join the server announces a version for each mod that participates in the
config/version handshake, and refuses a client that answers with the wrong version or none. The
list below is the server's own announcement, read from the live log on 2026-09-16.

**Both sides, and the server enforces it.** A client missing any of these is refused at the
handshake with `doesn't have the correct <mod> version`. Jotunn is enforced separately and first:
without it the server logs `Jötunn is not installed on the client. Server has mandatory mods,
cancelling connection`.

| Mod | Announced as |
| --- | --- |
| sighsorry/Clan | `Clan`, and `Clan Media` as a second channel |
| sighsorry/STU_Ward | `STUWard` |
| sighsorry/PortalRules | `PortalRules` |
| sighsorry/CreatureManager | `CreatureManager` |
| sighsorry/DataForge | `DataForge` |
| sighsorry/Dive_In | `DiveIn` |
| sighsorry/InventorySlots | `InventorySlots` |
| sighsorry/SkadiNet | `SkadiNet` |
| sighsorry/Blasted_Swimming_Tarred_Bug_Fix | `BlastedSwimmingTarredBugFix` |
| turbero/PvPBiomeDominions | `PvP Biome Dominions` |
| turbero/DetailedLevels | `Detailed Levels` |
| WackyMole/WackyEpicMMOSystem | `EpicMMOSystem`, plus its `ItemManager` and `PieceManager` |
| WackyMole/WackyItemRequiresSkillLevel | `ItemRequiresSkillLevel` |
| team0/ValheimRAFT | `ValheimRAFT` |
| ValheimModding/Jotunn | mandatory-mod check, not a version line |

**Both sides, but not enforced.** These need the client to work fully and will not refuse a join
without it, so a client that skips them looks connected and behaves wrongly.

| Mod | Why the client needs it |
| --- | --- |
| RandyKnapp/EpicLoot | Drops are rolled where the player is, and `PlayerMustKnowRecipe` reads `Player.m_localPlayer`. The server pushes `loottables.json` to every client at join, so the tables are the server's, but the rolling and the UI are the client's |
| VentureValheim/World_Advancement_Progression | Server-side alone it only blocks the world's global key list. Private keys, every lock, and the skill floor are client features (upstream README, "Server-Side Only?") |
| ValheimModding/JsonDotNET, ValheimModding/YamlDotNet | Libraries the above load on whichever side they run |

**Server-only.** Installing these on a client changes nothing a player can see.

| Mod | Why |
| --- | --- |
| MaxPlayerCount (fork) | Every patched surface runs on the host; a client is told the capacity by the server. Already excluded from the client pack by an assertion in the builder |
| nwesterhausen/DiscordConnector | Reads server events and posts a webhook; there is no client half |
| Digitalroot/Max_Dungeon_Rooms | **Server-side only, decided 2026-09-16.** Room counts are applied when the server generates a dungeon, and the result is world data, so a client needs nothing. It leaves the client Pack with DiscordConnector (#70). The generation argument is sound but untested on a client, so #70 proves it by entering a large crypt with a client that does not have the mod |

**Client-only — all dropped, 2026-09-16.** The review cut this whole category. A mod the server
cannot enforce is a mod whose behaviour varies per player, which is the AdminQoL lesson: its
gameplay defaults disabled durability loss for a full evening and no server setting could reach
them.

| Mod | Decision |
| --- | --- |
| sighsorry/AdminQoL | **Dropped.** All 29 settings are client-decided: none is marked `[Synced with Server]` and it takes no part in the handshake (#70) |
| TOYNBEE/BoneMod | **Dropped.** Cosmetic bone scaling, client-side, pointless on the server, and unenforceable by the same argument (#70) |
| Lembitu.Harness | **Kept in the repository, never in the Pack.** It is our test harness for future acceptance work, inert without `-lembitu-harness`, and the builder asserts it is absent from a player's pack |

Dropping BoneMod needs one builder change, not just a pin removal: `scripts/build-client-pack.sh`
asserts that a required client-side package is present, and BoneMod is currently the only entry in
that list. The assertion exists to catch a pack that silently lost client content, so it should be
repointed rather than deleted — Jotunn is the candidate, because a client without it is refused at
the handshake outright. `test/client-pack.test.sh` covers that assertion and moves with it.

**The pack also ships server-only mods.** The v5 archive contains `DiscordConnector` and
`Max_Dungeon_Rooms`; both leave in v6. They are inert on a client but they inflate a 128 MB
download that players extract by hand. Trimming is #70's work, and the dungeon mod's removal
carries the one check worth doing: a client without it must still load a generated crypt correctly.

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

These write content into the world save, so they are installed before the launch world is created
and never removed during the run (ADR-0009): **Max Dungeon Rooms**, **ValheimRAFT**.

EpicLoot and World Advancement Progression are one-way for a different reason: removing them
destroys player gear or per-character progress rather than corrupting the world. World Advancement
Progression additionally clears the world's global keys on startup, so it belongs in the pack before
the launch world is created rather than after.

## Acceptance gate

No pin is cleared for the launch pack until, on the current public test game:

1. the whole pack boots clean on a dedicated server — chainloader completion, the native Steam
   listener, and no `MissingFieldException` or `MissingMethodException`,
2. one manual two-client session covers a boss kill, personal keys surviving reconnect, a ward, a
   portal and a raft.

That is the whole bar. Per-feature single-client scenario coverage was cancelled with the plugins it
was written for: nothing in the pack is ours, so proving each mod's own features is upstream's job
and ours only where the pack combines them.

Two questions belong to that boot rather than to argument:

- **YamlDotNet has no declared consumer** now that the EpicMMOSystem fork is gone. The log decides
  whether any mod loads it.
- **Two gates patch the same paths.** WackyItemRequiresSkillLevel refuses on character level, World
  Advancement Progression refuses on personal keys, and both hook equipping and crafting. One
  observed refusal from each is required.

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

### Config surfaces this pack uses

Read off the generated files in that boot, so the enforced overlays name real keys:

- **Personal keys** — `com.orianaventure.mod.WorldAdvancementProgression.cfg`, section `[Keys]`
  (`BlockAllGlobalKeys`, `UsePrivateKeys`), `[Locking]` (`LockEquipment`, `LockCrafting`, and the
  locks we leave off), `[Raids]` (`UsePrivateRaids`), `[Skills]` (`EnableSkillManager`, left off
  because character level owns progression here).
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
  `[4 - Multiplayer Difficulty]` holds vanilla's per-player scaling and is left untouched, so extra
  players help rather than inflating the boss in step with them. Tier scaling through the preset
  avoids committing a copy of `levels.yml`, which the overlay would have to replace wholesale and
  which grows fields with every release.

## Known interactions

Recorded so they are not rediscovered:

- **Retention is death-cause blind.** PvPBiomeDominions patches `Player.CreateTombStone`, which
  takes no killer, so a flagged player who drowns keeps their gear too. #8's premise — dying to a
  player costing less than dying to a troll — is only half achievable with this mod.
- **Character level lives in the character save.** EpicMMOSystem stores level and XP in
  `Player.m_knownTexts`, and World Advancement Progression stores personal keys in the character
  file. A client therefore owns its own progression. This is accepted, with no tamper resistance
  (ADR-0010).
- **Creature level authority.** Character level rewrites creature star levels, and EpicLoot's rarity
  rolls and CreatureManager's Karma both read them. Boss level from the biome preset sits on top of
  that same number.
- **Jotunn piece categories.** Custom pieces can appear in the build menu without a category on this
  game build. Affects ValheimRAFT.
- **EpicLoot declares an older Jotunn.** 0.14.5 declares 2.29.2 and runs against our 2.30.0 pin;
  DiscordConnector likewise declares an older BepInEx pack. Both are accepted skews, proven by the
  acceptance boot rather than by their manifests.

## Considered and cut

Kept out deliberately. Each line is a decision, not an oversight.

| Mod | Why not |
| --- | --- |
| sighsorry/BossRules | World Advancement Progression gates boss summons and guardian powers per key; its remaining refunds and stones did not justify the mod, its overlay and the altar-scan guard we had to write |
| MidnightMods/ProgressivePowers | Forsaken power mastery dropped; powers are vanilla, gated per character by personal keys (ADR-0004) |
| warpalicious/More_World_Locations_AIO | 185 locations at the cost of a world-permanent dependency and four open defect tickets; vanilla locations plus Max Dungeon Rooms carry the run |
| sighsorry/Fast_AssetBundle_Loader | Existed for MWL's 200+ bundles, and produced Linux `DriveInfo` failures and a shared-cache isolation deviation |
| sighsorry/CaptainValheim, sighsorry/SecondaryAttacks, sighsorry/AdditiveDamageModifier | Three combat layers landing on one damage number; removed rather than tuned |
| sighsorry/VeiledRecipes | Recipe discovery is already what EpicLoot's `PlayerMustKnowRecipe` gating reads |
| sighsorry/RepairRequiresMaterials | Friction without a rule behind it |
| sighsorry/Groundwork | Tool scaling not worth another mod on the placement path it already broke once |
| MidnightMods/ImpactfulSkills | Third power curve (ADR-0004) |
| sighsorry/Valheim_Enchantment_System | Second enchanting path on the same items (ADR-0004) |
| MidnightMods/ValheimArmory | New base weapons need community EpicLoot patches to be enchantable (ADR-0004) |
| MidnightMods/StarLevelSystem | Character level owns creature levels (ADR-0005) |
| Smoothbrain/Groups | Second membership authority (ADR-0008) |
| sighsorry/InventoryActions | Mutually exclusive with InventorySlots, and smaller |
| Nosferatu/SmoothServer | One pacing layer only; SkadiNet chosen |
| WackyMole/WackysDatabase | DataForge covers tuning |
| Tristan/Valheim_PvP_Tweaks | Overlaps PvPBiomeDominions; oldest pins on the list |
| sighsorry/ServerManager | Its Discord and logging role is DiscordConnector's |
| AWLGaming/DiscordBot_AWL, warpalicious/DiscordTools, RustyMods/DiscordBot | Need an external bot host or two-way chat; the relay is a webhook |
| warpalicious/Discord_Screenshots | Client-only, nothing depends on it |
| sighsorry/YouAreNotWorthy | Gates on world keys, which this server does not write |
| shudnal/ProtectiveWards | STU_Ward covers wards |
| Therzie/Warfare | Untouched since March 2025 |
| ZenDragon/ZenBossStone | Per-player boss trophies, but pulls a second mod library into the closure |
| Hex_Viking/HexResourceTracker, GChallenge/GCValheimStats, Tristan/Player_Activity, Eilif/EilifPaths | Client-only and unenforceable; EilifPaths also changes gameplay per player |
| KGvalheim/Marketplace_And_Server_NPCs_Revamped | Deprecated on Thunderstore and pre-1.0. Design reference for the deferred Trade Post only |

## Re-pinning

Pins are re-checked once, immediately before the launch world is created, and then frozen for the
run. Between now and then, a newer upstream version replaces a pin only if it passes the gate above
again — most of this catalogue was re-published within the last week, so a pin chosen today is hours
old, not months.
