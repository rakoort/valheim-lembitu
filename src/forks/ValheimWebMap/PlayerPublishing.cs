using System;
using System.Collections.Generic;
using UnityEngine;

namespace ValheimWebMap
{
    internal struct PlayerEntry
    {
        public long Id;
        public string Key;
        public string Name;
        public bool Visible;
        public bool HasCharacter;
        public string CharacterKey;
        public long PlayerId;
        public bool Dead;
        public Vector3 Position;
        public float Yaw;
        public string Biome;
        public string Guild;
    }

    internal static class PlayerPublishing
    {
        public static void Sample(List<PlayerEntry> players, bool ignorePrivacy, float radius,
            ExploredMask mask, PrivateExploration pending, Func<long, string> guildName)
        {
            if (!ignorePrivacy) pending.BeginSample();
            for (int i = 0; i < players.Count; ++i)
            {
                PlayerEntry p = players[i];
                p.Visible = p.HasCharacter && (ignorePrivacy || p.Visible);
                p.Guild = guildName(p.PlayerId);
                players[i] = p;
                if (!ignorePrivacy) pending.Online(p.Id);
                if (!p.HasCharacter || p.Dead || p.Position.sqrMagnitude < 1f) continue;
                if (p.Visible) mask.Reveal(p.Position.x, p.Position.z, radius);
                else pending.Record(p.Id, p.Position.x, p.Position.z, radius);
            }
            if (!ignorePrivacy) pending.EndSample();
        }

        public static void WriteIdentity(JsonWriter j, PlayerEntry p)
        {
            j.Prop("id", p.Id);
            j.Prop("name", p.Name);
            j.Prop("guild", p.Guild);
            j.Prop("visible", p.Visible);
        }

        public static void WritePosition(JsonWriter j, PlayerEntry p, bool heading, bool biome)
        {
            if (!p.Visible) return;
            j.Prop("x", p.Position.x, 1);
            j.Prop("z", p.Position.z, 1);
            j.Prop("y", p.Position.y, 1);
            if (heading) j.Prop("yaw", p.Yaw, 0);
            if (biome) j.Prop("biome", p.Biome);
        }
    }
}
