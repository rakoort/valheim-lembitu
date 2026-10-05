# ADR-0026: Pins may come from Hexium as well as Thunderstore

Date: 2026-10-05
Status: Accepted; not yet implemented
Amends: ADR-0007 (pinned pack)

Azumatt's six mods in the Pack (AzuCraftyBoxes, AzuExtendedPlayerInventory, AzuHoverStats, AzuClock,
MouseTweaks, ProximityVoiceChat) are deprecated on Thunderstore, and their author publishes newer
releases on Hexium (`https://valheim.hexium.gg/teams/Azumatt`). The newer releases fix a possible
chest duplication and failed-craft item loss (AzuCraftyBoxes 1.8.27) and duplicate custom-slot items,
backpacks taking the cape slot and unequips after relog (AzuEPI 2.6.1)
(`local/premium-review-2026-10-04/StackHealth.md`). The owner chose to move all six to Hexium's
latest (2026-10-05). Each pin therefore names its download source; `scripts/stage-stack.sh` keeps
verifying the exact version and SHA-256 in `docs/modstack.lock.json` whatever the source, so a second
source adds no trust in a site, only a second place to fetch locked bytes from. Licences do not change
with the move: the Thunderstore copies carried none either, and ProximityVoiceChat 1.0.3 withdrew the
MIT licence 1.0.2 shipped by mistake. Staying on the deprecated Thunderstore pins was rejected because
it would keep known item-loss and duplication bugs for the Run.
