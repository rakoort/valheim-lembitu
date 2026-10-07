using System;
using System.Collections.Generic;
using System.Linq;
using BepInEx.Logging;

namespace Lembitu.Guide;

/// <summary>A guide page: the fixed contract id, its title and the body text.</summary>
internal sealed record GuidePage(string Id, string Title, string Body);

/// <summary>
/// The guide's text, delivered from the server. The content file is plain text the admin edits:
/// each page starts with a "page &lt;id&gt; | &lt;Title&gt;" line and runs to the next one; blank
/// lines split paragraphs; lines starting with '#' are comments. Page ids are the fixed contract
/// ids other plugins' refusal messages name, so a page whose id changed breaks those messages:
/// unknown ids are kept and logged, missing ones logged.
/// </summary>
internal static class GuideContent
{
    /// <summary>Stable page ids; ladder now explains profession benefits. Order is display order.</summary>
    internal static readonly string[] FixedIds =
    {
        "first-steps", "oath-and-class", "calling", "ladder", "boss-keys", "groups", "death",
    };

    private static ManualLogSource s_log = null!;

    public static IReadOnlyList<GuidePage> Pages { get; private set; } = Array.Empty<GuidePage>();

    public static void Configure(ManualLogSource log) => s_log = log;

    /// <summary>No content survives a disconnected network session.</summary>
    public static void Clear() => Pages = Array.Empty<GuidePage>();

    /// <summary>Parses the server's content; on a parse error keeps the previous pages.</summary>
    public static bool Load(string text)
    {
        List<GuidePage> pages = new();
        string? id = null, title = null;
        List<string> body = new();

        foreach (string raw in text.Split('\n'))
        {
            string line = raw.TrimEnd('\r');
            if (line.StartsWith("#") || (line.Length == 0 && id == null))
            {
                continue;
            }
            if (line.StartsWith("page "))
            {
                if (id != null)
                {
                    pages.Add(new GuidePage(id, title ?? id, Flatten(body)));
                }
                (id, title) = PageHeader(line);
                body.Clear();
                if (title == null)
                {
                    s_log.LogWarning($"Guide page '{id}' has no '| Title' in its header line; using the id as the title.");
                    title = id;
                }
                continue;
            }
            if (id == null)
            {
                continue;
            }
            body.Add(line);
        }
        if (id != null)
        {
            pages.Add(new GuidePage(id, title!, Flatten(body)));
        }

        if (pages.Count == 0)
        {
            s_log.LogWarning("Guide content has no pages; keeping what was shown before.");
            return false;
        }

        foreach (string fixedId in FixedIds.Where(fixedId => pages.All(p => p.Id != fixedId)))
        {
            s_log.LogWarning($"Guide content is missing the fixed page '{fixedId}'; refusal messages name it.");
        }

        Pages = pages;
        return true;
    }

    /// <summary>The page with this id, or null when the content does not carry it.</summary>
    public static GuidePage? Find(string id) => Pages.FirstOrDefault(p => p.Id == id);

    /// <summary>Display order: the fixed contract ids first, in contract order, then any extras.</summary>
    public static IReadOnlyList<GuidePage> Ordered() =>
        FixedIds.Select(Find).Where(p => p != null).Cast<GuidePage>()
            .Concat(Pages.Where(p => !FixedIds.Contains(p.Id)))
            .ToList();

    private static (string Id, string? Title) PageHeader(string line)
    {
        string rest = line.Substring("page ".Length).Trim();
        int bar = rest.IndexOf('|');
        string id = (bar < 0 ? rest : rest.Substring(0, bar)).Trim();
        string? title = bar < 0 ? null : rest.Substring(bar + 1).Trim();
        return (id, string.IsNullOrEmpty(title) ? null : title);
    }

    private static string Flatten(List<string> lines)
    {
        var kept = new List<string>();
        foreach (string line in lines)
        {
            if (line.Length == 0 && (kept.Count == 0 || kept[kept.Count - 1].Length == 0))
            {
                continue;
            }
            kept.Add(line);
        }
        while (kept.Count > 0 && kept[kept.Count - 1].Length == 0)
        {
            kept.RemoveAt(kept.Count - 1);
        }
        string text = string.Join("\n", kept);
        return text.Length == 0 ? "(this page is empty)" : text;
    }
}
