# ValheimWebMap

| | |
| --- | --- |
| Origin | https://github.com/koenhendriks/Valheim-Web-Map |
| Forked at | tag `v1.3.0`, commit `1e69163286110ecd23f596dedfd2f38fd570b6a0` |
| Licence | MIT, upstream `LICENSE` copied verbatim here |
| Browser dependency | Vendored upstream Leaflet JavaScript/CSS; BSD-2-Clause text in `web/LEAFLET-LICENSE.txt` |
| Identity | `com.valheimwebmap`, assembly `ValheimWebMap.dll`, version 1.3.0 |
| Retire condition | An upstream release covering larger worlds, including edge terrain and expanded cartography coordinates, passes this world's acceptance checks. |

## Our changes

- SDK net472 project inherits repository reference extraction/publicizing, generated PluginInfo and dist staging. Newtonsoft.Json 13.0.4 is compile-only, supplied at runtime by the adopted JsonDotNET package. Browser files remain embedded resources; no upstream binaries are vendored.
- Resolve radius and edge once per world from Expand World Size 1.43.0's public static Configuration.WorldRadius and WorldEdgeSize properties. WorldGenerator.worldSize is a const 10000, not mutable runtime geometry: Expand World Size transpiles literals in game methods. Reading that const would silently preserve the clipping bug. Reflection avoids a hard binary dependency; absent Expand World Size uses enforced config fallbacks. A present but changed API fails visibly instead of using a misleading smaller world.
- Map half-width is radius + edge + one 64m zone: 13814m for radius 13250 and edge 500. The same session value feeds the renderer, explored mask, tile service, atlas and API. Browser CRS already consumes API mapHalfSize and needs no change.
- Removed the renderer's separate inlined vanilla water-edge-squared clamp, which otherwise still discarded terrain past 10500m after increasing map half-width. Rendering now uses the resolved radius + edge.
- Explored percentage uses the resolved radius, not WorldGenerator.worldSize. Expanded cartography bitmap scale mirrors ExpandWorldSize.MinimapAwake.CalculatePixelSize using Configuration.MapSize and MapPixelSize. With default minimap size 1 and pixel size 0, shared half-width is 12288 * 13750 / 10500 = 16091.43m. Pins remain absolute world coordinates.
- Basemap cache filename includes map extent; renderer format bumped to 2. Exploration file format bumped to 2 and records half-width, rejecting incompatible extents rather than reinterpreting old cells at new coordinates. A pre-fork exploration file is not migrated; this server has not previously run this plugin.
- Enforced config enables every presentation/history/pin layer, keeps fog restrictions, tracks public-position visibility as upstream does, sets two render workers, one-second player samples, 30-second table scans, and 60-second dirty-data saves. Empty DataDirectory deliberately resolves beneath BepInEx Paths.ConfigPath, on the persistent config mount.
- Hidden-player exploration is buffered by peer and published only when that peer logs out. A ten-minute trailing clearing could still track a long-running expedition, so logout is the stronger boundary: no hidden movement changes public tiles while the peer remains connected. Per-mask-cell deduplication retains the last position/radius in each cell; pending data is memory-only and lost on a server crash (generated-zone recovery and deliberate cartography sharing still recover combined exploration). Cartography-table writes remain explicit sharing, not hidden position samples.
- Server-only: excluded by build-client-pack's NEVER_STAGED list; GUID supplied to CharacterStore for exclusion from ServerManager client lists. Installer installs the root-built DLL through the existing dist manifest, with no separate package registration.

## Resolution and cost

4096px covers 27628m: approximately 6.745m/pixel. Render arrays are height (4 bytes), biome/forest/lava (one each), and RGB (three): 160 MiB total at full render, excluding runtime overhead. The RGB atlas pyramid adds about 64 MiB including its existing 48 MiB level zero; fog is 4 MiB. Preview/cache/HTTP tile buffers and GC can raise peak memory. 8192 would quadruple pixel storage and sampling work. Two below-normal workers bound startup CPU competition; elapsed time and save/tick impact require test-host measurement. Basemap cache avoids repeated terrain sampling after restart.

## Proof and runtime gate

`dotnet build src/forks/ValheimWebMap/ValheimWebMap.csproj` compiles against lib/valheim and emits dist/plugins/ValheimWebMap.dll. `bash test/webmap-coverage.test.sh` executes actual MapRenderer, MapAtlas and TileService against synthetic game terrain, decodes served PNG tiles and checks mountain pixels rather than fog/void at four 13000m compass points. It also proves 13750m explored-mask coverage, hidden exploration remaining private until logout, expanded cartography coordinates, persistence and extent rejection. Synthetic terrain is not native-game terrain or HTTP performance acceptance.

On the integrator's isolated test server, generate configs, stop it, apply enforced overlays, then boot with the full server stack. Inspect the Map geometry startup line (13250/500/13814/16091.43) and render-complete log. Visit and reveal (13000,0), (-13000,0), (0,13000), (0,-13000), and edge 13750m; write a cartography table and inspect matching web terrain/fog/pins after its 30-second scan. Keep public position off and inspect /api/state: that player's entry must have visible=false and no x/y/z/yaw/biome. Exercise traders, checked/automated pins, a public-position death, logout/rejoin and History. Validate persistent files beneath Paths.ConfigPath/ValheimWebMap and cache loading on restart.
For privacy acceptance, with public position off travel to previously fogged ground without writing a cartography table: repeated public tile requests must stay fogged throughout the connection, then reveal the combined exploration after logout and the next one-second player sample.

HTTP, TLS, external port isolation and burst/save timings are #108's proxy/runtime gate, not proven by compilation or coordinate tests. The owner supplies the domain and DNS. Never run these checks on the live server during this wave.
