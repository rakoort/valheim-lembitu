{
  description = "Valheim 1.0.7 plugin toolchain for valheim-lembitu";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      forEach = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});

      # The live server combination (#112). The dedicated server ships for linux/amd64 only.
      lock = builtins.fromJSON (builtins.readFile ./docs/server-inputs.lock.json);
      linux = nixpkgs.legacyPackages.x86_64-linux;
      inputs = linux.callPackage ./nix/server-inputs.nix { inherit lock; };
      plugins = linux.callPackage ./nix/plugins.nix {
        inherit (inputs) server bepinexPack mods;
        bepinexVersion = lock.bepinexPack.version;
      };
      # Our own DLLs reach the image through `plugins` alone: ra's choice of their bytes
      # (docs/live-vs-lock-20261027.md, decision 3) swaps this one input.
      serverImage = linux.callPackage ./nix/server-image.nix {
        inherit (inputs) server redist bepinexPack mods;
        inherit plugins;
        tag = toString lock.server.build;
      };
    in
    {
      packages.x86_64-linux = {
        inherit (inputs) server redist bepinexPack mods;
        inherit plugins serverImage;
      };

      # astral-fleet's fleet-publish --project builds each image the Workload pins from this output,
      # keyed by its path in the fleet registry (docs/as-built/cluster.md, "fleet-publish --project").
      projectImages."project/valheim-lembitu/server" = serverImage;

      checks.x86_64-linux = {
        # The fetched bytes against the lock's per-file list, through the offline verifier.
        server-inputs = linux.runCommand "verify-server-inputs"
          { nativeBuildInputs = [ linux.jq ]; }
          ''
            cd ${./.}
            bash scripts/verify-server-inputs.sh \
              --server ${inputs.server} --redist ${inputs.redist} \
              --bepinex ${inputs.bepinexPack} --mods ${inputs.mods}
            touch "$out"
          '';
        # The image's plugin tree, read by each assembly's [BepInPlugin] and [BepInProcess], against
        # the lock's serverPlugins: what the chainloader must load, and what it skips by design.
        server-plugin-guids = linux.runCommand "server-plugin-guids"
          { nativeBuildInputs = [ linux.jq linux.ilspycmd ]; }
          ''
            export HOME=$TMPDIR DOTNET_CLI_TELEMETRY_OPTOUT=1
            bash ${./scripts/list-plugin-guids.sh} ${serverImage.passthru.bepinex}/plugins > found
            jq -r '.serverPlugins | (.load[] | . + "\tload"), (.skip | to_entries[] | .key + "\t" + .value)' \
              ${./docs/server-inputs.lock.json} | LC_ALL=C sort > locked
            diff locked found
            touch "$out"
          '';
        inherit (self.packages.x86_64-linux) plugins;
      };

      devShells = forEach (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.dotnet-sdk_8
            pkgs.curl
            pkgs.jq
            pkgs.unzip
            pkgs.zip
          ];

          # NuGet needs a writable home, and NixOS has no global dotnet install to probe.
          shellHook = ''
            export DOTNET_CLI_TELEMETRY_OPTOUT=1
            export DOTNET_ROOT=${pkgs.dotnet-sdk_8}
          '';
        };
      });
    };
}
