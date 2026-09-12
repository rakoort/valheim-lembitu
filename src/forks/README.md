# Forks of third-party mods

One directory per forked mod, named after the mod (`src/forks/EpicMMOSystem/`,
`src/forks/MaxPlayerCount/`). Our own plugins live in `src/plugins/` instead; the split exists so it
is always obvious whose code you are reading and whose licence applies.

Prefer official working 1.0.7 builds (ADR-0003). Retain a fork when it carries project-specific
behavior that upstream does not provide; import applicable official updates without losing that
behavior. `docs/modstack.md` lists which mods are adopted or maintained here.

Each fork directory contains:

- the mod's source, ported to Valheim 1.0.7,
- a `.csproj` following the conventions in `docs/build.md` (except for library forks, below),
- `UPSTREAM.md` recording:
  - upstream repository or Thunderstore page, and the exact version or commit we forked,
  - the licence, and where the original licence text lives in the directory,
  - every change we made, and why (so a future upstream release can be re-forked deliberately).

Keep our changes minimal and separable. A port is not an opportunity to restyle upstream code:
diffs against upstream are the only practical way to re-apply our work on a later release.

Forks inherit the shared build configuration in `Directory.Build.props` (see `docs/build.md`),
including `PluginGuid` being required. Upstream code written before nullable reference types should
set `<Nullable>annotations</Nullable>` in its own `.csproj` rather than absorb edits to silence
warnings. Not `disable`: a fork that imports our ServerSync compiles annotated source, and
`disable` reports every `?` in it as CS8632.

A fork may carry third-party libraries its upstream bundled as DLLs. Vendor those **as source**
too, under the fork's `Libs/`, with each one's origin and licence recorded below in `UPSTREAM.md`.
A prebuilt pre-1.0 copy is the ADR-0002 hazard repeated: `src/forks/EpicMMOSystem` found two of
them reading a field that 1.0 turned into a `const`, which fails at runtime and not at build.

`ServerSync/` is a **library** fork, not a plugin: it has no `.csproj` and produces no DLL of its
own. A `ServerSync.props` next to the source compiles it into whichever plugin imports it, which is
how upstream is meant to be used. A ported mod that shipped its own copy of ServerSync drops that
copy and imports ours instead — see `src/forks/ServerSync/UPSTREAM.md` and ADR-0002.
