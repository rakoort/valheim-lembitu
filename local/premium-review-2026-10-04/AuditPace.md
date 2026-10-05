# Progression pace audit — 2026-10-04

## Summary

1. **Guilds is the clearest month-length mismatch.** Stock level 20 requires 273,556 cumulative XP; level 30 requires 2,580,939. A four-member, 55-hour guild earning a deliberately explicit 300 activity XP/member-hour, plus generous boss/achievement credits, reaches only about level 14. Comfort II at L20 is not a Plains upgrade in that model; it is beyond the Run. Propose `[4 - Progression] LevelXpBase = 500`, `LevelXpGrowth = 1.12`, retain `MaxLevel = 30`, and retain the existing material/coin/level prices. This gives L20 at 31,720 XP and L30 at 107,291, preserving progression through the month rather than merely multiplying early rewards.
2. **The profession ladder needs event-rate budgets, not a blanket Calling-curve nerf.** Focus 60 requires approximately 5,724 raw skill XP; reaching it at the modeled Ashlands opening requires 127 XP per total play-hour, or 254 at −50% time. A 100-XP/hour focus arrives at Ashlands at 54, a 60-XP/hour smith at 44, and a 40-XP/hour herbalist at 37. These are conditional estimates, not new findings duplicating the Shakedown. Exact candidate gain changes and the required throughput are below; keep the Calling bands unchanged until measured.
3. **Solo class farming has a structural advantage; CreatureManager HP is not an unlimited XP multiplier.** A kill gives solo 100%, a three-player party member about 38.1%, and an eight-player member 18.75%. Parties win XP/hour only if their kill throughput improves by more than 2.625× or 5.333× respectively. Oathbound clamps ordinary health-derived XP to 80 (+at most 5 threat XP), with bosses four times the clamped base. An inflated Fader still pays only 320–325 before splitting. Keep `ExperienceMultiplier = 1`; do not slow everyone to solve a solo/party incentive issue. A bounded party-bonus candidate is `FullPartyBonus = 1`, not full contributor XP.
4. **EpicLoot 0.6 is much harsher than “60% of the drop chance.”** Code divides the zero-drop weight by the multiplier and multiplies positive weights by it: 0.6 gives 0.36× positive-drop odds. A stock 15% roll becomes 5.97%, not 9%; a 50% boss-shard roll becomes 26.47%. Guaranteed boss equipment count distributions are unchanged. If the intended odds multiplier is 0.6, propose `Global Drop Rate Modifier = 0.7746`; otherwise retain 0.6 knowingly. Rarity itself climbs appropriately from Magic/Rare to Epic/Legendary/Mythic, and boss re-kills still pay.
5. **ProgressivePowers does not finish prematurely.** With one kill of each boss, mastery immediately after Fader is Eikthyr 7, Elder 6, Bonemass 5, Moder 4, Yagluth 3, Queen 2, Fader 1. Later powers deliberately need repeat kills, up to seven Faders for Fader mastery 7. This is boss-count progression, not hours/use progression. Keep the present mastery defaults unless the owner wants every power mastered before the first Fader; the latter is a different design.
6. **Personal keys and death rules support the intended costs but do not prevent an exceptionally capable solo racer.** Equipment/craft/food/summon locks follow personal kills; no timer opens bosses and no guild shares absent members' keys. The skill floor is only a drain threshold, not free levels or a clamp. Class death loses half current-level progress, and costs effectively nothing at the level-80 XP cap. Focus professions are death-protected. These are accepted semantics, not bugs to relitigate.

## Scope, provenance and model

Read-only audit. No gameplay, builds, tests, servers, deployment, commits or repository configuration edits were performed. The only repository write is this handback. Arithmetic below is a sensitivity model, **not observed player telemetry**. The owner reports the Pack works; nothing here contradicts that runtime observation.

Primary-source shorthand used below:

- **OB-Core**: Oathbound **0.21.14**, `/tmp/lembitu-fit/ClassOverhauls/LionAndOtter-Oathbound-0.21.14/BepInEx/plugins/WarriorRpg/Warrior.Core-decompiled/Warrior.Core/`.
- **OB-Mod**: same package, sibling `WarriorRpg-decompiled/Warrior.Mod/Plugin.cs`.
- **Guild-src**: Guilds **1.2.2**, `/tmp/lembitu-research/GroupsWorldCluster/Guilds-code/Guilds/`.
- **PP-src**: ProgressivePowers **0.3.4**, `/tmp/lembitu-research/ProgressionCluster/ProgressivePowers.cs`.
- **EL-src**: EpicLoot **0.14.13**, `/tmp/lembitu-research/ProgressionCluster/EpicLoot.cs`.
- **EL-table**: `/tmp/lembitu-premium/AuditPace/loottables.json`, freshly extracted embedded `EpicLoot.config.loottables.json` from staged `dist/plugins/EpicLoot/EpicLoot.dll`.
- **CM-src**: CreatureManager **1.2.5**, `/tmp/lembitu-research/GroupsWorldCluster/CM-code/CreatureManager/CreatureDomainManager.cs`.
- **WAP-src**: World Advancement Progression **1.0.0**, `/tmp/lembitu-research/GroupsWorldCluster/WAP-code/VentureValheim.Progression/SkillsManager.cs`.
- **Smith-src**, **Herb-src**, **Impact-src**: BlacksmithingExpanded **1.2.4**, Herbalist **1.5.0**, ImpactfulSkills **0.21.0**, respectively `/tmp/lembitu-research/ProgressionCluster/BlacksmithingExpanded.cs`, `Herbalist.cs`, `ImpactfulSkills.cs`.

SHA-256 comparisons established the staged Oathbound core/mod, EpicLoot, ProgressivePowers and Guilds DLLs match the cached package DLLs used for prior decompiles. EpicLoot hash: `802790e0cbd8a6f951627619a488b84e6a406e8770e2687b2fff8b63d2adf9ea`; Guilds: `c9303d4f7fd9c99ee915f91dd4d203dfa416cc599baa093cdeb88d287c89ef40`; ProgressivePowers: `70a8854c543c693256840163c03986fda4db6971521899441911983ff8eb9a6f`. Versions are also recorded in `docs/modstack.md:41-44,59,80,83-86`.

### Explicit working assumptions [INFERENCE]

Use the shared brief's 50–60 hours/player to Fader; midpoint **55 hours**. Model biome opening at cumulative hours **0 / 4 / 12 / 20 / 27 / 35 / 45**, then Fader at 55. This allocates 4/8/8/7/8/10/10 hours to Meadows/Forest/Swamp/Mountains/Plains/Mistlands/Ashlands. It is a planning allocation, not a canonical biome schedule. ±50% scales the hours and ordinary activity at each milestone to 27.5 / 55 / 82.5 total hours, while preserving the same boss order. It does not invent extra boss mastery kills at +50% time.

Class scenario: a usual **three-player hunting party**, 30 credited group kills per total player play-hour, with mean unsplit rewards **20/30/40/45/55/65/75** by biome, one 320-XP boss kill at each biome end in an eight-player party, no respec/switch, no deaths, and a class chosen at the start. Those reward and kill-rate inputs are explicit assumptions, not verified creature-population averages. Actual idle/building time, killing-blow ownership, sieges, Karma, companions, threat bonus and deaths change the result.

Profession scenario: accumulated raw skill XP per **total play-hour**, after the underlying skill's increase step and other gain modifiers but before the Calling curve. Compare **100/hour** general specialist illustration, **60/hour** smith workload illustration and **40/hour** herbalist illustration. A raw rate is not a universal rate shared by the eleven professions.

Guild scenario: four contributing members, **300 activity XP/member-hour**, all seven first kills credited to this guild (optimistic in a cross-guild boss party), 150 repeat/kill XP per boss, and **1,000 achievement XP per biome completed** as a simple planning allowance. No coin donations. Thus opening-milestone XP is `4 × h × 300 + completedBiomes × (1500 + 150 + 1000)`. Activity and achievement assumptions are not measured. Real guild size 3–5 changes the activity term linearly; last-hit ownership can remove assumed boss credits.

### Exact formulas

**Class XP**: `baseKill = clamp(floor(2 × sqrt(maxHealth)), 10, 80)`; boss multiplies that base by four, then a strongest-hit threat bonus adds at most five (OB-Core `KillRewards.cs:7-23`). Actual max health is sent in the kill packet and used in the reward (OB-Mod `Plugin.cs:9865,9916,9930`). `threshold(L) = 25 × (L−1) × (L+2)`, cap 161,950 at L80; next-level cost `100 + 50 × (L−1)` (OB-Core `Progression.cs:10-12,94-116,168-180`). Death subtracts `ceil(XPIntoLevel/2)` (`Progression.cs:239-247`).

**Party share**: `s(n) = [1 + 0.5 × min(1,(n−1)/7)] / n`; stochastic integer rounding is expectation-preserving. It is 1 solo, 0.535714 for two, 0.380952 for three, 0.303571 for four and 0.1875 for eight (`src/plugins/Lembitu.Oathbound/PartyExperience.cs:157-181,228-232`). The chosen class XP forecast is cumulative `Σ(biomeHours × 30 × meanKillXP × s(3)) + completedBosses × 320 × s(8)`.

**Monster HP**: ordinary `H = vanillaH × 2 × level`; regular boss `H = vanillaH × 8 × [1 + 0.5 × (level−1)]` (`config/enforced/CreatureManager/levels.yml:50-56,97-103`). Hard star weights are Meadows `[90,10]`, Forest `[68,25,7]`, Swamp `[48,34,14,4]`, Mountains `[38,32,20,8,2]`, Plains `[30,30,23,12,4,1]`, Mistlands `[22,28,26,16,6,2]`, Ashlands `[12,22,25,21,13,7]` (CM-src:4773-4783). Expected ordinary level is 1.10/1.39/1.74/2.04/2.33/2.62/3.22, so expected HP floor multiplier is 2.20/2.78/3.48/4.08/4.66/5.24/6.44. **Compute XP by summing each star outcome; sqrt(mean HP) is not mean XP**, and the cap clips outcomes. Karma can add pressure beyond these weights.

**Profession XP**: `R(l) = 0.5 × floor(l+1)^1.5 + 0.5`; minimum cumulative focus XP to integer L is `T(L)=Σ(l=0..L−1) R(l)`. Real event gains discard overflow on a level-up, so this sum is a lower bound, increasingly approximate for large/batched events (`src/plugins/Lembitu.Callings/SkillRules.cs:19-39,55-68`; WAP-src:41-59,161-167). For non-focus, integrate the same requirements divided by rates 1 below30, 0.5 below60, 0.25 below80, 0.1 above80 (`config/enforced/lembitu.callings.cfg:13-20`). Focus forecast is inverse T of `h × rate`; raw skill level, not an enchanted effective level, pays a rung (`docs/adr/0023-what-professions-make-climbs-a-biome-ladder.md:29-40,65-66`; `docs/wiki/shakedown.md:61`).

**Guild XP**: next-level cost `round(1000 × 1.25^(L−1))`; cumulative `G(L) ≈ 4000 × (1.25^(L−1)−1)`, summing individually rounded costs for exact integers. These costs are not “XP to level L” independent thresholds (`Guild-src Progress.cs:251-270`; `Plugin.cs:200-211`). Proposed curve replaces the 1000 and 1.25 with 500 and 1.12.

**Loot**: for stock positive-drop probability P and modifier m, `P' = m²P / (1−P + m²P)`. For tables with more than one positive count, `expectedCount' = m² × Σ(positiveCount × stockWeight) / [zeroWeight + m² × Σ(positiveWeight)]`. Rarity weights normalize separately; several rows do not sum to 100 (`EL-src:17064-17099`; EL-table:975,1027). Boss count tables without a zero outcome retain their count distribution for any positive m.

**Mastery**: each level's boss requirements are cumulative **maximum counts per boss**, not additive payments and not hours using a power (PP-src:1399-1458). The default sequence walks forward through bosses once, then alternates original boss and Fader, increasing their required counts (PP-src:1461-1535).

## Per-biome pace tables

Numbers in parentheses in forecast rows are **−50% / baseline / +50%** play time. Class row is at **biome completion**, profession and guild rows at **biome opening**; this distinction is intentional because a craft gate must already be met when the biome opens. A separate post-Fader column avoids shifting the gates by one boss.

| Pillar / milestone | Meadows | Black Forest | Swamp | Mountains | Plains | Mistlands | Ashlands | Immediately after first Fader |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Opening hours, baseline | 0 | 4 | 12 | 20 | 27 | 35 | 45 | 55 |
| Class level at biome **completion**, current three-player model | 4 / **5** / 7 | 8 / **11** / 14 | 11 / **16** / 20 | 14 / **20** / 25 | 17 / **25** / 30 | 21 / **30** / 37 | 24 / **35** / 43 | 24 / **35** / 43 |
| Focus profession at **opening**, 100 raw XP/hour | 0 | 15 / **20** / 23 | 23 / **31** / 37 | 29 / **39** / 46 | 33 / **44** / 52 | 37 / **49** / 57 | 41 / **54** / 64 | 44 / **59** / 69 |
| Smith focus at opening, 60 raw XP/hour, baseline only | 0 | 16 | 25 | 31 | 35 | 39 | 44 | 47 |
| Herbalist focus at opening, 40 raw XP/hour, baseline only | 0 | 13 | 21 | 26 | 30 | 33 | 37 | 40 |
| Craft rung, normal material ladder | none | 10 | 20 | 30 | 40 | 50 | 60 | 60; Deep North is 70 |
| Guild at opening, current curve | 1 | 4 / **5** / 6 | 7 / **8** / 10 | 9 / **10** / 12 | 10 / **12** / 13 | 11 / **13** / 14 | 12 / **14** / 15 | 12 / **14** / 16 |
| Guild at opening, proposed 500/1.12 curve | 1 | 8 / **10** / 11 | 13 / **16** / 18 | 16 / **20** / 22 | 18 / **22** / 25 | 20 / **24** / 27 | 22 / **26** / 29 | 23 / **27** / 30 |
| Power mastery at biome **completion**, one kill/boss, Eikthyr→Fader order | 1,0,0,0,0,0,0 | 2,1,0,0,0,0,0 | 3,2,1,0,0,0,0 | 4,3,2,1,0,0,0 | 5,4,3,2,1,0,0 | 6,5,4,3,2,1,0 | 7,6,5,4,3,2,1 | same |
| Personal-key skill drain threshold at **opening**, all prior bosses attended | 0 | 10 | 20 | 30 | 40 | 50 | 60 | 70 |

All forecasts use the formulas and citations above. The 100-XP/hour profession is an illustration of the **minimum sustained specialist workload needed**, not a claim Mining, Fishing, Cooking and Hauling earn identically. No amount of extra hours raises mastery without the specified boss kills. Floors grant no XP. Non-focus death can cross below a rung even when its starting level was only just above the floor (WAP-src:134-158).

### Profession budget by rung

| Opens | Rung | Minimum cumulative focus XP | Required mean raw XP per total play-hour at −50% / baseline / +50% opening time |
|---|---:|---:|---:|
| Forest | 10 | 76 | 38 / 19 / 13 |
| Swamp | 20 | 390 | 65 / 33 / 22 |
| Mountains | 30 | 1,042 | 104 / 52 / 35 |
| Plains | 40 | 2,107 | 156 / 78 / 52 |
| Mistlands | 50 | 3,649 | 209 / 104 / 70 |
| Ashlands | 60 | 5,724 | 254 / 127 / 85 |
| Deep North, if visited at hour55 | 70 | 8,381 | 305 / 152 / 102 |
| Full mastery by hour55 | 100 | 20,301 | 738 / 369 / 246 |

This demonstrates why level100 is **not** a plausible dead-end risk for ordinary craft-focused workloads in a 55-hour Run, but crafting rung60 can still be too late. Four focuses do not mean four independently allocated 55-hour jobs; dual-purpose events such as mining/hauling and wood/smithing help, while sailing/exploration compete for attention.

Relevant event sources:

- Smith: default 1/craft, 0.75/ore-or-kiln insertion, 0.1/repair, 3/upgrade, 10/first craft type; gain factor1 (`Smith-src:4734-4738,4717,4974-4975,5440-5456`). For comparison, **5,724/0.75 ≈ 7,632 smelter/kiln insertions alone** to60, or 1,908 upgrades alone, before other gains and overflow. Supplying a guild and feeding charcoal genuinely matter; merely making everyone's six equipment pieces per biome does not prove the ladder reachable.
- Herbalist: default increase step1, `Exp Gain Factor = 1`, eligible gathering credit at most once/30seconds, crafting factor1 (`Herb-src:281-295,1553-1562,1690-1728,21372`). Gathering alone needs 5,724 credited picks, a theoretical **47.7 hours at the cooldown ceiling** before travel or missed eligible picks. This ceiling is not an achievable average. The cooldown is on the pick-handler's shared timer, so it is not a promise of an independent 120/hour for every nearby picker.
- Cooking: vanilla menu crafting raises the station's skill by the multi-craft amount; cooking-station handling pays 0.4 and 0.6 in its two relevant paths (`/tmp/lembitu-grill/PerkCalibration/InventoryGui.cs:1905-1906`; `CookingStation.cs:657-692`). ImpactfulSkills can additionally pay eating XP (`Impact-src:4106-4107`). The precise per-event skill-definition step and the guild's actual food throughput are not verified here; do not convert the raw-XP table into an asserted food count.
- Farming pays harvest XP and planting XP; Animal Handling has taming and honey activity; Hauling has cart-distance and carried-weight gains; Sailing has travel ticks (`Impact-src:2719,3487,3642,3703,5835,6177,6196,7579`). Mining, Wood Cutting, Exploration and Sailing have **no crafting rung**; Farming only gates the Scythe, Animal Handling saddles, Fishing baits, and Hauling backpacks (ADR-0023:45-57). They still need perk/mastery pace measurements, but they cannot prevent gear crafting by failing a nonexistent ladder rung.

### EpicLoot rarity pace

Rarity vectors below are level-1 common-mob weights in **Magic/Rare/Epic/Legendary/Mythic/Ancient** order. Missing final components mean zero. This is a reproducible lower-star reference, **not a biome population average**. Hard presets frequently roll higher levels, increasing loot and rarity; large elites have separate tables. Rarity acquisition time changes with ±50% kills, while the distribution does not.

| Biome | Representative source/table | Level-1 rarity weights | Level-1 chance of any table loot at m=0.6 | Fit |
|---|---|---|---:|---|
| Meadows | Boar/Deer/Neck/Greyling → Tier0 | 100/0/0/0/0/0 | 0% at level1; level2 stock5% becomes1.86% | Ordinary fresh-character magic is scarce; Eikthyr is the reliable loot event. |
| Forest | Greydwarf/Skeleton → Tier1; stronger mobs Tier2 | 75/25/0/0/0/0; Tier2 50/47/2/1/0/0 | 1.86%; Tier2 3.85% | Magic/Rare, occasional higher rarity from stronger/starred creatures. |
| Swamp | Draugr/Leech/Blob → Tier3 | 24/73/2/1/0/0 | 5.97% | Rare-led, occasional Epic/Legendary; boss/elite sources push higher. |
| Mountains | Wolf/Hatchling → Tier4 | 0/75/24/2/0/0 (sum101) | 8.26% | Rare/Epic, not a hard Legendary prohibition. |
| Plains | Goblin/Lox/Deathsquito → Tier5 | 0/50/49/4/0/0 (sum103) | 10.71% | Epic becomes normal with higher stars; rarity remains useful to chase. |
| Mistlands | Seeker/Dvergr → Tier7; Tick Tier6 | 0/15/70/15/0/0 | 16.24% | Epic/Legendary, Mythic available at higher stars. |
| Ashlands | Charred Archer/Twitcher → Tier7; melee/mage/Asksvin → Tier8 | Tier8 0/5/25/65/5/0 | 19.35% for Tier8 | Legendary/Mythic; Tier8 at level3+ includes Ancient. |

Sources: EL-table:761-915,917-975,1021-1187,1686-1890. Do not read weights177 on Eikthyr as a177% probability, nor assume the profession gate makes a rarity unavailable. Item type recipe knowledge and enchantment rarity are distinct axes.

At 300 eligible kills of **only** the Swamp reference creature/level, expected table drops are17.9; −50% and +50% produce9.0 and26.9. This is **before** division among the hunting group, category weights, recipe filtering and distribution among slots/classes. There is no eight-way per-player equipment roll. Use `1−(1−p)^K` for the probability of at least one result of a given rarity/category; half the mean count is not half that probability.

EpicLoot's normal loot category ratios are relative weights: defaults item0.7/unidentified0.1/material0.1 with our shard0.1 give 70/10/10/10 when all categories are viable (EL-src:47554-47557; enforced config:29-30). Direct elite/boss shard tables bypass that ratio (EL-src:47555). The player-known-recipe filter follows gear knowledge rather than profession level; it does not force dropped items to come from a smith (`config/enforced/randyknapp.mods.epicloot.cfg:4-7,28`; ADR-0023:91-93). The client seed changes only names/colors (`config/client/randyknapp.mods.epicloot.cfg:1-27`).

Boss reference drops at level1: Eikthyr1.3 expected equipment results, Elder1.75, Bonemass2.45, Moder3.3, Yagluth/Queen/Fader4.05 each, **unchanged by m=0.6 because none of their count tables has a zero outcome**. Their dominant rarities move Magic → Magic/Rare → Rare → Epic → Epic → Legendary → Legendary/Mythic (EL-table:1998-2404). The separate stock50% boss-shard table is26.47% at m0.6. These are shared loot results, not every attendee's personal reward.

## Ranked findings and recommendations

### 1. Resize the guild curve, not just the upgrade labels

**Evidence.** Defaults1000/1.25/30 and XP sources are in Guild-src `Plugin.cs:200-211`, `Progress.cs:122-213,251-270`. Current gates and prices are `config/enforced/adrian.valheim.guilds.cfg:33-42`. Cumulative current L10/L12/L20/L30 costs are approximately25,802/42,566/273,556/2,580,939 XP. All17 achievements, including every gold, pay at most `17 × (300+1000+3000) = 73,100` XP at defaults (`Progress.cs:32-50,229-236`). Seven generous first boss+kill credits add11,550: together these still leave about2.496 million activity/donation XP to cap.

At 3–5 members ×50–60 hours, stock L30 requires **8,321–16,642 activity XP/member-hour** even after every achievement and all boss-first credits. At50coins/XP, donating the complete stock L20 cost is13.68million coins and L30 is129.05million, separately from upgrade spending. Thus “the Market will buy the missing levels” is not a plausible month plan. Coin transfers between players do not create new currency.

**Concrete proposal.** In `adrian.valheim.guilds.cfg`, `[4 - Progression]`:

```ini
LevelXpBase = 500
LevelXpGrowth = 1.12
MaxLevel = 30
ActivityXpMultiplier = 1
DonationCoinsPerXp = 50
```

Retain `[6 - Upgrades] comfort = Silver:20,WolfPelt:20,C3000,L12;BlackMetal:30,LoxPelt:20,C8000,L20` and `monsterward = Iron:40,TrophyDraugr:5,TrophyBlob:5,C3000,L10`. Their material tier still prevents a fresh guild buying late safety/comfort with an early achievement burst. Retain `members = P1,L99`; reducing MaxLevel is unnecessary and would reduce banner points. New thresholds L10/L12/L20/L30:7,388/10,327/31,720/107,291. Baseline model reaches27 atFader; slow model23; fast30. **This is a proposed calibration, not evidence that exactly this curve is optimal.** It intentionally revisits ADR-0019's assumed month-long guild progression, not the owner's specified upgrade material prices.

**Fit / conflicts / Pack.** Synced server progression settings meet the Pack rule. No new mod. Monsterward interacts with Oathbound siege placement/defense, already planned in `shakedown.md:49`; this audit does not claim whether it starves sieges. Comfort stacks with SaunaMod intentionally (guild config:15-18). Materials/treasury supply may remain limiting even if XP becomes reachable.

**Confidence:** high mathematical mismatch; medium exact curve. **Shakedown-only:** actual XP/member-hour, guild-size spread, coin liquidity and siege/ward consequence. Add guild levels/activity XP alongside the existing boss/session records; current Shakedown lacks this pillar's numeric pace check.

### 2. Make the real EpicLoot drop modifier explicit before judging rarity pace

**Evidence.** EL-src:17081-17099 conclusively squares the odds multiplier. The staged DLL matches the cached package; its extracted table supports the probabilities above. This is not a new “health × loot feels hard” concern waiting for play: it is a settled numeric property of the installed code.

**Concrete proposal.** If the intended balance phrase is “60% as likely in odds terms,” change `[2 - Balance] Global Drop Rate Modifier = 0.7746` (`sqrt(0.6)`, rounded). It gives Swamp stock15% →9.57%, boss shard50% →37.5%. If the owner's “magic gear stays a treat” deliberately means the current stronger reduction, **retain0.6** and describe it as0.36× positive-drop odds. Do **not** change rarity JSON and drop chance together on the first tuning pass. Keep `Shard Stone Drop Ratio = 0.1`, `Boss Trophy Drop Mode = Default`, `Item Drop Limits = PlayerMustKnowRecipe`, all client colors/names, and temper risk unchanged.

A separate source correction: config comments say stock minimum effect count happens92% of the time (`config/enforced/randyknapp.mods.epicloot.cfg:12-13`), but the freshly extracted **staged** loot resource has80/18/2 weights (EL-table:2-8). That documentation cannot be used to estimate magic power. This is not a request to restore a different92% curve; it is an evidence discrepancy to correct when the parent curates docs.

**Fit / conflicts / Pack.** Server-synced balance, no extra mod. Rarity is **not** personally boss-locked; higher-star early creatures can drop a high-rarity known low-tier item. That is healthy loot variety, not automatically a race-ahead exploit. Recipe knowledge/material key enforcement is the important equipment-tier boundary.

**Confidence:** high on mechanics; medium/conditional on proposed odds. **Shakedown-only:** whether scarcity across eight players and class-compatible slots feels premium or punitive. Existing `shakedown.md:61` is profession effects, not the number of useful personal gear upgrades; do not confuse the two measurements.

### 3. Group reward advantage is conditional on throughput, not guaranteed by “150% total”

**Evidence.** Party share and fixed creature/boss health are precisely known (formulas above; `PartyExperience.cs:157-181`; enforced CM:99-102). A three-player party needs2.625× the solo group's kills/hour to tie each player's XP. A full party needs5.333×. Because ordinary foes are tuned for two, hunting eight together is not necessarily the sensible leveling pattern; the55-hour model is mainly a three-player guild hunt, not eight players at all times.

With identical credited kills/hour and biome exposure, the baseline no-death solo model ends about **57 vs party35**. This is a controlled mathematical comparison, **not a claim solo actually clears late-biome packs equally fast**. Solo wins especially when low-tier mobs die in one attack and the party spends time traveling to the same target. Tamed targets are excluded by Oathbound (`OB-Mod:9905-9909`), so livestock slaughter is not the relevant class-XP farm.

**Concrete candidate.** Keep Oathbound `[Progression] ExperienceMultiplier = 1` and `SharedExperience = false`. If measured guild hunts miss the throughput break-even, change `config/enforced/lembitu.oathbound.cfg`, `[Party] FullPartyBonus = 1`, retaining `FullPartySize = 8`, `Radius = 100`. Then three-player share becomes0.428571 (break-even2.333×), eight-player0.25 (break-even4×). This mildly strengthens cooperation without full contributor XP or difficulty scaling. It changes ADR-0022's150% total decision and therefore needs owner approval, not silent implementation. It cannot guarantee equal pace; no existing bounded bonus fully erases solo reward economics.

**Fit / conflicts / Pack.** Our synced config already exposes the key (`PartyExperience.cs:37-48`). Do not enable upstream contributor sharing: its recipients and full rewards would bypass our intended splitter semantics. Do not add personal class-level caps tied to bosses: those would be a new hard lock, contrary to the open soft-specialization concept.

**Confidence:** high mechanic, medium practical impact. **Shakedown-only:** XP/hour and kill throughput solo vs two/three/four, not merely the already-planned one-kill split test (`shakedown.md:38`). This finding is the code-settled reward break-even; class80 timing itself remains the existing Shakedown question, not a duplicate finding.

## Conditional calibration candidates — not settled findings

### Profession gates: adjust their owners' gain rates only after the existing focus-pace check

`shakedown.md:16-18` already asks exactly whether focuses reach each rung. This audit supplies its quantitative pass/fail budget; it does not report the hypothetical60/40-XP/hour rates as actual defects.

If the sample workloads prove representative, use these precise candidates rather than reducing the non-focus slowdown:

- **Smith** `[General] Skill gain factor = 1`; `[XP] XP per craft = 2.5`, `XP per smelt = 1.875`, `XP per upgrade = 7.5`, `First craft bonus XP = 25`; retain `XP per repair = 0.1`. Productive training gains about2.5× while free repairs do not become the dominant grinder. The60-XP/hour illustration becomes150/hour, meeting the baseline Ashlands budget with room for overhead. Gain factor is set both on the skill definition and in `GiveBlacksmithingXP` (`Smith-src:4545-4550,4974-4975`), so increasing that one factor squares its effect; individual XP keys are the more legible tuning surface. Smith setting lock remains the **already planned** `shakedown.md:31` verification; do not assume these changes satisfy the Pack until that check is settled.
- **Herbalist** `[5- Skill Exp] Exp Gain Factor = 3.5`, retaining `Potion Crafting Exp Gain Factor = 1`, `Exp Gain Cooldown = 30`, `Exp Loss Amount = 0`. The40-XP/hour illustration becomes140/hour. The factor is the skill's increase step, not separately multiplied into its craft request (`Herb-src:281-286,1559-1561`), so this is3.5× rather than a squared change. Gathering cooldown is a supply/travel constraint; lowering it does not help a player who lacks enough herbs. Keep the synced Fast Learner multiplier1.5 and Calling curve.
- **Cooking/Fishing/Farming/Animal Handling/Hauling**: keep the current settings and rung file until real raw gain/hour is known. Do not invent an unsupported universal XP multiplier or uniformly lower all364 recipe rules. At low time, whichever crafting pillar falls short may require a lower rung rather than vastly inflated XP for fast players; choosing that tradeoff is the owner's decision.

At−50%time even these candidates need more productive effort to meet Ashlands60: sample smith150/hour is below254 required, herbalist140 below254. A modest specialist delay is a meaningful profession/trade pressure; an entire biome having no qualified crafter in any guild is a progression stall. The Market can cover the former, not the latter. Report both guild coverage and individual level, not just “one player reached60.”

Focus/non-focus mathematical totals reinforce soft specialization: at 60, focus needs 5,724 and non-focus about 10,405 raw XP (1.82×); at 70 non-focus needs about 21,035 (2.51×); at 100 non-focus needs about 120,508 (5.94×), before deaths/overflow. Keep the current `[Steep curve]` 30/60/80 and 1/0.5/0.25/0.1. Killing a boss never fills this deficit: the floor gives no gain.

## Accepted behaviors / no change recommended

### Class curve and CreatureManager

Level80 needs161,950XP. At the ordinary upper reward85, at least1,906 solo kills, roughly5,002 group kills for three-party sharing, or10,162 full-party group kills are needed (ignoring the few boss rewards, deaths and threat availability). At55hours this is approximately35/91/185 credited kills per total play-hour. Our sample reaches35, with24–43 sensitivity; there is **no evidence here to preemptively lower ExperienceMultiplier**. Health2× raises uncapped reward by aboutsqrt2, not2×; starred/late mobs soon hit80 once maxHP≥1,600. Boss reward remains roughly60/person at full-party size, not thousands proportional to Fader's huge pool. Boss re-kills are loot/mastery events, not class-level jackpots.

AtL80 the XP cap sits exactly on the level threshold, so death loses0classXP. A profession100 focus is also death-protected. Whether that creates a cost-free long post-Run endgame is irrelevant to the stated first-Fader month unless players cap early; the Shakedown already measures that (`shakedown.md:16,63`). No extra finding based on unobserved early capping.

### ProgressivePowers mastery and re-kills

Keep `Kill Credit Range = 100`, `Max Attuned Powers = 1`, `Block Power Activation = true`, `Enable Advanced Power Config = false` (`config/enforced/MidnightsFX.ProgressivePowers.cfg:13-17`). The built-in seven-boss list ends withFader, and powers have seven features (PP-src:1883-1885,2118-2155). At full mastery, cumulative requirements are:

| Power | Counts needed for level7 under stock defaults |
|---|---|
| Eikthyr | One of every boss throughFader |
| Elder | Elder2; Bonemass/Moder/Yagluth/Queen/Fader1 |
| Bonemass | Bonemass2, Fader2; Moder/Yagluth/Queen1 |
| Moder | Moder3, Fader2; Yagluth/Queen1 |
| Yagluth | Yagluth3, Fader3; Queen1 |
| Queen | Queen4, Fader3 |
| Fader | Fader7 |

No change is required merely because Fader1 does not master Fader's own power; mastery after Fader is meaningful optional continuation. Before the first Fader, Queen remains level1 because level2 requires Fader. Queen's level3 eitr regeneration therefore cannot be assumed in that encounter's build budget. Later Yagluth/Moder features are likewise not automatically available. A simulation assuming every power at mastery7 throughout Ashlands overstates player power. Do not rewrite `Levels.yaml` solely to make that simulation true. The presence-radius check (shakedown.md:52) cannot settle count policy; that is already settled by code.

Boss re-kills remain useful: one shared trophy/key/Wishbone (epicloot.cfg:31-36), shared guaranteed equipment and probabilistic shards, personal mastery count, and Guilds150 last-hit boss XP. Multiple miners/prospectors need additional swamp keys/Wishbones. Trophies also serve power unlock/display needs without trophy-consuming recipes. Removing repeat incentives would be a mistake; none is proposed.

### Personal keys, skill floor, death and launch modifiers

Keep WAP private keys/global block, AdminBypass=false, all equipment/crafting/cooking/eating/power/summon locks, UnlockBossSummonsOverTime=false, and Guilds SharedProgression=false (WAP config:36-52; guild config:30-31). A solo player earning the needed personal keys can still progress; the barrier is fixed boss difficulty and preparation, not an attendance quorum. No evidence supports claiming the Pack technically prevents a solo race.

Keep BossKeysSkillPerKey=10, ceiling100, relative drain and focus protection. Level60.1 with floor60 drains to57.095 at5%; there is no floor clamp. A skill at or below the floor loses no levels, but WAP still clears its accumulator during LowerAllSkills (WAP-src:21-29,134-158). Full focus snapshot protection is separate (ADR-0021:47-52). These are established semantics, not the already-planned death-protection test presented again as a finding.

Keep Venture TeleportOnAnyDeath=true, SkillLossOnAnyDeath=true, AdminBypass=false. Code confirms these true values leave vanilla respawn and skill loss paths enabled; they do not force additional drain. Source: Venture Multiplayer Tweaks 1.0.0, `/tmp/lembitu-research/MapCluster/VentureValheim-Venture_Multiplayer_Tweaks-1.0.0/code/VentureValheim.MultiplayerTweaks.decompiled.cs:738-790`. Vanilla calls skill OnDeath only when HardDeath is true (`/tmp/lembitu-grill/PerkCalibration/Player.cs:3320-3323,3442-3449`), so the setting does not remove vanilla rapid-repeat soft-death protection. The same Venture source has an unconditional local-player CheckDeath suppression for 15 seconds after the recorded spawn time (lines681,794-803), a small respawn grace period not represented in the enforced config comments. No numeric pace change is proposed for that grace period; do not model every death/respawn second as having identical exposure to death. This grace exists uniformly in the Pack; its actual recovery feel is a runtime question.

Keep launch DeathPenalty default, Resources default, Raids less, Portals hard (config/launch/launch.env.example:59-76). Hauling ore is paid Road work, not wasted time. Faster ore transport changes profession/guild pace and world size together. Combat hard stacks with CM damage as already flagged (shakedown.md:62). Whether difficulty consumes more than55 hours to Fader needs real boss minutes/deaths (shakedown.md:48), not just an XP spreadsheet.

## Gaps

- **No actual activity telemetry.** Kill counts, group composition, elapsed hours and raw profession gain rates are not provided. Assumptions and per-biome tables are conditional. Existing Shakedown class/focus checks are the correct evidence source.
- **No empirical guild pace check yet.** Record XP deltas/sources per guild/session, members' play hours, coins generated/spent/donated, and cross-guild boss credit recipients. Last-hit stat credit comes from Guild-src StatsTracker.cs:26-49 and Plugin.cs:206-207; presence does not imply guild XP to every guild.
- **Recipe knowledge versus personal-key boundary.** This audit did not independently trace every WAP/recipe-discovery/EpicLoot filter call. Especially for the121 ladder material overrides (ADR-0023:100-107), known recipe is not necessarily proof WAP knows its modded material tier. Use a targeted static trace or the planned ladder/key refusal check (shakedown.md:27); numeric tuning cannot settle it.
- **Guild material/coin budget.** Time to Iron40/Silver20/BlackMetal30,3000/8000 coins and trophies depends on the group and economy. Reaching L20 does not prove ComfortII affordable.
- **Eleven profession definitions/event rates.** Common level requirements and major event owners were verified, not every skill-definition step or batching path. Mining/Wood Cutting/sailing/perk100 completion cannot be claimed from craft counts. Overflow, rested effects and Fast Learner uptime belong in measured raw XP/hour.
- **EpicLoot operational JSON.** Staged embedded tables and binary identity were checked, not deployed/generated/auto-sorter JSON. A custom active JSON can override rarity/effect counts; inspect that file before asserting the80% minimum or exact table is what players used. No SSH/server launch was permitted.
- **No claim of full first-Fader power balance.** Class/passive/skill forecasts are mostly below cap; bosses8× plus stars and Combat hard need real-player timing. Health→XP is certain; throughput is not.
