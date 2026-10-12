using System.Collections.Generic;
using HarmonyLib;

namespace Lembitu.Callings;

/// <summary>
/// Vanilla shouts "I have arrived!" once per session, on the client's first spawn
/// (<c>Game.UpdateRespawn</c> sends <c>$text_player_arrived</c>). ServerManager bridges every shout
/// to the Discord <c>#chat</c>, where those lines were most of the channel (owner, 2026-10-12). Only
/// that shout is skipped: it is the arrival text sent while <c>Game.UpdateRespawn</c> runs the first
/// spawn, so the same words typed by a player still go out.
/// </summary>
internal static class ArrivalShout
{
    private static bool s_inFirstSpawn;

    public static IEnumerable<PatchPlan> Plan()
    {
        var respawn = Hooks.Method(typeof(Game), "UpdateRespawn", new[] { typeof(float) }, typeof(void));
        Hooks.Field(typeof(Game), "m_firstSpawn", typeof(bool));
        var send = Hooks.Method(typeof(Chat), nameof(Chat.SendText), new[] { typeof(Talker.Type), typeof(string) }, typeof(void));
        yield return new PatchPlan(respawn)
        {
            Prefix = Hooks.Patch(typeof(ArrivalShout), nameof(EnterRespawn)),
            Finalizer = Hooks.Patch(typeof(ArrivalShout), nameof(LeaveRespawn)),
        };
        yield return new PatchPlan(send) { Prefix = Hooks.Patch(typeof(ArrivalShout), nameof(SkipArrival)) };
    }

    private static void EnterRespawn(bool ___m_firstSpawn) => s_inFirstSpawn = ___m_firstSpawn;

    private static void LeaveRespawn() => s_inFirstSpawn = false;

    private static bool SkipArrival(Talker.Type type, string text) =>
        !(s_inFirstSpawn && type == Talker.Type.Shout && text == Localization.instance.Localize("$text_player_arrived"));
}
