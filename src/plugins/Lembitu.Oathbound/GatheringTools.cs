using System;
using System.Collections.Generic;
using System.Reflection;
using System.Reflection.Emit;
using HarmonyLib;
using Warrior.Core;
using Warrior.Mod;

namespace Lembitu.Oathbound;

/// <summary>
/// A class never narrows a Calling (ADR-0022): every class may fish, and a Monk's bare hands mine and
/// chop as Mining and Wood Cutting.
/// </summary>
internal static class GatheringTools
{
    /// <summary>
    /// Every class check describes the item through Plugin.Describe and asks Equipment.Allows about
    /// that description, which records a fishing rod as a two-handed weapon and nothing more. A rod is
    /// described as no weapon at all, which every class may hold.
    /// </summary>
    public static IEnumerable<PatchPlan> FishingRodPlan()
    {
        var describe = Hooks.Method(typeof(Plugin), "Describe", new[] { typeof(ItemDrop.ItemData), typeof(string) }, typeof(EquipmentItem));
        yield return new PatchPlan(describe) { Postfix = Hooks.Patch(typeof(GatheringTools), nameof(DescribeRodAsTool)) };
    }

    /// <summary>
    /// Plugin.MonkGather turns a bare-handed hit on a rock or tree into a gathering hit and raises
    /// Unarmed. Its one RaiseSkill call is redirected to the gathering skill of what was hit, which our
    /// own prefixes on the four Damage methods record before Oathbound's run.
    /// </summary>
    public static IEnumerable<PatchPlan> MonkGatheringPlan()
    {
        var gather = Hooks.Method(typeof(Plugin), "MonkGather", new[] { typeof(HitData), typeof(int) }, typeof(void));
        Hooks.Once(gather, "Character.RaiseSkill", ci => ci.Calls(RaiseSkill));
        yield return new PatchPlan(gather) { Transpiler = Hooks.Patch(typeof(GatheringTools), nameof(RedirectRaise)) };

        foreach (var (target, prefix) in new[]
        {
            (typeof(TreeBase), nameof(HittingWood)),
            (typeof(TreeLog), nameof(HittingWood)),
            (typeof(MineRock), nameof(HittingRock)),
            (typeof(MineRock5), nameof(HittingRock)),
        })
        {
            var damage = Hooks.Method(target, "Damage", new[] { typeof(HitData) }, typeof(void));
            yield return new PatchPlan(damage)
            {
                Prefix = Hooks.Patch(typeof(GatheringTools), prefix, Priority.First),
                Finalizer = Hooks.Patch(typeof(GatheringTools), nameof(HitDone)),
            };
        }
    }

    private static MethodInfo RaiseSkill => AccessTools.DeclaredMethod(typeof(Character), nameof(Character.RaiseSkill), new[] { typeof(Skills.SkillType), typeof(float) });

    [ThreadStatic] private static Skills.SkillType s_gathering;

    private static void DescribeRodAsTool(ItemDrop.ItemData item, ref EquipmentItem __result)
    {
        if (item != null && IsFishingRod(item))
        {
            __result = default;
        }
    }

    /// <summary>
    /// The vanilla rod has no skill (None) and its own attack projectile is a placeholder: the bait it
    /// shoots as ammo carries the FishingFloat (FishingFloat.Setup receives the ammo). It is recognised
    /// by name, and any modded rod by firing bait.
    /// </summary>
    private static bool IsFishingRod(ItemDrop.ItemData item) =>
        item.m_shared.m_name == "$item_fishingrod"
        || item.m_shared.m_skillType == Skills.SkillType.Fishing
        || (item.m_shared.m_ammoType ?? "").IndexOf("bait", StringComparison.OrdinalIgnoreCase) >= 0;

    private static void HittingWood() => s_gathering = Skills.SkillType.WoodCutting;

    private static void HittingRock() => s_gathering = Skills.SkillType.Pickaxes;

    private static Exception? HitDone(Exception? __exception)
    {
        s_gathering = Skills.SkillType.None;
        return __exception;
    }

    private static IEnumerable<CodeInstruction> RedirectRaise(IEnumerable<CodeInstruction> instructions)
    {
        MethodInfo raise = RaiseSkill;
        foreach (CodeInstruction instruction in instructions)
        {
            if (instruction.Calls(raise))
            {
                instruction.opcode = OpCodes.Call;
                instruction.operand = AccessTools.DeclaredMethod(typeof(GatheringTools), nameof(RaiseGathering));
            }
            yield return instruction;
        }
    }

    /// <summary>Stands in for <c>player.RaiseSkill(Unarmed, amount)</c> inside MonkGather.</summary>
    private static void RaiseGathering(Character character, Skills.SkillType skill, float amount) =>
        character.RaiseSkill(s_gathering != Skills.SkillType.None ? s_gathering : skill, amount);
}
