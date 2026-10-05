# ScoutUI — premium presentation / QoL scouting

## Summary

1. **Try Ab5oluteZer0/CraftingSearch 1.0.2 first:** a small, preference-only search/sort improvement, without another inventory, crafting-from-chests, or progression owner.
2. **Try Marins/CompactStatusEffects 1.1.2:** clearer names/timers for the much larger Oathbound + Herbalist + passive-power buff load. Keep the right edge free of AzuClock/BetterMap and the party HUD.
3. **Try Jumpingmushroom/DamageSplash 0.1.3 with `Preset=Bold`, `Visibility=All`, `EdgeFlash=false`:** readable damage without arcade visual noise or ambiguous attribution in multiplayer.
4. **Try Biozip/HoverCompare 0.5.0 cautiously, with `ReplaceGameTooltip=false`:** useful gear comparison, but EpicLoot and extra-slot support explicitly remain untested. Never hide EpicLoot/Blacksmithing/Item_Requirement tooltip text behind simplified cards.
5. **Try RDMods/CustomMainMenu 1.5.0 for Pack branding:** one place for logo, loading art, rules tips and changelog. Replace its bundled demo/Discord branding; preserve the first-run cinematic. Prefer this over a second networked loading-screen system.
6. **Consider Goldenrevolver/Quick_Stack_Store_Sort_Trash_Restock 1.4.15, current-container-only:** unlike the cut storage routers, its area ranges and multiplayer permission are server-synced and lockable. Pin both ranges to zero and leave multiplayer area operations off. It explicitly handles AzuEPI slots.
7. **Do not add another party HUD/party system:** SocialSystem already has avatar/name/level/health bars and party name coloring. Screen-layout tuning, not another network authority, is the cohesive solution.
8. **BetterChat's original cut reason has expired because Clan is gone:** Crystal/BetterChat 1.6.4 is reconsiderable; prefer its limited changes over ComfyMods/Chatter's whole chat rewrite. Guild/party custom-channel preservation still needs Shakedown proof.
9. **Reject Stonaar/ValheimBuildCamera 1.10.0 despite its recent release:** it is not just a camera; it adds unsynced mist removal and resource-return behavior. Existing placement owners make its extensive transpilers especially undesirable.
10. **All 18 reviewed candidate DLLs and ConditionalConfigSync 1.0.10's two DLLs passed the requested stale-member screen.** No downloaded package contains a preloader patcher. This is static evidence, not a game boot or Harmony compatibility pass; nothing was installed, built, deployed, or run in-game.

## Evidence conventions and scope

Scratch root **S** = `/tmp/lembitu-premium/ScoutUI/`. `S/<Name>/src/<Assembly>/...` is decompiled **the exact package version below**, not upstream HEAD. Versioned READMEs are saved at `S/<Name>/readme.txt`, obtained from `https://thunderstore.io/api/experimental/package/<owner>/<name>/<version>/readme/`; package downloads use `https://thunderstore.io/package/download/<owner>/<name>/<version>/`. The package's `pkg/manifest.json`, `pkg/CHANGELOG.md` where supplied, and complete `pkg/` tree are retained.

The nondeprecated index and raw Thunderstore API version records are the source of update/activity claims: `/tmp/lembitu-premium/index.json`, `/tmp/lembitu-premium/thunderstore-valheim.json`; selected metadata at `S/selected.tsv`, extra metadata at `S/extra.tsv`, release histories at `S/activity.tsv`. Release counts below measure **visible Thunderstore publication activity**, not promises of future maintenance or GitHub issue responsiveness.

Ran `scripts/screen-bundled-libs.sh` against the downloaded binaries: `S/screen-all.txt:1` says clean for 15 candidate libraries; `S/screen-extra.txt:1` clean for HoverCompare, CaptainAudio and PlayerTitles (3); `S/ConditionalConfigSync/screen.txt:1` clean for 2 sync-dependency libraries. Inspected complete downloaded package layouts: all managed DLLs are plugins/root plugin assemblies, no `patchers/` or separate patcher DLL. Shared BepInEx/Jotunn/YamlDotNet remain the existing Pack owners; ConditionalConfigSync is the only new library proposed here. Use **1.0.10**, not Compass's old manifest minimum 1.0.5, or BetterChat's original 1.0.6-era closure. Static scanning does not establish Harmony targets exist, patch order is safe, or a UI is usable at every resolution.

No candidate changes the intended 50–60 hours/player month directly. Search/sorting should remove menu friction, not gathering/profession work. No automatic repairs, chest-to-chest routing, discovery radar, distant automatic pins or extra slot system are proposed.

## 1. Try in Shakedown — Ab5oluteZer0/CraftingSearch 1.0.2

**What:** localized/accent-insensitive recipe search, existing-game sort modes plus reverse alphabetic order.

**Evidence:** `S/CraftingSearch/readme.txt:1-36`; `src/CraftingSearch/CraftingSearch/Plugin.cs:13-78` patches `InventoryGui.Awake`, `UpdateRecipeList`, `Hide`, and `Chat.HasFocus`. The last only returns focus=true while typing; the recipe changes are list/UI operations. No configuration entries or gameplay permission/range to sync. README says tested on Valheim 1.0.15, not our exact 1.0.16.

**Fit/conflicts:** same broad inventory surface as AzuEPI/AzuCraftyBoxes/Item_Requirement/Oathbound, but does not patch `DoCrafting` or replace resource consumption. `Chat.HasFocus` can interact with social windows/input; avoid a second recipe-search owner such as MyLittleUI at the same time.

**Proposal:** try alone with the stock sorting default; retain profession-lock readouts. Check forge, cauldron, mead ketill and upgrade searches, including recipes blocked by personal key versus profession level; verify typing does not move the player or suppress guild/party chat after closing.

**Activity/confidence:** updated 2026-09-30; 3 visible releases across Sept 29–30. High confidence in narrow static scope; actual panel collision/input and gating presentation are Shakedown-only.

## 2. Try in Shakedown — Marins/CompactStatusEffects 1.1.2

**What:** vertical buff/debuff list with labels, countdown and scalable layout.

**Evidence:** `S/CompactStatusEffects/readme.txt`; `src/CompactStatusEffects/CompactStatusEffects/CompactStatusEffectsPlugin.cs:83-88` binds only Enabled, panel key, root offsets, Scale and SpacingY. `Hud_UpdateStatusEffects_Patch.cs:9-120` is a postfix that adjusts existing status-effect rects and displays `GetIconText()`. Input patches are `GameCamera.UpdateMouseCapture` and `PlayerController.TakeInput`, to support its options panel.

**Fit/conflicts:** presentation-only Pack exception, not buff strength/duration. Main overlap is `Hud.UpdateStatusEffects` with any broad UI mod and Oathbound's status UI; shared mouse-capture/input surface with SocialSystem. BetterMap/AzuClock occupy nearby screen space, not an established binary incompatibility.

**Proposal:** seed `[2 - Position] RootX=-180`, `RootY=-290`, `[3 - Sizing] Scale=1`, `SpacingY=55`, then let users tune preference. Do not combine with MyLittleUI's custom status elements. Check 10+ simultaneous effects, long localized names, controller F8/ESC behavior and different resolutions.

**Activity/confidence:** updated Sept 25; 3 visible releases that day. High static confidence; list length and Oathbound cooldown representation require Shakedown.

## 3. Try in Shakedown — Jumpingmushroom/DamageSplash 0.1.3

**What:** clearer outlined damage numbers, readable elemental ticks and configurable animations.

**Evidence:** README `S/DamageSplash/readme.txt` describes client-only rendering and explicitly warns that Mine cannot identify remote-owned hits reliably. `src/DamageSplash/DamageSplash/PluginConfig.cs:213-228,262-265` provides the exact preferences; `DamageSplash.Patches/DamageTextPatches.cs:8-38,121-125` patches `DamageText.Awake`, `AddInworldText`, `UpdateWorldTexts`; `ContextPatches.cs:16-19,98-120` observes `Character.ApplyDamage`; `OutgoingHitPatches.cs:13+` chooses outgoing-hit targets. This is not a damage multiplier mod.

**Fit/conflicts:** broad combat observation surface shared with Oathbound/CreatureManager/AdditiveDamageModifier, but a renderer owner rather than another combat mechanic. README names ColorfulDamage and ZenCombat as conflicting renderers; neither belongs in this addition.

**Proposal:** `[1 General] Preset=Bold`, `MaxDistance=30`; `[8 Self] Visibility=All`, `EdgeFlash=false`. Keep color/size choices local. The original Festive arc/edge flashes are less cohesive and less accessible. Compare server-owned boss damage, player-owned mobs, DOTs, heals/blocks and Oathbound ability hits; do not treat displayed tags as a trustworthy party DPS ranking.

**Activity/confidence:** Sept 26, 4 releases across Sept 25–26. Medium-high static confidence; multiplayer classification and eight-player clutter require Shakedown.

## 4. Try in Shakedown, guarded — Biozip/HoverCompare 0.5.0

**What:** gear comparison cards for inventory/chest, crafting/upgrades and trader.

**Evidence:** `S/HoverCompare/readme.txt:43-76` explicitly says EpicLoot and extra-slot mods **have not been tried** and offers preserving the original tooltip. `src/HoverCompare/HoverCompare/HoverComparePlugin.cs:74-83` contains local display preferences only. `Hovered.cs:24-43` dynamically postfixes `InventoryGrid.CreateItemTooltip` and `StoreGui.FillList`.

**Fit/conflicts:** comparison fills a real gap without owning slots. AzuEPI equipment lookup, EpicLoot property interpretation, Blacksmithing item data and WhichModAddedThis/Item_Requirement tooltip additions must remain visible. Green/red base-stat deltas are not proof an enchanted item is objectively better.

**Proposal:** `[Panel] ReplaceGameTooltip=false`, `View=Compact`, `MaxCompared=1`; consider `[General] Mode=Hold` to avoid covering the crafting panel. Reject adoption if enchanted-affix deltas or worn-slot selection are misleading. Use ordinary versus EpicLoot-enchanted, smith-crafted, two-handed, shield, custom Oathbound weapon and quality-upgrade examples.

**Activity/confidence:** Sept 30, one visible release. Medium static confidence, low integration confidence until Shakedown. Strong potential, not an adoption recommendation yet.

## 5. Try in Shakedown — RDMods/CustomMainMenu 1.5.0

**What:** coherent logo/music/menu changelog and loading art/tips.

**Evidence:** `S/CustomMainMenu/readme.txt` documents the exact config asset folder and keys. `src/CustomMainMenu/CustomMainMenu/CustomMainMenuPlugin.cs:129-152` binds local UI settings and patches presentation. Individual patch files identify `FejdStartup.Start`, `LoadMainScene`, `Hud.Awake`, `Hud.ShuffleTips`, `ChangeLog.Start/GetPlatformText`, scene/intro lifecycle and `AudioSettings.SetGlobalVolumeExceptHaptics`.

**Fit/conflicts:** pure Pack presentation. Shares menu startup with ServerQuickConnect; loading Hud lifecycle with Oathbound/HUD additions. Menu music can compete with CaptainAudio. Choose this OR ServerLoadingScreen for loading artwork, not both.

**Proposal:** ship original Lembitu artwork and `config/CustomMainMenu/changelog.txt`, `customtips.txt`; `[Loading Screen] UseCustomTips=true`, `UseCustomLoadingLogo=true`; `[Startup] SkipIntroCinematic=false`; `[Discord Panel] DiscordInviteUrl` must be the group's actual invite or empty, **not the bundled author invite**. Keep default letterboxing for legibility; decide custom music only after auditory review. Tips should explain personal boss presence, Calling craft-versus-use rules and shared boss drops.

**Activity/confidence:** Oct 2; 9 visible releases, including Sept 20/25 and Oct 2. High static fit; artwork, ServerQuickConnect button and audio sliders need actual client inspection.

## 6. Consider — Goldenrevolver/Quick_Stack_Store_Sort_Trash_Restock 1.4.15

**What:** favoriting, safe current-container quick stack/store/restock, sorting and trash UI.

**Evidence:** README `S/Quick_Stack_Store_Sort_Trash_Restock/readme.txt:41-47,91-114` documents multiplayer area-operation limitations, server-synced area settings and explicit AzuEPI support/custom-data merge exclusions. `src/QuickStackStore/QuickStackStore/QSSConfig.cs:442-480` uses `BindSynced` for permissions/ranges and `BindSyncLocker` for the toggle. `ServerSyncWrapper.cs:9-12` registers the locking config. `QuickStackModule.cs:18,70` and `RestockModule.cs:54,94` gate/scan on these ranges, not a second ungoverned per-client chest network.

**Proposal:** on server and clients, `[2 - Quick Stacking and Restocking] ToggleAreaStackRestockConfigServerSync=true`, `AllowAreaStackingInMultiplayerWithoutMUC=false`; `[2.1 - Quick Stacking] QuickStackToNearbyRange=0`; `[2.2 - Restocking] RestockFromNearbyRange=0`. Source `QSSConfig.cs:433-450` distinguishes the actual CFG section from display category `2.0 - Area Quick Stacking and Restocking`. Current-container behavior only. Do not install MultiUserChest to make area operations work.

**Conflicts:** `InventoryGui.Show/Hide/CloseContainer`, `InventoryGrid.UpdateGui/OnLeftDown/OnRightDown/UpdateGamepad`, `Container.Awake/RPC_StackResponse`, `Player.Update`; mouse gestures overlap MouseTweaks, slot decorations/layout overlap AzuEPI. Prefer this to adding InventorySort as well. The risk is inventory/network state, not just cosmetics; require a two-client item-conservation/locked-slot check, including EpicLoot/custom-data stacks and backpacks, before adoption.

**Activity/confidence:** Sept 12; 36 releases, two 1.0-era updates that day following a 2025 release. Medium confidence; lock behavior and custom inventory interactions need Shakedown. This does **not** re-propose cut StorageGroups/ChestSorter.

## 7. Consider, not first-wave — Crystal/BetterChat 1.6.4

**What:** persistent visibility, slash-to-open, mixed-case text and click-through, without replacing the whole chat panel.

**Evidence:** `S/BetterChat/readme.txt`; `src/BetterChat/BetterChat/BetterChatPlugin.cs:25-213` targets Chat Awake/Update/LateUpdate/OnNewChatMessage/AddInworldText/InputText and Terminal.AddString, plus Player lifecycle. Lines 336-362 register preference and policy-controlled entries with ConditionalConfigSync; lines 522-523 write talk ranges. This is not wholly cosmetic unless range settings are server controlled.

**Expired cut reason:** `docs/modstack.md:451,456` says Clan owned the old chat path and Clan is now removed. That reason expired. SocialSystem's inspected patches instead focus on windows, party/map identity and network state (`/tmp/lembitu-build/SocialSystem/SocialSystem.Patches/`), but Guilds/custom chat must still be tested.

**Proposal:** preserve vanilla `TalkDistance=15`, `WhisperDistance=4`, `DefaultShout=false`, `ShowShoutPings=true`; use ConditionalConfigSync policy to force the distance settings server-side. `HideDelay=20` or `AlwaysVisible=true` may remain preference. Do not add Chatter too. Verify `/g` guild versus party commands, message prefixes, whispers and text-input focus. No stronger channel-compatibility claim is made.

**Activity/confidence:** Sept 15, 23 releases, Sept 13/14/15 activity. Medium confidence; only Shakedown settles custom-channel preservation and sync policy behavior.

## 8. Consider — shudnal/Compass 1.1.2

**What:** headings and already-owned map pins, not world radar.

**Evidence:** `S/Compass/readme.txt:1-18`; `src/Compass/Compass/CompassHUD.cs:633-648` consumes Minimap's existing pin, ping, shout and player-pin lists. `Compass.cs:143,173-180,206-245` registers Lock Configuration and server-policy-controlled pin types/distance conditions. It does not need a map-sharing authority.

**Proposal:** `[General] Lock Configuration=true`; initially `[Pins] Show pins=None` for a heading-only compass. Add already-known personal/party pins only if their map semantics remain clear. Use ConditionalConfigSync 1.0.10. No trader reveal, auto distant pin creation or creature scanning. Do not replace BetterMap. Preference position/scale stay local.

**Conflicts:** Hud Awake/Update/OnDestroy and Player.SetCrouch; Oathbound top-center UI, AzuClock and CompactStatusEffects screen space. Guilds shared `!` pins and SocialSystem party pins are data supplied by their owners, not recreated here.

**Activity/confidence:** Sept 11, 10 releases, adjacent Sept 10 update. High static confidence that it displays existing pins; actual title/layout and pin privacy require Shakedown.

## 9. Consider only as an intentional consolidation — shudnal/MyLittleUI 1.2.26

**What:** requirements counts, upgrade-highlight tooltips, detailed character/effect stats, crafting search/filter, buff layout, many hover readouts.

**Evidence:** `S/MyLittleUI/readme.txt:5-24,43-79` documents sync policy, EpicLoot tooltip support and AzuEPI slot count handling. `src/MyLittleUI/MyLittleUI/MyLittleUI.cs:1527,1638-1639` locks; `1944-1952` enables counts/multicraft/filter; `2080,2116` exposes hold-repair; `1663-1739,1794` clock/weather/winds; `2103-2140` station/chest hovers; `2175-2179` status list. `MultiCraft.cs:30-65` observes crafting; `ItemTooltip.cs:23+` patches ItemData.GetTooltip; `ChatItemLinks.cs:106-230` adds inventory/chat hooks.

**Fit:** genuinely tunable and maintained, unlike an untunable all-in-one takeover. But overlaps AzuHoverStats, AzuClock, CraftingSearch, CompactStatusEffects and HoverCompare. Requirements counts explicitly say **player inventory only**, so they can understate AzuCraftyBoxes resources. Not a free improvement to drop into this stack.

**Proposal:** consider only if replacing overlapping display owners deliberately, or limiting it to upgrade/stat/tooltips. Force `Inventory / Enable repair on hold=false` (owner rejected auto repair), `Info - Winds / Enabled=false`; turn `Item - Available resources amount / Multicraft=false` for an initial display-only trial; turn off clock/weather/hovers/status replacements if keeping their owners. No silently adopting defaults. Never enable its native radial item search without a demonstrated need: the config itself warns about side effects from other mods.

**Activity/confidence:** Sept 24; 80 releases, recent Sept 21/22/24 activity. High confidence in tunability, medium-low fit as an addition. A consolidation decision plus Shakedown is needed; small specialist mods are the first recommendation.

## 10. Consider later — BeverloHills/PlayerTitles 1.2.0

**What:** admin-awarded cosmetic titles in vanilla nameplates/chat; optional guild reputation/boss-night ceremony, not another level system.

**Evidence:** `S/PlayerTitles/readme.txt:7-27,35-45`; `src/PlayerTitles/PlayerTitles.Networking/RpcManager.cs:130-156,208-234` verifies assigning/revoking senders against server admin identity. `PlayerTitles.Patches/NameplateTitlePatch.cs:9` postfixes Player.GetHoverName; `ChatTitlePatch.cs:9-38` intercepts Terminal.AddString and decorates the resolved player name. Current game signature exists: `S/Terminal.cs:2992,3020`.

**Proposal:** consider manual, sparse milestone titles only. No automatic skill rewards or guild rank replacement. Respect Guilds' name prefix/color authority: if both decorate names poorly, retain Guilds and reject this. Install consistently if tried; its Jotunn compatibility requirement is appropriate for the Pack.

**Activity/confidence:** Sept 10; 3 releases Sept 7–10. README explicitly says no live multiplayer proof, tested against 1.0.7/network39. Medium static confidence, low exact-game/multiplayer confidence until Shakedown. Stale-member pass alone does not answer that gap.

## 11. Consider later — korCaptain/CaptainAudio 1.3.52

**What:** curated biome/activity/boss soundtrack and ambient/SFX replacements.

**Evidence:** `S/CaptainAudio/readme.txt:5-20,153-158,274-279`; `src/CaptainAudio/CaptainAudio/Plugin.cs:48-53` binds volume/enabled/loading choices, no gameplay settings. Named Harmony patch files target MusicMan Awake/UpdateMusic, AudioMan Awake/QueueAmbientLoop, EnvMan Awake, MusicLocation Awake, Fireplace Start, TeleportWorld Awake, ZSFX Awake and Terminal.InputText.

**Proposal:** audition, do not automatically adopt. `[General] LocationVolumeMultiplier=1` rather than 5, `MusicVolume=0.6`, `AmbientVolume=0.3` are starting preferences, not remotely enforced gameplay. Preserve audible combat cues/proximity voice and OdinOnDemand audio; do not also override menu music through CustomMainMenu unless the combination is intentional. Verify redistributable rights for the included recordings before calling them Pack assets; README feature/credits text is not rights evidence.

**Activity/confidence:** Sept 10; 13 visible releases, previous May 25. Medium static confidence, subjective cohesion/performance/platform/audio-mixing confidence unverified. Shakedown listening is required; visual polish already has ValheimVisualEnhanced, so no second environment renderer is recommended.

## 12. Consider only instead of CustomMainMenu's loading art — SchmittIT/ServerLoadingScreen 1.0.8

**What:** server-delivered logo/background and hammer/campfire animation with a cached manifest.

**Evidence:** `S/ServerLoadingScreen/readme.txt:3-9,22-41,50-52`; `src/ServerLoadingScreen/ServerLoadingScreen/Plugin.cs:85-148` patches ZNet.OnNewConnection/OnDestroy, Hud.UpdateBlackScreen and Game.UpdateRespawn; lines 226-232 bind server-controlled layout/assets/transfer and animation. This is presentation, but it adds network traffic and intentionally delays initial spawn.

**Proposal:** defer behind client-shipped branding. If selected instead, `Layout / MinimumDisplaySeconds=5`, `LoadingAnimation=Campfire`, `Server / TransferRateKiB=0` initially to avoid replacing Steam's ceiling; small original images. Do not combine loading backgrounds with CustomMainMenu. Crossplay/PlayFab is expressly unvalidated and first transfer shows black until assets arrive.

**Activity/confidence:** Sept 29; 3 visible Sept 27–29 releases. Medium confidence in server ownership, low real-transfer/mixed-platform confidence. Shakedown is necessary; private same-Pack group has little reason to pay a second network protocol for assets already distributable in the Pack.

## 13. Reject for this Pack — Freelancers_Union/InventorySort 1.2.0

**What:** local inventory/open-container rearrangement, no area chest routing. Narrower than the big storage suites.

**Evidence:** `S/InventorySort/src/InventorySort/InventorySort/InventorySorter.cs:37-76` requires local container ownership and excludes equipped/hotbar/QuickStackDeposit locked positions. Lines 117-135 enumerate every nonreserved slot across inventory width/height; no AzuEPI slot-type reservation is present. Lines 164-174 avoid merging custom-data items. `InventorySortPlugin.cs:59-73` settings are local sort preferences; InventoryGui.Awake adds buttons.

**Reason:** AzuEPI is the slot owner. Empty special/equipment slots are not excluded by the visible algorithm; [INFERENCE] sort can place inappropriate items into those rows before AzuEPI repairs them. Skip equipped is not equivalent to reserve equipment slots. QSS explicitly supports AzuEPI; adding this as well brings no payoff. Does satisfy the no-routing constraint, but lacks sufficient slot interoperability evidence.

**Activity/confidence:** Oct 1, one visible release. High confidence in observed algorithm; actual AzuEPI consequence is unverified. Reject provisionally rather than use Shakedown to risk player inventory when a better-fitted candidate exists.

## 14. Reject as unnecessary rewrite — ComfyMods/Chatter 2.13.0

**What:** a full customizable TextMeshPro chat panel with filters/history/movable layout.

**Evidence:** `S/Chatter/readme.txt` explicitly calls this a complete rewrite with missing features. `src/Chatter/Chatter/ChatPatch.cs:17-43,73-112,282-334` patches Awake, InputText, OnNewChatMessage, Update, SendInput, HasFocus and AddInworldText, many as transpilers; TerminalPatch adds output interception; MessageHudPatch also intercepts messages. Its local UI/filter choices are presentation preferences.

**Reason:** wider Guilds/custom-channel and input risks than BetterChat for a group of eight, and a second message HUD observer beside Oathbound. Consider only if stock-panel chat remains an actual problem after the smaller BetterChat trial. No simultaneous Chatter/BetterChat/MyLittleUI chat augmentation.

**Activity/confidence:** Sept 14, 21 releases but previous 2.12.0 is Sept 2025; recent rewrite, not demonstrated continuity. High confidence in overlapping targets; compatibility would need Shakedown, but not recommended to spend that effort first.

## 15. Reject — Stonaar/ValheimBuildCamera 1.10.0

**What:** detached camera plus remote placement/removal and additional gameplay conveniences.

**Evidence:** `S/ValheimBuildCamera/readme.txt` advertises feather-cape mist disappearance and direct-to-inventory demolished resources. `src/ValheimBuildCamera/ValheimBuildCamera/BuildCamera.cs:20-203` patches Player.Update/SetControls/SetMouseLook/TakeInput/StartGuardianPower/CheckPlacementGhostVSPlayers/PieceRayTest/CopyPiece/RemovePiece/UpdateWearNTearHover and Character.GetCharactersInRange; lines 384-390 bind only local enabled/controls/display keys. `FeatherCapeMist.cs:11-14` prefixes ParticleMist.Update; `DirectResourceReturn.cs:23,68` transpiles RemovePiece/DropResources; CollapseReturns also changes WearNTear damage/wear paths.

**Reason:** cannot classify the complete DLL as pure camera preference. No server lock or verified independent off switches for these gameplay riders. Mist visibility and material handling are especially ill suited to a cohesive hard-progression Pack. Placement/removal transpilers overlap PlanBuild/Extra Snap Points/AzuCraftyBoxes, and Player.Update/control hooks overlap Oathbound's UI/control surface. The stale-member pass does not make this suitable.

**Activity/confidence:** Sept 29, 9 recent releases, including a claimed audit in 1.9.0. High confidence in the scope violation. Reject; not merely a Shakedown uncertainty.

## Existing owner: party presentation needs tuning, not replacement

`/tmp/lembitu-build/SocialSystem/SocialSystem/SocialConfig.cs:87-90` defines `2 - Interface / Show party HUD=true`, offsets and `Party HUD scale` as unsynced UI preferences. `SocialSystem.UI/PartyMemberView.cs:86-98,115,152` creates and updates member health bars. `SocialSystem.Patches/PartyHighlightPatches.cs:9-18` colors party EnemyHud names and Minimap pins. Use these facilities for cross-guild boss groups. No redundant party addon is recommended. Guilds remains the membership/rank/prefix owner. A permanently visible standalone guild-members health HUD was not independently verified; cross-guild party health bars satisfy the practical hunt/night need without exposing nonparty positions.

## Notable rejects and category coverage

- **Landoria/Socialize 1.0.16:** downloaded/decompiled/screened. README `S/Socialize/readme.txt:3-33` limits ephemeral groups to five and replaces public chat/map policy; decompiled `LimitMapPingToGroupPatch.cs:6`, `PersistentChatChannelPatch.cs:5`, `ShowGroupMembersOnMapPatch.cs:6` add new authority over chat/positions. Conflicts with SocialSystem's eight-person cross-guild party contract. Sept 12, 17 visible versions. Not an emote-only presentation mod despite its name.
- **asu1/ItemTooltipDisplay 1.0.0:** downloaded/decompiled/screened; `src/ItemTooltipDisplay/SekkaMods/TooltipText.cs:7-19` merely removes a specific notice line. Not a gear comparison system. Sept 10, one version. Insufficient benefit; HoverCompare is the actual comparison candidate.
- **MSchmoecker/VNEI 0.17.6:** downloaded/decompiled/screened. README exposes all items/recipes by default; `src/VNEI/VNEI/Plugin.cs:167-189` has Show Only Known/Force Show Only Known and cheat options. `VNEI.UI/DisplayItem.cs:117-142` gates item cheating by admin/world permission, so this is **not** an unrestricted cheat claim. Its crafting tab/index is broader than recipe search and does not establish how profession/personal gates would be explained. Prefer CraftingSearch first. Sept 10; 62 versions, previous April 12. A known-only recipe encyclopedia remains possible if the group explicitly wants it, but not a first-wave addition.
- **SeneaL_UI, SeneaLHudLayout, InventoryActions/InventorySlots, OpenKeep/large QoL suites:** incumbent-owner conflicts; the explicit SeneaL cut decision has not expired (`docs/modstack.md:455`). No backdoor re-proposal through an add-on layout.
- **StorageGroups/ChestSorter and chest-routing suites:** their Pack-rule objection is still live (`docs/modstack.md:469`). A Sept/Oct release date alone does not expire it.
- **ServersideQoL:** patcher deployment objection remains live (`docs/modstack.md:452`).
- **PIXPIX/Accessibility 0.6.0:** index primary description explicitly includes threat radar; March 3 update is pre-1.0. Not recommended under the no-radar contract. For accessibility, favor larger status text, Bold damage labels, no edge flashes, readable original tooltips and local HUD scaling rather than a threat-intelligence suite.
- **Emotes/social:** index search surfaced no sufficiently compelling updated emote-only candidate for deep verification. Do not use Socialize to fill that label. Vanilla emotes, Guilds banner/ranks and optional admin titles provide social presentation without another group system.
- **Ambient/visual:** CaptainAudio was deeply reviewed; current ValheimVisualEnhanced already owns world visual polish. GraphicsOverdrive's broad renderer feature count is not evidence it is a cohesive replacement, and no replacement is recommended here.

## Gaps

- No runtime UI/game/multiplayer tests were permitted or performed. First-wave candidates need one actual two-client Shakedown covering 1080p/1440p, controller/keyboard, 8-member party layout, long buffs, EpicLoot/smithing tooltips, personal-key/profession blocked recipes and guild/party chat. Static findings must not be promoted to adoption without that proof.
- ConditionalConfigSync 1.0.10 was downloaded, decompiled and screened, but policy-enforcement behavior needs an attempted nonadmin client change. QSS's locking toggle similarly needs an attempted range change; verify exact generated section names before writing overlays.
- AzuEPI slot reservation risk for InventorySort is inferred from the whole-grid algorithm, not observed corruption. Prefer the explicitly compatible QSS trial, with current-container-only and conserved-item checks.
- Upstream maintainer responsiveness, soundtrack/art redistribution rights, CPU/GPU costs, Linux/macOS audio and live Steam/PlayFab loading transfer were not verified. Thunderstore release activity and README claims are not substitutes.
- A dedicated emote-only extension, colorblind-safe palette suite and permanent guild-wide health display were not verified to this standard. They remain optional presentation gaps, not reasons to broaden gameplay/network ownership.
