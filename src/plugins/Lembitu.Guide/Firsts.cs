using System;
using System.Collections.Generic;
using System.Linq;
using BepInEx.Bootstrap;
using SocialSystem.Client;
using SocialSystem.Core;
using UnityEngine;
using Warrior.Core;

namespace Lembitu.Guide;

/// <summary>
/// The pages opened on a character's firsts (ADR-0027): the first join on first-steps, and - one
/// per character, recorded in Player.m_customData["lembitu.guide.seen"] as comma-separated ids -
/// the first oath on oath-and-class (Oathbound's class record), the first Calling window on calling
/// (the "lembitu.callings.window-seen" key Lembitu.Callings sets) and the first party on groups
/// (SocialSystem's client party state). The plugins that own that state are read, never patched;
/// a feature whose state cannot be found switches itself off alone at startup.
/// </summary>
internal static class Firsts
{
    public const string SeenKey = "lembitu.guide.seen";
    private const string OathProgressionKey = "local.warrior.rpg.progression";
    private const string CallingWindowSeenKey = "lembitu.callings.window-seen";
    private const float PollSeconds = 1f;

    private static bool s_firstJoin, s_oath, s_calling, s_party;
    private static float s_timer;

    public static void VerifyFirstJoin()
    {
        Hooks.Field(typeof(Player), nameof(Player.m_customData), typeof(Dictionary<string, string>));
        s_firstJoin = true;
    }

    public static void VerifyOath()
    {
        if (!Chainloader.PluginInfos.ContainsKey(GuidePlugin.OathboundGuid))
        {
            throw new HookMismatch("Oathbound is not loaded, so there is no class record to watch");
        }
        Hooks.Method(typeof(Progression), nameof(Progression.Decode), new[] { typeof(string) }, typeof(Progression));
        Hooks.Property(typeof(Progression), nameof(Progression.ClassId), typeof(string));
        Hooks.Field(typeof(Player), nameof(Player.m_customData), typeof(Dictionary<string, string>));
        s_oath = true;
    }

    public static void VerifyCalling()
    {
        Hooks.Field(typeof(Player), nameof(Player.m_customData), typeof(Dictionary<string, string>));
        s_calling = true;
    }

    public static void VerifyParty()
    {
        if (!Chainloader.PluginInfos.ContainsKey(GuidePlugin.SocialSystemGuid))
        {
            throw new HookMismatch("SocialSystem is not loaded, so there are no parties to watch");
        }
        Hooks.Property(typeof(SocialClient), nameof(SocialClient.Party), typeof(PartySnapshot));
        Hooks.Property(typeof(PartySnapshot), nameof(PartySnapshot.IsInParty), typeof(bool));
        Hooks.Field(typeof(Player), nameof(Player.m_customData), typeof(Dictionary<string, string>));
        s_party = true;
    }

    /// <summary>One page per tick at most, in the order a fresh character meets them, so a
    /// character that already has several firsts behind it is not met with a burst of windows.</summary>
    public static void Tick()
    {
        if (!(s_firstJoin || s_oath || s_calling || s_party))
        {
            return;
        }
        s_timer -= Time.unscaledDeltaTime;
        if (s_timer > 0f)
        {
            return;
        }
        s_timer = PollSeconds;
        Player? player = Player.m_localPlayer;
        if (player == null || player.IsDead() || GuideWindow.IsOpen || !ContentSync.HasContent)
        {
            return;
        }
        HashSet<string> seen = ReadSeen(player);

        if (s_firstJoin && !seen.Contains(GuideWindow.FirstPageId))
        {
            MarkSeen(player, GuideWindow.FirstPageId, seen);
            if (Settings.AutoOpenOnFirstJoin)
            {
                GuideWindow.Show(GuideWindow.FirstPageId);
            }
            return;
        }
        if (s_oath && !seen.Contains("oath-and-class") && OathTaken(player))
        {
            MarkSeen(player, "oath-and-class", seen);
            GuideWindow.Show("oath-and-class");
            return;
        }
        if (s_calling && !seen.Contains("calling")
            && player.m_customData.TryGetValue(CallingWindowSeenKey, out string? windowSeen) && windowSeen == "1")
        {
            MarkSeen(player, "calling", seen);
            GuideWindow.Show("calling");
            return;
        }
        if (s_party && !seen.Contains("groups") && SocialClient.Instance.Party.IsInParty)
        {
            MarkSeen(player, "groups", seen);
            GuideWindow.Show("groups");
        }
    }

    /// <summary>Read fresh every poll: Player.Load replaces m_customData, so a cached set goes stale.</summary>
    private static HashSet<string> ReadSeen(Player player)
    {
        player.m_customData.TryGetValue(SeenKey, out string? text);
        return text?.Split(',').Where(id => id.Length > 0).ToHashSet() ?? new HashSet<string>();
    }

    private static void MarkSeen(Player player, string id, HashSet<string> seen)
    {
        seen.Add(id);
        player.m_customData[SeenKey] = string.Join(",", seen.OrderBy(x => x, StringComparer.Ordinal));
        GuidePlugin.ClientLog.LogInfo($"Guide page '{id}' recorded as seen for this character.");
    }

    /// <summary>Oathbound's class record: an empty ClassId is a character with no oath yet.</summary>
    private static bool OathTaken(Player player)
    {
        if (!player.m_customData.TryGetValue(OathProgressionKey, out string? text))
        {
            return false;
        }
        try
        {
            return Progression.Decode(text).ClassId != "";
        }
        catch (FormatException)
        {
            return false;
        }
    }
}
