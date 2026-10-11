using System.Collections.Generic;
using Jotunn.Managers;
using UnityEngine;
using UnityEngine.UI;

namespace Lembitu.Guilds;

/// <summary>Other guild members, under the vanilla HUD so its visibility controls apply.</summary>
internal static class GuildMemberHud
{
    private const float Width = 256f;
    private const float RowHeight = 48f;
    private static readonly List<Row> Rows = new(4);
    private static GameObject? s_root;
    private static Hud? s_hud;
    private static float s_nextRefresh;

    private sealed class Row
    {
        public GameObject Root = null!;
        public CanvasGroup Opacity = null!;
        public Text Name = null!;
        public Text Status = null!;
        public Image Bar = null!;
        public RectTransform Fill = null!;
        public int Distance = int.MinValue;
    }

    public static void Reset()
    {
        if (s_root != null) Object.Destroy(s_root);
        s_root = null;
        s_hud = null;
        Rows.Clear();
        s_nextRefresh = 0f;
    }

    public static void Tick()
    {
        Hud? hud = Hud.instance;
        if (s_hud != hud) Reset();
        Player? player = Player.m_localPlayer;
        bool visible = hud != null && hud.m_rootObject != null && player != null &&
            Time.unscaledTime - GuildRoster.ReceivedAt <= 3f && GuildRoster.Members.Count > 1;
        if (!visible)
        {
            if (s_root != null) s_root.SetActive(false);
            return;
        }
        if (Time.unscaledTime < s_nextRefresh) return;
        s_nextRefresh = Time.unscaledTime + 0.2f;
        long localPid = player!.GetPlayerID();
        // Never display a roster addressed to a different local character after a character change.
        bool containsLocal = false;
        foreach (GuildRoster.MemberState member in GuildRoster.Members)
            if (member.Pid == localPid) containsLocal = true;
        if (!containsLocal)
        {
            if (s_root != null) s_root.SetActive(false);
            return;
        }
        if (s_root == null) Build(hud!);
        int rowIndex = 0;
        Vector3 localPosition = player.transform.position;
        foreach (GuildRoster.MemberState member in GuildRoster.Members)
        {
            if (member.Pid == localPid) continue;
            if (rowIndex == Rows.Count) Rows.Add(BuildRow(rowIndex));
            Row row = Rows[rowIndex++];
            row.Root.SetActive(true);
            row.Name.text = member.Name;
            row.Opacity.alpha = member.Online && !member.Dead ? 1f : 0.5f;
            row.Bar.gameObject.SetActive(member.Online && !member.Dead);
            if (!member.Online || member.Dead)
            {
                row.Status.text = member.Online ? "dead" : "offline";
                row.Distance = int.MinValue;
            }
            else
            {
                float dx = member.X - localPosition.x;
                float dz = member.Z - localPosition.z;
                int distance = Mathf.RoundToInt(Mathf.Sqrt(dx * dx + dz * dz));
                if (row.Distance != distance)
                {
                    row.Distance = distance;
                    row.Status.text = $"{distance} m";
                }
                row.Fill.anchorMax = new Vector2(member.MaxHealth > 0f ? member.Health / member.MaxHealth : 0f, 1f);
            }
        }
        for (int i = rowIndex; i < Rows.Count; ++i) Rows[i].Root.SetActive(false);
        s_root!.SetActive(rowIndex > 0);
    }

    private static void Build(Hud hud)
    {
        s_hud = hud;
        s_root = new GameObject("Lembitu_GuildMembers", typeof(RectTransform));
        s_root.layer = hud.m_rootObject.layer;
        s_root.transform.SetParent(hud.m_rootObject.transform, false);
        RectTransform rect = (RectTransform)s_root.transform;
        rect.anchorMin = rect.anchorMax = new Vector2(0f, 0.5f);
        rect.pivot = new Vector2(0f, 1f);
        rect.anchoredPosition = new Vector2(20f, 0f);
        rect.sizeDelta = new Vector2(Width, RowHeight * 4f);
    }

    private static Row BuildRow(int index)
    {
        Image backing = Image(s_root!.transform, "Member", 0f, -index * (RowHeight + 4f), Width, RowHeight,
            new Color(0.09f, 0.07f, 0.05f, 0.72f));
        var row = new Row
        {
            Root = backing.gameObject,
            Opacity = backing.gameObject.AddComponent<CanvasGroup>(),
            Name = Text(backing.transform, 8f, -2f, 240f, 23f, 16, TextAnchor.MiddleLeft),
            Status = Text(backing.transform, 184f, -25f, 64f, 18f, 13, TextAnchor.MiddleRight),
            Bar = Image(backing.transform, "Health", 8f, -29f, 166f, 10f, new Color(0.12f, 0.08f, 0.06f, 0.95f)),
        };
        row.Opacity.blocksRaycasts = false;
        row.Opacity.interactable = false;
        Image fill = Image(row.Bar.transform, "Fill", 0f, 0f, 0f, 0f, new Color(0.62f, 0.16f, 0.12f, 1f));
        row.Fill = (RectTransform)fill.transform;
        row.Fill.anchorMin = Vector2.zero;
        row.Fill.anchorMax = Vector2.one;
        row.Fill.offsetMin = Vector2.zero;
        row.Fill.offsetMax = Vector2.zero;
        return row;
    }

    private static Image Image(Transform parent, string name, float x, float y, float width, float height, Color color)
    {
        var obj = new GameObject(name, typeof(RectTransform), typeof(Image));
        obj.layer = parent.gameObject.layer;
        obj.transform.SetParent(parent, false);
        RectTransform rect = (RectTransform)obj.transform;
        rect.anchorMin = rect.anchorMax = new Vector2(0f, 1f);
        rect.pivot = new Vector2(0f, 1f);
        rect.anchoredPosition = new Vector2(x, y);
        rect.sizeDelta = new Vector2(width, height);
        Image image = obj.GetComponent<Image>();
        image.color = color;
        image.raycastTarget = false;
        return image;
    }

    private static Text Text(Transform parent, float x, float y, float width, float height, int size, TextAnchor alignment)
    {
        GUIManager gui = GUIManager.Instance;
        GameObject obj = gui.CreateText("", parent, new Vector2(0f, 1f), new Vector2(0f, 1f),
            Vector2.zero, gui.AveriaSerifBold, size, gui.ValheimBeige, true,
            new Color(0f, 0f, 0f, 0.95f), width, height, false);
        obj.layer = parent.gameObject.layer;
        RectTransform rect = (RectTransform)obj.transform;
        rect.pivot = new Vector2(0f, 1f);
        rect.anchoredPosition = new Vector2(x, y);
        Text text = obj.GetComponent<Text>();
        text.alignment = alignment;
        text.supportRichText = false;
        text.raycastTarget = false;
        text.horizontalOverflow = HorizontalWrapMode.Wrap;
        text.verticalOverflow = VerticalWrapMode.Truncate;
        return text;
    }
}
