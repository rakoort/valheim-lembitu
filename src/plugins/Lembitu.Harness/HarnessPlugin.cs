using System;
using System.Collections;
using System.IO;
using System.Linq;
using BepInEx;
using BepInEx.Logging;
using UnityEngine;
using UnityEngine.Rendering;

namespace Lembitu.Harness;

/// <summary>
/// Drives a real game client from code, so the playtest criteria that need a client (#10) become
/// assertions in a log instead of keystrokes a human has to press. Inert unless the client is
/// launched with <c>-lembitu-harness</c>: without it — and on any dedicated server, where the
/// plugin is installed alongside everything else in <c>dist/</c> — it logs one line and does
/// nothing.
///
/// The flow is the game's own: wait for the main menu, create a character through
/// <see cref="FejdStartup.OnNewCharacterDone" /> if none exists, then
/// <see cref="FejdStartup.SetServerToJoin" /> + <see cref="FejdStartup.JoinServer" /> — the same
/// members vanilla's <c>-joinserverwithcharacter</c> argument drives. What happens after spawn is
/// the part no headless server can reach: <see cref="Player.m_localPlayer" />, its inventory, and
/// the character-save keys the MMO system writes.
/// </summary>
[BepInPlugin(PluginInfo.Guid, PluginInfo.Name, PluginInfo.Version)]
public sealed class HarnessPlugin : BaseUnityPlugin
{
    private static ManualLogSource log = null!;

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

        log.LogInfo($"active: will join {server} as '{character}'");
        StartCoroutine(Play(server, password, character));
    }

    private IEnumerator Play(string server, string password, string character)
    {
        // ---- main menu ---------------------------------------------------------------------
        yield return new WaitUntil(() => FejdStartup.instance != null
                                       && FejdStartup.instance.m_mainMenu != null
                                       && FejdStartup.instance.m_mainMenu.activeInHierarchy);
        log.LogInfo("main menu up");

        // The menu waits for a click that is never coming. OnStartGame is the Start button's own
        // handler: it opens character selection, and opens the new-character panel when there is
        // no profile yet. The preview character the creation path needs only exists after this.
        FejdStartup.instance.OnStartGame();

        yield return new WaitUntil(() => FejdStartup.instance.m_characterSelectScreen != null
                                       && FejdStartup.instance.m_characterSelectScreen.activeInHierarchy);
        yield return new WaitForSeconds(2f);
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
                log.LogError($"character '{character}' was not created; stopping");
                yield break;
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
        while (Player.m_localPlayer == null)
        {
            GameObject failed = FejdStartup.instance?.m_connectionFailedPanel;
            if (failed != null && failed.activeInHierarchy)
            {
                string reason = FejdStartup.instance.m_connectionFailedError?.text ?? "(no message)";
                log.LogError($"join refused: {reason}");
                yield break;
            }

            if (Time.realtimeSinceStartup - started > joinBudget)
            {
                log.LogError($"no local player after {joinBudget:F0}s; {Progress()}");
                yield break;
            }

            if (Time.realtimeSinceStartup > nextUpdate)
            {
                nextUpdate = Time.realtimeSinceStartup + 30f;
                log.LogInfo($"waiting, {Time.realtimeSinceStartup - started:F0}s in: {Progress()}");
            }

            yield return null;
        }

        log.LogInfo($"spawned after {Time.realtimeSinceStartup - started:F0}s");

        yield return new WaitForSeconds(5f);
        Report();

        // Give a human a window to look at the screen, then leave the client running: a second
        // look costs nothing and shutting down is the run script's call.
        yield return new WaitForSeconds(120f);
        Report();
        log.LogInfo("harness done; client left running");
    }

    /// <summary>Where the join has got to, for the one line that says why it is still waiting.</summary>
    private static string Progress()
    {
        string net = ZNet.instance == null
            ? "ZNet absent"
            : $"ZNet up, {ZNet.instance.GetPeers().Count} peer(s)";
        string zones = ZoneSystem.instance == null ? "no zone system" : "zone system up";
        string scene = ZNetScene.instance == null ? "no scene" : "scene up";
        return $"{net}; {zones}; {scene}";
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
