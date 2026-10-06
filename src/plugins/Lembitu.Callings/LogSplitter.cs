using System.Collections.Generic;
using System.Reflection;
using UnityEngine;

namespace Lembitu.Callings;

/// <summary>
/// Wood Cutting's milestone (ADR-0030): from Wood Cutting 50 a chop on a fallen log has a chance, 10%
/// rising to 30% at 100, to split the whole log, its half logs included, into wood at once. The
/// chopper's client rolls, because only it knows its own skill, including work meals and gear the way
/// every perk reads it. The log's owner then runs vanilla's TreeLog.Destroy on the log and on every
/// half log it spawns, so the drops are exactly vanilla's plus the ImpactfulSkills and EpicLoot bonuses
/// that hook that method. The skipped chops also skip their skill XP; the split saves time, not levels.
/// </summary>
internal static class LogSplitter
{
    private const string Rpc = "LembituCallings_SplitLog";

    /// <summary>Half logs spawned while a split runs, split in turn once their parent is gone.</summary>
    private static List<TreeLog>? s_spawned;

    public static IEnumerable<PatchPlan> Plan()
    {
        MethodInfo awake = Hooks.Method(typeof(TreeLog), "Awake", System.Type.EmptyTypes, typeof(void));
        MethodInfo damage = Hooks.Method(typeof(TreeLog), nameof(TreeLog.Damage), new[] { typeof(HitData) }, typeof(void));
        Hooks.Method(typeof(TreeLog), "Destroy", new[] { typeof(HitData), typeof(bool) }, typeof(void));
        Hooks.Field(typeof(TreeLog), "m_nview", typeof(ZNetView));
        Hooks.Field(typeof(TreeLog), "m_firstFrame", typeof(bool));
        yield return new PatchPlan(awake) { Postfix = Hooks.Patch(typeof(LogSplitter), nameof(AfterAwake)) };
        yield return new PatchPlan(damage) { Prefix = Hooks.Patch(typeof(LogSplitter), nameof(BeforeDamage), HarmonyLib.Priority.Last) };
    }

    private static void AfterAwake(TreeLog __instance)
    {
        ZNetView nview = __instance.m_nview;
        if (nview == null || !nview.IsValid())
        {
            return;
        }
        nview.Register<HitData>(Rpc, (_, hit) => Split(__instance, hit));
        s_spawned?.Add(__instance);
    }

    /// <summary>On the chopper's client: a successful roll sends the split instead of the chop.</summary>
    private static bool BeforeDamage(TreeLog __instance, HitData hit)
    {
        Player player = Player.m_localPlayer;
        ZNetView nview = __instance.m_nview;
        if (player == null || hit == null || hit.m_attacker != player.GetZDOID() || hit.m_damage.m_chop <= 0f
            || __instance.m_firstFrame || nview == null || !nview.IsValid())
        {
            return true;
        }
        float chance = Settings.LogSplitterChance(player.GetSkillLevel(Skills.SkillType.WoodCutting));
        if (chance <= 0f || Random.value >= chance)
        {
            return true;
        }
        nview.InvokeRPC(Rpc, hit);
        return false;
    }

    /// <summary>On the log's owner: the log and everything it splits into become wood now.</summary>
    private static void Split(TreeLog log, HitData hit)
    {
        ZNetView nview = log.m_nview;
        if (log == null || nview == null || !nview.IsValid() || !nview.IsOwner()
            || nview.GetZDO().GetFloat(ZDOVars.s_health, log.m_health) <= 0f || !hit.CheckToolTier(log.m_minToolTier, alwaysAllowTierZero: true))
        {
            return;
        }
        Character attacker = hit.GetAttacker();
        bool cheated = attacker != null && attacker == Player.m_localPlayer && ((Player)attacker).GetInventory().CheatedDamagingItemEquipped();
        var pending = new Queue<TreeLog>();
        pending.Enqueue(log);
        while (pending.Count > 0)
        {
            TreeLog next = pending.Dequeue();
            var spawned = new List<TreeLog>();
            List<TreeLog>? outer = s_spawned;
            s_spawned = spawned;
            try
            {
                next.m_nview.GetZDO().Set(ZDOVars.s_health, 0f);
                next.Destroy(hit, cheated);
            }
            finally
            {
                s_spawned = outer;
            }
            foreach (TreeLog half in spawned)
            {
                pending.Enqueue(half);
            }
        }
    }
}
