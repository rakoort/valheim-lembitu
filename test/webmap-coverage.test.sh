#!/usr/bin/env bash
# Exercise expanded-world map coordinates and persistence without a game server.
# Usage: bash test/webmap-coverage.test.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
framework="net$(dotnet --version | cut -d. -f1).0"
cat > "$work/Coverage.csproj" <<EOF
<Project Sdk="Microsoft.NET.Sdk">
<PropertyGroup><OutputType>Exe</OutputType><TargetFramework>$framework</TargetFramework><EnableDefaultCompileItems>false</EnableDefaultCompileItems></PropertyGroup>
<ItemGroup>
<Compile Include="Program.cs" />
<Compile Include="$ROOT/src/forks/ValheimWebMap/WorldGeometry.cs" />
<Compile Include="$ROOT/src/forks/ValheimWebMap/SharedMapData.cs" />
<Compile Include="$ROOT/src/forks/ValheimWebMap/ExploredMask.cs" />
<Compile Include="$ROOT/src/forks/ValheimWebMap/PngEncoder.cs" />
<Compile Include="$ROOT/src/forks/ValheimWebMap/MapRenderer.cs" />
<Compile Include="$ROOT/src/forks/ValheimWebMap/MapAtlas.cs" />
<Compile Include="$ROOT/src/forks/ValheimWebMap/TileService.cs" />
<Compile Include="$ROOT/src/forks/ValheimWebMap/Palette.cs" />
<Compile Include="$ROOT/src/forks/ValheimWebMap/PrivateExploration.cs" />
</ItemGroup>
</Project>
EOF
cat > "$work/Program.cs" <<'EOF'
using System;
using System.IO;
using ValheimWebMap;
class Program
{
    static void Check(bool condition, string label) { if (!condition) throw new Exception("FAIL: " + label); Console.WriteLine("pass: " + label); }
    static byte[] Decode(byte[] png)
    {
        using var payload = new MemoryStream();
        int offset = 8;
        while (offset < png.Length)
        {
            int length = System.Buffers.Binary.BinaryPrimitives.ReadInt32BigEndian(png.AsSpan(offset,4));
            string kind = System.Text.Encoding.ASCII.GetString(png,offset+4,4);
            if (kind == "IDAT") payload.Write(png,offset+8,length);
            offset += length+12;
        }
        return PngEncoder.Unzlib(payload.ToArray(),256*(256*3+1));
    }
    static void Main()
    {
        var cfg = new PluginConfig();
        var g = WorldGeometry.Resolve(cfg);
        Check(g.Radius == 13250 && g.HalfSize == 13814, "runtime expanded radius plus edge and zone margin");
        const int renderSize = 1024;
        byte[] rendered = MapRenderer.Render(renderSize,g.HalfSize,g.Radius+g.Edge,2,_ => {},() => false);
        var renderMask = new ExploredMask(g.HalfSize,g.Radius);
        var tiles = new TileService(renderMask,g.HalfSize,7,"test");
        tiles.Atlas = new MapAtlas(1,renderSize,g.HalfSize,rendered);
        foreach (var p in new[] { (13000f,0f),(-13000f,0f),(0f,13000f),(0f,-13000f) })
        {
            int pixelX = (int)((p.Item1 + g.HalfSize) / (2*g.HalfSize) * renderSize);
            int pixelY = (int)((g.HalfSize - p.Item2) / (2*g.HalfSize) * renderSize);
            int offset = (pixelY*renderSize+pixelX)*3;
            Check(rendered[offset] == Palette.MountainSnow.R && rendered[offset+1] == Palette.MountainSnow.G && rendered[offset+2] == Palette.MountainSnow.B, "real renderer samples synthetic land, not void at " + p);
            renderMask.Reveal(p.Item1,p.Item2,100);
            Check(tiles.TryGetTile(2,pixelX/256,pixelY/256,out var png,out _),"tile served at " + p);
            byte[] raw = Decode(png);
            int tileOffset = (pixelY%256)*(256*3+1)+1+(pixelX%256)*3;
            Check(raw[tileOffset] == Palette.MountainSnow.R && raw[tileOffset+1] == Palette.MountainSnow.G && raw[tileOffset+2] == Palette.MountainSnow.B,"public tile contains land, not fog/void at " + p);
            var mask = new ExploredMask(g.HalfSize, g.Radius);
            mask.Reveal(p.Item1,p.Item2,100);
            Check(mask.Sample(p.Item1,p.Item2) > .99f, "explored cell revealed at " + p);
        }
        renderMask.Reveal(13750,0,100);
        Check(renderMask.Sample(13750,0) > .99f,"water edge lies within explored mask");
        var privateMask = new ExploredMask(g.HalfSize,g.Radius);
        var privacy = new PrivateExploration(privateMask);
        privacy.BeginSample(); privacy.Online(1); privacy.Record(1,13000,0,100); privacy.EndSample();
        Check(privateMask.Sample(13000,0) == 0,"hidden movement absent from public exploration");
        privacy.BeginSample(); privacy.Online(1); privacy.EndSample();
        Check(privateMask.Sample(13000,0) == 0,"hidden exploration stays private while peer connected");
        privacy.BeginSample(); privacy.EndSample();
        Check(privateMask.Sample(13000,0) > .99f,"hidden exploration joins combined map only after logout");
        const int size = 2048;
        float cell = g.SharedMapHalfSize * 2 / size;
        int col = (int)Math.Round(13000/cell + size/2f);
        using var stream = new MemoryStream();
        using (var writer = new BinaryWriter(stream,System.Text.Encoding.UTF8,true))
        {
            writer.Write(1); writer.Write(size*size);
            var cells = new byte[size*size]; cells[size/2*size+col] = 1; writer.Write(cells);
        }
        var map = SharedMapData.Parse(stream.ToArray(),g.SharedMapHalfSize);
        var rects = ExploredRuns.FromBitmap(map.Explored,size,map.PixelSize,g.HalfSize);
        var tableMask = new ExploredMask(g.HalfSize,g.Radius);
        tableMask.RevealRects(rects,0,rects.Count);
        Check(tableMask.AnyExplored(12990,-20,13010,20), "cartography cell maps to 13000m, not vanilla scale");
        string path = Path.Combine(Path.GetTempPath(),Guid.NewGuid()+".bin");
        try
        {
            tableMask.Save(path);
            var restored = new ExploredMask(g.HalfSize,g.Radius); restored.TryLoad(path);
            Check(restored.AnyExplored(12990,-20,13010,20),"exploration survives restart");
            try { new ExploredMask(10240,10000).TryLoad(path); throw new Exception("FAIL: wrong extent accepted"); }
            catch (InvalidDataException) { Console.WriteLine("pass: incompatible exploration extent refused"); }
        }
        finally { File.Delete(path); }
        HarmonyLib.AccessTools.Enabled = false;
        var fallback = WorldGeometry.Resolve(cfg);
        Check(fallback.HalfSize == 13814 && fallback.SharedMapHalfSize == cfg.SharedMapHalfSize.Value,"configured fallback without Expand World Size");
        Console.WriteLine("webmap coverage: all checks passed");
    }
}
namespace HarmonyLib { static class AccessTools { public static bool Enabled = true; public static Type TypeByName(string name) => Enabled ? typeof(ExpandWorldSize.Configuration) : null; } }
namespace ExpandWorldSize { static class Configuration { public static float WorldRadius => 13250; public static float WorldEdgeSize => 500; public static float MapSize => 1; public static float MapPixelSize => 0; } }
namespace ValheimWebMap {
    sealed class Entry { public float Value; public Entry(float value) { Value=value; } }
    sealed class PluginConfig { public Entry WorldRadius = new Entry(13250), WorldEdgeSize = new Entry(500), SharedMapHalfSize = new Entry(16091.4286f); }
}
class Heightmap { public enum Biome { Meadows, Swamp, Mountain, BlackForest, Plains, AshLands, DeepNorth, Ocean, Mistlands } }
class World { public int m_seed; public int m_worldGenVersion; }
class Version { public static string CurrentVersion => "synthetic"; }
class WorldGenerator
{
    public static WorldGenerator instance = new WorldGenerator();
    public Heightmap.Biome GetBiome(float x,float z) => Math.Max(Math.Abs(x),Math.Abs(z)) > 12500 ? Heightmap.Biome.Mountain : Heightmap.Biome.Ocean;
    public float GetBiomeHeight(Heightmap.Biome biome,float x,float z,out UnityEngine.Color mask) { mask = new UnityEngine.Color(); return biome == Heightmap.Biome.Mountain ? 100 : -400; }
    public static float GetForestFactor(UnityEngine.Vector3 point) => 2;
}
namespace UnityEngine
{
    struct Color { public float a; }
    struct Vector3
    {
        public float x,y,z;
        public Vector3(float x,float y,float z) { this.x=x; this.y=y; this.z=z; }
        public Vector3 normalized { get { float length = MathF.Sqrt(x*x+y*y+z*z); return new Vector3(x/length,y/length,z/length); } }
    }
    static class Mathf
    {
        public static float Clamp01(float value) => Math.Clamp(value,0,1);
        public static float Sqrt(float value) => MathF.Sqrt(value);
        public static float InverseLerp(float a,float b,float value) => Clamp01((value-a)/(b-a));
        public static float SmoothStep(float a,float b,float value) { float t=Clamp01(value); return a+(b-a)*t*t*(3-2*t); }
    }
}
EOF
if ! dotnet run --project "$work/Coverage.csproj" --nologo; then
  printf 'FAIL: webmap coverage harness\n' >&2
  exit 1
fi
