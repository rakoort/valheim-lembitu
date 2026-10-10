using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;
using System.Reflection.Emit;
using HarmonyLib;
using UnityEngine;

namespace Lembitu.Callings;

/// <summary>
/// DodgeShortcut 1.4.0 refuses its dodge key while the chat window's object is active, as a stand-in
/// for "the player is typing". Vanilla keeps that object active for ten seconds after every chat
/// line, and BetterChat shows it on new messages, so with Discord-bridged chat, join lines and
/// command help the dodge key failed most of the time (reported 2026-10-10). Its check is replaced
/// with vanilla's <c>Chat.HasFocus</c>, which is true only while the chat input has focus.
/// </summary>
internal static class DodgeChatFocus
{
    private static MethodInfo s_chatInstance = null!;
    private static FieldInfo s_chatWindow = null!;
    private static MethodInfo s_gameObject = null!;
    private static MethodInfo s_activeInHierarchy = null!;
    private static MethodInfo s_hasFocus = null!;

    public static IEnumerable<PatchPlan> Plan()
    {
        Type patches = AccessTools.TypeByName("DodgeShortcut.DodgePatches")
            ?? throw new HookMismatch("DodgeShortcut.DodgePatches not found");
        MethodInfo dodge = Hooks.Method(patches, "DodgePatch", Type.EmptyTypes, typeof(void));
        s_chatInstance = AccessTools.PropertyGetter(typeof(Chat), nameof(Chat.instance))
            ?? throw new HookMismatch("Chat.instance getter not found");
        s_chatWindow = AccessTools.DeclaredField(typeof(Terminal), nameof(Terminal.m_chatWindow))
            ?? throw new HookMismatch("Terminal.m_chatWindow not found");
        s_gameObject = AccessTools.PropertyGetter(typeof(Component), nameof(Component.gameObject))!;
        s_activeInHierarchy = AccessTools.PropertyGetter(typeof(GameObject), nameof(GameObject.activeInHierarchy))!;
        s_hasFocus = Hooks.Method(typeof(Chat), nameof(Chat.HasFocus), Type.EmptyTypes, typeof(bool));
        List<CodeInstruction> body = PatchProcessor.GetOriginalInstructions(dodge);
        int found = Enumerable.Range(0, body.Count).Count(i => IsChatWindowCheck(body, i));
        if (found != 1) throw new HookMismatch($"DodgePatches.DodgePatch: expected one chat-window check, found {found}");
        yield return new PatchPlan(dodge) { Transpiler = Hooks.Patch(typeof(DodgeChatFocus), nameof(UseChatFocus)) };
    }

    /// <summary>Chat.instance.m_chatWindow.gameObject.activeInHierarchy, starting at <paramref name="i"/>.</summary>
    private static bool IsChatWindowCheck(List<CodeInstruction> body, int i) =>
        i + 3 < body.Count
        && body[i].Calls(s_chatInstance)
        && body[i + 1].LoadsField(s_chatWindow)
        && body[i + 2].Calls(s_gameObject)
        && body[i + 3].Calls(s_activeInHierarchy);

    private static IEnumerable<CodeInstruction> UseChatFocus(IEnumerable<CodeInstruction> instructions)
    {
        List<CodeInstruction> body = instructions.ToList();
        for (int i = 0; i < body.Count; i++)
        {
            if (!IsChatWindowCheck(body, i)) continue;
            // Keep Chat.instance on the stack; its window test becomes the focus test.
            body[i + 1] = new CodeInstruction(OpCodes.Callvirt, s_hasFocus).WithLabels(body[i + 1].labels);
            body.RemoveRange(i + 2, 2);
            break;
        }
        return body;
    }
}
