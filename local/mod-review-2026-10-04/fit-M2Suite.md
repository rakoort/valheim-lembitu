# M2 suite fit research — 2026-10-04

## Scope, provenance and result

**The three-mod suite cannot be configured to satisfy ADR-0019 as written.** SkillsReworked can preserve practice professions by leaving their skills unmapped, but its attributes purchase skill levels, not independent base attributes. Pure Level mode has **zero spendable attribute points**, and hides the Rebirth button. Its death patch bypasses WAP's floor. TalentTree deliberately has no balance/off switches, globally rewrites combat even with no talents bought, and includes lethal-hit prevention and Guardian Power control. SocialSystem is the promising individual component: invite-only, server-managed, cap 8, map positions, independent of guilds; however it also shares health/status and supplies party chat/ready checks/friends, beyond the literal “nothing else” boundary.

Evidence abbreviations: `R` = `/tmp/lembitu-research/ProgressionCluster`; `S` = `/tmp/lembitu-fit/M2Suite/SocialSystem.cs`; `P` = `local/mod-review-2026-10-04/conflicts-ProgressionCluster.md`. Existing SkillsReworked/TalentTree decompiles and prior research were reused, not regenerated. SocialSystem 1.0.4 was downloaded and decompiled with ilspycmd. Exact package sources:
- https://thunderstore.io/package/download/M2Valheim/SkillsReworked/2.1.0/
- https://thunderstore.io/package/download/M2Valheim/TalentTree/2.3.3/
- https://thunderstore.io/package/download/M2Valheim/SocialSystem/1.0.4/

Primary metadata queried: https://thunderstore.io/api/experimental/package/M2Valheim/SkillsReworked/ ; https://thunderstore.io/api/experimental/package/M2Valheim/TalentTree/ ; https://thunderstore.io/api/experimental/package/M2Valheim/SocialSystem/ . All returned the requested version as latest, dependencies BepInExPack 5.4.2351 and Jotunn 2.30.2; TalentTree additionally hard-depends on SkillsReworked 2.1.0. Latest publication timestamps respectively 2026-10-03 18:15:36Z, 18:16:40Z, 18:17:13Z. Package inception dates respectively 2025-12-08, 2026-07-01, 2026-09-15. No download-count quality proxy used.

Authority: `docs/adr/0019-the-server-concept-mmorpg-lite-for-rival-guilds-that-cooperate.md:25-55,70-79`.

## 1. SocialSystem 1.0.4 — POSSIBLE (strongest component)

### Party size, invites and positions

Observed: `Max party size` defaults 8 and accepts 2–10, server-synchronized Jotunn binding. Invite timeout defaults 60 seconds, rejoin reservation 5 minutes, position sharing true. `S:225-243`. Server validates self-invite, leader-only invitation, already-in-party, capacity, recipient filter, cooldown and pending duplicate (`S:7408-7455`). Acceptance validates the actual pending inviter and expiration, connected inviter, recipient still ungrouped, inviter still leader and capacity **again**, then creates a party if needed and adds the invitee (`S:7457-7501`). Thus concurrent outstanding invitations cannot overfill a party through normal acceptance. No guild condition is present in these checks: mixing Northarun guilds is allowed by this party implementation, not an integration with guild membership.

Server sends positions once per second (`S:8569,8664-8674`), collects connected party members and sends their server-session positions only to party members (`S:7867-7896`). **Invisible status excludes your position even inside the party** (`S:7877-7889`), a qualification to README's “always visible” claim. Map visibility is appended via a postfix to `ZNet.GetOtherPublicPlayers` (`S:9040-9045`), not exploration/map reveal. Party-ID is published into the owning player's ZDO (`S:9850-9870`); SkillsReworked reads that key (`R/SkillsReworked.cs:4841-4868`).

### Authority, config and excess scope

Observed server session dispatch and party service own membership. Malformed requests are caught and logged (`S:8604-8630`), UI-only capacity gating is not the authority. The owner client publishes the party ZDO used for XP; XP itself is not server-accounted (see question 2). Gameplay party config uses Jotunn `BindConfigInOrder(... true, true, true ...)` (`S:227-231`), and a `NetworkCompatibility` attribute exists (`S:81-82`). **Exact attribute enum values and Jotunn's global lock behavior are not decoded/proven in this decompile**; README says server and all clients required (`/tmp/lembitu-fit/M2Suite/SocialSystem/README.md:43,53-54`). Do not promote synchronization to verified cheat-proof enforcement.

Literal concept excess: party HUD exposes avatar/name/level/health; health vitals synced every 0.25 seconds (`S:8571,8658-8662,7899-7914`); friends/status/direct messages, party chat and ready checks exist (`README.md:21-30,70-76`). HUD can be hidden personally (`S:238`), but that does not disable the protocol or server sharing. No server switch for these extra features in the complete bindings (`S:225-248`). Under a gameplay-only interpretation these are coordination/readout features, not extra damage/loot/XP buffs; accepting them is a dispatcher decision, not a claim that it meets “nothing else” literally.

### Quality, persistence and conflicts

More bounded than TalentTree: mostly postfixes for map/name highlighting and connection/spawn integration; prefixes chiefly protect UI/input/session shutdown (`S:8898-9045`). Server uses reusable member/invite/cooldown buffers (`S:7360-7370,7917-7925`), position packets once/sec and changed vitals only (`S:7899-7914`). It still traverses invites every frame in Tick (`S:8654-8657`); no measured pathological performance. Friend persistence is per-character customData (`S:10603-10633`); delimiter/base64 deserializer skips malformed IDs/base64 entries (`S:9982-10005`), with no explicit backup/version migration on this small record. Parties/invitations/messages are session-only (README claim `README.md:44-45`; server clear `S:8644-8651`). This is a suitably temporary party model.

Changelog evidences a young component and real repairs: 1.0.1 stale party membership/XP, 1.0.3 dedicated-server invitations/friends, 1.0.2 Linux cursor/controller (`CHANGELOG.md:4-13`). These are fixed-version source claims, not runtime reproduction. No defensible evidence of AI authorship. Modular services and embedded testing/virtual-player tooling are visible, but cannot prove testing coverage or polish.

Overlap surface: `ZNet.GetOtherPublicPlayers` and `Minimap.Update` with other party/map plugins, `EnemyHud.UpdateHuds` with readouts, inventory input with AzuExtendedPlayerInventory; default O/P keys are rebindable (`S:234-235`). No same-axis stat conflict with EpicLoot, CreatureManager, professions, powers, BetterArchery or MagicPlugin identified. [INFERENCE] UI collision with guild/SkadiNet map displays requires actual surface verification; no live combined client run done.

## 2. SkillsReworked 2.1.0 — REJECT for the specified level axis

### Party XP formula (including SocialSystem integration)

Observed: killer gets full base XP; every other nearby party member gets `xp * Clamp01(GroupShareFactor)` individually. Radius measured around killer, not victim; party membership reads ZDO IDs, falling back to old Groups API (`R/SkillsReworked.cs:4975-5007`). Default radius 50m, share 0.3; both synced configurable, radius 0–100 and factor 0–1 (`:5816-5818,5836-5837`). Receiver-level biome penalty applied per recipient (`:2785-2830`; changelog `M2Valheim-SkillsReworked-2.1.0/CHANGELOG.md:54`).

For one nonboss kill with n eligible members at equal scaling, total XP relative to solo is **1 + (n−1)f**. At n=8, f=0.3 yields **310%**, not 110–125%. Choosing f=0.0142857–0.0357143 yields 110–125% for eight; 0.03 yields 121%. But there is **no group-size normalization**: f=0.03 gives 103% for two and 109% for four. No single factor produces 110–125% for every party size 2–8 (two requires f≥0.1; eight requires f≤0.0357143). This is arithmetic derived directly from the code, not a game measurement. Also boss XP goes in full to everyone within 300m/key eligibility, party or not (`:2308-2333`), so eight nearby players receive approximately 800% of one solo boss award at equal scaling. No party-size knob changes that.

Authority: creature death announces a routed RPC; local player computes recipient eligibility, adds unique defeat key and XP (`:2285-2342`). Sender parameter is unused in the shown award handler; server-authoritative level accounting is not present there. Config synchronization does not change this trust boundary.

### Pure Level vs mapped attributes and professions

**Pure Level mode cannot buy anything with Level attribute points.** Empty attribute lists make `ActiveCount=0`; `MaxSpendablePoints=ActiveCount*100`, total points clamp to that maximum (`:3521-3536,3735-3771`). Attribute/rebirth UI hidden when none active (`:860-872`, previously read); talents still independently derive their own point budget from Level (`R/TalentTree.cs:18859-18871`). This is a level→talent economy only, not level→base attributes plus separate talents. Migration pure-mode early return avoids resetting existing trained skills (`R/SkillsReworked.cs:3090-3098`).

Mapped attributes can be purchased (points/level 0–4, milestone points 0–40 configurable: `:5819-5828`), but a mapped skill no longer advances by practice: RaiseSkill returns true only for assignable **unmapped** skills (`:3584-3591,4688-4713`). Unmapped vanilla and injected profession skills can continue through use; do not map Herbalist/Blacksmithing/Forging/etc. Mapping only combat skills preserves professions, but Strength/Dexterity/etc remain proxies for skill levels, not health/stamina/eitr independent attributes. README/changelog 2.1.0 confirms empty slots hidden/refunded, unmapped skills use vanilla practice (`CHANGELOG.md:5-8`); 2.0's “all unassigned follow Endurance” is superseded, not the current behavior (`:24-29`). Thus prior blanket statement that M2 replaces all practice advancement needs this version-specific refinement.

### WAP floor bypass and size of a fix

No upstream floor-respecting switch in shown config; `Death XP loss` controls **Level** loss only (`:5830`). `Skills.OnDeath` prefix manually multiplies unmapped skills and zeroes accumulators, then returns false (`:4640-4686`). WAP patches `LowerAllSkills`, not these writes (`R/VentureValheim.Progression.cs:3187-3213`). This is a proven bypass, even pure mode.

[INFERENCE] The immediate drain correction is localized to the ~17-line `LowerVanillaSkills` helper: delegate eligible practice-skill drain through WAP's policy or an integration. **Replacing it blindly with `skills.LowerAllSkills(factor)` is not safe**: WAP iterates every native skill datum, including Level and synthetic attributes, normalizing all to its boss-key floor (`WAP:3202-3207`). That would alter Level independently of M2's intended XP penalty and drain purchased attributes. WAP also patches `Skills.Skill.Raise` (`:3216-3239`); isolating the character-level skill from WAP gain/floor semantics is a second integration boundary. A safe fix must select practice skills while retaining WAP's floor/relative-vs-absolute/no-drain rules, not copy a fixed floor. Exact public WAP integration API suitability, patch order and live combined behavior remain unverified. There is no credible “one-line fix and done” evidence.

### Curve, costs, saves and quality

Level requirement shape is hardcoded `floor(level+1)^1.5 * .5 + .5` (`:2706-2711`). XP multiplier, biome optimal levels/minimum penalties, boss multipliers and skill-use XP are configurable (`:5829,5838-5870`); this tunes pace, **not arbitrary curve shape**. One-month Fader target is not established by source or screen.

Rebirth defaults **2 Levels + 999 Coins**, configurable None/LevelOnly/ItemOnly/Both and costs enabled flag (`:5831-5835`). Rebirth validates requirements, consumes levels/items, resets attributes and fires event; TalentTree subscribes to reset (`:2413-2469`; TalentTree `:12881-12884`). Pure-mode hidden Rebirth is another obstacle to normal talent respec access without mapped attributes.

Save hooks store/restore progression on Player.Save/Load (`:4762-4777`); customData scalar parsing invariant-culture with defaults/null guards (`:3850-3921`). Initial mapped-mode migration explicitly asks confirmation and can permanently reset trained skills; package warns backup (`CHANGELOG.md:21,33-37`); pure-mode skip noted above. Broad reflection integration injects SkillManager definitions with warnings/type-load handling (`:4898-4970`). Code has caching/null checks and localized exception handling, not simply unguarded patch soup. Nonetheless core OnDeath/RaiseSkill suppressions, direct skill-level authority and irreversible migration are substantial compatibility liabilities. No basis to assert AI generation. Cadence includes full model rewrite 2.0 followed by 2.1 changing unmapped-skill policy; deliberate current architecture, but materially unstable save/balance contract (`CHANGELOG.md:2-40`).

Pinned conflicts: WAP demonstrated; DetailedLevels shares skill dialog (`P:171,180`); custom profession SkillManager injection/death bookkeeping may compose imperfectly [INFERENCE] (`P:114`). ImpactfulSkills/Herbalist/Blacksmithing/ExpertExplorer are preserved only unmapped. SocialSystem itself is supported. No intrinsic dynamic creature scaling or new gear/content owner shown. Corpse run/timed debuff not supplied by this level mod; existing game/other mods must own them.

## 3. TalentTree 2.3.3 — REJECT

### Every relevant talent / formula surface

No talent changes the **random-roll formula** individually: the mod globally forces constant `0.4+.3*skillFactor`, including zero-investment characters (`R/TalentTree.cs:20715-20750`). Global armor effectiveness .65 and creature armor enabled are constants/readonly, not settings (`:14206-14242`). Global bow draw floor .3, movement slowdown, weapon-block/stagger/parry changes likewise are combat ownership, not optional playstyle perks (`:20466-20510,20600-20645`; packaged README `:198-275`).

Complete scope inventory by named talent (damage here includes added/conditional damage, mitigation and armor-derived attacks, not just the global roll):

| Family | Relevant nodes and effects | Primary code |
|---|---|---|
| Shared | **Armor** minors + armor sector amplifier mid nodes; **Physical Damage** minors + physical-damage amplifier mids | registrations `:6115-6180,10488-10550,11203-11257,12149-12190` |
| Warrior | **Master at Arms** slash/stagger/pierce DoT; **Revenge** stored-hit blunt bonus; **Even Ground** armor and physical resistance tier easing; **Hamstring** enemy armor reduction; **Last Bastion** armor-derived heal, lethal-hit prevention/invulnerability; **Triumph** armor-derived ally healing; **Reflect** parry reflected damage; **Focus** incoming damage multiplier | `:6144-6190`; Last Bastion execution `:6009-6041`; Even Ground `:6282-6322` |
| Berserker | **Glass Cannon** damage and armor reduction; **Execution** low-target-HP damage; **Savage** extra melee damage proc; **Deferred Pain** damage redistribution; **Forged in Pain** damage reduction; **Tether** knockback resistance; **Blood Rush/Axe Mastery/Overwhelm** affect attack cadence/stagger, not random-roll formula | `:12143-12218` |
| Bulwark | **Iron Skin** armor; **Ironclad** armor→HP; **Immolation** armor→fire damage aura; **Bulwark's Edge** HP→bonus damage; **Thorns** reflected pre-armor damage; **Shield Slam**, **Shield Charge** added attack/blunt damage; **Pavise** ranged damage mitigation | `:11211-11264` |
| Hunter | **Hawk Eye** projectile distance damage/zoom; **Quiver Economy** ammunition preservation; **Double Shot/Triple Shot** extra reduced-damage projectiles; **Steady Aim** velocity; **Quickshot** release/draw drain; **Heavy Draw** ranged knockback; **Deadeye** draw/reload time, damage, armor penetration; **Explosive Shot** bomb-consuming projectile explosion; **Hit and Run** post-projectile movement | `:10492-10551,10555-10605` |
| Valkyrie | **Lethal Patience**, **Feint**, **Duel Series** damage bonuses; **Weapon Flow** ranged knockback/melee stagger+armor penetration; **Weapon Swap** ranged/melee swap mobility; **Battle Waltz** attack speed | `:9161-9169,9197-9225` |
| Warcaller | **Chain Lightning** magical chaining + armor reduction; **Storm Lord** HP-scaled lightning detonation; **Necromancer** raised enemy ally; **Frost Emperor** slowing aura; **Divine Favor** Guardian Power cooldown + cycling unlocked powers; **Banner Bearer** shield-only armor/aura amplification; **Demoralize** reduces victim's outgoing damage | `:6857-6905`; README `:185-192` |

Magic ownership is not a separate spell-school progression tree, but fire/lightning/necromancy/frost effects unquestionably overlap that axis. These named effects are compiled registrations, not a YAML talent registry. README explicitly says **no balancing config for talents or combat changes** (`R/M2Valheim-TalentTree-2.3.3/README.md:281-285`); constants confirm it. Not spending a talent is not server disabling it, and does not stop the global formula changes.

### Death, respec and concept fit

Last Bastion specifically converts lethal damage to survival, removes burning/poison and makes player invulnerable (`:6009-6041`; README `:110`). This violates the no-second-life/cancel-death criterion. Limited talent allocation/hybrid builds match soft specialization; point budget 1/Level + 5/boss with costs minor/mid/keystone 1/2/3 is fixed code (`:18859-18879`). Meaningful respec cost inherited from SkillsReworked above, but pure Level mode hides its normal Rebirth UI. Bought talents remain active after Level loss (README `:57-60`), reducing punitive death power impact beyond the XP setback.

### Code quality, save handling and compatibility

Nontrivial engineered systems: versioned talent state, replacement migration catalog (`:18710-18815`), JSON customData with null guards and catches (`:18816-18857`), cached runtime/sector definitions and modular implementations. On corrupt JSON load it logs and continues; no backup/quarantine in that persistence helper, so [INFERENCE] a later normal save can overwrite malformed state with an empty/default state. No corruption injection run.

However patch surface is wide and fragile: BlockAttack transpiler searches fields plus nearby branch/Mul heuristic and flips a branch (`:20466-20510`); draw transpiler scans literal .2 followed by Mul and **throws** if absent (`:20600-20618`); additional transpiler exists (`:8872`). Stale-member screen cannot establish those IL patterns still match. Hot-path local draw postfix is guarded and arithmetic-only (`:10573-10604`); broader aura/cache/UI allocations were not profiled. Avoid inferring performance quality from the number of classes. No verified AI-generation signal; compiler-generated classes and NoOpEffect marker are not authorship evidence.

Changelog demonstrates substantial balance churn and multiplayer correctness repairs: 2.3 changes armor formula, creature armor, minor scaling and many auras; 2.3.1 fixes Savage triggering on magic/ranged; 2.2.3 fixes remote stale talent effects; 2.3 fixes remote stagger/chain/immolation plus logout invulnerability (`CHANGELOG.md:20-30,61-74`). Real active maintenance, but recent critical combat bugs and changing baseline; not proven polished by current downloads. Metadata dates above; per-historical-release dates not supplied by the experimental endpoint, so exact releases/day remains unknown.

Pinned conflicts/overlaps: EpicLoot owns damage/armor effects but TalentTree rewrites their effective baseline; CreatureManager now also competes with fixed biome creature armor; ADM combines resistance while Even Ground interprets vanilla enum tiers (`P:46-50,66-70`; direct `:6282-6322`). BetterArchery velocity/zoom/draw/movement overlap Hunter and global draw patches (`P:72-82,187`). ProgressivePowers cooldown/blocked activation conflicts in scope with Divine Favor cycling; MagicPlugin's spells/projectiles coexist with a second magical-effect owner, exact execution composition [INFERENCE]. DetailedLevels and Azu inventory button/window layout are UI composition gaps. Hotkeys Q/G/LeftShift have Hunter/Warden overlapping context, are rebindable (`P:172`). No explicit handshake attribute in reused M2 progression decompiles; Jotunn full enforcement remains gap (`P:171-172`).

## 4. Scoped binary validation and coverage gaps

Executed `scripts/screen-bundled-libs.sh --dir` against each exact extracted package, in order SocialSystem, SkillsReworked, TalentTree. Each printed **“clean: no stale game-member reference found in 1 library(ies)”**; command completed successfully. This is observed compatibility-screen evidence against the repository's current assembly set, **not proof of startup, transpiler match, rendering, RPC semantics or gameplay on 1.0.16**. No server deployed, game launched, repository edited, tests/builds run, or source fix implemented.

Specific remaining evidence gaps: exact SocialSystem compatibility enum/lock behavior; live M2/WAP gain + death composition including modded SkillManager skills; real combined HUD/keys with SkadiNet/Dive_In/Azu/Northarun; TalentTree transpiler application; measured one-month XP pacing; full aura hot-path profiling; historical per-release dates; user-controlled ZDO/RPC forgery behavior. None changes the configuration-only rejection: fixed combat formulas, zero pure-mode attribute budget and observed WAP bypass are already decisive.

## 5. Explicit configuration cost / comparison

| Mod | Version | Verdict | Decisive reasons |
|---|---:|---|---|
| M2Valheim/SkillsReworked | 2.1.0 | REJECT | Pure Level buys no attributes; mapped points replace skill practice rather than independent base attributes; OnDeath bypasses WAP floor |
| M2Valheim/TalentTree | 2.3.3 | REJECT | Unswitchable global gear/combat rewrites; Last Bastion prevents lethal death, Divine Favor/magic effects cross axis |
| M2Valheim/SocialSystem | 1.0.4 | POSSIBLE | Real server-managed invite-only cap-8 parties and positions; extra health/chat/ready-check scope and invisible-position opt-out |
| Complete M2 suite | exact versions above | REJECT | Cannot repair the level/attribute and floor contract or disable TalentTree combat/death/power behavior through configuration |

Cost to fit fully is **source work, not a config preset**: independent base-attribute effects/point spending in SkillsReworked; floor-aware eligible-practice death integration and separation of synthetic Level/attributes from WAP; normalized party XP and a boss reward policy if total-kill 110–125% is literal; TalentTree switches/removal for global formulas, death prevention, powers/magic and tree-path handling; pure-mode respec access; strict SocialSystem feature/visibility policy if “nothing else/always positions” is literal. [INFERENCE] First death-helper integration is localized, but full suite alignment is multi-boundary maintenance, not a small balance tweak. No implementation estimate asserted.

**Top component for this slice: SocialSystem alone, conditionally**, paired with a different level system or explicit XP adapter. Do not adopt the complete suite just to get its party integration. Dispatcher owns the ultimate scope interpretation and selection.
