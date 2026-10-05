# ADR-0027: An in-game guide window, in a third plugin of ours

Date: 2026-10-05
Status: Accepted; not yet implemented
Amends: ADR-0022 (two plugins of ours)

The Run's rules (an oath before class XP, the Calling, the profession ladder, personal boss keys,
guild against party, the Market, death costs) were explained only in `docs/rules.md`; in game a new
player saw "Visit an Oathstone" and little else (`local/premium-review-2026-10-04/AuditUX.md` §3).
The owner wants a real interface, not signs (2026-10-05). The scouting found no maintained mod with an
editable rulebook window; RustyMods/Almanac 3.8.0 came closest but is a large codex, NPC and
achievement system whose tutorials are built into its DLL and whose currency, store and market overlap
Guilds and Marketplace (`ScoutMeta.md` §1). So we build a guide window: chapters of short pages,
opened by a hotkey and an inventory button and shown on a character's first join, with its text in a
server-synced file the admin edits, so rules and tips change without a new build. It lives in a third
plugin, `Lembitu.Guide`, rather than in `Lembitu.Callings`: it hooks only the inventory and its own
file, so Oathbound and profession-mod updates never re-check it, and adding a plugin is adding a
directory (ADR-0001). Like the other two it declares `EveryoneMustHaveMod`.

**Refusals name their cause and the guide page** (owner, 2026-10-05). A refused craft, equip or drink
says which rule blocked it (personal boss key, profession rung, class equipment rule, tonic key) and
which guide page explains it. Each message is written where the refusal is decided: World Advancement
Progression's and Item_Requirement's message settings where they have them, `Lembitu.Oathbound` for
Oathbound's equipment rule, `Lembitu.Callings` for the tonic key. The first oath, the first opening of
the Calling window and the first party open the matching guide page once; `Lembitu.Guide` reads that
state rather than patching the mods that own it.
