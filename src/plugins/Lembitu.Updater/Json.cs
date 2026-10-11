using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Text;

namespace Lembitu.Updater;

/// <summary>Just enough JSON to read GitHub's release list: objects become dictionaries, arrays
/// lists, numbers doubles. Unity's JsonUtility read the list as empty in the game (2026-10-11), and
/// a JSON library from another mod would make the updater depend on the Pack it updates.</summary>
internal static class Json
{
    internal static object? Parse(string text)
    {
        int at = 0;
        object? value = Value(text, ref at);
        Space(text, ref at);
        if (at != text.Length) throw new InvalidDataException("trailing data in JSON at " + at);
        return value;
    }

    private static object? Value(string s, ref int i)
    {
        Space(s, ref i);
        if (i >= s.Length) throw new InvalidDataException("JSON ends early");
        switch (s[i])
        {
            case '{':
            {
                var map = new Dictionary<string, object?>(StringComparer.Ordinal);
                i++;
                Space(s, ref i);
                if (s[i] == '}') { i++; return map; }
                while (true)
                {
                    Space(s, ref i);
                    string key = Str(s, ref i);
                    Space(s, ref i);
                    Expect(s, ref i, ':');
                    map[key] = Value(s, ref i);
                    Space(s, ref i);
                    if (s[i] == ',') { i++; continue; }
                    Expect(s, ref i, '}');
                    return map;
                }
            }
            case '[':
            {
                var list = new List<object?>();
                i++;
                Space(s, ref i);
                if (s[i] == ']') { i++; return list; }
                while (true)
                {
                    list.Add(Value(s, ref i));
                    Space(s, ref i);
                    if (s[i] == ',') { i++; continue; }
                    Expect(s, ref i, ']');
                    return list;
                }
            }
            case '"': return Str(s, ref i);
            case 't': Word(s, ref i, "true"); return true;
            case 'f': Word(s, ref i, "false"); return false;
            case 'n': Word(s, ref i, "null"); return null;
            default:
            {
                int start = i;
                while (i < s.Length && "+-0123456789.eE".IndexOf(s[i]) >= 0) i++;
                if (start == i) throw new InvalidDataException("unexpected '" + s[i] + "' in JSON at " + i);
                return double.Parse(s.Substring(start, i - start), NumberStyles.Float, CultureInfo.InvariantCulture);
            }
        }
    }

    private static string Str(string s, ref int i)
    {
        Expect(s, ref i, '"');
        var text = new StringBuilder();
        while (true)
        {
            if (i >= s.Length) throw new InvalidDataException("unterminated JSON string");
            char c = s[i++];
            if (c == '"') return text.ToString();
            if (c != '\\') { text.Append(c); continue; }
            char e = s[i++];
            switch (e)
            {
                case 'n': text.Append('\n'); break;
                case 'r': text.Append('\r'); break;
                case 't': text.Append('\t'); break;
                case 'b': text.Append('\b'); break;
                case 'f': text.Append('\f'); break;
                case 'u': text.Append((char)Convert.ToInt32(s.Substring(i, 4), 16)); i += 4; break;
                default: text.Append(e); break;
            }
        }
    }

    private static void Space(string s, ref int i)
    {
        while (i < s.Length && char.IsWhiteSpace(s[i])) i++;
    }

    private static void Expect(string s, ref int i, char c)
    {
        if (i >= s.Length || s[i] != c) throw new InvalidDataException($"expected '{c}' in JSON at {i}");
        i++;
    }

    private static void Word(string s, ref int i, string word)
    {
        if (string.CompareOrdinal(s, i, word, 0, word.Length) != 0) throw new InvalidDataException("bad JSON literal at " + i);
        i += word.Length;
    }
}
