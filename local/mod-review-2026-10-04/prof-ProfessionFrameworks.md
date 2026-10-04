# Dedicated profession frameworks — 2026-10-04

## Decision summary

**Neither candidate can be THE requested profession system or replace ImpactfulSkills/BlacksmithingExpanded/Herbalist.** Aeres is genuinely a unified profession UI, but its progression is independent character-custom-data XP, never vanilla Skills; death/WAP do not touch it. It also permits only one active profession and has no quality or profession-exclusive recipes. Artisan Mastery is misleadingly named for this purpose: it is a profession-themed **equipment/content collection**, not a profession-level framework. It contains no profession XP, skill registration, profession choice or level-dependent crafting gates.

Recommendation for this slice: reject both as profession owners. Preserve the current owners provisionally while the other slices establish a better complete stack; do not install Aeres alongside them. Artisan can be considered separately as ship/decor content, but not as a profession solution and not under an unqualified non-combat label.

## Evidence scope and reproducibility

Downloaded and decompiled actual Thunderstore binaries: Dreanegade/Artisan_Mastery **1.0.6** (latest Thunderstore version, updated 2026-10-03 22:45 UTC), Aeres/AeresProfessions **0.1.0** (updated 2026-09-20 20:29 UTC). Primary metadata: https://thunderstore.io/api/experimental/package/Dreanegade/Artisan_Mastery/ and https://thunderstore.io/api/experimental/package/Aeres/AeresProfessions/ . Actual distribution URLs: https://thunderstore.io/package/download/Dreanegade/Artisan_Mastery/1.0.6/ and https://thunderstore.io/package/download/Aeres/AeresProfessions/0.1.0/ .

Workspace `/tmp/lembitu-prof/ProfessionFrameworks/`: `artisan.cs`, `aeres.cs`, unpacked READMEs/changelogs, metadata, zips, author catalogue. ILSpy command used `~/.dotnet/tools/ilspycmd -r lib/valheim -r lib/bepinex <DLL>`. SHA256 DLLs: Artisan `24c319f1b47d25efbfe0191996cafa68aa47918967097170fb87e69e10886e0e`; Aeres `184aa53f9f3b71f238ba3e803919db68b76a782364e58d0d58c9097abc0d3aea`.

Executed `scripts/screen-bundled-libs.sh --dir /tmp/lembitu-prof/ProfessionFrameworks`: **clean: no stale game-member reference found in 2 library(ies)**. This is a static reference screen, not Valheim execution or proof of multiplayer correctness. No repo edits, deployment or project-wide tests.

Citation shorthand below: `A` = `/tmp/lembitu-prof/ProfessionFrameworks/aeres.cs`; `D` = `/tmp/lembitu-prof/ProfessionFrameworks/artisan.cs`; `AR`/`DR` = respective unpacked `aeres/README.md` and `artisan/README.md` in that workspace. These are decompiled distribution evidence, not upstream source.

## 1. AeresProfessions 0.1.0

### Full profession/reward map

E = efficiency; Q = tradeable quality; R = profession-level-exclusive recipes; C = convenience. A personal buff to food the eater consumes is not tradeable food quality.

| Its profession | Owner's pillar | E | Q | R | C | Observed effect / XP |
|---|---|---|---|---|---|---|
| Miner | Gathering (mining) | yes | no | no | no | Pickaxe damage to MineRock/MineRock5; XP proportional to modified hit damage (A:210-235,443-449) |
| Woodcutter | Gathering (woodcutting) | yes | no | no | no | Chop damage to TreeBase/TreeLog; damage XP (A:238-263,443-449) |
| Hunter | Outside non-combat pillar | no non-combat reward | no | no | no | Direct creature/monster damage multiplier; XP from attacks (A:266-285) |
| Farmer | Farming | yes | no | no | no | Double harvest chance on hardcoded crops/forage; harvest/plant XP (A:288-325,421-425) |
| Blacksmith | Smithing | yes | no | no | no | Chance to refund all consumed materials at forge-like stations (A:108-150,174-193) |
| Alchemist | Alchemy | yes | no | no | no | Same refund perk, cauldron/mead station name match; crafting-cost XP (A:108-150,174-193) |
| Mason | Extra building profession | yes | no | no | no | Refund stone construction/stonecutter resources; Stone/BlackMarble/Grausten name list (A:159,174-203) |
| Mariner | Exploration/travel; fishing activity folded in | yes travel | no | no | yes travel | Sail force bonus only, no fishing perk; sailing XP and catching-fish XP (A:368-418) |
| Tavern Keeper | Cooking | no production efficiency | no | no | yes personal | Longer food duration for the active profession's eater; crafted food/cooking collection XP (A:174-180,327-365) |

**Animal handling completely absent. Fishing has XP but no fishing-specific reward. Exploration radius and hauling absent.** Profession enum and descriptions are exhaustive (A:1065-1138); README agrees (AR:9-21).

### Specialisation and WAP

Exactly one active profession: active name at `Professions.Active`; separate XP per profession at `Professions.XP.<type>`. Switching defaults true, has no cost/cooldown, but only the active profession earns XP and supplies perks. Setting `AllowSwitching=false` changes this into a permanent first-choice class (A:567-595,626-658). With switching allowed, players can level them serially, but never receive all their learned profession rewards simultaneously; this is not the requested open vanilla-skill model.

XP is a long string in `Player.m_customData`; levels derive from `BaseXp * (level-1)^1.6`, default max 50. No Skills integration (A:598-658). WAP iterates `Skills.m_skillData` on death and patches `Skills.Skill.Raise` (existing decompile `/tmp/lembitu-research/ProgressionCluster/VentureValheim.Progression.cs:3187-3239`). **Aeres XP is outside both paths and survives the skill drain untouched.** This is observed structural incompatibility, not a speculative patch conflict. README explicitly says vanilla skills level separately and progress lives on the client (AR:48-62).

### Config and combat leakage

Gameplay progression/perk/rule entries carry Jotunn `IsAdminOnly=true`; menu key/hint are ordinary local entries (A:500-523). README claims server syncing through Jotunn, and server install is needed (AR:29-50). [INFERENCE] Standard Jotunn config synchronization provides the advertised lock; a live malicious-client enforcement test was not performed. Same Pack policy can require installation despite the author's client-optional design.

Hunter adds direct non-player creature damage. There is **no Hunter-specific switch**: `Perks.PercentPerLevel=0` disables Hunter damage but also disables Miner and Woodcutter's only perks, because all three share that factor (A:507,641-648,1079-1085). `AllowSwitching` does not remove Hunter from the menu. No acceptable independent combat-off switch exists. Tavern Keeper changes duration, not immediate food stat magnitude, and its advantage stays with the eater, not the cook's sold product (A:344-365).

### Code quality/maturity

Small (~1140 lines) understandable prefix/postfix implementation; no transpilers. Null/local-player guards around attack and sailing paths (A:433-470); finalizers clear crafting/building mode even if the original throws (A:68-106). Native character-custom-data persistence avoids a separate file format but has no schema/version/migration or death policy (A:561-639).

Concrete issues visible in code:
- Harvest postfix grants XP/bonus solely from pre-interaction state, **does not check successful original result**; same issue for cooking collection and PlacePiece (A:291-340). [INFERENCE] failed/full-inventory/rejected interaction can reward unsuccessful work.
- Refund and double-harvest `Inventory.AddItem` return values ignored (A:136-149,304-309). [INFERENCE] full inventory can lose the advertised bonus rather than dropping it.
- Station identification is substring matching on `m_name`, not prefab identity; modded/custom stations can be misclassified or excluded (A:74-77,174-203); README acknowledges this (AR:59-60).
- XP multiplier zero still grants at least 1 XP due to `Math.Max(1, Round(...))`; config has no acceptable-value bounds (A:520-523,631-632). Negative/zero BaseXp and arbitrary MaxLevel can distort levels; long-term arithmetic overflow has no guard (A:598-632).
- Level calculation repeats up to MaxLevel and reparses strings on hot damage/perk/XP calls (A:616-648); bounded default 50 is modest but needlessly repeated work.
- Repeat suppression remembers only one touched instance for 0.75s, not authoritative successful actions (A:427-460).

One released version 0.1.0, young code and no observed release history establishing long-term maintenance. Do not mistake the clean stale-reference screen or neat UI for mature reward semantics.

### Overlap

ImpactfulSkills shares `Player.ConsumeResources`, `InventoryGui.DoCrafting`, `CookingStation.OnInteract`, `Pickable.Interact`, MineRock/MineRock5 damage, TreeBase/TreeLog damage, `Ship.GetSailForce`; references in `/tmp/lembitu-research/ProgressionCluster/ImpactfulSkills.cs:969,4006,4033,5873,6328,6427,7521,8128,8137`. Efficiency/extra harvest/sailing perks therefore stack, with two independent XP systems. Its quality-ingredient consumption transpiler at :969 also means Aeres resource refunds should not be assumed to preserve consumed ingredient quality.

BlacksmithingExpanded also patches DoCrafting (:3814,3955 in `/tmp/lembitu-research/ProgressionCluster/BlacksmithingExpanded.cs`); Aeres provides only refunds, not a replacement for its crafted-item enhancements. Herbalist shares DoCrafting and Pickable.Interact (`/tmp/lembitu-research/ProgressionCluster/Herbalist.cs:1553,1567,1680`), but Aeres supplies no herbalist recipes or skill gate. ExpertExplorer map progression has no direct Aeres map target overlap (`/tmp/lembitu-research/ProgressionCluster/ExpertExplorer.cs:1101-1189`); Aeres lacks its radius/biome/map features. Exact combined patch execution/order was not exercised.

## 2. Artisan Mastery 1.0.6

### What it actually is

README calls it the shared resource/building/peaceful-gear/shipbuilding core for the Distant Origins collection (DR:53-82,103-125), listing **Miner, Plague Doctor, Sailor sets**, not a full skill list (DR:111-115). Decompile confirms three equipment/status-effect families, with conditional rules based on equipped pickaxe, proximity to a ship, or low health (D:16754-16781). Registration is standard prefab/station/material recipes (D:28943 onward; representative dual picks/healing syringe/bomb at :29100-29145). There is no profession registry/XP storage/RaiseSkill/SkillManager registration in the full decompile. Skills.SkillType references are weapon classifications or equipment conditions, not profession progression.

| Theme/content | Eight-profession mapping | E | Q | R | C |
|---|---|---|---|---|---|
| Miner equipment/dual pickaxes | Gathering mining only | mining-oriented gear/fast horizontal digging (DR:113,143-146) | no skill-derived item quality | no profession gate | transport-oriented set claim (DR:113); exact asset stats unverified |
| Plague Doctor equipment, syringe, bomb, Doctor Desk | Alchemy theme, not brewing profession | no verified production efficiency | no | no profession gate | healing content, not a profession convenience ladder |
| Sailor equipment, Galleon, ship upgrades | Exploration/travel | upgrade-based ship performance (DR:174-198) | no profession quality | draught discovery gates, not skill gates | ships, cargo/storage/navigation systems |
| Shared fittings/wood/leather/thread, artisan workshop | Smithing/crafting content | no skill efficiency | no skill quality | material/station requirements only | no verified profession convenience |
| Food, Farming, Fishing, animals | No profession implementation | no | no | no | no |

All content is open to anyone who meets its ordinary recipe/station/resource requirements; no hard profession choice, but also no soft-specialisation investment. Gear benefits are owned by items/status effects rather than learned skills. WAP still drains normal skills, **but cannot drain these gear/upgrade-based benefits**. This fails the required profession investment/death contract; it does not actively replace WAP's skill patches. New recipes need explicit WAP biome mapping verification, not an assumption that custom stations inherit suitable personal-key gates.

### Server config and non-combat leakage

ServerSync with `General/Lock Configuration=On` by default; main helper adds synchronized entries (D:28062-28071,29231-29241). Independent Ships/Shipwrecks/Gear/Utility/Decor modules available. Generated item/piece settings off by default to avoid startup cost; enabling them exposes more tuning (D:28064,28117; DR:70-84).

It is **not combat-neutral**: sailor axe has hardcoded **+50% attack speed**, plague belt +15 health, sailor helmet +15 stamina, sailor armor wet immunity (D:2116-2121); attack speed hooks span StartAttack, UpdateAttack, fixed-update, stagger, death, FreezeFrame (D:1760-1992). Plague set activates another status effect below 25% HP (D:16773-16779). Cannon upgrade explicitly adds naval combat (DR:202-204); healing syringe and plague bomb are registered weapon-like items (D:29130-29145; friendly-melee exception :18548-18642). Exact armour/damage/resistance numbers in Unity assets remain unverified.

Coarse `Gear=Off` removes listed profession gear/Doctor Desk recipes, destroying the profession-themed payoff; `Ships=Off` removes ships/upgrades/cannon ammunition (D:8251-8268,8329-8344). `Enable Cannon Owner` only controls attribution, **not cannon disabling** (D:28092-28093). No fine non-combat-only/attack-speed-off switch observed. Notably `AxeSailor_DO` is absent from the GearItems disable list even though its hardcoded speed entry exists (D:8264-8268 versus :2120): [INFERENCE] Gear=Off alone should not be relied on to remove every combat-bearing item without a live recipe/asset check.

### Code quality/maturity

Substantial bespoke ship systems rather than a lightweight skill framework. Good signs: weak-table per-entity runtime state, compiled indexed conditional rules, 0.25s fast/0.75s spatial intervals (D:16697-16713), owner-aware persistent ship/container IDs and recovery lookup (D:10223-10225,10426-10463). ServerSync and ItemManager/PieceManager are embedded; their network patches are not bespoke profession bugs.

Risks: broad combat animation patch footprint, reflective dynamic targets, stock PieceManager UpdateAvailable IL rewrite (:4386,:4679), friendly-melee transpiler replacing PVP checks (:18548 onward), persistent ship/container systems with far larger failure surface than needed for this goal. Startup automatically recursively deletes previous sibling translation folders and sibling internal config files (D:13769-13810); real migration side effects, not just adding prefabs. Main-menu version-reset prompt also modifies configuration management (D:13338-13426). These are concrete maintenance concerns, not evidence of observed save corruption.

Seven Thunderstore releases since 2026-09-12; changelog records blocking, Eitr secondary-attack, Vulkan/shader/LOD, config-module and ship-furnishing fixes (`artisan/CHANGELOG.md:1-37`). Active recent maintenance, but young and still correcting combat/render/content issues. Author now says **new content primarily moves to Hexium**, Thunderstore retains occasional critical/compatibility fixes (DR:2-14). Therefore 'latest' here means latest Thunderstore; newer Hexium-only functionality is a coverage gap, not silently assumed equal.

### Overlap with current owners

Not a substitute for any profession skill owner. Direct stock target collision with BlacksmithingExpanded/ImpactfulSkills on `CraftingStation.GetLevel` (D:1386 versus BSE :3893 and Impactful :5377); its postfix only alters its dedicated stations, so collision is not automatically a conflict. ObjectDB registration and status/tooltip/combat hooks overlap broadly with Herbalist's content/status system, but no matching herbalist level gate is implemented. Ship navigation/map content overlaps conceptually with ExpertExplorer while not providing its exploration skill. Exact combined execution not tested. Replacing current profession mods with Artisan removes their learned rewards, leaving equipment/content progression instead.

## 3. Same-author packages

Primary catalogue queried: https://thunderstore.io/c/valheim/api/v1/package/ ; individual pages below. Catalogue coverage includes all listed Valheim packages for both authors as of this research. **Aeres has no sibling package in that catalogue.**

Dreanegade current siblings:
- [Hunter_Legacy](https://thunderstore.io/c/valheim/p/Dreanegade/Hunter_Legacy/) 1.1.5, updated 2026-10-01: ranged-combat equipment.
- [Magic_Supremacy](https://thunderstore.io/c/valheim/p/Dreanegade/Magic_Supremacy/) 3.1.3, updated 2026-10-01: magic expansion.
- [Historical_Heritage](https://thunderstore.io/c/valheim/p/Dreanegade/Historical_Heritage/) 2.1.5, updated 2026-07-12: historical armour/weapons.
- [Eternal_Legends](https://thunderstore.io/c/valheim/p/Dreanegade/Eternal_Legends/) 1.0.4, updated 2026-06-07: divine armour/relics.
- [TheShaperOfDistantOrigins](https://thunderstore.io/c/valheim/p/Dreanegade/TheShaperOfDistantOrigins/) 2.0.8, updated 2025-10-03: old crafting-station core; Artisan README explicitly describes the new shared-core restructuring (DR:53-82), so do not stack old core to 'complete' professions.
- [Historical_Arsenals](https://thunderstore.io/c/valheim/p/Dreanegade/Historical_Arsenals/) 2.0.1, updated 2025-09-10: historical armour/weapons.
- Older ADO_Demon_Hunter, ADO_Nightbound, ADO_Anubis, ADO_Horus (July 2025), ADO_Plague_Doctor (July 2025), ADO_Bashrad (July 2025), ADO_Samurai, ADO_Daowei, ADO_Gunjang (May 2025): catalogue descriptions are gear sets, not cooking/farming/fishing/animal skill systems. Pages follow `https://thunderstore.io/c/valheim/p/Dreanegade/<name>/`.

**Source claim, not binary verification:** sibling catalogue descriptions establish theme and update dates, not code quality. None advertises the missing peaceful skill professions. No sibling was decompiled; no evidence justifies installing combat siblings under Oathbound to complete this pillar. Artisan's actual shared conditional-system registry and MagicSupremacy optional prefab references demonstrate sibling integration (D:16690-16740,8286-8324), but thematic consistency does not create skill progression.

## 4. Proposed cohesive stack for this slice

This is a **provisional ownership proposal, not a claim the pack already satisfies all criteria**. It intentionally assigns exactly one owner per profession and excludes the two researched candidates. More detailed switch/reward verification for retained mods belongs to the corresponding sibling slices; unverified reward cells marked explicitly rather than inventing coverage.

| Profession | Exactly one proposed owner | Reward kinds evidenced here | Switches/ownership boundary | Gaps |
|---|---|---|---|---|
| Smithing | BlacksmithingExpanded | [INFERENCE] E/Q from current dedicated owner; detailed slice needed | Keep Impactful Forging off; no Aeres | Non-combat quality boundary and profession recipes need sibling proof |
| Cooking | ImpactfulSkills | E/C settings and cooking patches observed (:555-556,:4006-4033) | Cooking on; no Aeres Tavern Keeper | Tradeable Q and R need recipe/quality slice |
| Farming | ImpactfulSkills | E/C (:596-624) | Gather/AOE/multiplant/growth timer; no Aeres Farmer | Q/R not evidenced; **client gameplay-adjacent planting/snap settings exist**, resolve pack-lock interpretation |
| Alchemy | Herbalist | [INFERENCE] skill/recipe content owner, detailed slice needed | No Aeres Alchemist; no Artisan plague combat gear | Non-combat potion switches and four rewards need sibling proof |
| Gathering | ImpactfulSkills | E damage/loot patches (:6328-6436,:8128-8182) | Mining/woodcutting sole skill owner | Q/R not evidenced here |
| Fishing | ImpactfulSkills | [INFERENCE] retain existing core ownership pending slice | No Aeres Mariner split; content-only fish mods not a second skill owner | Full E/Q/R/C and fishing settings not investigated here |
| Animal handling | ImpactfulSkills | E honey/tame/slaughter; Q stars; C biome bees (:580-595) | Animal/bee on; disable bonus-star if combat tames violate Oathbound boundary | R absent in evidence |
| Exploration/travel | ImpactfulSkills | E/C sailing/radius/hauling (:557-559,:625-639) | Sole skill reward owner; do not double radius/sailing with another owner | Q/R absent; ExpertExplorer/Njord become content/UI only or leave stack |

Specific new cross-slice concern: ImpactfulSkills `FarmingMultiPlantDistanceBufferModifier`, buffer-space, snap-distance/style and snapping options are **BindClientConfig** (:613-620), unlike server-owned reward levels. Whether these count as forbidden per-player gameplay settings must be resolved before calling even this fallback acceptable. This report does not bless them.

## Coverage gaps

No live Valheim/client/server session was launched; no save roundtrip, full-inventory bonus, death/switch scenario or combined Harmony execution observed. Static code makes Aeres' independent XP incompatibility decisive without runtime. Artisan embedded Unity asset numerical stats and exact disabled-item visibility were not extracted; no precision claims about those values. Hexium-only newest versions and sibling binaries were not inspected. Retained-current-mod table is deliberately provisional and not a replacement for their dedicated analyses. No missing evidence can turn either downloaded binary into the specified eight-profession, vanilla-Skills, four-reward system: their observed progression model already rules that out.
