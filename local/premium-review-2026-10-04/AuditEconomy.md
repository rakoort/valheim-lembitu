# Professions, economy and guild progression audit

## Summary

1. **Three players can cover all eleven professions already.** The quota-aware minimum is three, not four: 6 Land slots cover 5 professions, 3 Craft cover 3, 3 Road cover 3. Guilds of 3–5 have no structural need to buy from another guild. Keep the soft-specialization design, but describe trade as comparative advantage/availability, not enforced interdependence.
2. **SeedBed bypasses Farming's level-60 biome-freedom reward.** Its processing station has no biome restrictions and neither the ladder nor WAP's disabled building lock governs it. Remove it before world creation, or explicitly abandon exclusive high-level biome freedom; changing PlantEverything alone does not close this hole.
3. **The ladder is intentionally not comprehensive.** `BH_RunnerElixer`, `SA_Sadle`, ship materials, glass conversion and EpicLoot custom material operations are uncovered. Many are valid Meadows/building exceptions, not progression exploits; Herbalist late-biome tonics are profession-gated but their modded materials are not WAP boss-key mapped.
4. **Guild level 20 currently costs 273,556 XP; level 30 costs 2,580,939.** A one-month run is likely to see the expensive Plains comfort upgrade locked by guild XP long after its materials arrive. Propose `LevelXpGrowth = 1.15`, retaining base 1000 and max 30; level 20 then costs 88,211 XP. Timing still requires activity measurements.
5. **Guild upgrades are a substantial finite coin sink: 42,100 coins per fully upgraded guild**, before donations and NPC/enchanting purchases. At 50 coins/XP, donations are mostly a token sink, not a plausible route to major guild advancement. Propose `DonationCoinsPerXp = 10`, keep Market fee 5%, and do not increase coin rewards until measuring liquidity.
6. **EpicLoot bounties mint 25–650 coins in pre-Fader biomes, outside Marketplace's fee.** Market bounties only redistribute player escrow. There are ample optional coin sinks; no defensible unconditional inflation/starvation verdict exists without actual mint/spend/hoarding rates. Early shortage and late optional-surplus coexist are the likely pattern [INFERENCE].
7. **Backpack weight halving plus quality-scaled carry bonuses undermine Hauling more than CraftyBoxes' 20 m radius.** Keep the radius; make backpack `Weight Multiplier = 1` and `Carry Bonus = 0` on all six normal tiers so backpacks own slots, Hauling owns mass/cart efficiency. Local-only backpack crafting automation is an additional Pack-rule issue.
8. **Craft specializations are commercially stronger than Land/Road**, and specialists only diverge substantially after level 30. Cooking's bonus threshold 40, Farming AOE 40/biome 60, Animal Handling quality 70 and Mining whole-vein 70 may arrive late in a 50–60 h run. Do not promise all master perks by Fader; first measure earned levels and work-hours rather than flattening every threshold.

## Scope and evidence

Read-only source/config audit; no game, server, build, tests, deployment or repo configuration edits. Only this handback was written; new decompiles are scratch. Versions: ImpactfulSkills 0.21.0, Herbalist 1.5.0, BlacksmithingExpanded 1.2.4, ExpertExplorer 1.7.0, Guilds 1.2.2, Marketplace 1.4.0 (`M/Plugin.cs:11`), EpicLoot 0.14.13, AdventureBackpacks 2.2.5, TheFisher/SeaAnimals 0.3.9, OdinShip 0.8.7, GlassPieces 1.2.8, PlantEverything 1.21.3, SeedBed 1.2.9, SaunaMod 2.1.0. Findings are static observations; predicted experience and policy proposals are [INFERENCE]. Shared assumption: 8 players × 50–60 player-hours, guilds 3–5. No forced-trade change is authorized by this report.

Primary-source abbreviations:
- **G** `/tmp/lembitu-research/GroupsWorldCluster/Guilds-code/Guilds/`.
- **M** `/tmp/lembitu-research/GroupsWorldCluster/Marketplace-code/Marketplace/`.
- **P** `/tmp/lembitu-research/ProgressionCluster/`.
- **W** `/tmp/lembitu-research/GroupsWorldCluster/WAP-code/VentureValheim.Progression/`.
- **E** `/tmp/lembitu-premium/AuditEconomy/EpicLoot/EpicLoot.config.adventuredata.json` (embedded in pinned DLL, extracted here).
- **B** `/tmp/lembitu-premium/AuditEconomy/AdventureBackpacks.cs` (pinned DLL decompile).
- **R** `config/enforced/ItemRequirement/radamanto.ItemRequirement.professions.yml`.

## 1. Focus-slot coverage: there is no missing guild profession

Evidence: `src/plugins/Lembitu.Callings/Professions.cs:29-61` defines five Land, three Craft, three Road and quotas 2/1/1. `config/enforced/adrian.valheim.guilds.cfg:27-42` caps members at five and disables member upgrades through level 99.

| Guild players | Total focus slots | Land slots / 5 types | Craft slots / 3 types | Road slots / 3 types | All 11 coverable? |
|---|---:|---:|---:|---:|---|
| 3 | 12 | 6 | 3 | 3 | Yes, with one duplicate Land |
| 4 | 16 | 8 | 4 | 4 | Yes; five surplus slots |
| 5 | 20 | 10 | 5 | 5 | Yes; nine surplus slots |

Concrete 3-player cover: A Mining + Woodcutting / Smith / Hauling; B Farming + Fishing / Cooking / Sailing; C Animals + any Land duplicate / Herbalist / Exploration. This proves feasibility; it does not mean each person can train four focuses to mastery in one month. Overlap, absence, time, geography and unequal stockpiles still create comparative advantage.

The ladder makes **a specialist somewhere** an efficient supplier; it does not make **a different guild** that supplier. Non-focus skills also remain open: `lembitu.callings.cfg:13-20` has full rate through 30, half through 60, quarter through 80, tenth thereafter, not hard locks. All Black Forest/Swamp/Mountain 10/20/30 craft gates are reachable at full rate by anyone. Raising late gates alone cannot force cross-guild trade.

Proposal: retain four focuses and max five; make no invented `FocusSlots` config suggestion (quota is source-defined, not configurable). If mandatory cross-guild dependency is desired, it is a concept decision requiring different Craft/Road quota availability or exclusive product ownership; **not fixable by existing numeric settings** while every 3-person guild covers all three Crafts. Prefer friendly buy orders for absent specialists and surplus bulk goods over hard profession exclusivity. Confidence high arithmetic/source, medium actual trade prediction; Shakedown must log inter-/intra-guild trade volumes and reasons.

## 2. Coin flow sketch: NPC minting versus circulation versus destruction

### What actually moves money

| Flow | Supply effect | Evidence |
|---|---|---|
| Looted coins; NPC purchases of valuables | Mint/add spendable coins | Vanilla behavior; exact 1.0.16 rates and trader sale-value distribution not verified here |
| EpicLoot Haldor bounty completion | Mints `RewardCoins`; separate iron/gold **tokens are not Coins** | `P/EpicLoot.cs:55950-55951,56134-56152`; `E:302-395` |
| Marketplace sale/buy-order/player bounty | Transfers existing escrow/account funds minus floored 5% fee | `M/MarketServer.cs:704-705,1202-1205,1432-1435`; cfg line 6 |
| Depositing coins in Market/guild treasury | Moves/holds currency, not automatically a sink | Donation setting explicitly distinguishes destruction: `G/Plugin.cs:211` |
| Guild upgrade purchases | Destroys treasury coins; finite per guild | `G/Progress.cs:305-325`; enforced guild cfg:41-42 |
| Guild donation | Destroys 50 coins for 1 XP currently | enforced cfg:34; `G/Plugin.cs:211` |
| NPC necessities, EpicLoot stash/gamble/maps | Destroys coins | `E:6-36,87-260,265-273` |
| Some EpicLoot coin-powered effects | Conditional spend/hoarding incentive; not reliable economy-wide sink | Mercenary spend calculation `P/EpicLoot.cs:37549-37556`; not every build uses the effect |

**Do not tax EpicLoot bounty rewards in the model:** Marketplace's comment “bounty rewards” refers to its own player-funded board. EpicLoot gives Coins directly through `InventoryManagement.Instance.GiveItem`, not through Market payout. At 5%, transactions below 20 coins have zero fee because the code floors it. Five recirculations of a large principal leave about 77.4%, not a fee on all minted money.

Pre-Fader bounty rewards: Meadows 25–30; Black Forest 75–90; Swamp 150–170; Mountain 230–300; Plains 290–400; Mistlands 500–550; Ashlands 600–650 (`E:302-388`). RefreshInterval 7 is stock (`E:291`); Max Bounties Per Player = 5 limits concurrent jobs, **not lifetime/monthly completion** (`randyknapp.mods.epicloot.cfg:43-46`). Do not infer five per day or one bounty reward per party member without verifying those event paths.

Stock useful sinks: ordinary gambles about 100/400/600/999/1200/1500 coins per representative tier (`E:87-170`); treasure maps 100–700 through Ashlands (`E:265-272`); magic materials 5/25/100/300/600/1000 each by rarity and Andvaranaut 1998 (`E:6-36`). Buying enchanting mats from Haldor competes with buying player goods, so high rarity pricing is both sink and profession-market competitor, not free trade stimulus.

### One-month sensitivity model (illustration, not measured forecast)

Let `L` be loot+valuable sale mint, `B` completed EpicLoot rewards, `V` gross Market turnover, `N` NPC/adventure spend, `U` guild coin purchases, `D` donation coins. Change in **total minted currency still existing**, including balances/treasuries, is approximately:

`ΔC = L + B - Σfloor(0.05 × each Market payout) - N - U - D`.

Example: 8 players each complete 20 bounties at a weighted mean 250 = 40,000 coins; each completes 40 = 80,000. These are explicit assumptions, not predicted completion rates. With two guilds each buying ward 3000 and first comfort 3000, `U=12,000`; Market turnover 40,000 destroys about 2000; 8 players making ten 600-coin gambles destroys 48,000. The first scenario is already negative before vanilla mint; the second leaves 18,000 before loot, other purchases and donations. Thus “5% will keep coins valuable” is not a proof of balance.

Guild full-upgrade coin budget per guild: regen 6000; comfort **11,000** (enforced); ward **3000** (enforced); resilience 7800; production 7800; growth 5500; respawn 1000 = **42,100**, excluding point-only upgrades and donations. Two guilds 84,200; three 126,300. Players choose upgrades, so this is capacity for absorption, not mandatory month-one spending. After finite upgrades saturate, late Fuling/treasure/bounty income can accumulate [INFERENCE]; early necessities and ambitious upgrade buying can starve Market bids [INFERENCE].

**Proposal:** retain `[2 - Server] FeePercent = 5`; set Guilds `[4 - Progression] DonationCoinsPerXp = 10` (package default). At 50, 3000 coins buys only 60 XP, vs 1500 first-boss XP; at 10 it buys 300, still small and not pay-to-skip. Do not simultaneously increase NPC reward mint and upgrade costs. Pin `FulingCoinDropScale = 1.0` if authoring an EpicLoot adventure patch; no reward buff recommended. Confidence high mechanisms, low month forecast. Shakedown alone settles mint/hour, coins voluntarily donated, hoarded bank balances and rejected buy orders for lack of money.

## 3. Guild level curve and upgrades: long tail exceeds month pacing

Source: `G/Plugin.cs:200-211` defaults base 1000, growth 1.25, max 30, activity multiplier 1, first boss 1500, repeat 150, achievements 300/1000/3000. `G/Progress.cs:251-272` sums each successive requirement, rounded. Calculated from those expressions (arithmetic only, no runtime test):

| Target guild level | Stock 1.25 total XP | Proposed 1.15 total XP |
|---|---:|---:|
| 10 (ward) | 25,802 | 16,785 |
| 12 (first comfort) | 42,566 | 24,349 |
| 15 | 86,950 | 40,504 |
| 20 (second comfort) | 273,556 | 88,211 |
| 30 | 2,580,939 | 377,170 |

A 3-player guild has ~150–180 player-hours; five ~250–300. Stock level 20 asks ~912–1824 XP per player-hour, level 30 ~8603–17206. Seven first-boss bonuses total at most 10,500 per guild **if that guild receives all first-kill attribution**; shared boss fights do not establish that all guilds get it. Plugin explicitly calls repeat boss XP “last hit” (`G/Plugin.cs:207`); tracker uses `PlayerProfile.IncrementStatEnemy` (`G/StatsTracker.cs:43-49`). Boss presence/key ownership is not automatically guild XP ownership.

Activity examples: trees 2 XP, ore 2, crafts 1, cooking 1, crops .5, fish 5, taming 15, travel .002 per walking unit (`G/Progress.cs:153-213`; stat definitions/achievements :33-50). Bulk gathering, crafting and collection can dominate; level cannot be predicted from clock time alone. Seventeen gold achievement tiers yield 51,000 XP if all achieved, but many thresholds (15,000 kills, 50,000 building placements, 5,000,000 travel) are not realistic month-one assumptions (`G/Progress.cs:33-50`).

**Proposal:** `[4 - Progression] LevelXpBase = 1000`, `LevelXpGrowth = 1.15`, `MaxLevel = 30`, `ActivityXpMultiplier = 1`; retain ward L10, comfort L12/L20 and materials. This keeps guild level relevant all month without pretending every upgrade should cap by Fader. At 1.15, second comfort asks about 294–588 XP/player-hour. Avoid raising activity multiplier first: it also amplifies cheap-craft/build behavior without fixing exponential tail. All are server-owned settings (`adrian.valheim.guilds.cfg:1-2`). Confidence high formula, medium proposal; calibrate expected level at Eikthyr/Elder/Bonemass/Moder/Yagluth/Queen/Fader in Shakedown.

Guild regen (+5/10/15%) overlaps general combat progression; production (+5/10/15%) overlaps smith processing; growth (+10/20/30%) overlaps farmer efficiency (`G/Progress.cs:310-315`). These are modest **guild perks**, not new individual professions; keep for now but count them when measuring mastery yields. Monsterward removes raids inside claim as explicitly intended; not an exploit finding.

## 4. Gate coverage: separate intended exceptions from actual holes

The generator classifies output type/name, maps **direct materials only**, skips rung zero, and never recursively derives material tiers (`scripts/generate-ladder.py:65-110,121-135`). WAP allows unknown material names (`W/KeyManager.cs:1422-1432`) and only has native food/material mappings; no BH/TF/silica/EpicLoot custom materials occur in those lists. Build pieces are outside Item_Requirement DoCrafting gate (`/tmp/lembitu-prof/RecipeGatesAndQuality/rad.cs:681-703`); WAP building and taming are deliberately off (`com.orianaventure.mod.WorldAdvancementProgression.cfg:48-54`). **Do not solve this by turning LockBuilding on for the whole pack**, which would reverse the explicit builder/repair rule.

| Content / exact items | Ladder coverage | WAP coverage and verdict | Proposal |
|---|---|---|---|
| Herbalist `BH_MinorHealthTonic`, `BH_MinorStaminaTonic`, `BH_MinorEitrTonic`; Medium/Large equivalents | Covered at 10 / 30–40 / 50 (`R:147-166`) | BH herbs not native WAP mappings; profession gate can stop novice production, not prevent a high-skill keyless alchemist making/using later herb products | Add personal-key mappings/integration before calling them biome boss-locked; ingredient profession overrides alone are insufficient. No supported arbitrary-material WAP CFG extension found; do not invent one |
| `BH_RunnerElixer` (Swift) | **Absent**; all ingredients Meadows -> rung zero | Unknown BH ingredients, no boss-key gate | Intentional Meadows utility at speed1.2 is defensible; record exemption rather than claim “all eight elixirs on ladder.” If premium focus supplier wanted, explicit `PrefabName: BH_RunnerElixer`, Herbalist Level40, BlockCraft true, BlockEquip false, EpicMMO false; this would be a policy exception, not biome-derived |
| `Dandelion`, `Thistle` recovery consumption | Neither crafted product nor ladder rule | Base recovery food/material checking needs gameplay proof; Herbalist consumption patches modify them (`P/Herbalist.cs:224-253,1743-1747,2187-2200`) | Keep low-tier recovery; do not gate raw plant picking behind alchemist. Recovery strength is consumer-owned, not premium producer quality |
| SeaAnimals `SA_Sadle` | Classified in generator but skipped rung zero; **absent** | Wood2 + DeerHide5, workbench1 (`/tmp/lembitu-grill/MasterRecipes/SeaAnimals/code.cs:898-905`); no meaningful WAP gate | Meadows marine mount saddle is an intentional early option or a strong utility exception. If mount specialization desired, explicit Animal Handling40 recipe gate, not invented later-biome ingredient inference; assess mount safety vs sailing in game |
| TheFisher `TF1Amberjack`, `TF2BrownTrout`, `TF3AtlanticCod`, other TF fish; `TFCrab` | No TF rules | Unknown custom pickups; conversion to `FishRaw` has ordinary raw-fish output. Aquarium/feed is decorative, not production | Keep decorative fish open; do not fake profession gating wild catch with recipe YAML. Verify Raw Fish yield/food economy (`TheFisher/code.cs:953-1049,889-895`; README:24-38) |
| `TheFisherTank_v1`, `TheFisherTank_v2`, fish trophy pieces | None, build pieces | Building lock off even with Crystal10. Not gear progression | Intentional decoration exception; keep. README:112-113 confirms FineWood40 Resin10 Crystal10. No blanket biome gate needed |
| OdinShip `MercantShip`, `CargoShip`, `BigCargoShip`, `RowingCanoe`, `DoubleRowingCanoe`, `LittleBoat`, `WarShip` | None, build pieces | All outside disabled building lock; ordinary material possession is only barrier, and traded iron nails can feed keyless building | Deliberate building exemption, but large cargo/war ships need an explicit Sailing supply hook if they are to reward sailors, not a claim ItemRequirement already covers boats |
| OdinShip `ResinWood`, `CaulkedWood`, `ClothShip`, `ShipRope`, `FishExtract` | Absent, material outputs outside profession classifier | Most use Meadows/BF raw resources. Intermediate product names lose recursive tier information | Optional explicit Sailing40 `CaulkedWood` craft gate as premium shipwright supply; leave rope/canvas/basic resinwood open. Avoid gating all nautical basic access |
| GlassPieces `BGP_SilicaOre`, `BGP_Glass`, `BGP_SilicaCollector`, glass pieces | None | Glass is blastfurnace conversion, not InventoryGui recipe; collector/building off; silica unknown mapping | No combat tier bypass established. Pin GlassPieces `[2- General] Use Smelter = Off` to preserve its stock Plains-furnace production; keep silica pickups On. Building glass still intentionally open if supplied |
| SaunaMod `sauna_stove`, `sauna_wrisks`, `sauna_bucket`; Well Steamed | None, pieces/status | Steam buffs ignore profession/key gating; bucket mead distribution may bypass ordinary EatFood ownership [UNVERIFIED] | Keep base recovery/social sauna; set `[Mead] DurationMultiplier = 1` instead of1.2 to avoid free boost competing with Herbalist. Verify keyless resistance via bucket before certifying boss-key coverage |
| PlantEverything `RaspberryBush`, `BlueberryBush`, mushrooms, saplings | None, cultivator/build placements | **Anywhere planting already closed** by EnforceBiomes=true, EnforceBiomesVanilla=true; intended Farming60 release remains | Retain both true. Actual custom-plant/ImpactfulSkills override interplay needs runtime demonstration; do not report already-fixed anywhere planting as present exploit |
| SeedBed `BSB_SeedBed`; e.g. Barley/Flax and mod herb conversions | None, build/processing | Explicit no biome restrictions; Ymir5/BronzeNails8/Wood18 construction (`SeedBed/code.cs:1293-1300`) does not add skill gates | **Remove SeedBed before launch world** or remove its biome-sensitive conversions through synced YAML. No actual biome/skill restriction CFG found; merely extending germination time does not fix reward bypass |
| AdventureBackpacks `BackpackBlackForest`, `BackpackSwamp`, `BackpackMountains`, `BackpackPlains`, `BackpackMistlands` | Covered Hauling10/20/30/40/50 (`R:169-178`); `BackpackMeadows` intentionally omitted | WAP checks direct normal recipe ingredients where mapped, not magical contained inventory. Customer equip has no profession gate, as intended | Retain gates; prove below/at threshold craft and upgrade with backpack automation. Do not call all backpacks uncovered |
| EpicLoot `ShardMagic/Rare/Epic/Legendary/Mythic/Ancient`, Dust/Reagent/Essence equivalents, Runestones/shardstones | Absent | Custom Enchanting Table operations and vendor sales are not profession DoCrafting; rarity is separate from boss gear tier | Keep EpicLoot owning rarity. Add earned-skill integration only if explicitly making smith the enchanter; YAML alone cannot gate custom convert/enchant actions. Gear equip WAP remains separate |

Sources for OdinShip chains: `/tmp/lembitu-research/BuildQoLCluster/Marlthon-OdinShip-0.8.7/OdinShip/OdinShip.dll.full.cs:3363-3577,3391-3394,3455-3458,3841,3901-4005`. Glass conversion and defaults: `/tmp/lembitu-premium/AuditEconomy/GlassPieces.cs:221-222,273-284,738-739,1039`. Sauna config and pieces: `/tmp/lembitu-research/BuildQoLCluster/SaunaMod/plugins/SaunaMod.dll.full.cs:282-293,1034,1887,2038`. SeedBed README:17-21 is explicit no-biome claim; code uses its own Germination, not Plant. PlantEverything cfg:8-10 is authoritative existing fix. All numeric rule proposals retain `BlockEquip=false`; customers should not need producer profession.

DataForge `items.yml`, `effects.yml`, `pieces.yml` are **comment-only templates**, not active overrides. They do not currently close any hole, create premium goods or modify coins. Citing example `value`, effect `raiseSkill`, recipe/plant fields as deployed balancing would be false. `pieces.yml:7-9` documents `remove:true`, useful for disabling a SeedBed piece before launch, but does not remove its world data or create a profession gate.

Confidence high for absence/type/exceptions; medium keyless late Herb use and sauna behavior until runtime. Only Shakedown can settle WAP/Harmony custom ConsumeItem and backpack crafting composition. The highest-consequence missing integration is **mod herbs versus personal boss keys**, not decoration.

## 5. Hauling versus local crafting and backpacks

`Azumatt.AzuCraftyBoxes.cfg:32-38` locks 20 m. That eliminates inventory shuffling **inside a workshop**, not forestry/mine-to-base shipping. Enlarged world and no metal portals still pay the hauler. Cutting to 5–10 m adds chest layout nuisance without reliably making inter-base transport more important. Keep `Container Range = 20`, `Leave One Item = Off`.

Backpack contents weigh ×0.5 by default: `B:6143-6151`; formula `B:2911-2935` adds inventory weight × multiplier. CarryBonus defaults are 5/10/15/20/25/30 for Meadows through Mistlands (`B:6363-6364,6410-6411,6461-6462,6511-6512,6563-6564,6616-6617`) and **multiply by quality** (`B:6181-6189`). At quality4 a Mistlands pack supplies +120 capacity before halving its cargo, exceeding Hauling's +100 at skill100 (`MidnightsFX.ImpactfulSkills.cfg:105-106`). Capacity/quality example is arithmetic; no claim all quality4 recipes are reached by Fader.

**Exact proposal**, repeated for sections `[Backpack: Satchel]`, `[Backpack: Rugged Backpack]`, `[Backpack: Bloodbag Wetpack]`, `[Backpack: Arctic Sherpa Pack]`, `[Backpack: Lox Hide Knappsack]`, `[Backpack: Explorers Wisppack]`:

```
Weight Multiplier = 1
Carry Bonus = 0
```

Section construction is `B:6005-6006`; English translated item names `dist/plugins/AdventureBackpacks/Translations/AdventureBackpacks.English.json:2-13`. Those numeric entries are `SyncedConfig`, so enforceable. Backpacks then sell slots and tier utility, Hauling capacity and cart efficiency; non-haulers can still buy high-tier packs, an intended trade benefit. If too harsh in Shakedown, try multiplier0.85 but **not** restore large quality-scaled carry simultaneously.

Pack rule caveat: `[Automation (Local Only)] Enable Craft From Backpack`, craft-output placement and auto-store are `UnsyncedConfig` (`B:3760-3778,4296`). Initial same file values do not enforce equality. They affect gameplay convenience/material reach, not merely color/keybind. Disabling in an overlay alone does not resolve rule; needs upstream lock/accepted classification or reject that version. DoCrafting/ConsumeResources/GetWeight/inventory patch overlap with CraftyBoxes, EpicLoot and ItemRequirement remains a combination acceptance surface, not a demonstrated break.

Confidence high arithmetic and lock scope; experience/trade effect Shakedown-only.

## 6. Profession balance and downtime

Current owner intent matters: do **not** resurrect earlier research's “combat all off” proposals. Smith gear bonuses, Animal stars and tempered Herbalist fight elixirs were deliberately accepted in current configs. Likewise old bundled-manager death warnings are addressed by current `SkillHooks.cs:105-150`; not a new unfixed finding.

| Profession | Work through month / likely trough [INFERENCE] | Why focus pays or fails |
|---|---|---|
| Mining | Sustained ore demand with downtime between metal tiers | Level40 crit/50 AOE/70 whole-vein, scaled yield. No sellable exclusive raw ore identity |
| Woodcutting | Sustained base/coal/ship demand; less mandatory endgame forestry | Continuous x1.67 yield /x1.5 chop at100, no premium craft gate; duplicate Land slots likely land here |
| Farming | Food supply repeated; early small carrot plot before major crops | AOE/multiplant40 and biome60 too late if SeedBed hands everyone alternative anywhere production |
| Fishing | Catch/food/decor demand, optional versus land food | Fishing bonus linear1.25 extra at100, bait ladder and ingredient quality; novice gets whole activity before focus difference grows |
| Animal Handling | Big initial taming/breeding, potentially quiet after herd established | Honey and slaughter repeat; star70 late, continuous tame/yield bonuses. Guild should order recurring food/honey rather than call tames sufficient recurring trade |
| Blacksmithing | New gear/repair/upgrade batches every biome; uneven bursts but most indispensable Craft | Gated armorer + producer-stamped bonuses; player crafting demand reaches everyone |
| Herbalist | Boss prep and repeated tonic/mead/elixir production | Broad consumables +1.5 bonus output100; consumer duration scaling weakens producer identity but explicit tonic tiers remain sellable |
| Cooking | Repeated food demand throughout, directly shared output | Bonus threshold40 means focus feels little distinct production early; eater-side degradation is not superior master-made food |
| Exploration | New islands/biomes throughout huge world, then falls when local routes known | Radius100→250, personal maps. Information not a normal item sale; no ladder exclusive recipe |
| Sailing | Large travel bursts; dormant during inland nights | Crew/row/headwind bonuses40–70; rewarding transport services needs players actually aboard, not Market instant delivery |
| Hauling | Mining/build nights always useful unless backpack mass dominates | Capacity/cart and backpack craft ladder; remote Market itself can substitute for physical delivery |

Perk thresholds/effect magnitudes source: enforced ImpactfulSkills cfg:54-80,105-115; Callings cfg:25-27; Explorer cfg:7-8; smith cfg:25-47; Herbalist cfg:26-62. Generation classification contains exclusive goods only for Smith/Cooking/Herbalist/Fishing/Animal saddles/Hauling backpacks/Scythe Farming (`scripts/generate-ladder.py:65-85`); it does not make eleven equivalent market-maker professions.

No defensible obvious-best conclusion without XP/work-hour and output measurements. Craft quota guarantees a three-player guild one of each commercially essential craft and Road one of each service: this is internally cohesive. Largest economic asymmetry is **Craft merchandise versus Road service**, not smith's modest +10% damage alone. NPC gambles/material stash and remote Marketplace are overlapping sources/distribution systems; do not add more loot/teleport economies casually.

Proposal: retain current curves/bonus magnitudes initially after fixing SeedBed/backpack overlap. If a full month sample fails to reach Farming60/Animal70/Mining70 despite deliberate focused work, tune that profession's XP rate, not globally shift Callings Band1End to40 (that erases specialization onset). No exact XP increase recommended without actual work-event rates. Keep HerbalistExtraAt1001.5, FishingExtraAt1001.25 and ExpertExplorer MaxExploreRadius250. These are existing deliberate tuning, not missing pins. Confidence medium role prediction; master-perk arrival is Shakedown-only.

## Ranked actionable proposals

1. **Pre-world cutover:** remove SeedBed, or remove its biome-sensitive conversions from synced YAML; no `EnforceBiomes` key exists in inspected SeedBed. This is the clearest reward-ownership bypass.
2. **Hauling ownership:** all six backpack sections `Weight Multiplier=1`, `Carry Bonus=0`; retain CraftyBoxes range20 and HaulingMaxWeightBonus100. Resolve local gameplay automation lock before certifying Pack.
3. **One-month guild curve:** Guilds Progression `LevelXpGrowth=1.15`, base1000/max30/activity1; retain materials and level requirements. Gate stage timing measured before adoption.
4. **Coin donation utility:** `DonationCoinsPerXp=10`; fee stays5. Do not buff bounty coin mint simultaneously. The current50 makes donations economically irrelevant relative to upgrade/NPC spending and earned activity XP.
5. **Recovery overlap:** Sauna `[Mead] DurationMultiplier=1`; pin GlassPieces `[2- General] Use Smelter=Off` (existing default) rather than accidentally opening early glass processing on an upstream default flip.
6. **Coverage policy:** explicitly decide Meadows exemptions `BH_RunnerElixer`, `SA_Sadle` and optional Sailing40 CaulkedWood supplier. If gated, add the exact result-prefab rules above **through generator policy**, not hand-edit generated R; no build-piece YAML illusion.
7. **Boss-key composition:** extend personal-key handling to mod herb outputs/materials through an actual supported integration. No verified config-only arbitrary mapping path; do not advertise late tonics as WAP-locked until proved. Keep ordinary decorative building and repair open.
8. **Honest trade goal:** keep 4 focuses; remove any claim that 3–5-player guilds cannot cover all11. Choose whether trade is optional comparative advantage or mandatory dependency before new profession/product systems.

## Gaps

- No live process per read-only contract: all source conclusions need combination acceptance for crafting prefixes, WAP custom consumables, sauna bucket effects, PlantEverything/ImpactfulSkills custom-biome release, Market metadata round-trip and backpack-contained prohibited-metal portal checks. No runtime compatibility claim made.
- Monthly economics has no measured valuable/coin loot yield, trader sale mix, Fuling rate, bounty completion frequency, gambling/stash demand, treasury savings or velocity. Exact native 1.0.16 trader purchase/sale table was not decompiled here; no invented price schedule used. Mint/destruction identity and reward tiers are verified, net forecast is not.
- `PerkThresholds/` is present but contains no files in available scratch; current enforced config and reused decompiles supplied thresholds. Historical handbacks were reused only as pointers, not authoritative over today's fixed code/config decisions.
- Native ObjectDB dump referenced by ladder SHA is not in inspected repo paths. Missing R entries are verified directly against current generated rules and generator classification; full live recipe catalogue/version drift must be exported on the accepted pack. This report does not infer source biome from TF1/2/3 names.
- WAP arbitrary custom-item material/key mapping config not found; ingredient overrides in generator are profession thresholds, not runtime boss-key enforcement. Exact integration design belongs to a separately authorized implementation.
- Guild last-hit attribution can skew rival guild levels on shared boss nights. Source proves tracker/default description, not whether other combat/stat patches grant participation counts. One cross-guild boss event with XP deltas settles it.
