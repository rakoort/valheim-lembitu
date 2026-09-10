# valheim-lembitu

Modded Valheim server: configuration, custom plugins, and forks of the mods upstream has not fixed.

Plugins target Valheim 1.0.7 (network version 39) and BepInEx 5.4.23.5. The server runs a pinned
stack of mostly-adopted mods: [docs/modstack.md](docs/modstack.md) lists every pin and the config we
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
