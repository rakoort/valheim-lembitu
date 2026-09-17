# The mod stack

What the development candidate runs, at which version, and what we changed about each default.
This file records exact versions for reproducible tests, not a prelaunch freeze. The reasoning is
in [adr/](adr/) and the vocabulary in [../CONTEXT.md](../CONTEXT.md).

Adopted pins were checked against live Thunderstore package APIs on **2026-09-15**. Development
follows the latest public Valheim client/server and latest mod releases. The live server runs
**1.0.14 / network 40** as of 2026-09-17; it had been 1.0.12, and nobody chose the change — the
container's updater ran its first pass on an idle restart, re-synced the game from Steam and
re-extracted BepInEx over the plugin tree, which cost one boot with zero plugins loaded. The
network version did not move, so clients were unaffected. `config/launch/launch.env.example`
documents exactly this hole: `UPDATE_CRON` is empty, but the updater's startup call still fires
when the server is idle. Freeze only after the acceptance gate below passes, before launch-world
creation (ADR-0007, ADR-0009).

The stack was reduced from thirty packages to twenty-three on **2026-09-15**, and every planned
plugin of ours except the test harness was cancelled, because upstream mods now cover the
load-bearing behaviour (ADR-0010). What was removed and why is in [Considered and cut](#considered-and-cut).

**This table is now the repository state** (#66, #70, #78, #80). `modstack.lock.json` carries
exactly these twenty-four pins — twenty-three after the 2026-09-15 reduction, twenty-one once #70
dropped AdminQoL and BoneMod, twenty-six once #78 adopted five quality-of-life mods, and
twenty-four once #80 removed character level. The retired fork and plugins are deleted from
`src/`, `config/enforced/` holds the overlays below, and `src/forks/` contains only
MaxPlayerCount. The dated measurements further down are the runs that established the pack, not a
prediction of it.

## Adopted upstream

Every mod here is pinned at exactly this version; the side it runs on is in
[Where each mod runs](#where-each-mod-runs). Most are installed on the server *and* the client
pack, two are withheld from the Pack as server-only — DiscordConnector and Max Dungeon Rooms —
and three ride in the Pack alone: AzuHoverStats, AzuClock and MouseTweaks. Candidate staging is
not deployment or verification. "Enforced config" is a deliberate deviation from the defaults and
belongs in server-locked config rather than a player's file.

| Mod | Pin | Role | Enforced config |
| --- | --- | --- | --- |
| sighsorry/Clan | 1.0.10 | Clans, roles, clan chat, guest clans, clan pings | Friendly fire off; config locked |
| sighsorry/STU_Ward | 1.3.15 | Wards resolved against clan membership | — |
| sighsorry/PortalRules | 1.0.7 | Portal access control | Access modes only: no fares, no map picker, no admin portals, GlobalKey gates unset; access-mode limits pinned at upstream values |
| VentureValheim/World_Advancement_Progression | 1.0.0 | Personal keys: private per-character progression, per-player raids, key-gated actions, vanilla skill caps | Private keys on, all global keys blocked; equipment, crafting, cooking, eating, guardian powers and boss summons locked; repairs, building, taming, boats and portals open; skill floor from boss keys with the ceiling at 100 |
| RandyKnapp/EpicLoot | 0.14.5 | Gear tiers: magic drops, rarities, enchanting and socketed shardstones | `Item Drop Limits` and `Gated Freebuild Mode` both `PlayerMustKnowRecipe`, so gating reads the player, not world keys; Adventure Mode off; drop rate 0.6, shardstones 0.05; effect counts thinned by patch (#73) |
| WackyMole/WackyEpicMMOSystem | 1.9.67 | Character level: XP, attributes, level band, XP meads | XP curve and attributes at upstream values; XP loss band 0.05-0.15; its own creature-level control off, so CreatureManager owns levels. Restored 2026-09-17 (2026-09-17, owner's instruction) without its armour-gate companion, so no level gates gear |
| sighsorry/CreatureManager | 1.1.14 | Fixed creature and boss multipliers, and holding vanilla's headcount scaling at zero | Cloning and customisation off; `Biome Level Preset = Hard`; **Karma and all three modifier switches off from 2026-09-17 (#84)**; headcount scaling pinned at 0 / 0 / 1 |
| Digitalroot/Max_Dungeon_Rooms | 2.0.39 | Larger dungeons | — |
| team0/ValheimRAFT | 4.3.2 | Custom ships, anchoring and vehicle building | Cannon prefabs off, flight off, non-admin debug off, and from 2026-09-17 `AdminsCanOnlyBuildRaft = true`, so no player builds a vehicle. The mod stays installed because it is world-permanent; whether the pin leaves is #82 |
| turbero/PvPBiomeDominions | 1.7.8 | PvP death and retention rules | Biome-forced PvP off everywhere |
| sighsorry/Dive_In | 1.2.3 | Diving, water combat, underwater creature pursuit | — |
| Azumatt/AzuExtendedPlayerInventory | 2.4.14 | Equipment slots, quick slots, Wishbone and Demister slots | Extra rows 0, three quick slots, equipment and special slots on; the vanity button off, which is the only switch the mod has for it |
| Azumatt/AzuCraftyBoxes | 1.8.19 | Crafting and building pull materials from containers near the station | `Container Range` 20 m; `Leave One Item` off; `Mod Enabled` on; config locked; `Azumatt.AzuCraftyBoxes.yml` committed empty, so everything in range is pullable |
| Azumatt/AzuHoverStats | 1.1.10 | Hover readouts for creatures, pieces, items, chests and crafting timers | — Nothing in it is server-synced, so the server can pin nothing; client-only |
| Azumatt/AzuClock | 1.1.0 | On-screen clock and weather forecast | — Client-only |
| Azumatt/MouseTweaks | 1.0.4 | Inventory moving, stack splitting and quick-dropping with mouse and modifier | — Client-only |
| Azumatt/ProximityVoiceChat | 1.0.2 | Positional voice chat, quieter with distance, no external program | Voice ranges and the Opus codec pinned; microphone, playback, indicators and keybinds stay the player's |
| turbero/DetailedLevels | 2.1.3 | Skill progress readout | — |
| sighsorry/DataForge | 1.3.4 | Item, recipe and effect tuning | Tuning only: no cloned or custom items |
| sighsorry/SkadiNet | 1.1.5 | Peer-aware network pacing, dungeon-layer filtering | — |
| sighsorry/Blasted_Swimming_Tarred_Bug_Fix | 1.2.6 | Vanilla state and teardown bug fixes | — |
| nwesterhausen/DiscordConnector | 3.1.3 | Server-side Discord webhook relay: joins, deaths, events | Webhook URL is a secret, set per deployment |
| ArgusMagnus/ServersideQoL | 2.0.11 | Server-side QoL framework: the module host every `ServersideQoL_*` feature plugs into. Ships a BepInEx preloader patcher | `Enabled` on, diagnostic logs off. No feature of its own |
| ArgusMagnus/ServersideQoL_JustSleep | 2.0.11 | Skip the night when enough players are in bed or sitting | Prompt at one player in bed; half the connected players must join in |
| JereKuusela/Expand_World_Size | 1.34.0 | World radius, edge and stretch. World-permanent in the strongest sense: the values are baked into terrain at generation | `World radius` 15000, `Stretch world` 1.5, `Stretch biomes` 1.5 — the vanilla layout scaled up by half again (#86) |
| Mushroom_Vikings/SeparateSpawns | 0.1.0 | Each clan starts in its own place, scored for a viable neighbourhood | Search radius, minimum separation between group spawns and the Black Forest scoring left at upstream values |
| MidnightMods/ProgressivePowers | 0.3.3 | Forsaken power mastery: powers grow with use | A third power curve, adopted against ADR-0004's rule and recorded in ADR-0018 |
| Vapok/AdventureBackpacks | 2.0.7 | Backpacks with their own storage | One-way: the packs are registered items, so removing the mod deletes them and their contents |
| ishid4/BetterArchery | 2.0.0 | Quivers, draw and aiming changes for bows | — Declares BepInEx 5.4.1501, a documented override |
| ValheimModding/Jotunn | 2.30.0 | Library | Overrides the 2.29.2 pin declared by EpicLoot |
| ValheimModding/JsonDotNET | 13.0.4 | Library | — |
| ValheimModding/YamlDotNet | 16.3.1 | Library | Declared by ServersideQoL, and its own detector plugin loads it either way (#66 boot) |

## Where each mod runs

Four groups, decided by evidence rather than by the package descriptions. The first group is
observable: at every join the server announces a version for each mod that participates in the
config/version handshake, and refuses a client that answers with the wrong version or none. The
list below is the server's own announcement, read from the live log on 2026-09-16, except the one
row marked as read from the assembly instead. Every other row, AzuExtendedPlayerInventory
included, has been read from a join: the 14:48 UTC+2 join of a v7 client logged `Sending
AzuExtendedPlayerInventory version 2.4.14 and minimum version 2.4.14 to the client`, then
`Version check, local: 2.4.14, remote: 2.4.14` and `Adding peer to validated list`.

Enforcement comes in two shapes, and the difference decides whether installing a mod on the
server refuses the players who lack it. ServerSync's own `VersionCheck` only refuses a silent peer
when its `ConfigSync.ModRequired` is true, and every Azumatt mod in this pack leaves that false.
What makes those mods mandatory is a *hand-rolled* check they each carry: a `ZNet.OnNewConnection`
prefix registers and invokes `<Mod>_VersionCheck`, and a `ZNet.RPC_PeerInfo` prefix disconnects
any peer the server has not recorded in `ValidatedPeers`. A client without the mod never answers,
so it is refused. A mod with neither mechanism refuses nobody.

**Both sides, and the server enforces it.** A client missing any of these is refused at the
handshake with `doesn't have the correct <mod> version`. Jotunn is enforced separately and first:
without it the server logs `Jötunn is not installed on the client. Server has mandatory mods,
cancelling connection`.

| Mod | Announced as |
| --- | --- |
| sighsorry/Clan | `Clan`, and `Clan Media` as a second channel |
| sighsorry/STU_Ward | `STUWard` |
| sighsorry/PortalRules | `PortalRules` |
| sighsorry/CreatureManager | `CreatureManager` |
| sighsorry/DataForge | `DataForge` |
| sighsorry/Dive_In | `DiveIn` |
| Azumatt/AzuExtendedPlayerInventory | `AzuExtendedPlayerInventory` |
| sighsorry/SkadiNet | `SkadiNet` |
| sighsorry/Blasted_Swimming_Tarred_Bug_Fix | `BlastedSwimmingTarredBugFix` |
| turbero/PvPBiomeDominions | `PvP Biome Dominions` |
| turbero/DetailedLevels | `Detailed Levels` |
| WackyMole/WackyEpicMMOSystem | `EpicMMOSystem`, plus its `ItemManager` and `PieceManager` |
| team0/ValheimRAFT | `ValheimRAFT` |
| Azumatt/AzuCraftyBoxes | `AzuCraftyBoxes`. **Read from `AzuCraftyBoxes.dll` 1.8.19, and loaded on the live server 2026-09-16** (`Loading [AzuCraftyBoxes 1.8.19]`, then `Registered 'Azumatt.AzuCraftyBoxes ConfigSync' RPC`), but not yet read from a join: ServerSync announces the version whenever `IsServer()`, and the hand-rolled `AzuCraftyBoxes_VersionCheck` refuses a client that never answers. The refusal itself is what the group's first v8 session confirms (#78) |
| ValheimModding/Jotunn | mandatory-mod check, not a version line |

**Both sides, but not enforced.** These need the client to work fully and will not refuse a join
without it, so a client that skips them looks connected and behaves wrongly — except
ProximityVoiceChat, where the failure is benign and deliberate.

| Mod | Why the client needs it |
| --- | --- |
| RandyKnapp/EpicLoot | Drops are rolled where the player is, and `PlayerMustKnowRecipe` reads `Player.m_localPlayer`. The server pushes `loottables.json` to every client at join, so the tables are the server's, but the rolling and the UI are the client's |
| VentureValheim/World_Advancement_Progression | Server-side alone it only blocks the world's global key list. Private keys, every lock, and the skill floor are client features (upstream README, "Server-Side Only?") |
| ValheimModding/JsonDotNET, ValheimModding/YamlDotNet | Libraries the above load on whichever side they run |
| Azumatt/ProximityVoiceChat | Voice is captured, encoded and played on the client; the server holds the ranges and the codec through `ConfigSync("Azumatt.ProximityVoiceChat")`. `ModRequired` is false and there is no hand-rolled check, so a friend without the mod joins and plays with no voice rather than being refused (read from `ProximityVoiceChat.dll` 1.0.2) |

**Server-only.** Installing these on a client changes nothing a player can see.

| Mod | Why |
| --- | --- |
| MaxPlayerCount (fork) | Every patched surface runs on the host; a client is told the capacity by the server. Already excluded from the client pack by an assertion in the builder |
| nwesterhausen/DiscordConnector | Reads server events and posts a webhook; there is no client half |
| Digitalroot/Max_Dungeon_Rooms | **Server-side only, decided 2026-09-16.** Room counts are applied when the server generates a dungeon, and the result is world data, so a client needs nothing. It leaves the client Pack with DiscordConnector (#70). The generation argument is sound but untested on a client, so #70 proves it by entering a large crypt with a client that does not have the mod |
| ArgusMagnus/ServersideQoL | **Server-only by design (#83).** The whole family is built for vanilla and console clients, so nothing of it belongs on a client. It is the first pinned package to ship a BepInEx *preloader patcher*, which rewrites `assembly_valheim.dll` in memory to add a property to a game type — deeper than a Harmony patch, and the reason `dist/patchers/` exists at all |
| ArgusMagnus/ServersideQoL_JustSleep | **Server-only (#83).** The night skip is decided on the host and announced to clients through the framework's own message RPC; a vanilla client needs nothing |

**Client-only — presentation only, reopened 2026-09-16 (#78).** The 2026-09-16 review had cut this
whole category, on the AdminQoL lesson: a mod the server cannot enforce is a mod whose behaviour
varies per player, and AdminQoL's gameplay defaults disabled durability loss for a full evening
with no server setting able to reach them. #78 narrows that rather than reversing it. A
presentation-only mod may ride in the Pack, because a player who removes it sees vanilla and no
rule changes. A gameplay-bearing mod the server cannot reach still does not ship.

| Mod | Decision |
| --- | --- |
| Azumatt/AzuHoverStats | **Adopted client-only.** Hover readouts for creatures, pieces, items and chests. Nothing in it is server-synced — every entry is a plain `Config.Bind` and there is no `ConfigSync` in the assembly — so the server could pin nothing even if it ran the mod, while installing it server-side *would* refuse every client that lacks it through its hand-rolled `AzuHoverStats_VersionCheck`. Its chest readout is not an information bypass: the `Container.GetHoverText` postfix bails on `m_checkGuardStone && !PrivateArea.CheckAccess(...)`, and STU_Ward prefixes exactly that method with clan-resolved trust, so another clan's warded chest shows nothing (#78) |
| Azumatt/AzuClock | **Adopted client-only.** Clock and weather forecast on screen. It bundles ServerSync but is not installed on the server, so nothing of it is synchronised; a player who removes it loses a readout |
| Azumatt/MouseTweaks | **Adopted client-only.** Mouse and modifier handling for moving, splitting and dropping stacks. Plain `Config.Bind` throughout, keybinds and thresholds only |
| sighsorry/AdminQoL | **Dropped.** All 29 settings are client-decided: none is marked `[Synced with Server]` and it takes no part in the handshake (#70) |
| TOYNBEE/BoneMod | **Dropped.** Cosmetic bone scaling, client-side, pointless on the server, and unenforceable by the same argument (#70) |
| Lembitu.Harness | **Kept in the repository, never in the Pack.** It is our test harness for future acceptance work, inert without `-lembitu-harness`, and the builder asserts it is absent from a player's pack |

**Client-only is a deployment rule, and it is enforced by the installer.** `scripts/stage-stack.sh`
stages every adopted pin into `dist/`, because the client Pack is built from the same table, so
`dist/` alone does not distinguish the sides. `scripts/install-plugins.sh` carries the server's
half — a `CLIENT_ONLY` list naming AzuHoverStats, AzuClock and MouseTweaks — and it withholds them
from a server install and prunes them from a server that already has one. That is not tidiness:
AzuHoverStats disconnects a peer that does not answer its version check, so deploying it would
refuse exactly the players the Pack shipped it for. The mirror-image list, for the server-only
packages a player's Pack must not carry, lives in `scripts/build-client-pack.sh` (#78).

Both drops are done. `scripts/build-client-pack.sh` asserts that a required client-side package is
present, to catch a pack that silently lost content, and BoneMod was the only entry in that list;
the assertion is repointed to Jotunn rather than deleted, because a client without Jotunn is
refused at the handshake outright, so its absence is a hard failure rather than a missing feature.
AzuCraftyBoxes joins it for the same reason from v8 on: once the server runs it, a Pack that lost
it would refuse every player who installed that Pack. `test/client-pack.test.sh` covers the
assertion.

**The pack also ships server-only mods.** The v5 archive contains `DiscordConnector` and
`Max_Dungeon_Rooms`; both leave in v6. They are inert on a client but they inflate a 128 MB
download that players extract by hand. Trimming is #70's work, and the dungeon mod's removal
carries the one check worth doing: a client without it must still load a generated crypt correctly.

## Forks

One fork remains. Adoption is the default (ADR-0003), and configuration reaches most
project-specific behaviour without owning someone else's source.

| Fork | Forked from | Why | Ticket |
| --- | --- | --- | --- |
| MaxPlayerCount | `AzumattDev/MaxPlayerCount@4482e27` = 1.2.4 source, pinned release 1.2.5, MIT-0 | Player cap above 10, raised to 20. Upstream 1.2.5 is binary-only and declares an older BepInEx pack, so there is nothing to recompile and no adopted package that does this | #9 |

MaxPlayerCount is server-only and stays out of the client pack: every surface it patches runs on the
host, and a client is told the server's capacity by the server. Its config default is 20.

## Our plugins

| Plugin | What it owns | Ticket |
| --- | --- | --- |
| Lembitu.Harness | Client-side test harness: joins the test server from a real client and drives a character through code | #10 |

The harness is test infrastructure, not pack content. It is inert unless the client is launched with
`-lembitu-harness`, and it ships to the disposable test client only.

## Deferred capability

The **Trade Post** — contracts, escrow and mailbox delivery as server records (ADR-0006, #16) — is
not built and not in the pack. It is deliberately safe to add mid-run: its state lives in server
records that never enter the world save, so only its buildable piece becomes one-way, and only from
the day it ships. DataForge therefore stays restricted to tuning, because a later ledger needs
stable item identity.

## World-permanent mods

These write content into the world save, so they are installed before the launch world is created
and never removed during the run (ADR-0009): **Max Dungeon Rooms**, **ValheimRAFT**.

EpicLoot and World Advancement Progression are one-way for a different reason: removing them
destroys player gear or per-character progress rather than corrupting the world. World Advancement
Progression additionally clears the world's global keys on startup, so it belongs in the pack before
the launch world is created rather than after.

## Acceptance gate

No pin is cleared for the launch pack until, on the current public test game:

1. the whole pack boots clean on a dedicated server — chainloader completion, the native Steam
   listener, and no `MissingFieldException` or `MissingMethodException`,
2. one manual two-client session covers a boss kill, personal keys surviving reconnect, a ward, a
   portal and a raft.

That is the whole bar. Per-feature single-client scenario coverage was cancelled with the plugins it
was written for: nothing in the pack is ours, so proving each mod's own features is upstream's job
and ours only where the pack combines them.

One question belongs to that boot rather than to argument:

- **One gate refuses crafting and equipping, and it has never been observed doing it.** World
  Advancement Progression refuses on personal keys, by the biome of an item's materials. Until #80
  there were two such gates and the boot had to separate them; character level is gone, so a single
  observed refusal is what the gate needs.

Package hashes are recorded in [modstack.lock.json](modstack.lock.json); `scripts/stage-stack.sh`
verifies every download against it and refuses a re-published zip under the same version number.

### Measured on a disposable host — 2026-09-15

The reduced pack was staged and booted once on astral-tricep from an off-repository copy of the
source, to answer questions the tables above depend on. This is a throwaway measurement, not the
acceptance run: no client joined, and the repository carried the old pins at the time. #66 then
landed the same pack in the repository and repeated the boot with the enforced overlay in effect,
which is the section after this one.

All twenty-three packages staged with verified hashes and passed dependency closure. The build
produced only MaxPlayerCount and Lembitu.Harness, with zero warnings and zero errors. The server
reached `Chainloader startup complete` and the native Steam listener with twenty-nine plugins
loaded and **no `MissingFieldException` or `MissingMethodException`**. Thirteen errors remained,
all of them the vanilla headless noise already documented: two `AsyncResourceUpload failed`, the
`Hidden/VideoDecode` and `Hidden/VideoComposite` material and shader-pass lines, and the failed
intro cinematic.

Four findings the tables above rest on:

- **The eight Jotunn `Ambiguous asset name` warnings are still there with MWL removed.** They come
  from Jotunn indexing the vanilla catalogue, not from any mod's reference, so cutting content does
  not silence them and no reference needs correcting.
- **YamlDotNet stays.** Its own detector plugin loads it (`YamlDotNet 16.0.0.0 loaded from
  plugins/YamlDotNet/YamlDotNet.dll`), so the missing declaration is a manifest gap, not a dead pin.
- **EpicMMOSystem 1.9.67 writes no `Players.json`.** It deploys twenty-seven tables and the
  version marker; the stranger's XP-bonus file the retired fork emptied is simply gone upstream,
  so that overlay is unnecessary.
- **Three adopted packages declare older dependency pins** — EpicLoot and DiscordConnector name
  BepInEx 5.4.2333, WackyEpicMMOSystem names 5.4.2202 — so `scripts/stage-stack.sh` records those
  as deliberate overrides; without them the closure check refuses to stage the pack. #66 added
  them.

Two of those four findings have since expired. EpicMMOSystem left the pack in #80, so its
`Players.json` behaviour no longer matters, and only two adopted packages now declare an older
BepInEx pack — EpicLoot and DiscordConnector, both at 5.4.2333 — because WackyEpicMMOSystem was the
one that named 5.4.2202.

### Config surfaces this pack uses

Read off the generated files in that boot, so the enforced overlays name real keys:

- **Personal keys** — `com.orianaventure.mod.WorldAdvancementProgression.cfg`, section `[Keys]`
  (`BlockAllGlobalKeys`, `UsePrivateKeys`), `[Locking]` (`LockEquipment`, `LockCrafting`, and the
  locks we leave off), `[Raids]` (`UsePrivateRaids`), `[Skills]` (`EnableSkillManager`, now *on*
  as a floor that follows private boss keys, with the ceiling left at vanilla; the 2026-09-16
  review reversed the earlier decision to leave it off).
- **Loot gating** — `randyknapp.mods.epicloot.cfg`, section `[2 - Balance]`, key
  `Item Drop Limits`, set to `PlayerMustKnowRecipe`. Caveat worth knowing before the session: the
  mode reads `Player.m_localPlayer.IsRecipeKnown`, and EpicLoot gates everything when there is no
  local player, so it only works where loot is rolled on a client. The two-client session must show
  real magic drops rather than universal downgrades; if it does not, the fallback is `Unlimited`.
- **Difficulty tier** — `sighsorry.CreatureManager.cfg`, section `[2 - Levels]`
  (`Biome Level Preset = Hard`, `Bosses Follow Biome Level Preset`). The preset is mostly about
  ordinary creatures: it sets the level distribution for every natural spawn in a biome, and `Hard`
  spawns roughly 40% stronger creatures than the `Easy` default. Bosses follow the same preset, so
  boss level and therefore boss health — through the `Boss` `healthPerLevel` default — rises by
  biome tier; expected boss health runs ×1.05 for Eikthyr to ×2.11 for Fader. `Hard` is not the
  package default, so it is pinned deliberately (#13). Section
  `[4 - Multiplayer Difficulty]` used to be left untouched, on the reasoning that extra players
  should help rather than inflate the boss. The 2026-09-16 review took the opposite decision and
  removed headcount from the question entirely: both percentages are zero and the cap is one, and
  difficulty is set in `levels.yml` instead, at `Global.health = 2` and `Boss.health = 8`. Ordinary
  health was 4 until 2026-09-17, when character level left the Pack and every character lost its
  attribute points (#80). That file is committed and replaced wholesale, with the cost the earlier
  note named — it grows fields with every release, so a package update is a review of this file
  (#68). Its ordinary-creature modifier chances are also ours, at 0.25 each rather than the
  package's 5, because the mod rolls one modifier per group and four groups at 5 put a modifier on
  nearly every creature.

## Known interactions

Recorded so they are not rediscovered:

- **AzuEPI's vanity system has no off switch, and hiding its button is enough.** Established from
  `AzuExtendedPlayerInventory.dll` 2.4.14, sha256 `852dcde0…6840b6`, decompiled with ilspycmd 11,
  because the readme only claims the `Minimal` preset "turns off the vanity button". One key
  controls the surface — `[5 - UI Features] Show Vanity Button` — and its whole effect is
  `VanityButtonGo.SetActive(...)`. A second vanity key exists, `Hide Unknown Vanity Items`, but
  it only decides whether the panel lists undiscovered armour, so it changes nothing once the
  panel cannot be opened. Nothing gates the vanity system itself. It is sufficient
  anyway: that same GameObject carries the gamepad binding built from
  `Vanity Panel Toggle Key`, so an inactive button leaves no button, no gamepad route and no way
  to author a vanity set. Present and unreachable, which is what the run wants. The key is
  synchronised, so the server holds it for everyone
  (`config/enforced/Azumatt.AzuExtendedPlayerInventory.cfg`). The `Minimal` preset is not used:
  it would take loadouts and the stats panel with it, and both are kept deliberately (#74).
- **The Pack's inventory mod is part of the announced set, and that is the safe failure.**
  AzuExtendedPlayerInventory participates in the join-time version handshake, so any change to
  which slot mod the server runs refuses an older Pack outright rather than mismatching silently.
  Every player needs the current Pack before they can connect (#74).
- **Retention is death-cause blind.** PvPBiomeDominions patches `Player.CreateTombStone`, which
  takes no killer, so a flagged player who drowns keeps their gear too. #8's premise — dying to a
  player costing less than dying to a troll — is only half achievable with this mod.
- **Progression lives in the character save.** World Advancement Progression stores personal keys
  in the player's own character file, so a client owns its own progression. This is accepted, with
  no tamper resistance (ADR-0010). Character level used to live there too, in
  `Player.m_knownTexts`; #80 removed it, and those keys are now stranded text in every character
  file that ever had a level.
- **Creature level authority.** CreatureManager owns creature star levels outright: the biome
  preset rolls them and Karma raises them. EpicLoot's rarity rolls read that level, and boss level
  from the same preset sits on top of it. Until #80, character level rewrote those levels first,
  which is the claim ADR-0005 was written against.
- **Jotunn piece categories.** Custom pieces can appear in the build menu without a category on this
  game build. Affects ValheimRAFT.
- **EpicLoot declares an older Jotunn.** 0.14.5 declares 2.29.2 and runs against our 2.30.0 pin;
  DiscordConnector likewise declares an older BepInEx pack. Both are accepted skews, proven by the
  acceptance boot rather than by their manifests.
- **AzuCraftyBoxes' restriction file is committed empty, and one API can rewrite it.** Read from
  `AzuCraftyBoxes.dll` 1.8.19, sha256 `5a191f9c…3084d`. `YamlUtils.ReadYaml` turns a blank file
  into an empty dictionary, and `CanItemBePulled` returns true for any container the dictionary
  does not name, so an empty `Azumatt.AzuCraftyBoxes.yml` means everything in range is pullable.
  The file must exist, because the plugin writes its bundled `Example.yml` when the path is
  missing. Two facts to keep: `Containers.AddContainerIfNotExists` is a public API that appends a
  container and rewrites the file, and `YamlUtils.WriteYaml` serialises the data twice into the
  same file, so anything that calls it leaves a doubled document. Nothing in this pack calls it,
  and the overlay is compared byte for byte on every restart, so a rewrite shows up as drift
  rather than as silence (#78).
- **Two Azumatt mods refuse a client on a per-mod RPC, not through ServerSync.** AzuCraftyBoxes
  and AzuHoverStats each patch `ZNet.OnNewConnection` to invoke `<Mod>_VersionCheck` and
  `ZNet.RPC_PeerInfo` to disconnect a peer that never answered. That is what makes a server-side
  install mandatory for players, independently of `ConfigSync.ModRequired`, which both leave
  false. It is also why AzuHoverStats is client-only: the mod would refuse clients while
  synchronising nothing (#78).

## Considered and cut

Kept out deliberately. Each line is a decision, not an oversight.

Three entries left this table on 2026-09-17, hours after joining it: EpicLoot, ValheimRAFT and
WackyEpicMMOSystem were removed and then restored the same day (ADR-0017). They are pinned
again above. What did not come back is player state — levels, magic item properties and every
vessel in the save.

| Mod | Why not |
| --- | --- |
| sighsorry/BossRules | World Advancement Progression gates boss summons and guardian powers per key; its remaining refunds and stones did not justify the mod, its overlay and the altar-scan guard we had to write |
| MidnightMods/ProgressivePowers | Forsaken power mastery dropped; powers are vanilla, gated per character by personal keys (ADR-0004) |
| warpalicious/More_World_Locations_AIO | 185 locations at the cost of a world-permanent dependency and four open defect tickets; vanilla locations plus Max Dungeon Rooms carry the run |
| sighsorry/Fast_AssetBundle_Loader | Existed for MWL's 200+ bundles, and produced Linux `DriveInfo` failures and a shared-cache isolation deviation |
| sighsorry/CaptainValheim, sighsorry/SecondaryAttacks, sighsorry/AdditiveDamageModifier | Three combat layers landing on one damage number; removed rather than tuned |
| sighsorry/VeiledRecipes | Recipe discovery is already what EpicLoot's `PlayerMustKnowRecipe` gating reads |
| sighsorry/RepairRequiresMaterials | Friction without a rule behind it |
| sighsorry/Groundwork | Tool scaling not worth another mod on the placement path it already broke once |
| MidnightMods/ImpactfulSkills | Third power curve (ADR-0004) |
| sighsorry/Valheim_Enchantment_System | Second enchanting path on the same items (ADR-0004) |
| MidnightMods/ValheimArmory | New base weapons need community EpicLoot patches to be enchantable (ADR-0004) |
| MidnightMods/StarLevelSystem | CreatureManager owns creature levels (ADR-0005, as amended) |
| Smoothbrain/Groups | Second membership authority (ADR-0008) |
| sighsorry/InventoryActions | Mutually exclusive with AzuExtendedPlayerInventory, which holds the slots for this run, and smaller |
| Nosferatu/SmoothServer | One pacing layer only; SkadiNet chosen |
| WackyMole/WackysDatabase | DataForge covers tuning |
| Tristan/Valheim_PvP_Tweaks | Overlaps PvPBiomeDominions; oldest pins on the list |
| sighsorry/ServerManager | Its Discord and logging role is DiscordConnector's |
| AWLGaming/DiscordBot_AWL, warpalicious/DiscordTools, RustyMods/DiscordBot | Need an external bot host or two-way chat; the relay is a webhook |
| warpalicious/Discord_Screenshots | Client-only, nothing depends on it |
| sighsorry/YouAreNotWorthy | Gates on world keys, which this server does not write |
| shudnal/ProtectiveWards | STU_Ward covers wards |
| Therzie/Warfare | Untouched since March 2025 |
| ZenDragon/ZenBossStone | Per-player boss trophies, but pulls a second mod library into the closure |
| Hex_Viking/HexResourceTracker, GChallenge/GCValheimStats, Tristan/Player_Activity, Eilif/EilifPaths | Client-only and unenforceable; EilifPaths also changes gameplay per player |
| KGvalheim/Marketplace_And_Server_NPCs_Revamped | Deprecated on Thunderstore and pre-1.0. Design reference for the deferred Trade Post only |
| MSchmoecker/MultiUserChest | The only candidate that changes networked item movement, which is where duplication and item loss live. The vanilla "someone is in the chest" wait is an annoyance, not a problem. A risk judgement, not a conflict: its own incompatibility list — QuickStore, QuickStack, SimpleSort — touches nothing in this pack (#78) |
| Crystal/BetterChat | Clan owns the chat window: it patches `Chat.Awake`, `InputText`, `HasFocus`, `Update`, `RPC_ChatMessage` and `SendPing`, and BetterChat rewrites the same input handling and visibility, risking the clan channel's prefixes. It would also add `shudnal/ConditionalConfigSync` 1.0.6 to the closure purely to make its own settings enforceable (#78) |
| RustyMods/Seasonality | It sets the world global keys `season_winter`, `season_summer`, `season_spring` and `season_fall`, and this server blocks every global key (ADR-0005, ADR-0010). It also ships seasonal modifiers and weather control, so it is not the visual-only mod it appears to be, and it would reopen a difficulty the run fixed for its whole length (#78) |
| Smoothbrain/CreatureLevelAndLootControl | **Tried and rejected 2026-09-17, on the live server.** It was the obvious replacement for CreatureManager — plain percentages for creature and boss health, its own affix tables, and the same three multiplayer-scaling keys — but 4.6.4 is from May 2025 and cannot run on Valheim 1.0: its bundled ServerSync reads `ZRoutedRpc.Everybody`, a field the game turned into a const, so its type initializer throws `TypeInitializationException` at boot and the mod does nothing. `scripts/screen-bundled-libs.sh` reports five stale references, and it was not run before the swap — which is the whole reason that script exists (ADR-0002, #84) |
| WackyMole/WackyItemRequiresSkillLevel | **Removed 2026-09-17 and not restored**, unlike the level mod it accompanied (2026-09-17, owner's instruction). Its curated rules gated iron, wolf, padded and carapace armour at character levels 20, 35, 50 and 65, and nothing reads those thresholds once there are no levels. World Advancement Progression's material-biome locks are the whole gear gate now (#80) |

## Re-pinning

Pins are re-checked once, immediately before the launch world is created, and then frozen for the
run. Between now and then, a newer upstream version replaces a pin only if it passes the gate above
again — most of this catalogue was re-published within the last week, so a pin chosen today is hours
old, not months.
