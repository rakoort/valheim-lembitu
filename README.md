# valheim-lembitu

Modded Valheim server: configuration, custom plugins, and forks of the mods upstream has not fixed.

Development targets the latest stable/public Valheim client and dedicated server with the latest
mod releases. Freeze the proven game and pack only after full-pack and two-client acceptance
(ADR-0007), not while developing. [docs/modstack.md](docs/modstack.md) records candidate versions and the config we
enforce, [CONTEXT.md](CONTEXT.md) defines the vocabulary, and [docs/adr/](docs/adr/) records the
decisions worth revisiting.

```sh
nix develop                      # or bring your own .NET SDK 8+
scripts/test-server.sh install   # game files, reference assemblies, BepInEx
dotnet build                     # -> dist/plugins/
scripts/install-plugins.sh ~/.cache/valheim-lembitu/server/BepInEx/plugins
scripts/test-server.sh run
```

Development and all runtime testing happen on astral-bicep (x86_64 Linux); see
[docs/build.md](docs/build.md) for the install loop, the plugin-pruning trap, and why a Mac cannot
run the server.
