# The live server as a Nix-built OCI archive (#113), in the pattern of astral-fleet's
# cluster/omp-auth-broker/image.nix: dockerTools.buildLayeredImage, then skopeo into an OCI archive.
#
# What is in it, all from the locked inputs (docs/server-inputs.lock.json):
#   gameRoot   the server depot (896661), the Steamworks redistributable (1006) and BepInExPack's
#              loader, as one directory of store symlinks. valheim_server.x86_64 is the one real
#              file: a byte-identical copy of the depot's, mode 0555, because the depot sets no
#              exec bit (#127's r2 N2).
#   bepinex    BepInEx/plugins, patchers and config seeds exactly as the live deploy path makes them:
#              scripts/stage-stack.sh over the locked mod zips, our plugins added, then
#              scripts/install-plugins.sh, which withholds the client-only packages.
#   entrypoint scripts/server-entrypoint.sh, which assembles the writable runtime tree and execs the
#              server with its stdout through lembitu-logmark;
#   ready      scripts/server-ready.sh as lembitu-ready, the readiness probe's exec check;
#   tools      lembitu-logmark, and lembitu-a2s, an A2S_INFO client (answered only with -public 1).
# What is not: the enforced and dedicated config (a ConfigMap), the world, the Secrets.
#
# `plugins` is the one input that decides our own DLLs' bytes; swapping it swaps nothing else.
{
  lib,
  runCommand,
  runCommandCC,
  writeShellApplication,
  dockerTools,
  skopeo,
  unzip,
  coreutils,
  findutils,
  gnused,
  gnutar,
  glibc,
  stdenv,
  zlib,
  cacert,
  tzdata,
  dumb-init,
  server,
  redist,
  bepinexPack,
  mods,
  plugins,
  tag,
}:
let
  root = ./..;

  pack = runCommand "bepinexpack-valheim" { nativeBuildInputs = [ unzip ]; } ''
    unzip -q ${bepinexPack} 'BepInExPack_Valheim/*' -d unpacked
    # The zip's own modes are not ours to keep (the store refuses group- or world-writable files).
    chmod -R u=rwX,go=rX unpacked
    mv unpacked/BepInExPack_Valheim $out
  '';

  # The install the live server runs, as one tree of links into the store.
  gameRoot = runCommand "valheim-lembitu-game" { } ''
    mkdir -p $out/BepInEx
    for entry in ${server}/* ${redist}/*; do
      ln -s "$entry" "$out/$(basename "$entry")"
    done
    rm $out/valheim_server.x86_64
    install -m 0555 ${server}/valheim_server.x86_64 $out/valheim_server.x86_64
    for entry in ${pack}/* ${pack}/.doorstop_version; do
      [[ "$(basename "$entry")" == BepInEx ]] || ln -s "$entry" "$out/$(basename "$entry")"
    done
    ln -s ${pack}/BepInEx/core $out/BepInEx/core
  '';

  # BepInEx's plugins, patchers and config seeds, made by the repository's own deploy scripts.
  bepinex = runCommand "valheim-lembitu-bepinex"
    {
      nativeBuildInputs = [ unzip ];
      src = lib.fileset.toSource {
        inherit root;
        fileset = lib.fileset.unions [
          (root + "/scripts/stage-stack.sh")
          (root + "/scripts/install-plugins.sh")
          (root + "/scripts/lib")
          (root + "/docs/modstack.md")
          (root + "/docs/modstack.lock.json")
        ];
      };
    }
    ''
      cp -r $src source
      chmod -R u+w source
      cd source
      patchShebangs scripts
      scripts/stage-stack.sh --cache ${mods} --dist "$PWD/dist"
      cp ${plugins}/plugins/*.dll dist/plugins/
      mkdir -p dist/patchers
      cp ${plugins}/patchers/*.dll dist/patchers/
      chmod -R u+w dist
      mkdir -p $out
      scripts/install-plugins.sh --dist "$PWD/dist" $out
      # The pack's own BepInEx.cfg is a config seed like the packages' seeds.
      mkdir -p $out/config
      cp ${pack}/BepInEx/config/BepInEx.cfg $out/config/
    '';

  # The small native tools: lembitu-logmark (the stdout filter that marks "Opened Steam server")
  # and lembitu-a2s (an A2S_INFO client; the server answers it only with -public 1).
  tools = runCommandCC "lembitu-tools" { } ''
    mkdir -p $out/bin
    $CC -O2 -Wall -Werror -o $out/bin/lembitu-a2s ${./a2s-info.c}
    $CC -O2 -Wall -Werror -D_GNU_SOURCE -o $out/bin/lembitu-logmark ${./logmark.c}
  '';

  ready = writeShellApplication {
    name = "lembitu-ready";
    runtimeInputs = [ coreutils ];
    text = builtins.readFile ../scripts/server-ready.sh;
  };

  # The game is a foreign binary: its interpreter is /lib64/ld-linux-x86-64.so.2 and it finds
  # glibc, libgcc_s, libstdc++ and zlib on the library path, never patched (its bytes stay the
  # depot's).
  libraryPath = lib.makeLibraryPath [ glibc stdenv.cc.cc.lib zlib ];

  entrypoint = writeShellApplication {
    name = "lembitu-server";
    runtimeInputs = [ coreutils findutils gnused tools ];
    text = ''
      export LEMBITU_GAME=${gameRoot}
      export LEMBITU_BEPINEX=${bepinex}
      export LEMBITU_LIBRARY_PATH=${libraryPath}
      ${builtins.readFile ../scripts/server-entrypoint.sh}
    '';
  };

  image = dockerTools.buildLayeredImage {
    name = "valheim-lembitu-server";
    inherit tag;
    contents = [ entrypoint tools ready ];
    # zstd, multi-threaded: the 2 GB game layer takes minutes to gzip on one core.
    compressor = "zstd";
    # No /data: a volume mounted over an image directory would take its root ownership.
    extraCommands = ''
      mkdir -p lib64 etc/ssl/certs etc/pki/tls/certs tmp home/lembitu run/lembitu usr/share
      ln -s ${glibc}/lib/ld-linux-x86-64.so.2 lib64/ld-linux-x86-64.so.2
      ln -s ${tzdata}/share/zoneinfo usr/share/zoneinfo
      ln -s ${tzdata}/share/zoneinfo/Europe/Oslo etc/localtime
      # steamclient.so reads the system CA bundle at Debian's and Red Hat's paths, not
      # SSL_CERT_FILE; without one, its game-server logon never connects.
      ln -s ${cacert}/etc/ssl/certs/ca-bundle.crt etc/ssl/certs/ca-certificates.crt
      ln -s ${cacert}/etc/ssl/certs/ca-bundle.crt etc/ssl/certs/ca-bundle.crt
      ln -s ${cacert}/etc/ssl/certs/ca-bundle.crt etc/pki/tls/certs/ca-bundle.crt
      echo 'hosts: files dns' > etc/nsswitch.conf
      chmod 1777 tmp
      echo 'root:x:0:0:root:/root:/sbin/nologin' > etc/passwd
      echo 'lembitu:x:10160:10160:Lembitu server:/home/lembitu:/sbin/nologin' >> etc/passwd
      echo 'root:x:0:' > etc/group
      echo 'lembitu:x:10160:' >> etc/group
    '';
    config = {
      # dumb-init is PID 1 and turns the kubelet's SIGTERM into the SIGINT the server saves on.
      Entrypoint = [
        "${dumb-init}/bin/dumb-init"
        "--rewrite"
        "15:2"
        "--"
        "${entrypoint}/bin/lembitu-server"
      ];
      User = "10160:10160";
      WorkingDir = "/run/lembitu";
      Env = [
        "HOME=/home/lembitu"
        "TZ=Europe/Oslo"
        "TZDIR=${tzdata}/share/zoneinfo"
        "SSL_CERT_FILE=${cacert}/etc/ssl/certs/ca-bundle.crt"
        "PATH=${entrypoint}/bin:${ready}/bin:${tools}/bin:${coreutils}/bin"
      ];
      ExposedPorts = {
        "2456/udp" = { };
        "2457/udp" = { };
        "3000/tcp" = { };
      };
    };
  };
in
# skopeo's own oci-archive: tar carries the build's file times, so two builds differ around the same
# blobs. Copy into an OCI layout directory and tar it with fixed order, times and owners instead.
runCommand "valheim-lembitu-server-${tag}.oci.tar"
  {
    nativeBuildInputs = [ skopeo gnutar ];
    passthru = { inherit image gameRoot bepinex entrypoint tools ready; };
  }
  ''
    skopeo --tmpdir "$TMPDIR" --insecure-policy copy docker-archive:${image} oci:layout:valheim-lembitu-server:${tag}
    tar --sort=name --mtime=@1 --owner=0 --group=0 --numeric-owner --format=posix \
      --pax-option=exthdr.name=%d/PaxHeaders/%f,delete=atime,delete=ctime \
      -C layout -cf $out oci-layout index.json blobs
  ''
