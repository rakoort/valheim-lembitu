using System;
using System.Reflection;
using HarmonyLib;

namespace ValheimWebMap
{
    internal sealed class WorldGeometry
    {
        public readonly float Radius;
        public readonly float Edge;
        public readonly float HalfSize;
        public readonly float SharedMapHalfSize;

        public WorldGeometry(float radius, float edge, float sharedMapHalfSize)
        {
            Radius = radius;
            Edge = edge;
            // Leave one zone beyond the water edge; avoid clipping the edge's last pixel.
            HalfSize = radius + edge + 64f;
            SharedMapHalfSize = sharedMapHalfSize;
        }

        public static WorldGeometry Resolve(PluginConfig cfg)
        {
            // worldSize is a const. Expand World patches literal operands, not that field.
            Type config = AccessTools.TypeByName("ExpandWorldSize.Configuration");
            float radius = Read(config, "WorldRadius", cfg.WorldRadius.Value);
            float edge = Read(config, "WorldEdgeSize", cfg.WorldEdgeSize.Value);
            float mapSize = Read(config, "MapSize", 1f);
            float pixelScale = Read(config, "MapPixelSize", 0f);
            // Mirrors ExpandWorldSize.MinimapAwake.CalculatePixelSize; shared bitmap carries no scale.
            float sharedHalf = config == null ? cfg.SharedMapHalfSize.Value
                : 12288f * (pixelScale > 0f ? pixelScale * mapSize : (radius + edge) / 10500f);
            return new WorldGeometry(radius, edge, sharedHalf);
        }

        private static float Read(Type type, string name, float fallback)
        {
            if (type == null) return fallback;
            PropertyInfo property = type.GetProperty(name, BindingFlags.Public | BindingFlags.Static);
            if (property == null) throw new InvalidOperationException("Expand World Size no longer exposes " + name);
            float value = (float)property.GetValue(null, null);
            if (float.IsNaN(value) || float.IsInfinity(value) || value < 0f)
                throw new InvalidOperationException("Invalid Expand World Size " + name);
            return value;
        }
    }
}
