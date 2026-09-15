# ItemRequiresSkillLevel

Blocks crafting, equipping and consuming an item until the character meets a requirement, and says
so in the tooltip and on the crafting panel. On this server the requirement is **character level and
attributes** (ADR-0004's second power curve), which is what stops a clan handing a newcomer endgame
gear.

| | |
| --- | --- |
| Upstream | <https://github.com/Wacky-Mole/ItemRequiresSkillLevel> |
| Forked at | `be31aa95e6a0be25f6cb036c2164e626cc91eef4` (2026-05-08, "update for Iron") |
| Version | `1.4.6` — the commit above declares it, and it is byte-identical to the pinned Thunderstore release `WackyMole/WackyItemRequiresSkillLevel 1.4.6` |
| Licence | **None stated.** Upstream's tree contains no licence file. The readme records the mod as originally by Detalhes and "maintained by WackyMole with permission" |
| Built for | Valheim 1.0.7 (network version 39), BepInEx 5.4.23.5 |

The missing licence is a real constraint, not an oversight of ours: the source lives here because we
must port it, and it should not be redistributed outside this repository without asking the
authors. Everything else in `src/forks/` carries an explicit licence.

## Why this fork exists

Upstream declares BepInEx `5.4.2333` and has not moved since May 2026 (ADR-0003: we fork only where
upstream is absent). The shipped 1.4.6 DLL is ILRepacked with **its own copy of ServerSync**, built
before Valheim 1.0, and the plugin's `ConfigSync` and `CustomSyncedValue` are static field
initialisers — so the failure happens in the type's static constructor, before anything else runs.
`src/forks/ServerSync/UPSTREAM.md` explains the mechanism: 1.0 turned `ZRoutedRpc.Everybody` into a
`const`, and a pre-1.0 assembly still carries an `ldsfld` to a field that no longer exists.

Recompiling against `lib/valheim/` and importing our ServerSync source fixes that at the root.

## Our changes

1. **De-ILRepacked.** `ServerSync.dll` and `YamlDotNet.dll` are gone, along with
   `ILRepack.targets` and upstream's `.csproj`/`.sln`/`Thunderstore/` tree. ServerSync comes from
   `src/forks/ServerSync/ServerSync.props` (ADR-0002); YamlDotNet is a compile-time
   `PackageReference` pinned to the exact build the server loads at runtime from the pinned
   `ValheimModding/YamlDotNet` plugin. That package's payload is YamlDotNet **16.3.0**
   (assembly version `16.0.0.0`) even though the Thunderstore version reads 16.3.1, and 16.3.1 was
   never published on NuGet — so the reference is `[16.3.0]`, exact. A floating `16.3.1` reference
   silently resolves to 17.x, whose assembly version the running game would refuse.
   Everything this mod uses of our `ConfigSync` exists: the constructor, `DisplayName`,
   `CurrentVersion`, `MinimumRequiredVersion`, `AddConfigEntry`, `AddLockingConfigEntry`, and
   `CustomSyncedValue<T>` with `Value`, `AssignLocalValue` and `ValueChanged`.
2. **Plugin identity from `PluginInfo`**, generated from the `.csproj` (`docs/build.md`). The GUID
   is unchanged — `WackyMole.ItemRequiresSkillLevel` — because the rule files are globbed from it
   and the ServerSync channel is named after it. Upstream's two file-name literals now derive from
   the same constant instead of repeating the string.
3. **World Advancement Progression support removed.** Upstream declared a soft dependency on it and
   used its presence to widen key checks from the per-player key set to the world-wide one. That mod
   is not in this stack, and world progression is exactly what ADR-0005 replaces: personal keys are
   authoritative, so a key rule asks what *this character* has done. The scope is now
   `GameKeyType.Player`, stated once with a comment naming #11, which owns the question of where
   personal keys are stored. The global-key branch itself is kept: issue #4 requires it to work,
   because that is the code path personal keys will answer through.
4. **The generated sample rule file is ours.** Upstream wrote a sample seeded with vanilla-skill
   rules and `defeated_*` world-key rules — on a fresh server, that sample becomes live
   configuration. Ours demonstrates the same schema with character-level and attribute rules plus
   one key rule. `config/enforced/WackyMole.ItemRequiresSkillLevel.yml` ships our real rules, and
   the generator only writes when no rule file exists at all, so on our server it never fires.
5. **Two diagnostics, because the mod's failure mode is silence.** Both are ours:
   - At rule load: how many files, rules and requirements were read, and a warning naming any
     requirement that can never be met. An unrecognised skill name hashes to a `SkillType` nobody
     has, so the evaluator reports it unmet and the item stays blocked for everyone, permanently.
   - When the item database appears (`ObjectDB.Awake`) and on every later reload: a warning naming
     every rule whose prefab does not exist, plus a count of the rules that do match. A misspelled
     prefab gates nothing and upstream never said so.
   These two lines are also the only evidence a headless server can produce for this mod: the gate
   itself runs client-side against `Player.m_localPlayer`.
6. **`<Nullable>annotations</Nullable>`**, not `disable`. Upstream is `LangVersion 9` with a few
   nullable annotations, and the ServerSync source compiled in here is fully annotated; `disable`
   reports every `?` in ServerSync as CS8632. `annotations` accepts both and warns on neither.
7. One duplicate `using` removed (CS0105). No other formatting or style change: the diff against
   upstream stays reviewable.

## Verified against 1.0.7

Every patch target and the members with a history of changing arity, checked in
`lib/valheim/assembly_valheim.dll` before the port and then re-checked by the compiler, which sees
publicized references:

| Member | 1.0.7 |
| --- | --- |
| `ItemDrop.ItemData.GetTooltip(int)`, `.IsEquipable()` | unchanged |
| `Humanoid.EquipItem` | `(ItemData item, bool triggerEquipEffects = true)` — the prefix binds the first parameter by name |
| `Attack.StartDraw(Humanoid, ItemDrop.ItemData)` | unchanged |
| `Player.CanConsumeItem` | `(ItemData item, bool checkWorldLevel = false)` |
| `InventoryGui.UpdateRecipe` | `(Player player, float dt)` — upstream's postfix took `(Player)`, which still binds |
| `InventoryGui.m_selectedRecipe`, `m_recipeDecription`, `m_craftButton` | present, including vanilla's misspelling |
| `Game.RequestRespawn` | `(float delay, bool afterDeath = false)` |
| `ZoneSystem.CheckKey` | `(string key, GameKeyType type = Global, bool trueWhenKeySet = true)`; `GameKeyType` is `{ Global, Player }` |

## Integration with EpicMMOSystem

`EpicMMOApi.cs` is vendored unchanged and stays reflection-only: it resolves
`EpicMMOSystem.EpicMMOSystem, EpicMMOSystem` as a presence probe, then `API.EMMOS_API, EpicMMOSystem`
for `GetLevel()`, and reads attributes straight out of
`Player.m_localPlayer.m_knownTexts["EpicMMOSystem_LevelSystem_<Attribute>"]`. There is no assembly
reference and no build-order dependency between the two forks, and no Harmony patch across them —
but those names are a contract. `src/forks/EpicMMOSystem/UPSTREAM.md` records the same contract from
the other side.

## Re-forking

Pull upstream's four `.cs` files, re-apply changes 2–7 (the compiler and this list are the guide),
and re-check the signature table above against the new game build. `ILRepack.targets`, the bundled
DLLs and the `Thunderstore/` tree are never vendored.
