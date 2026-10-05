using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Runtime.CompilerServices;
using BepInEx.Logging;

namespace Lembitu.Callings;

/// <summary>What a focus skill would be without the focus (CONTEXT.md, "Shadow level").</summary>
internal sealed class Shadow(float level, float accumulator)
{
    public float Level { get; set; } = level;
    public float Accumulator { get; set; } = accumulator;
}

/// <summary>
/// A character's four focus professions and their shadow levels. Only a focus stores a shadow; a
/// non-focus skill's shadow is its real level.
/// </summary>
internal sealed class Calling
{
    private const string Version = "1";

    private readonly Dictionary<Skills.SkillType, Shadow> _focus = new();

    public IEnumerable<KeyValuePair<Skills.SkillType, Shadow>> Focuses => _focus;

    public bool IsFocus(Skills.SkillType type) => _focus.ContainsKey(type);

    public bool TryGetShadow(Skills.SkillType type, out Shadow shadow) => _focus.TryGetValue(type, out shadow);

    public int CountIn(ProfessionGroup group) =>
        _focus.Keys.Count(type => Professions.TryGet(type, out Profession p) && p.Group == group);

    public bool HasRoomFor(Profession profession) => CountIn(profession.Group) < Professions.Quota(profession.Group);

    /// <summary>The shadow starts where the skill stands, so dropping it straight away changes nothing.</summary>
    public void Add(Profession profession, Skills.Skill skill) =>
        _focus[profession.Type] = new Shadow(skill.m_level, skill.m_accumulator);

    /// <summary>The skill falls to its shadow, which is what it would have been without the focus.</summary>
    public void Drop(Profession profession, Skills.Skill skill)
    {
        Shadow shadow = _focus[profession.Type];
        skill.m_level = shadow.Level;
        skill.m_accumulator = 0f;
        _focus.Remove(profession.Type);
    }

    public string Encode() =>
        Version + "|" + string.Join(";", _focus.Select(f =>
            Professions.TryGet(f.Key, out Profession p)
                ? p.Key + "=" + f.Value.Level.ToString("R", CultureInfo.InvariantCulture) + "," + f.Value.Accumulator.ToString("R", CultureInfo.InvariantCulture)
                : throw new InvalidOperationException($"skill {(int)f.Key} is not a profession")));

    public static Calling Decode(string text)
    {
        string[] parts = text.Split('|');
        if (parts.Length != 2 || parts[0] != Version)
        {
            throw new FormatException($"unsupported Calling record version '{parts[0]}'");
        }
        var calling = new Calling();
        if (parts[1].Length == 0)
        {
            return calling;
        }
        foreach (string entry in parts[1].Split(';'))
        {
            string[] field = entry.Split('=', ',');
            if (field.Length != 3 || !Professions.TryGet(field[0], out Profession profession)
                || !float.TryParse(field[1], NumberStyles.Float, CultureInfo.InvariantCulture, out float level)
                || !float.TryParse(field[2], NumberStyles.Float, CultureInfo.InvariantCulture, out float accumulator))
            {
                throw new FormatException($"invalid Calling entry '{entry}'");
            }
            if (calling._focus.ContainsKey(profession.Type) || !calling.HasRoomFor(profession))
            {
                throw new FormatException($"Calling holds '{field[0]}' twice or above its group's quota");
            }
            calling._focus[profession.Type] = new Shadow(level, accumulator);
        }
        return calling;
    }
}

/// <summary>
/// Each character's Calling, kept in Player.m_customData beside Oathbound's own record and cached per
/// Player. A record this version cannot read is never overwritten: the character plays with no
/// Calling until an admin looks at it, which is how Oathbound treats its own saves.
/// </summary>
internal static class CallingStore
{
    public const string CustomDataKey = "lembitu.callings";

    /// <summary>Set to "1" the first time the Calling window opens for a character, never cleared
    /// (contract); Lembitu.Guide opens the Calling page once for it.</summary>
    public const string WindowSeenKey = "lembitu.callings.window-seen";

    private sealed class Entry(Calling calling, bool readable)
    {
        public Calling Calling { get; } = calling;
        public bool Readable { get; } = readable;
    }

    private static readonly ConditionalWeakTable<Player, Entry> Cache = new();
    private static ManualLogSource s_log = null!;

    public static void Configure(ManualLogSource log) => s_log = log;

    public static Calling Of(Player player) => EntryOf(player).Calling;

    public static bool IsReadable(Player player) => EntryOf(player).Readable;

    public static void Save(Player player)
    {
        Entry entry = EntryOf(player);
        if (entry.Readable)
        {
            player.m_customData[CustomDataKey] = entry.Calling.Encode();
        }
    }

    /// <summary>Player.Load replaces m_customData, so a cached Calling is stale after it.</summary>
    public static void Forget(Player player) => Cache.Remove(player);

    private static Entry EntryOf(Player player) => Cache.GetValue(player, Load);

    private static Entry Load(Player player)
    {
        if (!player.m_customData.TryGetValue(CustomDataKey, out string text))
        {
            return new Entry(new Calling(), readable: true);
        }
        try
        {
            return new Entry(Calling.Decode(text), readable: true);
        }
        catch (FormatException error)
        {
            s_log.LogError($"Calling record of {player.GetPlayerName()} could not be read and is left untouched: {error.Message} ({text})");
            return new Entry(new Calling(), readable: false);
        }
    }
}
