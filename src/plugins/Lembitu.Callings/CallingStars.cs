using System;
using System.Collections.Generic;
using HarmonyLib;
using UnityEngine;
using UnityEngine.UI;

namespace Lembitu.Callings;

/// <summary>
/// Each profession row of the skills window carries a star showing the Calling (ADR-0022). The star
/// is its own marker beside the row, because DetailedLevels replaces the row's own click with its
/// skill-buff toggle. Since the Calling window of 2026-10-05 the star changes nothing: it shows the
/// Calling and carries the tooltip; the Calling is changed in the window opened from the Calling
/// button.
/// </summary>
internal static class CallingStars
{
    private const string StarName = "LembituCallingStar";

    private static readonly Color FocusColour = new(1f, 0.78f, 0.25f, 1f);
    private static readonly Color OtherColour = new(0.75f, 0.72f, 0.66f, 0.45f);

    /// <summary>
    /// Runs after DetailedLevels' Setup postfixes (priorities 700 and 100). Rows follow
    /// GetSkillList, which inside Setup is the same filtered (ImpactfulSkills) and sorted
    /// (DetailedLevels) list Setup used, because ImpactfulSkills lifts its filter only in a finalizer.
    /// </summary>
    public static IEnumerable<PatchPlan> Plan()
    {
        var setup = Hooks.Method(typeof(SkillsDialog), nameof(SkillsDialog.Setup), new[] { typeof(Player) }, typeof(void));
        Hooks.Field(typeof(SkillsDialog), "m_elements", typeof(List<GameObject>));
        Hooks.Field(typeof(SkillsDialog), nameof(SkillsDialog.m_tooltipAnchor), typeof(RectTransform));
        Hooks.Field(typeof(ZNetScene), "m_instances", typeof(Dictionary<ZDO, ZNetView>));
        yield return new PatchPlan(setup) { Postfix = Hooks.Patch(typeof(CallingStars), nameof(AfterSetup), Priority.Last) };
    }

    private static void AfterSetup(SkillsDialog __instance, Player player)
    {
        if (player != Player.m_localPlayer)
        {
            return;
        }
        List<Skills.Skill> skills = player.GetSkills().GetSkillList();
        List<GameObject> rows = __instance.m_elements;
        bool atStone = Oathstone.IsNear(player);
        for (int i = 0; i < rows.Count; i++)
        {
            Transform? star = FindStar(rows[i]);
            if (i >= skills.Count || !Professions.TryGet(skills[i].m_info.m_skill, out Profession profession))
            {
                star?.gameObject.SetActive(false);
                continue;
            }
            Show(star ?? Create(rows[i]), __instance, rows[i], profession, player, atStone);
        }
    }

    private static Transform IconOf(GameObject row) =>
        Utils.FindChild(row.transform, "icon_bkg") ?? Utils.FindChild(row.transform, "icon") ?? row.transform;

    /// <summary>Rows are reused and re-sorted, so a row's star is found by its name prefix.</summary>
    private static Transform? FindStar(GameObject row)
    {
        foreach (Transform child in IconOf(row))
        {
            if (child.name.StartsWith(StarName, StringComparison.Ordinal))
            {
                return child;
            }
        }
        return null;
    }

    /// <summary>A badge on the top-left corner of the skill's icon, clear of the skill's name. No
    /// Button; its raycastable Image keeps the tooltip reachable, while clicks belong to the row
    /// (DetailedLevels), not to the Calling.</summary>
    private static Transform Create(GameObject row)
    {
        Transform icon = IconOf(row);
        var star = new GameObject(StarName, typeof(RectTransform), typeof(Image));
        var rect = (RectTransform)star.transform;
        rect.SetParent(icon, worldPositionStays: false);
        rect.anchorMin = rect.anchorMax = new Vector2(0f, 1f);
        rect.pivot = new Vector2(0.5f, 0.5f);
        rect.sizeDelta = new Vector2(22f, 22f);
        rect.anchoredPosition = new Vector2(2f, -2f);
        var image = star.GetComponent<Image>();
        image.sprite = StarSprite.Get();
        image.preserveAspect = true;
        image.raycastTarget = true;
        var tooltip = star.AddComponent<UITooltip>();
        tooltip.m_tooltipPrefab = row.GetComponentInChildren<UITooltip>(includeInactive: true)?.m_tooltipPrefab;
        return star.transform;
    }

    private static void Show(Transform star, SkillsDialog dialog, GameObject row, Profession profession, Player player, bool atStone)
    {
        star.gameObject.SetActive(true);
        star.name = StarName + "." + profession.Key;
        star.SetAsLastSibling();
        Calling calling = CallingStore.Of(player);
        bool focus = calling.IsFocus(profession.Type);
        star.GetComponent<Image>().color = focus ? FocusColour : OtherColour;

        string group = Professions.Describe(profession.Group);
        string topic = focus ? $"In your Calling ({group})" : $"{group} profession";
        string state = focus
            ? "Levels at full speed and keeps its progress when you die."
            : $"Not in your Calling: gains at x{Settings.Rate(player.GetSkills().GetSkill(profession.Type).m_level):0.##} at its level.";
        string action;
        if (!CallingStore.IsReadable(player))
        {
            action = "Your Calling record could not be read; ask an admin.";
        }
        else if (focus && !atStone)
        {
            action = "Open the Calling window from the button below the list; changes happen at the Oathstone.";
        }
        else
        {
            action = "Open the Calling window from the button below the list.";
        }
        var rowRect = (RectTransform)row.transform;
        star.GetComponent<UITooltip>().Set(topic, state + "\n" + action, dialog.m_tooltipAnchor,
            new Vector2(0f, Math.Min(255f, rowRect.localPosition.y + 10f)));
    }

    /// <summary>Re-runs the skills dialog's Setup, so the stars follow a Calling changed in the window.</summary>
    internal static void Refresh(Player player)
    {
        if (InventoryGui.instance != null && InventoryGui.instance.m_skillsDialog.gameObject.activeInHierarchy)
        {
            InventoryGui.instance.m_skillsDialog.Setup(player);
        }
    }
}

/// <summary>
/// Finds Oathbound's Oathstone by its network prefab, without linking Oathbound: it is the
/// "WarriorOathstone" prefab Oathbound registers in ZNetScene beside the start temple.
/// </summary>
internal static class Oathstone
{
    private static readonly int PrefabHash = "WarriorOathstone".GetStableHashCode();

    public static bool IsNear(Player player)
    {
        if (ZNetScene.instance == null)
        {
            return false;
        }
        Vector3 at = player.transform.position;
        float range = Settings.OathstoneRange * Settings.OathstoneRange;
        foreach (ZDO zdo in ZNetScene.instance.m_instances.Keys)
        {
            if (zdo.GetPrefab() == PrefabHash && (zdo.GetPosition() - at).sqrMagnitude <= range)
            {
                return true;
            }
        }
        return false;
    }
}
