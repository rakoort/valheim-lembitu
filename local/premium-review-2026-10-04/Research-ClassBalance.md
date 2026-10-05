# ClassBalance evidence handback

Scope: external evidence for the three assigned questions; evidence collected 2026-10-05. No server settings recommendations, source/configuration edits, or validation runs. Server context comes from the supplied brief, not an independent repository audit. **Intent** means a developer's stated policy or documented patch behavior; **measured** means a study result or explicitly attributed telemetry; **report** means qualitative observations or community documentation. Patch percentages are not automatically acceptable inter-class spread targets.

## Summary

1. **Riot published explicit outcome bands, not DPS bands:** in May 2019 average-play champions were flagged below 49% win rate or above 54.5%–52.5% (upper threshold tightened with bans); skilled-play upper thresholds were 54%–52%. June 2020 tightened those upper bands by 0.5 percentage points. These are PvP, skill-bracket-specific intervention thresholds, not evidence for a co-op TTK tolerance. [R1, “Updating Our Approach”; R2, “Combating Power Creep”](https://www.leagueoflegends.com/en-us/news/dev/dev-champion-balance-framework/).
2. **WoW's official 2012 AMA favors observed encounter performance over a single simulation ranking:** Greg Street distinguished a 15% DPS delta from 1.5%, but did not announce either as an allowable band; Ion Hazzikostas explicitly accepted different strengths in burst, cleave and AoE while warning that razor-edge encounters produce class stacking. [W1, Ion's Heroic Spine answer and Greg's Simulation Craft answer](https://worldofwarcraft.blizzard.com/en-us/news/7207171/transcript-reddit-ama-with-world-of-warcraft-developers).
3. **FFXIV provides a directly relevant co-op exclusion case:** Yoshida said an approximately 1% excess in one Savage boss's HP contributed to job exclusion; jobs are balanced at applicable item level accounting for rotation difficulty and support, then encounters are tuned. The usual release adjustment of tester-clear values +1–2% boss HP is an encounter policy, not a job-spread target. [F1, “Reason for the HP Adjustment,” “Source of the Miscalculation,” “Why Adjust the Duty, Rather than Job Balance?”](https://na.finalfantasyxiv.com/lodestone/topics/detail/6d95409248d3ab3b5dbc0c8a04340b373870140b).
4. **Pet balance involves more than damage:** WoW Season of Discovery reduced owner-armor inheritance 45%→30% and stamina 45%→20% after pets exceeded double a geared level-25 player's health/armor, while preserving intentional pet tanking; damage scaling was normalized by ability resource cost. [W3, December 12, 2023, Season of Discovery/Hunter](https://worldofwarcraft.blizzard.com/en-us/news/24030413/).
5. **Designers connect minion progression to itemization and constrain exceptional scaling:** PoE 3.19 introduced minion-focused gear to reward gear investment like other archetypes; Diablo IV 1.4.0 documented 100% owner-attribute inheritance and capped Cult Leader's scaling input at 100% attack-speed bonus. These establish mechanisms, not cross-class equality or achieved outcomes. [P2, “Master new Balance Changes”](https://www.pathofexile.com/kalandra); [D1, 1.4.0/Miscellaneous and Cult Leader](https://news.blizzard.com/en-gb/article/24140806/diablo-iv-patch-notes-1-3-1-5).
6. **Co-op imbalance can harm participation despite helping victory:** Warframe's developers reported that dominant AoE weapons left others little to do; the top five accounted for 47% of high-Mastery-Rank weapon usage. They halved Wukong's autonomous twin damage, kept a 3× marked-target bonus, and replaced infinite ammo with a shared owner ammo pool. [A1, “AREA OF EFFECT (AOE) WEAPON CHANGES” and “WUKONG”](https://www.warframe.com/en/patch-notes/switch/32-0-0).
7. **Controlled co-op research supports complementary roles, not an arbitrary damage-gap allowance:** Harris's 40-participant study found higher social engagement for asymmetric play (5.8 vs 5.2, p=.02), and a 72-participant study found tighter interdependence increased connectedness (5.81 vs 5.26, p=.002). Benefits differed by role; neither study measured acceptable class DPS inequality or fairness of boss-gated versus grind-based power. [H1, §§6.2.1, 6.2.6, 7.3, 7.6.1](https://www.theplayfulpixel.ca/files/harris2019-uw-ethesis.pdf).

## Question 1 — What spread is acceptable, and how is it measured?

### Riot League of Legends: the strongest explicit numeric framework found

**Attribution/type/date:** RiotRepertoir, developer intent, 2019-05-30 [R1]; Summoner's Rift Team, intent and developer-reported telemetry, 2020-06-30 [R2]. Scope: Summoner's Rift PvP.

| Audience (2019 definition) | Underpowered threshold | Overpowered threshold | Measurement |
|---|---|---|---|
| Average, below top 10% | 49% WR | 54.5% WR below average ban rate; 52.5% at five times average ban rate | Global win rate plus ban rate; average ban rate approximately 7% at publication |
| Skilled, top 10% except elite | 49% WR | 54%→52% over the same ban-rate range | Win rate plus bans |
| Elite, top 0.1% | 5% presence | 45% ban rate | Presence = combined pick/ban rate; small sample made WR unreliable |
| Professional, top five recognized leagues | 5% presence | 90% current-patch presence or 80% consecutive-patch presence | Draft behavior rather than game win rate |

Riot flags overpowered if **any** audience crosses its upper threshold; underpowered only if **all** audiences are below lower thresholds. A character can therefore be considered balanced through suitability for one audience rather than equal strength everywhere. “Champions With High Play Rates?” explicitly says popularity is not a reliable power indicator outside the highest play levels. “Really Frustrating Champs?” adds survey data and player conversation to separate power from frustration.

**Change/contrary evidence:** 2020 tightened average/skilled upper thresholds by **0.5 percentage points** (yielding 54%→52% and 53.5%→51.5% respectively by arithmetic), expanded Elite from top 0.1% to top 0.5% to obtain reliable WR samples, and loosened Pro thresholds because frequent Pro-driven nerfs did not yield enough diversity to justify frustration elsewhere. The article also permits game-health intervention below numerical thresholds (Yuumi's limited-interaction late-game healing). Do not present the 2019 table as a current 2026 contract.

**Measured scope:** R2 reports fewer threshold-crossing champions in 2020 than 2019, but provides no controlled causal proof. Its patch-10.12 viable-pool snapshot was Average 81%, Skilled 87%, Elite 30%, Pro 36%, solo queue 93%, all audiences 98%; this is a roster-share metric, not a damage spread or player-satisfaction measure.

**Constraint established:** tolerances depend on audience and metric; an outcome-band framework does not directly determine a PvE DPS/TTK band.

### World of Warcraft: practical parity with encounter-specific asymmetry

**Attribution/type/date:** Blizzard official developer AMA, September 12, 2012; Ion Hazzikostas and Greg Street [W1].

- Ion's response to Heroic Spine class stacking: comparable DPS can be promised on an Ultraxion-style encounter, not equal 20-second burst, 40-second burst, two-target cleave, eight-target AoE, and spread-target damage. He calls universal equality a boring homogeneous world. His concrete contrary case: guilds took **9–10 Balance Druids** to solve Heroic Ragnaros phase-two burst AoE, then failed the conflicting phase-three DPS check. Varying and conflicting mechanics limited stacking.
- Greg's response to the Moonkin Simulation Craft question says the most important numbers are what players actually do on live; internal testing, Blizzard simulations, beta/PTR data supplement them. He cautions that ranking alone obscures effect size: **15% versus 1.5% DPS delta** are very different. Neither number is stated as an acceptable threshold.
- Greg's melee/ranged answer says caster mobility improvements upset earlier equal-damage assumptions; melee received a bigger damage edge so actual encounter damage would even out. No size of edge specified.
- “Mists of Pandaria Buff and Debuff Design,” March 2012 pre-beta [W2], explicitly seeks grouping power, freedom to invite whom players want, and limited class stacking. Utility such as battle resurrection, slows, knockbacks, and damage while moving factors into composition beyond buffs. It accepts some cutting-edge stacking while aiming for ordinary groups to finish every encounter without a large bench.

**Constraint established:** neither a stationary damage meter nor class identity alone captures effective parity; compare actual encounters and composition pressure. **Numeric target gap:** no verified official universal ±5% or other DPS tolerance found. The AMA's 15%/1.5% comparison must not be promoted into such a target. “Bring the player” appears in the AMA question; the developer's answer qualifies it rather than promises universal interchangeability.

### FFXIV: account for utility and rotation, protect viable recruitment

**Attribution/type/date/version:** Naoki Yoshida, official Lodestone explanation, September 2022, Patch 6.21 [F1]. Reader extraction omits the displayed publication timestamp; the exact day is not independently established here. Version/date scope is explicit in the body.

The job base damage at the applicable item level accounts for **rotation difficulty, support actions and their effects**. Encounter mechanics produce unavoidable departures from ideal values. Yoshida says jobs are balanced independently before encounter difficulty is set; altering the whole job system to solve one excessively tight duty could harm overall role balance.

The boss HP was roughly **1% too high** relative to previous fourth-stage Savage raids; consequences included job exclusions and excessive difficulty. Testers use appropriate item level, materia, food, medicines, mitigation, and differing compositions, without debug commands. Usual release tuning adds **1–2% HP** to tester-clear values and also considers remaining time and burst potential. Paladin and Warrior additionally needed emergency job adjustment.

**Contrary evidence/limits:** some players cleared the overtuned version through better rotations, gear and repeated attempts; correcting it disappointed those near their first clear. Thus a small encounter error can matter at a hard check, but this does **not** show a 1% job spread is either required or sufficient, nor that grind is irrelevant. No published numeric job-to-job permissible band verified.

### Path of Exile: viability diversity rather than explicit equal-DPS band

**Attribution/type/date:** official “Developer Q&A: 187 Questions Answered!”, posted August 27, 2015 [P1]. GGG's response to the question starting “I would like to know if you plan to rebalance damage values…” says it sampled builds from **level 90–95 and 99–100 players** and judged diversity high relative to 1.3.x. It acknowledges part of the criticism that stationary melee suffered versus builds doing damage while moving, and says it is monitoring physical damage/mitigation.

**Evidence type:** developer-reported telemetry with no sample counts, diversity statistic, effect size or raw data. No acceptable DPS band given. This establishes that realized high-level build participation can be a balance lens; it does not establish all builds are equally strong, or exclude survivor-selection bias.

### Warframe and Destiny coverage

Warframe [A1, 2022-09-07, Update 32 Switch notes] gives **47%** high-Mastery-Rank usage across its top five weapons and qualitative automation/forced-choice/participation criteria, but no allowable Warframe DPS band. Buffs to underused augments explicitly seek build diversity.

Bungie's **“Dev Insights: The Final Shape Abilities Tuning Preview” (2024-05-22)** and **“This Week In Destiny – 11/22/2023”** were located [B1/B2]. Direct readers returned a JavaScript application shell; a browser attempt also did not expose article body. Indexed search attributed a Well of Radiance effective-invulnerability/dominance rationale and numerical nerfs, but **those un-reached body claims are not admitted as verified evidence here**. Numeric acceptable subclass bands remain a gap.

## Question 2 — Asymmetric scaling, pets, resource loops, and fixes

### WoW: owner-stat scaling can fix gear disconnect and create tanking/double-dip problems

**Intent/documented patch mechanics:** official cumulative hotfix article [W3]. Distinct game modes must not be conflated.

1. **Retail, November 15, 2023:** Hunter pet attacks now scale with weapon attack power. Developers explain a logging-related fix accidentally increased pet special-attack damage by about **32.5% at item level 450**. They retained weapon scaling to reward weapon upgrades, while reducing listed ability damage **32.5%**. These are the source's reported values, not a claim that percentage increase/decrease cancel algebraically exactly.
2. **Season of Discovery, December 12, 2023:** damaging pet abilities gain attack-power contribution based on Focus costs; pets stop gaining spell damage. Spell pets had scaled too well and physical abilities too little; higher-cost/less-frequent attacks receive more AP benefit per attack. Scorpid Poison spreads owner-AP contribution across **five stacks**, replacing its heavily front-loaded first stack (the stated ramp rationale is PvP).
3. **Same SoD update:** armor inheritance **45%→30%**; stamina **45%→20%**. Developers observed some pets exceeding **double** a geared level-25 player's HP/armor. Dedicated hunter pet tanking remains intended, but pets should not be the “objectively correct choice.” This is a co-op tanking boundary, not a prohibition on summons tanking.
4. **SoD, January 4, 2024:** Boon of Blackfathom no longer applies directly to pets because inherited owner stats plus direct world buff application “double dip” for unintended damage. The team planned to review interactions as progression phases changed.

**Constraint established:** progression inheritance, ability frequency/resource efficiency, survivability, direct/inherited buff stacking, and encounter tank substitution are separate axes. This source is a documented counterexample to “owner-stat scaling alone balances pets.” A full historical Hunter/Warlock inheritance chronology or stable pet-versus-owner damage-share target was not verified.

### Diablo IV: full owner-attribute inheritance plus caps and loop correction

**Intent/documented mechanics:** Blizzard archived notes [D1].

- **1.4.0, Build 53129, May 14, 2024, all platforms:** “Necromancer, Barbarian, Druid, and Sorcerer Companions now receive **100% of the player's attributes**.” The notes do not enumerate all inheritable stats, so this is **not** proof every item effect, Lucky Hit, barrier or proc is copied. The earlier 30% figure was found in community discussion but not verified against a historical primary source; omitted from the verified claim.
- Same patch, **Cult Leader Paragon Node:** minions gain **30% multiplicative damage for each 20% attack-speed bonus**, replacing 15%, with scaling input capped at **100% attack-speed bonus**. This documents an investment-scaling cap, not a class-level cap or global minion attack-speed ceiling.
- **1.4.3, June 17, 2024:** Holy Bolts Elixir damage triggered by pets such as Necromancer minions scaled unintentionally high. Blizzard changed the elixir from enemy-health scaling to **weapon-damage scaling**, specifically reducing effectiveness against the toughest high-Pit enemies, alongside Pit enemy-HP reductions. The same patch states the goal that **most builds reach Pit tier 60** to obtain the final Masterworking material tier [D1, opening developer note and Bug Fixes]. That is a numeric content-access target, not equal peak damage.

**Constraint established:** shared owner progression can coexist with minion-specific investment; effects driven by enemy health can bypass expected gear progression; caps apply to a named scaling term, not necessarily the whole build.

### PoE: gear investment parity and removal of persistent snapshot advantages

- **3.19, Lake of Kalandra, August 2022 [P2]:** new minion-focused item base types offer damage and survivability crafting, explicitly to reward finding good items like other archetypes. This is strong primary evidence of correcting archetypes that benefited differently from item progression; no comparative outcome numbers provided.
- **“Snapshotting,” posted June 18, 2014, planned 1.2.0; edited October 10, 2014 [P3]:** Mark_GGG, Nick and Brian describe minion builds temporarily equipping supports/items, summoning, then removing them while retaining benefits and avoiding downsides. Mon'tregul's Grasp's intended tradeoff—few powerful zombies versus many normal zombies—was bypassed. Non-snapshot players felt weaker and, the developers say, usually were. Tedious setup became perceived obligation.
- Fix: ongoing minion/buff properties dynamically reflect changed gear, passives and supports, including max minion count. Explicit exception: a minion created at a set level does **not** immediately level when its enabling gem levels; newly raised minions or respawning into a new instance update that level. Thus “everything updates immediately” would overstate the source.

**Constraint established:** summoning must retain real tradeoffs across equipment changes; dynamically updating inherited stats and checking minion limits are distinct from pet leveling. Patch intent does not prove the achieved balance.

### Guild Wars: caps and maintenance costs; Guild Wars 2: AoE protection distinct from tank immunity

**Primary patch text preserved on ArenaNet-hosted community wiki, not independently captured publisher release page:** April 26, 2006 [G1], “Skill Changes / General”: without Death Magic, at most **two undead servants**, plus **one per two ranks**. “Necromancer”: Blood of the Master changed to a **5% health sacrifice plus 2% per creature healed**, making sustaining a larger army cost more. No developer causal claim that these changes fixed trivialized PvE is present.

**Community mechanical report, not developer intent:** [G2, Minion, revision 2731934, accessed 2026-10-05] records increasing HP degeneration, **+1 pip every 20 seconds**, max displayed degeneration 10 pips, and limits **2 at rank 0, 8 at 12, 10 at 16, 12 at 20**. It says minions do not flee AoE and may cluster. The documentation includes anomalies and should not be treated as decompiled verification.

**October 23, 2015 GW2 patch text [G3, “Profession Balance / General”]:** player-owned minions take **95% reduced damage and condition duration** from nonplayer attacks not specifically targeting them, but full effects when targeted. This separates surviving incidental PvE AoE from immunity while tanking. “Ranger” also makes Spirit of Nature healing scale with **15% of owner's healing power**, while cutting base healing about **35%**. These are mechanics; the source does not establish a desired pet damage-share percentage.

### Warframe: close the companion's resource bypass without deleting its active niche

**Update 32, September 7, 2022 [A1, WUKONG / Celestial Twin Changes].** Developers call Wukong mobile/tanky and say the twin could effortlessly carry players through most content. Changes: **halve** twin damage; retain **3×** bonus against actively marked enemies; introduce self-stagger; replace infinite ammo with a shared owner/twin ammo pool and fallback weapon switching. Explicitly, infinite ammo had let high-impact low-ammo weapons operate outside their intended balance. This establishes that merely inheriting the owner's loadout leaves a major balance loophole if the companion avoids its resource costs.

## Question 3 — Perceived fairness in co-op; distinct strengths; progression gates

### Controlled studies: asymmetric roles can improve connectedness, but not uniformly

**Measured primary research:** John Harris, University of Waterloo doctoral thesis, 2019 [H1]; chapters 3/5 incorporate CHI PLAY 2016 DOI **10.1145/2967934.2968113**; chapters 6/7 incorporate CHI 2019 DOI **10.1145/3290605.3300239** (thesis Statement of Contributions).

- **Study 1, §5.1.1, 34 participants / 17 pre-existing-relationship pairs**, university-area sample. §5.3.6 thematic interviews: participants almost universally liked relying on each other; an optional support role could feel “useless” or unnecessary. Combat foregrounded Kirk, puzzle/teleportation sections foregrounded Scotty. Participants also reported frustration when weaker partners spent most of their time bubbled rather than playing. **Report type:** qualitative participant experience, not statistical fairness measurement.
- **Study 2, §§6.2.1/6.2.6, 40 participants / 20 pairs**, median age 21. Due to a counterbalancing clerical error, inferential analysis used only the first trial in a between-participant analysis. Asymmetric play increased connectedness **M=4.0 vs 3.0, p=.04**, and behavioral engagement **5.8 vs 5.2, p=.02**. Important contrary result: connectedness improvement was significant for Kirk **p=.001**, not Scotty **p=.66**. This is evidence against assuming the support class shares the carry's satisfaction simply because the pair's mean improves.
- **Study 3, §§7.3/7.6.1, 72 participants / 36 pairs**, median age 23: tighter coupling increased connectedness **5.81 vs 5.26**, pairwise **p=.002**, overall **F(2,142)=5.8, p=.004**. Medium was **5.51**; loose→medium was not significant, and medium→tight was marginal (**p=.054**). Behavioral engagement also improved; its scoring direction was lower=more engaged.

**Limit:** short-session prototype games, mostly university students, dyads with pre-existing relationships; no sustained RPG leveling economy, no eight-player guild setting, and no manipulated DPS inequality or fairness scale tied to a numeric class gap. Distinct roles and meaningful dependency are supported; “players accept ±25% class TTK when everyone has a niche” is **not** established.

### Direct co-op designer evidence and counterexamples

- **Warframe [A1, AoE rationale]:** the developer's three tests are automation, overly dominant choices, and disruption of other players. Top-five usage **47%** is developer-reported telemetry; “players asking us to change these weapons because they leave so little for others to do” is attributed feedback, not a representative survey. Developers explicitly acknowledge the popular power fantasy and initially aim to limit frequency via ammo rather than remove high impact. This directly contradicts any blanket claim that PvE imbalance cannot hurt teammates.
- **WoW [W1]:** different encounter strengths are explicitly valued; ranking positions alone can inflate perception when effects are statistically tiny. Yet the same source recognizes composition exclusion at razor-edge checks. This is designer reasoning, not a measured tolerance survey.
- **FFXIV [F1]:** rotation difficulty and support justify different base damage, but tight checks can make those strengths insufficient to preserve recruitment. The correction itself caused disappointment among players who had invested in the original challenge. Both sides of the perceived-fairness problem are documented by the developer.
- **PoE [P3]:** unintuitive snapshotting allowed real extra power, created perceived pressure to do tedious setup, and removed tradeoffs. This is designer-reported correspondence between actual and perceived disadvantage; no experimental comparison.

### Power tied to progression gates rather than grind

**Verified designer/mechanics evidence, not causal fairness proof:**

1. **WoW Cataclysm postmortem, Greg Street, March 7, 2012 [W4], final “What lessons…” answer:** the plan offered incremental gear upgrades while **reserving tier sets for actual boss kills**. The same article's “What didn't work…” warns that difficult heroics left some friends unable to obtain prerequisite raid gear because no alternative existed. This documents both milestone rewards and the access cost of a hard progression bottleneck.
2. **Contrasting official policy within the same year:** the September 2012 AMA [W1, Dave Kosak, Black Prince legendary answer] says everyone, including Raid Finder players, could start the legendary; guild players gather faster, and final completion requires participation across all patches. The March postmortem disfavored ubiquitous guaranteed legendaries resembling a reputation bar, whereas this later statement emphasizes broad participation and reducing guild drama. These are different systems/stages and policy emphasis, not evidence for one universal anti-grind rule.
3. **Diablo IV [D1, 1.4.3]:** developers targeted “most builds” reaching **Pit 60**, the gate to the final material tier, by buffing underperformers and easing Pit difficulty. This is a practical accessibility threshold for endgame progression. The notes do not show that players perceived it as fairer than XP grind.
4. **Warframe [A1, Kahl's Garrison/Archon Hunts]:** weekly gameplay auto-ranks the new syndicate rather than requiring Standing; Archon Hunt rewards drop once per week despite replayability. These document milestone/time gates, but do not isolate class-fairness effects.

**Constraint established:** the cited designers protect both recognizable progression achievements and access to meaningful group play; their evidence does not resolve whether boss-gated class levels versus grind-based class levels feel fairer in this server.

## Gaps

- **No sourced universal co-op class spread band.** Riot's explicit numerical framework is PvP win rate. WoW's 15%/1.5% contrast is not a target. FFXIV's 1% issue is boss HP, not job spread. To settle a numeric PvE benchmark requires an official statement defining metric, gear/progression cohort, encounter population, percentile and acceptable band.
- **No verified Bungie body evidence.** B1/B2 were located via indexed search but native read returned application shells; browser opening B1 also failed to expose text. A reachable official archived body or official video with timestamp would settle it. Numerical indexed quotations are intentionally not treated as verified.
- **No full Hunter/Warlock pet-scaling chronology or prescribed damage-share target.** W3 covers a gear-scaling change, survivability, resource normalization and double-dipping, but not all historical expansions or Warlock design. Would need official historical patch notes/talks with coefficients and rationale.
- **Guild Wars archival provenance is limited.** Primary patch wording survives on official-hosted community wiki; raw client code or publisher archival copies would strengthen it. G2's AI/degeneration observations are community documentation, not independently measured.
- **Direct class-imbalance fairness study missing.** H1 measures connectedness/engagement and qualitative dependency, not numerical DPS tolerance. A controlled co-op experiment manipulating damage gap, visible contribution and complementary utility, with fairness and participation measures, would answer the exact question.
- **Boss gate versus grind fairness missing.** W4/W1/D1/A1 document policies and tradeoffs but no controlled comparison or telemetry linking the progression mechanism to perceived fairness.
- **PoE diversity telemetry lacks denominator.** P1 states samples at levels 90–95 and 99–100; raw data, sampling rules and a quantitative diversity statistic are absent.
- **Researcher-hosted 2016 article PDF timed out; ACM DOI returned 403.** Its relevant material was reached in the author's 2019 thesis, with chapter provenance explicitly declared. Do not claim the original PDF was read.
- No independent repository facts were needed for these external questions; no assertion about implemented server formulas is made.

## Citations

All “re-reached” entries below had actual article/patch/paper body or the cited bounded passage retrieved during this run; search snippets alone are excluded. Retrieval date 2026-10-05. Headings supply locators for web pages whose line numbers are unstable.

- **R1 — re-reached:** RiotRepertoir, * /dev: Champion Balance Framework*, 2019-05-30. https://www.leagueoflegends.com/en-us/news/dev/dev-champion-balance-framework/ — “Updating Our Approach”; “Champions With High Play Rates?”; “Champions With High Mastery Curves?”; “Really Frustrating Champs?”. Official developer intent.
- **R2 — re-reached:** Summoner's Rift Team, */dev: Balance Framework Update*, 2020-06-30. https://www.leagueoflegends.com/en-us/news/dev/dev-balance-framework-update/ — “Combating Power Creep”; “Overhauling Elite”; “Loosening Pro Play Thresholds”; “Meta Diversity Targets.” Official intent and attributed telemetry.
- **W1 — re-reached:** Blizzard, *Transcript: Reddit AMA with World of Warcraft Developers*, September 12, 2012. https://worldofwarcraft.blizzard.com/en-us/news/7207171/transcript-reddit-ama-with-world-of-warcraft-developers — Ion/Heroic Spine; Greg/Moonkin Simulation Craft and melee-versus-ranged; Dave/Black Prince legendary quest. Official direct developer statements.
- **W2 — re-reached:** Ghostcrawler, *Mists of Pandaria Buff and Debuff Design*, March 2012, pre-beta. https://worldofwarcraft.blizzard.com/en-us/news/4574894 — opening group-buff goals and utility notes. Official page shows March 9; contemporary secondary locator was March 8, likely publication/localization timing difference; claims attributed to month/pre-beta scope rather than silently resolving exact day.
- **W3 — re-reached:** Blizzard, cumulative *Hotfixes: January 8, 2024* article. https://worldofwarcraft.blizzard.com/en-us/news/24030413/ — dated subsections November 15, 2023 (Retail/Hunter), December 12, 2023 (SoD/Hunter), January 4, 2024 (SoD/Boon). Later article title does not date every entry. Official patch mechanics and developer notes.
- **W4 — re-reached:** Greg Street interview, Daxxarri, *Cataclysm Post Mortem*, March 7, 2012. https://worldofwarcraft.blizzard.com/en-us/news/4519250/cataclysm-post-mortem-greg-ghostcrawler-street — “What didn't work out as planned?”; “What lessons…goals for Mists?”. Official intent/postmortem observations.
- **F1 — re-reached:** Naoki Yoshida, *Adjustments to Abyssos: The Eighth Circle (Savage)*, September 2022, Patch 6.21. https://na.finalfantasyxiv.com/lodestone/topics/detail/6d95409248d3ab3b5dbc0c8a04340b373870140b — all three named analytical sections and conclusion. Exact publication day not independently recovered by reader.
- **P1 — re-reached:** GGG, *Developer Q&A: 187 Questions Answered!*, August 27, 2015. https://www.pathofexile.com/forum/view-thread/1409553 — physical damage/high-level build diversity question, located by its quoted opening in Question 1. Browser-retrieved body. Official reported telemetry; no raw dataset.
- **P2 — re-reached:** GGG, *Lake of Kalandra*, 3.19 promotional overview, launch August 19, 2022 PC/Mac. https://www.pathofexile.com/kalandra — “Master new Balance Changes.” Official minion itemization intent.
- **P3 — re-reached:** Mark_GGG, Nick and Brian, *Snapshotting*, posted June 18, 2014, revised October 10, 2014, planned 1.2.0. https://www.pathofexile.com/forum/view-thread/951414 — “Removing snapshotting results in a better game”; “Same skills, different behaviours”; “Areas…Minions.” Official intent and implementation description.
- **D1 — re-reached:** Blizzard, *Diablo IV Patch Notes (1.3–1.5)*. https://news.blizzard.com/en-gb/article/24140806/diablo-iv-patch-notes-1-3-1-5 — 1.4.0 Build 53129, May 14, 2024 / Miscellaneous and Necromancer/Cult Leader; 1.4.3 June 17, 2024 / opening note, End-Game, Bug Fixes. Official patch mechanics. Older linked notes at https://news.blizzard.com/diablo4/23964909/ returned 404; archive supersedes that dead link for these claims.
- **G1 — re-reached:** ArenaNet patch text archived on Guild Wars Wiki, April 26, 2006. https://wiki.guildwars.com/wiki/Game_updates/20060426 — Skill Changes/General and Necromancer. Official-hosted community-maintained archival transcription; revision 854575.
- **G2 — re-reached:** Guild Wars Wiki, *Minion*. https://wiki.guildwars.com/wiki/Minion — Defense, Control of minions, Counters; revision 2731934. Community mechanical report, explicitly not independent primary mechanical verification.
- **G3 — re-reached:** ArenaNet patch text archived on GW2 Wiki, October 23, 2015. https://wiki.guildwars2.com/wiki/Game_updates/2015-10-23 — original Update/Profession Balance/General and Ranger. Official-hosted community-maintained archival transcription.
- **A1 — re-reached:** Digital Extremes, *Veilbreaker: Update 32*, Switch, September 7, 2022. https://www.warframe.com/en/patch-notes/switch/32-0-0 — AREA OF EFFECT (AOE) WEAPON CHANGES; General Warframe Changes/WUKONG; WARFRAME AUGMENT BUFFS PART 2; KAHL'S GARRISON; ARCHON HUNTS. Native and browser body reached. Intent, reported telemetry, attributed player feedback, patch mechanics.
- **H1 — re-reached:** John Harris, *Leveraging Asymmetry and Interdependence to Enhance Social Connectedness in Cooperative Digital Games*, doctoral thesis, University of Waterloo, 2019. https://www.theplayfulpixel.ca/files/harris2019-uw-ethesis.pdf — Statement of Contributions (roman p.iv); §§5.1.1, 5.3.6, 5.5.3, 6.2.1, 6.2.6, 7.3, 7.6.1 (printed pp.71,79,82,92,96–98,110,113). Primary study methods/results, author-hosted full text.
- **H2 — record re-reached, original article body NOT re-reached:** Harris, Hancock & Scott, CHI PLAY 2016, DOI https://doi.org/10.1145/2967934.2968113 . Author institution record https://uwaterloo.ca/touchlab/references/leveraging-asymmetries-multiplayer-games-investigating reached; ACM page 403; author PDF https://markhancock.ca/pmwiki/uploads/Publications/p350-harris.pdf timed out. Findings cited via H1, not inferred from abstract.
- **H3 — DOI identified in re-reached H1, original article NOT independently re-reached:** Harris & Hancock, *To Asymmetry and Beyond!*, CHI 2019, https://doi.org/10.1145/3290605.3300239 . Findings cited via H1.
- **B1 — NOT body re-reached:** Bungie, *Dev Insights: The Final Shape Abilities Tuning Preview*, indexed May 22, 2024. https://www.bungie.net/7/en/News/Article/tfs-abilities-tuning-preview . Native read and ?hidenav=true returned app shell; browser did not expose body. Locator only; no body claim admitted.
- **B2 — NOT body re-reached:** Bungie, *This Week In Destiny – 11/22/2023*. https://www.bungie.net/7/en/News/Article/this-week-in-destiny-11-22-23 . Search locator only; no body claim admitted.
