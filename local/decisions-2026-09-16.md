# Settled configuration decisions — 2026-09-16 config review

Every value below was decided by the owner in the 2026-09-16 interview. These are the target values
for `config/enforced/`. "Pin" means the key must appear in the overlay even when the value equals
the mod's current default, because an upstream default is not a decision (`CONTEXT.md`, Enforced
config).

## com.orianaventure.mod.WorldAdvancementProgression.cfg

| Key | Value |
| --- | --- |
| `[Keys] BlockAllGlobalKeys` | `true` |
| `[Keys] UsePrivateKeys` | `true` |
| `[Locking] AdminBypass` | `false` |
| `[Locking] LockEquipment` | `true` |
| `[Locking] LockCrafting` | `true` |
| `[Locking] LockCooking` | `true` |
| `[Locking] LockEating` | `true` |
| `[Locking] LockEquipmentRepair` | `false` |
| `[Locking] LockBuilding` | `false` |
| `[Locking] LockBuildingRepair` | `false` |
| `[Locking] LockGuardianPower` | `true` |
| `[Locking] LockBossSummons` | `true` |
| `[Locking] LockTaming` | `false` |
| `[Locking] LockBoatsKey` | empty |
| `[Locking] LockPortalsKey` | empty |
| `[Locking] UnlockBossSummonsOverTime` | `false` |
| `[PortalUnlocking]` all nine keys | empty (vanilla hard hauling) |
| `[Raids] UsePrivateRaids` | `true` |
| `[Skills] EnableSkillManager` | `true` |
| `[Skills] AllowSkillDrain` | `true` |
| `[Skills] UseAbsoluteSkillDrain` | `false` |
| `[Skills] OverrideMinimumSkillLevel` | `false` |
| `[Skills] OverrideMaximumSkillLevel` | `true` |
| `[Skills] MaximumSkillLevel` | `100` |
| `[Skills] UseBossKeysForSkillLevel` | `true` |
| `[Skills] BossKeysSkillPerKey` | `10` |

Rationale for the skill block: `SkillsManager.UpdateCache` decides floor and ceiling
independently, so overriding the maximum at 100 keeps the ceiling vanilla while the floor follows
private boss keys at 10 per key. Cooking and eating being locked is an amendment to ADR-0005, which
currently says they stay open.

## sighsorry.CreatureManager.cfg

| Key | Value |
| --- | --- |
| `[1 - General] Lock Configuration` | `On` |
| `[2 - Levels] Biome Level Preset` | `Hard` |
| `[2 - Levels] Bosses Follow Biome Level Preset` | `On` |
| `[3 - Karma] Karma System Mode` | `KarmaLevelAndEnforcer` |
| `[3 - Karma] Maximum Enforcers Per Sector` | `1` |
| `[3 - Karma] Block Enforcer While Boss Is Active` | `On` |
| `[3 - Karma] Block Karma Gain While Boss Is Active` | `On` |
| `[3 - Karma] Block Karma Gain While Enforcer Is Active` | `On` |
| `[5 - Modifiers] Global Modifiers` | `On` |
| `[5 - Modifiers] Boss Modifiers` | `On` |
| `[5 - Modifiers] Enforcer Modifiers` | `On` |

## randyknapp.mods.epicloot.cfg

| Key | Value |
| --- | --- |
| `[2 - Balance] Item Drop Limits` | `PlayerMustKnowRecipe` |
| `[2 - Balance] Gated Freebuild Mode` | `PlayerMustKnowRecipe` |
| `[2 - Balance] Global Drop Rate Modifier` | `0.6` |
| `[2 - Balance] Shard Stone Drop Ratio` | `0.05` |
| `[2 - Balance] Item Drop Ratio` | `0.7` (pin, unchanged) |
| `[2 - Balance] Set Item Drop Chance` | `0.15` (pin, unchanged) |
| `[2 - Balance] Boss Trophy Drop Mode` | `OnePerPlayerNearBoss` |
| `[2 - Balance] Boss Trophy Drop Player Range` | `100` |
| `[2 - Balance] Wishbone Drop Mode` | `OnePerPlayerNearBoss` |
| `[2 - Balance] Wishbone Drop Player Range` | `100` |
| `[5 - Adventure] Adventure Mode Enabled` | `false` |

Effect thinning — Magic and Rare roll a single effect — lives in `loottables.json`'s
`MagicEffectsCount` and must be delivered as an EpicLoot patch file, not by forking the table. The
patch format is unverified; see the open question at the end.

Client-side only, therefore shipped as a config seed in the client Pack rather than enforced:
`Use Generated Magic Item Names = false`, and a muted palette replacing the default six-hue set —
Magic `#8a9ba8` (weathered iron), Rare `#b08d57` (bronze), Epic `#6b7f5e` (moss), Legendary
`#9c6b4f` (tanned leather), Mythic `#8c4a3c` (ember), Ancient `#5d4a5c` (bruised slate), and
`Set Item Color = #7d8a6f` instead of neon cyan.

## WackyMole.EpicMMOSystem.cfg — new overlay file

| Key | Value |
| --- | --- |
| `[0.General---------------] Force Server Config` | `true` |
| `[1.LevelSystem-----------] MaxLevel` | `100` (pin) |
| `LevelExperience` | `300` (pin) |
| `MultiplyNextLevelExperience` | `1.05` (pin) |
| `RateExp` | `1` (pin) |
| `FreePointForLevel` | `5` (pin) |
| `StartFreePoint` | `5` (pin) |
| `PriceResetPoints` | `3` (pin) |
| `BonusLevelPoints` | `5:5,10:5` (pin) |
| `LossExp` | `true` |
| `MinLossExp` | `0.05` |
| `MaxLossExp` | `0.15` |
| `GroupExp` | `0.7` (pin) |
| `Mentor` | `true` (pin) |
| `Group EXP Range` | `100` |
| `Player EXP Range` | `100` |
| `[2.Creature level control] Enabled_creature_level` | `false` |

The XP curve and attribute economy are pinned at their current values deliberately: the owner chose
to measure real levelling rates before tuning them. Creature levels belong to CreatureManager.

## Turbero.PvPBiomeDominions.cfg

Retention and looting rows stay exactly as pinned today. Change the position-sharing block: every
`[3 - Map Position]` biome rule becomes `HidePlayer`, and `Position Rule In Wards (override biome)`
stays `FollowBiomeRule`. Clan positions remain on in `sighsorry.Clan.cfg`.

## sighsorry.Clan.cfg

`Clan Friendly Fire = Off`, `Share Clan Positions = On`, `Lock Configuration = On`.

## WackyMole.ItemRequiresSkillLevel.yml

Keep the four armour tiers and their levels (20, 35, 50, 65). Set `BlockCraft: false` and keep
`BlockEquip: true` in every requirement: a player may craft ahead but not wear above their level.
World-progression gating on crafting still applies through WAP's `LockCrafting`.

## New overlay files, all values pinned as they run today

- `sighsorry.DiveIn.cfg`: the full swimming block — `Darkness Factor 0.5`, `Murkiness Factor 0.25`,
  `Surface Stamina Regen Rate 0.5`, `Midwater Stamina Regen Rate 0`, `Surface Eitr Regen Rate 0.7`,
  `Midwater Eitr Regen Rate 0.3`, `Midwater Idle Stamina Drain Per Depth 0.02`,
  `Swim Stamina Drain Multiplier Per Depth 2.5`, `Lock Configuration On`.
- `sighsorry.SkadiNet.cfg`: `Enabled true`, `SchedulerThroughput 35`, `PayloadReducerStrength 30`,
  `CompressionAggression 50`, `OwnershipIntensity 45`, `ClientStutterGuardStrength 50`,
  `DungeonLayerFiltering false`. This is the profile that survived a full night with several players.
- `digitalroot.mods.maxdungeonrooms.cfg`: `Min Rooms 20`, `Max Rooms 40`, all three per-dungeon
  overrides disabled. World-permanent under ADR-0009.
- `Azumatt.MaxPlayerCount.cfg`: `MaxPlayerCount 20`.
- `zolantris.ValheimRAFT.cfg`: add `AllowFlight = false`,
  `AllowDebugCommandsForNonAdmins = false`, `AllowExperimentalPrefabs = false`, and keep
  `CannonPrefabs_Enabled = false`. Ram values unchanged.
- `zolantris.DynamicLocations.cfg`: `enableDynamicSpawnPoints true`, `enableDynamicLogoutPoints true`.
- `BepInEx.cfg`: `[Logging.Disk] AppendLog = true` so a restart stops destroying the evidence.
- DiscordConnector (`games.nwest.valheim.discordconnector/discordconnector.cfg`):
  `Send Positions with Messages = false`; lifecycle, join, leave, death and shout notifications on;
  `Allow @here and @everyone mentions = false`. The webhook URL itself is a secret and belongs in
  `config/launch/launch.secret.env`, never in the overlay. Ticket #17 owns the relay.

## EpicLoot magic effects — an across-the-spectrum reduction

Every rarity loses one effect, and the extra-effect tail is thinned from `80/18/2` to `92/7/1`, so
most items show exactly their tier's base count. This is not a bottom-tier tweak: the whole ladder
moves down.

| Rarity | Now | Target |
| --- | --- | --- |
| Magic | `[[1,80],[2,18],[3,2]]` | `[[1,100]]` |
| Rare | `[[2,80],[3,18],[4,2]]` | `[[1,92],[2,7],[3,1]]` |
| Epic | `[[3,80],[4,18],[5,2]]` | `[[2,92],[3,7],[4,1]]` |
| Legendary | `[[4,80],[5,18],[6,2]]` | `[[3,92],[4,7],[5,1]]` |
| Mythic | `[[5,80],[6,18],[7,2]]` | `[[4,92],[5,7],[6,1]]` |
| Ancient | `[[6,80],[7,18],[8,2]]` | `[[5,92],[6,7],[7,1]]` |

Delivery is an EpicLoot patch file at `config/enforced/EpicLoot/patches/loottables.json`, which the
overlay applier copies wholesale to `BepInEx/config/EpicLoot/patches/loottables.json` — the exact
directory `FilePatching.GetPatchesDirectoryPath` computes. Server-side, not a client seed:
`loottables.json` is pushed to every client at join through Jotunn's initial synchronisation, so a
client-local copy is overwritten. Patching also bypasses `configstate.json` entirely, so neither a
mod update nor a declined hash can invalidate it. Use `"Action": "Overwrite"` on each
`$.MagicEffectsCount.<Rarity>` leaf with `"RequireAll": true`, so a renamed key fails loudly
instead of silently rolling stock. Full provenance in `docs/research.md`; ticket #73.

CreatureManager's 32 creature modifiers are a different surface with the same name, and the review
left them at stock: all three master switches On, every modifier at a 5% chance, up to four visible
per creature. Revisit only if creatures, rather than items, look noisy in play.

## Launch configuration — unchanged, confirmed

`Combat hard`, `DeathPenalty default`, `Resources default`, `Raids default`, `Portals hard`,
`SERVER_PUBLIC=true`, `CROSSPLAY=false`, `MaxPlayerCount 20`.

## Pack change

Drop `AdminQoL` from the adopted pin table. It is client-decided, not server-synced, so its
gameplay defaults — no durability loss, no equip delay, no roof requirement — cannot be enforced
from the server. Vanilla shelter requirements return. Rebuild as `2026-09-16-v6` and reissue.

## Open question for implementation

The EpicLoot patch file format is unverified. `EpicLoot.dll` exposes `ApplyPatch` and watches a
`patches/` directory, and `configstate.json` tracks per-file source hashes. Establish the schema
from the assembly before writing the `MagicEffectsCount` patch; do not fork `loottables.json`.

## Mods dropped, and which side each runs on

Client-only mods are cut as a category: AdminQoL and BoneMod. A mod the server cannot enforce
behaves differently for every player, which is the AdminQoL lesson. `Lembitu.Harness` stays in the
repository for future acceptance work and never ships in the Pack.

Server-only mods stay installed on the server and leave the client Pack: DiscordConnector and
Max_Dungeon_Rooms. The dungeon mod remains pinned and deployed because ADR-0009 makes it
world-permanent; removing it from the Pack needs one check first — a client without it entering a
crypt generated by a server that has it.

Dropping BoneMod requires repointing the builder's `REQUIRED` presence assertion, which BoneMod
currently satisfies alone. Jotunn is the candidate: a client without Jotunn is refused at the
handshake, so its absence is a hard failure rather than a missing feature.

The authoritative classification lives in `docs/modstack.md` under "Where each mod runs", derived
from the server's own version announcements at join rather than from package descriptions.

## Inventory: AzuExtendedPlayerInventory is the slot mod (#74)

The previous slot mod is replaced by `Azumatt/AzuExtendedPlayerInventory` 2.4.14, which
declares only the pack's own BepInEx loader pin. Target configuration:

| Setting | Value | Why |
| --- | --- | --- |
| Extra inventory rows | `0` | Carrying capacity stays vanilla plus whatever Haldor sells, which the mod adds independently. With no rows there is nothing to gate, which is why AzuEPI having no progression system costs nothing |
| Quick slots | `3` | Matches the three-wide quick row players already have; a small, readable gain over vanilla |
| Equipment slots | on | The reason for the mod: armour out of the backpack |
| Wishbone and Demister special slots | on | Both stop eating inventory space |
| Loadout button, player stats panel | on | Kept deliberately |
| Vanity surface | off | Unwanted. Whether the system itself can be disabled, or only its button, is unresolved and must be established from the generated config or the assembly |

The `Minimal` preset must not be used: it disables loadouts and stats along with vanity.

Accepted losses, with no AzuEPI counterpart: multicraft, favourites, the crafting grid with search
and sort, and scrollable tooltips. The progression-gated rows and slots of the previous mod go
too; they were never an enforced decision and unlocked on item discovery, not on boss keys.

The slot mod is one of the fifteen mods the server version-checks at join, so replacing it changes
the announced set and a client on the old Pack is refused rather than silently mismatched.

## EpicMMO HUD: XP bar yes, vanilla health and stamina

`WackyMole.EpicMMOSystemUI.cfg` replaces the HUD with a grouped XP/HP/stamina/eitr bar. Keep the XP
bar; return the rest to vanilla by setting `HP color`, `Stamina color` and `Eitr color` to `none`,
which the keys' own descriptions define as "make vanilla". Leave the exp fill colour set, since
`none` there removes the XP bar.

Every key in that file is `[Not Synced with Server]`, so it ships as a client Pack seed (#70), not
as enforced config. Unverified: whether `none` restores the vanilla bars or merely draws the mod's
bars transparently over a hidden vanilla HUD. One client launch settles it.

## Amendment, decided while #68 was being applied: difficulty is fixed, not scaled by headcount

Vanilla scales every creature by the number of players standing nearby — 30% effective health and
4% damage each, capped at five — so the same boss was a different fight depending on who logged
in, and a sixth player made it easier. The owner's decision removes headcount from the question
entirely and sets the difficulty outright.

| Key | Value |
| --- | --- |
| `sighsorry.CreatureManager.cfg` `[4 - Multiplayer Difficulty] HP Increase Per Player In Multiplayer (%)` | `0` |
| `sighsorry.CreatureManager.cfg` `[4 - Multiplayer Difficulty] DMG Increase Per Player In Multiplayer (%)` | `0` |
| `sighsorry.CreatureManager.cfg` `[4 - Multiplayer Difficulty] Maximum Player Count For Multiplayer Scaling` | `1` |
| `CreatureManager/levels.yml` `Global.health` | `4` |
| `CreatureManager/levels.yml` `Boss.health` | `8` |

Ordinary creatures and Enforcers carry four times vanilla health, regular bosses eight. Damage is
untouched at 1, because health lengthens a fight while damage only moves deaths earlier. Per-level
growth compounds on top of both, so these are floors: a level-3 Ashlands creature is 12× and a
level-2 boss 12×, and `Biome Level Preset = Hard` decides how often a high level is rolled.

There is only one cap key and it governs bosses and ordinary creatures alike, so "bosses at eight
players, monsters at four" was not expressible; fixing both outright is what the owner chose
instead. Pinning `levels.yml` wholesale also freezes its modifier tables at package values — 5%
per `Global` modifier, 10% per `Boss` one — which the review had left at stock. They stay stock;
they are now a committed number, so a package retune becomes a review.

## Correction to this file: CreatureManager's modifier switches

The CreatureManager table above places `Global Modifiers`, `Boss Modifiers` and
`Enforcer Modifiers` in `[5 - Modifiers]`. The mod generates them in `[2 - Levels]`, which
`local/live-config-sections.txt` records at lines 66, 72 and 78. The overlay pins the section the
mod writes. The wrong section is not a visible error: the applier appends the key under a
re-declared section, the mod keeps reading its own copy, and the drift check passes forever.
