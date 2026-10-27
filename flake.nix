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
    in
    {
      packages.x86_64-linux = {
        inherit (inputs) server bepinexPack mods;
        plugins = linux.callPackage ./nix/plugins.nix {
          inherit (inputs) server bepinexPack mods;
          bepinexVersion = lock.bepinexPack.version;
        };
      };

      checks.x86_64-linux = {
        # The fetched bytes against the lock's per-file list, through the offline verifier.
        server-inputs = linux.runCommand "verify-server-inputs"
          { nativeBuildInputs = [ linux.jq ]; }
          ''
            cd ${./.}
            bash scripts/verify-server-inputs.sh \
              --server ${inputs.server} --bepinex ${inputs.bepinexPack} --mods ${inputs.mods}
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
