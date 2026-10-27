# The locked live inputs (#112), read from docs/server-inputs.lock.json:
#   server       the dedicated server depot, fetched anonymously by DepotDownloader at the locked
#                manifest: a fixed-output derivation, so Nix refuses any other bytes;
#   redist       the same for the install's second depot, the Steamworks SDK redistributable;
#   bepinexPack  BepInExPack_Valheim at its locked sha256;
#   mods         every adopted mod's zip at its locked sha256, in one directory named the way
#                scripts/stage-stack.sh names its download cache (<team>-<mod>-<version>.zip).
# There is no SteamCMD and no updater: a depot that Steam stops serving anonymously fails this
# build rather than falling back to anything else.
{
  lib,
  stdenvNoCC,
  fetchurl,
  linkFarm,
  depotdownloader,
  cacert,
  lock,
}:
let
  inherit (lock) server redist bepinexPack;

  # One depot at one manifest, fetched anonymously by DepotDownloader: a fixed-output derivation,
  # so Nix refuses any bytes but the locked ones.
  fetchDepot =
    name: depot:
    stdenvNoCC.mkDerivation {
      inherit name;
      nativeBuildInputs = [ depotdownloader ];

      outputHashMode = "recursive";
      outputHashAlgo = "sha256";
      outputHash = depot.narHash;
      impureEnvVars = lib.fetchers.proxyImpureEnvVars;
      SSL_CERT_FILE = "${cacert}/etc/ssl/certs/ca-bundle.crt";

      buildCommand = ''
        export HOME="$TMPDIR/home"
        mkdir -p "$HOME"
        # No -username: an anonymous login, as the dedicated server's licence allows.
        DepotDownloader \
          -app ${toString depot.app} \
          -depot ${toString depot.depot} \
          -manifest ${depot.manifest} \
          -dir "$out"
        # DepotDownloader's own state (the manifest cache, its config, a staging dir) is not the game.
        rm -rf "$out/.DepotDownloader"
      '';
    };

  # "team/mod@version" -> "team-mod-version.zip", stage-stack.sh's cache name.
  modFileName =
    key:
    let
      parts = builtins.match "([^/]+)/([^@]+)@(.+)" key;
    in
    "${builtins.elemAt parts 0}-${builtins.elemAt parts 1}-${builtins.elemAt parts 2}.zip";

  fetchMod =
    key: pin:
    fetchurl {
      name = modFileName key;
      inherit (pin) url sha256;
    };
in
{
  server = fetchDepot "valheim-server-${toString server.build}" server;

  # The Steamworks SDK redistributable the live install carries beside the server (app 896660's
  # second depot): steamclient.so, which the server's libsteam_api.so loads at run time from
  # linux64/ on LD_LIBRARY_PATH, as the depot's own start_server.sh sets it.
  redist = fetchDepot "valheim-server-redist-${toString server.build}" redist;

  bepinexPack = fetchurl {
    name = "denikson-BepInExPack_Valheim-${bepinexPack.version}.zip";
    inherit (bepinexPack) url sha256;
  };

  mods = linkFarm "valheim-lembitu-mods" (
    lib.mapAttrsToList (key: pin: {
      name = modFileName key;
      path = fetchMod key pin;
    }) lock.mods
  );
}
