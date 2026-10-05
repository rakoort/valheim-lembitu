using System;
using System.Collections;
using System.Diagnostics;
using System.IO;
using BepInEx.Logging;
using UnityEngine;
using UnityEngine.InputSystem;
using UnityEngine.InputSystem.Controls;
using UnityEngine.InputSystem.LowLevel;

namespace Lembitu.Harness;

/// <summary>
/// Presses and releases a key the way a player does, so ZInput and Jotunn bindings fire for real.
/// Two paths. Real OS input first: xdotool activates the game window on the client's X display and
/// injects XTEST key events, which the engine receives exactly like a keyboard. Without xdotool,
/// or when the caller forces it, Unity's InputSystem gets queued state events instead: absolute
/// KeyboardState per frame while held, an empty state to release. Queued events are processed at
/// the next input update, before scripts, which is the same frame shape as OS input.
/// </summary>
internal static class HarnessKeys
{
    /// <summary>
    /// Presses <paramref name="keyName"/> (a Unity InputSystem <c>Key</c> name, e.g. "F7") and
    /// returns a result for the command response through <paramref name="done"/>. The readback
    /// proves the key state reached the InputSystem; xdotool reports delivery only.
    /// </summary>
    public static IEnumerator Press(string keyName, string method, float holdSeconds, ManualLogSource log, Action<KeyResult> done)
    {
        if (!Enum.TryParse(keyName, true, out Key key))
            throw new ArgumentException($"'{keyName}' is not an InputSystem Key name (try F7, e, escape, tab)");
        if (method.Length == 0) method = "auto";

        KeyResult result = new() { key = key.ToString(), method = method, pressed = false, frames = 0, holdSeconds = holdSeconds };
        bool wantXdotool = method is "auto" or "xdotool";
        bool wantSynthetic = method is "auto" or "synthetic";
        if (wantXdotool)
        {
            yield return XdotoolPress(keyName, holdSeconds, log, result);
            if (result.pressed)
            {
                done(result);
                yield break;
            }
        }
        if (method == "xdotool") throw new InvalidOperationException("xdotool key injection failed");
        if (!wantSynthetic) throw new ArgumentException("method must be auto, xdotool, or synthetic");

        result.method = "synthetic";
        yield return SyntheticPress(key, result);
        done(result);
    }

    private static IEnumerator SyntheticPress(Key key, KeyResult result)
    {
        Keyboard keyboard = Keyboard.current ?? throw new InvalidOperationException("no keyboard device");
        KeyControl control = keyboard[key];
        KeyboardState held = new(key);
        KeyboardState released = new();
        // One queued event per frame; ~60 fps, so hold seconds become frames. At least two frames,
        // because the event queued this frame is processed at the start of the next one.
        result.frames = Math.Max(2, Mathf.RoundToInt(60f * result.holdSeconds));
        for (int frame = 0; frame < result.frames; frame++)
        {
            InputSystem.QueueStateEvent(keyboard.device, held);
            yield return null;
            result.pressed |= control.isPressed;
        }
        InputSystem.QueueStateEvent(keyboard.device, released);
        yield return null;
        yield return null;
    }

    /// <summary>Types a string into the focused input field through xdotool; xdotool only.</summary>
    public static IEnumerator Type(string text, ManualLogSource log, Action<KeyResult> done)
    {
        if (text.Length == 0) throw new ArgumentException("text must not be empty");
        KeyResult result = new() { key = $"<text:{text.Length} chars>", method = "xdotool", pressed = true };
        string? binary = OnPath("xdotool");
        string? display = Environment.GetEnvironmentVariable("DISPLAY");
        if (binary == null || string.IsNullOrEmpty(display))
            throw new InvalidOperationException("text requires xdotool on the client's display; press keys with the key action instead");
        try
        {
            string windows = Run(binary, display, $"search --onlyvisible --pid {Process.GetCurrentProcess().Id}", out int status);
            if (status != 0 || windows.Trim().Length == 0) throw new InvalidOperationException("no visible window to type into");
            foreach (string id in windows.Split(['\n', '\r'], StringSplitOptions.RemoveEmptyEntries))
                Run(binary, display, $"windowactivate --sync {id.Trim()}", out status);
            Run(binary, display, $"type --delay 40 -- {text}", out status);
            if (status != 0) throw new InvalidOperationException("xdotool type failed");
        }
        catch (Exception error)
        {
            throw new InvalidOperationException($"typing failed: {error.Message}");
        }
        done(result);
        yield break;
    }

    /// <summary>Real XTEST input through xdotool; false when it is not usable and the caller should fall back.</summary>
    private static IEnumerator XdotoolPress(string keyName, float holdSeconds, ManualLogSource log, KeyResult result)
    {
        string? binary = OnPath("xdotool");
        string? display = Environment.GetEnvironmentVariable("DISPLAY");
        if (binary == null || string.IsNullOrEmpty(display)) yield break;
        string windows = Run(binary, display, $"search --onlyvisible --pid {Process.GetCurrentProcess().Id}", out int status);
        if (status != 0 || windows.Trim().Length == 0) yield break;
        string id = windows.Split(['\n', '\r'], StringSplitOptions.RemoveEmptyEntries)[0].Trim();
        Run(binary, display, $"windowactivate --sync {id}", out status);
        if (status != 0)
        {
            // Headless Weston may have no EWMH window manager; direct focus still delivers XTEST.
            Run(binary, display, $"windowfocus --sync {id}", out status);
            if (status != 0) yield break;
        }
        Run(binary, display, $"keydown {keyName}", out status);
        if (status != 0) yield break;
        try
        {
            float end = Time.realtimeSinceStartup + holdSeconds;
            while (Time.realtimeSinceStartup < end)
            {
                yield return null;
                result.frames++;
            }
        }
        finally { Run(binary, display, $"keyup {keyName}", out status); }
        yield return null;
        yield return null;
        result.method = "xdotool";
        result.pressed = status == 0;
    }

    private static string Run(string binary, string display, string arguments, out int status)
    {
        using Process process = Process.Start(new ProcessStartInfo
        {
            FileName = binary,
            Arguments = arguments,
            UseShellExecute = false,
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            Environment = { ["DISPLAY"] = display },
        }) ?? throw new InvalidOperationException("xdotool did not start");
        string output = process.StandardOutput.ReadToEnd();
        process.StandardError.ReadToEnd();
        process.WaitForExit(10000);
        status = process.ExitCode;
        return output;
    }

    private static string? OnPath(string file)
    {
        string? path = Environment.GetEnvironmentVariable("PATH");
        foreach (string directory in (path ?? "").Split(Path.PathSeparator))
        {
            if (directory.Length == 0) continue;
            string candidate = Path.Combine(directory, file);
            try { if (File.Exists(candidate)) return candidate; }
            catch (Exception) { /* unreadable PATH entry; try the next */ }
        }
        return null;
    }

    public sealed class KeyResult
    {
        public string key = "";
        public string method = "";
        public bool pressed;
        public int frames;
        public float holdSeconds;
    }
}
