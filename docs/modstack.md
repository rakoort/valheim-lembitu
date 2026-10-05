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

**This table is the repository state.** It carries seventy pins: the sixty-three of the
2026-10-04 review, plus the 2026-10-05 additions (#87) — six Azumatt mods re-pinned from Hexium,
Guilds to 1.2.3, and five Shakedown mods with their CrewStats companion and ConditionalConfigSync.
On the review day the owner added thirty-five packages and removed Clan, settled the server concept
(ADR-0019), and then judged every mod against it; Oathbound replaced the level and magic mods
(ADR-0020). Each removal is a row in [Considered and cut](#considered-and-cut). The lock records
the exact package bytes.
The retired fork and plugins are deleted from `src/`, and `src/forks/` contains only
MaxPlayerCount. The dated measurements below established earlier packs, not this candidate.

## Adopted upstream

Every mod here is pinned at exactly this version; the side it runs on is in
[Where each mod runs](#where-each-mod-runs). Most are installed on the server *and* the client
pack, DiscordConnector is withheld from the Pack as server-only,
and five ride in the Pack alone: AzuHoverStats, AzuClock, MouseTweaks, CraftingSearch and
CompactStatusEffects. Candidate staging is
not deployment or verification. "Enforced config" is a deliberate deviation from the defaults and
belongs in server-locked config rather than a player's file.

| Mod | Pin | Role | Enforced config |
| --- | --- | --- | --- |
| VentureValheim/World_Advancement_Progression | 1.0.0 | Personal keys: private per-character progression, per-player raids, key-gated actions, vanilla skill caps | Private keys on, all global keys blocked; equipment, crafting, cooking, eating, guardian powers and boss summons locked; repairs, building, taming, boats and portals open; skill floor from boss keys with the ceiling at 100 |
| RandyKnapp/EpicLoot | 0.14.13 | Gear tiers: magic drops, rarities, enchanting, shardstones and Haldor's adventure trade | Rebuilt from package defaults 2026-10-04: `Item Drop Limits = PlayerMustKnowRecipe`, because the boss-kill mode reads world keys this server blocks; `Gated Freebuild Mode = BossKillUnlocksCurrentBiomePieces`, which in practice lets FreeBuild skip only the workbench; drop rate 0.6, which puts a creature drop's magic odds at 0.36 times the package's; shardstones 0.1; failed tempering can destroy the item; Adventure Mode on with at most five bounties per player; one boss trophy, Wishbone and swamp key per kill rather than per player present, so re-killing a boss pays (2026-10-04). `EpicLoot/patches/lembitu-seaanimals.json` (2026-10-05) gives the hostile SeaAnimals creatures the biome tier's loot table through EpicLoot's own patch system — BlueShark Tier0, Crocodile Tier3, HammerHeadShark, TigerShark, HumboldtSquid and WhiteShark at their biomes' tiers — server-synced to every client at join; hostility read from the mod's prefabs, and the peaceful turtles, RightWhale and WhaleShark get none |
| LionAndOtter/Oathbound | 0.21.14 | Class level and talents: thirteen classes with 79-node trees, active abilities, companions, elemental and blood magic, and sieges | Adopted 2026-10-04 in place of EpicMMO and MagicPlugin (ADR-0020). Defaults pinned because the design rests on them: `SharedExperience` off, `ExperienceMultiplier` 1 with no talent-point cap, class access at the Oathstone, class equipment rules on, sieges on (they replace vanilla random raids). Blood moons off: their siege tier reads blocked world keys and their sense and star settings are local to each player. Respec and class switching reset to level 1, kill XP is split within the killer's party, and the gathering tools are open to every class through our `Lembitu.Oathbound`, because the mod has no settings for them (ADR-0022) |
| sighsorry/CreatureManager | 1.2.5 | Fixed creature and boss multipliers, monster modifiers, Karma and Enforcers, and holding vanilla's headcount scaling at zero | Every value fixed, never scaled by players present (ADR-0019): ordinary creatures 2x health and vanilla damage (damage growth trimmed back to 1.0 on 2026-10-05 after the 2026-10-04 raise; bosses keep 1.5x damage with slower growth), `Biome Level Preset = Hard`; Karma at `KarmaLevelAndEnforcer` with the cap and four blocking switches pinned, its levels capped at +2 (2026-10-05); modifiers on at about 10 in 100 ordinary creatures, about one per boss and two per Enforcer, without deathward, regenerating, omen or blamer — and bosses and Enforcers no longer roll the three counters that punish ranged and caster classes (`levels.yml`, `karma.yml`, 2026-10-05); headcount scaling pinned at 0 / 0 / 1; cloning and customisation off |
| sighsorry/Dive_In | 1.2.3 | Diving, water combat, underwater creature pursuit | — |
| Azumatt/AzuExtendedPlayerInventory | 2.6.1 | Equipment slots, quick slots, Wishbone and Demister slots | Extra rows 0, three quick slots, equipment and special slots on; the vanity button off, which keeps the whole vanity surface unreachable — 2.6.1's new `Weapon Vanity` key only lists weapons inside that panel (re-checked 2026-10-05). Adopted from Hexium (ADR-0026) with the layout keys re-checked: every pinned key kept its name and section, and the 2.6.x layout keys are unsynced client preferences |
| Azumatt/AzuCraftyBoxes | 1.8.27 | Crafting and building pull materials from containers near the station | `Container Range` 20 m; `Leave One Item` off; `Mod Enabled` on; config locked; `Azumatt.AzuCraftyBoxes.yml` committed empty, so everything in range is pullable. 1.8.27 from Hexium (2026-10-05, ADR-0026): upstream fixes for craft item loss, double-taken partial stacks and chests others have open |
| Azumatt/AzuHoverStats | 1.1.11 | Hover readouts for creatures, pieces, items, chests and crafting timers | — Nothing in it is server-synced, so the server can pin nothing; client-only |
| Azumatt/AzuClock | 1.1.1 | On-screen clock and weather forecast | — Client-only |
| Azumatt/MouseTweaks | 1.0.5 | Inventory moving, stack splitting and quick-dropping with mouse and modifier | — Client-only |
| Azumatt/ProximityVoiceChat | 1.0.4 | Positional voice chat, quieter with distance, no external program | Voice ranges and the Opus codec pinned; the 1.0.3 `Allow Global Voice` sync pinned off, so voice stays positional (2026-10-05); microphone, playback, indicators and keybinds stay the player's |
| turbero/DetailedLevels | 2.1.3 | Skill progress readout | — Client preference; the Pack seeds its readout key to F8 |
| Ab5oluteZer0/CraftingSearch | 1.0.2 | Search box and sort button in the crafting window | — Client-side UI with no settings at all; added for the Shakedown (2026-10-05) |
| Marins/CompactStatusEffects | 1.1.2 | Compact vertical status-effect HUD under the minimap | — Client-side HUD: position and scale are each player's; the Pack seeds its settings key to Quote (2026-10-05) |
| Bagr/DamageMeter | 3.7.0 | Boss-fight damage meter: a live panel, a table after each kill and party expeditions | Server behaviour pinned: death recaps on in the boss summary, joke awards off, expeditions started by admins only (2026-10-05). Pack key seed: menu F6, panel End, mode Backslash, expedition Pause |
| Bagr/CrewStats | 1.4.1 | Server-gathered statistics — kills, gathered resources, awards, death log — read in a client window | — Added for the Shakedown; the Pack seeds its statistics window key to Semicolon (2026-10-05) |
| Crystal/BetterChat | 1.6.4 | Chat window that appears on new messages; talk, whisper and shout handling | Talk and whisper distances pinned at the vanilla 15 m and 4 m through the mod's server-enforced sync policy, so it adds convenience without changing who hears what (2026-10-05) |
| shudnal/ConditionalConfigSync | 1.0.6 | Library | Declared by BetterChat |
| Goldenrevolver/Quick_Stack_Store_Sort_Trash_Restock | 1.4.15 | Quick stack, restock, sort, trash and favourite buttons for containers | Area quick stack and restock server-locked: the host's settings apply to everyone (`ToggleAreaStackRestockConfigServerSync` true), area stacking without MultiUserChest stays false, and both nearby ranges are 0, so stacking and restocking reach only the open container. Pack seed: Ctrl+U quick stack, Shift+U restock, LeftAlt+U sort, RightAlt+U trash (2026-10-05) |
| sighsorry/DataForge | 1.3.5 | Item, recipe and effect tuning | Tuning only: no cloned or custom items |
| sighsorry/SkadiNet | 1.1.6 | Peer-aware network pacing, dungeon-layer filtering | — |
| sighsorry/Blasted_Swimming_Tarred_Bug_Fix | 1.2.6 | Vanilla state and teardown bug fixes | — |
| nwesterhausen/DiscordConnector | 3.1.3 | Server-side Discord webhook relay: joins, deaths, events | Webhook URL is a secret, set per deployment |
| JereKuusela/Expand_World_Size | 1.43.0 | World radius, edge and stretch. World-permanent in the strongest sense: the values are baked into terrain at generation | `World radius` 13250, `Stretch world` 1.325, `Stretch biomes` 1.25, `Locations` 1.75: about 1.76x vanilla area with points of interest at vanilla density, chosen 2026-10-04 for rival-but-cooperating guilds (ADR-0019); before that 12500/1.25/1.25, and ADR-0018's 15000/1.5/1.25 |
| Mushroom_Vikings/SeparateSpawns | 0.1.1 | One scored start region per guild | `InnerRadius` 1200 and `MinStonesDistance` 500, so starts lie 0.5-1.2 km from the sacrificial stones, at least 1 km apart (halved on 2026-10-04 at the owner's request, from 2400 and 1000). From 2026-10-04 one group per guild, rostered by Steam ID before launch (ADR-0019); the committed roster still holds the three empty, randomly filled groups of the collaborative 2026-10-03 setup until the guilds are known. Its config lives in the game tree rather than BepInEx's, so `config/dedicated/` and `scripts/apply-dedicated-config.sh` own it, not the enforced overlay |
| MidnightMods/ProgressivePowers | 0.3.4 | Forsaken power mastery: powers grow with use | The boss-power pillar (ADR-0019): mastery credit within 100 m of the dead boss (package 200 m), the same radius as boss keys and party XP; one attuned power; active use blocked, so powers are passive bonuses over seven mastery levels (2026-10-04) |
| Vapok/AdventureBackpacks | 2.2.5 | Backpacks with their own storage | All six tiers server-pinned: contents at 85% weight; integer carry bonus per quality halved and rounded down to 2/5/7/10/12/15, Meadows through Mistlands (owner, 2026-10-05). One-way: removing the mod deletes its packs and contents. Craft-from-backpack and auto-store remain each player's preferences (ADR-0019) |
| OdinPlus/OdinArchitect | 1.7.9 | Larger and new building pieces | — Added 2026-10-03 (owner's instruction). One-way: its pieces live in the world save |
| MathiasDecrock/PlanBuild | 0.20.0 | Plan, copy and share builds | Direct build and terrain tools off for players, so a plan is finished with real materials at the right station; admins keep both (2026-10-04, ADR-0019) |
| OdinPlus/OdinsKingdom | 1.6.2 | Castle building pieces with their own build tool | — Added 2026-10-03 (owner's instruction). One-way: its pieces live in the world save |
| ComfyMods/SearsCatalog | 1.9.0 | Resizable, movable build panel | — Added 2026-10-03 (owner's instruction). Declares BepInEx 5.4.2202, a documented override |
| SpikeHimself/XPortal | 1.2.25 | Pick a portal destination from a list | — Added 2026-10-03 (owner's instruction). The only portal mod since PortalRules left the same day |
| Marlthon/OdinShip | 0.8.7 | Seven cargo and war ships | — Added 2026-10-03 (owner's instruction). One-way: its ships live in the world save |
| blacks7ar/GlassPieces | 1.2.8 | Glass, iron and copper building pieces and a minable resource | `Use Smelter = Off` server-pinned: glass uses the mod's furnace rather than vanilla smelters (2026-10-05). Added 2026-10-03. One-way: its pieces live in the world save |
| Marlthon/TheFisher | 0.3.9 | New fish, aquatic creatures and aquariums | — Added 2026-10-03 (owner's instruction) |
| Advize/PlantEverything | 1.21.3 | Cultivator plants berry bushes, flowers, mushrooms, extra trees and more | Biome rules enforced for its own plantables and vanilla crops, so planting anywhere stays ImpactfulSkills' high-level Farming reward (2026-10-04, ADR-0021) |
| OdinPlus/OdinsFoodBarrels | 1.3.9 | Buildable storage barrels for seeds, fruit and vegetables | — Added 2026-10-04 (owner's instruction). One-way: its pieces live in the world save |
| OdinPlus/OdinCampsite | 1.6.5 | Camping-style building pieces | — Added 2026-10-04 (owner's instruction). One-way: its pieces live in the world save |
| blacks7ar/SeedBed | 1.2.9 | Plant seeds in a bed instead of cultivated ground | — Added 2026-10-04 (owner's instruction). One-way: its pieces live in the world save |
| Marlthon/SeaAnimals | 0.3.9 | Dangerous and rideable ocean creatures | — Added 2026-10-04 (owner's instruction) |
| blacks7ar/Herbalist | 1.5.0 | Herbalism skill, a crafting station, tonics and recovery items | Its own tonic tiers set to 1 so Item_Requirement's biome ladder is the one gate; all eight elixirs kept and retuned to boss-fight strength (Berserker ×1.25, Swift ×1.2, Jump ×1.5, Fast Learner ×1.5, Invisibility and Heavy Lifter 60 s); config locked (2026-10-04, ADR-0024). Its bundled skill manager's own death handling never counts: `Lembitu.Callings` puts the skill back and drains it by World Advancement Progression's floor (ADR-0022). One-way: its station lives in the world save |
| MSchmoecker/DynamicStoragePiles | 0.8.1 | Stack and pile containers that show their fill level | — Added 2026-10-04 (owner's instruction). One-way: its pieces live in the world save |
| Searica/DodgeShortcut | 1.4.0 | A single dodge key | — Added 2026-10-04 (owner's instruction) |
| OdinPlus/BlacksmithingExpanded | 1.2.4 | Blacksmithing skill that improves crafting, smelting and kiln output | The smithing profession; ImpactfulSkills' Forging and Crafting are off so the two never stack. Gear bonuses follow the smith's level only: +1% damage, +0.5 armour and +1 block per 10 levels, no per-upgrade extra, no elemental rider (2026-10-04, ADR-0024). Its own 5% death loss cannot be pinned, because it lives under a section named after an unresolved localization key (`[skill_1208107160]`); `Lembitu.Callings` puts the skill back after it and drains a non-focus Blacksmithing once, by World Advancement Progression's floor (ADR-0022). Its main settings carry no lock entry of their own; `Lembitu.Callings` locks the sync at startup (#89, 2026-10-05) |
| xtavim/BetterMap | 1.1.0 | Boats, carts and resources on the map; automatic pins for what a player walks past | Creature radar and trader reveal off, automatic pins within 15 m only, exploration radius at the vanilla 100 m, config locked (2026-10-04, ADR-0019: readouts but no radar) |
| MilkMediaProductions/ExpertExplorer | 1.7.0 | Exploration skill that grows as points of interest are found | On-foot reveal radius 250 m at skill 100, from BetterMap's 100 m (2026-10-04, ADR-0024). It overwrites ImpactfulSkills' larger reveal while sailing, an open interaction |
| Northarun/Guilds | 1.2.3 | Guilds: ranks, guild chat, shared vault, guild-bound wards, a banner territory, guild levels, upgrades and achievements | Five members at most and the Members upgrade neutralised; founding a guild is free (`CreateCost` 0, package 1,000 coins, 2026-10-05); no waiting period after leaving or a kick (`RejoinCooldownHours` 0, package 12 h, 2026-10-05); guild levels grow 1.15× per level and coin donations buy guild XP at 10 coins per point, so trade feeds the guild (2026-10-05); boss keys never shared with absent members; Comfort upgrade at guild level 12 and 20, monster ward at level 10 (2026-10-04, ADR-0019). The membership and ward authority since Clan left; 1.2.3 restores banner territory lost after reconnect or restart |
| Northarun/Marketplace | 1.4.0 | Server-wide marketplace and order board: coin sales, buy orders, bounties, a bank | The one remote trade system; a 5% fee on every payout keeps coins scarce (2026-10-04, ADR-0019) |
| M2Valheim/SocialSystem | 1.0.4 | Invite-only parties of up to eight across guilds, party positions on the map, friends and party chat | Defaults pinned: parties of eight at most, positions shared within the party. Party kill-XP sharing is `Lembitu.Oathbound`'s, which reads party membership from SocialSystem's server-side party service rather than the party ID clients publish (2026-10-04, ADR-0020, ADR-0022) |
| MidnightMods/ImpactfulSkills | 0.21.0 | Land and Road professions and Cooking: yield, area work, growth timers, taming, sailing and hauling perks | Forging and Crafting off, `ScaleCraftedEquipmentQuality` included (BlacksmithingExpanded owns smithing); every Combat and Body perk off, the weapon equip-speed factor included; Knowledge Sharing off (ADR-0021). Switch-on perks on rungs 40-70, outliers brought to the middle: chop and dig ×1.5, wood and ore ×1.67, taming, slaughter and honey ×2.5, carry +100 (2026-10-04, ADR-0024). Sailing perks as shipped; they own ship speed since Njord left |
| Radamanto/Item_Requirement | 1.1.3 | The profession ladder: crafting gated by earned profession level, modded skills included | Adopted 2026-10-04 (ADR-0021). It blocks the craft itself, not just the button, and reads raw skill level. What each profession makes climbs ten levels per biome, Blacksmithing's weapons and armour included, crafting blocked and use never blocked (ADR-0023). `config/enforced/ItemRequirement/radamanto.ItemRequirement.professions.yml` holds 367 rules (Blacksmithing 254, Cooking 59, Herbalist 35, Fishing 8, Hauling 5, Animal Handling 4, Farming 1, Sailing 1), regenerated 2026-10-05 from the original native 1.0.16 ObjectDB dump: three named item floors added by generator policy, all other rules unchanged. The prior 364-rule file loaded in full on the 2026-10-04 test boot. Its `main.yml` is committed as `[]`, because the package writes example equip gates when no rule file exists. Upgrades share an item's rule, so a rule takes the highest rung across qualities |
| sighsorry/AdditiveDamageModifier | 1.2.4 | Resistances and weaknesses stack additively | Players always take at least 25% of each floored damage type (package: 10%), so stacked resistances never reach immunity; config locked (2026-10-04) |
| VentureValheim/Venture_Multiplayer_Tweaks | 1.0.0 | Server tweaks: PvP, map positions, trader pins, death behaviour | PvP held off for everyone; public map positions off (guild and party positions come from Guilds and SocialSystem); trader map pins off, temple pin on; vanilla respawn and skill loss on death (2026-10-04, ADR-0019) |
| VentureValheim/Venture_Logout_Tweaks | 1.0.0 | Restores status effects such as Rested from the last logout | — Added 2026-10-04 (owner's instruction) |
| ZenDragon/ZenRaids | 1.2.3 | Lit fires keep spawns out of a base; raid trigger control | Vanilla raid odds with no per-player bonus (2026-10-04, ADR-0019). It still decides when a raid would roll, but every raid is now an Oathbound siege, so its biome list no longer matters; frequency is lowered by the launch modifier `Raids less`. Base safety is earned later through the Guilds monster ward at guild level 10 |
| ZenDragon/Zen_ModLib | 1.14.20 | Library | Declared by ZenRaids |
| Searica/Extra_Snap_Points_Made_Easy | 2.1.0 | Extra snap points on vanilla pieces | — Added 2026-10-04 (owner's instruction). Its settings are plain local config despite their "synced" labels, so snapping is each player's preference; accepted under the Pack rule (ADR-0019) |
| JereKuusela/Server_devcommands | 1.115.0 | Server side of the admin tools: remote devcommands and permissions for admins | Server-only, withheld from the Pack. Admins install Infinity Hammer, its addon and World Edit Commands on their own clients; none of them is in the player stack (2026-10-04) |
| Nekitker/SaunaMod | 2.1.0 | Buildable, upgradable sauna: steam heal, buffs and up to +2 comfort | `[Mead] DurationMultiplier = 1` server-pinned in `nekitker.saunamod.cfg`: resistance meads keep vanilla duration (2026-10-05). Its comfort still stacks with the Guilds Comfort upgrade; both kept, the guild one priced late |
| ValMedia/OdinOnDemand | 1.3.0 | Cinema screens and music players | — Added 2026-10-04 (owner's instruction), kept after review. Every client fetches streams itself; only the Windows video player is bundled, so Mac and Linux players may get no video |
| ValMedia/OOD_LIB | 1.2.0 | Library | Declared by OdinOnDemand |
| SeasonedProfessionals/OdinEye | 1.2.37 | Server data over a REST API and WebSocket, for future tooling | Bound to loopback, never a published port: the API has no authentication and can push in-game messages (2026-10-04). Server-only, withheld from the Pack |
| MSchmoecker/WhichModAddedThis | 0.1.2 | Mod name in item tooltips and the build HUD | — Added 2026-10-04 (owner's instruction) |
| VentureValheim/Deluxe_Particles | 1.0.0 | Larger particle effect on dropped items | — Added 2026-10-04 (owner's instruction) |
| Pumpkin/ValheimVisualEnhanced | 0.5.18 | Client-side world-aware visual effects | — Added 2026-10-04 (owner's instruction) |
| Allifreyr/AutoServerPassword | 1.0.2 | Remembers server passwords after the first entry | — Kept 2026-10-04. Client-only; it stores passwords in plain text on each player's own PC |
| Radamanto/ServerQuickConnect | 1.0.4 | Main-menu button that joins a preset server | — Kept 2026-10-04. Client-only and unsynced; the server address goes into a Pack seed when the Pack is built, never the password, which stays with each player |
| ValheimModding/Jotunn | 2.30.2 | Library | Overrides the 2.29.2 pin declared by EpicLoot and the 2.29.0 declared by Guilds and Marketplace |
| ValheimModding/JsonDotNET | 13.0.4 | Library | — |
| ValheimModding/YamlDotNet | 16.3.1 | Library | Its own detector plugin loads it (#66 boot); it was first declared by ServersideQoL, which left on 2026-09-17 |

### Download sources

Every pin downloads from Thunderstore except the six rows here: Azumatt maintains these mods on
[Hexium](https://valheim.hexium.gg/teams/Azumatt) and their Thunderstore lines are deprecated
frozen (ADR-0026). `scripts/stage-stack.sh` reads this table, verifies each URL names the pin's
own version, and hashes what it downloads against the lock like any other pin. Hexium packages
ship a manifest but declare no dependencies, so these six add nothing to the closure check.

| Mod | Download URL |
| --- | --- |
| Azumatt/AzuClock | https://cdn.hexium.gg/upload/248/1.1.1.zip |
| Azumatt/AzuCraftyBoxes | https://cdn.hexium.gg/upload/48/1.8.27.zip |
| Azumatt/AzuExtendedPlayerInventory | https://cdn.hexium.gg/upload/11/2.6.1.zip |
| Azumatt/AzuHoverStats | https://cdn.hexium.gg/upload/219/1.1.11.zip |
| Azumatt/MouseTweaks | https://cdn.hexium.gg/upload/270/1.0.5.zip |
| Azumatt/ProximityVoiceChat | https://cdn.hexium.gg/upload/834/1.0.4.zip |

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
| sighsorry/CreatureManager | `CreatureManager` |
| sighsorry/DataForge | `DataForge` |
| sighsorry/Dive_In | `DiveIn` |
| Azumatt/AzuExtendedPlayerInventory | `AzuExtendedPlayerInventory` |
| sighsorry/SkadiNet | `SkadiNet` |
| sighsorry/Blasted_Swimming_Tarred_Bug_Fix | `BlastedSwimmingTarredBugFix` |
| turbero/DetailedLevels | `Detailed Levels` |
| LionAndOtter/Oathbound | Not yet read from a join. Jotunn-registered; whether it refuses a client without it is unverified |
| Lembitu.Oathbound, Lembitu.Callings, Lembitu.Guide, Lembitu.Guilds | Jotunn's module check: all four declare `NetworkCompatibility(EveryoneMustHaveMod, Minor)` (`src/plugins/*/…Plugin.cs`). Loaded on both sides; Oathbound and Callings joined together on 2026-10-04. Jotunn logs nothing for a matching set, and the refusal of a client without them is not yet read from a join |
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
| Bagr/DamageMeter, Bagr/CrewStats | The meters and windows render on the client while the server gathers the fights and the statistics; neither ships a ServerSync or a version check, so a client without them plays with no meter and is not refused (read from the 3.7.0 and 1.4.1 assemblies, 2026-10-05) |
| Crystal/BetterChat | The chat window and its settings panel are client UI. The server holds the enforced talk and whisper distances through ConditionalConfigSync (`ModRequired` false), so a client without the mod keeps vanilla chat — the same distances the overlay pins — and is not refused |
| Goldenrevolver/Quick_Stack_Store_Sort_Trash_Restock | The buttons, hotkeys and sorting run on the client; the server holds the area-stacking ranges through its `goldenrevolver.quick_stack_store` ConfigSync (`ModRequired` false). A client without the mod sees vanilla stacking and is not refused |

**Server-only.** Installing these on a client changes nothing a player can see.

| Mod | Why |
| --- | --- |
| MaxPlayerCount (fork) | Every patched surface runs on the host; a client is told the capacity by the server. Already excluded from the client pack by an assertion in the builder |
| nwesterhausen/DiscordConnector | Reads server events and posts a webhook; there is no client half |
| JereKuusela/Server_devcommands | Admin remote commands run on the server; players never use them. Withheld from the client pack by the builder's exclusion list |
| SeasonedProfessionals/OdinEye | A REST/WebSocket API on the server's loopback; there is no player half. Withheld from the client pack by the builder's exclusion list |

**Client-only — presentation only, reopened 2026-09-16 (#78).** The 2026-09-16 review had cut this
whole category, on the AdminQoL lesson: a mod the server cannot enforce is a mod whose behaviour
varies per player, and AdminQoL's gameplay defaults disabled durability loss for a full evening
with no server setting able to reach them. #78 narrows that rather than reversing it. A
presentation-only mod may ride in the Pack, because a player who removes it sees vanilla and no
rule changes. A gameplay-bearing mod the server cannot reach still does not ship.

| Mod | Decision |
| --- | --- |
| Azumatt/AzuHoverStats | **Adopted client-only.** Hover readouts for creatures, pieces, items and chests. Nothing in it is server-synced — every entry is a plain `Config.Bind` and there is no `ConfigSync` in the assembly — so the server could pin nothing even if it ran the mod, while installing it server-side *would* refuse every client that lacks it through its hand-rolled `AzuHoverStats_VersionCheck`. Its chest readout is not an information bypass: the `Container.GetHoverText` postfix bails on `m_checkGuardStone && !PrivateArea.CheckAccess(...)`, the vanilla ward check that Guilds extends to guild members with ward access, so an outsider sees nothing in a warded chest (#78) |
| Azumatt/AzuClock | **Adopted client-only.** Clock and weather forecast on screen. It bundles ServerSync but is not installed on the server, so nothing of it is synchronised; a player who removes it loses a readout |
| Azumatt/MouseTweaks | **Adopted client-only.** Mouse and modifier handling for moving, splitting and dropping stacks. Plain `Config.Bind` throughout, keybinds and thresholds only |
| Ab5oluteZer0/CraftingSearch | **Adopted client-only (2026-10-05).** Interface only: a search box and sort button in the crafting window. No config or sync code in the DLL; it patches `InventoryGui` display methods only, so a player who removes it sees the vanilla recipe list |
| Marins/CompactStatusEffects | **Adopted client-only (2026-10-05).** Interface only: a compact vertical status-effect HUD. Plain `Config.Bind` (position, scale, settings key), no sync code in the DLL; a player who removes it sees the vanilla status-effect area. Its settings key is seeded to Quote, leaving the default F8 to DetailedLevels |
| sighsorry/AdminQoL | **Dropped.** All 29 settings are client-decided: none is marked `[Synced with Server]` and it takes no part in the handshake (#70) |
| TOYNBEE/BoneMod | **Dropped.** Cosmetic bone scaling, client-side, pointless on the server, and unenforceable by the same argument (#70) |
| Lembitu.Harness | **Kept in the repository, never in the Pack.** It is our test harness for future acceptance work, inert without `-lembitu-harness`, and the builder asserts it is absent from a player's pack |

**Client-only is a deployment rule, and it is enforced by the installer.** `scripts/stage-stack.sh`
stages every adopted pin into `dist/`, because the client Pack is built from the same table, so
`dist/` alone does not distinguish the sides. `scripts/install-plugins.sh` carries the server's
half — a `CLIENT_ONLY` list naming AzuHoverStats, AzuClock, MouseTweaks, CraftingSearch and
CompactStatusEffects — and it withholds them
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
| Lembitu.Oathbound | Adapts Oathbound 0.21.14 where it has no setting (ADR-0022, ADR-0025): respec and class switch reset to level 1, with a confirmation before a switch and the tree's labels saying so; kill XP split within the killer's SocialSystem party near the kill, reaching its 150% total at four members; the fishing rod for every class and Mining and Wood Cutting from a Monk's bare hands; class power capped at ten per personal boss key (World Advancement Progression's private keys), spell growth and companion damage server-locked, and every equipment refusal naming the guide page. Patches Oathbound and reads World Advancement Progression, so a bump of either re-checks it; each feature verifies its own hooks at startup and switches off alone on a mismatch. Settings in `config/enforced/lembitu.oathbound.cfg` | ADR-0022, ADR-0025 |
| Lembitu.Callings | Professions and the Calling (ADR-0021, ADR-0022): the Calling window opened from the skills dialog (the row stars are read-only markers), the steep curve, shadow levels, focus protection and one death drain for every profession skill, and the Herbalist and Fishing bonus output. SeedBed's beds follow soil's biome rule with soil's yields (`config/enforced/blacks7ar.SeedBed.yml`), a Herbalist tonic or elixir needs its strongest herb's boss key to drink, and BlacksmithingExpanded's main config sync is locked at startup. Also keeps ExpertExplorer from aborting a new character's first save. Hooks vanilla, World Advancement Progression, SeedBed, ExpertExplorer and the bundled skill managers, never Oathbound. Settings in `config/enforced/lembitu.callings.cfg` | ADR-0022 |
| Lembitu.Guide | The in-game guide window (ADR-0027): chapters of short pages with the fixed page ids, opened by F1 and an inventory button and shown once on a character's first join; its text is the server's `config/enforced/lembitu.guide.md`, sent at join and on reload. Reads Oathbound's class record, Lembitu.Callings' window key and SocialSystem's client party state to open the matching page on each character's firsts. Patches nothing, so an Oathbound, SocialSystem or profession-mod bump does not re-check it. Settings in `config/enforced/lembitu.guide.cfg` | ADR-0027 |
| Lembitu.Guilds | Guilds form in game and claim SeparateSpawns' start regions (ADR-0028): every new player wakes at the sacrificial stones while their guild holds no region (SeparateSpawns' random assignment held back), a guild leader claims one of the three regions at its portal stone in the ring after a confirmation window naming the region and where it lies, and the region then follows membership — bedless respawn and portal — until the member leaves or the guild disbands; a bed overrides, as in vanilla. Membership is read from Guilds' server store only; the claim lives in the server's `config/bepinex/Lembitu.Guilds/<world>.claims.json`. Patches SeparateSpawns and reads Guilds, so a bump of either re-checks it; each feature verifies its own hooks at startup and switches off alone on a mismatch. Settings in `config/enforced/lembitu.guilds.cfg` | ADR-0028, #91 |
| Lembitu.Harness | Client-side test harness: joins the test server from a real client and drives a character through code | #10 |

These plugins run on the server and every client: they declare Jotunn's
`EveryoneMustHaveMod`, so the server refuses a client without them, and their settings are locked
from the server through Jotunn. `scripts/build-client-pack.sh` takes them from the build output, not
the pin table. Each is pinned to the packages it was read from: an Oathbound bump re-checks
`Lembitu.Oathbound`, a World Advancement Progression bump re-checks `Lembitu.Oathbound` (its boss-key
counts) and `Lembitu.Callings`, a SeedBed, BlacksmithingExpanded, Herbalist or ExpertExplorer bump
re-checks `Lembitu.Callings`, and a SeparateSpawns or Northarun/Guilds bump re-checks
`Lembitu.Guilds`; all log `<feature>: on` or the reason a feature switched off.

The harness is test infrastructure, not pack content. It is inert unless the client is launched with
`-lembitu-harness`, and it ships to the disposable test client only. Its fixture actions (set a
skill, give an item, teleport, land a fish, die) arrange a scene and are never gameplay proof.

## Deferred capability

The **Trade Post** (ADR-0006, #16) is superseded: Northarun/Marketplace is the remote market
(ADR-0019). DataForge stays restricted to tuning, now for a reason the Marketplace makes concrete: an
item that later disappears is lost from saves, and Marketplace clears a listing before delivering it,
so a removed clone can destroy listed items (ADR-0023).

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

- **Two gates refuse crafting, and one of them also equipping.** World Advancement Progression
  refuses crafting and equipping on personal keys, by the biome of an item's materials. Since
  2026-10-04 Item_Requirement also refuses crafting below a profession's ladder rung (ADR-0023). The
  boot must observe each refusal on its own, so a refusal can be told apart from the other.

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

- **Separate Spawns 0.1.1 can leave a client stuck on the loading screen when it joins after leaving
  another world in the same game session — not fixed (2026-10-05).** Its portal-terrain leveller
  (`PortalTerrainLeveler.ProcessQueue`) keeps its pending jobs and its coroutine running when a world
  unloads. On the next join it asks the zone system for terrain before the client's
  `WorldGenerator` exists, so `HeightmapBuilder.Build` throws `NullReferenceException` on the game's
  single terrain thread. That thread never restarts, so the game waits forever. Seen on the owner's
  first Shakedown join, after a local world had been opened in the same process. Workaround: quit
  the game completely and join without opening another world first; the owner's next join worked.
  The fix belongs in `Lembitu.Guilds`, which owns the Separate Spawns bridge: stop that coroutine and
  clear its jobs when a world unloads, and defer the zone loading while `WorldGenerator.instance` is
  null.
- **EpicLoot 0.14.13 can grow the skills list after vanilla builds its rows, crashing DetailedLevels 2.1.3 — fixed in `Lembitu.Callings` (2026-10-05).** Rebuild once if the local skill count grew during `SkillsDialog.Setup`; clear the original exception only after that rebuild succeeds, without creating skills in the fix. A fresh-character native first open now shows the Calling button and profession stars without a DetailedLevels exception (`~/lembitu-native-tests/20261005T181625Z-skills-rebuild/` on astral-tricep).
- **ExpertExplorer 1.7.0 stopped every new character from being created — fixed in
  `Lembitu.Callings` (ADR-0022).** Its `Player.Save` prefix loads exploration data the first time it
  meets a character, and `PlayerExplorationData.IsLegacySave` passes the missing
  `PlayerExplorationData` entry straight to `Regex.IsMatch`, which throws `ArgumentNullException`
  (`PlayerExplorationData.cs:136-184`). `FejdStartup.OnNewCharacterDone` saves the fresh preview
  character that `OnCharacterNew` builds, so the exception escaped and nothing was written. Confirmed
  2026-10-04 through the real menu on astral-tricep (client build 25527674, the full pack): pointer
  clicks on Start, New and Done left the new-character panel open, saved no character and logged the
  throw; the same clicks without ExpertExplorer saved the character. Evidence, with screenshots, is
  under `~/lembitu-menu-evidence/` on astral-tricep. `Lembitu.Callings` now answers a missing tag as
  "old format", which reads nothing from a character without data; the full-pack acceptance of the
  same day created three characters with no throw (`docs/build.md`). A character made before
  ExpertExplorer was installed meets the same check on load and gets the same answer; that path is
  read from the code, not exercised.
- **Guilds clamps `[5 - Territory] MembersPerUpgrade` to 1..100 on boot, and the cap holds anyway.**
  Observed 2026-10-04: an enforced 0 came back as 1 on every boot. Established from `Guilds.dll`
  1.2.2, sha256 `c9303d4f…89ef40`, decompiled with ilspycmd 11: the member cap is
  `MaxMembers + tier("members") × MembersPerUpgrade`, and the server refuses an upgrade whose `L`
  token exceeds the guild's level, which never passes MaxLevel (30). With `members = P1,L99` no
  guild reaches tier 1, so the cap stays five. The overlay pins 1, the lowest value the file keeps.
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
PvPBiomeDominions. On 2026-10-04 Oathbound replaced WackyEpicMMOSystem (ADR-0020).

| Mod | Why not |
| --- | --- |
| sighsorry/BossRules | World Advancement Progression gates boss summons and guardian powers per key; its remaining refunds and stones did not justify the mod, its overlay and the altar-scan guard we had to write |
| MidnightMods/ProgressivePowers | Cut on 2026-09-15, then restored; currently adopted above |
| warpalicious/More_World_Locations_AIO | 185 locations at the cost of a world-permanent dependency and four open defect tickets; the stack now uses vanilla locations |
| sighsorry/Fast_AssetBundle_Loader | Existed for MWL's 200+ bundles, and produced Linux `DriveInfo` failures and a shared-cache isolation deviation |
| sighsorry/CaptainValheim, sighsorry/SecondaryAttacks | Combat layers landing on one damage number; removed rather than tuned. AdditiveDamageModifier, cut with them, was readopted on 2026-10-04 |
| sighsorry/VeiledRecipes | Recipe discovery is already what EpicLoot's `PlayerMustKnowRecipe` gating reads |
| sighsorry/RepairRequiresMaterials | Friction without a rule behind it |
| sighsorry/Groundwork | Tool scaling not worth another mod on the placement path it already broke once |
| sighsorry/Valheim_Enchantment_System | Second enchanting path on the same items (ADR-0004) |
| MidnightMods/ValheimArmory | New base weapons need community EpicLoot patches to be enchantable (ADR-0004) |
| MidnightMods/StarLevelSystem | CreatureManager owns creature levels (ADR-0005, as amended) |
| Smoothbrain/Groups | Deprecated, and its bundled ServerSync reads `ZRoutedRpc.Everybody`, a const on Valheim 1.0. Parties are SocialSystem's (ADR-0020) |
| sighsorry/InventoryActions | Mutually exclusive with AzuExtendedPlayerInventory, which holds the slots for this run, and smaller |
| Nosferatu/SmoothServer | One pacing layer only; SkadiNet chosen |
| WackyMole/WackysDatabase | DataForge covers tuning |
| Tristan/Valheim_PvP_Tweaks | Excluded in September 2026 for overlapping PvPBiomeDominions and old pins; not adopted as a replacement after the 2026-10-03 removal |
| sighsorry/ServerManager | Its Discord and logging role is DiscordConnector's |
| AWLGaming/DiscordBot_AWL, warpalicious/DiscordTools, RustyMods/DiscordBot | Need an external bot host or two-way chat; the relay is a webhook |
| warpalicious/Discord_Screenshots | Client-only, nothing depends on it |
| sighsorry/YouAreNotWorthy | Gates on world keys, which this server does not write |
| shudnal/ProtectiveWards | Guilds covers wards (ADR-0019) |
| Therzie/Warfare | Untouched since March 2025 |
| Hex_Viking/HexResourceTracker, GChallenge/GCValheimStats, Tristan/Player_Activity, Eilif/EilifPaths | Client-only and unenforceable; EilifPaths also changes gameplay per player |
| KGvalheim/Marketplace_And_Server_NPCs_Revamped | Deprecated on Thunderstore and pre-1.0. Design reference for the deferred Trade Post only |
| MSchmoecker/MultiUserChest | The only candidate that changes networked item movement, which is where duplication and item loss live. The vanilla "someone is in the chest" wait is an annoyance, not a problem. A risk judgement, not a conflict: its own incompatibility list — QuickStore, QuickStack, SimpleSort — touches nothing in this pack (#78) |
| Crystal/BetterChat | Clan owns the chat window: it patches `Chat.Awake`, `InputText`, `HasFocus`, `Update`, `RPC_ChatMessage` and `SendPing`, and BetterChat rewrites the same input handling and visibility, risking the clan channel's prefixes. It would also add `shudnal/ConditionalConfigSync` 1.0.6 to the closure purely to make its own settings enforceable (#78) |
| ArgusMagnus/ServersideQoL, ArgusMagnus/ServersideQoL_JustSleep | **Removed 2026-09-17, hours after adoption, without ever working.** The framework ships a BepInEx *preloader patcher* and aborts unless it sits in the game tree's `patchers/` directory. `scripts/install-plugins.sh` deploys `patchers/` into `/config/bepinex`, but the container mirrors only `plugins/` into `/opt/valheim`, so the mod logged `ServersideQoL.Patchers.dll was not installed correctly` on every boot and JustSleep never wrote a config. Fixing it needs a second bespoke deploy step, like the one SeparateSpawns already needs; the owner judged a night-skip not worth that and cut both. The patcher gap in our installer is real and outlives the mods (#86) |
| Smoothbrain/CreatureLevelAndLootControl | **Tried and rejected 2026-09-17, on the live server.** It was the obvious replacement for CreatureManager — plain percentages for creature and boss health, its own affix tables, and the same three multiplayer-scaling keys — but 4.6.4 is from May 2025 and cannot run on Valheim 1.0: its bundled ServerSync reads `ZRoutedRpc.Everybody`, a field the game turned into a const, so its type initializer throws `TypeInitializationException` at boot and the mod does nothing. `scripts/screen-bundled-libs.sh` reports five stale references, and it was not run before the swap — which is the whole reason that script exists (ADR-0002, #84) |
| WackyMole/WackyItemRequiresSkillLevel | **Removed 2026-09-17 and not restored**, unlike the level mod it accompanied (2026-09-17, owner's instruction). Its curated rules gated iron, wolf, padded and carapace armour at character levels 20, 35, 50 and 65, and nothing reads those thresholds once there are no levels. World Advancement Progression's material-biome locks are the whole gear gate now (#80) |
| seneaL/SeneaL_UI | **Considered and dropped 2026-10-04** (owner's decision). It replaces the whole UI and by default takes over the inventory from AzuExtendedPlayerInventory, crafts from nearby chests beside AzuCraftyBoxes, and auto-feeds smelters beside BetterStations |
| sighsorry/Clan | **Removed 2026-10-04** (owner's instruction). Guilds of three to five are the membership, with parties for shared hunts (ADR-0019, superseding ADR-0008) |
| WackyMole/WackyEpicMMOSystem | **Replaced 2026-10-04 by Oathbound** (ADR-0020). Level and attributes only, with no talent tree; its party XP reads the deprecated Smoothbrain/Groups API, and its death penalty subtracts the retained XP from the total rather than the lost XP |
| blacks7ar/MagicPlugin | **Replaced 2026-10-04 by Oathbound's Mage and Warlock** (ADR-0020). One magic system, owned by the class pillar |
| blacks7ar/MagicRevamp | **Cut 2026-10-04: does not load.** Its assembly hard-depends on `org.bepinex.plugins.backpacks`, the deprecated Smoothbrain/Backpacks, which its manifest omits |
| Tenemo/EpicLoot_ProgressionFix | **Cut 2026-10-04: fails at startup.** It requires AzuCraftyBoxes 1.8.27 exactly, throws against our 1.8.19 and unpatches all its gameplay fixes. It also ships a preloader patcher the container never deploys (#86), and forces server-wide chat and armour-before-block with no switch |
| M2Valheim/SkillsReworked, M2Valheim/TalentTree | **Rejected 2026-10-04.** SkillsReworked's death drain writes skill levels directly, bypassing the boss-key floor. TalentTree rewrites the damage roll and armour for everyone with no setting, and its Last Bastion talent prevents death |
| friendly_neighbor/ExperienceSystem | **Rejected 2026-10-04.** Second Life cancels deaths and has no off switch; respec is free |
| korCaptain/CaptainSkillTree, treextr/PathOfValheiman, Lorska/Valheim_Level_System_by_Lorska, Ketanol/LevelingSystem_SharingXP and nine other level, class and party mods | **Reviewed 2026-10-04 and not adopted.** Decompiled verdicts are in `local/mod-review-2026-10-04/fit-*.md` |
| Mydayyy/ServerSideMap, NightOfGames/Huginn_Map | **Cut 2026-10-04.** Both share every player's explored map server-wide, while maps are personal and shared only by choice (ADR-0019) |
| ZenDragon/ZenMap | **Cut 2026-10-04.** No-map play resets exploration, its table radius is overwritten by ExpertExplorer, and it blocks the pin-naming Guilds' shared `!` pins rely on |
| sighsorry/STU_Ward | **Cut 2026-10-04.** Its `Guilds` group provider looks up the deprecated Smoothbrain Guilds (`org.bepinex.plugins.guilds`), not Northarun's `adrian.valheim.guilds`, so it cannot resolve wards against guilds. By default it also disables the vanilla ward recipe, the ward Northarun binds to a guild. Guild-bound vanilla wards and the banner territory protect bases instead |
| javadevils/OCDheim | **Cut 2026-10-04.** Transpiles the same placement method as Extra Snap Points and adds a second set of terrain tools; Extra Snap Points and PlanBuild cover precision building |
| JereKuusela/Infinity_Hammer, sighsorry/InfinityHammerAddon, JereKuusela/World_Edit_Commands | **Admin-only from 2026-10-04, not pinned.** Free copying, placement without cost, ignoring wards and removing anything contradict full-cost building, so admins install them on their own clients. Server_devcommands stays on the server for them |
| ValheimQoL/StorageGroups, Heyaeyaeya/ChestSorter | **Cut 2026-10-04.** Both route items between chests and their range is a per-player setting the server cannot lock, which the Pack rule refuses (ADR-0019). AzuCraftyBoxes and DynamicStoragePiles cover crafting from chests and seeing what is in them |
| ComfyMods/ComfyAutoRepair | **Cut 2026-10-04** (owner's decision). Vanilla one-item repair keeps repair trips deliberate; the mod also capped station level at 4, so higher-tier gear might not have auto-repaired |
| ZenDragon/ZenBossStone | **Cut 2026-10-04** (owner's decision). World Advancement Progression's personal keys already track each player's boss progress; its sacrifice-for-loot fallback would also have dropped CreatureManager's and EpicLoot's boss rewards |
| RustyMods/Seasonality | **Scrapped 2026-10-04** (owner's decision, "for now"). Seasonal spawns, ice shelves and the rest leave with it; the world keeps fixed difficulty without a calendar |
| blacks7ar/BetterStations | **Cut 2026-10-04** (owner's decision). Its smelter, kiln and other stations are new types rather than vanilla ones, so BlacksmithingExpanded's smelting and kiln perks, which patch the vanilla stations, would not reach them, and the smith's production speed would stop being a profession reward |
| ishid4/BetterArchery | **Cut 2026-10-04** (owner's decision). Its settings have no server sync, so arrow velocity, gravity and accuracy were each player's own to change, against the Pack rule, and archery belongs to Oathbound's Ranger and Hunter classes |
| Wubarrk/Njord | **Cut 2026-10-04** (owner's decision). It replaces vanilla ship propulsion with its own force and zeroes vanilla sail and rowing force, with no setting that restores them, so ImpactfulSkills' Sailing perks (sail force, rowing, wind angles) had nothing to act on and a Sailing focus gained almost nothing (ADR-0024). Vanilla propulsion returns; ships lose its 1.5× steering and shipwright vendor |

## Re-pinning

Pins are re-checked once, immediately before the launch world is created, and then frozen for the
run. Between now and then, a newer upstream version replaces a pin only if it passes the gate above
again — most of this catalogue was re-published within the last week, so a pin chosen today is hours
old, not months.
