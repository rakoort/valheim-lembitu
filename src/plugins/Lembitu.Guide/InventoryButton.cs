using UnityEngine;
using UnityEngine.UI;

namespace Lembitu.Guide;

/// <summary>
/// The Guide button in the inventory (ADR-0027): a Valheim-styled button in the player panel's top
/// corner, built the first time the inventory exists and toggling the window like the hotkey. It
/// lives under InventoryGui's own player panel, so it appears and hides with the inventory.
/// </summary>
internal static class InventoryButton
{
    private static Button? s_button;

    public static void Verify()
    {
        Hooks.Field(typeof(InventoryGui), nameof(InventoryGui.m_player), typeof(RectTransform));
    }

    /// <summary>Built lazily: InventoryGui.instance exists from scene load, but its panels only
    /// after the first show, and the button must survive into every later show.</summary>
    public static void Tick()
    {
        if (GuidePlugin.IsHeadless || s_button != null || InventoryGui.instance == null)
        {
            return;
        }
        RectTransform player = InventoryGui.instance.m_player;
        if (player == null)
        {
            return;
        }
        s_button = Jotunn.Managers.GUIManager.Instance.CreateButton("Guide", player,
            new Vector2(1f, 1f), new Vector2(1f, 1f), new Vector2(-64f, -18f), 104f, 30f)
            .GetComponent<Button>();
        s_button.GetComponentInChildren<Text>(true).fontSize = 14;
        s_button.onClick.AddListener(() => GuideWindow.Toggle());
        GuidePlugin.ClientLog.LogInfo("Inventory guide button built in the player panel.");
    }
}
