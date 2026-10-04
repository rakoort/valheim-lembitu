# SkillTreeReplacements — exact-package fit research

Research date: 2026-10-04. Research only: no repository source/config edits, publication, deployment or live game execution. All three exact packages were downloaded, extracted, decompiled with ilspycmd 11.0.0.9375, and screened against the supplied game-library checker. **All three screens returned exit 0, “clean: no stale game-member reference found in 1 library(ies)”.** This is a static compatibility screen, not proof of startup/Harmony composition, multiplayer or FPS.

## Sources and citation convention

`W` = `/tmp/lembitu-fit/SkillTreeReplacements/`. `P` = `W/PathOfValheiman-src/PassiveTree/`; `PU` = `W/PathOfValheiman-src/PassiveTree.UI/`; `N` = `W/NorntasticSkillGrowth-src/`; `R` = `W/Rist-src/Rist/`. Every file:line below refers to the downloaded exact-version primary artifact, not an upstream HEAD. Package README/CHANGELOG citations use `W/<mod>/...`. Decompiled source remains in that workspace for follow-up.

Primary package URLs:
- https://thunderstore.io/package/download/treextr/PathOfValheiman/4.11.5/
- https://thunderstore.io/package/download/Dafini/NorntasticSkillGrowth/0.14.2/
- https://thunderstore.io/package/download/Ezomic/Rist/1.7.0/

Metadata URLs (saved as `W/<mod>.metadata.json`):
- https://thunderstore.io/api/experimental/package/treextr/PathOfValheiman/
- https://thunderstore.io/api/experimental/package/Dafini/NorntasticSkillGrowth/
- https://thunderstore.io/api/experimental/package/Ezomic/Rist/

Concept authority: `docs/adr/0019-the-server-concept-mmorpg-lite-for-rival-guilds-that-cooperate.md:29-55,70-73`. Pinned integration facts reused from `local/mod-review-2026-10-04/conflicts-ProgressionCluster.md:40-88`, which cites the existing exact pinned decompiles. These are code overlap observations, not a reproduced crash.

## 1. treextr/PathOfValheiman 4.11.5 — REJECT

### What replacing vanilla progression actually does

This is a full progression/combat/professions overhaul, **not a separable passive-tree companion**.

- `P/XpSources.cs:67-114`: local-player `Skills.RaiseSkill` prefix converts practice into its own XP, then returns `!DisableVanillaSkills`. Default true therefore skips native RaiseSkill and its eventual `Skills.Skill.Raise` path. The non-vanilla-skill branch also returns that value (:76-79): modded skills can be frozen too, even though they do not earn this XP.
- `P/XpSources.cs:117-128`: local `Skills.OnDeath` calls its own `Progress.OnDeath`, then returns `!DisableVanillaSkills`. Default true skips native skill drain, so **WAP's LowerAllSkills death-floor path is not reached**. WAP is not directly unpatched; the upstream call is bypassed. WAP's Raise floor/cap is similarly bypassed when native RaiseSkill is skipped. Pinned WAP hooks are documented in prior research :40-44.
- `P/Effects.cs:281-293`: local `Skills.GetSkillLevel` is replaced with floored/clamped `BaseSkillLevel + GearSkill`, not the stored practice level. The default base is zero, with partial equipment skill credit (`P/Plugin.cs:545-548`). Thus a stored boss floor does not rescue the effective skill value under default replacement.
- There **is** an escape hatch: `Disable vanilla progression=false` permits native practice, drain and GetSkillLevel (`P/Plugin.cs:545`, patches above). However it **does not disable the separate damage-roll rewrite**. `P/Effects.cs:228-245` replaces local Player.GetRandomSkillFactor whenever StatText has an attribute for that skill, using tree-derived centre +/-0.15, irrespective of DisableVanillaSkills. Turning the skill switch off is not a clean cutover to vanilla combat.

### Level, points, XP, respec and death

- Own character `Level` and `Xp`; points are `(Level-1)*max(1,PointsPerLevel) + BonusPoints + boss/dungeon/monolith rewards + debug points`, not the chosen external level economy (`P/Progress.cs:38-52,136-160`). Default one point/level, cap 200 is an author claim in README :115; formula is observed code.
- Curve is configurable `round(LevelBaseXp * max(1,level)^LevelExponent)` (`P/Plugin.cs:1047-1050`); multiplier, points/level, cap, base/exponent, death fraction and skill/kill/craft XP are synced entries (`P/ConfigSync.cs:120-141`). Peaceful work is routed into a **second Craft progress** rather than combat progression (`P/Progress.cs:316-325`). A following `if (peaceful...)` branch is unreachable after that return (:327-339): concrete stale code, not an AI attribution.
- Respec costs default **10 coins per refunded point**, configurable 0–500, or free; alternate eye payment is one greydwarf eye/point (`P/Plugin.cs:577-578`; `P/Progress.cs:174-199`). README :113 describes connected-build refunds. This satisfies meaningful paid respec as an available policy.
- Death removes configured fraction of current-level XP, not levels (`P/Progress.cs:377-386`). Tree stats can modify that death fraction (:379), so the death penalty is also part of the build. No death cancellation was verified in the read paths; the default skill-drain bypass alone is decisive.

### Axis overlap and pinned conflicts

- **Damage-roll authority:** unconditional GetRandomSkillFactor replacement above violates gear combat-number ownership even with vanilla skills re-enabled. EpicLoot's skill/damage patches and ImpactfulSkills/Herbalist RaiseSkill patches are documented in prior research :60-64. Same axis is proven; exact winning patch order is [INFERENCE].
- **Armour formula:** `P/ArmorEffect.cs:10-47` brackets player RPC_Damage with a counter/finalizer, then multiplies body armour by tunable `armor.effect` at priority 600. It is not merely a talent additive bonus. CreatureManager also hooks body armour (prior research :66-68); exact combined multiplier/order needs live proof.
- **Core stagger formula:** `P/NoStaggerBonus.cs:10-71` transpiles RPC_Damage to suppress native stagger-hit bonus; patch seeks IsStaggering, then literal 2 and HitData.ApplyModifier within 12 instructions. README changelog :78-81 says native sneak/stagger multipliers are removed and bought in the tree. This is outside a playstyle-only talent axis.
- **Professions/gear rolls:** own separate craft tree, profession tasks and persistent crafted-item affixes are explicit exact-version source claims (`W/PathOfValheiman/CHANGELOG.md:67-76`); source routes peaceful XP into Craft above. Duplicates BlacksmithingExpanded and ImpactfulSkills Forging, and reaches into Herbalist/ExpertExplorer/work economies. Prior research :54-64 establishes pinned profession effects. Magic/elemental nodes plus new early staves are author claims (README :94-101), overlapping MagicPlugin's school/gear axis.
- **Resistance/block/projectile/archery:** RPC_Damage, SEMan.AddStatusEffect, Humanoid.BlockAttack, ItemData.GetBlockPower, attack-cost and animation patches are visible in `P/Effects.cs:330-595,638-705`; exact all-mod composition is unverified. Extra projectile/chain/split and draw nodes are README :94-97 and changelog :42. BetterArchery and EpicLoot's projectile overlaps are established in prior research :74-78. ADM owns resistance processing (prior research :66-72); no runtime proof that PoV preserves ADM's floor.
- **World difficulty:** changelog :88-91 claims its own biome/boss health/damage ladder. This reaches into CreatureManager's fixed 8/2 tuning axis. No approved clean recipe removing every such side system was established.
- **Selective switches exist, but are not a global axis boundary:** convenience mastery, glancing blows, shield, levitation switches (`P/Plugin.cs:448,476-509`); advanced disabled list only targets convenience options, with craft mastery switches described (`P/DisabledTalents.cs:38-89`). **Do not report that these disable the unconditional damage/stagger rewrites.** Exact exhaustive removal of all profession and combat side effects remains a gap.
- UI: default P tree window and Shift mass-planting (`P/Plugin.cs:579-580`); frozen skill display plus SkillsDialog patch are additional DetailedLevels integration risk [INFERENCE]. Shield overlays health (Plugin :479); conflicts with other level HUDs are placement risks, not observed crashes. No specific startup conflict verified with Guilds, AzuExtendedPlayerInventory, Dive_In or SkadiNet; no compatibility guarantee follows.

### Party fit, authority and config lock

- Not intentional parties. `P/SharedXp.cs:47-64` splits by **all living nearby players**, no invitation/guild/party membership, no eight cap. Receiver credits nearby peers, with token-bucket bounding (:125-176); clients broadcast XP (:108-122). It is not configurable 110–125% invite-party XP: observed local divisor is equal division and no configurable party bonus was found in this implementation. Radius/on-off is configurable.
- Progress and XP are computed locally (`P/XpSources.cs:72-113`; Progress.Current uses local player, `P/Progress.cs:122-130`). Sharing trusts peer reports subject to bounds, not server verification of kill credit. Pack installation is necessary but is not authoritative character-data storage.
- Custom RPC config sync, not embedded ServerSync: server payload accepted only from trusted server sender, capped to 65536 chars, parsed against known schema, rejecting invalid/duplicate entries (`P/ConfigSync.cs:265-339`). Runtime effective values resolve server before local (`P/RuntimeSettings.cs:235-254,396-408`); this is functional host precedence, rather than a standard ServerSync AddLockingConfigEntry. No Jotunn-required compatibility/version-handshake attribute was established. Server installation requirement is author claim README :121. No external HTTP on this build is author claim README :3-5; not independently audited across every dormant web-related class.

### Save safety, performance and polish

- Saved in Player.m_customData with pt.level/xp plus comma-separated node IDs/choices, identity/name metadata and `.r` allocation namespace (`P/Progress.cs:80-120,1298-1394`), travels with character (README :121). Load uses TryParse, ignores unknown node IDs and restores/refunds by identities; when identity metadata is absent it refunds allocation (:1381-1393). Load also **deletes every pt.prof.* key** (:1301-1306). This demonstrates migration/repair work but not corruption-proof storage; external editability and non-finite float handling remain risks [INFERENCE]. No server ledger/transactional backup verified.
- Not a naive 2600-node full-frame UI: tree has tiled link meshes/nodes, viewport culling with movement threshold and queued tile wake (`PU/TreeWindow.cs:29-47,2063-2128`), staged coroutine construction and yields (:3268-3305,5049-5263), closed-window early return and 30 Hz visible pulses (:7096-7153). This is real performance engineering. Initial UI still constructs node/link views across the tree; no measured load memory, frame timing, or worst-case craft fog result is available. `TreeWindow.cs` is 11,491 lines and contains many unrelated systems; maintainability is weaker than node count marketing implies.
- Mixed patch style: targeted postfixes, guarded prefixes, but multiple core replacements and IL rewrites. NoStaggerBonus catches exceptions and preserves original IL, and logs no-match, which avoids startup failure but silently leaves different combat rules than intended (:18-71). Progress.Current is dereferenced without null protection in RaiseSkill and OnDeath (`XpSources.cs:108,126`), unlike guarded paths elsewhere; actual startup timing failure is [INFERENCE]. Armour counter cleanup uses finalizer correctly (ArmorEffect :22-28).
- Metadata proves created **2026-09-11 16:44 UTC**, updated **2026-10-04 06:32 UTC**, latest 4.11.5 (metadata URL above). It does **not** provide version history, so exact release count/day is unknown. Changelog shows 4.11.0–4.11.5 plus UI, save-budget and mesh/stutter regressions fixed recently (:3-64). README openly says early access, same-day break/fix, unfinished ascendancy bonuses (:17-21,125). Fast churn and dead branch are observed. **AI generation of PoV is not established**; naming, prose and rapid version numbers are not attribution evidence.
- Static screen clean: `W/PathOfValheiman-screen.txt:1`. Old BepInEx dependency does not itself prove incompatibility; no live startup performed.

**Concept coverage:** supports limited node budget, build routes, soft specialization, paid respec, tunable curve and current-level XP loss. Violates default boss-floor skill drain, separate level/base-attribute versus talent ownership, profession/gear/magic axis ownership, invite-only party specification, and fixed world-tuning ownership. Corpse-run/debuff composition and one-month Fader balance unmeasured. Verdict rests on **core combat rewrites surviving the vanilla-skill switch**, plus default floor/drain bypass—not popularity or an invented startup failure.

## 2. Dafini/NorntasticSkillGrowth 0.14.2 — REJECT

### Concept and configuration

Skill-derived shared perk budget is conceptually closer to a talent layer than PoV: combined skill high-water levels buy points, default interval 10; points spend across trees (`N/Norntastic.Config/ModConfig.cs:111`). It is **not** a character-level attribute-point system and supplies no party kill-XP formula/map-position grouping. Retroactive boss-floor skills can immediately buy perks [INFERENCE from high-water/initial seed], so it is not independent of WAP pacing.

Prestige can and must be turned off for this contract: `N/Norntastic.Core/Prestige.cs:60-76` directly calls ResetSkill after level-100 qualification, outside WAP's LowerAllSkills/Raise hooks. It can drop a skill below a boss floor until another floor-applying action [INFERENCE]. Toggle is real (:19-22; ModConfig :112). No Skills.OnDeath/LowerAllSkills/RaiseSkill replacement was found in its patch directory; ordinary drain remains native in that inspected surface, not a proven full-stack death test.

Free respec defaults true; disabling it is intended to require Unwoven Thread/respec points (ModConfig :116-117). **README :88 says the item does not exist and a cheat command stands in for it.** Thus a meaningful ordinary-play respec economy is not delivered by the package's stated surface. README is visibly older than newest content: it reports 69/384 implemented versus :20's 360 nodes, and later changelog adds more machinery. Do not treat those counts as authoritative current binary totals. The specific ordinary-play respec item absence was not exhaustively verified across all content builders; it is a source claim with that scope.

### Decisive multiplayer problem

**The shipped binary's `Synced<T>` simply returns `cfg.Bind<T>`** (`N/Norntastic.Config/ModConfig.cs:201-204`), with no synchronization registration. README :117-119 says ServerSync is optional at build time. Therefore labeling settings “Synced” is not proof of server lock; this inspected artifact does not implement it in its config helper. The editable local perks.json wins after first launch (README :156-157). Database fingerprint is also bound through that no-op sync helper (ModConfig :147). Plugin carries a NetworkCompatibility attribute (`N/Norntastic/Plugin.cs:27`) but ilspy could not decode its arguments; README claims EveryoneMustHaveMod (:153-154). Presence/version compatibility is not authoritative settings/tree locking. This fails ADR :70-73 in this exact build.

### Quality, persistence and overlaps

- Own character text payload `Norntastic.v1`, legacy `NornsLoom.v1`, version `nl1`; pipe sections with high-water/allocations/prestige/styles/respec maps (`N/Norntastic.Core/PerkStateStore.cs:18-99,109-140`). Unknown versions are read anyway (:51-54); character portability is intentional. Null checks/catch/logging and legacy migration exist.
- A claimed corruption protection is questionable: TryLoad catch logs “payload untouched” and returns false (:122-126), while Player.Load false branch seeds fresh state (`N/Norntastic.Patches/PlayerPersistencePatch.cs:43-61`) and later Ready-state save writes current payload (:25-34). **[INFERENCE] failed load can become fresh state and later overwrite the original**, contrary to log text; not exercised in game.
- Aggregate effect driver ticks at 0.25 seconds, rather than every frame; reused dictionaries in aggregator (`N/Norntastic.Effects/PerkEffectDriver.cs:14,39-73`; EffectAggregator.cs:13-21). It rebuilds condition/auras/guardian effects every tick. No FPS benchmark or allocation profile.
- Profession, extra skills, content automation, armour penetration, dual-wield, arbitrary-item brawler attacks and guardian power cooldown are far outside a narrow perk tree: observed config switches ModConfig :119-148; prestige effects above; inspected combat file inventory and README :24-29,68-84. Guardian cooldown cap (:121) duplicates ProgressivePowers; smith/craft/resource effects duplicate BlacksmithingExpanded/ImpactfulSkills/Herbalist; hit/damage/armour effects overlap EpicLoot/ADM/CreatureManager. Those are axis collisions, exact Harmony order/crash unverified. Many content systems have individual switches, but no server-locked curated tree is present here.
- P panel, J/G/H brawler controls are author claims (README :22,68); DetailedLevels skill UI overlap and G guardian/control collisions are [INFERENCE]. No specific hard conflict proved with Guilds/AzuExtendedPlayerInventory/Dive_In/SkadiNet.
- **AI assistance is explicitly disclosed** in README :241. More useful polish evidence is changelog :5-12: fryer output existed as a plan without a builder; :40-46 says missing Arm was shipped. Metadata created Sep 15, updated Sep 17, while changelog says feature absent “for months” (:45-46): report these different source scopes, not a proven historical duration. Stub-heavy historical README claims (:127-147) are not current live-test evidence.
- Static screen clean (`W/NorntasticSkillGrowth-screen.txt:1`). No stale API rejection and no startup crash verified. Binaries have null checks/guarded persistence but conceptual/API scaffold history deserves scrutiny.

**Concept coverage:** limited shared points, specialization and editable thresholds available; no base-attribute level, no invite-party sharing, no level death-XP loss, respec economy source gap, prestige floor bypass if enabled, uncontrolled profession/gear/power side axes, and no observed server settings lock. Month-long pace/corpse-run/debuff composition unknown. Decisive rejection: **shipped fake sync helper**, plus broad unfinished/content scope—not an AI label alone.

## 3. Ezomic/Rist 1.7.0 — REJECT for the specified pillars; best engineered bounded option in this slice

### Fit and configurable limits

Own character level beside skills, **XP solely from skill level-ups**, one banked pick/level spent on independent runestone ranks, default cap five (README :3-24,30-60). Curve/skill weights configurable (`R/RistConfig.cs:102-107`). It does not provide allocated base-attribute points separated from talents, a connected talent tree, invite-party kill-XP sharing, or a party bonus formula. This is a different progression model, not a nearly-complete solution to the ask.

Default RemoveDeathSkillLoss skips Skills.OnDeath completely (`R/DeathPenalty.cs:5-10`; RistConfig :134), bypassing WAP drain-floor invocation. **Can set false** to preserve native/WAP death processing. No level-XP-loss config or paid respec path was found in inspected config/console/network reward paths; these remain explicit missing features, not fabricated impossibility proof across future versions. README's death feature is skill-loss removal, not XP loss (:84-98). No second-life prevention was verified.

Catalogue is editable, so unwanted power, armour, bow, mead, map/exploration or inventory effects can be removed instead of pretending a global toggle exists. Examples are author-documented specials (`README:162-190`; shipped cards comments :12-37); new catalogue lines map to SE_Stats fields. That permits curation, but is not the contracted character-attribute/talent split. Default cards no longer grant inventory rows (`cards.txt:44-48`), so do not claim an unavoidable AzuExtendedPlayerInventory row conflict from a dormant capability.

### Multiplayer authority and lock

Better bounded authority than PoV: server receives skill reports, validates owner and 0–100 level, rate/step/XP budget, derives XP, validates pick budget/card/rank and sends state (`R/Net.cs:93-239`). Client reports are explicitly **self-reported, not verified game events** (RistConfig :137; README :256-267). Snapshot/skill jump limits may interact with WAP mass boss-floor gains; config provides MaxSkillLevelJump (README :265). Exact award behavior needs a floor-unlock scenario.

Without Longhouse Core, plugin logs that version gate, cards.txt check and host-authoritative curve are unavailable (`R/RistPlugin.cs:168-177`). With Core it registers and syncs **only seven** entries: XP/curve, rank/capstone and skill weights (`:181-196`). **RemoveDeathSkillLoss, attack speed cap, stamina floor are not in this list.** Thus don't promise that the full gameplay policy is locked merely because Core is installed. No independent ServerSync/Jotunn lock verified. A server ledger calculates rewards regardless; local effect catalogue and these unsynced limits still need enforced pack/lock handling beyond the specified slice.

### Save quality and performance

- `BepInEx/config/rist-ledger.txt`, server-side keyed platform identity plus character (`R/Ledger.cs:26-44`; Net :99-105; README :304-307). Dirty ledger flushes every ten seconds (:169-175). Missing/empty catalogue and excessive deleted-card fraction block reconciliation (:103-167), with explicit warning. File-read exception prevents later write (:82-86,184-191).
- Important weakness: malformed individual ledger rows are **skipped**, not protected from subsequent overwrite (:64-80). Save writes temp, deletes original, then moves temp (:200-206): not atomic replacement and no backup; interruption between delete/move can lose canonical file [INFERENCE]. Better guardrails than mere JSON but not robust transactions.
- Update calls Effects.Apply every frame (`R/RistPlugin.cs:207-234`); it computes a signature before unchanged-state guard (`R/Effects.cs:48-67`). Signature allocates a key list, sorts it, builds a StringBuilder and string each frame for nonempty ranks (:228-245). This is avoidable **O(r log r) plus allocations/frame**; small catalogue bounds it but is a concrete quality flaw. Actual FPS/GC impact unmeasured.
- No transpiler hits were returned by the scoped search of Rist source; targeted feature classes and null checks in network/effects are preferable to PoV's large core rewrite. That statement is static source search, not absence of every runtime detour.
- Catalogue damage/ranged/armour/sneak modifiers overlap EpicLoot; draw/projectile effects overlap BetterArchery; power cooldown/duration overlaps ProgressivePowers; exploration radius overlaps ExpertExplorer; mead effects overlap Herbalist. Curating catalogue can remove these axes. DetailedLevels is not directly replaced as in PoV; compendium fifth tab and extra XP HUD have placement risks with other UI [INFERENCE], not verified crashes. No specific hard conflict proved with Northarun/Guilds, Dive_In or SkadiNet. No professions replacement was verified.
- Metadata created Aug 17, updated Sep 30, latest 1.7.0. No AI-authorship evidence established; explicit default tuning rationale and guardrails are code/source observations, not proof of live polish. Static screen clean (`W/Rist-screen.txt:1`); built-against 1.0.7 claim (README :7) does not outweigh clean supplied stale-member screen, nor prove startup on 1.0.16.

**Concept coverage:** soft-specialization ranks, editable effects, configurable pace and preserved vanilla skills when death switch false; fails separate base-attribute/talent contract, paid respec/level-XP death-loss evidence, invite-party kill sharing, and fully locked gameplay settings evidence. Corpse-run/debuff and one-month balance unmeasured. Decisive rejection is **skill-up-only runestone economy instead of the requested character/talent/party economies**, with default death bypass and incomplete sync adding costs. It is the least invasive of these three if the owner deliberately changes the concept, not a recommendation to do so.

## Final comparison

| Mod | Exact version | Verdict | Decisive reasons |
|---|---:|---|---|
| PathOfValheiman | 4.11.5 | REJECT | Core damage/stagger/armour plus separate craft/level overhaul; default skips WAP gain/death-floor paths, and re-enabling skills does not remove damage-roll replacement |
| NorntasticSkillGrowth | 0.14.2 | REJECT | “Synced” config helper in this binary is only cfg.Bind; broad unfinished/content/power/profession side axes and respec-economy source gap |
| Rist | 1.7.0 | REJECT for this concept | Skill-up-only runestones, not separate character attributes + talent tree or shared kill XP; paid respec/XP death loss absent from inspected surface and partial settings sync |

**Top recommendation for this slice: adopt none for ADR-0019.** Rist is the best bounded implementation to study, not a strong-fit mod. PoV is appropriate only for a wholesale overhaul stack, and Norntastic's actual binary sync behavior is a stronger objection than its disclosed AI assistance.

## Coverage gaps and verification limits

All requested questions have code/source evidence or these explicit gaps: no live game startup/Harmony composition, no measured multiplayer/floor scenario, no memory/FPS profile with full node UI, no one-month Fader curve simulation, no exhaustive per-node effectiveness audit, no PoV AI attribution, no historical per-version timestamps (experimental metadata exposes latest only), no independently verified complete selective-disable recipe for PoV, no full Longhouse Core lock/catalogue protocol decompile, and no current binary-wide ordinary-play Norntastic respec-item construction proof. Screen execution is the only compatibility experiment performed; no “loads clean” conclusion is claimed. Repo and deployment left untouched.
