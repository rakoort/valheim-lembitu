# EpicMMO family fit research — 2026-10-04

## Scope, sources and evidence limits

Research only; no repository source/configuration edits, publication, deployment or push. Authoritative concept: `docs/adr/0019-the-server-concept-mmorpg-lite-for-rival-guilds-that-cooperate.md:25-55,70-79`. Reused prior EpicMMO/pinned-mod decompiles and `local/mod-review-2026-10-04/conflicts-ProgressionCluster.md:24-30,106-117,174`; independently investigated the previously open death/accounting/group questions.

Primary package URLs: https://thunderstore.io/package/download/korCaptain/CaptainSkillTree/2.1.425/ and https://thunderstore.io/package/download/WackyMole/WackyEpicMMOSystem/1.9.71/ . Captain metadata endpoint: https://thunderstore.io/api/experimental/package/korCaptain/CaptainSkillTree/ . Package README/changelog claims below are attributable to those exact package bytes, not an unversioned current page.

Citation abbreviations:
- **C** = `/tmp/lembitu-fit/EpicMMOFamily/CaptainSkillTree.cs` (complete ILSpy C# decompile).
- **P** = `/tmp/lembitu-fit/EpicMMOFamily/project/` (same binary, per-type ILSpy project; paths below relative to P).
- **E** = `/tmp/lembitu-research/ProgressionCluster/EpicMMOSystem.cs` (1.9.71 prior decompile).
- **R** = `/tmp/lembitu-fit/EpicMMOFamily/package/README.md`.
- **H** = `/tmp/lembitu-fit/EpicMMOFamily/package/CHANGELOG.md`.

Observed verification: downloaded/unpacked Captain 2.1.425, decompiled both main and per-type forms, ran repository stale-member screen on its two DLLs: **clean, no stale game-member reference found in 2 libraries**. Ran same scoped screen on EpicMMO 1.9.71: **clean, 1 library**. These are static reference screens, **not successful Valheim startup**, Harmony composition, server joining or play tests. Scoped executable arithmetic reproduced the decompiled death and group formula examples below; no game process was run. All combined-stack runtime outcomes remain [INFERENCE].

## 1. WackyMole/WackyEpicMMOSystem 1.9.71

**Verdict: POSSIBLE for level/attributes, not a complete level+talent+party solution.** It has the desired independent character level and attribute economy, paid attribute respec and tunable curves; its death total-XP arithmetic is demonstrably inconsistent, and its native group path is not a normalized party XP pool.

### Concept fit and configuration

- Character level and attribute points: fits. `E:4219-4254` derives budget from level × `freePointForLevel`, starting points and configured milestones, subtracting committed attributes and pending deposits. No second vanilla Skill level is introduced. Six-month maintainability caveat: string-backed state and direct parsing, not a typed/versioned save contract (`E:4202-4216`).
- Talent pillar: absent. Attribute allocations are not a playstyle talent tree. Captain is a separate extension, assessed below.
- Paid respec: fits the mechanism. `E:4294-4312,4452-4459` charges spent attribute points × configured `priceResetPoints`, paid with configured coin prefab, or consumes a ResetTrophy if coins are insufficient. Whether its chosen price is *meaningful* during the one-month economy is unmeasured.
- Pace: supports tuning: `E:4482-4505` builds level XP from base experience, growth multiplier, maximum level and cumulative/noncumulative mode. Existing observed pin/config baseline is documented at prior report `:174`: level cap 100, base 300, multiplier 1.05, global rate 1. This does not establish a one-month Fader timing.
- Ownership: not pure base attributes by default. Prior decompile shows physical/magic damage, regeneration and damage reduction as well as HP/stamina/eitr (`E:3637-3651,3721-3741,3745-3789,3794-3880`); these overlap EpicLoot combat effects and MagicPlugin stats. Configurable attribute effects make this more separable than Captain, but the dispatcher must choose ownership/tuning rather than assume they are independent.
- WAP death floor: its own death handler neither replaces `Skills.LowerAllSkills` nor cancels Player.OnDeath; it is a separate character-XP penalty (prior report `:106-117`). Corpse run and native respawn debuff are not a replacement feature of this mod; WAP/Valheim remain their owners.
- Party, invites, up-to-eight, cross-guild positions: **not delivered by EpicMMO alone**. Its embedded Groups API stub returns false/empty without an external patching provider (`E:16409-16433`). No Guilds API appears in the actual XP dispatcher. Built-in friends UI explicitly calls Groups invitations and leader APIs (`E:5138-5144,5174-5195`), not a generic party interface.
- Eight-player boss/two-player creature/static scaling: no group-size normalization in the XP handler; difficulty remains a separate pinned owner. This research does not establish absence of every optional creature tweak; reused prior report covers the wider stat integration.
- Server contract: prior evidence says top-level ServerSync defaults `ModRequired=false`, while embedded ItemManager/PieceManager contribute their own handshake (`local/mod-review-2026-10-04/conflicts-ProgressionCluster.md:174`; `E:6902-6907,11619`). Do not equate the top-level flag to the actual pack handshake. Existing enforced configuration and mandatory Pack installation are distinct from anti-cheat/server-owned XP.

### Death XP loss and total-XP suspicion: resolved in code, not merely a suspicion

`E:4462-4478` first marks player dead in custom data/ZDO. Penalty is only applied when `LossExp` and `HardDeath()` are true. Draw loss fraction L between `MinLossExp` and `MaxLossExp`; retained fraction r=1−L. It writes:

- current XP = trunc(current XP × r)
- total XP = previous total XP − trunc(current XP × r)

It subtracts the **retained** current XP from total, not the **lost** current XP. It does not call AddLevel/setLevel to delevel. `AddExp` normally adds identical reward amounts to current and total (`E:4348-4364`), so the death operation breaks that accounting invariant. Scoped executable example: before current=1000,total=10000,L=0.10; after current=900,total=9100, whereas a matching 100-XP loss would give total=9900. The arithmetic mismatch is observed; whether consumers reconstruct/recalculate level or display misleading totals after reload is a coverage gap. Repeated soft deaths after the native HardDeath window do not execute this penalty. No game reproduction or fix was made.

### EpicMMO group API and XP formula

`E:8224-8363` awards a full local kill reward, then checks **Groups.API.IsLoaded()**, enumerates **Groups.API.GroupPlayers()**, excludes by player *name*, and sends each other member `int(baseKillXP × GroupExp)`. Receiver checks `GroupRange`, applies its own level-difference curve/mentor logic, then calls ordinary AddExp (`E:8150-8215`). AddExp applies the recipient's global/single rate and XP potion (`E:4330-4347`). This is client-computed, peer-RPC-delivered XP, not server-validated XP: receiver uses `sender` only as a parameter, with no membership authentication in this handler.

Under equal rates/no level penalty/no potion and N participating members receiving one kill, total reward relative to solo is **1+(N−1)g**, not 1.1–1.25 by construction. Default g=.7 (`E:6516`) yields 170%,240%,380%,590% at N=2,3,5,8. To hit 115% at exactly eight requires g=.15/7 ≈ .02143; the same setting gives only 102.14% at two. **No constant GroupExp simultaneously holds 110–125% for every party size 2–8**: two requires g≥.10, eight requires g≤.25/7≈.03571. Creature kill-credit/fanout to more than one recipient could further alter totals; that actual server path was not exercised, so the one-primary-award assumption is explicit.

Unmodified EpicMMO reads **no other party API**. However Captain 2.1.425 actively patches this embedded Groups path to feed its native party; thus the ADR's `:93-94` statement that EpicMMO reads deprecated Groups is correct for EpicMMO alone but incomplete for this extension. See section 3.

### Quality and conflicts retained from earlier work

Mostly additive stat postfixes plus client-side death/XP prefixes; broad compatibility screen is clean. Persistence is native character knownTexts/customData/ZDO, not dedicated server-owned database (`E:4284-4288,4464-4466`; prior report `:174`). Potential malformed-value exceptions follow direct Parse. EpicLoot/Blacksmithing/ImpactfulSkills/Herbalist/MagicPlugin overlap is principally stacked power/regen, not a proven startup conflict. UI uses separate level/attribute and resource HUD, so preserve existing vanilla-resource/XP-only UI policy; DetailedLevels remains a skills-window owner. No new full performance audit of EpicMMO was undertaken: explicitly reused prior report rather than rerunning its complete review.

## 2. korCaptain/CaptainSkillTree 2.1.425

**Verdict: REJECT for this concept as shipped.** Decisive: Berserker cancels death and suppresses both WAP's native skill-drain path and EpicMMO XP death path; combat/profession/gear features are not cleanly switchable as an isolated talent owner. Party support is real, but does not repair those violations.

### Dependency and compatibility with EpicMMO 1.9.71

Package manifest pins installation dependencies BepInExPack 5.4.2333, EpicMMO 1.9.66, Jotunn 2.30.0 (`package/manifest.json:6-9`; package URL above). Actual plugin attributes hard-depend on Jotunn but **soft-depend on EpicMMO without exact-version attribute** (`C:815-818`). README English says EpicMMO 1.8.0+ recommended, works without it (`R:635-642`). These statements concern different scopes: installer dependency versus runtime optional bridge.

Bridge reflects `EpicMMOSystem.LevelSystem.Instance`, getLevel, AddExp(int,bool), getCurrentExp/getTotalExp/DeathPlayer and API class methods (`C:72011-72057`). Those relevant signatures exist in 1.9.71 (`E:4320,4462`, dispatcher `E:8224`; prior API `E:275-277`). On detection it disables Captain's internal level ladder and patches XP/UI (`C:69613-69646`), so successful pairing has one level source, not two. **Static API compatibility is supported; successful loading/integration is [INFERENCE]**, particularly because the bridge uses runtime Harmony and packet decoding. Its own changelog explicitly records a fix for 1.9.67 packet layout (`H:209-224`); current fallback reads string,int,bool,Vector3 (`C:71849-71885`), matching 1.9.71 packet header (`E:8230-8233`). Detection only requires getLevel to declare IsAvailable, so partial compatibility does not guarantee XP API availability (`C:72057`).

### What trees/classes actually do

Source-owner overview is package README `R:727-762`:

| Tree/class | Content and axis implications |
|---|---|
| Attack expert | Damage, critical chance/damage; duplicates combat-number power |
| Speed expert | Movement, attack speed, cooldowns; partly legitimate playstyle, but many stat multipliers |
| Defense expert | HP, armor, dodge/regen, automatic parry counter; reaches base attributes and armor |
| Production expert | Gathering/crafting efficiency and bonuses; overlaps professions, not merely combat talents |
| Bow/Crossbow | Explosive arrows/arrow rain, extra shots and freeze burst; overlaps BetterArchery/EpicLoot projectile processing |
| Staff | Double cast, healing/knockback; duplicates magic-school abilities and MagicPlugin staff behavior |
| Sword/Knife/Spear/Polearm/Mace | Rush/whirlwind/assassination/combo throws/AOE/fury hammer/shield charge; combat playstyle perks plus fixed/percentage weapon-number bonuses |
| Archer | Multi-shot, jump/fall mitigation, ammo economy, stamina reductions |
| Mage | Mana burst/eitr; magic-school overlap |
| Tanker | Taunt, absorption/explosion, reduction/HP; party combat benefit beyond XP/positions |
| Rogue | Assassination/crit/stealth |
| Berserker | Rage/low-HP damage, **death-prevention invulnerability** |
| Paladin | Holy Light/heals/buffs, party support |
| Producer | Planting grids, durability, reduced crafting materials and **random gear enchantments** |

This is not just README categorization: live decompile changes weapon damage in `P:CaptainSkillTree.SkillTree/SkillTree_ItemData_GetDamage_MeleeExpert_Patch.cs:6-46,63-208`; adds flat and percentage armor in `P:CaptainSkillTree.SkillTree/SkillEffect.cs:768-845`; enchants multiply weapon damage and armor in `P:CaptainSkillTree.SkillTree/ProducerCrafting.cs:452-529`; Berserker death behavior below. It **does not replace the native random skill damage-roll formula** in the searched project (no GetRandomSkill/GuardianPower targets found), unlike M2 TalentTree, but still rewrites effective item damage and body armor. Its explicit melee_root bonus is hard-coded +3 to every nonzero physical channel (`...MeleeExpert_Patch.cs:27-40`), with no configuration getter on that path.

JobTreeRules restrict permitted weapon trees, shield use and secondary active abilities, not just efficiency (`P:CaptainSkillTree.SkillTree.JobRestriction/JobTreeRules.cs:19-77,184-243`). This diverges from unrestricted soft specialization. Job-specific tree access has configuration hooks (`:127-147`), but choosing all available flags does not remove the base/secondary rules and special Tanker/Producer-only skills. No assertion that every profession/magic feature is mandatory: many numerical effects can be neutralized; the shipped package is nevertheless a broad class overhaul.

### Death/WAP: a direct unacceptable rule conflict

`P:CaptainSkillTree.SkillTree/BerserkerSkills.cs:169-208` Prefix(Player.OnDeath) returns false during active invincibility or activates it, sets HP=1 and returns false on lethal damage unless cooldown. It does this without an enable check for death prevention. `:211-238` Priority600 Prefix(Skills.LowerAllSkills) returns false while protected; `:242-281` dynamically patches EpicMMO DeathPlayer and also returns false. WAP's LowerAllSkills replacement is documented by prior decompile `.../VentureValheim.Progression.cs:3187-3239`; both want that method. Exact Harmony order can vary [INFERENCE], but the explicit prevention of the real death is already sufficient to violate the accepted policy.

Available config is threshold, invulnerability duration and cooldown, not an on/off death-prevention flag (`P:CaptainSkillTree.SkillTree/Berserker_Config.cs:13-19,69-73,166-168`). Threshold=0 is **not** a safe disabling mechanism: the lethal OnDeath fallback is threshold-independent. Duration=0 is also not a safe proof: fallback still sets health and returns false. A prohibitively expensive/unobtainable Berserker talent is content gating rather than a clean feature switch; no such workaround was implemented or judged equivalent to compliance.

### Points, saves, respec and server locks

- Actual spending budget is **hard-coded 2×level + Plugin.SkillTreePoint + saved BonusPoints**, minimum 2 (`C:11355-11375`); GetAvailablePoints calls that path (`C:11385-11400`). There is also GetTotalMaxPoints using configured SkillPointsPerLevel (`C:11313-11325`) and an effective server getter (`C:69012`), but the spending path does not use either. Thus do not advertise fully configurable points-per-level merely because its config exists. No-op AddSkillPoints (`C:11403-11405`) is another misleading API surface.
- Talents are character m_customData `CaptainSkillTree_<node>`; reads use TryParse, writes invalidate caches/HUD (`C:8626-8674`), initialization creates missing keys (`C:11407-11420`). This is local-character allocation, not authoritative server spending. Known job-tree migration classes exist in the project; exhaustive old-version save migration/corruption recovery was not exercised.
- Dead save scaffolding: private SaveSkillTreeToFile/LoadSkillTreeFromFile have no direct callers in project search; they write key=value text with a .json extension under player name, swallow exceptions and use non-atomic WriteAllText (`P:.../SkillTreeManager.cs:5630-5714`). These are code-health signals, not proof that current live saves use that fragile path.
- Paid selective respec is real: passive 100 coins/node, active 500, job 1000 defaults, configurable (`C:58638-58640`; `P:CaptainSkillTree.Gui/SkillTreeUI.cs:3717-3728,3904-3945`). UI sums selected node prices, checks coins, removes them and resets specific levels; admin mode bypasses payment. It respects dependent nodes (`:3731-3750`). Whether these prices are economically meaningful is unmeasured.
- Job switching is different: hard-coded **maximum two** changes; first is free, subsequent costs configured JobResetCost and calls ResetAllSkillLevels (`C:8271-8278,8353-8420`). This is not unlimited meaningful-cost respec. Selective reset's job interaction may permit alternative transitions; that end-to-end behavior is a gap, not assumed safe.
- Config coverage is extensive per-effect numeric configuration; zero enchant chances are available for Producer (`C:42548-42556,42696-42728`), guild subsystem switch exists (`C:58947-58954`), quests switch exists (`C:46449-46450`), and level-difference damage/drop suppression has toggles (`C:69025-69059`). But there is no demonstrated universal disable for profession trees/all class stat rewrites/death cancellation. Embedded Producer enchant value ranges need source rebuild according to README (`R:865-868`), not server config.
- Server config is **custom RPC/table overrides**, not ordinary ServerSync locking. BindServerSync merely binds IsAdminOnly metadata (`P:.../SkillTreeConfig.cs:2074-2115`); server broadcasts a manual dictionary and GetEffectiveValue prefers it when received (`:2453-2456`; `C:57409-58208`). Admin update RPC checks host identity against server admin list (`C:57329-57379`). However receive RPC ignores sender (`C:2486-2495`), and table receiver accepts whatever it is passed (`C:58861-58877`). Keys read directly from .Value, including the actual point budget, escape effective-table overrides. README's “all configs sync” is therefore stronger than the code proves. `EnableLiveConfigSync` defaults false and pertains to remote admin writes (`C:57150,57166-57207`), not a universal synchronized lock switch.

### Code quality, churn, performance and conflict matrix

Strengths: many hooks have null guards, bounded periodic work, cached reflection and exception containment; native party/XP integration handles version drift and keeps original exceptions through finalizer (`C:71926`). Skill manager update gates input at .02s and state at .1s (`P:.../SkillTreeManager.cs:5770-5805`). Static stale-member screen is clean.

Weaknesses: large breadth and dead no-op patches (`C:71929-71965`, manager no-op methods `P:.../SkillTreeManager.cs:5808-5839`), duplicated point-accounting paths, direct client authority, silent catches, hard-coded combat additions, and an actual duplicated armor-enchant application path: SkillEffect adds enchant percentage regardless of Tanker defense talent (`P:SkillEffect.cs:834-844`) while ProducerCrafting also adds it when that talent is absent (`P:ProducerCrafting.cs:516-523`). [INFERENCE] Both installed postfixes therefore multiply enchanted armor twice on that condition; no live order/result test was run. A separate GetBodyArmor postfix is a literal +0 dead patch (`P:SkillTree_Character_GetBodyArmor_Patch.cs:12-18`).

Performance: PartyMinimapMarkers UpdatePins calls allocating GetOtherMembers in prefix and offscreen-arrow pass (`P:CaptainSkillTree.MMO_System/PartyMinimapMarkers.cs:11-40,137-154`; `PartyManager.cs:411-414`), so normal map-pin updates allocate lists repeatedly. Reflection GetLevel invokes and writes a formatted backup every call (`C:69701-69729`). XP operations emit frequent LogInfo with boxing/string formatting (`C:71398-71426,71467-71476,71872-71878`). This is not a measured FPS regression, but concrete avoidable hot-path costs. No AI authorship can be inferred reliably; dead scaffolding/churn are observed, AI origin is unknown.

Changelog shows 2.1.279 on Sep19, 2.1.300 Sep21, 2.1.347 Sep26, 2.1.377 Sep28, 2.1.413 Sep29, 2.1.425 Oct3 (`H:3-18,83-86,131-158,209-258`). Suffix jumps are **not evidence of 146 published releases**; exact cadence count is unknown. The source claims show rapid feature expansion and recurring fixes: native parties Sep19, missing party sync Sep20, packet compatibility Sep21, guild subsystem Sep29, bar/VFX correctness Oct1. This supports instability/ongoing expansion concerns; downloads were not used as a quality proxy.

| Pinned owner | Observed collision/overlap | Severity |
|---|---|---|
| WAP 1.0.0 | Berserker LowerAllSkills prefix plus death cancellation | Proven policy conflict; composition order not tested |
| EpicLoot 0.14.13 | ItemData.GetDamage, Character.GetBodyArmor, crit/projectiles; own Producer permanent enchants | Duplicate gear authority, potential order-dependent stacking [INFERENCE]; no startup conflict proven |
| BetterArchery 2.0.2 | FireProjectileBurst/Projectile.OnHit and multishot/ammo economy | Shared targets, behavioral stacking [INFERENCE]; Captain bow patch targets C:51340-51388; prior BetterArchery EQUIVALENT source at `/tmp/lembitu-research/ProgressionCluster/BetterArchery.cs:3440-3464,3677-3809` |
| MagicPlugin 2.2.2 | Staff dualcast/mage eitr/heal and magic amplification | Magic-school/stat ownership overlap, not proven binary incompatibility |
| ProgressivePowers 0.3.4 | Defensive/offensive bonuses coexist; searched project has no native guardian-power reset/replacement | No direct boss-power target found; balance stacking [INFERENCE] |
| Herbalist, BlacksmithingExpanded, ImpactfulSkills | Production gathering/crafting/durability/material reduction | Profession ownership duplication; shared crafting hooks [INFERENCE] |
| CreatureManager, AdditiveDamageModifier | Damage, armor/resistance stacks | Order/composition gap; Captain Tanker/Archer resist effects broaden axis |
| DetailedLevels | Captain patches SkillsDialog setup and injects inventory icon | Skills-window/UI collision risk [INFERENCE], not exercised |
| Northarun/Guilds | Captain now has a second guild subsystem | Config Guild_SystemEnabled can disable Captain guilds; no need to merge memberships |
| AzuExtendedPlayerInventory | Captain inventory icon/GUI hooks | Layout collision risk [INFERENCE]; actual UI not viewed |
| Dive_In, SkadiNet | No direct named integration found in inspected relevant paths | Runtime composition unverified; no proven conflict claimed |

Hotkeys default Z/G/H/Y (`R:713-718`) collide at least with vanilla sit Z and guardian power G unless rebound; shield charge uses Mouse2 as its source-owned default (`H:131-134`). This requires client pack keymap choices. DetailedLevels/inventory/UI evidence is risk, not an observed hard UI failure.

## 3. What fills the party pillar with this family?

**Captain's own native party is a real alternative provider for EpicMMO XP and map positions. It is not a compliant party-only solution as shipped, and its XP controls differ by route.**

- Invite/accept/join-request/roster RPCs and independent session-ID membership are in `C:75724-75736`; default max size 5 is configurable via Party_MaxSize (`C:58957-58960`) and checked on member add (`C:76146-76148`). Settable to 8; no Guilds membership dependency appears in native membership code. Native leader can enable automatic joining (`P:PartyManager.cs:360-365,1303-1307`), violating strict invite-only if allowed; starts/reset defaults false (`:627`). Whether server can prohibit that leader toggle is not established.
- Native positions are cached/shared with dedicated markers and offscreen arrows, expiring stale positions at ten seconds (`P:PartyMinimapMarkers.cs:11-40,137-178`). Does not imply full map discovery sharing.
- Normal paired route: **EpicMMOGroupsBridge** dynamically transpiles only EpicMMO RPC_DeadMonster, appending substitutions to its embedded Groups.API IsLoaded/GroupPlayers calls (`C:71670-71738`). When within captured death RPC window it returns Captain native members (`C:71741-71775`). Thus EpicMMO can consume this party without Smoothbrain/Groups installed. It does NOT broadly replace all friends-menu Groups invites; those remain old API calls.
- When bridge is active and EpicMMO actually calls GroupPlayers, EpicMMO does payout with **EpicMMO GroupExp/GroupRange** (`E:8355-8361,8158`), **not Captain Party_ExpSharePercent/Range**. If bridge unavailable or did not enumerate, capture-finalizer sends Captain fallback (`C:71897-71925`); fallback uses Captain percentage/range (`C:71412-71461`). These are two independently configured formula authorities. The package README claim “config percentage/range” and changelog party sync fix do not establish that Captain's knobs govern the normal paired route.
- Fallback records AddExp's input argument, not XP actually awarded after RateExp/potion (`C:71888-71894`; `E:4330-4347`). Its README's “actual payout” claim (Korean `R:413`) overstates that detail. Recipient adds XP through EpicMMO again, so its multiplier still applies. Both routes are full killer reward plus constant percent to each other member, not party-size-normalized 110–125% totals.
- Extra party scope exists: chat/vitals, ping sharing, rings, friendly-fire protection and party-targeted skills, not only XP/positions (`C:75766-75780`; `P:PartyManager.cs:1504-1507`; config `C:58957-58960`; README `R:753-762`). Healing/taunt/buffs and Producer skill/return portals affect coordinated party play beyond the requested two features. Guild/quest/ping/friendly-fire options exist, but no demonstrated master party-only mode disabling every combat/summon behavior.

## 4. Explicit acceptance answer and remaining gaps

**Does EpicMMO + Captain deliver level + attributes + talents + costly respec under one-owner-per-axis? No, not as shipped.** It can provide one EpicMMO level source, EpicMMO attributes, character-saved Captain talents and paid selective resets; that mechanical integration is statically supported. But Captain duplicates base attributes/armor/weapon combat numbers, professions and magic, has restricted class/weapon access, and explicitly cancels costly death. Its points-per-level config does not govern actual spending. Those are source-backed failures, not hypothetical download-quality concerns.

**What fills the party pillar?** Captain itself supplies a native invite/leader-managed party and position markers, adapting EpicMMO's embedded Groups API via a targeted transpiler. This is the important correction to prior research. Yet it does not meet the normalized XP pool, strict invite-only lock or party-only feature scope without changes or a narrowed design; no compliant ready-made party-only solution was established by this slice. Other party candidates are assigned separately. Do not install deprecated Groups simply to satisfy EpicMMO's old API name.

Coverage gaps: no Valheim startup/network handshake/play smoke; no combined Harmony ordering; no corruption/reload migration reproduction; no actual FPS/UI/keymap observation; no complete old-save format audit; no one-month balance measurement; no proof of server-enforced all-key lock (counterexamples observed). Package screens passed, so rejection is concept/code behavior, **not a claimed current startup failure**.

## Final comparison

| Mod | Version | Verdict | Decisive reasons |
|---|---:|---|---|
| WackyMole/WackyEpicMMOSystem | 1.9.71 | POSSIBLE | Tunable level/attributes and paid respec; inconsistent death total-XP bookkeeping and deprecated/native-unadapted group route |
| korCaptain/CaptainSkillTree | 2.1.425 | REJECT | Explicit Berserker death/skill/XP-loss suppression; broad gear/profession/magic ownership with incomplete switches/points config |
| EpicMMO + Captain native party path | 1.9.71 + 2.1.425 | REJECT as complete concept solution | Native bridge genuinely works at static API level; two XP knob sets and non-normalized party pool plus Captain's rule violations |

Top fit from this slice: **EpicMMO alone remains the possible level/attribute candidate; Captain is not a fitting talent add-on for the accepted concept.** This is a fit verdict, not an implementation or deployment decision.
