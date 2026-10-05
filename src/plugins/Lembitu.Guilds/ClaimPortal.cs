using System;
using System.Collections.Generic;
using System.Globalization;
using BepInEx.Logging;
using HarmonyLib;
using Jotunn.Managers;
using UnityEngine;
using UnityEngine.Events;
using UnityEngine.UI;
using North = global::Guilds;
using Spawns = global::SeparateSpawns;

namespace Lembitu.Guilds;

/// <summary>
/// The claim at the portal (ADR-0028): a guild leader whose guild holds no region, using an
/// unclaimed region's portal stone in the ring around the sacrificial stones, gets a confirmation
/// window naming the region and showing where it lies. Confirming asks the server, which validates
/// leader, region-free and one-region-per-guild before it stores the claim, moves the guild's
/// online members into the region's group and tells the clients. Everyone else using those stones
/// still gets SeparateSpawns' own answer; claimed portals retain its activation and travel flow.
/// </summary>
internal static class ClaimPortal
{
    private const string ClaimRpc = "lembitu.guilds ClaimRegion";
    private const string ResultRpc = "lembitu.guilds ClaimResult";
    private const string AnnounceRpc = "lembitu.guilds Claimed";
    private const string Guide = " Guide: Guilds, parties and the Market (groups).";

    /// <summary>Whether the claim feature's patch is on (verified at startup).</summary>
    public static bool ClaimOn;

    private static ManualLogSource s_log = null!;
    private static GameObject? s_window;
    private static bool s_blockingInput;
    private static string s_region = "";

    public static void Configure(ManualLogSource log) => s_log = log;

    public static IEnumerable<PatchPlan> Plan()
    {
        var interact = Hooks.Method(typeof(TeleportWorld), nameof(TeleportWorld.Interact),
            new[] { typeof(Humanoid), typeof(bool), typeof(bool) }, typeof(bool));
        Hooks.Method(typeof(Spawns.GroupPortalMarker), nameof(Spawns.GroupPortalMarker.AttachFromZdoIfNeeded),
            new[] { typeof(GameObject) }, typeof(Spawns.GroupPortalMarker));
        Hooks.Field(typeof(Spawns.GroupPortalMarker), nameof(Spawns.GroupPortalMarker.IsSpawnEnd), typeof(bool));
        Hooks.Field(typeof(Spawns.GroupPortalMarker), nameof(Spawns.GroupPortalMarker.GroupName), typeof(string));
        // The window's client-side hint reads Guilds' own synced state; the server re-checks every rule.
        Hooks.Field(typeof(North.GuildClient), nameof(North.GuildClient.HasData), typeof(bool));
        Hooks.Field(typeof(North.GuildClient), nameof(North.GuildClient.InGuild), typeof(bool));
        Hooks.Property(typeof(North.GuildClient), nameof(North.GuildClient.MyRank), typeof(int));
        Hooks.Method(typeof(Spawns.GroupSpawnResolver), nameof(Spawns.GroupSpawnResolver.GetGroupForLocalPlayer), Type.EmptyTypes, typeof(string));
        Hooks.Property(typeof(Spawns.Plugin), nameof(Spawns.Plugin.Roster), typeof(Spawns.GroupRoster));
        Hooks.Property(typeof(Spawns.GroupRoster), nameof(Spawns.GroupRoster.Groups), typeof(Dictionary<string, Spawns.GroupEntry>));
        Hooks.Property(typeof(Spawns.GroupEntry), nameof(Spawns.GroupEntry.Players), typeof(List<string>));
        // Where the region lies comes from SeparateSpawns' synced layout.
        Hooks.Property(typeof(Spawns.Plugin), nameof(Spawns.Plugin.LayoutCache), typeof(Spawns.WorldLayoutCache));
        Hooks.Property(typeof(Spawns.WorldLayoutCache), nameof(Spawns.WorldLayoutCache.Current), typeof(Spawns.WorldLayoutData));
        Hooks.Field(typeof(Spawns.WorldLayoutData), nameof(Spawns.WorldLayoutData.GroupSpawnPositions), typeof(Dictionary<string, Vector3>));
        Hooks.Field(typeof(Spawns.WorldLayoutData), nameof(Spawns.WorldLayoutData.SacrificialStonesPosition), typeof(Vector3));
        // First, ahead of SeparateSpawns' own Interact prefix (priority 400): an eligible leader claims
        // a free region even if an earlier guild activated its portal. Ownership and activation differ.
        yield return new PatchPlan(interact) { Prefix = Hooks.Patch(typeof(ClaimPortal), nameof(InteractPrefix), Priority.First) };
    }

    // ----- the interaction, client side

    private static bool InteractPrefix(TeleportWorld __instance, Humanoid human, bool hold, ref bool __result)
    {
        if (hold || !Settings.Enabled || !ClaimOn)
        {
            return true;
        }
        if (Player.m_localPlayer == null || human as Player != Player.m_localPlayer)
        {
            return true;
        }
        try
        {
            Spawns.GroupPortalMarker? marker = Spawns.GroupPortalMarker.AttachFromZdoIfNeeded(__instance.gameObject);
            if (marker == null || marker.IsSpawnEnd)
            {
                return true; // vanilla portals and SeparateSpawns' own activation flow
            }
            if (!LeaderWindowEligible() || Spawns.GroupSpawnResolver.GetGroupForLocalPlayer() != null)
            {
                return true; // ineligible leaders and members keep SeparateSpawns' own message
            }
            Spawns.GroupRoster? roster = Spawns.Plugin.Roster;
            if (roster == null || !roster.Groups.TryGetValue(marker.GroupName, out Spawns.GroupEntry? group)
                || group?.Players == null || group.Players.Count != 0)
            {
                return true; // already claimed (or not synced); the server still validates confirmation
            }
            Open(marker.GroupName);
            __result = false;
            return false;
        }
        catch (Exception error)
        {
            s_log.LogError($"lembitu.guilds: portal claim check failed: {error}");
            return true;
        }
    }

    /// <summary>The client-side hint that the window may open; the server re-checks every rule.</summary>
    private static bool LeaderWindowEligible()
    {
        return North.GuildClient.HasData && North.GuildClient.InGuild && North.GuildClient.MyRank == 0;
    }

    // ----- the window

    private static void Open(string region)
    {
        Close();
        s_region = region;
        GameObject panel = GUIManager.Instance.CreateWoodpanel(GUIManager.CustomGUIFront.transform,
            new Vector2(0.5f, 0.5f), new Vector2(0.5f, 0.5f), Vector2.zero, 560f, 330f);
        panel.name = "LembituGuildsClaim";
        s_window = panel;
        GUIManager.BlockInput(true);
        s_blockingInput = true;

        Text title = Text(panel.transform, $"Claim the {region} start region", 26,
            GUIManager.Instance.ValheimOrange, GUIManager.Instance.NorseBold, TextAnchor.UpperCenter);
        Place(title.gameObject, 20f, 18f, 520f, 42f);
        Text body = Text(panel.transform, Body(region), 17,
            GUIManager.Instance.ValheimBeige, GUIManager.Instance.AveriaSerif, TextAnchor.UpperLeft);
        Place(body.gameObject, 30f, 74f, 500f, 160f);
        ClaimButton($"Claim {region}", 50f, Confirm);
        ClaimButton("Cancel", 290f, Cancel);
    }

    private static string Body(string region)
    {
        return $"{region} lies {Where(region)}.\n\n" +
               $"Claiming makes {region} your guild's home: members wake and respawn there while they have no bed, and its portal answers to them. One region per guild, first come, first served. A bed always overrides it.";
    }

    /// <summary>Where the region sits, from SeparateSpawns' synced layout: wind and distance from the stones.</summary>
    private static string Where(string region)
    {
        try
        {
            Spawns.WorldLayoutData? layout = Spawns.Plugin.LayoutCache?.Current;
            if (layout != null
                && layout.GroupSpawnPositions.TryGetValue(region, out Vector3 spawn)
                && layout.SacrificialStonesPosition != Vector3.zero)
            {
                Vector3 delta = spawn - layout.SacrificialStonesPosition;
                float km = new Vector2(delta.x, delta.z).magnitude / 1000f;
                return $"{Compass(delta)} of the sacrificial stones, {km.ToString("0.0", CultureInfo.InvariantCulture)} km out";
            }
        }
        catch
        {
            // The layout has not arrived; say so instead of guessing.
        }
        return "in the lands around the stones (this client has not been told how far yet)";
    }

    /// <summary>Sixteen-wind bearing from the stones. +x is east and north is -z, as on the map.</summary>
    private static string Compass(Vector3 delta)
    {
        string[] winds =
        {
            "north", "north-north-east", "north-east", "east-north-east", "east", "east-south-east",
            "south-east", "south-south-east", "south", "south-south-west", "south-west", "west-south-west",
            "west", "west-north-west", "north-west", "north-north-west",
        };
        float bearing = Mathf.Repeat(Mathf.Atan2(delta.x, -delta.z) * Mathf.Rad2Deg, 360f);
        return winds[Mathf.RoundToInt(bearing / 22.5f) % winds.Length];
    }

    private static void ClaimButton(string label, float x, System.Action onClick)
    {
        GameObject go = GUIManager.Instance.CreateButton(label, s_window!.transform, new Vector2(0f, 1f),
            new Vector2(0f, 1f), Vector2.zero, 220f, 42f);
        Place(go, x, 250f, 220f, 42f);
        Button button = go.GetComponent<Button>();
        button.onClick.AddListener(new UnityAction(onClick));
    }

    private static void Confirm()
    {
        string region = s_region;
        Close();
        if (ZRoutedRpc.instance == null || ZNet.instance == null)
        {
            return;
        }
        long server = ZNet.instance.IsServer() ? ZDOMan.GetSessionID() : ZNet.instance.GetServerPeer()?.m_uid ?? 0;
        if (server == 0)
        {
            return;
        }
        ZRoutedRpc.instance.InvokeRoutedRPC(server, ClaimRpc, region);
        s_log.LogInfo($"lembitu.guilds: asking to claim the {region} start region.");
    }

    private static void Cancel() => Close();

    /// <summary>Escape, menus, death or a gone player close the window, the way the guild window closes.</summary>
    public static void ClientTick()
    {
        if (s_window == null)
        {
            return;
        }
        Player? player = Player.m_localPlayer;
        if (player == null || player.IsDead()
            || ZInput.GetKeyDown(KeyCode.Escape, logWarning: false)
            || Menu.IsVisible() || InventoryGui.IsVisible() || Minimap.IsOpen())
        {
            Close();
        }
    }

    private static void Close()
    {
        if (s_window != null)
        {
            UnityEngine.Object.Destroy(s_window);
            s_window = null;
            s_region = "";
        }
        if (s_blockingInput)
        {
            GUIManager.BlockInput(false);
            s_blockingInput = false;
        }
    }

    // ----- the routed RPCs

    /// <summary>Client to server: the leader confirmed the window.</summary>
    public static void RPC_ClaimRegion(long sender, string region)
    {
        if (ZNet.instance == null || !ZNet.instance.IsServer())
        {
            return;
        }
        try
        {
            Claims.EnsureLoaded();
        }
        catch (Exception error)
        {
            s_log.LogError($"lembitu.guilds: could not read the claim store: {error.Message}");
        }
        string? failure = null;
        try
        {
            failure = TryClaim(sender, region);
        }
        catch (Exception error)
        {
            s_log.LogError($"lembitu.guilds: recording the claim failed: {error}");
            failure = "The claim could not be recorded; tell an admin what you did." + Guide;
        }
        if (failure != null)
        {
            s_log.LogInfo($"lembitu.guilds: claim refused for sender {sender}: {failure}");
            Reply(sender, ok: false, region, failure);
            return;
        }
        Reply(sender, ok: true, region, $"The {region} start region is your guild's home now.");
    }

    /// <summary>Every rule the server checks before a claim lands. Returns the refusal, or null.</summary>
    private static string? TryClaim(long sender, string? region)
    {
        if (!Settings.Enabled || !ClaimOn || !Bridge.FollowOn)
        {
            return "Region claims are switched off on this server." + Guide;
        }
        if (string.IsNullOrEmpty(region))
        {
            return "That portal stone names no region." + Guide;
        }
        Spawns.WorldLayoutData? layout = Spawns.Plugin.LayoutCache?.Current;
        if (layout == null || !layout.GroupSpawnPositions.ContainsKey(region))
        {
            return $"{region} has no place in this world's spawn layout yet." + Guide;
        }
        Spawns.GroupRoster? roster = Spawns.Plugin.Roster;
        if (roster == null || !roster.Groups.ContainsKey(region))
        {
            return $"{region} is not one of this world's start regions." + Guide;
        }
        long pid = Bridge.PidOfSender(sender);
        North.Guild? guild = pid != 0 ? North.GuildServer.GuildOf(pid) : null;
        North.Member? member = guild?.Find(pid);
        if (guild == null || member == null || member.Rank != 0)
        {
            return "Only the leader of a guild with no region may claim one." + Guide;
        }
        RegionClaim? held = Claims.ClaimOfRegion(region!);
        if (held != null && held.GuildId != guild.Id)
        {
            return $"{region} already belongs to {held.Label}." + Guide;
        }
        string? own = Claims.RegionOfGuild(guild.Id);
        if (own != null)
        {
            return $"Your guild already holds {own}; one region per guild." + Guide;
        }
        Claims.Record(new RegionClaim
        {
            Region = region!,
            GuildId = guild.Id,
            GuildTag = guild.Tag,
            GuildName = guild.Name,
            ClaimedTicks = DateTime.UtcNow.Ticks,
            ClaimedBy = member.Name,
        });
        Bridge.RunReconcile();
        string label = $"[{guild.Tag}] {guild.Name}";
        string announcement = $"{label} claimed the {region} start region.";
        s_log.LogInfo($"lembitu.guilds: {announcement} (leader {member.Name}).");
        if (ZRoutedRpc.instance != null)
        {
            ZRoutedRpc.instance.InvokeRoutedRPC(0L, AnnounceRpc, announcement);
        }
        return null;
    }

    /// <summary>Server to the claiming client: how the server answered.</summary>
    public static void RPC_ClaimResult(long sender, ZPackage pkg)
    {
        if (ZNet.instance != null && ZNet.instance.IsServer())
        {
            return;
        }
        try
        {
            bool ok = pkg.ReadBool();
            string region = pkg.ReadString();
            string message = pkg.ReadString();
            if (MessageHud.instance != null)
            {
                MessageHud.instance.ShowMessage(MessageHud.MessageType.Center, message);
            }
            s_log.LogInfo($"lembitu.guilds: claim of {region} {(ok ? "accepted" : "refused")}: {message}");
        }
        catch (Exception error)
        {
            s_log.LogError($"lembitu.guilds: could not read the claim result: {error}");
        }
    }

    /// <summary>Server to everyone: a region changed hands.</summary>
    public static void RPC_Claimed(long sender, string announcement)
    {
        if (ZNet.instance != null && ZNet.instance.IsServer())
        {
            return;
        }
        if (MessageHud.instance != null)
        {
            MessageHud.instance.ShowMessage(MessageHud.MessageType.TopLeft, announcement);
        }
    }

    private static void Reply(long sender, bool ok, string region, string message)
    {
        if (ZRoutedRpc.instance == null)
        {
            return;
        }
        ZPackage pkg = new();
        pkg.Write(ok);
        pkg.Write(region ?? "");
        pkg.Write(message);
        ZRoutedRpc.instance.InvokeRoutedRPC(sender, ResultRpc, pkg);
    }

    // ----- widget helpers, the guild window's construction style

    private static Text Text(Transform parent, string content, int size, Color color, Font font, TextAnchor align)
    {
        GameObject go = GUIManager.Instance.CreateText(content, parent, new Vector2(0f, 1f), new Vector2(0f, 1f),
            Vector2.zero, font, size, color, true, new Color(0f, 0f, 0f, 0.9f), 100f, 30f, false);
        Text text = go.GetComponent<Text>();
        text.alignment = align;
        text.supportRichText = true;
        text.horizontalOverflow = HorizontalWrapMode.Wrap;
        text.verticalOverflow = VerticalWrapMode.Overflow;
        return text;
    }

    private static void Place(GameObject go, float x, float y, float width, float height)
    {
        RectTransform rect = (RectTransform)go.transform;
        rect.anchorMin = new Vector2(0f, 1f);
        rect.anchorMax = new Vector2(0f, 1f);
        rect.pivot = new Vector2(0f, 1f);
        rect.anchoredPosition = new Vector2(x, -y);
        rect.sizeDelta = new Vector2(width, height);
    }
}
