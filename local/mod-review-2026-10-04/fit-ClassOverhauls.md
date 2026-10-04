# Class/RPG overhauls — fit research (2026-10-04)

## Scope, method and citation key

Research only; repository/source/configuration left unchanged. Downloaded the six exact requested Thunderstore ZIPs, extracted under `/tmp/lembitu-fit/ClassOverhauls/`, and successfully decompiled their gameplay DLLs with ILSpy 11.0.0.9375, using `lib/valheim` and `lib/bepinex` reference directories. Ran `scripts/screen-bundled-libs.sh --dir <extracted package>` for each: **all six returned 0, clean**. This is a static member-reference screen, **not proof of startup, Harmony reflection correctness, multiplayer interoperability or actual play**. No game/server was launched. Erroneous extra attempts against ZIP paths (not directories) failed redirection and are excluded from those results.

Authoritative yardstick: `docs/adr/0019-the-server-concept-mmorpg-lite-for-rival-guilds-that-cooperate.md:29-55,70-79`: fixed difficulty; costly death; month-scale pace; seven distinct progression axes; soft specialisation and meaningful-cost respec; intentional invite-only parties with restrained XP, not a replacement guild; server-controlled gameplay settings. The additional attribute-point and pinned-mod requirements are from the assignment.

Below, `ROOT` means `/tmp/lembitu-fit/ClassOverhauls/`. Each package abbreviation resolves to its exact directory:

- **VA**: `kpttr-Valheim_Ascended-0.4.1`; **OB**: `LionAndOtter-Oathbound-0.21.14`; **ND**: `Alpus-NorseDemigods-1.7.1`; **VL**: `momos3939-ValheimLegends-0.7.12`; **WC**: `BunzBoiModding-ValheimWeaponClasses-1.1.3`; **JG**: `JGSTUDIOS-JGRPG-0.1.63`.
- VA code: `ROOT/VA/plugins/ValheimAscended-decompiled/`.
- OB plugin code: `ROOT/OB/BepInEx/plugins/WarriorRpg/WarriorRpg-decompiled/Warrior.Mod/Plugin.cs`; OB core: same parent, `Warrior.Core-decompiled/Warrior.Core/`.
- ND code: `ROOT/ND/NorseDemigods-decompiled/`.
- VL code: `ROOT/VL/ValheimLegends-decompiled/ValheimLegends/`.
- WC code: `ROOT/WC/ValheimWeaponClasses-decompiled/`.
- JG code: `ROOT/JG/BepInEx/plugins/JGRPG-decompiled/JGRPG/`.

Package README citations are exact downloaded primary-source text, available from the versioned URLs below; do not treat their descriptions as verified implementation unless corroborated by code. The requested fast-triage rule was used: a decisive concept rejection ends the deep audit. Explicit gaps below are **not** clean bills of health.

## 1. kpttr/Valheim_Ascended 0.4.1 — REJECT

Primary package: https://thunderstore.io/package/download/kpttr/Valheim_Ascended/0.4.1/

**Decisive reasons:** a standalone replacement of the stack, not an axis-scoped talent/level system, and a verified lethal-hit escape.

- Author explicitly describes a complete standalone package, broad combat/spawning/UI/inventory changes, expected conflicts with mods in those systems, and untested interoperability (`ROOT/VA/README.md:13-21`). This is a source compatibility warning, not proof that every named pinned mod fails.
- Its enchanting gives items two slots and fifteen affix effects; smithing alters gear via component stat sliders; Mage/Paladin have Eitr abilities (`README.md:49-52,110-134`). **[INFERENCE]** This directly competes for EpicLoot's gear axis, BlacksmithingExpanded's profession axis and MagicPlugin's magic axis. Bow draw/controls replacement overlaps BetterArchery; loadout slots overlap AzuExtendedPlayerInventory; creature-star changes overlap CreatureManager (`README.md:75-102,159-166`). No claim of a proven startup conflict.
- Death cancellation is real code: `VA code/ValheimAscended.Patches/HitAffixPatch.cs:236-275` patches `Character.Damage`; equipped Undying affix zeroes lethal damage, sets HP to 1 and grants two seconds of immunity. It iterates equipped items and their affixes on lethal checks. This violates the required death contract regardless of vanilla skill-floor ordering. `ValheimAscended.Talents/TalentDefs.cs:722-724` also describes Undying Fury, a killing-blow survival talent; its full execution was not audited.
- Fit positives claimed: limited talent currency (30 boss-earned points), coin-cost respec, and party/map sharing (`README.md:39,63-67,184-193`). Progression is renown/milestones, including weapon mastery and professions, not the requested ordinary character kill-XP/attribute allocation owner (`README.md:172-180`). Party invite/cap/XP-budget formula was not verified.
- UI/hotkeys: full custom HP/stamina/Eitr bars and nearly every panel; G/H/B abilities, Q sheath, broad panel keys (`README.md:153-168,207-220`). **[INFERENCE]** This is especially unsuitable if vanilla bars and DetailedLevels skill UI are retained.
- Maintainability/source claims: explicitly early access, incomplete, unbalanced, expected breakage; smithing set bonuses unfinished (`README.md:7-11,133-146`). No attribution of AI authorship is supportable from that.
- Screen: `ROOT/VA/screen.txt:1`, clean.

**Coverage gaps after decisive rejection:** no exhaustive disable-switch inventory, server-lock audit, XP curve/point-config audit, save migration/corruption audit, hot-path profiling, or eight-player runtime. A targeted decompiled search found no `EnableEnchanting`, `EnableSmithing`, or `EnableProfessions` names; absence of these names alone does not prove no other disabling mechanism. Even selectively disabling affixes would not establish safe integration of this full replacement.

## 2. LionAndOtter/Oathbound 0.21.14 — REJECT for this concept

Primary package: https://thunderstore.io/package/download/LionAndOtter/Oathbound/0.21.14/
Primary guide linked by author: https://lionandotter.com/oathbound/guide/ (not separately audited).

**Decisive reasons:** shared XP is full reward per damage contributor, not invite-only party sharing; respec is unconditionally free. Among this slice it is the closest existing class/talent implementation, but not an install-and-configure solution.

### Fit and configurability

- Source claims 13 classes, 79-node trees, cap 80; each class retains separate XP/talents, only active class progresses (`ROOT/OB/README.md:3-9`). Equipment restrictions can be disabled; abilities/talent weapon requirements remain (`README.md:37-43`). **[INFERENCE]** That permits broader equipment use, but does not turn class spell/companion access into the required anyone-can-do-anything soft specialisation.
- Plugin binds server-controlled `ExperienceMultiplier` in range 0.1–10 (`OB plugin:10147-10160`); core curve is hard-coded `100 + 50*(level-1)`, max 80 (`OB core/Progression.cs:10-12,94-107`). Thus XP speed is tunable, curve shape is not shown configurable.
- Respec button literally says **Reset for free** and calls `Respec`, clears buffs, persists; there is no payment in that path (`OB plugin:12637-12645`; `OB core/Progression.cs:218-221`). Meaningful-cost respec fails.
- Shared XP config explicitly says **full enemy EXP to each player who damaged it**, no distance limit, companions count (`OB plugin:10784-10786`). Server `RouteDeath` verifies creature ownership, deduplicates death, and sends the same reward `num * _xpMultiplier` to each contributor (`OB plugin:9891-9941`). At eight contributors this is eight full rewards, not a configurable 110–125% shared budget. There is no party membership in that routing path.
- Default sieges/blood moons reach into encounter/world difficulty; toggles exist (`OB plugin:6285-6288,10900`; README:8,37-41). Blood-moon senses/star multipliers are expressly local/spawning-host-controlled in their config descriptions: disable the feature for fixed CreatureManager difficulty rather than assuming all balance settings are server locked.
- Verified axis crossings: talents modify attack damage/crit (`OB plugin:559-583`), armour (`666-675`), and maximum health/stamina (`522-532`). **[INFERENCE]** These stack with EpicLoot/ImpactfulSkills/AdditiveDamageModifier rather than leaving attributes exclusively to the level pillar. Mage/Warlock and pet classes add another ability/magic layer (README:5,29). No enchanting/smithing feature is claimed by the README; none was encountered in inspected paths, not an exhaustive absence proof.

### Death, authority, code quality

- `Player.OnDeath` patch is a void prefix with exception logging (`OB plugin:716-729`), not a false-return death cancellation. Applies active-class XP penalty once to owning local player and persists (`7254-7274`); core loses half unfinished-level XP without levels (`OB core/Progression.cs:239-247`). It does not directly write vanilla skills in this path. **[INFERENCE]** WAP's ordinary skill floor can remain active; actual ordering/runtime alongside WAP was not tested.
- Server routes/deduplicates rewards; client applies character progress and persists in `Player.m_customData`. Config synchronization uses Jotunn `SynchronizationManager` and server-session snapshots (`OB plugin:9787-9801,10159-10160`). No separate ServerSync dependency was established. Server-routing is stronger than purely local kill awards, but it is not proof of cheat-resistant progression: save/class state remains character-side.
- Good persistence hygiene: version decode, preserved pre-migration snapshots, FormatException prevents replacing corrupted saved progression, `Persist` refuses write when load error exists (`OB plugin:10469-10512`). Author warns old releases cannot read format 7, migrated talents refunded (`README.md:47-51`). This is a concrete positive, not merely a popularity signal.
- Many postfix resource modifiers, but also invasive patches. `Character.ApplyDamage` transpiler injects at the **second** `HitData.GetTotalDamage` call; throws when total-read count changes (`OB plugin:889-915`). Startup verifies numerous reflected hook signatures; on failure unpatches itself and disables plugin (`10161-10174,10311-10338`). Good fail-closed strategy; call-order transpiler remains brittle. Static screen cannot validate its IL-shape assumption.
- Null/ownership/finite-number guards visible in damage resolve (`OB plugin:918-932`) and creature routing (`9905-9914`). Server recipient lookup uses `GetPeers().FirstOrDefault` per rewarded contributor and allocates a packet per contributor (`9921-9941`); kill-event work, not evidence of a problematic per-frame path.
- Maintainability concern: `Plugin.cs` exceeds 12,600 lines and combines UI, netcode, classes, raids and persistence; broad change surface. WIP is author acknowledged, with scripted two-player XP checks but broad multiplayer still ongoing (`README.md:47-51`). No verified AI authorship claim.
- H/B/J/K default ability/companion keys; skill/inventory interfaces and full trait descriptions need Shakedown collision checks (`README.md:29`). **[INFERENCE]** B/H can collide with other mod binds. Guild membership is not substituted by its contributor set.
- Screen: `ROOT/OB/screen.txt:1`, clean.

**Gaps:** exhaustive per-frame allocation audit, every class's lethal-save perks, exact Jotunn compatibility attribute flags, points-per-level configurability and UI co-existence not verified. These cannot rescue the observed free-respec/full-contributor-XP mismatch. No actual 1.0.16 launch was performed; README claims it is tested there (`README.md:19`).

## 3. Alpus/NorseDemigods 1.7.1 — REJECT

Primary package: https://thunderstore.io/package/download/Alpus/NorseDemigods/1.7.1/

**Decisive reason:** demigod skill plus class magic and infused permanent stats, not a selectable talent-point/attribute-point owner. It brings a parallel magic/progression system.

- Classes consist of god-specific spells/companions and preferred weapons/armour (`ROOT/ND/README.md:3,51-67`). Permanently consumed infusions increase HP, block armour, Eitr/regen, attack speed and armour (`README.md:69-96`). **[INFERENCE]** That competes with level attributes and MagicPlugin, and changes combat power alongside EpicLoot/ImpactfulSkills. There is no talent-point purchase tree documented here.
- Optional teleport/harpoon features can be disabled (`README.md:32,49`); full class magic/permanent-stat feature isolation was not verified. Auto-config rebalance overwrites advanced settings on update unless disabled (`README.md:5`): important deployment risk, not a runtime hard conflict.
- Death interaction is unusually direct: prefix snapshots demigod skill; postfix rewrites its level and accumulator after `Skills.LowerAllSkills`, either restore entirely (default loss disabled) or subtract fixed configured levels down to zero (`ND code/NorseDemigods/NorseDemigods.cs:1299-1335`). Same target as WAP. **[INFERENCE]** Depending on ordering and whether WAP applies to this custom skill, this can bypass/overwrite its floor for the demigod skill; it does **not** rewrite all vanilla skills in the inspected patch. Do not report a proven general WAP conflict without runtime/ordering evidence.
- Config has XP gain modifier 20–500%, fixed level loss on death/class-switch, optional boss-derived cap (`ND code/NorseDemigods/Configs.cs:246-255`). Class switching has a potential meaningful penalty but only if skill-loss mode enabled; this is not talent respec.
- Quality observation: skill snapshot uses static fields, not per-call `__state`, so reentrancy/shared-instance ordering is brittle (`NorseDemigods.cs:1302-1314`). Uses mostly prefix/postfix for this path. Source claims 1.0 update, experimental classes explicitly gated (`README.md:198-206`). No polishedness conclusion from counts.
- Hotkeys mouse side buttons, block combos, Alt override, P teleport (`README.md:35-49`); **[INFERENCE]** overlaps input-oriented pinned mods should be bound deliberately. No own enchanting/smithing system established beyond infusion crafting.
- Screen: `ROOT/ND/screen.txt:1`, clean (includes bundled AnimationSpeedManager).

**Gaps after decisive rejection:** intentional parties/shared XP/map contract, save schema/migrations, effective server locking, complete ability-disable/config surface, per-frame allocations, Harmony ordering with WAP and magic skill UI collisions. None were treated as verified compatible.

## 4. momos3939/ValheimLegends 0.7.12 — REJECT

Primary package: https://thunderstore.io/package/download/momos3939/ValheimLegends/0.7.12/

**Decisive reason:** this is a twelve-class active-ability/magic-skill layer, not the requested character attribute-point level or limited-point talent tree.

- Author lists twelve classes, three named abilities each, class change by sacrificial offering (`ROOT/VL/README.md:36-104`). There is meaningful item-based class change in concept, but not purchased talent respec. No enchanting/smithing profession is documented; **Enchanter** is a combat ability class, not EpicLoot-style gear crafting (`README.md:93-96`).
- Code creates **six custom skills**: Discipline, Abjuration, Alteration, Conjuration, Evocation, Illusion (`VL code/ValheimLegends.cs:2026-2048,2531-2571`). Abilities scale/read those skills and call `RaiseSkill` (e.g. `Class_Berserker.cs:153,178-187`, `Class_Druid.cs:47-68`). **[INFERENCE]** This adds another magic-school progression layer beside MagicPlugin and another skill UI population beside DetailedLevels; neither supplies the separate character-level attribute allocation or point-limited talent axis.
- Verified ranged combat change sets projectile velocity and damage multiplier for Power Shot (`ValheimLegends.cs:736-738`): **[INFERENCE]** potential BetterArchery/EpicLoot interaction; no proven startup conflict.
- Quality issue: repeated `GetSkillList().FirstOrDefault(...).m_level` reads without guarding a missing skill (`Class_Druid.cs:47-48`, `Class_Berserker.cs:178-179`). **[INFERENCE]** A missing custom-skill registration/state can null-dereference; not reproduced. Save restoration accesses custom `VL_SkillData` and invokes reflected `Skills.GetSkill` when missing (`ValheimLegends.cs:1616-1645`); full corruption/migration handling not audited.
- README claims fully audited 1.0 patch signatures, server-sync balance settings and preserved class on death (`README.md:16-32,134-151`). These are claims, not independently reproduced. Inspected skill raises use ordinary `RaiseSkill`; **[INFERENCE]** WAP may still see them, but no floor/death patch-order proof.
- Configurable Z/X/C ability binds and global cooldown/stamina/damage/skill-gain multipliers (`README.md:108-115,134-142`). **[INFERENCE]** Z overlaps vanilla guardian-power activation unless mod handles context; ProgressivePowers/input coexistence needs actual play. Party heals/buffs are abilities, not invite-only XP/map party membership.
- Screen: `ROOT/VL/screen.txt:1`, clean.

**Gaps after decisive rejection:** server authority/lock mechanism and exact compatibility flags, death/skill-floor ordering, XP sharing/group membership, complete save handling, hot-path allocation audit and class disable controls. No full 1.0 runtime validated.

## 5. BunzBoiModding/ValheimWeaponClasses 1.1.3 — REJECT

Primary package: https://thunderstore.io/package/download/BunzBoiModding/ValheimWeaponClasses/1.1.3/

**Decisive reason:** levels automatically unlock predetermined perks, not limited points buying a talent build; no attribute-point level allocation either.

- README describes ten weapon classes, level 1–50, passive unlocked every ten levels (`ROOT/WC/README.md:5-9`). Code confirms fixed perk thresholds and class-level eligibility, e.g. SwordMaster +7% sword damage at 10, stamina/movement at 20, later riposte/attack-speed buffs (`WC code/SwordMasterPerkManager.cs:24-54,93`). No player talent purchase choice exists in that verified path. **[INFERENCE]** It is a weapon-specialisation overlay rather than a talent-tree candidate.
- Important stale README correction: README says only `EnableMod` config, hardcoded XP and no RPC anywhere (`README.md:100,115,123`). **That is false for downloaded 1.1.3**: plugin version is 1.1.3 and initializes `XPConfigManager` (`WC code/ClassObeliskMod.cs:10-18,30-40`). `XPConfigManager` creates a separate XP cfg, binds creature values, all level thresholds and star multipliers, registers it with Jotunn `SynchronizationManager`; helper adds `IsAdminOnly=true` (`XPConfigManager.cs:109-158`). Decompile also contains `ClassSyncRpc.cs` and roster resync class. README's identity table says 1.1.0 (`README.md:11-17`), so treat developer architecture claims as old scope, not authoritative for the shipped version.
- XP pace therefore **is configurable**, a positive; points-per-level/respec does not describe its fixed-perk architecture. This avoids incorrectly rejecting it for an obsolete README configurability claim.
- Weapon classification actually uses `m_skillType` and item types with null guards, not just name matching as README suggests (`ClassCombatManager.cs:45-142`). Positive improvement in interoperability.
- Persistence uses `Player.Save` postfix, prepares serializable class data and appends JSON to the character ZPackage, catches/logs errors (`Player_Save_Patch.cs:5-31`). **[INFERENCE]** Appending to native package rather than namespaced `m_customData` increases multi-mod format coupling; actual load rollback/corruption behaviour not audited.
- No enchanting/smithing documented. Wizard/Warlock and automatic weapon combat bonuses duplicate parts of magic/combat power axes (`README.md:7-9`; `SwordMasterPerkManager.cs:26-52`). **[INFERENCE]** BetterArchery, ImpactfulSkills and EpicLoot balance interaction needs Shakedown; no hard conflict was proven.
- Screen: `ROOT/WC/screen.txt:1`, clean.

**Gaps after decisive rejection:** party XP formula/map membership, death/skill-floor integration, actual RPC authority validation/server-lock enforcement, save-load schema migration, each perk's hot path and class switching costs. The code differs materially from the README, so do not inherit its old multiplayer/debug-command criticisms without current code inspection.

## 6. JGSTUDIOS/JGRPG 0.1.63 — REJECT

Primary package: https://thunderstore.io/package/download/JGSTUDIOS/JGRPG/0.1.63/

**Decisive reasons:** XP/level is shared globally by the world, not earned by a character or deliberate party; talent resets are free.

- README explicitly advertises shared world RPG level/XP, boss caps, free talent resets, five active abilities for each of three classes (`ROOT/JG/README.md:3-14`). This gives a level/talent system, but wrong progression ownership for personal boss-key carry/re-kill progression and invite-only parties.
- Verified code: `WorldProgression` static Level/XP/LevelCap; `AddXP` only on server; persists world progress and broadcasts (`JG code/WorldProgression.cs:3-47`). Level requirements are table-indexed, cap 90. This is server-authoritative world progression, **not** eight-person party XP sharing. No party configurable budget appears in this path.
- Classes centre on Tank armour/blocking/damage reduction, Berserker damage/attack speed, Ranger explosive ranged and party buffs (`README.md:17-26`); **[INFERENCE]** another combat power owner overlapping EpicLoot/ImpactfulSkills/BetterArchery. No enchanting, smithing or general spell-school feature claimed in this source.
- Avoid a misleading death accusation: despite the name **TooAngryToDie**, inspected patch merely modifies incoming damage; it does **not** cancel death (`JG code/BerserkerTooAngryToDiePatch.cs:5-18`). Passive getter clamps damage reduction, not resurrection (`BerserkerPassiveBonuses.cs:77-91`). Full death/floor compatibility remains unknown.
- U talent UI, Shift+1–5 abilities, gamepad overrides; configurable (`README.md:29-53`). **[INFERENCE]** UI/input collisions require actual play. README states dedicated server/client install and multiplayer tested with edge cases remaining (`69-80`), not evidence for this pinned stack.
- Screen: `ROOT/JG/screen.txt:1`, clean.

**Gaps after decisive rejection:** full XP/points configurability, server-config lock, world save atomicity/migration, character talent save corruption behaviour, Harmony target overlap, per-frame allocations and WAP runtime ordering. World-scope progress and free reset already violate the concept without relying on those unknowns.

## Final comparison

| Mod | Exact version | Verdict | Decisive reasons |
|---|---:|---|---|
| Valheim Ascended | 0.4.1 | REJECT | Standalone replacement of professions/gear/combat/UI; verified Undying blocks lethal hits |
| Oathbound | 0.21.14 | REJECT | Free respec; contributor sharing grants full XP each with no party budget/membership |
| NorseDemigods | 1.7.1 | REJECT | Demigod skills/spells/permanent infusions instead of point-limited talent/attribute axes |
| ValheimLegends | 0.7.12 | REJECT | Class abilities and six magic/discipline skills, not attribute-level/talent-point systems |
| ValheimWeaponClasses | 1.1.3 | REJECT | Fixed level-unlocked weapon perks, not player-purchased talent builds |
| JGRPG | 0.1.63 | REJECT | Global world XP/level instead of character/party; free resets |

**Top recommendation for this slice: none for the current concept.** Oathbound has the most convincing inspected save/error/authority safeguards and is the closest class-tree package, but its observed respec/XP model cannot satisfy the contract through the verified configuration. This is a concept-fit rejection, not a claim that it is bad software or cannot enter a differently scoped server. All six static screens pass; none was rejected for a proven startup failure. Download counts were not used.
