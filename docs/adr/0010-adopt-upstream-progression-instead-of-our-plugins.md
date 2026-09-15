# ADR-0010: Adopt upstream progression instead of writing our own plugins

Date: 2026-09-15
Status: Accepted
Issues: #11, #12, #13, #14, #15, #16, #17, #27, #44

## Context

The plan carried nine plugins of our own: personal keys, contribution credit, boss health scaling,
a PvP XP bonus, banked offline XP, the Trade Post, a Discord relay, the progression bridge and a
build-skew probe. None of them existed yet, every one of them would have been load-bearing on a
private server with fifteen players, and three of them (personal keys, the bridge, contribution)
depended on an unresolved question about whether character saves could be trusted (#44).

The mod ecosystem moved in the meantime. `VentureValheim/World_Advancement_Progression` 1.0.0
(2026-09-10) implements private per-character keys, blocks the world's global key list, evaluates
raids per player and gates actions on those keys — against exactly our BepInEx and Jotunn pins.
EpicLoot 0.14.5 already offers `PlayerMustKnowRecipe` for its drop gating, which reads the
requesting player rather than the world. CreatureManager exposes boss level and health scaling in
config. `nwesterhausen/DiscordConnector` 3.1.3 is a maintained server-side webhook relay.

At the same time the stack itself had grown to thirty packages, with three combat layers landing on
one damage number, a world-permanent content mod responsible for four open defect tickets, and a
diagnostic backlog describing warnings in code we were about to delete.

## Decision

- **Ship no custom gameplay code.** Personal keys, the progression bridge, contribution credit, the
  PvP XP bonus, banked XP and the Discord relay are cancelled as plugins. What survives of ours is
  `Lembitu.Harness` (test infrastructure) and the MaxPlayerCount fork (ADR-0003).
- **Adopt World Advancement Progression** as the personal-key mechanism, with private keys on,
  global keys blocked, private raids on, and only equipment and crafting key-locked.
- **Adopt DiscordConnector** for the relay.
- **Answer loot gating with EpicLoot's own config**, `Item Drop Limits = PlayerMustKnowRecipe`.
- **Scale bosses through CreatureManager config**, not a plugin: boss level, and therefore boss
  health, rises by biome tier so that later bosses need two or three cooperating clans rather than
  one clan of three to five.
- **Accept character saves as authoritative** for keys and character level, with no tamper
  resistance. This settles #44 by decision rather than by engineering.
- **Defer the Trade Post** (ADR-0006) and drop the remaining XP capabilities, since EpicMMOSystem
  already ships a PvP damage band and PvP kill XP.
- **Cut ten mods** — BossRules, ProgressivePowers, More World Locations AIO, Fast_AssetBundle_Loader,
  CaptainValheim, SecondaryAttacks, AdditiveDamageModifier, VeiledRecipes, RepairRequiresMaterials
  and Groundwork — leaving twenty-three packages (`docs/modstack.md`).
- **Shrink acceptance** to one clean full-pack boot plus one manual two-client session, and cancel
  the per-feature single-client scenario work that existed to prove our own plugins.

## Consequences

- The project maintains no gameplay code. A game update becomes a question of upstream pins rather
  than of re-porting our own patches, and the re-fork procedure applies to one small file.
- **Progression is client-owned.** A determined player can edit their own character file to grant
  themselves keys or levels. Accepted deliberately: this is a private, invited roster.
- **Presence, not damage, earns a key.** One clan can carry another to a boss kill. That is a social
  matter in a group of fifteen, and it is the right side to err on when the goal is cooperation.
- **Two gates refuse the same actions.** Character level and personal keys both hook equipping and
  crafting, so a player can meet one and fail the other. The refusal messages come from two mods and
  will not read as one system.
- **EpicLoot's per-player gating is untested here.** Its mode reads `Player.m_localPlayer`, and the
  mod gates everything when there is no local player, so it only works where loot is rolled on a
  client. If the two-client session shows universal downgrades, the fallback is `Unlimited`.
- **Less content.** Cutting More World Locations AIO removes 185 locations; the run leans on vanilla
  locations, larger dungeons, Karma pressure and clan politics instead.
- **Offline trade is gone for now.** Players with little overlap must meet to trade until the
  deferred ledger is built.
- The diagnostic backlog closes with the code it described, and the warnings that survive are
  vanilla: the eight Jotunn ambiguous-name warnings are catalogue duplication, unchanged by removing
  content.
