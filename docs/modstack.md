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

**This table is the decision, not yet the repository state.** The pins, lock entries, enforced
config files and the deletion of the retired fork and plugins are one implementation task, tracked
separately. Until it lands, `modstack.lock.json` still carries the old thirty-package set, the
retired sources are still under `src/`, and `config/enforced/` still holds the BossRules overlay.
Everything below describes what the pack becomes, and the measured evidence for it is dated.

## Adopted upstream

Every mod here is intended for the server *and* client pack at exactly this version (BoneMod is
client-side). Candidate staging is not deployment or verification. "Enforced config" is a deliberate
deviation from the defaults and belongs in server-locked config rather than a player's file.

| Mod | Pin | Role | Enforced config |
| --- | --- | --- | --- |
| sighsorry/Clan | 1.0.10 | Clans, roles, clan chat, guest clans, clan pings | Friendly fire off; config locked |
| sighsorry/STU_Ward | 1.3.15 | Wards resolved against clan membership | — |
| sighsorry/PortalRules | 1.0.7 | Portal access control | Access modes only: no fares, no map picker, no admin portals, GlobalKey gates unset |
| VentureValheim/World_Advancement_Progression | 1.0.0 | Personal keys: private per-character progression, per-player raids, key-gated equipment and crafting | Private keys on, all global keys blocked, gear and crafting locked, nothing else locked |
| RandyKnapp/EpicLoot | 0.14.5 | Gear tiers: magic drops, enchanting, bounties | Gated Drop Mode `PlayerMustKnowRecipe`, so gating reads the player, not world keys |
| WackyMole/WackyEpicMMOSystem | 1.9.67 | Character level: XP, attributes, level band, XP meads | Upstream XP tables untouched |
| WackyMole/WackyItemRequiresSkillLevel | 1.4.7 | Character-level gates on crafting, equipping and consuming | Curated rules in `WackyMole.ItemRequiresSkillLevel.yml` |
| sighsorry/CreatureManager | 1.1.14 | Karma and Enforcer encounters; boss level and health scaling | Creature cloning and customisation off; boss health rises by biome tier through `Biome Level Preset` |
| Digitalroot/Max_Dungeon_Rooms | 2.0.39 | Larger dungeons | — |
| team0/ValheimRAFT | 4.3.2 | Custom ships, anchoring and vehicle building | Server-synced `CannonPrefabs_Enabled = false` |
| turbero/PvPBiomeDominions | 1.7.8 | PvP death and retention rules | Biome-forced PvP off everywhere |
| sighsorry/Dive_In | 1.2.3 | Diving, water combat, underwater creature pursuit | — |
| sighsorry/InventorySlots | 1.4.17 | Equipment and quick slots, comparison, multicraft | Keep-on-death off |
| turbero/DetailedLevels | 2.1.3 | Skill progress readout | — |
| sighsorry/AdminQoL | 1.1.3 | Admin console GUI and item sets | — |
| sighsorry/DataForge | 1.3.4 | Item, recipe and effect tuning | Tuning only: no cloned or custom items |
| sighsorry/SkadiNet | 1.1.5 | Peer-aware network pacing, dungeon-layer filtering | — |
| sighsorry/Blasted_Swimming_Tarred_Bug_Fix | 1.2.6 | Vanilla state and teardown bug fixes | — |
| nwesterhausen/DiscordConnector | 3.1.3 | Server-side Discord webhook relay: joins, deaths, events | Webhook URL is a secret, set per deployment |
| TOYNBEE/BoneMod | 1.0.2 | Cosmetic bone scaling (client-side) | — |
| ValheimModding/Jotunn | 2.30.0 | Library | Overrides the 2.29.2 pin declared by EpicLoot |
| ValheimModding/JsonDotNET | 13.0.4 | Library | — |
| ValheimModding/YamlDotNet | 16.3.1 | Library | Nothing declares it since the EpicMMOSystem fork was retired; the acceptance boot decides whether it stays |

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
acceptance run: no client joined, and the repository still carries the old pins.

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
  BepInEx 5.4.2333, WackyEpicMMOSystem names 5.4.2202 — so `scripts/stage-stack.sh` needs those
  recorded as deliberate overrides before it will stage the pack.

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
- **Boss scaling** — `sighsorry.CreatureManager.cfg`, section `[2 - Levels]`
  (`Biome Level Preset`, `Bosses Follow Biome Level Preset`), which raises boss level by biome tier
  and therefore boss health through the `Boss` `healthPerLevel` default. Section
  `[4 - Multiplayer Difficulty]` holds vanilla's per-player scaling. Tier scaling through the preset
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
