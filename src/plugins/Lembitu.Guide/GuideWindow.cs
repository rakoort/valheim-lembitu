using System;
using System.Collections.Generic;
using Jotunn.Managers;
using UnityEngine;
using UnityEngine.UI;

namespace Lembitu.Guide;

/// <summary>
/// The guide window (ADR-0027): a draggable Jotunn wood panel with a chapter bar (one button per
/// page, in contract order), a scrolling body and Prev/Next/Close. Keyboard and mouse only, by
/// decision; built lazily on first open so Jotunn's fonts and control assets exist, and re-rendered
/// from the server's content whenever it changes. Blocks game input while open, like the map.
/// </summary>
internal static class GuideWindow
{
    public const string FirstPageId = "first-steps";

    private const float Width = 660f;
    private const float Height = 600f;
    private const int ChapterColumns = 3;
    private const float ChapterBarWidth = (Width - 40f) / ChapterColumns;
    private const float ChapterBarHeight = 28f;

    private static GameObject? s_panel;
    private static Text s_pageTitle = null!;
    private static Text s_body = null!;
    private static readonly List<GameObject> s_chapterButtons = new();
    private static int s_builtForPageCount = -1;
    private static int s_pageIndex;
    private static bool s_rerenderQueued;

    public static bool IsOpen => s_panel != null && s_panel.activeSelf;

    /// <summary>Verify the exact Jotunn overloads used to build and control the window.</summary>
    public static void Verify()
    {
        Hooks.Method(typeof(GUIManager), nameof(GUIManager.CreateWoodpanel),
            new[] { typeof(Transform), typeof(Vector2), typeof(Vector2), typeof(Vector2), typeof(float), typeof(float), typeof(bool) },
            typeof(GameObject));
        Hooks.Method(typeof(GUIManager), nameof(GUIManager.CreateScrollView),
            new[] { typeof(Transform), typeof(bool), typeof(bool), typeof(float), typeof(float), typeof(ColorBlock), typeof(Color), typeof(float), typeof(float) },
            typeof(GameObject));
        Hooks.Method(typeof(GUIManager), nameof(GUIManager.CreateText),
            new[] { typeof(string), typeof(Transform), typeof(Vector2), typeof(Vector2), typeof(Vector2), typeof(Font), typeof(int), typeof(Color), typeof(bool), typeof(Color), typeof(float), typeof(float), typeof(bool) },
            typeof(GameObject));
        Hooks.Method(typeof(GUIManager), nameof(GUIManager.CreateButton),
            new[] { typeof(string), typeof(Transform), typeof(Vector2), typeof(Vector2), typeof(Vector2), typeof(float), typeof(float) },
            typeof(GameObject));
        Hooks.Method(typeof(GUIManager), nameof(GUIManager.BlockInput), new[] { typeof(bool) }, typeof(void));
        Hooks.Property(typeof(GUIManager), nameof(GUIManager.AveriaSerif), typeof(Font));
        Hooks.Method(typeof(ZInput), nameof(ZInput.GetKeyDown), new[] { typeof(KeyCode), typeof(bool) }, typeof(bool));
        Hooks.Method(typeof(ZInput), nameof(ZInput.GetKey), new[] { typeof(KeyCode), typeof(bool) }, typeof(bool));
    }

    /// <summary>Content arrived or changed while the window may be on screen.</summary>
    public static void OnContentChanged()
    {
        if (IsOpen)
        {
            s_rerenderQueued = true;
        }
    }

    public static void Toggle() => TogglePage(null);

    /// <summary>Opens the window on the named page id (falls back to the first page) or toggles it closed.</summary>
    public static void TogglePage(string? pageId)
    {
        if (IsOpen && pageId == null)
        {
            Hide();
            return;
        }
        Show(pageId);
    }

    public static void Show(string? pageId)
    {
        try
        {
            EnsureBuilt();
        }
        catch (Exception error)
        {
            GuidePlugin.ClientLog.LogWarning($"Guide window could not be built: {error.Message}");
            return;
        }
        IReadOnlyList<GuidePage> pages = GuideContent.Ordered();
        if (pageId != null)
        {
            for (int i = 0; i < pages.Count; i++)
            {
                if (pages[i].Id == pageId)
                {
                    s_pageIndex = i;
                    break;
                }
            }
        }
        bool wasOpen = IsOpen;
        s_panel!.SetActive(true);
        if (!wasOpen)
        {
            GUIManager.BlockInput(true);
        }
        Render();
    }

    public static void Hide()
    {
        if (!IsOpen)
        {
            return;
        }
        s_panel!.SetActive(false);
        GUIManager.BlockInput(false);
    }

    /// <summary>Close and forget the previous server's displayed pages.</summary>
    public static void Clear()
    {
        Hide();
        s_pageIndex = 0;
        s_rerenderQueued = false;
        foreach (GameObject button in s_chapterButtons)
        {
            if (button != null)
            {
                UnityEngine.Object.Destroy(button);
            }
        }
        s_chapterButtons.Clear();
        s_builtForPageCount = -1;
        if (s_panel != null)
        {
            s_pageTitle.text = "";
            s_body.text = "";
        }
    }

    /// <summary>The hotkey. Keyboard edge only; the window's own buttons cover the mouse.</summary>
    public static void Tick()
    {
        if (s_rerenderQueued)
        {
            s_rerenderQueued = false;
            if (IsOpen)
            {
                Render();
            }
        }
        if (GuidePlugin.IsHeadless || (Chat.instance != null && Chat.instance.HasFocus()))
        {
            return;
        }
        if (Settings.HotKeyIsDown())
        {
            Toggle();
        }
    }

    private static void EnsureBuilt()
    {
        if (s_panel != null)
        {
            return;
        }
        if (GUIManager.CustomGUIFront == null)
        {
            throw new InvalidOperationException("Jotunn's custom GUI is not up yet");
        }

        // Scene changes destroy the old panel and its buttons along with Jotunn's GUI root.
        s_chapterButtons.Clear();
        s_builtForPageCount = -1;
        s_rerenderQueued = false;
        s_panel = GUIManager.Instance.CreateWoodpanel(GUIManager.CustomGUIFront.transform,
            new Vector2(0.5f, 0.5f), new Vector2(0.5f, 0.5f), Vector2.zero, Width, Height, draggable: true);
        s_panel.name = "LembituGuide";

        Text header = MakeText("Lembitu guide", s_panel.transform, new Vector2(0.5f, 1f), new Vector2(0.5f, 1f),
            new Vector2(0f, -22f), GUIManager.Instance.AveriaSerifBold, 26, GUIManager.Instance.ValheimOrange);
        header.rectTransform.sizeDelta = new Vector2(Width - 40f, 34f);

        s_pageTitle = MakeText("", s_panel.transform, new Vector2(0.5f, 1f), new Vector2(0.5f, 1f),
            new Vector2(0f, -54f), GUIManager.Instance.AveriaSerifBold, 20, Color.white);
        s_pageTitle.rectTransform.sizeDelta = new Vector2(Width - 40f, 28f);

        GameObject scroll = GUIManager.Instance.CreateScrollView(s_panel.transform,
            showHorizontalScrollbar: false, showVerticalScrollbar: true, handleSize: 10f,
            handleDistanceToBorder: 4f, handleColors: GUIManager.Instance.ValheimScrollbarHandleColorBlock,
            slidingAreaBackgroundColor: new Color(0f, 0f, 0f, 0.15f), width: Width - 40f, height: Height - 272f);
        RectTransform scrollRect = (RectTransform)scroll.transform;
        scrollRect.anchorMin = new Vector2(0.5f, 0.5f);
        scrollRect.anchorMax = new Vector2(0.5f, 0.5f);
        scrollRect.anchoredPosition = new Vector2(0f, -58f);
        Transform content = scroll.transform.Find("Scroll View/Viewport/Content");
        content.GetComponent<VerticalLayoutGroup>().childControlWidth = true;
        content.GetComponent<VerticalLayoutGroup>().spacing = 6f;

        s_body = MakeText("", content, new Vector2(0f, 1f), new Vector2(0f, 1f), Vector2.zero,
            GUIManager.Instance.AveriaSerif, 18, Color.white, contentSizeFitter: true);
        s_body.horizontalOverflow = HorizontalWrapMode.Wrap;
        s_body.verticalOverflow = VerticalWrapMode.Overflow;
        s_body.alignment = TextAnchor.UpperLeft;

        MakeButton("Close", s_panel.transform, new Vector2(0.5f, 0f), new Vector2(0.5f, 0f), new Vector2(0f, 14f), 140f, 36f)
            .onClick.AddListener(Hide);
        MakeButton("< Prev", s_panel.transform, new Vector2(0.5f, 0f), new Vector2(0.5f, 0f), new Vector2(-110f, 14f), 90f, 36f)
            .onClick.AddListener(() => Step(-1));
        MakeButton("Next >", s_panel.transform, new Vector2(0.5f, 0f), new Vector2(0.5f, 0f), new Vector2(110f, 14f), 90f, 36f)
            .onClick.AddListener(() => Step(1));

        s_panel.SetActive(false);
    }

    private static void Step(int direction)
    {
        IReadOnlyList<GuidePage> pages = GuideContent.Ordered();
        if (pages.Count == 0)
        {
            return;
        }
        s_pageIndex = (s_pageIndex + direction + pages.Count) % pages.Count;
        Render();
    }

    private static void Render()
    {
        IReadOnlyList<GuidePage> pages = GuideContent.Ordered();
        if (pages.Count == 0)
        {
            s_pageTitle.text = "Guide";
            s_body.text = "The server's guide has not arrived yet. It follows at the next join.";
            return;
        }
        s_pageIndex = Math.Min(s_pageIndex, pages.Count - 1);
        s_pageTitle.text = pages[s_pageIndex].Title;
        s_body.text = pages[s_pageIndex].Body;

        if (s_builtForPageCount != pages.Count)
        {
            BuildChapterBar(pages);
            s_builtForPageCount = pages.Count;
        }
        for (int i = 0; i < s_chapterButtons.Count && i < pages.Count; i++)
        {
            s_chapterButtons[i].GetComponentInChildren<Text>().color =
                i == s_pageIndex ? GUIManager.Instance.ValheimOrange : Color.white;
        }
    }

    private static void BuildChapterBar(IReadOnlyList<GuidePage> pages)
    {
        foreach (GameObject button in s_chapterButtons)
        {
            UnityEngine.Object.Destroy(button);
        }
        s_chapterButtons.Clear();

        for (int rowStart = 0; rowStart < pages.Count; rowStart += ChapterColumns)
        {
            int columns = Math.Min(ChapterColumns, pages.Count - rowStart);
            float rowWidth = columns * ChapterBarWidth;
            float y = -96f - rowStart / ChapterColumns * (ChapterBarHeight + 6f);
            for (int column = 0; column < columns; column++)
            {
                GuidePage page = pages[rowStart + column];
                float x = -rowWidth / 2f + ChapterBarWidth * column + ChapterBarWidth / 2f;
                Button button = MakeButton(page.Title, s_panel!.transform, new Vector2(0.5f, 1f), new Vector2(0.5f, 1f),
                    new Vector2(x, y), ChapterBarWidth - 8f, ChapterBarHeight);
                button.GetComponentInChildren<Text>().fontSize = 12;
                button.onClick.AddListener(() =>
                {
                    IReadOnlyList<GuidePage> all = GuideContent.Ordered();
                    for (int j = 0; j < all.Count; j++)
                    {
                        if (all[j].Id == page.Id)
                        {
                            s_pageIndex = j;
                            Render();
                            return;
                        }
                    }
                });
                s_chapterButtons.Add(button.gameObject);
            }
        }
    }

    private static Button MakeButton(string label, Transform parent, Vector2 anchorMin, Vector2 anchorMax, Vector2 position, float width, float height) =>
        GUIManager.Instance.CreateButton(label, parent, anchorMin, anchorMax, position, width, height).GetComponent<Button>();

    private static Text MakeText(string value, Transform parent, Vector2 anchorMin, Vector2 anchorMax, Vector2 position,
        Font font, int fontSize, Color color, bool contentSizeFitter = false) =>
        GUIManager.Instance.CreateText(value, parent, anchorMin, anchorMax, position, font, fontSize, color,
            outline: true, outlineColor: Color.black, width: 0f, height: 0f, addContentSizeFitter: contentSizeFitter)
            .GetComponent<Text>();
}
