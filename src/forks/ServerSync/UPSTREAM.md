# ServerSync

Server-authoritative config synchronisation for BepInEx mods: the server pushes its config values to
clients on login, optionally locks them, and refuses clients whose mod versions do not match.

| | |
| --- | --- |
| Upstream | <https://github.com/blaxxun-boop/ServerSync> |
| Forked at | `c57c2aa54e07cdcc7630d6068699ea781622323e` (2025-04-06, "fix config file save via bepinex config manager") |
| Licence | MIT-0, `LICENSE.txt` in this directory (copied verbatim from upstream) |
| Built for | Valheim 1.0.7 (network version 39), BepInEx 5.4.23.5 |

## Why this fork exists

Every pre-1.0 **binary** of ServerSync throws `MissingFieldException` on 1.0.7 the moment a mod
broadcasts a config value. Valheim 1.0 turned `ZRoutedRpc.Everybody` into a `const`, and a `const`
is not a field at runtime: assemblies compiled before the change carry an `ldsfld` to a field that
no longer exists. Nothing in ServerSync's *source* is wrong — it needs recompiling against 1.0.7,
which turns the same expression into an inlined `ldc.i8`. That is what this directory is: upstream's
source, built by our toolchain against `lib/valheim/`.

Everything else upstream reaches for by name still exists in 1.0.7: `ZNet.Awake`,
`ZNet.OnNewConnection`, `ZNet.Shutdown`, `ZNet.RPC_PeerInfo`, `ZNet.GetPeer(ZRpc)`,
`ZNet.ListContainsId`, `ZNet.m_adminList`, `ZNet.m_connectionStatus`, `ZRpc.HandlePackage`,
`ZRpc.m_socket`, `ZRpc.m_functions`, `ZRoutedRpc.m_peers`, `ZNetPeer.m_socket`,
`ZPlayFabSocket.m_remotePlayerId` and `FejdStartup.ShowConnectError` (which gained a parameter, which
a postfix does not care about).

## Our changes

1. **Member names are `nameof`, not strings.** Every `[HarmonyPatch(typeof(X), "member")]` and
   `AccessTools.Declared*(typeof(X), "member")` now names the member as `nameof(X.member)`. We
   compile against publicized reference assemblies, so private game members are visible to the
   compiler and a member the game renames or deletes becomes a **build error** instead of a patch
   that silently does not apply, or an `AccessTools` call returning null and blowing up mid-session.
   This is the same failure mode as the `Everybody` breakage: the game moved, and nothing said so
   until runtime.

   Three *game and loader* members stay strings because no symbol exists to name them:
   `"<Tags>k__BackingField"` (a compiler backing field in BepInEx), `"m_action"` (a field of
   `ZRpc`'s private nested `RpcMethod<T>`), and `"ClassImpl"` on `System.Reflection.ParameterInfo`.
   The reflection at `ConfigSync.cs:1079-1092` (`"key"`, `"value"`, `"Add"`) walks whatever types a
   consumer synchronises, so there is nothing to name there either. RPC names on the wire
   (`"PeerInfo"`, `"RoutedRPC"`, `"ZDOData"`, `"Error"`, `"ServerSync VersionCheck"`) are protocol
   strings, not members, and are left alone.

2. **No project file, no `AssemblyInfo.cs`.** This is shared source, compiled into each consumer;
   see `ServerSync.props` next to this file. Upstream's `.csproj` hard-codes Steam install paths and
   is useless here.

Nothing else is touched, so `git diff` against upstream stays reviewable when we re-fork a later
release.

## Using it

In a plugin `.csproj`:

```xml
<Import Project="$(RepoRoot)src/forks/ServerSync/ServerSync.props" />
```

Then, in the plugin:

```csharp
private static readonly ConfigSync configSync = new(PluginInfo.Guid)
{
    DisplayName = PluginInfo.Name,
    CurrentVersion = PluginInfo.Version,
};

configSync.AddConfigEntry(Config.Bind("Section", "Key", value, "description"));
```

`src/plugins/Lembitu.Hello/HelloPlugin.cs` is a working example, and its startup probe is what proves
on every test-server run that broadcasting still works on the running game build.

## Re-forking

Pull upstream's `ConfigSync.cs`, re-apply change 1 (the `nameof` conversion — the compiler finds
every site for you: build, fix errors), and update the commit and date above. Only this directory
changes; every plugin in the repo picks the new build up on the next `dotnet build`.
