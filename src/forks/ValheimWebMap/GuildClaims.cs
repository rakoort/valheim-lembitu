using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Reflection;
using Newtonsoft.Json.Linq;
using UnityEngine;

namespace ValheimWebMap
{
    /// <summary>Public claim positions only; no whole-world scan or guild-private state enters the snapshot.</summary>
    internal sealed class GuildClaims
    {
        private struct RegionClaim
        {
            public long GuildId;
            public string Day;
        }
        private static readonly int WardKey = "Guilds_WardGuild".GetStableHashCode();
        private static readonly int SiegeKey = "oathbound.siege.state".GetStableHashCode();
        private readonly Dictionary<string, RegionClaim> _regions = new Dictionary<string, RegionClaim>();
        private readonly Dictionary<long, string> _guildRegions = new Dictionary<long, string>();
        private string _path;
        private DateTime _modified;
        private PropertyInfo _layoutCache, _currentLayout;
        private FieldInfo _positions;
        private bool _layoutInitialized;
        public string Json { get; private set; } = "[]";
        public string RegionOf(long guildId) => _guildRegions.TryGetValue(guildId, out string region) ? region : null;

        public void Refresh(GuildLookup guilds, string configRoot, string world)
        {
            ReadClaims(configRoot, world);
            _guildRegions.Clear();
            foreach (var region in _regions)
                if (guilds.HasGuild(region.Value.GuildId)) _guildRegions[region.Value.GuildId] = region.Key;
            var j = new JsonWriter().BeginArray();
            foreach (object guild in guilds.Guilds)
            {
                if (!guilds.HasBanner(guild)) continue;
                long id = guilds.GuildId(guild);
                WriteClaim(j, "territory:" + GuildLookup.Id(id), "territory", id, guilds.Banner(guild), guilds);
                j.Prop("halfSide", guilds.HalfSide(guild, id), 2).EndObject();
            }
            WriteRegions(j, guilds);
            ZDOMan manager = ZDOMan.instance;
            if (manager != null)
            {
                foreach (ZDOID id in ZDOExtraData.GetAllZDOIDsWithHash(ZDOExtraData.Type.Long, WardKey))
                {
                    ZDO zdo = manager.GetZDO(id);
                    if (zdo == null) continue;
                    long guildId = zdo.GetLong(WardKey, 0L);
                    if (guildId == 0) continue; // this layer is guild-bound wards, not every vanilla ward
                    GameObject prefab = ZNetScene.instance?.GetPrefab(zdo.GetPrefab());
                    PrivateArea area = prefab != null ? prefab.GetComponent<PrivateArea>() : null;
                    if (area == null) continue;
                    // Prefer the instantiated ward's runtime radius; unloaded wards use their prefab.
                    GameObject instance = ZNetScene.instance.FindInstance(id);
                    PrivateArea live = instance != null ? instance.GetComponent<PrivateArea>() : null;
                    float radius = live != null ? live.m_radius : area.m_radius;
                    WriteClaim(j, "ward:" + zdo.m_uid, "ward", guildId, zdo.GetPosition(), guilds);
                    j.Prop("radius", radius, 2).EndObject();
                }
                foreach (ZDOID id in ZDOExtraData.GetAllZDOIDsWithHash(ZDOExtraData.Type.String, SiegeKey))
                {
                    ZDO zdo = manager.GetZDO(id);
                    if (zdo == null) continue;
                    string json = zdo.GetString(SiegeKey, "");
                    if (json.Length == 0) continue;
                    JObject siege;
                    try { siege = JObject.Parse(json); }
                    catch (Newtonsoft.Json.JsonException) { continue; }
                    WriteClaim(j, "outpost:" + zdo.m_uid, "outpost", guilds.PlayerGuildId(zdo.GetLong(ZDOVars.s_creator, 0L)), zdo.GetPosition(), guilds);
                    j.Key("siege");
                    int stage = (int?)siege["Stage"] ?? 0;
                    if (stage >= 1 && stage <= 4)
                    {
                        string label = stage == 1 ? "warning" : stage == 2 ? "first wave" : stage == 3 ? "second wave" : "commander";
                        if ((bool?)siege["Paused"] == true) label += " (suspended)";
                        j.BeginObject().Prop("stage", label).EndObject();
                    }
                    else j.Value((string)null);
                    j.EndObject();
                }
            }
            Json = j.EndArray().ToString();
        }

        private static void WriteClaim(JsonWriter j, string id, string kind, long guildId, Vector3 position, GuildLookup guilds)
        {
            j.BeginObject().Prop("id", id).Prop("kind", kind)
                .Prop("guildId", guilds.HasGuild(guildId) ? GuildLookup.Id(guildId) : null)
                .Prop("color", guilds.ColorOfGuild(guildId)).Prop("x", position.x, 1).Prop("z", position.z, 1);
        }
        private void ReadClaims(string configRoot, string world)
        {
            foreach (char invalid in Path.GetInvalidFileNameChars()) world = world.Replace(invalid, '_');
            string path = Path.Combine(configRoot, "Lembitu.Guilds", world + ".claims.json");
            DateTime modified = File.Exists(path) ? File.GetLastWriteTimeUtc(path) : DateTime.MinValue;
            if (path == _path && modified == _modified) return;
            _regions.Clear();
            if (modified != DateTime.MinValue)
            {
                JObject data = JObject.Parse(File.ReadAllText(path));
                if (data["Claims"] is JArray claims)
                {
                    foreach (JObject claim in claims)
                    {
                        string region = (string)claim["Region"];
                        if (string.IsNullOrEmpty(region)) continue;
                        long ticks = (long?)claim["ClaimedTicks"] ?? 0L;
                        _regions[region] = new RegionClaim
                        {
                            GuildId = (long?)claim["GuildId"] ?? 0L,
                            Day = ticks > 0 && ticks <= DateTime.MaxValue.Ticks
                                ? new DateTime(ticks, DateTimeKind.Utc).ToString("yyyy-MM-dd", CultureInfo.InvariantCulture) : null
                        };
                    }
                }
            }
            _path = path;
            _modified = modified;
        }
        private void WriteRegions(JsonWriter j, GuildLookup guilds)
        {
            if (!_layoutInitialized)
            {
                Type plugin = GuildLookup.FindType("SeparateSpawns.Plugin");
                if (plugin == null) return;
                const BindingFlags flags = BindingFlags.Public | BindingFlags.NonPublic;
                _layoutCache = plugin.GetProperty("LayoutCache", flags | BindingFlags.Static);
                _currentLayout = _layoutCache?.PropertyType.GetProperty("Current", flags | BindingFlags.Instance);
                _positions = GuildLookup.Field(_currentLayout?.PropertyType, "GroupSpawnPositions", typeof(Dictionary<string, Vector3>));
                if (_layoutCache == null || _currentLayout == null) throw new MissingMemberException("SeparateSpawns layout API changed");
                _layoutInitialized = true;
            }
            object cache = _layoutCache.GetValue(null, null);
            object layout = cache != null ? _currentLayout.GetValue(cache, null) : null;
            if (layout == null) return; // world layout not generated yet
            foreach (var position in (Dictionary<string, Vector3>)_positions.GetValue(layout))
            {
                _regions.TryGetValue(position.Key, out RegionClaim region);
                WriteClaim(j, "region:" + position.Key, "region", region.GuildId, position.Value, guilds);
                j.Prop("name", position.Key).Prop("claimedDay", guilds.HasGuild(region.GuildId) ? region.Day : null).EndObject();
            }
        }
    }
}
