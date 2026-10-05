using UnityEngine;
using UnityEngine.UI;

namespace Lembitu.Guide;

/// <summary>
/// The Guide button joins the inventory's native character-header controls. Six controls fit
/// inside the existing Texts-to-PvP row, anchored to those elements rather than the inventory grid.
/// It appears and hides with that panel and leaves equipment, quick slots and crafting untouched.
/// </summary>
internal static class InventoryButton
{
    private static Button? s_button;

    public static void Verify()
    {
        Hooks.Field(typeof(InventoryGui), nameof(InventoryGui.m_info), typeof(RectTransform));
        Hooks.Field(typeof(InventoryGui), nameof(InventoryGui.m_pvp), typeof(Toggle));
    }

    /// <summary>Built lazily: InventoryGui.instance exists from scene load, but its panels only
    /// after the first show, and the button must survive into every later show.</summary>
    public static void Tick()
    {
        if (GuidePlugin.IsHeadless || s_button != null || InventoryGui.instance == null)
        {
            return;
        }
        InventoryGui gui = InventoryGui.instance;
        RectTransform info = gui.m_info;
        if (info == null || gui.m_pvp == null) return;
        var texts = info.Find("Texts") as RectTransform;
        var skills = info.Find("Skills") as RectTransform;
        var trophies = info.Find("Trophies") as RectTransform;
        var achievements = info.Find("Achievements") as RectTransform;
        if (texts == null || skills == null || trophies == null || achievements == null) return;
        var pvp = (RectTransform)gui.m_pvp.transform;
        float left = texts.anchoredPosition.x;
        float step = (pvp.anchoredPosition.x - left) / 5f;
        s_button = Jotunn.Managers.GUIManager.Instance.CreateButton("Guide", texts.parent,
            texts.anchorMin, texts.anchorMax, texts.anchoredPosition, texts.rect.width, 30f)
            .GetComponent<Button>();
        s_button.name = "LembituGuideButton";
        var guide = (RectTransform)s_button.transform;
        guide.pivot = texts.pivot;
        RectTransform[] row = { guide, texts, skills, trophies, achievements, pvp };
        for (int i = 0; i < row.Length; ++i)
            row[i].anchoredPosition = new Vector2(left + step * i, texts.anchoredPosition.y);
        s_button.GetComponentInChildren<Text>(true).fontSize = 14;
        s_button.onClick.AddListener(() => GuideWindow.Toggle());
        GuidePlugin.ClientLog.LogInfo("Inventory guide button built in the native character-header row.");
    }
}
