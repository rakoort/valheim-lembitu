using System;
using System.Collections;
using System.Linq;
using BepInEx;
using BepInEx.Logging;
using UnityEngine;
using UnityEngine.Rendering;

namespace Lembitu.Harness;

/// <summary>
/// Joins a real game client and exposes opt-in native gameplay commands and observations.
/// Scenario assertions live in the external controller, not in these session reports. Inert
/// without <c>-lembitu-harness</c> and always inert on dedicated servers. File control additionally
/// requires an explicit absolute <c>-lembitu-control-dir</c>.
///
/// Character creation and joining use the same engine paths as the menu. Commands execute on
/// Unity's main thread after a local player has spawned; quit remains available during startup.
/// </summary>
[BepInPlugin(PluginInfo.Guid, PluginInfo.Name, PluginInfo.Version)]
public sealed class HarnessPlugin : BaseUnityPlugin
{
    private static ManualLogSource log = null!;
    private HarnessControl? control;

    private void Update() => control?.Tick();
    private void OnDestroy() => control?.Stop();

    private IEnumerator GuardedPlay(string server, string password, string character)
    {
        IEnumerator play = Play(server, password, character);
        while (true)
        {
            object current;
            try
            {
                if (!play.MoveNext()) yield break;
                current = play.Current;
            }
            catch (Exception error)
            {
                log.LogError(error);
                control?.Fail(error.ToString());
                yield break;
            }
            yield return current;
        }
    }
    /// <summary>Everything the harness does, one phase per log line.</summary>
    private void Awake()
    {
        log = BepInEx.Logging.Logger.CreateLogSource(PluginInfo.Name);

        if (SystemInfo.graphicsDeviceType == GraphicsDeviceType.Null)
        {
            // A dedicated server. dist/ carries this DLL everywhere, so the guard matters.
            log.LogInfo("idle: dedicated server has no client to drive");
            return;
        }

        if (!Argument("-lembitu-harness"))
        {
            log.LogInfo("idle: launch the client with -lembitu-harness to activate");
            return;
        }

        string server = Option("-lembitu-server", "127.0.0.1:2466");
        string password = Option("-lembitu-password", "");
        string character = Option("-lembitu-character", "harness");

        try
        {
            string directory = Option("-lembitu-control-dir", "");
            if (directory.Length > 0) control = new HarnessControl(directory, Argument("-lembitu-fixtures"), log);
            log.LogInfo($"active: will join {server} as '{character}'");
            StartCoroutine(GuardedPlay(server, password, character));
        }
        catch (Exception error) { log.LogError(error); control?.Fail(error.ToString()); }
    }

    private IEnumerator Play(string server, string password, string character)
    {
        // ---- main menu ---------------------------------------------------------------------
        float startupDeadline = Time.realtimeSinceStartup + 120f;
        while (FejdStartup.instance == null)
        {
            if (Time.realtimeSinceStartup >= startupDeadline) throw new TimeoutException($"main menu singleton did not appear; {Progress()}");
            yield return null;
        }

        // The intro cinematic hides the menu, and on a headless client it can sit there. The
        // game's own join path stops it the same way.
        if (CinematicsManager.IsStartedPlaying())
        {
            log.LogInfo("stopping the intro cinematic");
            CinematicsManager.Stop();
        }

        // Bounded, and it proceeds either way: the menu object being active is a nice signal, not
        // a prerequisite, and hanging here is what a harness must never do.
        float menuDeadline = Time.realtimeSinceStartup + 120f;
        while (!(FejdStartup.instance.m_mainMenu != null && FejdStartup.instance.m_mainMenu.activeInHierarchy)
               && Time.realtimeSinceStartup < menuDeadline)
        {
            yield return null;
        }

        log.LogInfo(FejdStartup.instance.m_mainMenu != null && FejdStartup.instance.m_mainMenu.activeInHierarchy
            ? "main menu up"
            : "main menu never activated; going ahead anyway");

        // The menu waits for a click that is never coming. OnStartGame is the Start button's own
        // handler: it opens character selection, and opens the new-character panel when there is
        // no profile yet. The preview character the creation path needs only exists after this.
        FejdStartup.instance.OnStartGame();

        float selectDeadline = Time.realtimeSinceStartup + 120f;
        while (!(FejdStartup.instance.m_characterSelectScreen != null
                 && FejdStartup.instance.m_characterSelectScreen.activeInHierarchy)
               && Time.realtimeSinceStartup < selectDeadline)
        {
            yield return null;
        }

        if (FejdStartup.instance.m_characterSelectScreen == null
            || !FejdStartup.instance.m_characterSelectScreen.activeInHierarchy)
        {
            throw new TimeoutException("character selection never opened");
        }

        yield return new WaitForSecondsRealtime(2f);
        log.LogInfo("character selection open");

        // ---- character ---------------------------------------------------------------------
        if (PlayerProfile.HaveProfile(character))
        {
            log.LogInfo($"character '{character}' already exists");
        }
        else
        {
            FejdStartup.instance.m_csNewCharacterName.text = character;
            FejdStartup.instance.OnNewCharacterDone(forceLocal: true);
            if (!PlayerProfile.HaveProfile(character))
            {
                throw new InvalidOperationException($"character '{character}' was not created");
            }

            log.LogInfo($"character '{character}' created and saved");
        }

        // ---- join --------------------------------------------------------------------------
        // Not FejdStartup.JoinServer(): that asks matchmaking about the server first, and a
        // dedicated test server started with -public 0 is not in any server list, so it is judged
        // unjoinable and the attempt never reaches a socket. These four calls are what
        // JoinServer() itself does once its checks pass (FejdStartup.JoinServer, the
        // ServerJoinDataType.Dedicated branch), with the address resolved here instead of through
        // an async matchmaking lookup.
        string host = server;
        int port = 2456;
        int colon = server.LastIndexOf(':');
        if (colon > 0 && int.TryParse(server.Substring(colon + 1), out int parsed))
        {
            host = server.Substring(0, colon);
            port = parsed;
        }

        FejdStartup.ServerPassword = password;
        FejdStartup.instance.SelectCharacter(character, global::FileHelpers.FileSource.Local);
        ZNet.SetServer(server: false, openServer: false, publicServer: false, "", "", null);
        ZNet.ResetServerHost();
        ZNet.SetServerHost(host, port, OnlineBackendType.Steamworks);
        log.LogInfo($"joining {host}:{port} as '{character}'");
        FejdStartup.instance.TransitionToMainScene();

        // ---- in world ----------------------------------------------------------------------
        // A refused client is told so on the connection-failed panel; a connected one gets a
        // local player. Both are waited on, because waiting for the player alone cannot tell
        // "slow" from "rejected". The budget is generous on purpose: this pack loads 266 files of
        // locations and a few hundred asset bundles, and a software-rendered client on a virtual
        // display took eight minutes to reach the world on its first run.
        const float joinBudget = 1200f;
        float started = Time.realtimeSinceStartup;
        float nextUpdate = started + 30f;
        while (Player.m_localPlayer == null || Player.m_localPlayer.InCutscene()
               || Player.m_localPlayer.IsTeleporting() || Player.m_localPlayer.IsDead())
        {
            ZNet.ConnectionStatus connection = ZNet.GetConnectionStatus();
            if (connection is not (ZNet.ConnectionStatus.None or ZNet.ConnectionStatus.Connecting or ZNet.ConnectionStatus.Connected))
                throw new InvalidOperationException($"join failed: {connection}");
            GameObject? failed = FejdStartup.instance?.m_connectionFailedPanel;
            if (failed != null && failed.activeInHierarchy)
            {
                string reason = FejdStartup.instance?.m_connectionFailedError?.text ?? "(no message)";
                throw new InvalidOperationException($"join refused: {reason}");
            }

            if (Time.realtimeSinceStartup - started > joinBudget)
            {
                throw new TimeoutException($"client not playable after {joinBudget:F0}s; {Progress()}");
            }

            if (Time.realtimeSinceStartup > nextUpdate)
            {
                nextUpdate = Time.realtimeSinceStartup + 30f;
                log.LogInfo($"waiting, {Time.realtimeSinceStartup - started:F0}s in: {Progress()}");
            }

            yield return null;
        }

        log.LogInfo($"playable after {Time.realtimeSinceStartup - started:F0}s");

        yield return new WaitForSecondsRealtime(5f);
        Report();
        control?.Ready();
        log.LogInfo("harness ready; client left running");
    }

    /// <summary>Where the join has got to, for the one line that says why it is still waiting.</summary>
    private static string Progress()
    {
        string net = ZNet.instance == null
            ? "ZNet absent"
            : $"ZNet up, {ZNet.instance.GetPeers().Count} peer(s)";
        string zones = ZoneSystem.instance == null ? "no zone system" : "zone system up";
        string scene = ZNetScene.instance == null ? "no scene" : "scene up";
        UnityEngine.SceneManagement.Scene active = UnityEngine.SceneManagement.SceneManager.GetActiveScene();
        string roots = active.IsValid() && active.isLoaded
            ? string.Join(", ", active.GetRootGameObjects().Select(root => root.name))
            : "not loaded";
        return $"{net}; {zones}; {scene}; active scene {active.name} [{roots}]; focused {Application.isFocused}";
    }

    /// <summary>Everything the session state proves, in one block.</summary>
    private static void Report()
    {
        Player player = Player.m_localPlayer;
        if (player == null)
        {
            log.LogWarning("report skipped: no local player");
            return;
        }

        string knownTexts = player.m_knownTexts is { Count: > 0 }
            ? string.Join(", ", player.m_knownTexts.Keys.OrderBy(k => k).Take(20))
            : "none";

        log.LogInfo(
            $"session: player '{player.GetPlayerName()}' at {player.transform.position}, " +
            $"inventory {player.GetInventory().GetAllItems().Count} item(s), " +
            $"server peers {(ZNet.instance == null ? "?" : ZNet.instance.GetPeers().Count.ToString())}, " +
            $"known texts: {knownTexts}");

        // The MMO system stores level and XP here on first spawn. Absent keys mean it never
        // initialised this character — the first thing #10 would want to know.
        if (player.m_knownTexts != null)
        {
            foreach (string key in new[] { "EpicMMOSystem_LevelSystem_Level", "EpicMMOSystem_LevelSystem_CurrentExp" })
            {
                string value = player.m_knownTexts.TryGetValue(key, out string v) ? v : "(absent)";
                log.LogInfo($"  {key} = {value}");
            }
        }
    }

    private static bool Argument(string name) => Environment.GetCommandLineArgs().Contains(name, StringComparer.Ordinal);

    private static string Option(string name, string fallback)
    {
        string[] args = Environment.GetCommandLineArgs();
        int i = Array.IndexOf(args, name);
        return i >= 0 && i + 1 < args.Length ? args[i + 1] : fallback;
    }
}
