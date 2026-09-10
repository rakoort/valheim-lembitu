# ADR-0003: Adopt upstream 1.0.7 builds instead of forking them

Date: 2026-09-10
Status: Accepted
Issues: #3, #6, #7, #24, #25

## Context

Tickets #3 through #8 were written on the premise that Valheim 1.0 had broken the mods this server
depends on and their authors had not fixed them, so each one was ours to fork, port and publish. On
2026-09-09, between 15:23 and 19:15 UTC, sighsorry re-published his entire catalogue against
BepInExPack Valheim `5.4.2350`, each release naming Valheim 1.0.7 explicitly, dropping the Jotunn
dependency and carrying a ServerSync build fixed for 1.0.7's routed RPC targets. turbero,
warpalicious, MidnightMods, RandyKnapp and Digitalroot shipped equivalent updates within hours.

That removes the reason to fork Clan, STU_Ward, BossRules, PvPBiomeDominions and DetailedLevels: a
fork exists to fix a broken build, and the build is no longer broken. Three mods did not move —
WackyEpicMMOSystem, WackyItemRequiresSkillLevel and MaxPlayerCount — and ValheimRAFT has had no
1.0-era release at all.

Forking is not free. Each fork is source we vendor, port, publish for licence compliance and
re-apply upstream releases onto, and each one drifts the moment upstream ships a fix we did not
write.

## Decision

- **Adopt, do not fork, wherever upstream ships a working 1.0.7 build.** Clan, STU_Ward and
  BossRules become adopt-and-verify rather than ports; #3, #6 and #7 close on that basis.
- **Fork only where upstream is absent**: WackyEpicMMOSystem (#5),
  WackyItemRequiresSkillLevel (#4), MaxPlayerCount (#9) and ValheimRAFT.
- **Adoption still means verification, and pinning.** An upstream claim of 1.0.7 support is
  evidence, not proof; every adopted mod passes the gate in `docs/modstack.md` before it enters the
  pack, at a pinned version.
- **Re-evaluate on publication, not on schedule.** #24 asked whether four dropped mods had been
  fixed; the answer arrived the same day. The lesson is to re-check upstream immediately before
  pinning rather than assuming yesterday's survey holds.

## Consequences

- The port work in this project shrank from five mods to four, and the four that remain are the ones
  nobody upstream is working on.
- We carry version risk instead of maintenance risk: an adopted mod can publish a change we did not
  ask for. ADR-0007 answers that by freezing pins for the run.
- `src/forks/` holds fewer, larger forks. The convention in `src/forks/README.md` still applies, but
  its examples had to change: Clan and BossRules are no longer ours.
- Licence obligations shrink with the fork count. Only the four forks need published source.
