using System;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Reflection.Emit;
using BepInEx;
using BepInEx.Configuration;
using BepInEx.Logging;
using HarmonyLib;
using Steamworks;

namespace MaxPlayerCount;

/// <summary>
/// Raises the ten-player limit Valheim embeds in three places: the admission check in
/// <c>ZNet.RPC_PeerInfo</c>, the capacity it advertises to Steam, and the capacity it asks PlayFab
/// for when crossplay is on. All three are rewritten from one config value.
/// </summary>
[BepInPlugin(PluginInfo.Guid, PluginInfo.Name, PluginInfo.Version)]
[BepInIncompatibility("org.bepinex.plugins.valheim_plus")]
public class MaxPlayerCountPlugin : BaseUnityPlugin
{
    /// <summary>
    /// The limit vanilla compares against in <c>ZNet.RPC_PeerInfo</c>. Every rewritten literal is
    /// expressed relative to it, so a site that vanilla offsets (PlayFab reserves a lobby slot for
    /// the server itself and therefore loads 11) keeps its offset.
    /// </summary>
    private const int VanillaPlayerLimit = 10;

    // Fully qualified: inside a BaseUnityPlugin, bare `Logger` is the instance property.
    private static readonly ManualLogSource Log = BepInEx.Logging.Logger.CreateLogSource(PluginInfo.Name);

    private static ConfigEntry<int> maxPlayers;

    private readonly Harmony harmony = new(PluginInfo.Guid);

    private FileSystemWatcher watcher;

    private void Awake()
    {
        maxPlayers = Config.Bind(
            "1 - General",
            "MaxPlayerCount",
            20,
            "Player limit this server admits and advertises. Steam allows 64; PlayFab's own ceiling is undocumented.");

        harmony.PatchAll(Assembly.GetExecutingAssembly());
        SetupWatcher();
    }

    private void OnDestroy()
    {
        watcher?.Dispose();
        Config.Save();
    }

    /// <summary>
    /// The limit is read on every admission and every lobby creation, not baked into the rewritten
    /// IL, so editing the config file takes effect without a restart. That is what this watcher is
    /// for; without it BepInEx would only re-read the file at startup.
    /// </summary>
    private void SetupWatcher()
    {
        watcher = new FileSystemWatcher(Paths.ConfigPath, PluginInfo.Guid + ".cfg");
        watcher.Changed += ReloadConfig;
        watcher.Created += ReloadConfig;
        watcher.Renamed += ReloadConfig;
        watcher.SynchronizingObject = ThreadingHelper.SynchronizingObject;
        watcher.EnableRaisingEvents = true;
    }

    private void ReloadConfig(object sender, FileSystemEventArgs e)
    {
        int before = maxPlayers.Value;
        try
        {
            Config.Reload();
        }
        catch (Exception ex)
        {
            Log.LogError($"Could not reload {PluginInfo.Guid}.cfg, keeping {before}: {ex.Message}");
            return;
        }

        if (maxPlayers.Value != before)
        {
            Log.LogInfo($"Player limit reloaded: {before} -> {maxPlayers.Value}");
        }
    }

    /// <summary>
    /// The configured limit, expressed at the offset the rewritten site used. A configured value
    /// below one means "leave vanilla alone", which is how the config disables the mod.
    /// </summary>
    private static int LimitFor(int vanillaLimit)
    {
        int configured = maxPlayers.Value;
        return configured < 1 ? vanillaLimit : configured + (vanillaLimit - VanillaPlayerLimit);
    }

    /// <summary>
    /// Called from every rewritten method in place of the literal it used to load, so the limit is
    /// answered per admission and per lobby rather than baked in when Harmony patched.
    /// </summary>
    private static int ReplacePlayerLimit(int vanillaLimit)
    {
        int limit = LimitFor(vanillaLimit);
        // The first time each site runs is the only proof the inserted call executes rather than
        // merely compiling: admission fires when a peer connects, the PlayFab sites when a
        // crossplay lobby is created.
        if (Once(usedSites, vanillaLimit))
        {
            Log.LogInfo($"Rewritten limit in use: vanilla loaded {vanillaLimit}, answered {limit}");
        }

        return limit;
    }

    private static CodeInstruction CallReplacePlayerLimit() =>
        new(OpCodes.Call, AccessTools.DeclaredMethod(typeof(MaxPlayerCountPlugin), nameof(ReplacePlayerLimit)));

    /// <summary>
    /// Reports a rewritten site once, however often the transpiler runs — and it runs a lot: every
    /// mod in the stack carries its own ServerSync copy, each of which patches
    /// <c>ZNet.RPC_PeerInfo</c>, and Harmony re-runs every transpiler on a method it re-patches.
    /// </summary>
    private static void ReportPatched(string method, string what, int vanillaLimit)
    {
        if (Once(patchedSites, method))
        {
            Log.LogInfo($"Patched {method}: {what} reads {vanillaLimit} in vanilla, now {LimitFor(vanillaLimit)}");
        }
    }

    /// <summary>True the first time this key is seen. Harmony patches off the main thread.</summary>
    private static bool Once<T>(HashSet<T> seen, T key)
    {
        lock (seen)
        {
            return seen.Add(key);
        }
    }

    private static readonly HashSet<string> patchedSites = new();

    private static readonly HashSet<int> usedSites = new();

    /// <summary>
    /// Admission. Vanilla's check is <c>if (GetNrOfPlayers() &gt;= 10)</c>, so the limit is a
    /// literal in the peer-admission path: the transpiler finds the call, then the first literal
    /// loaded after it, and pipes that literal through <see cref="ReplacePlayerLimit" />.
    /// </summary>
    [HarmonyPatch(typeof(ZNet), nameof(ZNet.RPC_PeerInfo))]
    internal static class MaxPlayersCount
    {
        [HarmonyTranspiler]
        private static IEnumerable<CodeInstruction> MaxPlayersPatch(IEnumerable<CodeInstruction> instructions)
        {
            List<CodeInstruction> codes = new(instructions);
            for (int i = 0; i < codes.Count; ++i)
            {
                if (!IsCallTo(codes[i], nameof(ZNet.GetNrOfPlayers)))
                {
                    continue;
                }

                for (int j = i + 1; j < codes.Count; ++j)
                {
                    if (codes[j].opcode != OpCodes.Ldc_I4_S)
                    {
                        continue;
                    }

                    int vanillaLimit = Convert.ToInt32(codes[j].operand);
                    codes.Insert(j + 1, CallReplacePlayerLimit());
                    ReportPatched($"{nameof(ZNet)}.{nameof(ZNet.RPC_PeerInfo)}", "the server-full check", vanillaLimit);
                    return codes;
                }

                break;
            }

            Log.LogError($"Could not find the server-full check in {nameof(ZNet)}.{nameof(ZNet.RPC_PeerInfo)}: the limit is still vanilla's {VanillaPlayerLimit}");
            return codes;
        }

        private static bool IsCallTo(CodeInstruction instruction, string method) =>
            (instruction.opcode == OpCodes.Call || instruction.opcode == OpCodes.Callvirt)
            && instruction.operand is MethodInfo called
            && called.Name == method;
    }

    /// <summary>
    /// The capacity the dedicated server advertises to Steam. A prefix rather than a transpiler,
    /// because vanilla passes the count in as an argument.
    /// </summary>
    [HarmonyPatch(typeof(SteamGameServer), nameof(SteamGameServer.SetMaxPlayerCount))]
    internal static class MaxPlayerSteamPatch
    {
        [HarmonyPrefix]
        private static void SetMaxPlayerSteamPrefix(ref int cPlayersMax)
        {
            int configured = maxPlayers.Value;
            if (configured < 1)
            {
                return;
            }

            Log.LogInfo($"{nameof(SteamGameServer)}.{nameof(SteamGameServer.SetMaxPlayerCount)} asked for {cPlayersMax}, advertising {configured}");
            cPlayersMax = configured;
        }
    }

    /// <summary>
    /// The capacity PlayFab is asked for when crossplay is on. Both methods load an offset literal
    /// (11: ten players plus the server's own relay leg) and then store it, one into a lobby
    /// request field and one through a network-configuration property.
    /// </summary>
    [HarmonyPatch]
    internal static class MaxPlayerPlayfabPatch
    {
        private static IEnumerable<MethodBase> TargetMethods()
        {
            yield return AccessTools.DeclaredMethod(typeof(ZPlayFabMatchmaking), nameof(ZPlayFabMatchmaking.CreateLobby));
            yield return AccessTools.DeclaredMethod(typeof(ZPlayFabMatchmaking), nameof(ZPlayFabMatchmaking.CreateAndJoinNetwork));
        }

        [HarmonyTranspiler]
        private static IEnumerable<CodeInstruction> MaxPlayerPlayfabTranspiler(
            IEnumerable<CodeInstruction> instructions,
            MethodBase original)
        {
            List<CodeInstruction> codes = new(instructions);
            for (int i = 0; i + 1 < codes.Count; ++i)
            {
                if (codes[i].opcode != OpCodes.Ldc_I4_S || !StoresPlayerLimit(codes[i + 1]))
                {
                    continue;
                }

                int vanillaLimit = Convert.ToInt32(codes[i].operand);
                codes.Insert(i + 1, CallReplacePlayerLimit());
                ReportPatched($"{nameof(ZPlayFabMatchmaking)}.{original.Name}", "the crossplay capacity", vanillaLimit);
                return codes;
            }

            Log.LogError($"Could not find the capacity literal in {nameof(ZPlayFabMatchmaking)}.{original.Name}: crossplay is still capped at vanilla's {VanillaPlayerLimit}");
            return codes;
        }

        /// <summary>
        /// The two stores that follow the literal. Both members belong to the PlayFab SDK rather
        /// than to the game or to us, so they are matched by name: nothing in this repo references
        /// those assemblies, and pulling them in to spell two names would be a worse trade than
        /// the transpiler's own "pattern not found" error, which is logged loudly above.
        /// </summary>
        private static bool StoresPlayerLimit(CodeInstruction instruction)
        {
            if (instruction.opcode == OpCodes.Stfld)
            {
                return instruction.operand is FieldInfo field && field.Name == "MaxPlayers";
            }

            return instruction.operand is MethodInfo method && method.Name == "set_MaxPlayerCount";
        }
    }
}
