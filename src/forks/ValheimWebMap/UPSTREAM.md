# ValheimWebMap

| | |
| --- | --- |
| Origin | https://github.com/koenhendriks/Valheim-Web-Map |
| Forked at | tag `v1.3.0`, commit `1e69163286110ecd23f596dedfd2f38fd570b6a0` |
| Licence | MIT, upstream `LICENSE` copied verbatim here |
| Browser dependency | Vendored upstream Leaflet JavaScript/CSS; BSD-2-Clause text in `web/LEAFLET-LICENSE.txt` |
| Identity | `com.valheimwebmap`, assembly `ValheimWebMap.dll`, version 1.3.0 |
| Retire condition | None for the Run: guild claims and the Chronicle never come from upstream (ADR-0003, 2026-10-11 amendment; ADR-0036). An upstream larger-world release is imported, not adopted in its place. |

## Our changes

- SDK net472 project inherits repository reference extraction/publicizing, generated PluginInfo and dist staging. Newtonsoft.Json 13.0.4 is compile-only, supplied at runtime by the adopted JsonDotNET package. Browser files remain embedded resources; no upstream binaries are vendored.
- Resolve radius and edge once per world from Expand World Size 1.43.0's public static Configuration.WorldRadius and WorldEdgeSize properties. WorldGenerator.worldSize is a const 10000, not mutable runtime geometry: Expand World Size transpiles literals in game methods. Reading that const would silently preserve the clipping bug. Reflection avoids a hard binary dependency; absent Expand World Size uses enforced config fallbacks. A present but changed API fails visibly instead of using a misleading smaller world.
- Map half-width is radius + edge + one 64m zone: 13814m for radius 13250 and edge 500. The same session value feeds the renderer, explored mask, tile service, atlas and API. Browser CRS already consumes API mapHalfSize and needs no change.
- Removed the renderer's separate inlined vanilla water-edge-squared clamp, which otherwise still discarded terrain past 10500m after increasing map half-width. Rendering now uses the resolved radius + edge.
- Explored percentage uses the resolved radius, not WorldGenerator.worldSize. Expanded cartography bitmap scale mirrors ExpandWorldSize.MinimapAwake.CalculatePixelSize using Configuration.MapSize and MapPixelSize. With default minimap size 1 and pixel size 0, shared half-width is 12288 * 13750 / 10500 = 16091.43m. Pins remain absolute world coordinates.
- Basemap cache filename includes map extent; renderer format bumped to 2. Exploration file format bumped to 2 and records half-width, rejecting incompatible extents rather than reinterpreting old cells at new coordinates. A pre-fork exploration file is not migrated; this server has not previously run this plugin.
- Enforced config enables map/pin layers and operational session/death recording, keeps fog restrictions, sets two render workers, one-second samples, 30-second table scans and 60-second dirty-data saves. Empty DataDirectory resolves beneath BepInEx Paths.ConfigPath on the persistent mount.
- Owner reversal on 2026-10-09: `[Players] IgnorePositionPrivacy` defaults false for upstream-compatible visibility, but the enforced overlay sets true. Every spawned connected character then counts as visible regardless of the in-game public-position toggle; existing Display settings still govern heading and biome. All living characters reveal exploration live, bypassing PrivateExploration. With the switch false, hidden exploration remains buffered until logout (memory-only, lost on crash); cartography sharing remains explicit. The in-game map is unchanged.
- Main-thread reflection into Guilds 1.5.1 reads the authoritative server roster and its geometry/progression helpers. `/api/state` includes full public guild cards and claim positions, plus each player's guild name, string id and muted colour. An explicit whitelist excludes vault items, coins, message of the day and guild pins; no raw guild object is serialized. Guild API drift disables all guild features with one warning, leaving terrain, players and cartography pins working. See `docs/wiki/operations.md` for the public fields, source geometry, claim dates and Siege stages.
- Start regions use SeparateSpawns layout points and the Lembitu.Guilds claims file; ward and outpost lookups use ZDO key indexes. Territory and banner clicks open cards. The light parchment panel groups online players by guild, guildless last, and stores one layer list in the browser. History UI, public `/api/history`, play durations and death totals are removed; server session/death recording remains.
- Server-only: excluded by build-client-pack's NEVER_STAGED list; GUID supplied to CharacterStore for exclusion from ServerManager client lists. Installer installs the root-built DLL through the existing dist manifest, with no separate package registration.

## Resolution and cost

4096px covers 27628m: approximately 6.745m/pixel. Render arrays are height (4 bytes), biome/forest/lava (one each), and RGB (three): 160 MiB total at full render, excluding runtime overhead. The RGB atlas pyramid adds about 64 MiB including its existing 48 MiB level zero; fog is 4 MiB. Preview/cache/HTTP tile buffers and GC can raise peak memory. 8192 would quadruple pixel storage and sampling work. Two below-normal workers bound startup CPU competition; elapsed time and save/tick impact require test-host measurement. Basemap cache avoids repeated terrain sampling after restart.

## Proof and runtime gate

`dotnet build src/forks/ValheimWebMap/ValheimWebMap.csproj` emits dist/plugins/ValheimWebMap.dll. `bash test/webmap-coverage.test.sh` exercises actual terrain rendering, tiles, expanded coordinates, privacy override and player JSON. `bash test/webmap-guilds.test.sh` exercises the map classes against a two-guild store, claims file, wards and outposts, including the public whitelist, fixed palette, live Siege transitions and renamed-API disable. Its HTTP fixture runs real MapSession, cartography decoding, terrain rendering, tile encoding and WebServer handlers, proving positions/pins/terrain survive drift with one warning and without owner pin totals. Its browser guard exercises cards, grouping and saved layer choices. Synthetic game stores do not replace native acceptance.

On an isolated test server, generate configs, stop it, apply overlays, then boot the full stack. Native guild acceptance uses one player founding a guild, a banner with a territory upgrade, a bound ward and an outpost under Siege. Compare the territory square against the in-game border within one map cell and inspect the actual browser card and Siege transitions. Multi-player/two-guild cases use synthetic data; the owner checks them live after deploy. The earlier expanded-terrain gate still checks the 13000m compass points, 13750m edge, cartography sharing, fog policy and restart persistence. Session history remains on disk, not on the page.

HTTP, TLS, external port isolation and burst/save timings are #108's proxy/runtime gate, not proven by compilation or coordinate tests. The owner supplies the domain and DNS. Never run these checks on the live server during this wave.
