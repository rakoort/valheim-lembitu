using System;
using System.Collections.Generic;
using System.IO;
using System.IO.Compression;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Sockets;
using System.Threading;
using ValheimWebMap;

internal static class MapHttpCheck
{
    public static void Run(string root, bool drift)
    {
        BepInEx.Paths.ConfigPath = root;
        PlayerTracker.Source.Clear();
        PlayerTracker.Source.Add(new PlayerEntry { Id = 42, PlayerId = 42, Key = "Steam_42", Name = "Asta", HasCharacter = true,
            Position = new UnityEngine.Vector3(600, 100, 700), Yaw = 90, Biome = "Mountain" });
        using var raw = new MemoryStream();
        using (var writer = new BinaryWriter(raw, System.Text.Encoding.UTF8, true))
        {
            writer.Write(3); writer.Write(4); writer.Write(new byte[] { 1, 1, 1, 1 }); writer.Write(2);
            foreach (var pin in new[] { ("Copper", 600f, 700f), ("Home", 1000f, 1000f) })
            {
                writer.Write(42L); writer.Write(pin.Item1); writer.Write(pin.Item2); writer.Write(100f); writer.Write(pin.Item3);
                writer.Write(0); writer.Write(false); writer.Write("Steam_42");
            }
        }
        using var compressed = new MemoryStream();
        using (var zip = new ZLibStream(compressed, CompressionLevel.Fastest, true)) zip.Write(raw.ToArray());
        var table = new ZDO(1000, new UnityEngine.Vector3(600, 100, 700), "piece_cartographytable".GetStableHashCode());
        table.Bytes[ZDOVars.s_data] = compressed.ToArray();
        ZDOMan.instance.Add(table);
        var log = new BepInEx.Logging.ManualLogSource();
        using var session = new MapSession(new PluginConfig(), log, new World { m_name = "fixture", m_seed = 1, m_worldGenVersion = 2 });
        var deadline = System.Diagnostics.Stopwatch.StartNew();
        while ((session.Tiles.Atlas == null || !session.PinsJson.Contains("Copper")) && deadline.Elapsed.TotalSeconds < 10)
        {
            session.Tick(1); Thread.Sleep(5);
        }
        for (int i = 0; i < 3; i++) session.Tick(1);
        var reserve = new TcpListener(IPAddress.Loopback, 0); reserve.Start();
        int port = ((IPEndPoint)reserve.LocalEndpoint).Port; reserve.Stop();
        using var server = new WebServer(log, new SessionApi(session));
        server.Start("127.0.0.1", port);
        using var client = new HttpClient { BaseAddress = new Uri("http://127.0.0.1:" + port + "/") };
        using var state = System.Text.Json.JsonDocument.Parse(client.GetStringAsync("api/state").GetAwaiter().GetResult());
        var published = state.RootElement;
        Require(published.GetProperty("guildsEnabled").GetBoolean() == !drift, "HTTP guild availability matches lookup API");
        var player = published.GetProperty("players").EnumerateArray().Single(p => p.GetProperty("name").GetString() == "Asta");
        Require(player.GetProperty("visible").GetBoolean() && player.GetProperty("x").GetSingle() == 600
            && player.GetProperty("z").GetSingle() == 700 && player.GetProperty("yaw").GetSingle() == 90,
            "actual MapSession keeps visible player positions serving under guild drift");
        if (drift) Require(player.GetProperty("guild").ValueKind == System.Text.Json.JsonValueKind.Null
            && player.GetProperty("guildId").ValueKind == System.Text.Json.JsonValueKind.Null
            && player.GetProperty("color").GetString() == "#888781", "HTTP drift clears guild identity without hiding player");
        using var pins = System.Text.Json.JsonDocument.Parse(client.GetStringAsync("api/pins").GetAwaiter().GetResult());
        var copper = pins.RootElement.GetProperty("pins").EnumerateArray().Single(p => p.GetProperty("name").GetString() == "Copper");
        Require(copper.GetProperty("x").GetSingle() == 600 && copper.GetProperty("z").GetSingle() == 700
            && copper.GetProperty("owner").GetString() == "42", "actual cartography pin keeps serving under guild drift");
        var owner = pins.RootElement.GetProperty("owners").EnumerateArray().Single(o => o.GetProperty("id").GetString() == "42");
        Require(owner.GetProperty("name").GetString() == "Asta" && !owner.TryGetProperty("pins", out _),
            "public pin owner keeps attribution but has no per-player total");
        byte[] png = client.GetByteArrayAsync("tiles/0/0/0.png").GetAwaiter().GetResult();
        byte[] pixels = Decode(png);
        int center = 128 * (256 * 3 + 1) + 1 + 128 * 3;
        Require(pixels[center] > 100 && pixels[center + 1] > 100 && pixels[center + 2] > 100,
            "actual rendered mountain terrain keeps serving, not a fog-only tile, under guild drift");
        Require(log.Warnings.Count(w => w.StartsWith("Web map guild features unavailable:")) == (drift ? 1 : 0),
            "actual map polling emits exactly one guild-drift warning");
        Require(client.GetAsync("api/history").GetAwaiter().GetResult().StatusCode == HttpStatusCode.NotFound,
            "removed public History endpoint is unavailable");
    }

    private static byte[] Decode(byte[] png)
    {
        using var payload = new MemoryStream();
        for (int offset = 8; offset < png.Length;)
        {
            int length = System.Buffers.Binary.BinaryPrimitives.ReadInt32BigEndian(png.AsSpan(offset, 4));
            if (System.Text.Encoding.ASCII.GetString(png, offset + 4, 4) == "IDAT") payload.Write(png, offset + 8, length);
            offset += length + 12;
        }
        return PngEncoder.Unzlib(payload.ToArray(), 256 * (256 * 3 + 1));
    }
    private static void Require(bool condition, string label)
    {
        if (!condition) throw new Exception("FAIL: " + label);
        Console.WriteLine("pass: " + label);
    }
    private sealed class SessionApi : IMapApi
    {
        private readonly MapSession session;
        public SessionApi(MapSession value) { session = value; }
        public string InfoJson() => "{}";
        public string StateJson() => session.StateJson;
        public string PinsJson() => session.PinsJson;
        public bool TryGetTile(int z, int x, int y, out byte[] png, out string etag) => session.Tiles.TryGetTile(z, x, y, out png, out etag);
    }
}
namespace BepInEx
{
    internal static class Paths { public static string ConfigPath; }
}
namespace BepInEx.Logging
{
    internal sealed class ManualLogSource
    {
        public readonly List<string> Warnings = new();
        public void LogInfo(object value) { }
        public void LogWarning(object value) { Warnings.Add(value.ToString()); }
        public void LogError(object value) { throw new Exception(value.ToString()); }
        public void LogDebug(object value) { }
    }
}
namespace ValheimWebMap
{
    internal sealed class PluginConfig
    {
        public readonly Guilds.Entry<float> WorldRadius = new(13250), WorldEdgeSize = new(500), SharedMapHalfSize = new(16091.4286f),
            CartographyScanInterval = new(1), UpdateInterval = new(1), SaveInterval = new(600), ExploreRadius = new(100), PinMergeDistance = new(0);
        public readonly Guilds.Entry<int> MaxZoom = new(7), Resolution = new(256), RenderThreads = new(1), HistoryRetentionDays = new(90),
            RevealGeneratedZonesMargin = new(0), DeathMarkersPerPlayer = new(3);
        public readonly Guilds.Entry<string> DataDirectory = new(""), TraderLocations = new("");
        public readonly Guilds.Entry<bool> RevealGeneratedZones = new(false), TrackSessions = new(false), TrackDeaths = new(false),
            ShowPins = new(true), RevealFromCartographyTable = new(true), IgnorePositionPrivacy = new(true), ShowTraders = new(false),
            HidePinsInFog = new(true), ShowCheckedPins = new(true), ShowAutomatedPins = new(false), ShowDeathMarkers = new(false),
            ShowExploredPercent = new(true), ShowDayAndTime = new(true), ShowHiddenPlayers = new(true), ShowDeadStatus = new(true),
            ShowHeading = new(true), ShowBiome = new(true);
    }
    internal static class PlayerTracker
    {
        public static readonly List<PlayerEntry> Source = new();
        public static void Collect(ZNet net, List<PlayerEntry> into) { into.Clear(); into.AddRange(Source); }
    }
}
namespace HarmonyLib { internal static class AccessTools { public static Type TypeByName(string name) => null; } }
internal class Heightmap { public enum Biome { Meadows, Swamp, Mountain, BlackForest, Plains, AshLands, DeepNorth, Ocean, Mistlands } }
internal class World { public string m_name; public int m_seed, m_worldGenVersion; }
internal class Version { public static string CurrentVersion => "synthetic"; }
internal class WorldGenerator
{
    public static WorldGenerator instance = new();
    public Heightmap.Biome GetBiome(float x, float z) => Heightmap.Biome.Mountain;
    public float GetBiomeHeight(Heightmap.Biome biome, float x, float z, out UnityEngine.Color mask) { mask = new(); return 100; }
    public static float GetForestFactor(UnityEngine.Vector3 point) => 2;
}
internal class ZNet { public static ZNet instance = new(); }
internal class EnvMan { public static EnvMan instance = new(); public int GetDay() => 2; public float GetDayFraction() => 0.25f; }
internal struct Vector2s { public int x, y; public Vector2s(int x, int y) { this.x = x; this.y = y; } }
internal class ZoneSystem
{
    public static ZoneSystem instance;
    private readonly HashSet<Vector2s> m_generatedZones = new();
    public float m_zoneSize = 64;
    public Dictionary<int, LocationInstance> m_locationInstances = new();
    public class LocationInstance { public Location m_location; public bool m_placed; public UnityEngine.Vector3 m_position; }
    public class Location { public string m_prefabName; public bool m_iconAlways; }
}
internal static class Utils
{
    public static byte[] Decompress(byte[] input)
    {
        using var stream = new MemoryStream(input); using var zip = new ZLibStream(stream, CompressionMode.Decompress);
        using var output = new MemoryStream(); zip.CopyTo(output); return output.ToArray();
    }
}
namespace UnityEngine
{
    public struct Color { public float a; }
    public static class Mathf
    {
        public static float Clamp01(float value) => Math.Clamp(value, 0, 1);
        public static float Sqrt(float value) => MathF.Sqrt(value);
        public static float InverseLerp(float a, float b, float value) => Clamp01((value - a) / (b - a));
        public static float SmoothStep(float a, float b, float value) { float t = Clamp01(value); return a + (b - a) * t * t * (3 - 2 * t); }
    }
}
