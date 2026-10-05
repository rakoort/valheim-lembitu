# ADR-0022: Two plugins of ours — Lembitu.Oathbound and Lembitu.Callings

Date: 2026-10-04
Status: Accepted; implemented 2026-10-04 in `src/plugins/Lembitu.Oathbound` and `src/plugins/Lembitu.Callings`
Amends: ADR-0020 (scope of `Lembitu.Oathbound`), ADR-0021 (owner of the Callings code)

## Context

ADR-0020 decided one patch plugin, `Lembitu.Oathbound`, for the four changes Oathbound has no
settings for. ADR-0021 then gave the Callings design to "a plugin of ours" and said it widened that
single plugin. The two halves patch different targets. The Oathbound half hooks Oathbound
internals, and Oathbound ships almost daily, so every bump means re-checking it. The Callings half
hooks vanilla skills, World Advancement Progression, BlacksmithingExpanded and Herbalist, which
change rarely, and needs from Oathbound only where the Oathstone stands.

## Decision

**Two plugins, split by what they patch.**

- **`Lembitu.Oathbound`** adapts Oathbound: respec and class switch reset to level 1, and party
  kill XP.
- **`Lembitu.Callings`** owns professions: the focus choice, the steep curve, shadow levels, the
  star in the skills window and the Oathstone check. It finds the Oathstone without linking
  Oathbound's assembly.

An Oathbound bump that breaks a hook disables only the class features; professions keep working.
Each plugin has its own enforced config and its own version check at join.

## Lembitu.Oathbound

**No talent-point cap, and Oathbound's stock XP pace.** Oathbound grants class level − 1 points
and no branch excludes another, so a level-80 character owns all 79 nodes. Level 80 costs
161,950 XP, roughly 2,500-3,000 kills at this server's creature health. The owner chose not to cap
points and not to change `ExperienceMultiplier` (1). If level 80 arrives too early in the Run, that
is revisited once observed. This drops item 4 of ADR-0020.

**A kill pays the killer's party, and nobody else.** Oathbound's `SharedExperience` stays off, so
the server attributes each kill to the owner of the killing blow (companions and burning count for
their owner). An unpartied killer earns the kill alone. A partied killer's party members near the
kill split it with the party bonus. Players who hit the creature but are outside the killer's party
earn nothing. This keeps partying the only way to share XP: if unpartied helpers kept full XP, two
strangers on one Troll would earn 200% and out-earn any party. Guilds that fight a boss together
party up first; boss keys stay presence-based and are unaffected. A party never waives proximity:
a member who is not near the kill earns nothing from it and does not count in the split.

**The party bonus rises from 100% for one to 150% for four, and stays there.** With n party members
in range of the kill (the killer included), the party shares the kill's XP ×
(1 + 0.5 × min(1, (n − 1) / 3)), split equally: one member alone earns 100%, two share about 117%
(58% each), three about 133% (44% each), four or more share 150%, so eight earn 18.75% each. Shares
are rounded at random so each member's average is exact. The first curve rose linearly to 150% at
eight; the 2026-10-04 premium review moved the full bonus to four (`FullPartySize = 4`, not yet
applied), because hunting parties are usually two to four and a three-player member earned only 38%
of a kill. That curve itself replaced the 110-125% band of ADR-0019 and ADR-0020 (owner's
decisions, 2026-10-04).

**"Near the kill" is 100 m**, measured on the server from the dead creature to each member's
reported position, among connected members. It is the same radius World Advancement Progression uses
for a boss key and ProgressivePowers for mastery credit (pinned to 100 m the same day), so "present
for the fight" means one distance across the server. The centres differ slightly: a boss key is
measured from the player whose game controls the boss. A member SocialSystem holds in the party while
disconnected is never in range, and neither is a dead member. The killer always counts, wherever
they stand: an unpartied killer earns a long-range kill in full, so joining a party never costs the
killer a kill (decided from the code, 2026-10-04).

**Every class may gather with every profession.** Oathbound's equipment rules (`Equipment.Allows`)
treat the fishing rod as a two-handed weapon, so Rogue, Monk, Berserker, Highlander and Breaker could
not fish, and a Monk holds no pickaxe or axe and mines and chops bare-handed, which raises Unarmed
rather than Mining or Wood Cutting. `Lembitu.Oathbound` lets every class equip the fishing rod, and
a Monk's bare-handed hit on a rock or tree raises Mining or Wood Cutting. Armour, weapon, shield and
bow restrictions stay as Oathbound ships them. A class therefore never narrows a Calling
(ADR-0021: anyone can practise any profession).

How it is built, decided from the code rather than asked:

- **Respec.** After `Warrior.Core.Progression.Respec` clears the active class's talents, its XP is
  set to zero, so the class is at level 1. The tree's "Reset for free" button reads "Reset to level
  1".
- **Class switch.** After a successful `Progression.SwitchClass`, both the class left and the class
  taken have their XP and talents cleared. Their records are kept, because Oathbound keys the unlock
  of Berserker, Highlander, Breaker and Dragonsworn on the record existing. Oathbound switches at
  the first click on "Take this oath", so when either class has progress the button now asks once
  more and names both classes; the picker's and the notice's "each class keeps its own progress"
  say the opposite now.
- **Kill XP.** Oathbound's server-side `RouteDeath` keeps its validation and its per-creature XP
  (`KillRewards.Experience`); only the send of the killer's reward is replaced, by a transpiler on its
  one `ZRpc.Invoke` and its listen-host `ReceiveReward` call. Party membership comes from
  SocialSystem's server-side party service by player ID, not from the party ID clients publish on
  their character, which a client writes and the server cannot vouch for. Shares are rounded at
  random so each averages exactly, and the server logs each split.
- **Gathering tools.** Every class check describes the item through Oathbound's `Plugin.Describe`
  and asks `Equipment.Allows` about that `EquipmentItem`, which records the rod as a two-handed
  weapon and nothing more. A postfix on `Describe` describes a fishing rod as no weapon at all, which
  every class may hold. The vanilla rod has no skill (`None`) and the float is carried by the bait it
  fires, so the rod is recognised by its name (`$item_fishingrod`) or, for a modded rod, by firing
  bait (measured 2026-10-04). A Monk's
  bare-handed hit on a rock or tree (`Plugin.MonkGather`) raises Mining or Wood Cutting instead of
  Unarmed, by the same amount Oathbound gave Unarmed.
- **Enforced Oathbound config.** `SharedExperience = false` and `ExperienceMultiplier = 1` are pinned,
  because the design above depends on them.

## Lembitu.Callings

**The Calling is chosen in a window, only at the Oathstone** (owner, 2026-10-05 premium review; not
yet implemented). A Calling button in the skills window opens a window listing the eleven professions
under Land, Craft and Road with the 2-1-1 quota, each skill's level, and what a focus changes. It can
be read anywhere. Within about 10 m of the Oathstone (the `WarriorOathstone` object Oathbound places
beside the start temple) a change takes effect at once; elsewhere the controls say to go to the
Oathstone. There is no pending state. Dropping a focus asks for confirmation and names the level the
skill falls to. The stars on each profession row of the skills window stay as read-only markers with
their tooltip; first built as the clickable control, they keep their own target because DetailedLevels
uses a click on the row to show skill buffs.

**A focus keeps its XP on death; its shadow does not.** Dying leaves a focus skill's level and its
progress into the next level untouched. Its shadow, being what the skill would be without the focus,
drains as a non-focus skill would: World Advancement Progression's relative drain and boss-key floor,
applied to the shadow's own level. Dropping a focus therefore gives back both the faster gain and the
death protection the focus gave. Combat, body and non-focus profession skills drain as before. With
the ladder of ADR-0023, a specialist never drains below a rung of their own focus.

**Herbalist and Fishing get a bonus-output perk.** Neither mod gives its producer a level-scaled
perk: tonic strength reads the drinker's skill, and no pinned mod scales fishing. `Lembitu.Callings`
adds expected extra output that grows linearly with level: about 1.5 extra items per successful
tonic, elixir or mead-base craft and about 1.25 extra fish per landed catch at 100 (ADR-0024). Each
craft or catch rolls once: the whole part of the expectation is given and the fraction is a chance,
so the average is exact. It copies the item's identity and quality, consumes nothing more and grants
no extra skill XP.

**Every profession skill drains by one rule.** BlacksmithingExpanded and Herbalist bring bundled
skill managers that take their skill out of the list during death, apply their own loss and put it
back, so World Advancement Progression's drain and floor never see it (Blacksmithing lost 5% even
below the floor; Herbalist lost nothing). `Lembitu.Callings` records both skills before the death,
puts them back after the managers' own handling, and drains a non-focus Blacksmithing or Herbalist
once by World Advancement Progression's settings and boss-key floor, in the same death step where
it protects focuses and drains shadows. The managers' own loss setting therefore never counts. It
could not be pinned anyway: BlacksmithingExpanded files it under a section named after an unresolved
localization key (`[skill_1208107160]`), so the first overlay aimed at `[Blacksmithing]` did nothing,
and a native death on 2026-10-04 drained Blacksmithing twice (20 → 19 → 18.05) before this was
changed.

**A seed bed is a planter that follows soil's rules** (owner, 2026-10-05 premium review; not yet
implemented). SeedBed 1.2.9 checks only ward access, the seed and the seed count before a bed accepts
seeds (`Germination.UseItem`), so a bed grew any crop in any biome and bypassed Farming's level-60
reward. `Lembitu.Callings` refuses seeds whose plant cannot grow in the bed's biome unless the planter
has Farming 60, the level at which ImpactfulSkills lifts the biome rule for soil
(`FarmingBiomeUnrestrictedLevel`). The plant's biomes are read from the vanilla `Plant` of the
cultivator piece that takes that seed. SeedBed's synced conversions are set to soil's yields in place
of its five-for-fifteen.

**BlacksmithingExpanded's settings are locked by us** (owner, 2026-10-05 premium review; not yet
implemented). Its main `ConfigSync` sends settings from the server but registers no locking entry and
never sets `IsLocked`; only its bundled skill manager is locked (BlacksmithingExpanded 1.2.4 decompile,
`local/premium-review-2026-10-04/AuditCombat.md` §2). A client could change the smith's gear
bonuses, against the Pack rule. `Lembitu.Callings` sets that sync to locked at startup and logs the
feature like its others.

**Tonics follow the food rule for boss keys** (owner, 2026-10-05 premium review; not yet
implemented). World Advancement Progression locks eating by the biome of an item's materials but lets
materials it does not know through (`KeyManager.cs:1422-1432`, `local/premium-review-2026-10-04/
AuditEconomy.md` §4), and it knows none of Herbalist's herbs. So a tonic or elixir bought on the
Market could be drunk without its biome's boss key. `Lembitu.Callings` maps each Herbalist herb to
its biome, as the ladder generator already does (ADR-0023), and refuses a tonic or elixir whose
highest-biome herb needs a boss key the drinker lacks, with the same message World Advancement
Progression gives for food.

**A new character survives ExpertExplorer's first save.** ExpertExplorer 1.7.0, the Exploration
profession's mod, aborts the first save of every new character: its old-format check passes a missing
version tag to `Regex.IsMatch`, which throws (`docs/modstack.md`, "Known interactions"). A
Thunderstore search on 2026-10-04 found no better-built replacement. Advize/CartographySkill 3.2.0
sets the reveal radius back to base each time a world loads and raises it again only at the next
level-up (`Minimap.Awake` postfix; `UpdateExploreRadius` called from `OnSkillLevelup`).
blacks7ar/Explorer 1.1.7 tracks resources, dungeons and caves, the radar ADR-0019 rules out.
Smoothbrain/Exploration is deprecated. ExpertExplorer has no newer release and no upstream issue for
this. `Lembitu.Callings` therefore answers a missing tag the way the check answers any non-version
tag, "old format"; the old-format readers find nothing to read on a character without data. The same
answer covers a character made before ExpertExplorer was installed, which meets the check on load.

How it is built, decided from the code rather than asked:

- **Gain.** A lowest-priority prefix on `Skills.RaiseSkill(SkillType, float)` scales `factor` for the
  eleven profession skills. Every one of them reaches that method: vanilla skills directly, the
  Jotunn skills of ImpactfulSkills and ExpertExplorer and the bundled-manager skills of
  BlacksmithingExpanded and Herbalist through `Player.RaiseSkill`. Running last means ImpactfulSkills'
  per-skill rates and any learning bonus are already in `factor`. World Advancement Progression's
  `Skill.Raise` replacement then applies its ceiling as before.
- **Shadow levels.** Only a focus skill stores one; a non-focus skill's shadow always equals its real
  level. When a skill becomes a focus its shadow starts at its current level and progress, and every
  later gain also advances the shadow at the steep-curve rate against vanilla's level requirement,
  through World Advancement Progression's own gain rule (`SkillsManager.GetSkillAccumulationGain`).
  Dropping the focus sets the real level to the shadow and clears its accumulator.
- **Death.** A focus skill's level and accumulator are saved before `Skills.OnDeath` and restored
  after every other patch on it has run, the two bundled skill managers' own drain included; their
  drain therefore never reaches a focused Blacksmithing or Herbalist. ImpactfulSkills restores its
  hidden skills the same way (`ImpactfulSkills.cs:4710-4737`). The shadow, and a non-focus
  Blacksmithing or Herbalist, are drained at the same moment by World Advancement Progression's own
  `GetSkillDrain`, floor and normalisation, with vanilla's factor (`m_DeathLowerFactor` ×
  `Game.m_skillReductionRate`). That step runs whenever `Skills.OnDeath` runs; a mod that blocks
  `LowerAllSkills` (Venture Multiplayer Tweaks' `SkillLossOnAnyDeath = false`) would stop the other
  skills draining but not these, so that setting stays at its default.
- **The star.** A badge on each profession row's icon with its own button and tooltip, added after
  DetailedLevels' own Setup postfixes. The rows follow `GetSkillList` inside `SkillsDialog.Setup`,
  where ImpactfulSkills' hidden-skill filter and DetailedLevels' sort are both in force. The Oathstone
  is found as a loaded `WarriorOathstone` network object within 10 m, without linking Oathbound.
  Dropping a focus confirms in the game's own yes/no popup.
- **Bonus output.** Herbalist's 17 products and every vanilla mead base (`MeadBase*` and
  `BarleyWineBase`) count as Herbalist crafts. The bonus is granted only when `InventoryGui.DoCrafting`
  actually added the product, with the same quality, variant and crafter, and never for upgrades. A
  catch is `FishingFloat.Catch` on the fisher's own client; the extra fish are copies of the landed
  one and drop at the fisher's feet when the inventory is full. Both read the producer's skill as the
  perks do, status effects included.
- **Storage.** A versioned record in `Player.m_customData` (`lembitu.callings`), beside Oathbound's
  own, holding the four focuses and their shadows. A record that cannot be read is never
  overwritten; the character plays with no Calling and its stars say to ask an admin.
- **Settings.** The curve bands and rates, the Oathstone range and both bonus rates are server-locked
  through Jotunn, which the Pack already requires (`config/enforced/lembitu.callings.cfg`).

## Consequences

- Adding a plugin is adding a directory (ADR-0001); the build cost of two is the same as one.
- An Oathbound pin bump re-checks `Lembitu.Oathbound` only.
