# Forks of third-party mods

One directory per forked mod, named after the mod (`src/forks/Clan/`, `src/forks/BossRules/`). Our
own plugins live in `src/plugins/` instead; the split exists so it is always obvious whose code you
are reading and whose licence applies.

Each fork directory contains:

- the mod's source, ported to Valheim 1.0.7,
- a `.csproj` following the conventions in `docs/build.md`,
- `UPSTREAM.md` recording:
  - upstream repository or Thunderstore page, and the exact version or commit we forked,
  - the licence, and where the original licence text lives in the directory,
  - every change we made, and why (so a future upstream release can be re-forked deliberately).

Keep our changes minimal and separable. A port is not an opportunity to restyle upstream code:
diffs against upstream are the only practical way to re-apply our work on a later release.
