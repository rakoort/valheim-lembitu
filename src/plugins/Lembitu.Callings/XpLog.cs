using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Text;
using BepInEx.Logging;

namespace Lembitu.Callings;

/// <summary>
/// Measures the Calling (ADR-0030): every client sums the profession XP it earns and, every
/// ReportMinutes of play, sends the server one report that the server writes to its log. Each line
/// names the player and, per profession, the real level, whether it is a focus, the raw XP (after
/// every mod's rate, before the steep curve) and the XP the curve let through. Admin-facing only; no
/// player sees it. A logout loses at most one unsent window.
/// </summary>
internal static class XpLog
{
    private const string Rpc = "LembituCallings_XpReport";

    private sealed class Gain
    {
        public float Raw;
        public float Earned;
    }

    private static readonly Dictionary<Skills.SkillType, Gain> s_gains = new();
    private static float s_seconds;
    private static ZRoutedRpc? s_registered;
    private static ManualLogSource s_log = null!;

    public static bool On { get; set; }

    public static void Configure(ManualLogSource log) => s_log = log;

    /// <summary>Verifies the members the report reads; the gain itself is recorded by SkillHooks.</summary>
    public static IEnumerable<PatchPlan> Plan()
    {
        Hooks.Field(typeof(Skills), "m_skillData", typeof(Dictionary<Skills.SkillType, Skills.Skill>));
        Hooks.Field(typeof(ZNetPeer), nameof(ZNetPeer.m_playerName), typeof(string));
        return Enumerable.Empty<PatchPlan>();
    }

    /// <summary>One gain of the local player's profession: raw before the steep curve, earned after it.</summary>
    public static void Record(Skills.SkillType type, float raw, float earned)
    {
        if (!On)
        {
            return;
        }
        if (!s_gains.TryGetValue(type, out Gain gain))
        {
            s_gains[type] = gain = new Gain();
        }
        gain.Raw += raw;
        gain.Earned += earned;
    }

    /// <summary>ZRoutedRpc is rebuilt with every world, so the report RPC re-registers against it.</summary>
    public static void Tick(float dt)
    {
        if (!On)
        {
            return;
        }
        ZRoutedRpc? rpc = ZRoutedRpc.instance;
        if (rpc != null && s_registered != rpc)
        {
            rpc.Register<ZPackage>(Rpc, Receive);
            s_registered = rpc;
            s_gains.Clear();
            s_seconds = 0f;
        }
        Player player = Player.m_localPlayer;
        if (rpc == null || player == null || ZNet.instance == null)
        {
            return;
        }
        s_seconds += dt;
        if (s_seconds >= Settings.XpReportMinutes * 60f)
        {
            Send(player);
        }
    }

    private static void Send(Player player)
    {
        long server = ZNet.instance.IsServer() ? ZDOMan.GetSessionID() : ZNet.instance.GetServerPeer()?.m_uid ?? 0;
        if (server == 0)
        {
            return;
        }
        Calling calling = CallingStore.Of(player);
        var pkg = new ZPackage();
        pkg.Write(s_seconds / 60f);
        pkg.Write(player.GetPlayerName());
        pkg.Write(Professions.All.Count);
        foreach (Profession profession in Professions.All)
        {
            player.GetSkills().m_skillData.TryGetValue(profession.Type, out Skills.Skill skill);
            s_gains.TryGetValue(profession.Type, out Gain gain);
            pkg.Write(profession.Key);
            pkg.Write(skill?.m_level ?? 0f);
            pkg.Write(calling.TryGetShadow(profession.Type, out _));
            pkg.Write(gain?.Raw ?? 0f);
            pkg.Write(gain?.Earned ?? 0f);
        }
        ZRoutedRpc.instance.InvokeRoutedRPC(server, Rpc, pkg);
        s_gains.Clear();
        s_seconds = 0f;
    }

    private static void Receive(long sender, ZPackage pkg)
    {
        if (ZNet.instance == null || !ZNet.instance.IsServer())
        {
            return;
        }
        ZNetPeer? peer = ZNet.instance.GetPeer(sender);
        float minutes = pkg.ReadSingle();
        string name = pkg.ReadString();
        int count = pkg.ReadInt();
        var line = new StringBuilder("Profession XP: player=")
            .Append(peer?.m_playerName ?? name)
            .Append(" id=").Append(peer?.m_socket?.GetHostName() ?? "host")
            .Append(" minutes=").Append(minutes.ToString("0.0", CultureInfo.InvariantCulture));
        for (int i = 0; i < count; i++)
        {
            string key = pkg.ReadString();
            float level = pkg.ReadSingle();
            bool focus = pkg.ReadBool();
            float raw = pkg.ReadSingle();
            float earned = pkg.ReadSingle();
            line.Append(" | ").Append(key)
                .Append(" level=").Append(level.ToString("0.00", CultureInfo.InvariantCulture))
                .Append(" focus=").Append(focus ? 1 : 0)
                .Append(" raw=").Append(raw.ToString("0.000", CultureInfo.InvariantCulture))
                .Append(" earned=").Append(earned.ToString("0.000", CultureInfo.InvariantCulture));
        }
        s_log.LogInfo(line.ToString());
    }
}
