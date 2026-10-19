using System.Collections.Generic;
using System.Linq;
using UnityEngine;

namespace Lembitu.Callings;

/// <summary>
/// A death names what it cost and what the Calling kept (#123). The drain's own message, a generic
/// "$msg_skills_lowered" from vanilla or World Advancement Progression, read as if focus skills had
/// dropped too. It is held back while SkillHooks handles the death, and this message is shown once
/// the focus skills are back. With this feature off the generic message shows as before.
/// </summary>
internal static class DeathMessage
{
    private const string SkillsLowered = "$msg_skills_lowered";

    private static bool s_holding;

    public static bool On { get; set; }

    public static IEnumerable<PatchPlan> Plan()
    {
        var message = Hooks.Method(typeof(Player), nameof(Player.Message),
            new[] { typeof(MessageHud.MessageType), typeof(string), typeof(int), typeof(Sprite), typeof(bool) }, typeof(void));
        yield return new PatchPlan(message) { Prefix = Hooks.Patch(typeof(DeathMessage), nameof(BeforeMessage)) };
    }

    /// <summary>A death of the local player starts lowering skills.</summary>
    public static void Hold() => s_holding = On;

    /// <summary>The death's skill handling is done: show this message in place of the generic one.</summary>
    public static void Show(Player player, Calling calling, float factor)
    {
        bool held = s_holding;
        s_holding = false;
        if (held && factor > 0f && SkillRules.DrainsOnDeath)
        {
            player.Message(MessageHud.MessageType.TopLeft, Text(calling, factor, SkillRules.DrainFloor));
        }
    }

    private static bool BeforeMessage(string msg) => !(s_holding && msg == SkillsLowered);

    private static string Text(Calling calling, float factor, float floor)
    {
        string lost = floor > 0f
            ? $"Skills above {floor:0} lost {factor * 100f:0.#}%"
            : $"Skills lost {factor * 100f:0.#}%";
        string[] kept = calling.Focuses
            .Select(f => Professions.TryGet(f.Key, out Profession p) ? p.DisplayName : null)
            .OfType<string>()
            .ToArray();
        return kept.Length == 0 ? lost + "." : $"{lost}; your Calling kept {string.Join(", ", kept)}.";
    }
}
