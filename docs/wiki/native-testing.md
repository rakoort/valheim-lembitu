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

## Retired diagnostic scopes — 2026-09-15

Three sections that lived here are gone with the work they described (ADR-0010).

The transferred rendering comparison (#58) existed to route nine client warning families through
per-scenario views owned by the cancelled single-client scenario tickets. Those tickets are closed,
and the families themselves are vanilla headless noise on this stack: the `Hidden/VideoDecode` and
`Hidden/VideoComposite` material and pass errors, the failed intro cinematic, the HDR reflection
warning, the shader and occlusion fallbacks. Only `AsyncResourceUpload failed` remains
unexplained, and #59 owns it.

The EpicMMO panel-drag ownership record (#62) and the StoneOutlook restoration blocker (#32)
described code and content that are no longer in the pack: the EpicMMOSystem fork is retired in
favour of upstream 1.9.67, and More World Locations AIO is cut. Their retained evidence stays on
astral-tricep under `/home/ra/.cache/valheim-lembitu/ticket-62-20260914/` and
`ticket-32-20260914/` for anyone re-treading that ground.

One measurement from the StoneOutlook work is worth carrying: a location a mod registers can be
missing from the mod's own definitions rather than from an operator setting, and a shipped
soft-reference manifest is the place to check that before assuming a configuration mistake.

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

- **Separate accepted log evidence from rendered views.** The per-family rendered-client log-level separation was the accepted comparison for #38. The per-scenario rendered-view work it transferred to is cancelled with the scenario tickets (ADR-0010), and no such view was ever produced. A log-level separation is not a rendering result, then or now.

- **Prove chainload from the log, then distinguish noise from failure.** Look for the BepInEx banner, plugin loading and its own runtime lines, plus chainloader completion. The retired Hello probe proved ServerSync RPC registration and a config broadcast without the pre-1.0 `MissingFieldException`; with no plugin of ours synchronising config, a clean chainload plus each mod's own runtime lines is what the log can now show, and a banner alone shows neither. The server directory's own `LogOutput.log`, written under its BepInEx tree at runtime, retains the same output. The documented `libParty.so` exception and early `SteamNetworkingUtils004` warning also occur on vanilla dedicated servers; they are not mod-failure evidence. Conversely, `GameServer.Init() failed` followed by `Steam is not initialized` indicates occupied UDP ports in this setup (`docs/build.md:315-335`).

- **Find the display failure before blaming the game stack.** Without Weston's fake seat, Xwayland 24.1.12 aborted in `xwl_cursor_warped_to` when the pointer warped; Valheim's later Bumblelion stack was downstream of losing the display. A disposable-display probe reproduced the crash without Valheim, and adding only `--fake-seat` survived 20 consecutive pointer warps. Default Vulkan also stayed in `loading` with BepInEx disabled, whereas OpenGL reached the menu and native gameplay. This justified `-force-glcore`, not a claim that every bundled mod shader works. On NixOS, the launcher additionally uses `steam-run` when available because launching without its FHS libraries produced missing-libX11/video-device failures (`docs/build.md:339-353`; `scripts/test-client.sh:134-143`).

- **Startup order was not failed Steam authentication.** Clan still failed before joining with the harness and third-party patchers removed. A missing native language preference sent `Localization.SetStartupLanguage` through a preference migration that accessed Steamworks before Valheim initialized it. Controlled profiles with identical binaries isolated the saved-language difference; native Settings initialization was the installed correction. File-open tracing found the effective Linux store at `unity3d/unknown/unknown/prefs`, not the guessed save-directory preferences. The runner still rejects missing generated configs, so recurrence is visible (`docs/build.md:570-607`).

- **Readiness and shutdown must follow native boundaries.** `Game server connected` is Steam registration, before world generation and listener opening. Wait for `Opened Steam server`; the real-child-process regression deliberately holds that second marker back to prove registration cannot release a waiting client. At the other end, a quit acknowledgement precedes Unity finishing saves and unmounting Steam storage. Killing the client immediately after acknowledgement left an already-open storage batch; the coordinator now waits for native process exit, including after failed startup (`scripts/test-native.py:127-140,338-356`; `test/test-native.test.sh:23-67`; `docs/build.md:527-533,611-617`).

- **Separate connection symptoms by controlled comparisons.** After readiness was fixed, the full Pack still stalled during location loading and hit the normal RPC timeout. Removing only client FastAssetBundleLoader or disabling only the SkadiNet stutter guard did not solve it. Removing either the location pack or the boss-rules mod isolated the interaction: a pre-sync ServerSync state let a connecting client perform an authority-only reference scan, synchronously loading location prefabs and blocking the main thread. Both of those mods have since been cut (ADR-0010), which removes the interaction rather than explaining it away. The method is the lesson: a join stall is diagnosed by removing one mod at a time, not by raising timeouts.

- **Serialize what the real client actually returns.** Unity's runtime `JsonUtility` omitted nested response state in the first real-client run. The protocol therefore uses Newtonsoft.Json rather than treating missing observations as successful gameplay. This is a runtime finding, not merely a serializer preference (`docs/build.md:379-384`; `src/plugins/Lembitu.Harness/HarnessControl.cs:86-89`).

- **Date acceptance; do not promote old proof into current clearance.** The September 9 chainload log and September 12 minimal-mode results are historical 1.0.7 evidence. Later startup and join failures were separately diagnosed, not retrospectively erased. The September 13 record reports two fresh full-Pack repetitions on public 1.0.12/network 40, retained evidence and separate visual inspection. Residual FastAssetBundleLoader Linux `DriveInfo` exceptions remained in that successful gameplay log; success did not explain them away. That record still excludes exhaustive mod-feature and simultaneous two-client acceptance (`docs/build.md:315-318,478-568,675-706`).
