# Fixed difficulty versus player-count scaling

Research date: 2026-10-05. Evidence only; no server settings recommendations. **Important version conflict:** the brief calls the supplied DLL 1.0.16, but its own `Version.CurrentVersion` is 1.0.12. Exact 1.0.16 is therefore an explicit gap, not a verified claim.

## Summary

1. **Observed code:** the supplied Valheim assembly defaults to +30% effective enemy health and +4% non-player-attacker damage per additional nearby player, counting strictly within 100 horizontal units and capping ordinary counting at five. Health scaling is implemented as damage reduction recalculated on hits, not extra spawned HP. `/tmp/lembitu-premium/FixedVsScaled/Game.cs:138-144,1111-1139`; `Character.cs:2268-2272,2413-2418`; `Player.cs:5483-5493`.
2. **Version gap:** that same DLL identifies itself as 1.0.12, not requested 1.0.16; its measured SHA256 matches the September 12 reference lock. `Version.cs:168`; `lib/valheim/refs.lock.json:2-3,13`.
3. **Developer intent:** Blizzard moved most WoW raiding away from rigid 10/25 sizes because of roster/social tensions, scheduling friction and difficulty balancing the two sizes; retained fixed 20-player Mythic for razor-edge tuning. Bashiok, 2013-11-09, [“Flex Lives”](https://worldofwarcraft.blizzard.com/en-us/news/11499600).
4. **Developer intent plus shipped mechanics:** Diablo III's Wyatt Cheng explicitly acknowledged that solo could feel easier/more efficient, and reduced extra-player HP from 70% to 50% to compensate coordination inefficiency and allow less-geared friends to improve the group. [2013-04-02 journal, “Monster Health”](https://news.blizzard.com/en-us/article/9382478/developer-journal-multiplayer-improvements); [1.0.8 patch, “Monsters”](https://news.blizzard.com/en-us/article/9647272/patch-1-0-8-now-live).
5. **Measured observational evidence, not a causal trial:** Ducheneaut et al. observed 129,372 WoW characters in 2005; grouping rose sharply in late-game content too difficult to solo, while almost-never-grouped characters leveled about twice as efficiently. CHI 2006, pp. 3–5, “Research Methods”/“The social factor: grouping patterns”; [paper mirror](https://paperzz.com/doc/7538206/alone-together%3F-exploring-the-social-dynamics-of-massively).
6. **Contrary shipped change:** Capcom added a two-player difficulty to Monster Hunter World in September 2019, rather than treating all multiplayer groups identically. [Ver. 10.11, “Major Changes”](https://www.monsterhunter.com/update/mhw/us/ver10_10.html). Exact HP ratios and designer rationale are not established by these patch notes.
7. **Report, not telemetry:** Dark Souls' community documentation describes +50% boss HP per phantom but says co-op usually remains easier; Four Kings and low-contribution NPC summons are exceptions. [Wikidot, revision 73, 2021-12-20, “Increase in Boss HP”](https://darksouls.wikidot.com/co-op). Scaling itself does not establish that grouping is punished.

## 1. Difficulty versus player count: mechanics, rationale and complaints

### Distinctions needed to interpret the evidence

A **fixed raid size** is an encounter tuned for a bounded roster with an admission limit; it is not the same policy as a fixed encounter allowing arbitrary extra combatants. WoW's fixed 20-player Mythic cannot be zerged by bringing a twenty-first player. A **sublinear** HP increase can preserve a group advantage even though individual enemy durability rises. The following descriptions separate first-party mechanics/intent from community documentation; an “official wiki” is community-authored and is not a developer statement.

### WoW fixed 10/25, Flex, Normal/Heroic and Mythic

**Intent, first party, 2013-11-09:** Bashiok's “Warlords of Draenor: Dungeons and Raids,” “Flex Lives,” says parallel 10- and 25-player raids sought to offer the same epic experience regardless of guild size, with similar challenge and reward, but balancing the two had inherent problems and rigid sizes created social tensions. Flex was described as extremely popular, accommodating variable schedules, permitting extra friends and letting leaders fill spots. This is an unquantified developer observation, **not published telemetry**.

The 2013 announcement planned flexible Normal/Heroic 10–25; that is the announcement scope, not verification of all later releases. It retained fixed 20 Mythic because incremental sizes prevent razor-edge tuning. “1, 2, 3, 4, I Declare a Thumb War” also says loot drops would scale with roster size. Source: [Blizzard](https://worldofwarcraft.blizzard.com/en-us/news/11499600), headings above.

**Transition documentation, 2014-05-06:** Blizzard confirms flexible Normal/Heroic and fixed 20 Mythic replacing separate Flex mode. [Siege of Orgrimmar Changes](https://worldofwarcraft.blizzard.com/en-us/news/14014199/siege-of-orgrimmar-changes-in-patch-60-and-warlords-of-draenor), introduction and bullets, directly re-reached.

**Constraint established:** fixed rosters give precise encounter-composition/tuning control but impose attendance and exclusion costs; flex addresses those costs without requiring challenge to disappear. These are Blizzard's stated tradeoffs, not a universal ranking of systems.

### Valheim vanilla supplied assembly

See question 3 for full traced mechanics, version conflict and exact table. This is nearby-player scaling, **not online-server-population scaling**. Its health factor is sublinear relative to the number of equal contributors. No Iron Gate statement specifically explaining these coefficients or the five-player cap was located. Do not attach generic “preserve challenge” intent to Iron Gate without a source.

### Terraria Expert/Master

**Community-authored official documentation, retrieved 2026-10-05:** [Expert Mode, “Bosses”](https://terraria.wiki.gg/wiki/Expert_Mode), retrieved revision 1027876, says Expert boss HP equals Classic HP × boss-specific boost factor × multiplayer factor. All Expert changes also apply to Master (introduction). Master baseline is additional difficulty, not a different claim that each extra player always adds the same percentage.

The multiplayer factor starts at 1; second player adds 0.35; subsequent additions follow `a[n+1] = a[n] + (1-a[n])/3`. Thus factors for 1/2/3/4 players are approximately 1/1.35/1.916667/2.627778. At ten or more players apply `(factor*2+8)/3`; cap 1000. HP is set when the boss spawns; later joining does not update it. Boss-specific base boost factors differ (wiki examples: Skeletron 2.0, Plantera 1.4). The wiki says all damaging participants receive a treasure bag, so increased HP is not the only multiplayer mechanic.

**Limits:** not independently decompiled Terraria; the article's other source-code footnotes reference desktop 1.4.5.6 and warn the current version is 1.4.5.8, but the boss formula has no direct method citation there. Exact historical consistency and Re-Logic's rationale are unknown. No prevalence estimate for player complaints was found. Constraint: distinguish baseline mode difficulty, boss-specific scaling, spawn-time counting, and per-participant rewards.

### Monster Hunter World / Iceborne

**First-party shipped change:** Capcom's [Ver. 10.11 notes](https://www.monsterhunter.com/update/mhw/us/ver10_10.html), available 2019-09-05, “Major Changes”: “Two player difficulty has been added to multiplayer”; two-player quests use it. This establishes a separate two-person tier, not an exact multiplier or per-person continuous formula.

**Secondary reporting, 2019-06-21:** Dustin Bailey reports older World had solo/multiplayer tiers with no differentiation among group sizes and no downscale after someone left; forthcoming update adds two-player tier, retaining common 3/4 tier and downscaling on departures. [PCGamesN article](https://www.pcgamesn.com/monster-hunter-world/multiplayer-scaling), opening paragraphs, links to IGN report. These details beyond Capcom's patch quote remain secondary in this run.

**Player reports, 2018-08-21 and 2018-10-20:** [Steam thread](https://steamcommunity.com/app/582010/discussions/0/1735462352482827576), directly re-reached: Vanessa corrects jscjml's initial approximate 2.6 HP ratio to 2.2, and jscjml accepts in post 8. Guizin complains about difficult part breaks on October 20, post 10; Marcus101RR claims a Cheat Engine observation in post 9. These are not independently reproduced experiments or universal first-party ratios. Exact monster/quest-dependent first-party HP values remain a gap.

**Constraint established:** multiplayer difficulty tier granularity matters for a duo, and departure behavior matters separately. The patch change alone does not prove its designer motive or measured benefit.

### Deep Rock Galactic

**Community-authored official documentation:** [Difficulty Scaling](https://deeprockgalactic.wiki.gg/wiki/Difficulty_Scaling), retrieved revision 50593 on 2026-10-05, “Normal Scaling” and “Resistance Scaling,” describes separate hazard/player-count effects on enemy damage, counts and category-dependent resistance. At Hazard 5 for 1/2/3/4 players: enemy damage 2.8/3.0/3.2/3.4; count modifiers .85/.85/1.25/1.50; normal enemy resistance 1.20 for every size; large resistance 1.20/1.20/1.40/1.50; extra-large .75/.80/1.20/1.70. Resistance divides incoming damage, equivalent to effective HP; not every enemy gets per-player HP inflation.

The wiki explicitly attributes small solo-to-duo spawn changes to losing solo helper Bosco. **This explanation is a wiki claim, not a sourced Ghost Ship designer statement.** The page carries a cleanup warning and does not give a verified game-build version for these tables. Its linked March 9, 2023 developer stream concerns Deep Dive hazard naming, not sufficient evidence for the player-count rationale. No designer rationale or complaint prevalence independently verified.

**Constraint established:** spawn pressure, lethal hits, durable specials and the solo companion are separate balancing axes; a universal HP-per-person model would misdescribe DRG.

### Dark Souls

**Community documentation, original Dark Souls scope, revision 73 dated 2021-12-20:** [Co-op, “Increase in Boss HP”](https://darksouls.wikidot.com/co-op) states one phantom gives 1.5× boss HP, two 2×; most encounters still become easier. Its specific contrary cases are Four Kings (insufficient DPS leaves multiple kings alive) and Gaping Dragon NPC helpers contributing little while increasing HP. This supports the existence of “solo can be better” advice, **not frequency of the problem or a FromSoftware intent statement**, and must not be generalized to DS2/DS3.

**Primary intent, adjacent game rather than exact DS scaling:** Hidetaka Miyazaki's [PlayStation interview](https://blog.playstation.com/2022/01/28/an-interview-with-fromsoftwares-hidetaka-miyazki/), 2022-01-28, question “How has the ongoing discourse around game difficulty and accessibility…”, says Elden Ring did not intentionally reduce difficulty, but easier access to multiplayer assistance and more freedom were expected to raise completion. This is a prospective designer expectation, not measured clear-rate evidence, and not an explanation of Dark Souls' 50% HP coefficient.

**Constraint established:** count scaling can still coexist with help as an accessibility lever; low-contribution helpers and timed enemy accumulation can invert the advantage.

### Diablo II /players X and Diablo III

**First-party Diablo II documentation:** [Arreat Summit, “Monster Experience In Multiplayer Games” and “Upping the Party Members in Single Player and TCP/IP”](https://classic.battle.net/diablo2exp/basics/experience.shtml), undated Lord of Destruction documentation (site copyright 2019), gives spawned monster HP `baseHP*(n+1)/2` and XP `baseXP*(n+1)/2`. `/players X` sets effective population up to eight in single player/open Battle.net/TCP/IP, raising life, XP and item drops. Simulated extras are in-game, not party members. Thus /players 8 gives 4.5× base HP/XP without actual eight-player cooperation. Do not conflate reward/difficulty selection with a mechanism forcing groups.

**First-party intent, 2013-04-02:** Wyatt Cheng's [Developer Journal](https://news.blizzard.com/en-us/article/9382478/developer-journal-multiplayer-improvements), “Making Two Heads Actually Better Than One,” acknowledges solo autonomy, pausing, route selection, coordination costs and lost followers. “Monster Health” reduces 70% extra HP per player to 50%, producing 1/1.5/2/2.5 for one through four players. Goal: compensate inefficiency, allow a less-geared friend to be beneficial, tolerate temporary separation. “Multiplayer Bonuses” adds explicit +10% XP/Gold Find/Magic Find per extra player up to 30%. “Identify All” reports internal playtests finding full inventories and identifying in town a common separation point; no sample size or quantified result published.

**First-party shipped proof:** [1.0.8.16416 notes](https://news.blizzard.com/en-us/article/9647272/patch-1-0-8-now-live), 2013-05-07, “General—Multiplayer Co-Op” and “Monsters—General,” confirm the 50% health and 10%-per-extra-person reward changes. This is a direct case of scaling being softened, not abolished, to support grouping.

## 2. Evidence that fixed difficulty incentivizes grouping, and costs

### Measured evidence and its causal boundary

Ducheneaut, Yee, Nickell and Moore (CHI 2006), *“Alone Together?” Exploring the Social Dynamics of Massively Multiplayer Online Games*, pp. 407–416 (paper internal pp. 1–10), [reachable full-text mirror](https://paperzz.com/doc/7538206/alone-together%3F-exploring-the-social-dynamics-of-massively), “Research Methods” and “The social factor: grouping patterns” (internal pp. 2–5): census every 5–15 minutes on five servers from June 2005; 129,372 unique characters, not necessarily distinct humans. Grouping stabilized near 40% with increasing level, then rose strongly after 55 and exceeded half of playtime from level 59. Authors connect this to endgame dungeons too difficult to enter alone. Almost-never-grouped characters leveled about twice as efficiently as other grouping bands. Warlocks spent about 30% of time grouped versus priests about 40%; authors report significant class differences.

**Evidence type:** observational measurement plus author interpretation/ethnography. It supports that difficult, group-dependent endgame is associated with grouping, and that class solo viability changes grouping rates. It **does not isolate fixed HP from loot, encounter mechanics, class complementarities, leveling stage or player selection**. It is not an experiment comparing fixed versus scaled Valheim bosses.

“Size of guilds and commitment levels”/“Impacts of guild membership…” (internal pp. 5–6): average observed guild 14.5 characters, median six, 90th percentile 35; 13% of multi-member guilds in a June week absent in July week. Guilded characters played longer controlling for average level; authors say this seems consistent with social pressure, not proof of causation. Their network analysis says guild size has diminishing returns in forming tightly connected play groups. **Constraints from evidence:** roster size is not equal to simultaneously available reliable combatants; mandatory grouping has organization/commitment costs. No eight-friend/off-hours-specific effect size established.

### Intent/report evidence for benefits and costs

- **Blizzard's fixed Mythic rationale:** precise competitive tuning; no claim that fixed sizes were selected primarily to prevent solo progression. Fixed-size raid evidence cannot alone justify arbitrary-size fixed encounters.
- **Blizzard's Flex rationale:** rigid groups produce bench/exclusion tension and schedule friction. This is particularly relevant to availability, but no off-hours telemetry is published in the cited post.
- **Cheng's grouping rationale:** nominal arithmetic advantage is insufficient when logistics and unequal power consume it; shipped sublinear scaling plus reward bonuses are evidence against the premise that eliminating scaling is necessary to incentivize grouping.
- **Primary community report with disagreement:** [WoW Season of Discovery forum, 2025-04-16](https://us.forums.blizzard.com/en/wow/t/pugging-in-sod-is-turning-into-a-joke/2093534), posts 6/10/19 complain of overfilling groups to speed content/carry weaker players and dilute individual loot. Post 7 disputes that 40-player groups trivialize the newest raid and cites a claimed 1.4% clear rate. That statistic is **unverified poster telemetry**, not adopted here as measured fact. Posts 2/18 also disagree about prevalence of abusive loot practices. Scope is SoD's particular raid implementation, not retail flex. This documents competing experiences: additional people can ease fixed-tuned content, but tuning and reward allocation can overwhelm or reverse perceived benefit.

### Transparent arithmetic, not empirical evidence

[INFERENCE] If an encounter has fixed health H and each contributor adds damage rate d with no coordination loss, group time is H/(n*d). With Valheim-style effective health H*(1+.3*(n-1)), it is H*(1+.3*(n-1))/(n*d), still lower than solo for n>1. These idealized equations show why “scaling punishes friends” is not implied by rising HP. They exclude aggro relief, support, deaths, class synergies, collision, mechanics and logistics; not recommendations or predictions of this pack.

No controlled fixed-versus-scaled study or published designer telemetry quantifying increased grouping, solo abandonment or larger-group trivialization was found in this run. The credible conclusion is narrower: mechanics create a potential group advantage; published behavioral evidence and designer accounts show both grouping responses and substantial costs, not a universal measured policy outcome.

## 3. Exact Valheim decompile: supplied binary, not verified 1.0.16

### Provenance and reproducibility

Executed `~/.dotnet/tools/ilspycmd -t Game lib/valheim/assembly_valheim.dll` and corresponding `Character`, `Player`, `Version` commands. Decompiled files are in `/tmp/lembitu-premium/FixedVsScaled/` (ILSpy 11.0.0.9375). `shasum -a 256` observed `1231fc2ffdbe6038ba622b8646c2084980d06962e5f8521ae5a0b886be0f1c61`, identical to `lib/valheim/refs.lock.json:13`; lock extraction date/source are `:2-3` (2026-09-12). `Version.cs:168` declares `CurrentVersion = new GameVersion(1, 0, 12)`. **Cannot call these exact 1.0.16 values without a verified 1.0.16 binary.**

### Exact defaults and count

- `Game.cs:138`: `m_difficultyScaleRange = 100f`.
- `Game.cs:140`: `m_difficultyScaleMaxPlayers = 5`.
- `Game.cs:142`: `m_damageScalePerPlayer = 0.04f`.
- `Game.cs:144`: `m_healthScalePerPlayer = 0.3f`.
- `Game.cs:1111-1126`: count players near supplied position; minimum one, maximum five. However positive `m_forcePlayers` returns immediately before clamping (`:1113-1115`); `SetForcePlayerDifficulty` is `:1106-1108`. **The five cap is ordinary counting, not a universal cap on developer force override.**
- `Player.cs:5483-5493`: iterates `s_players`, counts `Utils.DistanceXZ(player.position, point) < range`. Horizontal only, strict inequality; no explicit alive/participating/attacking check in this helper. Therefore “actively fighting” is not the criterion visible here.

### Exact factors

Let p be that returned count. `Game.cs:1129-1132`: player damage scale = `1 + .04*(p-1)`. `Game.cs:1135-1139`: enemy incoming damage scale = `1 / (1 + .3*(p-1))`. `GetDifficultyHealthScale` is not the helper used in the inspected Game type; the relevant health mechanism is `GetDifficultyDamageScaleEnemy`.

| Ordinary nearby player count | Effective enemy HP factor | Damage factor for non-player attacker |
|---:|---:|---:|
| 0 or 1 | 1.00 | 1.00 |
| 2 | 1.30 | 1.04 |
| 3 | 1.60 | 1.08 |
| 4 | 1.90 | 1.12 |
| 5+ | 2.20 | 1.16 |

These are additive relative-to-solo factors, not compounding 1.3 or 1.04 repeatedly. Effective HP is terminology for division of damage, **not observed maximum-HP mutation**.

### Caller trace and timing

`Character.cs:2268-2272` applies `GetDifficultyDamageScalePlayer` to hits with a non-null non-player attacker, using **victim position**, then world enemy-damage rate. Note: this condition itself is not restricted to a player victim. `Character.cs:2413-2418` applies `GetDifficultyDamageScaleEnemy` in `ApplyDamage` for a **non-player victim**, again at victim position, then player-damage world rate. These count/scale calls happen on damage processing; neither freezes multiplayer HP scaling at spawn. Thus an old claim that joining after spawning avoids vanilla scaling is not supported by this code.

Scope caveat: these are C# initializers and callable implementation in supplied managed code. Serialized Unity prefab/scene field overrides were not inspected; no game server or client launched under the research-only contract. Mod patches and serialized defaults can alter runtime behavior. This is static primary-code evidence, not an in-game damage experiment.

### Iron Gate rationale

Targeted searches for Iron Gate/Richard Svensson statements on multiplayer scaling, plus official-site results, located mechanics discussions, general interviews and world-modifier material but **no attributable explanation of nearby-player +30%/+4%, range 100 or cap five**. That missing intent is explicit; the coefficients do not reveal why their authors selected them.

## 4. Contrary evidence: moving away from fixed sizes

The strongest first-party case is **Blizzard's 2013 Flex announcement and Warlords expansion rationale**: progression raiding for more variable attendance, less stress, fewer excluded friends and less logistical overhead. It kept the highest-end fixed size for tuning precision. This is a deliberate **hybrid**, not evidence that either all-fixed or all-scaled is best.

**Capcom's September 2019 two-person tier** is a second first-party change away from undifferentiated multiplayer difficulty; the official notes establish the change but not precise reasoning. Secondary contemporary reporting adds adaptive downscaling after departures.

**Diablo III 1.0.8** is contrary to all-or-nothing fixed/scaled framing: Blizzard retained player-count HP scaling, made it gentler, rewarded each person, and reduced coordination overhead because bringing a less-geared friend should be beneficial. Designer playtests found a logistical separation point unrelated to boss HP.

**Miyazaki's January 2022 interview** likewise connects more accessible assistance to expected completion without deliberately lowering overall difficulty. It is adjacent Souls-series intent, not comparative telemetry.

Constraints evidenced across these sources: attendance flexibility and participation quality matter independently of nominal count; extreme tuning and social inclusion can motivate different policies within one game; scaling magnitude/tier granularity/companions/rewards/logistics are separable. No server-specific design decision follows automatically.

## Gaps

- **Exact 1.0.16:** supplied binary embeds 1.0.12; settle with verified 1.0.16 managed assembly and matching provenance, then repeat Game/Character/Player decompile. No source files/configs updated.
- **Unity serialized overrides/runtime proof:** no corresponding Game prefab data or live vanilla 1.0.16 damage run inspected; settle by confirming serialized field values and a scoped hit experiment. Research contract forbids server launch.
- **Iron Gate rationale:** no coefficient/range/cap-specific statement located; settle with directly attributable developer Q&A, design note or interview transcript.
- **Terraria/DRG developer intent and exact build:** mechanics available only via community-authored official wikis; settle with verified game-code/data and developer commentary. Do not promote wiki explanations to designer intent.
- **Monster Hunter exact HP and downscaling primary proof:** two-player tier confirmed first-party; exact monster/quest multipliers and departure mechanics remain secondary here. Official manual fetch redirected to a PHP “No route” error; official patch text partially answers the issue.
- **Dark Souls exact code/first-party coefficient rationale:** only community wiki establishes +50% per phantom and exceptions; Elden Ring interview is explicitly adjacent-game intent.
- **Controlled/causal evidence:** CHI census associates group-dependent endgame with grouping, not a fixed-versus-scaled intervention. No published causal group-rate/retention/off-hours measurement located.
- **Complaint prevalence:** community threads and wiki advice document existence, not population frequency; competing reports retained.
- **Study original hosting:** author PDF timed out via both read and curl; CMU copy had invalid TLS hostname. Full text was read in Paperzz mirror; mirror fidelity has not been checked against author PDF. No study numbers adopted solely from search summaries.

## Citations

All re-reach status is as of 2026-10-05. “Re-reached” means article/code text actually read, not merely appearing in search.

- **Re-reached, primary code:** `lib/valheim/assembly_valheim.dll`; scratch `Game.cs:138-144,1106-1139`, `Character.cs:2268-2272,2413-2418`, `Player.cs:5483-5493`, `Version.cs:168`, all under `/tmp/lembitu-premium/FixedVsScaled/`. Repository provenance `lib/valheim/refs.lock.json:2-3,13`.
- **Re-reached, primary intent:** Bashiok, 2013-11-09, *Warlords of Draenor: Dungeons and Raids*, “Flex Lives,” “1, 2, 3, 4…,” “Bench Stocks Plummet”: https://worldofwarcraft.blizzard.com/en-us/news/11499600 . Current page omits year visually; contemporary indexed publication date is 2013-11-09.
- **Re-reached, primary documentation:** Blizzard, 2014-05-06, *Siege of Orgrimmar Changes…*, introduction/bullets: https://worldofwarcraft.blizzard.com/en-us/news/14014199/siege-of-orgrimmar-changes-in-patch-60-and-warlords-of-draenor .
- **Re-reached, primary intent:** Wyatt Cheng, 2013-04-02, *Developer Journal: Multiplayer Improvements*, “Making Two Heads…,” “Monster Health,” “Identify All”: https://news.blizzard.com/en-us/article/9382478/developer-journal-multiplayer-improvements . Current migrated page does not display date; date located in contemporaneous index.
- **Re-reached, primary shipped changes:** Lylirra/Blizzard, 2013-05-07, *Patch 1.0.8 Now Live*, 1.0.8.16416, “General” and “Monsters”: https://news.blizzard.com/en-us/article/9647272/patch-1-0-8-now-live . Current migrated page does not display date; indexed date 2013-05-07.
- **Re-reached, first-party documentation, undated:** Arreat Summit, *Experience*, multiplayer/single-player-count headings: https://classic.battle.net/diablo2exp/basics/experience.shtml . Lord of Destruction scope, not current D2R version verification.
- **Re-reached, first-party patch:** Capcom, Ver. 10.11, 2019-09-05, “Major Changes”: https://www.monsterhunter.com/update/mhw/us/ver10_10.html . Long page read through relevant section, not all unrelated weapon notes.
- **Not successfully re-reached:** Capcom Iceborne PC manual: https://game.capcom.com/manual/MHW_PC/en/steam/page/4/1 . Redirect/error, not evidentiary basis.
- **Re-reached, secondary reporting:** Dustin Bailey, 2019-06-21: https://www.pcgamesn.com/monster-hunter-world/multiplayer-scaling , opening paragraphs.
- **Re-reached, community report:** Hoick/Vanessa/jscjml, 2018-08-21; Marcus101RR/Guizin, 2018-10-20: https://steamcommunity.com/app/582010/discussions/0/1735462352482827576 . Initial ratio disagreement corrected in post 8; not first-party mechanics proof.
- **Re-reached, community-authored official wiki:** https://terraria.wiki.gg/wiki/Expert_Mode , introduction and “Bosses,” revision 1027876; retrieved current page mentions 1.4.5.6/1.4.5.8 in other code footnotes.
- **Re-reached, community-authored official wiki:** https://deeprockgalactic.wiki.gg/wiki/Difficulty_Scaling , “Normal Scaling”/“Resistance Scaling,” revision 50593, build unspecified and cleanup warning.
- **Re-reached, community mechanics/report:** https://darksouls.wikidot.com/co-op , “Increase in Boss HP,” revision 73, 2021-12-20.
- **Re-reached, primary interview:** Tim Turi interviews Hidetaka Miyazaki, 2022-01-28 (updated 2022-03-04): https://blog.playstation.com/2022/01/28/an-interview-with-fromsoftwares-hidetaka-miyazki/ , newcomer and difficulty/accessibility questions. URL intentionally spells miyazki.
- **Re-reached, primary community reports, conflicting accounts:** https://us.forums.blizzard.com/en/wow/t/pugging-in-sod-is-turning-into-a-joke/2093534 , 2025-04-16, posts 2/6/7/10/18/19.
- **Re-reached via third-party full-text mirror, primary research:** Ducheneaut et al., CHI 2006, pp. 407–416: https://paperzz.com/doc/7538206/alone-together%3F-exploring-the-social-dynamics-of-massively . “Research Methods,” “The social factor,” guild sections. **Author PDF not re-reached (timeouts):** https://www.nickyee.com/pubs/Ducheneaut%2C%20Yee%2C%20Nickell%2C%20Moore%20-%20Alone%20Together%20%282006%29.pdf . **CMU copy not re-reached (TLS):** https://students.lti.cs.cmu.edu/11780/sites/default/files/alone_together_exploring_5599_parc.pdf . StudyLib mirror reached a landing page only, no usable article text.
