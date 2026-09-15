# Native testing

This page explains how the dedicated test server, headless client and native gameplay harness prove behaviour in the real game, and how to distinguish that proof from setup, historical observations and unresolved failures. The operating procedure and dated evidence remain in `docs/build.md:300-706`.

## Decisions

- **Run the real game on x86_64 Linux.** Development uses astral-bicep; astral-tricep is the second host for two-client tests. The documented Apple Silicon attempts failed in the dedicated server's Mono runtime under both Rosetta and QEMU, while the native macOS arm64 client could not load the x86_64 Doorstop library. These are observed platform limits, not reasons to substitute simulated gameplay (`docs/build.md:29-45`).

- **Install a separate dedicated server with DepotDownloader.** `scripts/test-server.sh install` downloads the public dedicated server anonymously, extracts fresh references, installs the pinned BepInEx pack and installs built plugins when available. DepotDownloader avoids SteamCMD's 32-bit dependencies and uses a self-contained, hash-checked download. The default installation is `~/.cache/valheim-lembitu/server`, overridable with `VALHEIM_TEST_DIR`. The standalone launcher uses port 2466 because the existing barebones server occupies 2456; arguments after `run` replace the entire default argument list (`scripts/test-server.sh:20-25,37-100`; `docs/build.md:300-313`).

- **A headless client still needs licensed Steam and real graphics.** A running Steam client must be logged into an account that owns Valheim, and the current public game installation must match the test server. Anonymous server downloading does not provide a licensed client. A GPU-backed X display is mandatory; a physical monitor or desktop session is not. The launcher can start Weston with `--backend=headless --renderer=gl --fake-seat --xwayland` and launches Valheim with `-force-glcore`. The native coordinator instead requires the display to exist already and does not own the compositor (`scripts/test-client.sh:10-17,74-92,142-147`; `scripts/test-native.py:456-462`; `docs/build.md:339-360`).

- **Initialize native settings in a separate test preference profile.** Set `XDG_CONFIG_HOME` to `~/.cache/valheim-lembitu/client-preferences` for both first-run setup and later tests. Before adding gameplay mods, open Settings in the current client, choose the language, press OK and quit normally. Reaching the menu alone does not persist the preference. Keep this profile separate from the Steam desktop preferences; do not inject a language key or force Steamworks initialization earlier (`docs/build.md:362-370,587-596`). Here, “preference profile” means native settings storage, not an alternative Pack.

- **Keep game execution inside Unity; keep assertions outside it.** `Lembitu.Harness` advances commands through the plugin's `Update` on Unity's main thread. Python publishes JSON requests and checks observations, not emulated mouse or keyboard input. Activation requires `-lembitu-harness`; command intake also requires an explicit absolute control directory. Dedicated servers remain inert even when the DLL is installed. The protocol uses the Pack's Newtonsoft.Json through JsonDotNET; harness-only installations must include that library too (`src/plugins/Lembitu.Harness/HarnessPlugin.cs:11-26,50-78`; `src/plugins/Lembitu.Harness/HarnessControl.cs:32-40,62-104`; `src/plugins/Lembitu.Harness/Lembitu.Harness.csproj:19`; `docs/build.md:377-384`).

- **Make acceptance repeatable and owned.** `scripts/test-native.py` copies source installations into private working directories, excluding existing plugins, configs, saves and logs. Every repetition has fresh worlds, characters, save directories and IPC. Client storage uses explicit absolute `--save-dir` and `--log-file` paths; the server receives explicit `-savedir` and `-logFile`. Full-Pack mode generates configs in a disposable world, applies the existing enforced-config merger, then starts a separate measured world. Minimal mode installs only the harness and Newtonsoft.Json (`scripts/test-native.py:143-205,338-345,374-409`; `scripts/test-client.sh:107-113`; `docs/build.md:456-463`).

- **Retain evidence without touching the live server.** The coordinator requires a base port of 2480 or higher, checks all three UDP ports before launch, never treats an existing listener as its server, and stops only process groups it created. It preserves proof, events, IPC, installed-file hashes, screenshots, logs and generated configs under `~/.local/state/lembitu/native-tests/`; working copies and saves are removed unless `--keep-work` is used. Keep exact game identities, Pack pins, invocation, host and client/server topology with a result: the dated acceptance record identifies its source/build copy and invocation, while installed hashes identify deployed inputs (`scripts/test-native.py:93-125,179-188,414-435,438-500`; `docs/build.md:469-476,675-702`).

## Exclusions

- **Fixtures are setup, not gameplay proof.** `fixture.spawn` requires explicit launcher opt-in and arranges objects in a disposable world. Prove pickup, material consumption, equipment, movement and attack results separately through native actions. Attacks do not directly grant damage or XP, and the historical native verification did not teleport the player. Commands use observed entity, inventory and button IDs; those IDs cannot be carried across client sessions (`docs/build.md:412-434,478-498`).

- **This is not an unattended licence or settings provisioner.** Supply the authenticated licensed Steam session, initialized native preferences and GPU-backed display before acceptance. Refresh disposable client copies from the current public Steam installation and rebuild against fresh server references; do not modify the live server or historical evidence to make a test work (`docs/build.md:339-370,456-463`).

- **A passing subset cannot stand in for a larger claim.** Minimal mode is diagnostic isolation, never full-Pack acceptance; full-Pack mode does not silently fall back to it. Joining does not prove gameplay, screenshot creation does not prove rendering, and repeated sequential clients do not prove simultaneous two-client behaviour. Inspect the Skills and combat screenshots separately. The September 13 acceptance covers the existing native scenario, not every mod feature, and does not clear the outstanding simultaneous two-client requirement for a launch freeze (`docs/build.md:451-476,663-668,692-706`).

- **IPC files are not a process supervisor.** Use a fresh control directory per launch and one coordinator per directory. Retained `status.json` can describe a previous process. Atomic UUID requests are limited to 16 KiB; responses remain as evidence. A controller timeout does not cancel an already-published command: inspect that UUID's response before retrying. Native refusals must be asserted explicitly rather than counted as successful actions (`scripts/harness.py:94-142`; `docs/build.md:397-440`).

## Transferred rendering comparison (#58)

The per-family rendered-client log-level comparison is accepted for #38. The per-scenario rendered-view comparison belongs to #49 (combat/water) and #52 (generated content/world UI); no such view is claimed to have been produced or compared.

Compare each scenario’s rendered views and corresponding client logs against all nine warning families in the [docs/build.md matrix at the reviewed #38 candidate](https://github.com/rakoort/valheim-lembitu/blob/2a91e6d7bb869ebf830b65ef2ed3ea996341de25/docs/build.md#L351-L361):

1. HDR reflection texture unsupported.
2. `Hidden/VideoDecode` missing, including the five decode passes: `YCbCr_To_RGB1`, `YCbCrA_To_RGBAFull`, `YCbCrA_To_RGBA`, `Flip_RGBA_To_RGBA`, `Flip_RGBASplit_To_RGBA`.
3. `Hidden/VideoComposite` missing, including its `Default` pass, associated zero-pass errors and intro cinematic failure.
4. `Hidden/Dof/DepthOfFieldHdr` unsupported and depth-of-field disabled.
5. `Hidden/SunShaftsComposite` / `Hidden/SimpleClear` unsupported and sun-shafts disabled.
6. AmplifyOcclusion CopyTexture unsupported / CacheAware optimization disabled.
7. AmplifyOcclusion GBuffer normals unavailable / Camera source fallback.
8. `AsyncResourceUpload failed` (asset/cause unestablished; #59 owns diagnosis or reclassification).
9. IMGUI module stripped / `OnGUI` skipped.

Consume the retained full-Pack evidence on astral-bicep at `/home/ra/.local/state/lembitu/native-tests/20260913T154603Z-full-pack-497266e6/`, both `run-1/` and `run-2/`. Compare `gameplay-unity.log` and `client-LogOutput.log` with paired `server-unity.log` and `config-server-unity.log`; the rendered-client comparison also covered `config-client-unity.log`, `no-fixtures-unity.log` and `wrong-password-unity.log`. These dated logs establish log-level separation, not either scenario’s rendered-view result or current Pack clearance.

Retain one comparison row per family, identifying the inspected scenario view, corresponding log evidence and outcome. Mark unexercised or unavailable views explicitly unverified; missing artifacts or zero log matches do not prove visual correctness. Route real client rendering defects to #31. If AsyncResourceUpload appears in rendered-client logs, refer to #59 rather than carrying forward its bounded accepted-noise classification.

## Capture integrity instrument (#56)

Use `scripts/retain-pair.js` for new paired-log captures; the old [.nt/evidence/retain-pair.js](https://github.com/rakoort/valheim-lembitu/blob/2a91e6d7bb869ebf830b65ef2ed3ea996341de25/.nt/evidence/retain-pair.js)
at #38 candidate `2a91e6d7bb869ebf830b65ef2ed3ea996341de25` is historical evidence, not the maintained tool.
After the owned server exits, run `bun /absolute/repo/scripts/retain-pair.js SOURCE_SHA RUN_NAME`
from its workspace. Supply the measured source commit and a new run name. Inputs retain the original layout:
Runtime inputs are [Unity .nt/review-fix-raw/server-unity.log and BepInEx .nt/server/BepInEx/LogOutput.log](../../scripts/retain-pair.js#L27-L30),
and server binaries/config under `.nt/server/`. Bun is required.

The instrument creates a new `.nt/evidence/` directory and refuses an existing one; it never rewrites
old captures. Full-read integrity compares byte length with source sizes before/after reading and checks
file identity and modification metadata. This detects observed source changes, not arbitrary concurrent
rewrites; capture only stopped servers. The other flags measure newline preservation, retained-byte
equality and absence of reader framing. Failed integrity or lifecycle checks produce the capture report
before a nonzero exit; input decoding or I/O failures may abort without a complete report.
`test/retain-pair.test.sh` exercises successful retention, reader framing, real redaction line loss and
refusal to overwrite an earlier bundle. These fixtures prove the instrument, not game rendering.

## EpicMMO panel drag ownership (#62, 2026-09-14)

The three controllers retain separate contracts, as permitted by #62. The per-controller rationale
and live source callers are in [EpicMMOSystem's maintenance notes](../../src/forks/EpicMMOSystem/UPSTREAM.md#panel-drag-ownership-62).
Only comments and documentation changed; no drag implementation, serialized type, setting or caller changed.

Native evidence on astral-tricep is retained under
`/home/ra/.cache/valheim-lembitu/ticket-62-20260914/`. The source base is
`ca45304f1ce1ce2ea610842912ffdfc8c5f5104f`, with the three ownership comments applied before
the measured build. `candidate-binary-identity.sha256` identifies the rebuilt EpicMMOSystem DLL
and both deployed copies; the client copy matched with `cmp`. The real client/server ran
Valheim l-1.0.12/network 40, with the isolated retained #61 Pack and a temporary diagnostic plugin.
`installed-binaries.json` records deployed DLL hashes, including that diagnostic.

`verify.py` produced 16 passing assertions in `verification.json`:

- PointPanel moved from `(0, 0)` to `(-250, -30)`; NavigatePanel moved from `(0, 100)` to `(200, 300)`.
  Settings remained unchanged during drag and matched the new positions at drag end.
- Native screen clamping held NavigatePanel at the top/left and PointPanel at the bottom/right
  of the 1600×900 surface, allowing floating-point rounding below 0.001 pixels.
- Both panels restored nonzero settings after deliberate position perturbation. The default
  restore skipped a zero setting; explicit restore applied zero. Saved positions were then restored.
- After a normal client quit and fresh client launch, both panels reopened at their saved positions.
  This checks client UI-config persistence, not character/world fixture reuse.

The temporary probe invoked the production `OnBeginDrag`, `OnDrag`, `OnEndDrag` and `RestoreWindow`
methods on the live panel components from Unity Update. Pointer coordinates came from the real
client; assertions ran outside Unity. `final-saved.png` and `restarted-restored.png` were visually
inspected: the attributes panel remained readable at its moved position and the navigation bar
remained at its saved location behind it. [native-restore/events.jsonl](ssh://astral-tricep/home/ra/.cache/valheim-lembitu/ticket-62-20260914/native-restore/events.jsonl) retains native quit/exit evidence.

Verification boundaries: injected X button drags did not move the panels. The held-button probe
recorded a focused game, PointPanel raycast hits, `InputSystemUIInputModule`, and legacy
`Input.GetMouseButton(0) == false`. Direct native callback proof does not attest physical mouse
dispatch. Initial runs also exposed missing Python/display tooling and an unprotected character
death; those attempts remain retained, not counted as successful drag evidence. The final probe
enabled god mode solely to isolate UI verification from combat. No HUD-drag, FriendList,
rendering-family, multiplayer or full-Pack acceptance is claimed. Diagnostic sources are retained
in `diagnostic-instrumentation.tar.gz`; the deployed probe and loose diagnostic programs were removed.

## StoneOutlook restoration blocker (#32, 2026-09-14)

MWL 5.1.0 omits the location definition, not an operator setting.
`Prefabs.AddContainerPrefab` derives `MWL_StoneOutlook1` from its loot chest prefab,
then calls `LocationDB.GetLocationConfig`. The native lookup returns null.
`LocationDefinitions.BlackForest` omits StoneOutlook, so the chest registration fails.

A read-only native probe enumerated the three embedded location-prefab bundles.
Their only StoneOutlook asset was
[assets/warpprojects/more world locations/blackforest pack 2/containers/mwl_stoneoutlook1_loot_chest_wood1.prefab](ssh://astral-tricep/home/ra/.cache/valheim-lembitu/ticket-32-20260914/diagnostic-LogOutput.log).
The shipped soft-reference manifest has no StoneOutlook entry. The complete upstream
tree at `5546c481847e3f169e5a22c12b402db8e20c5acf` has no path matching `outlook`;
its location definitions also omit StoneOutlook. These checks do not establish that
an older release could never supply the missing asset.

Historical upstream `e643f76e93a898e343f167cfc50ab72ba46e2aec` retains
`MWL_StoneOutlook1_Config` in the upstream file [More World Locations_AIO/Src/Locations/LocationConfigs.cs](https://github.com/rakoort/valheim-lembitu/issues/32):
Black Forest, Coastal group, minimum distance 500, altitude -2 through 1,
minimum similar-location distance 1024, and slope rotation enabled. That revision
has no Outlook entry in `AssetPaths.cs` or `LocationsNEW.cs`. Commit
`9b4897fa15359477cbab2f804831bc6546c774b0` deleted those legacy files.
Recovering the old config alone does not supply a registered, loadable location.

Evidence lives on astral-tricep under
`/home/ra/.cache/valheim-lembitu/ticket-32-20260914/`:
`diagnostic-console.log`, `diagnostic-LogOutput.log`, `run-ticket32.py`,
`Probe.cs`, `Probe.csproj`, and `diagnostic-saves/`. This is an isolated copy of
the #64 diagnostic installation, with complete MWL content and public Valheim
1.0.12/network 40. It retains earlier diagnostic plugins, including the local
BossRules guard, and adds a read-only asset probe; it is not exact-HEAD Pack acceptance.
The fresh world is `Ticket32Diagnostic`, ports 2506–2508. No client was launched.
The server reached native Steam-listener readiness, then the owned process group
was stopped. The diagnostic assertion failed: `StoneOutlook LocationConfig missing
in native registration`.

Examined SHA-256 identities:

- MWL ZIP: `525c92b337b918782999d4fdec19688f144cf31981a81b0ca5ba3401da56a315`.
- MWL DLL: `6e553376a8b0fa5774d395b79991fe49dd95a47266a37a862239389f426c5f84`.
- Soft-reference manifest: `879003ecd4e9e4a71f752d0948c89bf576e6da57a822211d1d4a105e60cd151c`.

The native probe build succeeded with zero warnings and errors.
**#32 remains blocked, not implemented or accepted.** Restoration needs a recoverable
location asset and registration, or a verified upstream correction. No content was
removed, quantity override invented, or warning suppressed. No StoneOutlook placement,
seed/coordinate pair, client visit or persistence is claimed. After restoration,
run the exact-candidate server generation comparison required by #32; #52 owns the
client visit and reload.

## EpicLoot Graphic dictionary warnings (#36, 2026-09-15)

Retain these three Jotunn warnings without suppressing them or forking either mod.
They concern empty runtime caches, not unresolved UI references. On Valheim
1.0.12/network 40, EpicLoot 0.14.5 supplies all three objects under
`_JotunnRoot/Prefabs/piece_enchantingtable/Disenchant/DisenchantRoot/`:

- `Level2/Particles`
- `Level3/Particles`
- `Level4/Particles`

Each owns `EpicLoot_UnityLib.SetRarityColor._defaultColors`, a private readonly
`Dictionary<Graphic, Color>`. A read-only Harmony probe around Jotunn 2.30.0
`MockManager.FixMemberReferences` observed every dictionary immediately before
and after its warning: all six counts were zero. There were no keys, destroyed
Graphic references or mock references in those dictionaries to resolve.

The exact shipped EpicLoot DLL shows that the field starts empty. `Awake` fills
it from `Graphics`, caching each Graphic’s current colour; `Refresh` uses that
cache when restoring default colours. It is not a dictionary of serialized mock
assets. Jotunn’s [2.30.0 resolver](https://github.com/Valheim-Modding/Jotunn/blob/v2.30.0/JotunnLib/Managers/MockSystem/MockManager.cs#L308-L353)
emits the unsupported-dictionary warning before reading the field value.
The warning therefore does not establish that any entry needs replacement.

Evidence is retained on astral-tricep in
`/home/ra/.cache/valheim-lembitu/ticket-36-20260915/`: native logs,
`verification.json`, `installed-files.json`, `SetRarityColor.cs` and archived
diagnostic instrumentation. The source input is
`ac9f18c81e9a76d93391267f3e91216c34643886`; fresh server references, the complete
build and all 30 locked package hashes were verified. This is an isolated
dedicated-server reference-resolution investigation on ports 2536–2538, not
client or full-Pack gameplay acceptance. The tracked local BossRules guard
remained present; unrelated working-tree deletions were not imported.

The initial copied installation contained an unpinned FastAssetBundleLoader
patcher; that attempt was excluded and the inherited patcher removed from the
owned copy before the measured probe. A separate baseline coordinator watched
the console instead of the explicit Unity log and missed observed listener
readiness; its failed coordinator result is retained, not counted as a pass.

The instrumented run and a fresh uninstrumented replay both reached the native
Steam listener and stopped their owned process groups. Each emitted three
Graphic/Color warnings out of eleven unsupported-dictionary warnings total.
The external verifier checked all three owner paths and six zero-entry counts;
the uninstrumented replay contained no probe log records.

This disposition covers only the three Graphic/Color dictionaries. Other
unsupported dictionaries, including ValheimRAFT’s, are separate observations.
No enchanting UI colours, interactions, hover/selection or reopen behaviour
were exercised; #43 retains that client-state proof. Recheck the actual fields
and entries after either package changes instead of accepting a matching count.

## Lessons

- **Separate accepted log evidence from scenario views.** Under [#38’s September 14 scope amendment](https://github.com/rakoort/valheim-lembitu/issues/38), the per-family rendered-client log-level separation is the accepted required comparison for #38. The per-scenario rendered-view comparison transfers to [#49](https://github.com/rakoort/valheim-lembitu/issues/49) and [#52](https://github.com/rakoort/valheim-lembitu/issues/52), not unfinished #38 acceptance. No #49/#52 view is claimed to have been produced or compared.

- **Prove chainload from the log, then distinguish noise from failure.** Look for the BepInEx banner, plugin loading and its own runtime lines, plus chainloader completion. The recorded Hello probe additionally proves ServerSync RPC registration and a config broadcast without the pre-1.0 `MissingFieldException`; a banner alone does not show that behaviour. The server directory's own `LogOutput.log`, written under its BepInEx tree at runtime, retains the same output. The documented `libParty.so` exception and early `SteamNetworkingUtils004` warning also occur on vanilla dedicated servers; they are not mod-failure evidence. Conversely, `GameServer.Init() failed` followed by `Steam is not initialized` indicates occupied UDP ports in this setup (`docs/build.md:315-335`).

- **Find the display failure before blaming the game stack.** Without Weston's fake seat, Xwayland 24.1.12 aborted in `xwl_cursor_warped_to` when the pointer warped; Valheim's later Bumblelion stack was downstream of losing the display. A disposable-display probe reproduced the crash without Valheim, and adding only `--fake-seat` survived 20 consecutive pointer warps. Default Vulkan also stayed in `loading` with BepInEx disabled, whereas OpenGL reached the menu and native gameplay. This justified `-force-glcore`, not a claim that every bundled mod shader works. On NixOS, the launcher additionally uses `steam-run` when available because launching without its FHS libraries produced missing-libX11/video-device failures (`docs/build.md:339-353`; `scripts/test-client.sh:134-143`).

- **Startup order was not failed Steam authentication.** Clan still failed before joining with the harness and third-party patchers removed. A missing native language preference sent `Localization.SetStartupLanguage` through a preference migration that accessed Steamworks before Valheim initialized it. Controlled profiles with identical binaries isolated the saved-language difference; native Settings initialization was the installed correction. File-open tracing found the effective Linux store at `unity3d/unknown/unknown/prefs`, not the guessed save-directory preferences. The runner still rejects missing generated configs, so recurrence is visible (`docs/build.md:570-607`).

- **Readiness and shutdown must follow native boundaries.** `Game server connected` is Steam registration, before world generation and listener opening. Wait for `Opened Steam server`; the real-child-process regression deliberately holds that second marker back to prove registration cannot release a waiting client. At the other end, a quit acknowledgement precedes Unity finishing saves and unmounting Steam storage. Killing the client immediately after acknowledgement left an already-open storage batch; the coordinator now waits for native process exit, including after failed startup (`scripts/test-native.py:127-140,338-356`; `test/test-native.test.sh:23-67`; `docs/build.md:527-533,611-617`).

- **Separate connection symptoms by controlled comparisons.** After readiness was fixed, the full Pack still stalled during location loading and hit the normal RPC timeout. Removing only client FastAssetBundleLoader or disabling only the SkadiNet stutter guard did not solve it. Removing either MWL or BossRules isolated the interaction: BossRules' pre-sync ServerSync state let a connecting client perform an authority-only reference scan, synchronously loading location prefabs and blocking the main thread. A native server-authority guard corrected the boundary without extending timeouts or removing content. Official BossRules 1.0.10 supplied that predicate, so the temporary local plugin was removed. An initial assertion expecting no client reference file was also wrong: the valid client output is an empty template (`docs/build.md:609-661`).

- **Serialize what the real client actually returns.** Unity's runtime `JsonUtility` omitted nested response state in the first real-client run. The protocol therefore uses Newtonsoft.Json rather than treating missing observations as successful gameplay. This is a runtime finding, not merely a serializer preference (`docs/build.md:379-384`; `src/plugins/Lembitu.Harness/HarnessControl.cs:86-89`).

- **Date acceptance; do not promote old proof into current clearance.** The September 9 chainload log and September 12 minimal-mode results are historical 1.0.7 evidence. Later startup and join failures were separately diagnosed, not retrospectively erased. The September 13 record reports two fresh full-Pack repetitions on public 1.0.12/network 40, retained evidence and separate visual inspection. Residual FastAssetBundleLoader Linux `DriveInfo` exceptions remained in that successful gameplay log; success did not explain them away. That record still excludes exhaustive mod-feature and simultaneous two-client acceptance (`docs/build.md:315-318,478-568,675-706`).
