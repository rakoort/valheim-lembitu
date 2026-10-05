using System;
using System.Collections.Generic;
using HarmonyLib;
using Jotunn.Managers;
using UnityEngine;
using UnityEngine.UI;

namespace Lembitu.Callings;

/// <summary>
/// The Calling window (ADR-0021, ADR-0022; owner, 2026-10-05): a Calling button in the skills window
/// opens a window listing the eleven professions under Land, Craft and Road with the 2-1-1 quota,
/// each skill's level and shadow level, and what a focus changes. It can be read anywhere; a change
/// takes effect at once only within OathstoneRange of the Oathstone, and elsewhere the controls say
/// to go there. Dropping a focus asks for confirmation and names the level the skill falls to. The
/// first open records "lembitu.callings.window-seen" for the character (never cleared), which
/// Lembitu.Guide uses to open the Calling page once. Keyboard and mouse only, by decision.
/// </summary>
internal static class CallingWindow
{
    private const string ButtonName = "LembituCallingButton";
    private const string WindowName = "LembituCallingWindow";

    private static GameObject? _window;
    private static Transform? _rows;
    private static Text? _footer;

    public static IEnumerable<PatchPlan> Plan()
    {
        var setup = Hooks.Method(typeof(SkillsDialog), nameof(SkillsDialog.Setup), new[] { typeof(Player) }, typeof(void));
        yield return new PatchPlan(setup) { Postfix = Hooks.Patch(typeof(CallingWindow), nameof(AfterSetup), Priority.Last) };
    }

    /// <summary>The Calling button in the skills window. Created once; the dialog survives reopening.</summary>
    private static void AfterSetup(SkillsDialog __instance, Player player)
    {
        if (player != Player.m_localPlayer || __instance.transform.Find("SkillsFrame/" + ButtonName) != null)
        {
            return;
        }
        var close = __instance.transform.Find("SkillsFrame/Closebutton") as RectTransform;
        if (close == null)
        {
            Debug.LogWarning("Calling button: skills close button is missing.");
            return;
        }
        GameObject button = GUIManager.Instance.CreateButton("Calling", close.parent,
            close.anchorMin, close.anchorMax, close.anchoredPosition, close.rect.width, close.rect.height);
        var rect = (RectTransform)button.transform;
        rect.pivot = close.pivot;
        var options = close.parent.Find("DLOptionsButton") as RectTransform;
        var stats = close.parent.Find("DLStatsButton") as RectTransform;
        if (options != null && stats != null)
        {
            // Fit four controls into the existing footer, preserving its edges and vanilla row.
            float left = options.anchoredPosition.x - options.rect.width * options.pivot.x;
            float right = close.anchoredPosition.x + close.rect.width * (1f - close.pivot.x);
            const float gap = 6f;
            float width = (right - left - 3f * gap) / 4f;
            RectTransform[] footer = { options, stats, rect, close };
            for (int i = 0; i < footer.Length; ++i)
            {
                footer[i].SetSizeWithCurrentAnchors(RectTransform.Axis.Horizontal, width);
                footer[i].anchoredPosition = new Vector2(left + i * (width + gap) + width * footer[i].pivot.x, close.anchoredPosition.y);
            }
        }
        else
        {
            rect.anchoredPosition = close.anchoredPosition - new Vector2(close.rect.width + 8f, 0f);
        }
        button.name = ButtonName;
        button.transform.SetAsLastSibling();
        button.GetComponent<Button>().onClick.AddListener(Toggle);
    }

    private static void Toggle()
    {
        if (_window != null && _window.activeSelf)
        {
            _window.SetActive(false);
            return;
        }
        Open();
    }

    private static void Open()
    {
        Player player = Player.m_localPlayer;
        if (player == null || !CallingStore.IsReadable(player))
        {
            player?.Message(MessageHud.MessageType.Center, "Your Calling record could not be read; ask an admin. Guide: Calling (calling).");
            return;
        }
        if (GUIManager.CustomGUIFront == null)
        {
            player.Message(MessageHud.MessageType.Center, "The Calling window is not available yet. Guide: Calling (calling).");
            return;
        }
        if (_window == null)
        {
            Build();
        }
        _window!.SetActive(true);
        player.m_customData[CallingStore.WindowSeenKey] = "1";
        Rebuild();
    }

    private static void Build()
    {
        var window = new GameObject(WindowName, typeof(RectTransform));
        _window = window;
        window.AddComponent<Window>();
        var rect = (RectTransform)window.transform;
        rect.SetParent(GUIManager.CustomGUIFront.transform, worldPositionStays: false);
        rect.anchorMin = rect.anchorMax = new Vector2(0.5f, 0.5f);
        rect.anchoredPosition = new Vector2(350f, 0f);
        rect.sizeDelta = new Vector2(560f, 640f);
        GUIManager.Instance.CreateWoodpanel(window.transform, Vector2.zero, Vector2.one, Vector2.zero, 0f, 0f, draggable: false);

        Label(window.transform, "Calling", 16f, 12f, 300f, 34f, 26, GUIManager.Instance.ValheimOrange, bold: true);

        GameObject close = GUIManager.Instance.CreateButton("X", window.transform,
            new Vector2(1f, 1f), new Vector2(1f, 1f), new Vector2(-30f, -28f), 36f, 30f);
        close.GetComponent<Button>().onClick.AddListener(() => _window!.SetActive(false));

        Label(window.transform,
            "Your Calling is two Land professions, one Craft and one Road. A focus levels at full speed and keeps its"
            + " level when you die; its shadow level is what it would be without the focus. Dropping a focus sets the"
            + " skill to its shadow.",
            16f, 54f, 528f, 76f, 14, GUIManager.Instance.ValheimBeige);

        var rows = new GameObject("Rows", typeof(RectTransform));
        _rows = rows.transform;
        _rows.SetParent(window.transform, worldPositionStays: false);
        var rowsRect = (RectTransform)_rows;
        rowsRect.anchorMin = Vector2.zero;
        rowsRect.anchorMax = Vector2.one;
        rowsRect.offsetMin = new Vector2(0f, 52f);
        rowsRect.offsetMax = new Vector2(0f, -140f);

        _footer = Label(window.transform, "", 16f, 596f, 528f, 36f, 14, GUIManager.Instance.ValheimYellow);
    }

    private static void Rebuild()
    {
        if (_window == null || !_window.activeSelf || _rows == null)
        {
            return;
        }
        Player player = Player.m_localPlayer;
        Calling calling = CallingStore.Of(player);
        bool readable = CallingStore.IsReadable(player);
        bool atStone = readable && Oathstone.IsNear(player);
        for (int i = _rows.childCount - 1; i >= 0; i--)
        {
            UnityEngine.Object.Destroy(_rows.GetChild(i).gameObject);
        }
        float y = 6f;
        foreach (ProfessionGroup group in new[] { ProfessionGroup.Land, ProfessionGroup.Craft, ProfessionGroup.Road })
        {
            Label(_rows, $"{Professions.Describe(group)} — choose {Professions.Quota(group)}"
                + $" ({calling.CountIn(group)} of {Professions.Quota(group)} chosen)",
                16f, y, 400f, 24f, 16, GUIManager.Instance.ValheimOrange, bold: true);
            y += 28f;
            foreach (Profession profession in Professions.All)
            {
                if (profession.Group != group)
                {
                    continue;
                }
                bool focus = calling.IsFocus(profession.Type);
                int level = (int)player.GetSkills().GetSkill(profession.Type).m_level;
                Label(_rows, (focus ? "★ " : "") + profession.DisplayName, 24f, y, 190f, 24f, 16,
                    focus ? GUIManager.Instance.ValheimYellow : GUIManager.Instance.ValheimBeige);
                Label(_rows, level.ToString(), 216f, y, 70f, 24f, 16, GUIManager.Instance.ValheimBeige);
                Label(_rows, $"shadow {(focus ? FallsTo(calling, profession) : level)}", 288f, y, 120f, 24f, 16,
                    GUIManager.Instance.ValheimBeige);
                string label = focus ? "Drop" : calling.HasRoomFor(profession) ? "Add" : "Full";
                GameObject button = GUIManager.Instance.CreateButton(label, _rows,
                    new Vector2(0f, 1f), new Vector2(0f, 1f), new Vector2(454f, -y), 84f, 24f);
                ((RectTransform)button.transform).pivot = new Vector2(0f, 1f);
                button.GetComponent<Button>().interactable = atStone && (focus || calling.HasRoomFor(profession));
                Profession chosen = profession;
                button.GetComponent<Button>().onClick.AddListener(() => Change(chosen));
                y += 30f;
            }
            y += 8f;
        }
        _footer!.text = !readable ? "Your Calling record could not be read; ask an admin."
            : atStone ? "Standing at the Oathstone: changes take effect at once."
            : "To change your Calling, stand at the Oathstone beside the start temple.";
    }

    private static void Change(Profession profession)
    {
        Player player = Player.m_localPlayer;
        if (player == null || !CallingStore.IsReadable(player))
        {
            return;
        }
        if (!Oathstone.IsNear(player))
        {
            player.Message(MessageHud.MessageType.Center, "Change your Calling at the Oathstone. Guide: Calling (calling).");
            return;
        }
        Calling calling = CallingStore.Of(player);
        if (calling.IsFocus(profession.Type))
        {
            AskDrop(player, calling, profession);
            return;
        }
        if (!calling.HasRoomFor(profession))
        {
            player.Message(MessageHud.MessageType.Center,
                $"Your Calling already holds {Professions.Quota(profession.Group)} {Professions.Describe(profession.Group)}; drop one first. Guide: Calling (calling).");
            return;
        }
        calling.Add(profession, player.GetSkills().GetSkill(profession.Type));
        CallingStore.Save(player);
        player.Message(MessageHud.MessageType.Center, $"{profession.DisplayName} joins your Calling.");
        Refresh();
    }

    /// <summary>The drop names the level the skill falls to, and re-checks the Oathstone when answered:
    /// the player cannot walk away mid-question, but the stone could be unloading.</summary>
    private static void AskDrop(Player player, Calling calling, Profession profession)
    {
        Skills.Skill skill = player.GetSkills().GetSkill(profession.Type);
        int falls = FallsTo(calling, profession);
        _window!.SetActive(false);
        UnifiedPopup.Push(new YesNoPopup(
            $"Drop {profession.DisplayName}?",
            $"{profession.DisplayName} leaves your Calling and falls from level {(int)skill.m_level} to {falls}, the level it would have without the focus.",
            () =>
            {
                UnifiedPopup.Pop();
                if (Player.m_localPlayer == player && Oathstone.IsNear(player) && calling.IsFocus(profession.Type))
                {
                    calling.Drop(profession, skill);
                    CallingStore.Save(player);
                    player.Message(MessageHud.MessageType.Center, $"{profession.DisplayName} left your Calling at level {falls}.");
                    Refresh();
                }
                if (Player.m_localPlayer == player)
                {
                    Open();
                }
            },
            () =>
            {
                UnifiedPopup.Pop();
                if (Player.m_localPlayer == player)
                {
                    Open();
                }
            },
            localizeText: false));
    }

    private static int FallsTo(Calling calling, Profession profession) =>
        calling.TryGetShadow(profession.Type, out Shadow shadow) ? (int)shadow.Level : 0;

    private static void Refresh()
    {
        Rebuild();
        CallingStars.Refresh(Player.m_localPlayer);
    }

    private static Text Label(Transform parent, string content, float x, float y, float width, float height, int size, Color colour, bool bold = false)
    {
        GameObject go = GUIManager.Instance.CreateText(content, parent,
            new Vector2(0f, 1f), new Vector2(0f, 1f), new Vector2(x, -y),
            bold ? GUIManager.Instance.AveriaSerifBold : GUIManager.Instance.AveriaSerif,
            size, colour, outline: true, Color.black, width, height, addContentSizeFitter: false);
        ((RectTransform)go.transform).pivot = new Vector2(0f, 1f);
        Text text = go.GetComponent<Text>();
        text.alignment = TextAnchor.UpperLeft;
        text.raycastTarget = false;
        return text;
    }

    /// <summary>The window belongs to the skills dialog: it hides when the dialog closes, and dies with
    /// the scene, so a destroyed window is simply built again on the next open.</summary>
    private sealed class Window : MonoBehaviour
    {
        private void Update()
        {
            InventoryGui gui = InventoryGui.instance;
            if (gui == null || gui.m_skillsDialog == null || !gui.m_skillsDialog.gameObject.activeInHierarchy)
            {
                gameObject.SetActive(false);
            }
        }
    }
}
