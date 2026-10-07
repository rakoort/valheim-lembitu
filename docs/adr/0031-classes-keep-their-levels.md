# ADR-0031: Classes keep their levels

Date: 2026-10-06
Status: Accepted; ships with Pack v17, native acceptance still required (#92, #99)
Amends: ADR-0020 and ADR-0022 (respec and class switch)

## Context

The Run's first evening made the cost of experimenting real: our reset hooks erased class XP on a
respec and erased both classes on a switch. Stock Oathbound 0.21.14 already stores XP and talents
per class (`Warrior.Core.Progression._classes`). The owner chose to keep that progress rather than
make a player repeat kills to try a different role. The Oathstone still makes choosing a role an
intentional trip; reading and spending points need not require one.

## Decision

**Each class keeps its own progress.** Switching at the Oathstone is free. Returning to a class
restores its XP and talents; resetting talents is free there too, without losing XP. Only the active
class earns kill XP. Breaker, Highlander, Berserker and Dragonsworn keep their shipped unlocks.

**The tree opens anywhere, the oath changes only at the stone.** The inventory Classes button
appears only after the first oath, which is taken at the Oathstone. Afterwards a player may open the
tree and spend points anywhere. Taking an oath, including the first, and Reset talents require
Oathbound's own stone range. Away from it the action is disabled or refused with a short message
naming the Oathstone. `AccessMode = MenuButton` supplies the tree; our patch supplies the restriction
that this stock mode lacks.

**Remove the resets, not disguise them.** `ClassReset.cs`'s RespecPlan, SwitchPlan,
SwitchConfirmationPlan and LabelPlan leave. Stock wording returns: “Reset for free” and “Each class
keeps its own progress”. The extra switch confirmation leaves with the XP cost it warned about.

**Nothing else changes.** Death still costs half the progress into the current level of the active
class only, never a level. Party XP, poison credit, gathering tools, personal-key power caps,
spell growth and companion damage remain as decided. Power stops at 80 after Fader (ADR-0033).

## Consequences

- A player can try a role without destroying another role's work. This does not grant the new
  class levels: it still has to earn its own XP.
- Levels already lost to switches since the Run began cannot be restored.
- Native acceptance must show a free respec keeping XP, a switch away and back keeping both
  classes' records, a readable/spendable tree away from the stone but refused oath/reset actions,
  and no Classes button on a fresh character before the first oath.
