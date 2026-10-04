# Party and skill-floor fit — 2026-10-04

## Scope and evidence

Authority: `docs/adr/0019-the-server-concept-mmorpg-lite-for-rival-guilds-that-cooperate.md:25-55,70-79`: eight-player, invite-only, cross-guild temporary parties; XP and positions only; boss-key death floor; one owner per progression axis. Research only; repository source/configuration unchanged.

All eight exact packages were downloaded from `https://thunderstore.io/package/download/<Team>/<Mod>/<Version>/`, extracted and decompiled using ilspycmd 11.0.0.9375 with `lib/valheim` and `lib/bepinex` references. Evidence root **P = `/tmp/lembitu-fit/PartiesAndFloors/`**; citations `P/F.cs:line` refer to full decompiled assemblies. Prior evidence root **R = `/tmp/lembitu-research/ProgressionCluster/`**. Publisher README citations use the extracted version, not a mutable latest page.

Executed scoped proof: `scripts/screen-bundled-libs.sh --dir P/<Mod>` for all eight. Groups exited **1**; every other target exited **0**. Logs at `P/<Mod>.screen`. This is a static member-reference screen, NOT a Unity startup or eight-client playtest. Script's actual check detects field reads of members now declared const (`scripts/screen-bundled-libs.sh:73-95,103-145`); it does not comprehensively prove method signatures, Harmony target existence, network authority or runtime UI compatibility. Clean screen means eligible for Shakedown, not verified loading. No game runtime was launched here.

Metadata primary sources (queried today): `https://thunderstore.io/api/experimental/package/<Team>/<Mod>/`. Exact target versions are latest for all eight. Groups is deprecated; others are not. BetterUI created September 14 and updated September 29; Zenox September 13–29; SocialSystem September 15–October 3; Socialize August 1–September 12; SkillFloors July 26 2025–September 10 2026; FortifySkillsRedux October 9 2023–September 21 2026; SkillLoss September 22–28 2026. Fast releases are not proof of AI authorship. **Authorship and unfinished-churn claims are unverified**; no download-count quality proxy is used.

## Zenox/BetterUI 1.0.14 — REJECT as the party owner

Primary package: https://thunderstore.io/package/download/Zenox/BetterUI/1.0.14/

- **Invitation:** explicit Yes/No popup, so intentional acceptance exists (`P/BetterUI.cs:2023-2040`). Invitation receiver trusts transmitted party ID; no server-issued invitation token/expiry/leader check is present there. Sender uses only loaded nearby Player objects, not a server-wide roster (`1896-1936`).
- **Size:** party configuration has enabled/HP/stamina/offset only (`1880-1894`); accept simply overwrites own ZDO party ID (`2032-2035`). No enforced/configurable eight-player maximum in this implementation.
- **Cross-guild:** its membership is a standalone `ZenoxPartyID` ZDO string (`1954-1966`), unrelated to Guilds. Cross-guild is supported structurally; no membership restriction found.
- **Positions / XP:** party implementation enumerates loaded `Player.GetAllPlayers`, identifies peers by same ZDO string and sends vitals (`1969-2003,2043-2059`). No party map-position publication or compatible Groups/SocialSystem XP API was found. The Minimap references inspected are HUD-editor transforms (`1419-1424`), not membership position sharing. Does not satisfy the complete party contract.
- **Scope/UI:** HUD XP is the sum of skill XP, not character attribute progression (`1092-1094`); turn this off with a real level mod. Patches Hud.Awake/Update, Skills.Skill.Raise, InventoryGui.UpdateCharacterStats, InventoryGrid.UpdateGui and HotkeyBar.UpdateIcons (`58-117,150-199,643-670`). These share UI surfaces with EpicMMO HUD and AzuExtendedPlayerInventory; exact visual collision is **[INFERENCE]**, not a proven hard conflict. Skills Raise postfix adds another observer to WAP's replacement.
- **Quality:** useful null checks around local player/ZDO/Hud, but `UpdatePartyHud` allocates a new List or LINQ closure/ToList every frame (`2043-2059`); broadcast is throttled to 0.5s while roster allocation is not (`1969-1975`). Incoming stats append to dictionary without membership validation (`1990-1993`). Membership uses live ZDO, not versioned character save; no migration/corruption machinery needed for its temporary string, but no durable server party authority. Ordinary BepInEx config, no lock demonstrated for these party options.
- **Fit:** does not rewrite gear numbers/professions/magic or cancel deaths in the examined party/UI path, but fails eight-cap, all-map positions and kill-XP integration. XP curve, attribute points and respec are not its axis. Screen clean; no runtime proof. Decisive rejection is incomplete party semantics, not popularity or UI preference.

## Zenox/Zenox 1.0.53 — REJECT

Primary package: https://thunderstore.io/package/download/Zenox/Zenox/1.0.53/

Party is the same narrow nearby-player/ZDO model: config (`P/Zenox.cs:4412-4430`), sender (`4454-4470`), popup receiver (`4555-4573`), per-frame roster (`4575` onward). It uses the SAME `ZenoxPartyID` key as BetterUI (`2992`, versus BetterUI `1043`), so installing both creates two invitation/party-HUD owners over the same identity **[INFERENCE: duplicate ownership risk]**. Invite acceptance exists, but no verified eight-cap/map publication/XP consumer integration. Independent of Guilds.

Its all-in-one scope is actively contrary to this server out of the box: tailwind always provides max sail force (`2336-2338`; config `3377`), permanent guardian power sets GP TTL zero and unlocks powers server-wide (`554-568`; config `3381`), raids disabled (`3390`), fog disabled (`3391-3393`), automatic boss discovery (`3383`, default off). Tailwind and permanent power are switchable; the latter reaches directly into ProgressivePowers' axis and removes personal earning/power-choice constraints. These are not unavoidable features, but switching off unrelated systems still leaves an inadequate party owner. `SyncedValue<T>` exists (`5458` onward) for gameplay features, while party flags are plain ConfigEntry (`4414-4416`); do not assume those party controls use the gameplay sync layer.

Broad UI takeover and near-copy party code carry BetterUI's per-frame allocation/authority issues; functional feature switches are better than hardcoded gameplay, but patch breadth increases integration risk. Screen clean; startup, UI and full SyncedValue lock semantics not runtime verified. No claim that fast version cadence proves AI authorship. Does not contribute an attribute/talent/XP curve or meaningful respec solution relevant to this slice.

## Landoria/Socialize 1.0.16 — REJECT

Primary package: https://thunderstore.io/package/download/Landoria/Socialize/1.0.16/

- Server invitation/acceptance state is checked against stored inviter (`P/Socialize.cs:976-990`); leader-only invites, no self-invite, grouped target rejection (`1154-1171`). Intentional, independent parties; no Guilds dependency seen.
- **Hardcoded five cap**, checked both invitation and acceptance (`983`, `1164`); README explicitly says five (`P/Socialize/README.md:14`). Cannot tune to eight without source changes.
- Positions are automatic every two seconds, private outside group; pings group-only (`README:31-35`; decompiled server position serialization `2280-2338`). This changes more map/privacy semantics than the contract requires.
- **Direct `/g` collision:** registers `g` for group chat (`Socialize.cs:855-857,884-899`) while Guilds consumes `/g` (`/tmp/lembitu-research/GroupsWorldCluster/Guilds-code/Guilds/ChatPatches.cs:125-128`). Order-dependent outcome is **[INFERENCE]**; command ownership collision is observed. It also prefixes Chat.SendInput/SendText (`693-726`), modifies ranges and persistent channels, removes public server-wide chat (`README:21-29`) and hides public position toggle (`Socialize.cs:2579-2605`). Not just XP/positions.
- README says Crossplay yes, Steam network no, player-hosted unsupported (`README:68-74`). These are publisher claims, not a locally reproduced network failure.
- Quality: separately factored policies and server invitation validation are better than Zenox's unvalidated string acceptance. Session-only party state explicitly cleared/disconnected (`README:4,18-19`; `Socialize.cs:1110-1114,1428-1431`). No extra character-save format found. Update services poll RPC readiness/timeouts (`1398-1416,2694-2699`); no performance benchmark. No compatible Groups/SocialSystem XP API found, so no verified level-mod pairing. Screen clean; no runtime proof. Reject for cap and `/g` ownership, not stale refs.

## Smoothbrain/Groups 1.2.10 — REJECT current binary

Primary package: https://thunderstore.io/package/download/Smoothbrain/Groups/1.2.10/
API source link in exact README: https://github.com/blaxxun-boop/Groups (`P/Groups/README.md:3`). API metadata marks deprecated (queried today).

Functional fit is much closer: invites, leave/remove/promote (`README:5-15`), map visibility regardless public toggle (`35-37`), max config range 2–10 permits eight and config lock defaults on (`P/Groups.cs:737-740,769-771`). Group list API returns PlayerReferences (`196` onward), independent of guild identity. `/p` rather than `/g` avoids Guilds command ownership (`README:23`). Adds health HUD, colored names, friendly-fire control and group-only pings (`README:25-45`), beyond the narrow sharing contract; PvP is absent so friendly-fire control has no intended gameplay role here.

**Observed blocker:** screen exit 1, stale `ZRoutedRpc.Everybody` field references in ServerSync AddConfigEntry/AddCustomValue callbacks, `sendZPackage`, and group-ping RestrictBroadcast (`P/Groups.screen:1-11`). Config entries actually register in Awake (`Groups.cs:769-771`), and RestrictBroadcast is injected by a Chat.SendPing transpiler (`1225-1257`). These are reachable subsystems, not unused bundled code. **[INFERENCE]** current binary will fail in config-change broadcast/group-ping paths on this game's const-member change. It has NOT been launched to claim a specific startup exception. To the user's precise 'does it still load?' question: no demonstrated clean-load result; known stale reachable references mean reject as shipped, even if plugin Awake itself happens to finish.

Quality: old ServerSync snapshot is the decisive defect; friendly-fire Aoe/Character transpilers (`630-691`) and ping RPC rewrite (`1238-1257`) are additional instruction-pattern fragility. Adds damage interception despite party scope. API polling/group references allocate Lists (`196` onward); no measured frame profile. Temporary group leaves on shutdown (`692-700`), no character migration required.

Integration: WackyEpicMMO 1.9.71 checks `Groups.API.IsLoaded/GroupPlayers` (`R/EpicMMOSystem.cs:8343-8358`), configurable `GroupExp`, range (`6516,6521`). SkillsReworked 2.1.0 also reads Groups API (`R/SkillsReworked.cs:5017-5020`) but can instead use SocialSystem. Native APIs do not make this stale binary acceptable.

## M2Valheim/SocialSystem 1.0.4 — POSSIBLE; strongest party candidate in this slice

Primary package: https://thunderstore.io/package/download/M2Valheim/SocialSystem/1.0.4/

- **Invite-only and authority:** server PartyService allows leader invitations (`P/SocialSystem.cs:6363-6375`); acceptance validates stored invitation, inviter identity, timeout, membership, leader and capacity before adding (`6412-6455`). Stronger than client-only ZDO strings.
- **Eight:** default eight, configurable 2–10 (`210`), server IsFull uses same cap (`6612-6614`), disconnect reservations count toward party slot/rejoin behavior (`213`, `6538-6593`).
- **Cross-guild:** standalone character PlayerId dictionaries/server Party service (`6311-6337`), independent `SocialSystem_PartyId` ZDO (`8778-8798`); no Guilds criterion in invitation path. Cross-guild supported structurally, real mixed-guild session untested.
- **Map:** server position sharing (`6822` onward) and config true (`212`); 1s sync interval (`7499,7594-7604`). Clients may hide their party markers (`215`) without overriding server roster. Positions rather than terrain exploration; no automatic map exploration discovered.
- **Config authority:** hard Jotunn dependency/network-compatibility attribute (`80-82`), package pins Jotunn 2.30.2 and BepInExPack 5.4.2351 (`SocialSystem/manifest.json:6-8`). ConfigFileExtensions.BindConfigInOrder first boolean is synced/admin-only: target calls true for party mechanics, false for UI (`210-226`); Jotunn supplied XML describes this exact contract (`R/Jotunn/plugins/Jotunn.xml:3822-3835,9948-9951`). No separate ServerSync copy. Attribute enum arguments were not decoded by this C# decompile; exact compatibility strictness remains unknown.
- **Extras:** friends, direct messages, `/p` chat, ready checks, status, vitals HUD (`README:19-30,70-76`). Not literally 'nothing else', though these are social/display tools rather than combat bonuses. Party HUD disable/move/scale configurable (`221-225`). O and P configurable (`217-218`). No gear formula, profession, boss-power, magic or death modification found in party paths. XP curves/points/respec/death-XP belong to paired level mod, not SocialSystem.
- **UI/conflicts:** no `/g` takeover; `/p` avoids Guilds. InventoryGui.Show prefix deliberately suppresses opening inventory while a social window is open (`7844-7855`): interaction difference relevant to AzuExtendedPlayerInventory, not proven hard incompatibility. Minimap.Update/EnemyHud.UpdateHuds postfix recoloring (`7857-7872`); potential last-writer conflict with other name/map color mods **[INFERENCE]**. HUD placement can coexist by configuration; actual EpicMMO/Guilds/Azu visual overlap untested. Do not install a second party owner.
- **Quality:** explicit invitation invariants, timeout/rejoin model, reused scratch buffers (`6321-6325,6458-6466,6577-6593`), null-safe ZDO publisher with IsOwner (`8784-8798`) and shutdown cleanup (`7828-7841`). Better decomposition than Zenox and no party-wide core combat prefixes/transpilers found. UI List rebuilding occurs on membership redraw (`1577-1582`), not proven every frame. Server vitals sent 0.25s, positions 1s (`7499-7501,7591-7604`); traffic grows with party peers but bounded at chosen eight **[INFERENCE]**.
- **Save:** parties/invitations/messages session-only (`README:43-45`; server Clear `6602-6609`), friends/status use namespaced Player customData (`9535-9560,9773-9799`). Friends names are base64 and each malformed record is ignored with FormatException catch (`8901-8933`); no explicit migration/version, but corruption of one entry does not abort whole deserialize. Character attributes/skills not serialized by this mod.
- **Pairing:** SkillsReworked's native integration reads the same nonzero party ID (`R/SkillsReworked.cs:4843-4866`); nearby receiver gets xp × configurable factor (`4979-4993`). SocialSystem itself does not calculate XP. No verified native EpicMMO bridge in this target.
- **Verdict:** POSSIBLE rather than unconditional STRONG FIT because extras exceed literal minimal party scope, game startup/UI/mixed-guild runtime is untested, and fixed per-recipient XP factor is not a party-size-normalized formula. Screen clean. Best party candidate here, particularly if SkillsReworked is otherwise selected by the level/talent research.

## Armikur/SkillFloors 1.2.2 — REJECT as boss-key floor replacement

Primary package: https://thunderstore.io/package/download/Armikur/SkillFloors/1.2.2/

Floors are independently trained at configurable 15% of active skill XP, not boss keys (`P/SkillFloors.cs:72,88-123`). Raise postfix recomputes raw increseStep × factor × Game skill rate (`161-169`), and death postfix raises any skill below its personal trained floor (`172-186`). It does not replace LowerAllSkills; shares Raise target with WAP. Its accumulator advances even if WAP limits actual Raise gain **[INFERENCE from unconditional postfix and WAP replacement]**, allowing a second floor authority disconnected from boss progression. Death restores max of surviving skill and own floor, potentially above WAP floor. Does not bypass death itself, corpse run or timed debuff; does replace intended floor ownership.

Save is version-1 Base64 ZPackage in Player customData (`247-258,262-285`); unsupported version warns/aborts but malformed base64/truncated package lacks catch in load. Static floor dictionary/load flag reset on logout (`379-384`), scoped spawn guards (`341-376`). No frame update loop required. Null-safety weakest on generic Raise/OnDeath paths: direct m_info/local HUD assumptions. Floor increment discards XP overflow (`99-102`); rates up to 1.5 can produce substantial trained floor. Jotunn IsAdminOnly config tag (`72-75`) exists, but exact enforcement dependency/compatibility not independently proved in this slice. Screen clean. No reason to add a duplicate skill-floor save system when requirement is keyed catch-up, not practice-earned permanent skill.

## Searica/FortifySkillsRedux 1.7.0 — REJECT with WAP; not the desired replacement

Primary package: https://thunderstore.io/package/download/Searica/FortifySkillsRedux/1.7.0/

Practice-earned fortify accumulator based on gap between active and fortified skill (`P/FortifySkillsRedux.cs:773-800`); configurable skill XP multiplier default 1.5 (`405`), fortify knobs (`415-426`), global/per-skill settings (`370`). This is not boss-key progression. **Death finalizer assigns every skill directly to fortify level** (`604-623`), not merely clamps a lower bound; can LOWER a skill below WAP's boss floor after WAP drained it. Also mutates global DeathSkillsReset key (`593-601`) and offers retained-item/tombstone changes (`378,493-588`), outside unchanged corpse rules; item features switchable, but floor policy remains wrong.

Shares Raise with WAP (prefix priority 700 fortify, priority 0 active multiplier; `773-829`), and modifies save/load internals: injects dummy skill IDs into live m_skillData at Skills.Save then restores only in postfix (`697-768`); reads original package manually and rewinds (`650-695`). Maintains old save version handling for accumulators (`666`), null checks on skill info, but no exception guard/finalizer around save dictionary restoration: thrown save could leave dummy data in memory **[INFERENCE]**. This is a substantially more invasive persistence seam than customData. Effects on level-up use local player and prefab array index without demonstrated bounds guards (`809-814`). SkillsDialog.Setup postfix (`831-838`) overlaps DetailedLevels' surface **[INFERENCE: visual collision]**. Screen clean. Mature release history does not outweigh wrong death semantics.

## Mirfin/SkillLoss 1.2.0 — REJECT with WAP; no boss-floor support

Primary package: https://thunderstore.io/package/download/Mirfin/SkillLoss/1.2.0/

Per-skill death multipliers, not a keyed floor. Its LowerAllSkills prefix independently applies level − level × factor × multiplier, clamps only to ZERO, resets accumulator and returns false (`P/SkillLoss.cs:299-302,402-419`). WAP uses the same core target and returns false; SkillLoss does not check __runOriginal. **Observed conflicting algorithms; [INFERENCE] order-dependent floor bypass/double drain**. XP multipliers through RaiseSkill prefix (`421-424,524-529`) alter profession/magic/vanilla skill pace and feed WAP's Raise replacement indirectly. ServerSync registration present (`221-225`); clean stale-field screen. No extra character-save persistence found in examined gameplay classes; relies on vanilla skills. Death path uses GetSkillList and straightforward bounded loop, no per-frame work. No boss-key hook/API or switch that transforms it into WAP's algorithm. It can zero loss per skill, but eliminating loss is not desired boss-floor behavior. Exact lock default not independently verified; does not affect decisive rejection.

## WAP 1.0.0 comparison — KEEP existing skill manager

WAP floor derives from counted boss keys and configured skill-per-key, with optional min/max overrides (`R/VentureValheim.Progression.cs:3269-3275,3312-3314`), unlike all three alternatives. Server-synced enable/drain/absolute-drain config (`396-399`). LowerAllSkills prefix checks __runOriginal before owning drain, uses GetSkillDrainFloor/GetSkillDrain, zeros accumulator and skips original (`3187-3213`). Raise is a full replacement that owns gain ceiling/accumulation (`3216-3240`). Full replacement patches are more intrusive than postfix observers, but they implement the requested mechanic rather than an unrelated trained floor. Avoid stacking any of the three above. WAP remains other progression gating owner regardless, so replacing its skill manager would add another mod without delivering boss-key floor.

WAP's Raise replacement does not multiply Game.m_skillGainRate in this observed body (`3225-3227`); that is a relevant tuning boundary for level/skill research, not an instruction to change it here. Personal-vs-global boss-key setup belongs to server configuration; floor calculation code supports boss count, but this slice did not reverify live config or execute death. Keep WAP recommendation is based on semantics/source, not a new runtime proof.

## Comparison

| Mod | Version | Verdict | Decisive reasons |
|---|---|---|---|
| Zenox/BetterUI | 1.0.14 | REJECT (party owner) | No verified enforced eight-cap, all-map party positions or XP integration; client live-ZDO roster |
| Zenox/Zenox | 1.0.53 | REJECT | Same inadequate party; broad tailwind/permanent-power/raid defaults outside axis |
| Landoria/Socialize | 1.0.16 | REJECT | Hardcoded five; owns `/g` and map/chat privacy beyond contract |
| Smoothbrain/Groups | 1.2.10 | REJECT current binary | Reachable stale Everybody field reads; deprecated despite useful native XP API |
| M2Valheim/SocialSystem | 1.0.4 | POSSIBLE, top party candidate | Server validated invitations, configurable eight, positions, SkillsReworked integration; extras and runtime caveats |
| Armikur/SkillFloors | 1.2.2 | REJECT replacement | Trained floor not boss-key; duplicate Raise/death authority |
| Searica/FortifySkillsRedux | 1.7.0 | REJECT replacement | Death finalizer overwrites WAP floor; invasive dummy-skill persistence |
| Mirfin/SkillLoss | 1.2.0 | REJECT replacement | Core drain replacement clamps to zero, conflicts with WAP |
| VentureValheim/WAP | 1.0.0 | STRONG FIT for floor, KEEP | Boss-key floor matches intent; no extra floor owner needed |

## Coverage gaps

No Unity/client/server startup, map-position cross-zone test, mixed-guild eight-person invitation scenario, corpse/death scenario, or HUD screenshot was run. Screen results are narrowly static. No blanket compatibility claim with pinned Herbalist/Blacksmithing/MagicPlugin/ImpactfulSkills/BetterArchery/SkadiNet/Dive_In/AdditiveDamageModifier/CreatureManager/EpicLoot: these party mods' examined party paths do not own those combat/profession formulas, but all-in-one Zenox and floor XP multipliers explicitly reach wider. DetailedLevels/Guilds/Azu/EpicMMO UI overlap needs actual Pack Shakedown. Network attribute arguments and some lock defaults noted above remain undecoded/unverified. Main agent owns final chosen-level combination and XP normalization interpretation.

## Ending: party × level kill-XP pairings

1. **SocialSystem 1.0.4 + SkillsReworked 2.1.0:** verified native ZDO integration (`R/SkillsReworked.cs:4843-4866,4979-4993`; `P/SocialSystem.cs:8778-8798`). Radius and factor configurable; receiver computes share locally, server authorizes party roster. Not EpicMMO-compatible out of the box.
2. **Groups 1.2.10 + WackyEpicMMO 1.9.71:** verified API consumer (`R/EpicMMOSystem.cs:8343-8358`), factor/range configurable (`6516,6521`), but current Groups binary fails stale-reference screen. Do not choose the stale package merely to obtain this pairing.
3. **Groups + SkillsReworked:** native API branch verified (`R/SkillsReworked.cs:4990,5017-5020`), same binary blocker. Prefer its SocialSystem branch instead.
4. **BetterUI, Zenox, Socialize:** no verified native XP pairing with either examined level mod. Similar UI/party naming is not integration.
5. **CaptainSkillTree alternative:** sibling EpicMMOFamily reports native PartyManager and EpicMMOGroupsBridge adapting embedded Groups calls at `/tmp/lembitu-fit/EpicMMOFamily/CaptainSkillTree.cs:71652-71927`. This is attributed peer evidence, not independently inspected here; use that agent's handback to judge it, not Groups' broken DLL.

**Formula caveat:** SkillsReworked's ordinary share is `recipientXP = killXP × factor`, not divide-by-party-size (`4979-4993`); for one killer plus N−1 eligible recipients, total is **[INFERENCE]** `killXP × (1 +(N−1)factor)`, before other recipient reward modifiers. At N=8, factor 0.0142857–0.0357143 yields 110–125% of a single solo kill; default 0.3 yields 310%. A fixed factor does not hold a uniform 110–125% bonus at every party size. The ADR's phrase 'what its members would earn apart' (`53-55`) needs the dispatcher's interpretation before tuning; no invented adaptive formula is promised by these mods.
