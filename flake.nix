{
  description = "Valheim 1.0.7 plugin toolchain for valheim-lembitu";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" "aarch64-darwin" "x86_64-darwin" ];
      forEach = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      devShells = forEach (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.dotnet-sdk_8
            pkgs.curl
            pkgs.unzip
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
