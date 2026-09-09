# valheim-lembitu

Modded Valheim server: configuration, custom plugins, and 1.0-native forks.

Plugins target Valheim 1.0.7 (network version 39) and BepInEx 5.4.23.5.

```sh
nix develop                      # or bring your own .NET SDK 8+
scripts/test-server.sh install   # game files, BepInEx, plugins
scripts/extract-refs.sh          # reference assemblies
dotnet build                     # -> dist/plugins/
```

Development and all runtime testing happen on astral-bicep (x86_64 Linux); see
[docs/build.md](docs/build.md) for the install loop, the plugin-pruning trap, and why a Mac cannot
run the server.
