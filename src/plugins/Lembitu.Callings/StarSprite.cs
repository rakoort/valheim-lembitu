using UnityEngine;

namespace Lembitu.Callings;

/// <summary>
/// A five-pointed star drawn once at runtime, so the Calling star needs no asset bundle and no glyph
/// the game's fonts may lack. White, tinted by the Image that shows it.
/// </summary>
internal static class StarSprite
{
    private const int Size = 64;

    private static Sprite? s_sprite;

    public static Sprite Get() => s_sprite != null ? s_sprite : s_sprite = Draw();

    private static Sprite Draw()
    {
        var points = new Vector2[10];
        for (int i = 0; i < points.Length; i++)
        {
            float radius = i % 2 == 0 ? 0.48f : 0.19f;
            float angle = Mathf.PI / 2f + i * Mathf.PI / 5f;
            points[i] = new Vector2(0.5f + radius * Mathf.Cos(angle), 0.5f + radius * Mathf.Sin(angle));
        }

        var texture = new Texture2D(Size, Size, TextureFormat.RGBA32, mipChain: false)
        {
            wrapMode = TextureWrapMode.Clamp,
            filterMode = FilterMode.Bilinear,
        };
        var pixels = new Color32[Size * Size];
        const int samples = 4;
        for (int y = 0; y < Size; y++)
        {
            for (int x = 0; x < Size; x++)
            {
                int inside = 0;
                for (int sy = 0; sy < samples; sy++)
                {
                    for (int sx = 0; sx < samples; sx++)
                    {
                        var p = new Vector2((x + (sx + 0.5f) / samples) / Size, (y + (sy + 0.5f) / samples) / Size);
                        if (Contains(points, p))
                        {
                            inside++;
                        }
                    }
                }
                pixels[y * Size + x] = new Color32(255, 255, 255, (byte)(255 * inside / (samples * samples)));
            }
        }
        texture.SetPixels32(pixels);
        texture.Apply(updateMipmaps: false, makeNoLongerReadable: true);
        return Sprite.Create(texture, new Rect(0, 0, Size, Size), new Vector2(0.5f, 0.5f), 100f);
    }

    /// <summary>Even-odd point-in-polygon test.</summary>
    private static bool Contains(Vector2[] polygon, Vector2 p)
    {
        bool inside = false;
        for (int i = 0, j = polygon.Length - 1; i < polygon.Length; j = i++)
        {
            if ((polygon[i].y > p.y) != (polygon[j].y > p.y)
                && p.x < (polygon[j].x - polygon[i].x) * (p.y - polygon[i].y) / (polygon[j].y - polygon[i].y) + polygon[i].x)
            {
                inside = !inside;
            }
        }
        return inside;
    }
}
