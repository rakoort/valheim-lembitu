using System;
using System.Collections.Generic;
using System.Reflection;
using System.Reflection.Emit;
using BepInEx.Bootstrap;
using HarmonyLib;
using VentureValheim.Progression;
using Warrior.Core;

namespace Lembitu.Oathbound;

/// <summary>
/// Class power follows boss keys (ADR-0025). Oathbound scales spells, Warlock summons, wards and
/// Wither, Monk fists, class abilities, companions and the defense tree by class level, and class
/// level comes from kills that no boss gates, so a caster could grind kills past the gear gate that
/// holds a weapon class back. Every effect above therefore reads the power level: the class level
/// capped at ten per personal boss key.
/// Talent points, class XP and the class level itself are untouched.
///
/// Where each effect runs: Oathbound only ever evaluates its own local player's state
/// (<c>Plugin.ActiveState</c> requires <c>Player.m_localPlayer</c>), so every capped number is
/// computed on that player's own client — spell casts, companion stats (written to ZDO floats the
/// game syncs), and the defense tree's ward and guard. The server never recomputes them, so counting
/// World Advancement Progression's private keys from <c>KeyManager.PrivateKeysList</c>, the local
/// character's own key set, is right on every machine.
///
/// Level reads left alone, and why: <c>Progression.Level</c> itself (talent points, class XP, HUD —
/// untouched by decision); the wolf's pack-command unlock at class level 6 (<c>HunterTree.cs</c> and
/// the <c>oathbound.hunter.level</c> gate in HunterCompanion — an unlock the tree promises, not
/// scaling); and <c>Equipment.MonkHardness</c> in the Monk's bare-handed gathering (a tool tier for
/// rocks and trees, not combat power in the class band).
/// </summary>
internal static class ClassPower
{
    /// <summary>Class levels of power per personal boss key: 10 before Eikthyr, 80 after Fader.</summary>
    private const int LevelsPerKey = 10;

    /// <summary>The seven personal boss keys, in World Advancement Progression's own spelling.</summary>
    private static readonly string[] BossKeys =
    {
        "defeated_eikthyr", "defeated_gdking", "defeated_bonemass", "defeated_dragon",
        "defeated_goblinking", "defeated_queen", "defeated_fader",
    };

    private static MethodInfo s_levelGetter = null!;
    private static MethodInfo s_levelOf = null!;

    /// <summary>
    /// The personal boss keys the local character holds, as World Advancement Progression records
    /// them on the character (<c>VV_PrivateKeys</c>) and mirrors in KeyManager's list. The stack pins
    /// its private keys on, so the list is the character's own key set on every client.
    /// </summary>
    public static int PersonalBossKeys()
    {
        HashSet<string> keys = KeyManager.Instance.PrivateKeysList;
        int count = 0;
        foreach (string key in BossKeys)
        {
            if (keys.Contains(key))
            {
                count++;
            }
        }
        return count;
    }

    /// <summary>The level Oathbound's level-scaled power reads: min(class level, 10 × (keys + 1)).</summary>
    public static int Of(Progression state) => Of(state.Level);

    private static int Of(int level) => Math.Min(level, LevelsPerKey * (PersonalBossKeys() + 1));

    public static IEnumerable<PatchPlan> Plan()
    {
        if (!Chainloader.PluginInfos.ContainsKey(OathboundPlugin.WorldAdvancementGuid))
        {
            throw new HookMismatch("World Advancement Progression is not loaded, so there are no personal boss keys to count");
        }
        Hooks.Method(typeof(KeyManager), "get_Instance", Type.EmptyTypes, typeof(KeyManager));
        Hooks.Property(typeof(KeyManager), "PrivateKeysList", typeof(HashSet<string>));
        Hooks.Field(typeof(KeyManager), "BOSS_KEY_MEADOW", typeof(string));
        Hooks.Method(typeof(ProgressionConfiguration), "GetUsePrivateKeys", Type.EmptyTypes, typeof(bool));

        s_levelGetter = AccessTools.PropertyGetter(typeof(Progression), nameof(Progression.Level))
            ?? throw new HookMismatch("Warrior.Core.Progression.Level getter not found");
        s_levelOf = Hooks.Method(typeof(ClassPower), nameof(Of), new[] { typeof(Progression) }, typeof(int));

        // The two multipliers every spell, summon, ward, Wither curse, Monk fist and class ability
        // goes through. Spell growth per level is Oathbound's own server setting since 0.22.0
        // (`Scaling/SpellPowerPerLevel`); only the level it multiplies is ours.
        MethodInfo levelPower = Hooks.Method(typeof(ClassMagic), nameof(ClassMagic.LevelPower), new[] { typeof(Progression) }, typeof(float));
        Hooks.Once(levelPower, "class level read", ci => ci.Calls(s_levelGetter));
        yield return new PatchPlan(levelPower) { Transpiler = Hooks.Patch(typeof(ClassPower), nameof(CapLevel)) };

        MethodInfo spellLevelPower = Hooks.Method(typeof(ClassMagic), nameof(ClassMagic.SpellLevelPower), new[] { typeof(Progression) }, typeof(float));
        Hooks.Once(spellLevelPower, "class level read", ci => ci.Calls(s_levelGetter));
        yield return new PatchPlan(spellLevelPower) { Transpiler = Hooks.Patch(typeof(ClassPower), nameof(CapLevel)) };

        // The formulas that read the class level directly: companion health and damage, the defense
        // tree's ward pool. WarlockTree.LevelPower only forwards SpellLevelPower, so the summons
        // are already covered above.
        MethodInfo[] capped =
        {
            Hooks.Method(typeof(HunterTree), nameof(HunterTree.Health), new[] { typeof(Progression) }, typeof(float)),
            Hooks.Method(typeof(HunterTree), nameof(HunterTree.Damage), new[] { typeof(Progression) }, typeof(float)),
            Hooks.Method(typeof(DragonTree), nameof(DragonTree.Health), new[] { typeof(Progression) }, typeof(float)),
            Hooks.Method(typeof(DragonTree), nameof(DragonTree.Damage), new[] { typeof(Progression) }, typeof(float)),
            Hooks.Method(typeof(DefenseTree), nameof(DefenseTree.Capacity), new[] { typeof(Progression), typeof(float) }, typeof(float)),
            Hooks.Method(typeof(DefenseCombat), nameof(DefenseCombat.Block), new[] { typeof(Progression), typeof(float), typeof(float), typeof(bool), typeof(bool) }, typeof(float)),
        };
        foreach (MethodInfo method in capped)
        {
            Hooks.Once(method, "class level read", ci => ci.Calls(s_levelGetter));
            yield return new PatchPlan(method) { Transpiler = Hooks.Patch(typeof(ClassPower), nameof(CapLevel)) };
        }

        // Both the talent tooltip and the oath picker reach this overload; the picker passes its
        // selected class's raw level rather than the active Progression record. Cap it once here.
        MethodInfo description = Hooks.Method(typeof(DefenseTree), nameof(DefenseTree.Description), new[] { typeof(string), typeof(int), typeof(Talent) }, typeof(string));
        MethodInfo tooltip = Hooks.Method(typeof(DefenseTree), nameof(DefenseTree.Description), new[] { typeof(Progression), typeof(Talent) }, typeof(string));
        Hooks.Once(tooltip, "level-based defense description", ci => ci.Calls(description));
        yield return new PatchPlan(description) { Prefix = Hooks.Patch(typeof(ClassPower), nameof(CapDescriptionLevel)) };
    }

    private static void CapDescriptionLevel(ref int level) => level = Of(level);

    /// <summary>Replaces every read of the class level with the power level.</summary>
    private static IEnumerable<CodeInstruction> CapLevel(IEnumerable<CodeInstruction> instructions)
    {
        foreach (CodeInstruction instruction in instructions)
        {
            if (instruction.Calls(s_levelGetter))
            {
                instruction.opcode = OpCodes.Call;
                instruction.operand = s_levelOf;
            }
            yield return instruction;
        }
    }
}
