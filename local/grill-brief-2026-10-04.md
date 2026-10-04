# Grilling brief — continue the 2026-10-04 design session

Use the `grilling` skill, one question at a time with the ask tool. Nothing is published or deployed;
do not publish, push or deploy without the owner saying so. Cohesion matters more than feature count.
The owner decides; look facts up yourself (decompile mods, read configs) before asking.

## Read first

- `docs/adr/0019-the-server-concept-mmorpg-lite-for-rival-guilds-that-cooperate.md` — the concept.
- `docs/adr/0020-oathbound-owns-class-level-talents-and-magic.md` — combat, talents, magic, parties.
- `docs/adr/0021-callings-focus-professions-across-craft-land-and-road.md` — professions.
- `CONTEXT.md` — glossary (Guild, Party, Calling, Focus, Skill floor, Tuning target).
- `docs/modstack.md` — the 64-pin stack, each row's enforced config, and "Considered and cut".
- `local/mod-review-2026-10-04/` — decompiled research behind every verdict (conflicts-*, fit-*, prof-*).

## State of the repository

Only documentation was committed. The matching code and config changes are in the working tree,
uncommitted, on purpose: `config/enforced/*` overlays (new and edited), `config/dedicated/*`,
`scripts/stage-stack.sh` (overrides, pin tripwire 64), `scripts/build-client-pack.sh` (exclusions),
`docs/modstack.lock.json`, deletions of retired overlays. Until those are committed, a clean checkout
of HEAD cannot stage the documented pin list (the dependency-closure overrides live in the
uncommitted `stage-stack.sh`). `src/plugins/Lembitu.LevelUpSound/` is untracked and dead since
EpicMMO left; the owner decides whether to delete it.

## Settled (do not reopen unless the owner does)

Concept: ~8 players, guilds of 3-5 (cap 5, no limit on guild count), separate starts, no PvP,
harder than vanilla with every value fixed and no player scaling, bosses tuned for 8 and creatures
for 2, Fader in about a month. Oathbound for classes, talents and magic; SocialSystem parties.
Callings: two Land, one Craft, one Road focus; non-focus profession skills level on a steep curve
(full to 30, half to 60, quarter to 80, tenth beyond); dropping a focus knocks the skill down to its
non-focus shadow level; focus starred in the skills window, changed only at the Oathstone. World
13250 / 1.325 / 1.25 / locations 1.75. Boss loot one drop per kill. Seasons scrapped. Death debuff
dropped. Pack rule allows preference-only player settings.

## Open frontier, in suggested order

1. **Plugin spec (`Lembitu.Oathbound` + Callings).** One plugin or two. Respec and class switch reset
   to level 1 (hook `Warrior.Core.Progression.Respec` / `SwitchClass`). Talent-point cap: number, or
   wait for Shakedown pace. Party XP: formula giving ~110-125% total at any party size, reading
   SocialSystem's party ZDO, patching Oathbound's server-side kill routing (`Plugin.cs` ~9885-9940).
   Callings: XP hook for eleven profession skills, shadow levels, storage on the character, the
   skills-window star (DetailedLevels also patches that window), Oathstone proximity check, and how
   BlacksmithingExpanded/Herbalist skills (bundled SkillManager) are hooked.
2. **Master recipes per profession.** What is gated at 60-75 with Item_Requirement; which premium
   items are authored in DataForge; boss trophies as ingredients. Research gaps: Farming, Gathering,
   Animal Handling and Road have no obvious premium item in the current pool
   (`prof-RecipeGatesAndQuality.md`).
3. **Perk thresholds.** Move ImpactfulSkills, Herbalist and BlacksmithingExpanded top perks above 30
   so focus matters; BlacksmithingExpanded's own combat item bonuses (damage, armour) on or off
   against EpicLoot and Oathbound.
4. **Death loss for BlacksmithingExpanded and Herbalist.** Their bundled SkillManager bypasses the
   boss-key floor; set their loss percentage to match vanilla drain, or patch.
5. **Remaining mod checks not yet put to the owner:** ExpertExplorer vs ImpactfulSkills Voyager radius
   overlap and Njord vs Voyager handling; ProgressivePowers settings (kill-credit range 200 m vs the
   100 m boss-key presence, one attunement); Oathbound sieges vs ZenRaids and the guild monster ward;
   Herbalist's tonic levels vs the steep curve; SearsCatalog, XPortal, DynamicStoragePiles,
   DodgeShortcut, TheFisher, SeaAnimals, OdinShip, SaunaMod settings were never reviewed in detail.
6. **Operational:** SeparateSpawns roster by Steam ID once guilds are known; Pack seed with the
   ServerQuickConnect address (never the password); DiscordConnector is documented as withheld from
   the client pack but `scripts/build-client-pack.sh` does not exclude it; `docs/rules.md` still
   describes Clan, PvP and EpicMMO and needs a rewrite after the plugin spec.
7. **Shakedown measurements to plan:** Njord per-hull speed caps vs vanilla, tuning targets,
   steep-curve numbers, level-80 pace for the talent cap.

## Facts worth knowing before asking

- World Advancement Progression's skill floor is a death-drain threshold; it never raises a skill.
- Oathbound: points = class level − 1, every node costs 1, 79 nodes, cap 80; respec is free in stock;
  death removes half the unfinished level's XP; shared XP gives full XP to every damage dealer.
- Item_Requirement blocks the craft itself and reads raw skill level, including modded skills.
- ImpactfulSkills `EnableWeaponSkill=false` still leaves equip speed on; the overlay zeroes its factor.
- EpicLoot `Item Drop Limits = PlayerMustKnowRecipe` because world keys are blocked.
