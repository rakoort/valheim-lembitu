using System;
using System.Linq;
using BepInEx;
using UnityEngine;

namespace Lembitu.Updater;

/// <summary>Keeps the player's Pack current. At start it checks GitHub for a newer Pack, downloads
/// only the files that changed and stages them; the Lembitu.Updater.Patcher in BepInEx/patchers
/// installs them at the next start, before any mod loads. Client only, and it patches nothing in
/// the game.</summary>
[BepInPlugin(PluginInfo.Guid, PluginInfo.Name, PluginInfo.Version)]
public sealed class UpdaterPlugin : BaseUnityPlugin
{
    internal const string Releases = "https://api.github.com/repos/rakoort/valheim-lembitu/releases?per_page=50";
    private readonly Notice notice = new();
    private GUIStyle? style;

    private void Awake()
    {
        if (Application.isBatchMode)
        {
            Logger.LogInfo("Pack updates: off on a dedicated server");
            return;
        }
        // Tests point the updater at a local release feed; a harness session without one must not
        // download real releases into a disposable test install.
        string feed = Environment.GetEnvironmentVariable("LEMBITU_UPDATE_FEED") ?? "";
        if (feed.Length == 0 && Environment.GetCommandLineArgs().Contains("-lembitu-harness"))
        {
            Logger.LogInfo("Pack updates: off in a harness session without LEMBITU_UPDATE_FEED");
            return;
        }
        Logger.LogInfo("Pack updates: on" + (feed.Length == 0 ? "" : " (feed " + feed + ")"));
        StartCoroutine(new PackUpdater(feed.Length == 0 ? Releases : feed, Logger, notice).Run());
    }

    // The main menu shows the notice; in game the same news arrives once as a top-left message.
    private void OnGUI()
    {
        if (notice.Text.Length == 0 || FejdStartup.instance == null) return;
        if (notice.Until > 0 && Time.realtimeSinceStartup > notice.Until)
        {
            notice.Text = "";
            return;
        }
        style ??= new GUIStyle(GUI.skin.box) { fontSize = 20, wordWrap = true, alignment = TextAnchor.MiddleCenter, padding = new RectOffset(18, 18, 14, 14) };
        float width = Mathf.Min(760f, Screen.width - 40f);
        float height = style.CalcHeight(new GUIContent(notice.Text), width) + (notice.Quit ? 48f : 0f);
        GUILayout.BeginArea(new Rect((Screen.width - width) / 2f, 24f, width, height));
        GUILayout.Box(notice.Text, style, GUILayout.Width(width));
        if (notice.Quit && GUILayout.Button("Quit Valheim", GUILayout.Height(40f))) Application.Quit();
        GUILayout.EndArea();
    }
}

/// <summary>What the player is told about the update, and for how long.</summary>
internal sealed class Notice
{
    internal string Text = "";
    internal bool Quit;
    internal float Until;

    internal void Progress(string text) => Set(text, quit: false, seconds: 0, inGame: false);
    internal void Ready(string label) =>
        Set($"Lembitu Pack {label} is downloaded. Restart Valheim to install it.", quit: true, seconds: 0, inGame: true);
    internal void Done(string text) => Set(text, quit: false, seconds: 20, inGame: false);
    internal void Fail(string text) => Set(text, quit: false, seconds: 0, inGame: true);

    private void Set(string text, bool quit, float seconds, bool inGame)
    {
        Text = text;
        Quit = quit;
        Until = seconds > 0 ? Time.realtimeSinceStartup + seconds : 0;
        if (inGame && Player.m_localPlayer != null && MessageHud.instance != null)
            MessageHud.instance.ShowMessage(MessageHud.MessageType.TopLeft, text);
    }
}
