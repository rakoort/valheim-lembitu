using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using BepInEx.Logging;
using HarmonyLib;
using Jotunn.Entities;
using Jotunn.Managers;
using VentureValheim.Progression;

namespace Lembitu.Callings;

/// <summary>
/// WAP 1.0.0 knows no Deep North materials. The server supplies the generated prefab list through
/// Jotunn initial synchronization, just like Guide content; clients never read their local file.
/// Enforcement is on the player's crafting/equipping actions, as with WAP, not an anti-cheat service.
/// </summary>
internal static class DeepNorthKeys
{
    public const string FileName = "lembitu.callings.deep-north.txt";
    // WAP 1.0.0 KeyManager.BOSS_KEY_ASHLAND, awarded by Fader's death.
    private const string FaderKey = "defeated_fader";
    private static readonly HashSet<string> s_items = new(StringComparer.Ordinal);
    private static ManualLogSource s_log = null!;
    private static CustomRPC s_rpc = null!;
    private static ZNet? s_network;
    private static string? s_content;
    private static DateTime s_lastWrite;
    private static float s_poll;
    public static int Count => s_items.Count;

    public static IEnumerable<PatchPlan> Plan()
    {
        Pinned.Pin(SkillRules.WorldAdvancementProgressionGuid, "1.0.0", "World Advancement Progression");
        Hooks.Property(typeof(KeyManager), "Instance", typeof(KeyManager));
        Hooks.Method(typeof(KeyManager), "HasPrivateKey", new[] { typeof(string) }, typeof(bool));
        Hooks.Field(typeof(InventoryGui), "m_craftRecipe", typeof(Recipe));
        var craft = Hooks.Method(typeof(InventoryGui), "DoCrafting", new[] { typeof(Player) }, typeof(void));
        var equip = Hooks.Method(typeof(Humanoid), nameof(Humanoid.EquipItem),
            new[] { typeof(ItemDrop.ItemData), typeof(bool) }, typeof(bool));
        yield return new PatchPlan(craft) { Prefix = Hooks.Patch(typeof(DeepNorthKeys), nameof(BeforeCraft), Priority.First) };
        yield return new PatchPlan(equip) { Prefix = Hooks.Patch(typeof(DeepNorthKeys), nameof(BeforeEquip), Priority.First) };
    }

    public static void Enable(ManualLogSource log)
    {
        s_log = log;
        s_rpc = NetworkManager.Instance.AddRPC("deep-north-keys", ServerReceive, ClientReceive);
        SynchronizationManager.Instance.AddInitialSynchronization(s_rpc, PackageForPeer);
    }

    public static void Tick(float delta)
    {
        ZNet? network = ZNet.instance;
        if (network == null || !network.enabled || (!network.IsServer() &&
            ZNet.GetConnectionStatus() != ZNet.ConnectionStatus.Connected &&
            ZNet.GetConnectionStatus() != ZNet.ConnectionStatus.Connecting))
        {
            Clear();
            return;
        }
        StartSession(network);
        if (!network.IsServer()) return;
        s_poll -= delta;
        if (s_poll > 0f) return;
        s_poll = 2f;
        if (LoadFromDisk()) s_rpc.SendPackage(ZRoutedRpc.Everybody, Package(s_content!));
    }

    private static void StartSession(ZNet network)
    {
        if (ReferenceEquals(s_network, network)) return;
        Clear();
        s_network = network;
    }

    private static void Clear()
    {
        s_network = null;
        s_content = null;
        s_items.Clear();
        s_lastWrite = default;
        s_poll = 0f;
    }

    private static bool LoadFromDisk()
    {
        try
        {
            string path = Path.Combine(BepInEx.Paths.ConfigPath, FileName);
            FileInfo info = new(path);
            if (s_content != null && info.Exists && info.LastWriteTimeUtc == s_lastWrite) return false;
            string content = File.ReadAllText(path);
            if (content == s_content) return false;
            Load(content);
            s_lastWrite = info.LastWriteTimeUtc;
            s_log.LogInfo($"Deep North personal Fader-key locks on ({Count} prefabs), server list synchronized.");
            return true;
        }
        catch (Exception error)
        {
            s_log.LogWarning($"Deep North key list could not be loaded; retaining the last server list, or blocking actions until initial sync: {error.Message}");
            return false;
        }
    }

    private static void Load(string content)
    {
        HashSet<string> items = new(StringComparer.Ordinal);
        using StringReader reader = new(content);
        string? line;
        while ((line = reader.ReadLine()) != null)
        {
            string prefab = line.Trim();
            if (prefab.Length != 0 && !prefab.StartsWith("#", StringComparison.Ordinal)) items.Add(prefab);
        }
        if (items.Count == 0) throw new InvalidDataException("Deep North prefab list is empty.");
        s_items.Clear();
        s_items.UnionWith(items);
        s_content = content;
    }

    private static ZPackage? PackageForPeer(ZNetPeer peer)
    {
        ZNet? network = ZNet.instance;
        if (network == null || !network.IsServer()) return null;
        StartSession(network);
        LoadFromDisk();
        return s_content == null ? null : Package(s_content);
    }

    private static ZPackage Package(string content)
    {
        ZPackage package = new();
        package.Write(content);
        return package;
    }

    private static IEnumerator ServerReceive(long sender, ZPackage package)
    {
        yield break; // Clients cannot publish policy.
    }

    private static IEnumerator ClientReceive(long sender, ZPackage package)
    {
        ZNet? network = ZNet.instance;
        if (network == null || network.IsServer()) yield break;
        StartSession(network);
        Load(package.ReadString());
        s_log.LogInfo($"Deep North personal Fader-key locks on ({Count} prefabs), received server list.");
    }

    private static bool BeforeCraft(InventoryGui __instance, Player player)
    {
        if (player != Player.m_localPlayer || __instance.m_craftRecipe?.m_item == null) return true;
        return Allowed(player, __instance.m_craftRecipe.m_item.gameObject.name, "craft");
    }

    private static bool BeforeEquip(Humanoid __instance, ItemDrop.ItemData item, ref bool __result)
    {
        if (__instance != Player.m_localPlayer || item?.m_dropPrefab == null) return true;
        if (Allowed(__instance, item.m_dropPrefab.name, "equip")) return true;
        __result = false;
        return false;
    }

    private static bool Allowed(Humanoid player, string prefab, string action)
    {
        if (s_content == null)
        {
            player.Message(MessageHud.MessageType.Center, "Waiting for the server's boss-key rules. Guide: Boss keys (boss-keys).");
            return false;
        }
        if (!s_items.Contains(prefab) || (KeyManager.Instance != null && KeyManager.Instance.HasPrivateKey(FaderKey))) return true;
        player.Message(MessageHud.MessageType.Center,
            $"Needs your own Fader boss key to {action} Deep North gear. Guide: Boss keys (boss-keys).");
        return false;
    }
}
