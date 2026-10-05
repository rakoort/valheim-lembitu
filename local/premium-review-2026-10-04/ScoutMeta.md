# ScoutMeta — premium meta-system scouting

## Summary
1. **Try RustyMods/Almanac 3.8.0, narrowly as a codex and server-authored onboarding NPC.** It has locked ServerSync and synchronized dialogue content, but its default lottery/token store/marketplace/bounties are much broader than needed. Turn those off; do not introduce another progression or currency owner.
2. **Try Bagr/CrewStats 1.4.1 + DamageMeter 3.7.0 together**, for weekly profession recognition, boss-night chronicles, expedition summaries and death recap. Their statistics are client-reported, server-stored: excellent social evidence, not anti-cheat or a safe monetary reward oracle.
3. **Use Guilds' existing achievements rather than adding another guild achievement system.** Guilds 1.2.3 has 17 three-tier achievements across combat, crafting, gathering, building and travel. Some top thresholds fit a long grind better than a 50–60-hour month; do not make completing all gold tiers a launch promise.
4. **Try Skitale/ValheimAdminForge 0.5.0** for a coherent moderation GUI and audit log. Action authorization is server-side, not merely a hidden client window. Keep boss spawning off, strict item validation on, and player tags off to avoid Guilds chat/name overlap.
5. **Consider JereKuusela/Cron_Job 1.14.0** for scheduled announcements/join instructions and calendar operations. It runs server console commands from `cron.yaml`; do not automatically start vanilla raids, which Oathbound sieges replace, or write world boss keys.
6. **Consider HaEs/HaesServerMessages 1.6.2 as the minimal welcome/countdown alternative.** Despite its HAES-specific README, the DLL reads editable welcome/schedule text files. It is a message display, not a persistent rulebook; its message RPC does not authenticate the sender.
7. **Reject RtDQuestForge as the pack's cooperative contract engine in its current form.** Definitions are server-synced, but quest progress is a client JSON file named after the character, rewards are local, and kill credit goes to the killing blow, not the whole cooperating party.
8. **Progression integrity remains an unresolved prerequisite.** Both ServerCharacters packages in the full Thunderstore API are deprecated. Statistics/inventory logs are not server-character storage. Do not promise tamper-proof Callings/Oathbound/personal keys from these additions.
9. **Do not add FiresDiscordIntegration, DiscoveryJournal, or SealedTombstone by default.** Respectively: broad chat/control replacement and Windows wrapper assumptions; locally switchable knowledge progression violates the Pack rule; corpse permission friction works against rescuing a friend and is not strong anti-tamper.

## Method and compatibility evidence
Read-only review; no game launch, builds, tests, deployment, SSH or repo edits. Downloaded and decompiled **12 current packages**: Guilds, Almanac, CrewStats, DamageMeter, VikingStoryteller, ValheimAdminForge, FiresDiscordIntegration, RtDQuestForge, DiscoveryJournal, SealedTombstone, HaesServerMessages, Cron_Job. Each is updated after 2026-09-09 according to `/tmp/lembitu-premium/index.json`. Primary package bytes were fetched from `https://thunderstore.io/package/download/<owner>/<name>/<version>/`; versioned README is extracted alongside each DLL.

Citation shorthand below: `S/<package>` = `/tmp/lembitu-premium/ScoutMeta/<package>`. All `src/` citations are decompiled from the stated package version, not upstream head. README citations refer to that exact downloaded version.

Ran `PATH=$HOME/.dotnet/tools:$PATH scripts/screen-bundled-libs.sh --dir /tmp/lembitu-premium/ScoutMeta`: **clean: no stale game-member reference found in 12 library(ies)**. This is static member screening, not runtime compatibility proof. All downloaded candidates contain one plugin DLL each; none of these twelve package payloads requires a packaged preloader patcher. Dependencies are not part of this twelve-DLL screen: Almanac/Cron require YamlDotNet 16.3.1, QuestForge requires JsonDotNET 13.0.4 + Jotunn 2.30.0, AdminForge only BepInEx. Resolve against the pack's pinned dependencies, not by downgrading Jotunn.

A source search for `GetGlobalKey`/`SetGlobalKey` across all twelve decompiles found only AdminForge's explicit admin world-key editor and event requirement display; Almanac also describes a creature's defeat-key metadata. No evidence found that the other candidates need world boss keys for their core advertised use. This is a search result, not a guarantee about reflection or every dependency.

## 1. Try — RustyMods/Almanac 3.8.0
**What:** best integrated candidate for a codex, achievements, metrics, dialogue NPCs and quests, but the full feature set also adds tokens, stores, lottery, bounties, treasure hunts and a marketplace.

**Verified:** `S/Almanac/src/Almanac.Utilities/Configs.cs:579-597` registers `1 - General / 0 - Lock Configuration` with `AddLockingConfigEntry`; gameplay settings are synchronized unless explicitly presentation-only. `:602-662` exposes tab toggles. `S/Almanac/src/Almanac.NPC/DialogueManager.cs:2042-2043` creates the synchronized dialogue value/folder. Versioned README `:220-290,292-361` documents authored dialogue text, requirements and commands; `:400-428` documents YAML quests. `S/Almanac/src/Almanac.Tutorials/Tutorial.cs:22-37` loads embedded assembly tutorials: **do not mistake this for a verified arbitrary external Markdown rulebook loader**.

**Important authority limit:** achievement collection calls `Player.m_localPlayer.AddTokens` in `S/Almanac/src/Almanac.Achievements/AchievementManager.cs:639-647`. Synced definitions are not authoritative player completion. Use zero-token/no-stat rewards for onboarding and prestige. `Groups/API.cs:60-73` is the old Groups-style integration stub, returning false/empty absent a provider; **SocialSystem integration is not verified**. Do not advertise shared party contracts without a two-client check.

**Proposal:** trial with `1 - General / 0 - Lock Configuration = On`, `Knowledge Wall = On`, `Enable Conversion = Off`, `Admin Tools Check No Cost = On`; `2 - Tabs / Lottery = Off`, `Store = Off`, `Marketplace = Off`, `Treasures = Off`, `Bounties = Off`, `Status Effects = Off`; `6 - Achievements / Status Effects = Off`. Keep Items/Pieces/Creatures as the codex. Initially turn Achievements/Metrics/Leaderboard off if choosing CrewStats; enable only a small custom onboarding achievement set with `TokenReward: 0` if useful. Keep default NPC build requirement `SwordCheat:1:true` so ordinary players do not manufacture guide NPCs (`Configs.cs:718-720`). Author a guide at each guild start: Calling choice, 10-level-per-biome craft ladder, personal presence keys, no-PvP rivalry, and where the market lives. This is a recommendation, not content already implemented.

**Overlap:** directly patches `InventoryGui.Awake`, `IsVisible`, `Hide`, `UpdateTrophyList`, `Chat.HasFocus`, `Player.TakeInput`, `PlayerController.TakeInput` (named patch files under `Almanac.UI`). Trophy button replacement is explicit (`Configs.cs:588`). These surfaces share screen/input with Guilds, Marketplace, Oathbound, extended inventory and SocialSystem. Almanac Marketplace is a separate market, not verified Northarun integration. Bounties/treasure overlap EpicLoot Adventure and its economy. Custom NPC pieces become a save dependency; choose before world creation.

**Confidence:** high static feature/lock evidence; medium fit. **Shakedown:** actual inventory layout at 1080p/controller, focus trapping, guide-NPC placement, unknown-item filtering for modded gear, and dialogue party behavior.

## 2. Try — Bagr/CrewStats 1.4.1
**What:** lightweight shared co-op statistics and rotating recognition for cooks, miners, smiths, builders and explorers, not just damage dealers.

**Evidence:** `S/CrewStats/pkg/README.md:3-18` lists ten tabs, death causes, profession awards and Today/Last 7 days/All time. `:21-32` explains character-counter delta reporting, online-only accumulation, server-measured online time, and persistent server data. `src/CrewStats/Plugin.cs:513-517` exposes only window preferences, reporting interval and server log path, not gameplay multipliers; `:636-641` resolves sender against connected peers. No ServerSync locking found, but the feature changes no gameplay reward/difficulty: presentation preferences and reporting cadence do not create a second progression system.

**Proposal:** trial; maintain `Client / ReportSeconds = 30` as a pack default, allow personal window placement/hotkeys. Use weekly **separate** discipline commendations rather than a single damage/grind winner. Guild aggregation is **not native verified**: it shows individual columns. If guild recognition is wanted, judge against the Guilds roster manually; do not claim it automatically tracks historical membership changes.

**Overlap:** `Player.OnDeath`, damage/block hooks, inventory-adjacent button, input suppression and chat commands. Oathbound owns actual XP/death outcomes; CrewStats only observes. Damage totals differ from DamageMeter: README `:27` says before resistances, so never compare them as interchangeable measures.

**Integrity:** server persistence is real, but reports originate on clients; not proof against edited saves, fake reports or farming/automation. No material/XP rewards should be paid automatically from these numbers.

**Confidence:** high documented/code fit; runtime UI/accuracy still Shakedown-only. Review 3–5-person profession totals after one week before choosing month awards.

## 3. Try — Bagr/DamageMeter 3.7.0
**What:** boss-night result table, expedition chronicle and death recap; complements CrewStats through stored fight history.

**Evidence:** `S/DamageMeter/pkg/README.md:6-9,25-42` documents recap, inventories including AdventureBackpacks, expedition histories, server storage and client-owned creature measurements. `src/DamageMeter/Plugin.cs:2385-2394` gives local live-panel modes and server expedition start policy; `:2413` exposes `Server / SummaryDeathRecaps` (default false). CrewStats reads its server files (`CrewStats README:15-16,45`), a verified additive integration rather than another independent stats silo.

**Proposal:** `Live panel / Mode = Bosses only` as presentation default, `Server / SummaryDeathRecaps = true`, `Server / ExpeditionStart = Admins` initially, `Server / Awards = false` to avoid celebrating death or mocking weaker players. Inventory logging is **consider**, not a presumed anti-cheat solution: explain it to players and decide privacy/retention before enabling it. The expeditions are a server-wide running aggregate; do not assume SocialSystem party membership filtering.

**Fit:** recap/chronicle makes eight-player boss nights memorable without accelerating Fader. Prefer after-fight information over permanent DPS pressure; tanking/parries/deaths are visible but healer contribution is not a verified complete score.

**Overlap:** `Character.ApplyDamage`, `Character.RPC_Damage`, character death, player death and `Humanoid.BlockAttack` observer patches (source files under `DamageMeter/`). Oathbound/CreatureManager/EpicLoot operate on those systems too; no observed takeover of their difficulty or death penalties. F6/F8/F9/F10 defaults need a pack-wide keybind check. Native source is server aggregation of client observations, not damage authority.

**Confidence:** high static fit. **Shakedown:** eight-player damage attribution, summons/DoT, boss death table, personal-key attendance versus meter range, Oathbound sieges and Linux persistence.

## 4. Existing owner — Northarun/Guilds 1.2.3 achievements
**Evidence:** `S/Guilds/src/Guilds/Progress.cs:32-50` defines **17** achievements, three tiers each: slayer/boss/archer, artisan/armorer/weaponsmith/cook, lumberjack/miner/farmer/collector/fisher, builder/wanderer/sailor/tamer/gourmet. `GuildServer.cs:2160-2175` evaluates cumulative guild stats, grants configured tier XP and logs/broadcasts unlocks. `GuildUI.cs:999-1000,3250-3260` renders the existing achievements tab. `Progress.cs:307-316` already owns territory upgrades, vault, membership and perks.

**Month sensitivity:** gold thresholds include 50,000 placements, 100 boss kills, 1,000 fish and 5,000,000 travelled distance. These are fixed code definitions, not exposed configurable thresholds in that initializer. [INFERENCE] Many gold tiers are aspirational for 3–5 people over 50–60 hours each; silver/bronze and weekly discipline recognition are the more credible month arc. Do not require gold completion or add another mod merely to duplicate them.

**Proposal:** preserve Guilds as rivalry/territory owner; inspect 1.2.3 changelog and existing config compatibility before updating its current pin. Do not turn personal boss keys into shared guild progression. The guild server's aggregation does not mean its raw client stats are tamper-proof.

**Confidence:** high for presence/thresholds, medium for pacing. Shakedown settles attainable tier rates and balance of guild sizes.

## 5. Try — Skitale/ValheimAdminForge 0.5.0
**What:** integrated searchable admin/moderation GUI, server-authorized actions, kick/ban, stuck-player rescue, audit trail and event controls.

**Evidence:** `S/ValheimAdminForge/src/ValheimAdminForge.Net/AdminRpc.cs:272-284,303-319` resolves server request context and refuses non-admin actions; `:400-428` rate-limits peers. Versioned README `:53-67,116-148,176-185` covers confirmation, audit file, adminlist identity and server-only caps. No settings sync is needed for caps enforced by the server; client window preferences cannot grant privilege.

**Proposal:** `General / AllowNonAdminWindow = false`; `Server / StrictItemCheck = true`, `AllowBossSpawn = false`, `AuditLog = true`, `PlayerTags = false`. Admins use rescue/moderation, not free materials for normal building. Avoid global-key editor (`src/ValheimAdminForge.Commands/WorldCommand.cs:114`) entirely. Disable/avoid vanilla event controls as scheduled content because Oathbound owns sieges; on-demand admin diagnostic use only.

**Overlap:** admin console tooling already includes Server_devcommands and optional Infinity Hammer/World Edit (modstack:468), contrary to a literal 'ships none' assumption. AdminForge adds discoverability/audit, not the first possible admin action. Name/chat tags overlap Guilds, hence off. Runtime validation must prove a non-admin direct RPC is denied and an actual admin can rescue/kick without collateral effects.

**Confidence:** high server-guard evidence; medium adoption fit, Shakedown needed.

## 6. Consider — JereKuusela/Cron_Job 1.14.0
**What:** server-side scheduling using YAML and existing console commands; avoids a second player UI.

**Evidence:** `S/Cron_Job/src/CronJob/CronManager.cs:16-24` uses `cron.yaml` and join jobs; `:91-101` invokes server console commands; `:229-244` gates join processing to server and expands player substitutions; `:293-340` loads jobs/timezone. README:3-5 says server-only installation. No client config lock needed for server-owned commands.

**Proposal:** consider a small scheduled announcement/join-message job set only. Weekly gathering/building exhibitions and boss-night reminders fit the month. Schedule presentation, not forced boss progression. Do not use vanilla raid scheduling, global-key writes, automatic free materials, logout punishments or difficulty changes. Exact announcement command must be verified against the chosen existing console/message owner before writing `cron.yaml`; no fabricated ready-to-run syntax here.

**Conflicts:** scheduler can execute any installed command, so it is operationally broad; overlap DiscordConnector if adding Discord jobs, and Oathbound if starting raids. No territory or guild scoring is native verified. **Confidence:** high scheduling evidence; medium value for this small server. Shakedown: timezone, duplicate-on-restart behavior and intended messages.

## 7. Consider — HaEs/HaesServerMessages 1.6.2
**What:** simple welcome and timed HUD broadcasts. More reusable than README suggests.

**Evidence:** `S/HaesServerMessages/src/HaesServerMessages/HaesServerMessagesPlugin.cs:135-140` reads `haes_messages.txt`, `haes_welcome.txt`, jokes files; `:224-252` creates/loads welcome text with delay/name replacement; `:255-260` creates HH:mm schedule in server local time; `:291-329` processes only on server and targets the joining peer. `:366-381` message handler displays payload without checking sender identity: nuisance-spoofing risk, not a gameplay authority bypass.

**Proposal:** consider only if Cron plus existing message commands cannot satisfy simple welcome. Replace HAES default content and remove default restart claims; use concise welcome pointing to the real guide/rules. Keep jokes empty. It cannot substitute for a readable persistent Calling/ladder rulebook. No gameplay configs, server owns authored messages; no preloader/key dependency found.

**Overlap:** MessageHud queue/timer and chat presentation; not Guilds memberships or party systems. **Confidence:** high static reuse evidence, medium recommendation because unauthenticated RPC and no rich rules panel. Shakedown: no lost/duplicated welcomes, long text readability, joins during first spawn/Oathbound class selection.

## 8. Consider alternative, not alongside CrewStats — JacobsValheim/VikingStoryteller 0.4.9
**What:** richer factual timeline/ledger and optional local HTML reporting, including assists, AFK estimates and exact-creature revenge.

**Evidence:** `S/VikingStoryteller/pkg/README.md:5-23` explicitly targets 1.0.16, read-only observer design, server collection/client reporting, period leaderboards and a Windows-only tested environment (Linux not equivalently smoked). `:41-49` carefully bounds loot-origin inference; `:55-61` describes retention/lifetime totals. These are documented guarantees, not independently runtime-proved here; DLL was decompiled and screened.

**Proposal:** consider instead of CrewStats if post-session storytelling/HTML is more valuable than its simple in-game profession table. Do not run both by default: duplicate observers, tabs and ledger retention multiply operator/UI cost. Client reporting preferences make missing coverage possible; do not pay competitive rewards for completeness-dependent totals.

**Overlap:** many crafting/building/loot/storage observer hooks; optional EpicLoot metadata is additive but not a progression owner. F8 overlaps DamageMeter. No direct Northarun or SocialSystem integration verified. **Confidence:** medium; richer functionality, greater surface area, explicit Linux verification gap. Shakedown and actual report usefulness settle it.

## 9. Reject as cooperative reward engine — Soloredis/RtDQuestForge 0.2.14
**Evidence:** README `:33-37` promises server definitions but explicitly credits the **killing blow**. `S/RtDQuestForge/src/RtDQuestForge/QuestManager.cs:51-82` stores `progress_<characterName>.json` locally; `:118-125` counts kills and added inventory items, `:153-155` completes locally. Server list application `:46-48` changes definitions, not authoritative progress storage. Jotunn network compatibility enforces matching installation (README:52-53); it does not protect client progress.

**Fit failure:** last-hit credit steers rivals within the same cooperative hunt, and client JSON reset/editing undermines repeatability/integrity of reward claims. Gather tracking is inventory-added activity, not verified resource production/delivery. Rewards introduce a parallel economy/skill-grant path; not evidence of Oathbound/Calling-aware rewards.

**Proposal:** reject for reward-bearing public/guild contracts; at most consider rewardless authored instructional quests, but Almanac already serves that UI/content need. No world-key dependency/preloader/stale-field finding observed. UI/input + character spawn + Character.OnDeath + Inventory.AddItem patches overlap existing UI/loot systems. **Confidence:** high rejection grounds; Shakedown cannot turn local progression into server authority.

## 10. Reject default — Landoria/SealedTombstone 1.0.10
**Evidence:** `S/SealedTombstone/pkg/README.md:20-30,42-46` specifies owner approvals, offline-owner denial, ten-day public expiry, clients+dedicated server required (listen server unsupported). `src/Landoria.SealedTombstone/TombstoneAccess.cs:61-70` writes lock day/attacker metadata to the owning ZDO; `:149-155,211-214` associates supplied character IDs with peer IDs. It is not a strong anti-tamper identity proof: connected peer presence is checked, but these entry points accept reported character IDs.

**Proposal:** reject default for eight trusted friends; it adds permission prompts/offline friction to rescue cooperation. Corpse run remains meaningful already; do not add safe pouch/keep gear/death cancellation. If theft is actually a problem, reconsider after a threat-model review, not as premium polish. No configurable progression settings found; fixed policy is consistent but unhelpfully broad. Patches tombstone interaction/setup and player damage/death; those overlap death systems. **Confidence:** high fit judgement. Shakedown cannot cure offline-owner policy; it can only prove interactions.

## 11. Reject — Dedryx/DiscoveryJournal 0.2.1 under the present Pack rule
**Evidence:** `S/DiscoveryJournal/src/DiscoveryJournal/Plugin.cs:59-65` exposes local `Shared Discovery / LearnFromNearbyStorage`, radius and access settings. `:120-130` allows the journal UI to toggle it locally. README:53 says client-only; :75 confirms optional storage learning changes character knowledge/progression. No server lock exists.

**Proposal:** reject even though its default is false: shipping the same default does not lock the gameplay-affecting option. A server-lockable or presentation-only release could be an attractive known-recipes browser. It does not supply an authored Calling/personal-key rules manual today. Inventory tabs/input and recipe knowledge overlap Almanac/EpicLoot recipe knowledge gating. Static screen passed; no global-key requirement/preloader found. **Confidence:** high Pack-rule failure; no Shakedown required for the lock gap.

## 12. Reject default — VerdantsAscent/FiresDiscordIntegration 1.0.31
**Evidence:** `S/FiresDiscordIntegration/pkg/README.md:5,15-25,40-60` describes two-way chat, inline GIFs, remote restart/stop/moderation, snapshots and screenshots. `:91-101` puts the bot token outside shareable config; good practice. `:22-23` uses a separate watchdog and Windows `.bat` restart wrapper, not this pack's container orchestration. It is broader than DiscordConnector webhook relay, so **additive features exist**, but it is not a clean drop-in for this server.

**Proposal:** reject for now; retain DiscordConnector and use existing server host controls. Two-way chat/screenshot integration would reopen the deliberate modstack:443 external-bot/two-way-chat decision; no evidence that its reason expired. If that user requirement changes, evaluate an explicit replacement rather than double-posting chat/events from both. Image overlay/chat patches overlap Guilds/Marketplace/SocialSystem chat, and remote administration enlarges credential/security scope. DLL screened clean; runtime Linux watchdog/control behavior unverified. **Confidence:** high fit rejection, medium platform assessment (Windows wrapper documented, not asserting every feature Windows-only).

## Notable rejects and remaining categories
- **Smoothbrain/ServerCharacters 1.4.16; HaesHeimSERV/ServerCharacters 1.4.14:** both `is_deprecated: true` in full raw Thunderstore API. Versioned Smoothbrain README fetched to `/tmp/lembitu-premium/ScoutMeta/ServerCharacters-readme.json` documents server saves/inventory, signed emergency backups, single-character mode and backup-only mode. This matches the integrity need much better than stats logging, but **not recommended for a fresh 1.0 run without a maintained release and custom-data round-trip proof**. Not among twelve decompiles; stale-field/current runtime support therefore [UNVERIFIED]. Never imply deprecated automatically means proven broken.
- **Wubarrk/TerroritySmellatory 0.3.1:** current README fetched to `Territory-readme.json`; admin-marked territory protection, runic barriers, forced PvP rules, no-skill-loss, sanctuary buffs, map boundaries; server checks/admin storage described. It is **territory policy, not verified territory competition scoring**. Reject as duplicate Guilds claim owner and broad death/raid/protection overlap; toggles could make a neutral fairground but no identified need justifies second territory system. Not decompiled; authority claim README-level only.
- **BountiesReworked / ExtraBiomeBounties / Unofficial_EpicLoot_BountyAdditions:** description/index identifies EpicLoot add-ons, not a missing core contract system. Existing EpicLoot Adventure is already an owner; consider only in an EpicLoot-specific balance review, not another generic bounty layer. Detailed current reward/lock behavior [UNVERIFIED].
- **ValheimAnticheat 0.0.1 / CatosAntiCheat 1.0.4 / PlayerModList 1.0.0:** discovered current anti-cheat/mod-list candidates; not decompiled here. Mod-list enforcement is not proof of character-state authority. Avoid claiming a fake client/modlist can never lie or that whitelisting protects Oathbound XP.
- **Old TombstoneHelper / Simple Smarter Corpse Run:** old pre-1.0 index dates, and access/weight convenience only; no need to risk old hooks when admin rescue covers glitched inaccessible graves. **Valkyrie Death Messages** likewise predates 1.0 and only shout announcements, while DamageMeter supplies current recap.
- RustyMods catalogue: Almanac is the relevant current meta candidate. Its other current entries are combat/content/building/seasons/portals rather than a separate verified guild scoring system. AlmanacClassSystem is another class/progression owner and therefore rejected beside Oathbound. Northarun's current index entries are Guilds and Marketplace; no third native integration package was found in that owner scan.

## Gaps
- No game/runtime validation authorized. Static twelve-DLL compatibility pass is not evidence of working 1.0 UI, Linux persistence, Jotunn interplay or all dependency compatibility. Shakedown must settle those surfaces.
- No verified maintained server-character storage candidate. Need a current source/binary, custom-data persistence for both Lembitu plugins/Oathbound/WAP, reconnect/crash rollback proof, cross-world character restrictions, and inventory transaction testing before adoption. The correct gap is state authority, not merely a backup directory.
- No verified automatically guild-aggregated weekly territory league, shared-party reward contracts, healer/support score, or editable standalone rules-book mod found that cleanly respects existing owners. Almanac dialogue onboarding plus Guilds progression and manually judged weekly exhibitions is the cohesive proposal, not a fabricated native integration.
- Stats/reporting mods trust client gameplay reports. Rewardless prestige is proportionate for a trusted eight-player server; stronger financial prizes need stronger authority than these observations.
- At 12–15 hours/player/week, favor four weekly categories and a final chronicle, not a perpetual daily quest grind. If actual play doubles, thresholds/rewards require remeasurement; none of these meta mods should themselves determine boss pacing.
