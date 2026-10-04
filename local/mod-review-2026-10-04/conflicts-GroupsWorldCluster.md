# Groups, protection, world rules and economy — research handback

Research date: 2026-10-04. Exact package versions are those in the brief. No repository files changed; no publication, deployment or game execution. Evidence is static README reading and exact-package decompilation. Recommendations below are proposed owner decisions, not implemented decisions. No crash is demonstrated merely by sharing a Harmony target.

## Evidence notation / primary sources

`R` = `/tmp/lembitu-readmes/`; `D` = `/tmp/lembitu-research/GroupsWorldCluster/`. All code references below are decompiled exact-version package binaries. Package primary-source download URLs: `https://thunderstore.io/package/download/<team>/<mod>/<version>/`, specifically Northarun/Guilds/1.2.2, Northarun/Marketplace/1.4.0, sighsorry/STU_Ward/1.3.17, sighsorry/CreatureManager/1.2.5, VentureValheim/Venture_Multiplayer_Tweaks/1.0.0, ZenDragon/ZenRaids/1.2.3, ZenDragon/ZenBossStone/1.0.3, SeasonedProfessionals/OdinEye/1.2.37. Cached SeparateSpawns 0.1.1 and WAP 1.0.0 were also decompiled. README claims are explicitly distinguished from binary observations.

## 1. Group authority and ward integration

### HARD integration incompatibility: STU_Ward's Guilds provider is NOT Northarun/Guilds

**Observed:** `D/STU-code/STUWard/GuildsCompat.cs:64-94` looks up plugin GUID **`org.bepinex.plugins.guilds`**, takes that plugin instance's assembly, then reflects `Guilds.API`, `Guilds.Guild`, `Guilds.GuildGeneral`, `Guilds.PlayerReference`, and `API.GetGuild(int)`. It does not merely find any assembly named Guilds. Northarun's binary declares **`adrian.valheim.guilds`** at `D/Guilds-code/Guilds/Plugin.cs:14`. Original Smoothbrain source declares `org.bepinex.plugins.guilds`: https://raw.githubusercontent.com/blaxxun-boop/Guilds/master/Guilds/Guilds.cs (read 2026-10-04, source currently says 1.1.14; fetched Thunderstore README says deprecated 1.1.13, `R/Smoothbrain__Guilds.md:1-8`). Therefore the generic optional “Guilds” wording in `R/sighsorry__STU_Ward.md:70` refers to the old Smoothbrain API, not the new Northarun package.

**Decision / recommendation:** do not promise automatic STU guild trust or same-guild overlap after Clan removal. Choose Northarun guild-bound vanilla wards/banner claims as group protection; retain STU only for explicitly registered-player protection if needed. Do not install deprecated Smoothbrain Guilds to satisfy STU: it adds a second membership authority. A Northarun STU adapter would be new implementation, outside this research.

### OVERLAP / INTERACTION: vanilla guild wards, STU clones, banner territory

Guilds binds by `Guilds_WardGuild` ZDO key and patches **all `PrivateArea` instances**, not a vanilla-prefab-filtered subset: `D/Guilds-code/Guilds/WardPatches.cs:10,34-79,82-118,121-159`. Its `IsPermitted` postfix grants membership/rank WardAccess when the builder remains in that guild. Binding requires builder identity and BindWard permission. Thus the README's “ward you built” does not prove STU clones are excluded. STU independently authorizes owner, registered players and its own provider-qualified group (`R/sighsorry__STU_Ward.md:59-70,89-98`); one trusted tier lets everyone change settings/dismantle. **[INFERENCE]** Northarun binding a STU clone may make vanilla access succeed while STU's independent guards still deny it; composed clone behavior has not been exercised.

STU defaults **`[1 - General] Disable Vanilla Guard Stone Recipe = On`**, blocking construction of the obvious Northarun-compatible ward. See `D/STU-code/STUWard/WardPluginConfigBindings.cs:47-55`. It also defaults `Hostile Creature Structure Protection Mode = UnattendedOnly`, potentially bypassing intended raid structure damage; `Off`/`Always` are distinct policies.

**Decision / recommendation:** use vanilla wards for guild binding and set STU `Disable Vanilla Guard Stone Recipe = Off` if retaining STU. Prefer no dual protection in the same base until actual STU-clone/Guilds binding composition is verified. Use `Hostile Creature Structure Protection Mode = Off` for difficulty-oriented bases unless offline protection is expressly wanted. Banner territory is a second square access boundary (`D/Guilds-code/Guilds/TerritoryPatches.cs:9-37`), not a replacement for STU's broad pickup/item-use/terrain policies.

### Clan removal impact

`docs/rules.md:43-56` and `CONTEXT.md:34-50` still describe Clan as sole authority, guest clan behavior and clan-friendly-fire immunity; `docs/modstack.md:23-26,84-85` now records replacement by Northarun. These sources conflict by scope/date: the stack changed 2026-10-04, old rules still describe the retired design. Northarun config has no friendly-fire toggle among its complete bindings (`D/Guilds-code/Guilds/Plugin.cs:175-223`); retaining Clan immunity is **not verified**. STU's primary Clan automatic trust disappears, although owner/individual registrations remain (README :70,85). No Clan-to-Northarun roster/ID migration is documented in read evidence.

**Decision / recommendation:** adopt one authority, Northarun. Explicitly decide PvP policy rather than assuming guildmate immunity transfers; force PvP off with Venture if collaboration is intended. Recreate membership and audit every existing STU ward's individual access. Archive old registry; do not interpret old Clan IDs as Northarun IDs. Source configs/docs need dispatcher-owned cutover, not edits in this research.

## 2. Raid and spawn protection

### OVERLAP: Guilds Monster ward vs ZenRaids light perimeter

Guilds upgrade `monsterward` defaults to `Bronze:30,TrophyGreydwarfShaman:5,TrophySkeleton:5,C1000,L3`; `[6 - Upgrades] monsterward` is the exact key (`D/Guilds-code/Guilds/Progress.cs:305-325`). Its binary rejects a successful `SpawnSystem.IsSpawnPointGood` if `Territory.At(spawnPoint,10f)` has that upgrade (`TerritoryPatches.cs:65-80`). README says “no monster spawns or raids — claim only” (`R/Northarun__Guilds.md:81-94`). **Boundary:** this is spawn-point rejection, not a `RandEventSystem.StartRandomEvent` cancellation. Raids can still be selected and monsters outside the claim can walk in; full raid immunity is not proved.

ZenRaids replaces ordinary workbench-style spawn suppression with lit-fire protection: `[Spawn Protection] Fire Must Be Lit`, `Light Range Percent`, `Fuel Override`, `Protect From Despawn` (`D/Raids-code/ZenRaids.SpawnProtect/Configs.cs:65-77`). README :17-26 describes fueling as the mechanic. Guild permanent claim spawn suppression makes this fuel loop redundant inside upgraded claims.

**Decision / recommendation:** choose whether progression buys permanent base safety or lighting remains meaningful. For enhanced difficulty, retain light maintenance and avoid buying Monster ward; there is no verified separate boolean upgrade-disable key. Do not recommend an unverified empty-cost syntax as disabling it. If keeping Monster ward, present Zen light protection as useful only outside claims, not two independent layers of difficulty.

### INTERACTION: ZenRaids vs WAP private raids

WAP replaces `RandEventSystem.RefreshPlayerEventData`, populating peer private-key data, and overrides `HaveGlobalKeys` to true (`D/WAP-code/VentureValheim.Progression/KeyManager.cs:659-696`). Repo pins private keys, blocks global keys and enables private raids (`config/enforced/com.orianaventure.mod.WorldAdvancementProgression.cfg:36-38,67-68`). Zen edits event key lists, biomes and known-item requirements (`D/Raids-code/ZenRaids.Raid/Rules.cs:61-100,149-157`), and patches `UpdateRandomEvent`, `StartRandomEvent`, `InValidBiome`, `CheckBase` (:214-300). No directly competing replacement of WAP's two raid targets was observed.

**Decision / recommendation:** let WAP own personal eligibility; Zen owns chance/biome/base/perimeter policy. Keep WAP `UsePrivateRaids=true`, `UsePrivateKeys=true`, `BlockAllGlobalKeys=true`; Zen `Ignore Condition - Known Items=true` avoids accidental trophy pickup advancement; `Append Global Keys To Player Keys=true` translates vanilla global prerequisites into private prerequisites, not sharing world progress. Decide `No Raid Biomes` consciously: Zen defaults Meadows excluded, which is a major difficulty reduction. Keep key override lists empty unless intentionally replacing event prerequisites. Actual combined event eligibility is untested.

## 3. ZenBossStone, personal keys and guild sharing

### INTERACTION / OVERLAP: independent unlock records and loot flow

Zen uses **`BossStone_*` unique character keys**, not WAP `defeated_*` keys (`D/Boss-code/ZenBossStone/Extensions.cs:21-38,89-107,150-157`). Trophy sacrifice marks nearby players' stone reality and optionally produces boss loot (:54-64). README :8-12 confirms no loot on boss death except trophy, heavy/no-teleport trophy transport, and group credit for people standing at stones. WAP boss-kill participation and Guilds SharedProgression concern separate boss keys. Guilds shares WAP keys via WAP RPC; shared keys persist after leaving (`R/Northarun__Guilds.md:165-167,190-191`). This will not automatically make their Zen stone appear hung.

**Decision / recommendation:** keep Guilds `SharedProgression=false` for genuinely personal progression; otherwise choose intentional guild-level advancement and accept offline/uninvolved members receiving keys after `SharedProgressionMinHours` (default 24). Zen stones should be described as power/transport ceremony, not the authoritative proof of boss-key eligibility. Decide whether the 1200-weight trophy hauling mechanic fits this world. Keys: Zen `[General] Per Player Boss Stones`, `Sacrifice Trophy For Boss Loot`, `Sacrifice Trophy Range`, `Sacrifice Trophy Ignored Bosses`, `Sacrifice Trophy For Boss Loot - Explicit`, `Autoset World Modifier PlayerEvents`; `[Trophy] Boss Trophy Weight`, `Boss Trophy Max Stack Size`, `Boss Trophy No Teleport`, `Remove Trophy From Raid Requirements` (`R/ZenDragon__ZenBossStone.md:45-138`). README sample is old v0.6.2, so default claims from that sample are version-qualified, not a freshly generated 1.0.3 config.

**Additional loot interaction:** Zen's sacrifice fallback uses prefab boss drops, ignores non-guaranteed drops, applies one-per-player counts and prefab level multipliers (`D/Boss-code/ZenBossStone/Extensions.cs:195-245,340-342`). It is not a replay of the killed CreatureManager boss's live level/modifiers. **[INFERENCE]** CM/EpicLoot death-time bonus drops may not transfer faithfully. Recommendation: do not enable sacrifice-for-loot while assuming every CM/EpicLoot reward survives; use explicit fixed loot if choosing the ceremony, with owner approval of replaced reward semantics. No runtime reward composition proof.

## 4. Venture Multiplayer / Logout and SeparateSpawns

### Every Multiplayer 1.0.0 config toggle (binary, not renamed README aliases)

`D/Venture-code/VentureValheim.MultiplayerTweaks/MultiplayerTweaksPlugin.cs:243-264`:

- `[General] AdminBypass` (false), `GameDayOffset` (0), `OverridePlayerPVP` (false), `ForcePlayerPVPOn` (true), `TeleportOnAnyDeath` (true), `TeleportOnPVPDeath` (true), `SkillLossOnAnyDeath` (true), `SkillLossOnPVPDeath` (true), `HidePlatformTag` (false).
- `[Arrival] PlayerDefaultSpawnPoint` (empty), **`EnableValkrie`** (true; actual spelling), `EnableArrivalMessage` (true), `UseArrivalShout` (true), `OverrideArrivalMessage` (empty).
- `[Map] EnableTempleMapPin`, `EnableHaldorMapPin`, `EnableHildirMapPin`, `EnableBogWitchMapPin` (all true), **`OverridePlayerMapPositions`** (false), **`ForcePlayerMapPositionOn`** (true), `AllowMapPings`, `AllowShoutPings` (true).
- No player-count-scaling key or toggle exists here. Hugin tutorial seen tracking, near-boss message localization (100 m), and death grace are behaviors, not additional exposed config toggles (README :29-43,63). All listed configs are marked synced.

### INTERACTION: Venture death skill loss vs WAP

Venture prefixes `Skills.LowerAllSkills`/`Skills.Clear`, returning false when configured to suppress loss (`D/Venture-code/.../GeneralTweaks.cs:119-142`); WAP also owns `Skills.LowerAllSkills` and repo pins a private-key skill floor with drain enabled. Recommendation: keep both Venture loss toggles true so WAP floor/drain remains the authority; do not accidentally erase a difficulty penalty. Guild position RPCs can reveal guildmates even with public map positions off (`R/Northarun__Guilds.md:108,182`), so “forced map privacy” is public privacy, not guild privacy. Recommendation: hide public position, keep guild positions, and coordinate with MapCluster for map replacements.

### No demonstrated conflict: Logout Tweaks is a different responsibility

README `R/VentureValheim__Venture_Logout_Tweaks.md:29-47`: client-only, no config, stores Rested/Wet/Poison/Burning/Spirit/Frost/Lightning/vanilla potions/death effects/slimed/tarred/immobilized/boss powers in player file; poison/burning retain remaining damage/time, preventing logout death avoidance. Custom mod status effects no longer automatically restored. Recommendation: retain alongside Multiplayer; do not claim guild regeneration or arbitrary mod effects persist. Its absence is not server-enforced by that installation model.

### INTERACTION: SeparateSpawns groups are not guilds

README installs on server/every client (`D/Separate/README.md:65-67`). Binary has independent platform-ID roster `SeparateSpawns.groups.json`; no Northarun guild integration was found. Dedicated roots are **game-root/config/bepinex**, with BepInEx config fallback (`D/Separate-code/SeparateSpawns/ModPaths.cs:12-28,51-89`), explaining repo `config/dedicated/` ownership. Repo now records random assignment into three empty groups (`docs/modstack.md:57`), whereas old `docs/rules.md:127-131` still says five clan starts. This is a documented conflicting state, not evidence that random assignment follows a guild.

Both Venture and Separate patch `Game.FindSpawnPoint` / `Game.SpawnPlayer`; Venture nonempty default spawn sets a logout point (`D/Venture-code/.../ArrivalTweaks.cs:79-89`), while Separate replaces/synchronizes group spawn. **Decision / recommendation:** retain Separate for geographic starts, but curate its roster to match the intended 2–3 player groups if group-specific starts are wanted. Leave Venture `PlayerDefaultSpawnPoint` empty and temple pin enabled; do not add a second default-spawn authority. Guild banner respawn is a later progression feature, not initial-world placement. Generation/spawn config keys: `InnerRadius`, `MinSpawnDistance`, `MinStonesDistance`, `BlackForestProximity`, `MinBurialChambers`, `EikthyrReach`, `IslandsWeight`, `DistanceWeight`, `MeadowsSizeWeight`, portal `CoreCost`/`StonesRadius`, seed `MaxRerolls`; full bindings at `D/Separate-code/SeparateSpawns/ModConfig.cs:65-91`. Keep reports off for production (`EnableLayoutReports`).

## 5. CreatureManager 1.2.5 and player-count scaling sources

### Upgrade delta

Exact 1.2.5 changelog `D/sighsorry_CreatureManager_1.2.5/CHANGELOG.md:3-7`: adds public main-thread/final-position `CreatureManagerSpawnApi.CanSpawn(GameObject,Vector3)` for ordinary spawners; DropNSpawn 1.3.18 consumes it. Reuses blocker policy/live settings; does not change native exclusions, distance/dungeon boundaries or assign Enforcer/karma/loot. 1.2.4 (:9-13) optimized blocker discovery. No config/YAML migration claimed. Binary still binds the enforced levels/preset/modifier/karma/multiplayer keys (`D/CM-code/CreatureManager/CreatureManagerPlugin.cs:336-354`), and `levels.yml` remains the named rules file. Existing overlay therefore still applies; update server and clients together, since ServerSync minimum required version is 1.2.5 (:687-692). BepInEx dependency is now 5.4.2351 (latest README deps), which conflicts with the brief's game 1.0.7-era baseline expectation: do not infer latest-package runtime compatibility from a retained YAML format.

### Explicit player-count scaling sources table

| Source | What scales | Exact control to pin | Evidence / status |
|---|---|---|---|
| Vanilla `Game` | Enemy effective HP (damage received divided), enemy damage, nearby players | No config of its own; CM sets `m_healthScalePerPlayer=0`, `m_damageScalePerPlayer=0`, `m_difficultyScaleMaxPlayers=1` | `D/Game.cs:138-144,1117-1139`, decompiled repo `lib/valheim/assembly_valheim.dll`. Defaults 100 m, cap 5, 30% HP / 4% damage per extra player. There is no single `Game.m_difficultyScale` field in this evidence. |
| CreatureManager 1.2.5 | Controls the same vanilla combat fields, not a second additive headcount multiplier | `[4 - Multiplayer Difficulty] HP Increase Per Player In Multiplayer (%)=0`; `DMG Increase Per Player In Multiplayer (%)=0`; `Maximum Player Count For Multiplayer Scaling=1` | `D/CM-code/CreatureManager/CreatureGameSettings.cs:17-19`, Plugin :352-354. Already pinned in `config/enforced/sighsorry.CreatureManager.cfg:99-102`. |
| ZenRaids 1.2.3 | Raid trigger probability by logged-on player count | `[Raids General] Raid Chance Bonus By Player=0`; `Min Player Count=1`; optionally pin `Raid Chance` independently (-1 vanilla or fixed nonzero) | `D/Raids-code/ZenRaids.Raid/Configs.cs:57-59`; Rules :238-258 uses `base+(Player.GetAllPlayers().Count-1)*bonus`, and online-player gate. Not creature HP/damage, but is headcount-dependent difficulty if changed. |
| Venture Multiplayer Tweaks 1.0.0 | None observed | No scaling key; do not invent one | Complete binary bindings :243-264 above. |
| ZenBossStone | Boss sacrifice **loot** for one-per-player drops | `Sacrifice Trophy For Boss Loot=false` avoids this added ceremony calculation; or explicit boss loot definitions fix amounts | `D/Boss-code/ZenBossStone/Extensions.cs:54-64,228-242`. Not combat scaling; normal vanilla boss one-per-player reward semantics are distinct. |
| WAP private raids | Eligibility derived from each player's keys and location, not combat stat headcount | Keep `UsePrivateRaids=true`; no HP/damage headcount control observed | KeyManager :659-696. More eligible players naturally means more potential locations; no numerical per-player bonus verified. |
| Guilds | Contributions pool guild XP; members increase activity throughput | `ActivityXpMultiplier`, `DonationCoinsPerXp`, guild upgrade cost curves; no combat headcount multiplier identified | Plugin :200-223; this is pooled progression, not creature scaling. |
| MaxPlayerCount fork | Capacity, not a verified combat scaling source | Capacity may stay 20; **do not treat it as disabling vanilla scaling** | Current brief/repo stack; implementation not decompiled in this slice. [INFERENCE] capacity alone does not override Game combat fields. |
| Remaining entire stack | Not exhaustively screened in this slice | No global “guaranteed none” claim until other clusters' binary evidence is integrated | Coverage gap: not every content/progression DLL was scanned for `GetPlayerDifficulty`, `GetPlayersInRange`, health/damage field writes or custom count formulas. |

**Recommended owner answer:** keep CM's 0/0/1 triple and pin Zen's bonus 0/minimum 1. This proves the identified combat/count-chance controls, not an exhaustive whole-stack guarantee. Distinguish fixed biome/star/karma progression difficulty from forbidden headcount scaling. CM's fixed `Hard`, boss biome fallback, `healthPerLevel`, `damagePerLevel`, modifier rolls and regional karma are intentionally not disabled by this triple.

## 6. Coins, banking and deferred trading

### INTERACTION: Guilds and Marketplace intentionally integrate

`R/Northarun__Guilds.md:154-181,190-192`: creation fee bank-first/inventory-second; guild treasury can transfer to/from Marketplace bank; materials from vault, coins treasury; donation sinks coins for XP. `D/Guilds-code/Guilds/Plugin.cs:186,211` confirms CreateCost default 1000 (sink) and DonationCoinsPerXp default 10 (0 disables donation). Upgrades costs are real progression sinks, not a new currency. `[6 - Upgrades]` exact keys: `territory`, `vault`, `members`, `regen`, `comfort`, `monsterward`, `resilience`, `production`, `growth`, `respawn` (definitions `Progress.cs:305-325`; owner should use generated costs, not assume coin prices alone define power).

Marketplace ordinary Valheim coins (`R/Northarun__Marketplace.md:8-11`), bank/mail/escrow persistent server data (:112 onward), not passive minted income. `[2 - Server] FeePercent` (sink, default 0), `MaxListingsPerPlayer`, `ExpireHours`, `MaxPricePerUnit`, `BlockedItems`; `[3 - Order Board] MaxBuyOrdersPerPlayer`, `MaxBountiesPerPlayer`, `BountyClaimTimeoutHours` (:95-110). Vault and marketplace preserve custom item data per READMEs (Guilds :192, Marketplace :30); no independent stress/duplication proof.

### OVERLAP: Marketplace vs Trade Post; INTERACTION with EpicLoot

Deferred Trade Post is explicitly not built: `CONTEXT.md:54-62`, `docs/modstack.md:239-242`, `docs/rules.md:263-266`. Marketplace already provides offline coin sale, buy-order escrow, mailbox and bounties, duplicating most planned ledger responsibilities; it is server-wide player trading, not a clan's physical single trade interface. **Decision / recommendation:** adopt Marketplace as current ledger; defer/cancel separate Trade Post implementation rather than running two banking/escrow authorities. Decide if worldwide remote access undermines meaningful encounters; this is a design tradeoff, not a binary conflict.

EpicLoot Adventure Mode remains enabled with Unlimited gate and five bounty limit (`config/enforced/randyknapp.mods.epicloot.cfg:17-20,36-40`). That confirms an existing NPC treasure/bounty/gambling economy but not precise coin issuance. **Coverage gap:** latest EpicLoot reward/currency tables were not decompiled in this slice; don't equate every bounty reward currency with vanilla Coins without that inspection. Recommendation: retain NPC adventures and player marketplace as different jobs, but size guild coin sinks after actual reward tables are integrated by dispatcher; initially disable coin-to-guild-XP donation (`DonationCoinsPerXp=0`) if avoiding purchasable progression is the goal.

## 7. OdinEye and DiscordConnector

### INTERACTION/security surface: REST API is not only passive data

README server-only/optional client stats (`R/SeasonedProfessionals__OdinEye.md:8-20`), primary source https://github.com/js-ferguson/odin-eye. Binary default **`[Hosting] HttpServerAddress=http://localhost:2469/`** (`D/Eye-code/OdinEye/OdinEyePlugin.cs:68-69`). HTTP starts an address-bound HttpServer, directly dispatches GET and POST controllers, registers `/activity` WebSocket; **no application authentication check in this dispatch path** (`D/Eye-code/OdinEye.Http/HttpWebServer.cs:23-95,108-112`). `POST /players/<steamID>/notify` invokes routed in-game ShowMessage (`.../OdinEye.Http.Api.Controllers/PlayerNotifyController.cs:15-17,37-65`). Therefore exposing it public-facing permits more than observing server health.

**Decision / recommendation:** keep loopback binding, no public port mapping. Remote tools through authenticated TLS reverse proxy or private tunnel; treat event feed/player locations/IDs as sensitive group-play intelligence. No built-in auth key was found among plugin config bindings. This is a deployment recommendation, not proof of all library-default authentication behavior.

### OVERLAP: OdinEye dashboards/bots vs DiscordConnector notifications

Connector already emits server and join/leave/death/shout notifications (`config/enforced/games.nwest.valheim.discordconnector/discordconnector-toggles.cfg:17-25`), and position exposure is deliberately off (:14-15). OdinEye provides raw REST/WebSocket events for custom consumers, not an automatic Discord webhook replacement (README :10-16). **Decision / recommendation:** keep Connector for existing notifications; only add OdinEye if a dashboard/API consumer is actually wanted. Avoid a second bot echoing the same events; preserve position privacy. No mutually exclusive patch or crash demonstrated.

## Per-mod installation, handshake, permanence and key inventory

| Mod | Runs / handshake | Persistent or one-way state | Relevant controls / evidence |
|---|---|---|---|
| Northarun Guilds 1.2.2 | Both; README says Jotunn rejects missing clients; binary has NetworkCompatibility attribute but unresolved attribute arguments in initial decompile | Custom banner prefab world content; ward ZDO binding; external guild roster/vault/coins/XP; WAP-shared character keys persist on leave | All keys detailed §§1,3,6; `[7 - Map] ShareMemberPositions,MaxGuildPins`; README :142 onward and :190-192. Back up guild server records before removal; vault items not world chests. |
| Marketplace 1.4.0 | Both; Jotunn rejects missing clients (README :85-110) | Listings, escrow, balances, mailbox server records; removal strands records/assets, not safe disposable UI | FeePercent,BlockedItems and limits as §6. |
| Clan 1.1.3 (removed) | Former both/enforcement **[INFERENCE]**; this slice did not decompile its handshake | External memberships; old STU provider metadata; no migration verified | Existing friendly-fire/guest behavior in rules :43-56 is no longer supplied simply by adding Northarun. |
| STU_Ward 1.3.17 | Both for cloned content/features; embedded ServerSync **ModRequired defaults false**, plugin does not set true (`D/STU-code/STUWard/Plugin.cs:59-64`; `ServerSync/ConfigSync.cs:432`; `VersionCheck.cs:127-169`). Installed-client minimum version is 1.3.17, not a proof missing clients are rejected | Clone prefab + world ownership/registrations; policy/recent-player YAML external (`R/sighsorry__STU_Ward.md:76-85`) | Lock Configuration, Max Ward Radius, Max Wards Per Steam ID, Pickup Block Mode, Hostile Creature Structure Protection Mode, Ward Range Configuration, Disable Vanilla Guard Stone Recipe, STUWard Recipe; `[2 - Ward Restrictions] <action> Restriction` ForcedOn/NotForced (bindings :47-71). |
| WAP 1.0.0 | Both; config synced; exact handshake mode **not verified** in resolved Jotunn attribute | Private character keys permanent until reset; server key cache; removal changes gates even if records survive | Private keys/global block/private raids/skill floor/drain §2 and §5; repo overlay :36-85. |
| ZenRaids 1.2.3 | Both **[INFERENCE]** for client light/raid data plus server rules; Zen_ModLib handshake implementation **not inspected** | No custom world prefab observed; altered lighting fuel capacities/raid config can revert; permanence **[INFERENCE]** | Raid chance/bonus/minimum/biomes/keys/known items; fire lit/range/fuel/despawn keys as §2/5. |
| ZenBossStone 1.0.3 | Client behavior, server optional but server installation enforces clients and admin configs per README :18-22; actual Zen_ModLib mechanism **not verified** | `BossStone_*` unique character keys; heavy trophy data/PlayerEvents world modifier; state remains if removed but meaning changes | Ceremony/loot/trophy controls §3; explicit loot can remove new headcount reward multiplication. |
| Venture Multiplayer 1.0.0 | Both; Jotunn config sync README :117; missing-client enforcement attribute arguments **not verified** | Spawn/death logout points and tutorial knowledge are character state; most policies reversible **[INFERENCE]** | Complete 22-key inventory §4; no player scaling toggle. |
| Venture Logout 1.0.0 | Client-only, no required server mod/handshake per README :47 | Status-effect data stored in character save; not new items/world content | No config. Vanilla listed effects only; custom restoration unsupported. |
| SeparateSpawns 0.1.1 | Both per README :65; hand-rolled roster/layout sync; no rejection/version handshake found in inspected PeerInfo patch; **do not claim required-at-handshake** | Generated layout, portals/altars and platform roster/cache; reroll/placement one-way for existing world **[INFERENCE]** | Dedicated root and generation/portal/group controls §4. |
| CreatureManager 1.2.5 | Both, ServerSync **ModRequired=true**, min 1.2.5 (Plugin :687-692) | Saved creature levels/modifiers; optional cloned content if enabled; removing changes existing stat interpretation | Enforced keys retained; headcount triple; fixed level/modifier/karma YAML independent. |
| OdinEye 1.2.37 | Dedicated server-only, optional separate OdinEyeClient; no mandatory client per README :16 | Server statistics/history **[INFERENCE]**; no world content identified | HttpServerAddress; no built-in auth config found. |
| DiscordConnector 3.1.3 | Server notification tool **[INFERENCE]**; handshake not decompiled here | Config/webhook external; no world content identified **[INFERENCE]** | Message toggles and Send Positions with Messages; keep positions off. |

## Coverage gaps and limits

- No game smoke run: research-only and no server/private multiplayer runtime authorized in this slice. Harmony composition, raid selection vs inward-walking mobs, STU clone binding, vault duplication durability, boss loot composition remain unexercised.
- Whole-stack headcount guarantee requires integrating other clusters and scanning remaining mod formulas; table is explicit about inspected sources and does not claim exhaustive absence.
- Jotunn/Zen library attribute values/enforcement were unresolved in initial decompilation; READMEs supply source claims where specified. STU's false ModRequired and CM's true are binary-observed.
- Exact EpicLoot coin reward tables and legacy Clan registry migration were not examined; absence of a documented migration is not proof a migration is impossible.
- The brief's game baseline is 1.0.7 while CM current changelog includes later 1.0.15/1.0.16-era contracts and 5.4.2351 dependency. Latest update does not establish compatibility with an older game binary. Dispatcher must settle exact live game target before choosing latest packages.
