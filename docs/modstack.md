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

**This table is the repository state.** It carries seventy-two pins: the sixty-three of the
2026-10-04 review plus four retained Shakedown additions, ConditionalConfigSync,
LiveExperienceTracker and Oathbound Addon (owner, 2026-10-06), FineDining (ADR-0029), and Tally (#109, 2026-10-07).
CrewStats and DamageMeter were removed by the owner on 2026-10-05 after CrewStats covered inventory.
On the review day the owner added thirty-five packages and removed Clan, settled the server concept
(ADR-0019), and then judged every mod against it; Oathbound replaced the level and magic mods
(ADR-0020). Each removal is a row in [Considered and cut](#considered-and-cut). The lock records
the exact package bytes.
The retired fork and plugins are deleted from `src/`; the maintained fork is ValheimWebMap.
The dated measurements below established earlier packs, not this candidate.

## Adopted upstream

Every mod here is pinned at exactly this version; the side it runs on is in
[Where each mod runs](#where-each-mod-runs). Most are installed on the server *and* the client
pack; ServerManager runs on both sides,
and eight ride in the Pack alone: AzuHoverStats, AzuClock, MouseTweaks, CraftingSearch,
CompactStatusEffects, LiveExperienceTracker, Oathbound Addon and Tally. Candidate staging is
not deployment or verification. "Enforced config" is a deliberate deviation from the defaults and
belongs in server-locked config rather than a player's file.

| Mod | Pin | Role | Enforced config |
| --- | --- | --- | --- |
| VentureValheim/World_Advancement_Progression | 1.0.0 | Personal keys: private per-character progression, per-player raids, key-gated actions, vanilla skill caps | Private keys on, all global keys blocked; equipment, crafting, cooking, eating, guardian powers and boss summons locked; repairs, building, taming, boats and portals open; skill floor from boss keys with the ceiling at 100 |
| RandyKnapp/EpicLoot | 0.14.13 | Gear tiers: magic drops, rarities, enchanting, shardstones and Haldor's adventure trade | Stock balance restored (2026-10-06, owner): only `Item Drop Limits = PlayerMustKnowRecipe` deviates, avoiding blocked world keys. Run dependencies pinned at stock: FreeBuild skips only the workbench; Adventure Mode on, bounty gating Unlimited. Stock restoration pinned to overwrite v16 and verify: drop rate 1, shardstones 0.2, boss trophies/Wishbones/swamp keys per player within 100 m, failed tempering never destroys gear, no bounty limit. Client seed replaces v16 muted colours with stock Blue/Yellow/Purple/Teal/Orange/Red and set #26ffff; generated names on. `EpicLoot/patches/lembitu-seaanimals.json` (2026-10-05) gives the hostile SeaAnimals creatures the biome tier's loot table through EpicLoot's own patch system — BlueShark Tier0, Crocodile Tier3, HammerHeadShark, TigerShark, HumboldtSquid and WhiteShark at their biomes' tiers — server-synced to every client at join; hostility read from the mod's prefabs, and the peaceful turtles, RightWhale and WhaleShark get none |
| LionAndOtter/Oathbound | 0.22.0 | Class level and talents: thirteen classes with 79-node trees, abilities, companions, magic and sieges | Stock XP and talents stay per class. `SharedExperience` off, `ExperienceMultiplier` 1, equipment rules and sieges on, blood moons off (blocked world keys and unsynced multipliers). `AccessMode = MenuButton`: tree and talent spending anywhere after the first oath; our plugin keeps first oath, switching and free respec at the Oathstone (2026-10-06, owner). Party kill XP and gathering-tool exceptions remain ours |
| ishid4/BetterArchery | 2.0.2 | Bow zoom, improved flight and retrievable arrows | Returns in Pack v17 (2026-10-06, owner): Lembitu.Oathbound mirrors exactly 14 gameplay keys through Jotunn at BetterArchery defaults; local edits revert and server sync reapplies. Zoom, draw-cancel, crosshairs, sneak readout and nocked-arrow visuals remain preferences. The quiver is off (2026-10-10, owner): AzuExtendedPlayerInventory forces `Enable Quiver` false whenever BetterArchery is present, and BetterArchery only steps aside for two other inventory mods, so a locked-on quiver added two rows that held any item and made row counts differ between players. We no longer lock that key, so AzuEPI's value stands and the Leather Quiver item and recipe are not registered. Both sides; installer client-only list unchanged. BepInEx 5.4.1501 declaration overridden by our pinned loader. Ranger True Flight (+10% speed) and Snapshot (+50% for 5 s after dodge) stack above it |
| sighsorry/CreatureManager | 1.2.9 | Fixed creature and boss multipliers, monster modifiers, Karma and Enforcers, and holding vanilla's headcount scaling at zero | Fixed five-player bosses: biome following off, level 1, health 5, damage 1.5 (2.25 with Combat hard). Ordinary health 2, healthPerLevel 0.75, vanilla base damage and damagePerLevel 0.15; Hard biome preset stays. Boss offence always rolls; defence/on-hit/utility each 33%, giving 1–4 modifiers, mean 1.99. Ordinary modifiers nominally ~20% (applicability may reduce this); Enforcers ~2 unchanged. Deathward, regenerating, omen, blamer banned everywhere; vortex, adaptive, chameleon banned for bosses/Enforcers. Boss unflinching zero because non-staggering bosses cannot roll it; armored/reflection split defence equally. KarmaLevelAndEnforcer, cap +2 and blocking switches unchanged; headcount 0 / 0 / 1; cloning/customisation off (2026-10-06, owner). 1.2.9's 5 s Dungeon Enforcer spawn delay taken (package default, owner 2026-10-09) |
| sighsorry/Dive_In | 1.2.4 | Diving, water combat, underwater creature pursuit | — |
| Azumatt/AzuExtendedPlayerInventory | 2.6.1 | Equipment slots, quick slots, Wishbone and Demister slots | Extra rows 0, three quick slots, equipment and special slots on; the vanity button off, which keeps the whole vanity surface unreachable — 2.6.1's new `Weapon Vanity` key only lists weapons inside that panel (re-checked 2026-10-05). Adopted from Hexium (ADR-0026) with the layout keys re-checked: every pinned key kept its name and section, and the 2.6.x layout keys are unsynced client preferences |
| Azumatt/AzuCraftyBoxes | 1.8.27 | Crafting and building pull materials from containers near the station | `Container Range` 20 m; `Leave One Item` off; `Mod Enabled` on; config locked; `Azumatt.AzuCraftyBoxes.yml` committed empty, so everything in range is pullable. 1.8.27 from Hexium (2026-10-05, ADR-0026): upstream fixes for craft item loss, double-taken partial stacks and chests others have open |
| Azumatt/AzuHoverStats | 1.1.11 | Hover readouts for creatures, pieces, items, chests and crafting timers | — Nothing in it is server-synced, so the server can pin nothing; client-only |
| Azumatt/AzuClock | 1.1.1 | On-screen clock and weather forecast | — Client-only |
| Azumatt/MouseTweaks | 1.0.5 | Inventory moving, stack splitting and quick-dropping with mouse and modifier | — Client-only |
| Azumatt/ProximityVoiceChat | 1.0.4 | Positional voice chat, quieter with distance, no external program | Voice ranges and the Opus codec pinned; the 1.0.3 `Allow Global Voice` sync pinned off, so voice stays positional (2026-10-05); microphone, playback, indicators and keybinds stay the player's |
| turbero/DetailedLevels | 2.1.4 | Skill progress readout | — Client preference; the Pack seeds its readout key to F8 |
| Ab5oluteZer0/CraftingSearch | 1.0.2 | Search box and sort button in the crafting window | — Client-side UI with no settings at all; added for the Shakedown (2026-10-05) |
| Marins/CompactStatusEffects | 1.1.2 | Compact vertical status-effect HUD under the minimap | — Client-side HUD: position and scale are each player's; the Pack seeds its settings key to Quote (2026-10-05) |
| dsoltyka/LiveExperienceTracker | 1.0.3 | Live skill XP rows above the health panel: skill, progress bar, current/needed XP and the latest gain | — Client-only HUD; every setting is the player's layout (2026-10-06, owner) |
| Jumpingmushroom/Tally | 1.0.1 | Shared combat meters and local records | — Required client mod (#109, 2026-10-07); no server install or config lock. Pack seed: `Sharing.Enabled = true`, toggle F10, window 300 × 220. Shared numbers and positions reach every participating player; records stay in each player's local file, not the character store. Two-account meter/layout acceptance remains owner-only |
| Somedudethattrytomakemodwork/oathbound_addon | 1.0.1 | Oathbound Addon: a command window for the Hunter's wolf — free hunt, stay, heel, recall — with a stance badge | — Client-only; no stat changes. Its settings are the window key, the badge and Oathbound HUD offsets, all preferences; the Pack seeds the window key to Y, because its default G is vanilla 1.0's radial menu. It reflects Oathbound internals and declares Oathbound 0.21.6, so every Oathbound bump re-checks it (2026-10-06, owner) |
| Crystal/BetterChat | 1.6.4 | Chat window that appears on new messages; talk, whisper and shout handling | Talk and whisper distances pinned at the vanilla 15 m and 4 m through the mod's server-enforced sync policy, so it adds convenience without changing who hears what (2026-10-05) |
| shudnal/ConditionalConfigSync | 1.0.10 | Library | Declared by BetterChat |
| Goldenrevolver/Quick_Stack_Store_Sort_Trash_Restock | 1.4.15 | Quick stack, restock, sort, trash and favourite buttons for containers | Area quick stack and restock server-locked: the host's settings apply to everyone (`ToggleAreaStackRestockConfigServerSync` true), area stacking without MultiUserChest stays false, and both nearby ranges are 0, so stacking and restocking reach only the open container. Pack seed: Ctrl+U quick stack, Shift+U restock, LeftAlt+U sort, RightAlt+U trash (2026-10-05) |
| sighsorry/DataForge | 1.3.8 | Item, recipe and effect tuning | Tuning only: no cloned or custom items. 1.3.8's `Fireplace Fuel Multiplier` stays at its package default of 10 (owner, 2026-10-09) |
| sighsorry/SkadiNet | 1.1.6 | Peer-aware network pacing, dungeon-layer filtering | — |
| sighsorry/Blasted_Swimming_Tarred_Bug_Fix | 1.2.6 | Vanilla state and teardown bug fixes | — |
| sighsorry/ServerManager | 1.1.7 | Authoritative characters, exact mod admission, ten-player capacity and Discord operations | ADR-0034; one character per account, empty starter items, log-only cheat/stat actions. Eight presentation mods optional (ValheimVisualEnhanced joined the seven on 2026-10-10); Tally required. Five-minute saves; native acceptance #101 passed with owner-only two-account checks outstanding |
| JereKuusela/Expand_World_Size | 1.44.0 | World radius, edge and stretch. World-permanent in the strongest sense: the values are baked into terrain at generation | `World radius` 13250, `Stretch world` 1.325, `Stretch biomes` 1.25, `Locations` 1.75: about 1.76x vanilla area with points of interest at vanilla density, chosen 2026-10-04 for rival-but-cooperating guilds (ADR-0019); before that 12500/1.25/1.25, and ADR-0018's 15000/1.5/1.25. From 1.44 the settings are also saved in the world file and override the config on load |
| Mushroom_Vikings/SeparateSpawns | 0.1.1 | One scored start region per guild | `InnerRadius` 1200 and `MinStonesDistance` 500, so starts lie 0.5-1.2 km from the sacrificial stones, at least 1 km apart (halved on 2026-10-04 at the owner's request, from 2400 and 1000). From 2026-10-04 one group per guild, rostered by Steam ID before launch (ADR-0019); the committed roster still holds the three empty, randomly filled groups of the collaborative 2026-10-03 setup until the guilds are known. Its config lives in the game tree rather than BepInEx's, so `config/dedicated/` and `scripts/apply-dedicated-config.sh` own it, not the enforced overlay |
| MidnightMods/ProgressivePowers | 0.3.6 | Forsaken power mastery: powers grow with use | The boss-power pillar (ADR-0019): mastery credit within 100 m of the dead boss (package 200 m), the same radius as boss keys and party XP; one attuned power; active use blocked, so powers are passive bonuses over seven mastery levels (2026-10-04) |
| Vapok/AdventureBackpacks | 2.2.11 | Backpacks with their own storage | All six tiers server-pinned: contents at 85% weight; integer carry bonus per quality halved and rounded down to 2/5/7/10/12/15, Meadows through Mistlands (owner, 2026-10-05). One-way: removing the mod deletes its packs and contents. Craft-from-backpack and auto-store remain each player's preferences (ADR-0019) |
| OdinPlus/OdinArchitect | 1.8.0 | Larger and new building pieces | — Added 2026-10-03 (owner's instruction). One-way: its pieces live in the world save |
| MathiasDecrock/PlanBuild | 0.20.0 | Plan, copy and share builds | Direct build and terrain tools off for players, so a plan is finished with real materials at the right station; admins keep both (2026-10-04, ADR-0019) |
| OdinPlus/OdinsKingdom | 1.6.2 | Castle building pieces with their own build tool | — Added 2026-10-03 (owner's instruction). One-way: its pieces live in the world save |
| ComfyMods/SearsCatalog | 1.9.0 | Resizable, movable build panel | — Added 2026-10-03 (owner's instruction). Declares BepInEx 5.4.2202, a documented override |
| SpikeHimself/XPortal | 1.2.26 | Pick a portal destination from a list | — Added 2026-10-03 (owner's instruction). The only portal mod since PortalRules left the same day. 1.2.26 (released 2026-10-08, adopted 2026-10-09) fixes the configuration panel that was dead near the sacrificial stones: its buttons ignored input and the open panel blocked the game |
| Marlthon/OdinShip | 0.8.7 | Seven cargo and war ships | — Added 2026-10-03 (owner's instruction). One-way: its ships live in the world save |
| blacks7ar/GlassPieces | 1.2.8 | Glass, iron and copper building pieces and a minable resource | `Use Smelter = Off` server-pinned: glass uses the mod's furnace rather than vanilla smelters (2026-10-05). Added 2026-10-03. One-way: its pieces live in the world save |
| Marlthon/TheFisher | 0.3.9 | New fish, aquatic creatures and aquariums | — Added 2026-10-03 (owner's instruction) |
| Advize/PlantEverything | 1.21.3 | Cultivator plants berry bushes, flowers, mushrooms, extra trees and more | Biome rules enforced for its own plantables and vanilla crops, so planting anywhere stays ImpactfulSkills' high-level Farming reward (2026-10-04, ADR-0021) |
| OdinPlus/OdinsFoodBarrels | 1.4.0 | Buildable storage barrels for seeds, fruit and vegetables | — Added 2026-10-04 (owner's instruction). One-way: its pieces live in the world save |
| OdinPlus/OdinCampsite | 1.6.5 | Camping-style building pieces | — Added 2026-10-04 (owner's instruction). One-way: its pieces live in the world save |
| blacks7ar/SeedBed | 1.2.9 | Plant seeds in a bed instead of cultivated ground | — Added 2026-10-04 (owner's instruction). One-way: its pieces live in the world save |
| Marlthon/SeaAnimals | 0.3.9 | Dangerous and rideable ocean creatures | — Added 2026-10-04 (owner's instruction) |
| blacks7ar/Herbalist | 1.5.0 | Herbalism skill, a crafting station, tonics and recovery items | Its own tonic tiers stay at 1: no profession-level craft gate. All eight elixirs kept and retuned to boss-fight strength (Berserker ×1.25, Swift ×1.2, Jump ×1.5, Fast Learner ×1.5, Invisibility and Heavy Lifter 60 s); config locked (ADR-0024). Pack v17: Lembitu.Callings reads the brewer's grade, not the drinker's skill, for tonic/elixir duration and mead scaling; ungraded drinks count as grade 1 and resistance/Tasty/Lingering meads have no one-hour floor. Tonic drinking keeps its personal boss-key checks. `Exp Gain Factor = 2` remains, with ImpactfulSkills' Herbalist rate 4.6 (2026-10-06). Its bundled death handling never counts: Lembitu.Callings restores the skill and drains it by the personal-key floor (ADR-0022). One-way: its station lives in the world save |
| MSchmoecker/DynamicStoragePiles | 0.8.1 | Stack and pile containers that show their fill level | — Added 2026-10-04 (owner's instruction). One-way: its pieces live in the world save |
| Searica/DodgeShortcut | 1.4.0 | A single dodge key | — Added 2026-10-04 (owner's instruction). It rebuilds the dodge key hint with fewer children, which made Zen_ModLib's own dodge-hint rewrite throw inside the settings menu's Accept; `Lembitu.Callings` runs Zen's rewrite only on the full vanilla hint (2026-10-10). It also refused its key whenever the chat window was merely shown (vanilla shows it ten seconds after every chat line); `Lembitu.Callings` swaps that test for vanilla's `Chat.HasFocus`, so only typing in chat blocks the dodge (2026-10-10; a reported "Alt no longer dodges" is not yet tied to this) |
| OdinPlus/BlacksmithingExpanded | 1.2.4 | Blacksmithing skill that improves crafting, smelting and kiln output | The smithing profession; ImpactfulSkills' Forging and Crafting are off so the two never stack. Gear bonuses follow the smith's level only: +2% damage, +1 armour and +2 block per 10 levels, no per-upgrade extra, no elemental rider (2026-10-04, ADR-0024). XP about 1.75× the package for crafts, smelts, upgrades and first crafts, with ImpactfulSkills Blacksmithing rate 3.8 on top for mastery at Kall; repairs unchanged (2026-10-06, ADR-0030). Its own 5% death loss cannot be pinned, because it lives under a section named after an unresolved localization key (`[skill_1208107160]`); `Lembitu.Callings` puts the skill back after it and drains a non-focus Blacksmithing once, by World Advancement Progression's floor (ADR-0022). Its main settings carry no lock entry of their own; `Lembitu.Callings` locks the sync at startup (#89, 2026-10-05) |
| xtavim/BetterMap | 1.1.0 | Map interface: boats, carts, death markers and zoom | Auto Pins Enable false; creature radar and trader reveal off. Alone writes the 100 m baseline explore-radius field; Explorer scales the reveal call (2026-10-05, ADR-0019, ADR-0024) |
| blacks7ar/Explorer | 1.1.7 | Exploration skill with skill-gated live resource and dungeon markers | Marker perks unlock at Meadows 1, Black Forest 10, Swamp 20, Mountains 30, Plains 40, Mistlands 50 and Ashlands 60; dungeons/caves 10. These level unlocks stay after the crafting ladder leaves. Callings grows marker range from 20 m at level 1 to 96 m at 100; reveal grows from the 100 m baseline to 400 m. Explorer owns map reveal; BetterMap is the map interface only (Pack v17, 2026-10-06). On Valheim 1.0.17 its new-biome reward (10 XP) fired at every biome crossing, because it still patches `Player.AddKnownBiome` with the pre-1.0.17 signature; `Lembitu.Callings` skips that prefix and pays the reward once per biome the character has not recorded (2026-10-10) |
| Northarun/Guilds | 1.5.1 | Guilds: ranks, guild chat, shared vault, guild-bound wards, a banner territory, guild levels, upgrades and achievements | Five members at most and the Members upgrade neutralised; founding a guild is free (`CreateCost` 0, package 1,000 coins, 2026-10-05); no waiting period after leaving or a kick (`RejoinCooldownHours` 0, package 12 h, 2026-10-05); guild levels grow 1.15× per level and coin donations buy guild XP at 10 coins per point, so trade feeds the guild (2026-10-05); boss keys never shared with absent members; Comfort upgrade at guild level 12 and 20, monster ward at level 10 (2026-10-04, ADR-0019). The membership and ward authority since Clan left. 1.3–1.5 add guild buildings, Diplomacy, a territory barrier that keeps outsiders out and territory levelling that flattens the ground and clears trees and rocks; both territory features stay at their package defaults, on (owner, 2026-10-09). Levelling is a permanent terrain edit |
| Northarun/Marketplace | 1.5.0 | Server-wide marketplace and order board: coin sales, buy orders, bounties, a bank | The one remote trade system; a 5% fee on every payout keeps coins scarce (2026-10-04, ADR-0019) |
| M2Valheim/SocialSystem | 1.0.5 | Invite-only parties of up to eight across guilds, party positions on the map, friends and party chat | Defaults pinned: parties of eight at most, positions shared within the party. Party kill-XP sharing is `Lembitu.Oathbound`'s, which reads party membership from SocialSystem's server-side party service rather than the party ID clients publish (2026-10-04, ADR-0020, ADR-0022) |
| MidnightMods/ImpactfulSkills | 0.21.1 | Land and Road professions and Cooking: yield, area work, growth timers, taming, sailing and hauling perks | Forging/Crafting/ScaleCraftedEquipmentQuality, Combat/Body perks, equip-speed bonus and Knowledge Sharing off. Perk unlocks 40–70 stay, without craft gates. Mastery: wood/ore ×2, vein break 10%, Farming thresholds 50,70,90,100; taming/honey ×2.5, slaughter ×3, animal bonus star 40%; sail force bonus 2, headwind angle 10°; carry +150, cart mass reduction 90%. Pace rates: Wood Cutting/Mining/Fishing/Animal Handling 1.9, Farming 2.7; Explorer 2.9, Sailing 11.8, Hauling cart XP 0.6 / carried-load XP 6.7; Blacksmithing 3.8, Herbalist 4.6, Cooking 4. Land masters before Fader, Road at Fader, Craft at Kall. Cooking eating XP and eater decay reduction off (2026-10-06, owner) |
| sighsorry/FineDining | 1.1.4 | Food spoilage and freshness, the Icebox, cooking-station auto-eject | Spoilage on (`Spoilage Mode = FollowYaml`) with the package lifetimes, 2-4 days of server time; stale food bottoms out at 0.75. Three food slots and `Food Stat Scale = 1.1`, so a fresh dish gives 110% of vanilla and a stale one 82.5%. Chef's Choice, diminishing returns, Full Course, Cooking XP for eating and its Cooking production bonus off; the vanilla fermenter excluded, so meads keep vanilla timing and output; config locked. `FineDining/Spoilage.yml` makes jerky, sausages, smoked fish and smoked moose meat keep forever beside the package's own overrides, which follow 1.1.4 (owner, 2026-10-09). Nothing spoils in the Mountains or Deep North; the Icebox pauses spoilage, two per account (2026-10-06, ADR-0029). One-way: its Icebox and rotten foods vanish if it leaves |
| sighsorry/AdditiveDamageModifier | 1.2.4 | Resistances and weaknesses stack additively | Players always take at least 25% of each floored damage type (package: 10%), so stacked resistances never reach immunity; config locked (2026-10-04) |
| VentureValheim/Venture_Multiplayer_Tweaks | 1.0.0 | Server tweaks: PvP, map positions, trader pins, death behaviour | PvP held off for everyone; public map positions off (guild and party positions come from Guilds and SocialSystem); trader map pins off, temple pin on; vanilla respawn and skill loss on death (2026-10-04, ADR-0019) |
| VentureValheim/Venture_Logout_Tweaks | 1.0.0 | Restores status effects such as Rested from the last logout | — Added 2026-10-04 (owner's instruction) |
| ZenDragon/ZenRaids | 1.2.3 | Lit fires keep spawns out of a base; raid trigger control | Vanilla raid odds with no per-player bonus (2026-10-04, ADR-0019). It still decides when a raid would roll, but every raid is now an Oathbound siege, so its biome list no longer matters; frequency is lowered by the launch modifier `Raids less`. Base safety is earned later through the Guilds monster ward at guild level 10 |
| ZenDragon/Zen_ModLib | 1.14.21 | Library | Declared by ZenRaids; rebuilt upstream for Valheim 1.0.17 (2026-10-07). Its unconditional FixShowDodgeKeyHint assumes the vanilla dodge hint; next to DodgeShortcut it threw in `Settings.ApplyAndClose`, so Accept neither saved settings (volumes included) nor closed the menu. Its "Update KeyHints" switch does not reach that patch; `Lembitu.Callings` guards it (2026-10-10) |
| Searica/Extra_Snap_Points_Made_Easy | 2.1.1 | Extra snap points on vanilla pieces | — Added 2026-10-04 (owner's instruction). Its settings are plain local config despite their "synced" labels, so snapping is each player's preference; accepted under the Pack rule (ADR-0019) |
| JereKuusela/Server_devcommands | 1.115.0 | Server side of the admin tools: remote devcommands and permissions for admins | Server-only, withheld from the Pack. Admins install Infinity Hammer, its addon and World Edit Commands on their own clients; none of them is in the player stack (2026-10-04) |
| Nekitker/SaunaMod | 2.5.0 | Buildable, upgradable sauna: steam heal, buffs and up to +2 comfort | `[Mead] DurationMultiplier = 1` server-pinned in `nekitker.saunamod.cfg`: resistance meads keep vanilla duration (2026-10-05). Its comfort still stacks with the Guilds Comfort upgrade; both kept, the guild one priced late |
| ValMedia/OdinOnDemand | 1.3.0 | Cinema screens and music players | — Added 2026-10-04 (owner's instruction), kept after review. Every client fetches streams itself; only the Windows video player is bundled, so Mac and Linux players may get no video |
| ValMedia/OOD_LIB | 1.2.0 | Library | Declared by OdinOnDemand |
| SeasonedProfessionals/OdinEye | 1.2.39 | Server data over a REST API and WebSocket, for future tooling | Bound to loopback, never a published port: the API has no authentication and can push in-game messages (2026-10-04). Server-only, withheld from the Pack |
| MSchmoecker/WhichModAddedThis | 0.1.2 | Mod name in item tooltips and the build HUD | — Added 2026-10-04 (owner's instruction) |
| VentureValheim/Deluxe_Particles | 1.0.0 | Larger particle effect on dropped items | — Added 2026-10-04 (owner's instruction) |
| Pumpkin/ValheimVisualEnhanced | 0.5.18 | Client-side world-aware visual effects | — Added 2026-10-04 (owner's instruction). Optional at join since 2026-10-10: its plugin filters itself to the client process (the server logs it as skipped) and carries no sync, so a machine whose GPU hangs with it, like astral-tricep, may leave it out |
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
| sighsorry/FineDining | `sighsorry.FineDining`: its ServerSync `ConfigSync` sets `ModRequired = true` and minimum version 1.1.3 (read from `FineDining.dll` 1.1.3, 2026-10-06), so a client without it is refused. Not yet read from a join |
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
| Crystal/BetterChat | The chat window and its settings panel are client UI. The server holds the enforced talk and whisper distances through ConditionalConfigSync (`ModRequired` false), so a client without the mod keeps vanilla chat — the same distances the overlay pins — and is not refused |
| Goldenrevolver/Quick_Stack_Store_Sort_Trash_Restock | The buttons, hotkeys and sorting run on the client; the server holds the area-stacking ranges through its `goldenrevolver.quick_stack_store` ConfigSync (`ModRequired` false). A client without the mod sees vanilla stacking and is not refused |
| blacks7ar/Explorer | Both sides: the server locks tier/reveal settings and the client runs live trackers. Bundled ServerSync ModRequired is false; installing it alone does not require clients to have it (read from Explorer 1.1.7, 2026-10-05) |

**Server-only.** Installing these on a client changes nothing a player can see.

| Mod | Why |
| --- | --- |
| JereKuusela/Server_devcommands | Admin remote commands run on the server; players never use them. Withheld from the client pack by the builder's exclusion list |
| SeasonedProfessionals/OdinEye | A REST/WebSocket API on the server's loopback; there is no player half. Withheld from the client pack by the builder's exclusion list |
| ValheimWebMap (fork) | The web server runs inside the game server and players use a browser, not a mod. Withheld from the client pack by the builder's `NEVER_STAGED` list and from ServerManager's client lists |

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
| dsoltyka/LiveExperienceTracker | **Adopted client-only (2026-10-06).** Interface only: a postfix on `Skills.Skill.Raise` reads the skill's accumulator and paints a fading row per skill above the health panel. Plain `Config.Bind` layout settings, no sync code, no `NetworkCompatibility` attribute in the DLL; a player who removes it loses the readout |
| Jumpingmushroom/Tally | **Adopted client-only (2026-10-07).** Required rather than optional under the character-store mod policy (#102/#109). The Pack seeds sharing on and the toggle to F10; records remain local. Shared numbers and positions are not private. The owner's two-account session must still prove both-player meters and default-resolution placement |
| Somedudethattrytomakemodwork/oathbound_addon | **Adopted client-only (2026-10-06).** Gameplay-bearing but setting-free in the ADR-0019 sense: stay and heel stop the local Hunter's own wolf from sensing or chasing targets (`BaseAI.CanSenseTarget` and `MonsterAI.UpdateAI` patches limited to that one wolf), and nothing it binds changes difficulty or numbers. No sync code and no Jotunn; on a dedicated server it finds no local player and does nothing. Orders act on the client that runs the wolf's AI, so a wolf whose AI moved to another player's client ignores them until it moves back [INFERENCE from the patches; a Shakedown check] |
| sighsorry/AdminQoL | **Dropped.** All 29 settings are client-decided: none is marked `[Synced with Server]` and it takes no part in the handshake (#70) |
| TOYNBEE/BoneMod | **Dropped.** Cosmetic bone scaling, client-side, pointless on the server, and unenforceable by the same argument (#70) |
| Lembitu.Harness | **Kept in the repository, never in the Pack.** It is our test harness for future acceptance work, inert without `-lembitu-harness`, and the builder asserts it is absent from a player's pack |

**Client-only is a deployment rule, and it is enforced by the installer.** `scripts/stage-stack.sh`
stages every adopted pin into `dist/`, because the client Pack is built from the same table, so
`dist/` alone does not distinguish the sides. `scripts/install-plugins.sh` carries the server's
half — a `CLIENT_ONLY` list naming AzuHoverStats, AzuClock, MouseTweaks, CraftingSearch,
CompactStatusEffects, LiveExperienceTracker, oathbound_addon and Tally — and it withholds them
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

One fork is maintained. Adoption is the default (ADR-0003), and configuration reaches most
project-specific behaviour without owning someone else's source.

| Fork | Forked from | Licence | Why | Retire when | Config |
| --- | --- | --- | --- | --- | --- |
| ValheimWebMap | [koenhendriks/Valheim-Web-Map](https://github.com/koenhendriks/Valheim-Web-Map) v1.3.0 (`1e69163286110ecd23f596dedfd2f38fd570b6a0`) | MIT | Server-only public web map; 1.3.0 draws only ±10,240 m and this world reaches 13,250 m (ADR-0003, 2026-10-07 amendment). Our changes: the world's radius and edge read from Expand_World_Size, corrected render and cartography extents, and a hidden player's exploration held back until logout (`src/forks/ValheimWebMap/UPSTREAM.md`) | An upstream release covers larger worlds and passes this world's checks | `config/enforced/com.valheimwebmap.cfg` |

The MaxPlayerCount fork left on 2026-10-07: ServerManager's ten-player capacity replaced it, and
DiscordConnector left with it (#102).

## Our plugins

| Plugin | What it owns | Ticket |
| --- | --- | --- |
| Lembitu.Oathbound | Version 0.4.0: oath changes and free respec require the Oathstone using its own collider-range rule; the inventory Classes button is hidden until the first oath, then the tree and talent spending work anywhere. Stock per-class XP/talents and wording return. Party kill XP reaches 150% at four nearby members; poison credit, fishing rod for every class, Monk gathering and ten-power-levels-per-personal-key cap remain unchanged. Spell growth, companion damage and BetterArchery gameplay are server-locked through Jotunn; player archery preferences stay untouched | Config in `config/enforced/lembitu.oathbound.cfg`; all-or-nothing hook checks per feature |
| Lembitu.Callings | Professions and the Calling (ADR-0021, ADR-0022): Calling window, read-only stars, steep curve, shadow levels, focus protection, one profession death drain, Herbalist/Fishing bonus output, SeedBed soil rules, tonic boss-key checks and BlacksmithingExpanded config lock. Pack v17 removes profession crafting gates: benefits, not blocks. Deep North gear and Frost Foundry uncooked intermediates require the player's personal Fader key to craft and equip; the list is generated from native materials. Brewer's grade (real Herbalist level, 1 below 25 through 5 at 100) stamps mead bases, fermented meads, tonics and elixirs, crosses the fermenter and replaces drinker-skill scaling; ungraded drinks count as 1. Cook's grade adds 5% food stats and 12.5% shelf life per grade above 1, follows station conversions and survives the Market; work meals raise Land/Road perks by 10, never grades. Eaten-food scales survive relog. Explorer markers grow 20..96 m. Log splitter, quick bite and steady overload unlock at 50; clients report profession XP every ten minutes. Hooks vanilla, World Advancement Progression, SeedBed, Herbalist, Explorer, FineDining and bundled skill managers, never Oathbound. Settings in `config/enforced/lembitu.callings.cfg` | ADR-0022, ADR-0029, ADR-0030 |
| Lembitu.Guide | The in-game guide window (ADR-0027), version 0.3.0: stable page ids, F1 and an inventory button, first-join display, server text sent at join and reload. Pack v17 keeps the `ladder` id but titles it Profession benefits: no profession craft gates, brewer's grade, stronger cook's grades and the Deep North personal Fader key. Reads Oathbound's class record, Callings' window key and SocialSystem's party state for first-event pages; patches neither upstream mod. Settings in `config/enforced/lembitu.guide.cfg` | ADR-0027 |
| Lembitu.Guilds | Guilds form in game and claim SeparateSpawns' start regions (ADR-0028): every new player wakes at the sacrificial stones while their guild holds no region (SeparateSpawns' random assignment held back), a guild leader claims one of the three regions at its portal stone in the ring after a confirmation window naming the region and where it lies, and the region then follows membership — bedless respawn and portal — until the member leaves or the guild disbands; a bed overrides, as in vanilla. Membership is read from Guilds' server store only; the claim lives in the server's `config/bepinex/Lembitu.Guilds/<world>.claims.json`. Patches SeparateSpawns and reads Guilds, so a bump of either re-checks it; each feature verifies its own hooks at startup and switches off alone on a mismatch. Settings in `config/enforced/lembitu.guilds.cfg` | ADR-0028, #91 |
| Lembitu.Harness | Client-side test harness: joins the test server from a real client and drives a character through code | #10 |

These plugins run on the server and every client: they declare Jotunn's
`EveryoneMustHaveMod`, so the server refuses a client without them, and their settings are locked
from the server through Jotunn. `scripts/build-client-pack.sh` takes them from the build output, not
the pin table. Each is pinned to the packages it was read from: an Oathbound bump re-checks
`Lembitu.Oathbound`, a World Advancement Progression bump re-checks `Lembitu.Oathbound` (its boss-key
counts) and `Lembitu.Callings`, a SeedBed, BlacksmithingExpanded, Herbalist, Explorer or FineDining
bump re-checks `Lembitu.Callings`, and a SeparateSpawns or Northarun/Guilds bump re-checks
`Lembitu.Guilds`; all log `<feature>: on` or the reason a feature switched off.

The harness is test infrastructure, not pack content. It is inert unless the client is launched with
`-lembitu-harness`, and it ships to the disposable test client only. Its fixture actions (set a
skill, give an item, teleport, deliver a hit or a chop, cast a float, raise a skill, read an object's
network data, land a fish, die) arrange a scene and are never gameplay proof.

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

- **Boss keys gate gear; profession levels reward making it.** World Advancement Progression
  still refuses crafting and equipping on personal keys. Lembitu.Callings extends that rule to
  generated Deep North gear and Frost Foundry intermediates using the personal Fader key.
  Observe a low-profession craft succeeding with its key, and Deep North craft/equip refused
  without Fader and allowed with it. No profession-level crafting gate remains in Pack v17.

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
- **FineDining 1.1.3 forgets eaten foods' scales on a relog — fixed in `Lembitu.Callings` (2026-10-06).** Its saved diet state holds only the slot fields (`{"UnlockedFoodSlots":3,"AppliedBaseSlotScale":1.1}` with soup eaten), so after a relog every eaten food fell back to the base 110%: a graded dish lost its grade and stale food came back fresh. Callings keeps the scales in `lembitu.callings.eaten-scales` and restores them only when FineDining loads an empty list. A native relog kept graded soup at ×1.21 (`~/lembitu-native-tests/20261006T094335Z-cook/` on astral-tricep; ADR-0029).
- **Oathbound 0.21.14 paid nobody for a poison kill — fixed in `Lembitu.Oathbound` 0.3.0 (2026-10-06).** Oathbound credits a kill to the attacker on the creature's last hit and lends burning ticks the player who set the fire, but vanilla poison ticks carry no attacker (`SE_Poison.UpdateStatusEffect`) and Oathbound lends them nobody, so with SharedExperience off a creature that died of poison paid no class XP. `Lembitu.Oathbound` credits the poison to the player whose hit set it and answers only Oathbound's kill-owner lookup; no hit gains an attacker. A poisoner no longer nearby is not found, as with fire. Native proof: a 40 hp boar poisoned by a Mage's hit fell tick by tick and paid +12 class XP, the same as a direct kill (`~/lembitu-native-tests/20261006T103841Z-fixes/` on astral-tricep; the poisoning hit is a harness fixture, the poison and the reward are the game's).
- **Herbalist 1.5.0 compounded shared mead durations — fixed in `Lembitu.Callings` (2026-10-06).** The upstream consume prefix mutates the shared status effect, making repeated drinks compound. Pack v17 replaces that prefix with its formulas read from the brewer's grade, restores shared assets after every attempt, and removes the one-hour floor: cooldowns 10–80% shorter, resist/Tasty/Lingering durations ×1.25–2. The v16 native proof of non-compounding (`~/lembitu-native-tests/20261006T103841Z-fixes/`) used the old drinker-skill formula and retained floor; it is not v17 acceptance.
- **Herbalist 1.5.0 reuses its herb heal-duration bonus for potions — adapted in `Lembitu.Callings` 0.6.0 (2026-10-06, owner).** Every elixir's `SetupStats` receives `Duration Bonus Factor` (default +10 s), and scaling adds it before multiplying: retained decompile `/tmp/lembitu-sweep-2026-10-06/Herbalist.cs:208,322,2926,2954`. Callings drops that additive term only while scaling a potion, so configured duration means configured × (1 + 0.75 × (grade − 1) / 4), including ungraded grade-1 drinks: Invisibility lasts 60 s at grade 1 and 105 s at grade 5. Dandelion/thistle healing and their duration bonus stay unchanged. Managed-source smoke covers grade factors; native potion acceptance remains required.
- **ExpertExplorer retired 2026-10-05.** Its new-character save failure was previously
  guarded by Callings. Explorer 1.1.7 replaces it and the obsolete save hook is removed;
  P belongs to SocialSystem Party, with no ExpertExplorer pin prompt.
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
| Radamanto/Item_Requirement | **Removed in Pack v17 (2026-10-06, owner): benefits, not blocks.** All 367 profession craft rules and the three named level-40 exceptions leave. Personal boss-key locks stay; Explorer's marker-level perks and Herbalist's tonic tiers at 1 stay. Deep North gear instead requires the personal Fader key through Lembitu.Callings. |
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
| sighsorry/ServerManager | **Adopted 2026-10-07 (#101/#102), reversing the 2026-10-04 rejection.** Its authoritative character store and exact-Pack admission are now required; its Discord and ten-player capacity replace DiscordConnector and MaxPlayerCount |
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
| Bagr/CrewStats, Bagr/DamageMeter | **Removed from Pack and server 2026-10-05** (owner). CrewStats' statistics window covered inventory; the owner chose to remove both statistics/meter mods instead of repairing the overlay. Their configs and key seeds leave too. |
| MilkMediaProductions/ExpertExplorer | **Replaced 2026-10-05 by blacks7ar/Explorer 1.1.7** (owner, ADR-0019/0024). Exploration becomes skill-gated live resource/dungeon radar; the obsolete Callings first-save guard and P pin prompt leave with ExpertExplorer. |
| nbusseneau/Better_Cartography_Table | **Not added 2026-10-07** (owner). 1.0.0's guild pins call Smoothbrain's Guilds API, not Northarun's, so guild tables cannot work here; its settings are local and unsynced, which the Pack rule refuses; pin privacy is checked only on the client. Northarun Guilds already shares guild pins (`docs/wiki/operations.md`, Decisions of 2026-10-07) |
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
| Wubarrk/Njord | **Cut 2026-10-04** (owner's decision). It replaces vanilla ship propulsion with its own force and zeroes vanilla sail and rowing force, with no setting that restores them, so ImpactfulSkills' Sailing perks (sail force, rowing, wind angles) had nothing to act on and a Sailing focus gained almost nothing (ADR-0024). Vanilla propulsion returns; ships lose its 1.5× steering and shipwright vendor |

## Re-pinning

Pins are re-checked once, immediately before the launch world is created, and then frozen for the
run. Between now and then, a newer upstream version replaces a pin only if it passes the gate above
again — most of this catalogue was re-published within the last week, so a pin chosen today is hours
old, not months.
