using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.Reflection;
using UnityEngine;

namespace ValheimWebMap
{
    /// <summary>Guilds 1.5.1 server authority. All reflection and snapshot building runs on the main thread.</summary>
    internal sealed class GuildLookup
    {
        public const string Grey = "#888781";
        private const BindingFlags Static = BindingFlags.Static | BindingFlags.Public | BindingFlags.NonPublic;
        private const BindingFlags Instance = BindingFlags.Instance | BindingFlags.Public;
        private static readonly object NoExtraTiers = 0;
        private readonly Action<string> _warn;
        private readonly Dictionary<long, object> _guilds = new Dictionary<long, object>();
        private readonly Dictionary<long, long> _memberships = new Dictionary<long, long>();
        private readonly Dictionary<long, float> _halfSides = new Dictionary<long, float>();
        private readonly HashSet<long> _online = new HashSet<long>();
        private readonly Dictionary<string, FieldInfo> _fields = new Dictionary<string, FieldInfo>();
        private readonly object[] _one = new object[1];
        private readonly object[] _two = new object[2];
        private readonly GuildClaims _claims = new GuildClaims();
        private Action _ensureLoaded;
        private MethodInfo _halfSide, _levelOf, _buildingCount;
        private FieldInfo _store, _definitions, _buildingId, _memberId, _memberName, _memberRank;
        private bool _initialized, _disabled;
        private string _guildsJson = "[]", _claimsJson = "[]";

        // Fixed heraldic tones, in Guilds.Palette order. Unknown colours are neutral, never name-hashed.
        private static readonly Dictionary<string, string> Tones = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
        {
            { "FFD27A", "#b6a06b" }, { "FF8C42", "#b78059" }, { "FF5A4E", "#ae6b62" },
            { "D9435E", "#995d6b" }, { "C77DFF", "#977ca9" }, { "8A7CFF", "#817ba9" },
            { "5DA9FF", "#7090b1" }, { "4ED6E0", "#71a2a5" }, { "55D68A", "#76a084" },
            { "A6E05A", "#97a76c" }, { "E8E8E8", "#b3b1a8" }, { "B08D5A", "#998568" }
        };

        public GuildLookup(Action<string> warn) { _warn = warn; }

        public void Refresh(IReadOnlyList<PlayerEntry> players, string configRoot, string world)
        {
            if (_disabled) return;
            try
            {
                if (!_initialized) Initialize();
                _ensureLoaded();
                _guilds.Clear();
                _halfSides.Clear();
                _memberships.Clear();
                _online.Clear();
                foreach (PlayerEntry player in players) if (player.PlayerId != 0) _online.Add(player.PlayerId);
                foreach (object guild in (IEnumerable)_store.GetValue(null))
                {
                    long id = Get<long>(guild, "Id");
                    _guilds.Add(id, guild);
                    foreach (object member in Get<IEnumerable>(guild, "Members"))
                        _memberships[(long)_memberId.GetValue(member)] = id;
                }
                _claims.Refresh(this, configRoot, world);
                var guildJson = new JsonWriter().BeginArray();
                foreach (object guild in _guilds.Values) WriteGuild(guildJson, guild);
                guildJson.EndArray();
                _guildsJson = guildJson.ToString();
                _claimsJson = _claims.Json;
            }
            catch (Exception error)
            {
                _disabled = true;
                _guilds.Clear();
                _halfSides.Clear();
                _memberships.Clear();
                _guildsJson = _claimsJson = "[]";
                _warn("Web map guild features unavailable: " + (error.InnerException ?? error).Message);
            }
        }

        public void Write(JsonWriter j)
        {
            j.Prop("guildsEnabled", _initialized && !_disabled);
            j.Key("guilds").ValueJson(_guildsJson);
            j.Key("claims").ValueJson(_claimsJson);
        }

        public string NameOf(long playerId) => TryGuildOf(playerId, out object guild) ? Get<string>(guild, "Name") : null;
        public string IdOf(long playerId) => _memberships.TryGetValue(playerId, out long id) ? Id(id) : null;
        public string ColorOf(long playerId) => TryGuildOf(playerId, out object guild) ? Tone(guild) : Grey;
        internal long PlayerGuildId(long playerId) => _memberships.TryGetValue(playerId, out long id) ? id : 0L;
        internal string ColorOfGuild(long id) => _guilds.TryGetValue(id, out object guild) ? Tone(guild) : Grey;
        internal bool HasGuild(long id) => _guilds.ContainsKey(id);
        internal IEnumerable<object> Guilds => _guilds.Values;
        internal long GuildId(object guild) => Get<long>(guild, "Id");
        internal bool HasBanner(object guild) => Get<bool>(guild, "HasBanner");
        internal Vector3 Banner(object guild) => Get<Vector3>(guild, "BannerPos");
        internal float HalfSide(object guild, long id)
        {
            if (_halfSides.TryGetValue(id, out float halfSide)) return halfSide;
            _two[0] = guild; _two[1] = NoExtraTiers;
            halfSide = (float)_halfSide.Invoke(null, _two);
            _halfSides.Add(id, halfSide);
            return halfSide;
        }
        internal static string Id(long id) => id.ToString(CultureInfo.InvariantCulture);

        private bool TryGuildOf(long pid, out object guild)
        {
            guild = null;
            return _memberships.TryGetValue(pid, out long id) && _guilds.TryGetValue(id, out guild);
        }
        private string Tone(object guild)
        {
            string color = Get<string>(guild, "Color");
            return color != null && Tones.TryGetValue(color.TrimStart('#'), out string tone) ? tone : Grey;
        }
        private T Get<T>(object guild, string name) => (T)_fields[name].GetValue(guild);

        private void Initialize()
        {
            Type server = FindType("Guilds.GuildServer");
            if (server == null) throw new MissingMemberException("Northarun/Guilds is absent");
            Type guild = Method(server, "GuildOf", new[] { typeof(long) }).ReturnType;
            _store = Field(server, "Guilds", typeof(List<>).MakeGenericType(guild), Static);
            _ensureLoaded = (Action)Delegate.CreateDelegate(typeof(Action), Method(server, "EnsureLoaded", Type.EmptyTypes, typeof(void)));
            _halfSide = Method(server, "HalfSide", new[] { guild, typeof(int) }, typeof(float));
            _buildingCount = Method(server, "BuildingCount", new[] { typeof(long), typeof(string) }, typeof(int));
            _levelOf = Method(FindType("Guilds.Progress"), "LevelOf", new[] { typeof(long) }, typeof(int));
            foreach (string name in new[] { "Name", "Tag", "Color", "Emblem", "Description" }) _fields[name] = Field(guild, name, typeof(string));
            _fields["Id"] = Field(guild, "Id", typeof(long));
            _fields["Xp"] = Field(guild, "Xp", typeof(long));
            _fields["HasBanner"] = Field(guild, "HasBanner", typeof(bool));
            _fields["BannerPos"] = Field(guild, "BannerPos", typeof(Vector3));
            _fields["Upgrades"] = Field(guild, "Upgrades", typeof(Dictionary<string, int>));
            Type member = FindType("Guilds.Member");
            _fields["Members"] = Field(guild, "Members", typeof(List<>).MakeGenericType(member));
            _memberId = Field(member, "Pid", typeof(long));
            _memberName = Field(member, "Name", typeof(string));
            _memberRank = Field(member, "Rank", typeof(int));
            Type relation = FindType("Guilds.Relation");
            if (relation == null || !relation.IsEnum || Enum.GetName(relation, 1) != "Ally" || Enum.GetName(relation, 2) != "War")
                throw new MissingMemberException("Guilds relations API changed");
            _fields["Relations"] = Field(guild, "Relations", typeof(Dictionary<,>).MakeGenericType(typeof(long), relation));
            Type building = FindType("Guilds.BuildingDef");
            _definitions = Field(FindType("Guilds.Buildings"), "Defs", typeof(List<>).MakeGenericType(building), Static);
            _buildingId = Field(building, "Id", typeof(string));
            _initialized = true;
        }

        private void WriteGuild(JsonWriter j, object guild)
        {
            long id = GuildId(guild);
            j.BeginObject().Prop("id", Id(id)).Prop("name", Get<string>(guild, "Name"))
                .Prop("tag", Get<string>(guild, "Tag")).Prop("color", Tone(guild))
                .Prop("emblem", Get<string>(guild, "Emblem")).Prop("description", Get<string>(guild, "Description"));
            object leader = null;
            foreach (object member in Get<IEnumerable>(guild, "Members"))
                if ((int)_memberRank.GetValue(member) == 0) { leader = member; break; }
            j.Key("leader");
            if (leader == null) j.Value((string)null);
            else WriteMember(j, leader, false);
            j.Key("members").BeginArray();
            foreach (object member in Get<IEnumerable>(guild, "Members")) WriteMember(j, member, true);
            j.EndArray().Prop("startRegion", _claims.RegionOf(id));
            _one[0] = Get<long>(guild, "Xp");
            j.Prop("level", (int)_levelOf.Invoke(null, _one));
            j.Key("upgrades").BeginArray();
            foreach (var upgrade in Get<Dictionary<string, int>>(guild, "Upgrades"))
                j.BeginObject().Prop("name", upgrade.Key).Prop("tier", upgrade.Value).EndObject();
            j.EndArray().Key("buildings").BeginArray();
            foreach (object definition in (IEnumerable)_definitions.GetValue(null))
            {
                string name = (string)_buildingId.GetValue(definition);
                _two[0] = id; _two[1] = name;
                if ((int)_buildingCount.Invoke(null, _two) > 0) j.BeginObject().Prop("name", name).EndObject();
            }
            j.EndArray().Key("relations").BeginArray();
            foreach (DictionaryEntry relation in Get<IDictionary>(guild, "Relations"))
            {
                int value = Convert.ToInt32(relation.Value, CultureInfo.InvariantCulture);
                if ((value != 1 && value != 2) || !_guilds.TryGetValue((long)relation.Key, out object other)) continue;
                j.BeginObject().Prop("guildId", Id((long)relation.Key)).Prop("name", Get<string>(other, "Name"))
                    .Prop("relation", value == 1 ? "ally" : "war").EndObject();
            }
            j.EndArray().Key("banner");
            if (HasBanner(guild))
            {
                Vector3 pos = Banner(guild);
                j.BeginObject().Prop("x", pos.x, 1).Prop("z", pos.z, 1).EndObject();
            }
            else j.Value((string)null);
            j.Prop("territoryHalfSide", HasBanner(guild) ? HalfSide(guild, id) : 0f, 2).EndObject();
        }
        private void WriteMember(JsonWriter j, object member, bool online)
        {
            long id = (long)_memberId.GetValue(member);
            j.BeginObject().Prop("id", Id(id)).Prop("name", (string)_memberName.GetValue(member));
            if (online) j.Prop("online", _online.Contains(id));
            j.EndObject();
        }
        internal static Type FindType(string name)
        {
            foreach (Assembly assembly in AppDomain.CurrentDomain.GetAssemblies())
            {
                Type type = assembly.GetType(name, false);
                if (type != null) return type;
            }
            return null;
        }
        internal static FieldInfo Field(Type type, string name, Type expected, BindingFlags flags = Instance)
        {
            FieldInfo field = type?.GetField(name, flags);
            if (field == null || field.FieldType != expected) throw new MissingMemberException("Guild map field changed: " + type?.FullName + "." + name);
            return field;
        }
        private static MethodInfo Method(Type type, string name, Type[] arguments, Type returns = null)
        {
            MethodInfo method = type?.GetMethod(name, Static, null, arguments, null);
            if (method == null || (returns != null && method.ReturnType != returns))
                throw new MissingMemberException("Guild map method changed: " + type?.FullName + "." + name);
            return method;
        }
    }
}
