using System;
using System.Linq;
using BepInEx.Configuration;
using UnityEngine;

namespace Lembitu.Guide;

/// <summary>
/// Guide window settings (ADR-0027). The hotkey is a client preference and is deliberately not in
/// config/enforced - a server overlay cannot change a player's controls. AutoOpenOnFirstJoin is the
/// server's decision and is locked through Jotunn like our other settings.
/// </summary>
internal static class Settings
{
    private static ConfigEntry<KeyboardShortcut> s_hotkey = null!;
    private static ConfigEntry<bool> s_autoOpenOnFirstJoin = null!;
    private static KeyCode s_mainKey;
    private static KeyCode[] s_modifiers = Array.Empty<KeyCode>();

    public static bool HotKeyIsDown()
    {
        if (s_mainKey == KeyCode.None || !ZInput.GetKeyDown(s_mainKey, logWarning: false))
        {
            return false;
        }
        for (int i = 0; i < s_modifiers.Length; i++)
        {
            if (!ZInput.GetKey(s_modifiers[i], logWarning: false))
            {
                return false;
            }
        }
        return true;
    }
    public static bool AutoOpenOnFirstJoin => s_autoOpenOnFirstJoin.Value;

    public static void Bind(ConfigFile config)
    {
        s_hotkey = config.Bind("Window", "HotKey", KeyboardShortcut.Deserialize("F1"),
            "Key that opens and closes the guide window. Verified free of the vanilla bindings and "
            + "of every Pack mod's defaults (ZInput defaults and the staged plugins, 2026-10-05). "
            + "Client preference, not synced.");
        ReadHotKey();
        s_hotkey.SettingChanged += (_, _) => ReadHotKey();
        s_autoOpenOnFirstJoin = config.Bind("Window", "AutoOpenOnFirstJoin", true,
            new ConfigDescription("Open the guide on First steps the first time a character joins.",
                null, GuidePlugin.AdminOnly()));
    }

    // Cache the chord only when its preference changes; keyboard polling must not allocate.
    private static void ReadHotKey()
    {
        KeyboardShortcut shortcut = s_hotkey.Value;
        s_mainKey = shortcut.MainKey;
        s_modifiers = shortcut.Modifiers.ToArray();
    }
}
