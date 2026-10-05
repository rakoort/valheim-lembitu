using System;
using System.Collections;
using System.IO;
using BepInEx.Logging;
using Jotunn.Entities;
using Jotunn.Managers;

namespace Lembitu.Guide;

/// <summary>
/// The server reads BepInEx/config/lembitu.guide.md and sends it through Jotunn's initial sync
/// before the player loads, then broadcasts edits. A client never reads a local copy, and content
/// belongs to one network session: disconnecting clears both the pages and the displayed window.
/// </summary>
internal static class ContentSync
{
    public const string ContentFileName = "lembitu.guide.md";
    private const string RpcName = "content";
    private const float PollSeconds = 2f;

    private static ManualLogSource s_log = null!;
    private static string s_file = null!;
    private static CustomRPC s_rpc = null!;
    private static ZNet? s_network;
    private static string? s_served;
    private static DateTime s_lastWrite;
    private static float s_pollTimer;
    private static bool s_missingLogged;

    public static string? Current { get; private set; }
    public static bool HasContent => Current != null;

    public static void Verify(ManualLogSource log)
    {
        s_log = log;
        s_file = Path.Combine(BepInEx.Paths.ConfigPath, ContentFileName);
    }

    public static void Enable()
    {
        s_rpc = NetworkManager.Instance.AddRPC(RpcName, ServerReceive, ClientReceive);
        SynchronizationManager.Instance.AddInitialSynchronization(s_rpc, PackageForPeer);
    }

    public static void Tick(float delta)
    {
        ZNet? network = ZNet.instance;
        if (network == null || !network.enabled)
        {
            if (!ReferenceEquals(s_network, null))
            {
                ClearSession();
            }
            return;
        }
        if (!network.IsServer())
        {
            ZNet.ConnectionStatus status = ZNet.GetConnectionStatus();
            // Initial synchronization arrives during Connecting, before world load.
            if (status != ZNet.ConnectionStatus.Connected && status != ZNet.ConnectionStatus.Connecting)
            {
                if (!ReferenceEquals(s_network, null))
                {
                    ClearSession();
                }
                return;
            }
            StartSession(network);
            return;
        }

        StartSession(network);
        s_pollTimer -= delta;
        if (s_pollTimer > 0f)
        {
            return;
        }
        s_pollTimer = PollSeconds;
        if (LoadFromDisk())
        {
            s_rpc.SendPackage(ZRoutedRpc.Everybody, Package(Current!));
            int peers = ZRoutedRpc.instance == null ? 0 : ZRoutedRpc.instance.m_peers.Count;
            s_log.LogInfo($"Guide content reloaded ({Current!.Length} characters) and sent to {peers} connected peer(s).");
        }
    }

    private static void StartSession(ZNet network)
    {
        if (ReferenceEquals(s_network, network))
        {
            return;
        }
        ClearSession();
        s_network = network;
    }

    private static void ClearSession()
    {
        s_network = null;
        Current = null;
        s_served = null;
        s_lastWrite = default;
        s_pollTimer = 0f;
        s_missingLogged = false;
        GuideContent.Clear();
        GuideWindow.Clear();
    }

    /// <summary>Returns true only when the server loaded new, usable content.</summary>
    private static bool LoadFromDisk()
    {
        if (ZNet.instance == null || !ZNet.instance.IsServer())
        {
            return false;
        }
        try
        {
            FileInfo info = new(s_file);
            if (!info.Exists)
            {
                if (!s_missingLogged)
                {
                    s_log.LogWarning($"Guide content file {s_file} is missing; deploy it to supply the server's pages.");
                    s_missingLogged = true;
                }
                return false;
            }
            s_missingLogged = false;
            if (info.LastWriteTime == s_lastWrite && s_served != null)
            {
                return false;
            }
            s_lastWrite = info.LastWriteTime;
            string text = File.ReadAllText(s_file);
            if (text == s_served)
            {
                return false;
            }
            s_served = text;
            if (!GuideContent.Load(text))
            {
                return false;
            }
            Current = text;
            return true;
        }
        catch (Exception error)
        {
            s_log.LogWarning($"Guide content could not be read: {error.Message}");
            return false;
        }
    }

    private static ZPackage? PackageForPeer(ZNetPeer peer)
    {
        ZNet? network = ZNet.instance;
        if (network == null || !network.IsServer())
        {
            return null;
        }
        StartSession(network);
        LoadFromDisk();
        return Current == null ? null : Package(Current);
    }

    private static ZPackage Package(string content)
    {
        ZPackage package = new();
        package.Write(content);
        return package;
    }

    /// <summary>Clients cannot publish content to the server.</summary>
    private static IEnumerator ServerReceive(long sender, ZPackage package)
    {
        yield break;
    }

    private static IEnumerator ClientReceive(long sender, ZPackage package)
    {
        ZNet? network = ZNet.instance;
        if (network == null || network.IsServer())
        {
            yield break;
        }
        StartSession(network);
        string text = package.ReadString();
        if (GuideContent.Load(text))
        {
            Current = text;
            GuideWindow.OnContentChanged();
        }
    }
}
