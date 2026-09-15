# ADR-0002: ServerSync vendored once, as shared source

Date: 2026-09-09
Status: Superseded 2026-09-15
Issue: #2

## Context

Most of the mods we are porting synchronise their config from the server with
[ServerSync](https://github.com/blaxxun-boop/ServerSync) (MIT-0). Every pre-1.0 **binary** of
ServerSync is broken on Valheim 1.0.7: `ZRoutedRpc.Everybody` became a `const`, so an assembly
compiled before the change carries an `ldsfld` to a field that no longer exists and throws
`MissingFieldException` the first time a mod broadcasts a config value. The source is fine; the
build is stale.

Upstream distributes ServerSync as source to ILRepack into each mod, and its patching is written for
that: `VersionCheck.PatchServerSync` only de-duplicates Harmony patches *within its own assembly*,
and RPCs are named after each `ConfigSync` instance, so one copy per mod is the supported shape.
Third-party mods on the same server carry their own embedded copies either way.

The same class of failure — the game moves a member, nothing complains until runtime — applies to
every `[HarmonyPatch(typeof(ZNet), "Awake")]` and `AccessTools.DeclaredField(…, "m_adminList")` in
that file, and to every fork we are about to port.

## Decision

- **Vendor ServerSync once** at `src/forks/ServerSync/`, at upstream commit `c57c2aa`, with
  `LICENSE.txt` and `UPSTREAM.md` beside it.
- **Ship it as shared source, not a shared DLL.** `ServerSync.props` in that directory adds
  `ConfigSync.cs` and the three extra references it needs to whichever plugin imports it, so a
  consumer is one `<Import>`. There is one copy to fix and no assembly for BepInEx to resolve at
  load time.
- **Fix it by recompiling**, against `lib/valheim/` for 1.0.7. The `Everybody` expression then
  inlines to a constant, and `dist/plugins/Lembitu.Hello.dll` has no reference to that field at all.
- **Name game members with `nameof`, not strings.** We compile against publicized reference
  assemblies, so `nameof(ZNet.Awake)` and `nameof(ZNet.m_adminList)` resolve at build time. A game
  update that renames or removes them is then a build error, not a patch that quietly stops applying
  on a live server. This is our only substantive edit to upstream's code, and it is mechanical.
- **`Lembitu.Hello` is the first consumer and the proof.** On every server start, once the network
  is up, it writes a synced config entry and a `CustomSyncedValue`, so the broken path is exercised
  by the ordinary test-server loop rather than by a test we would have to remember to run. It takes
  both because only the second can fail loudly: BepInEx invokes config-entry change handlers inside
  a `try`/`catch` that logs and swallows (`ConfigFile.OnSettingChanged`), whereas a
  `CustomSyncedValue` broadcasts off a plain C# event, so the exception reaches the probe. The two
  broadcast through the same code, so a stale build cannot fail one and pass the other.

## Consequences

- Each fork's DLL contains its own copy of ServerSync's types and applies its own Harmony patches,
  as every other mod on the server already does. They cannot drift from each other: there is one
  source file.
- A future upstream release is re-forked by replacing one file and rebuilding; the `nameof`
  conversion is re-applied with the compiler pointing at each site.
- A future *game* update that moves `ZNet.Awake`, `ZRpc.m_socket` and friends fails `dotnet build`
  in one place, instead of failing on a live server. Three game and loader members are still named
  by string because no symbol exists: `"<Tags>k__BackingField"`, `ZRpc.RpcMethod<T>`'s
  `"m_action"`, and `ParameterInfo`'s `"ClassImpl"`. Reflection over a consumer's own synced types
  (`ConfigSync.cs:1079-1092`) stays string-based for the same reason.
- Forks that want ServerSync must not also bundle their own copy: the `<Import>` replaces whatever
  vendoring their upstream shipped with.

## Superseded — 2026-09-15

This decision had exactly two consumers: the EpicMMOSystem fork and `Lembitu.Hello`. Both are
retired (ADR-0010), and nothing we still ship synchronises config from the server — the remaining
fork, MaxPlayerCount, enforces its limit on the host's own admission path and needs no handshake.
`src/forks/ServerSync/` goes with them.

The technical finding behind this ADR stays true and still applies to any adopted package that
bundles a prebuilt library: a pre-1.0 binary carrying an `ldsfld` to `ZRoutedRpc.Everybody`, now a
`const`, throws at runtime rather than failing at build. Screening a bundled DLL against the game is
described in `docs/build.md`.
