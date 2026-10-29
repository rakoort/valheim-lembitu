# The repository's own plugins (src/**/*.csproj), built the way docs/build.md builds them, from the
# locked inputs alone: the game's reference assemblies come from the fetched server, BepInEx's from
# the locked pack (scripts/extract-refs.sh), and the adopted mods the plugins compile against from
# the locked zips (scripts/stage-stack.sh). NuGet packages are locked in nix/plugins-deps.json;
# regenerate it with `nix build .#plugins.fetch-deps && ./result nix/plugins-deps.json` after a
# PackageReference changes.
#
# The phases are the documented `dotnet build` at the root rather than buildDotnetModule's
# defaults, which add --runtime (an x64 platform target for these AnyCPU net472 assemblies) and
# publish each project. The output mirrors dist/: plugins/ and patchers/ hold our DLLs.
#
# The build matches the live server's DLLs (ra's decision 3 (b), docs/live-vs-lock-20261027.md): the
# lock's `plugins` names the SDK, the build path the PDB records and the commit stamp of the live
# build, and the compiler is held to that SDK version. The result is IL-identical to the live DLLs
# and differs from them only in the content-derived build IDs, which follow the compiler's exact
# version. ContinuousIntegrationBuild stays off: it would map the sources to /_/ and override the
# PathMap. The PathMap also maps the hook's NuGet folder, `$TMPDIR/nuget.<random>/`, which otherwise
# reaches the build IDs and makes two builds differ. It maps to NuGet's default on the Mac,
# `/Users/ra/.nuget/`. That only touches the build IDs, which differ from live anyway.
{
  lib,
  buildDotnetModule,
  dotnetCorePackages,
  unzip,
  server,
  bepinexPack,
  bepinexVersion,
  mods,
  stamp,
}:
let
  root = ./..;
  sdk = dotnetCorePackages."sdk_${lib.versions.major stamp.sdk}_0";
in
assert lib.assertMsg (sdk.version == stamp.sdk)
  "the lock's plugins.sdk is ${stamp.sdk}, but nixpkgs supplies ${sdk.version}; the build IDs follow the compiler, so re-prove and re-lock it";
buildDotnetModule {
  pname = "valheim-lembitu-plugins";
  version = "0";

  src = lib.fileset.toSource {
    inherit root;
    fileset = lib.fileset.unions [
      (root + "/Valheim.Lembitu.proj")
      (root + "/Directory.Build.props")
      (root + "/Directory.Build.targets")
      (root + "/src")
      (root + "/scripts/extract-refs.sh")
      (root + "/scripts/stage-stack.sh")
      (root + "/scripts/lib")
      (root + "/docs/modstack.md")
      (root + "/docs/modstack.lock.json")
    ];
  };

  nugetDeps = ./plugins-deps.json;
  dotnet-sdk = sdk;
  nativeBuildInputs = [ unzip ];

  configurePhase = ''
    runHook preConfigure
    dotnet restore Valheim.Lembitu.proj -p:Deterministic=true -p:NuGetAudit=false
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild

    patchShebangs scripts
    # lib/: the fetched server's managed assemblies and the locked BepInExPack, which
    # extract-refs.sh re-verifies against its own pinned sha256.
    mkdir -p lib/.cache
    cp ${bepinexPack} lib/.cache/BepInExPack_Valheim-${bepinexVersion}.zip
    VALHEIM_MANAGED=${server}/valheim_server_Data/Managed scripts/extract-refs.sh
    # dist/: every locked mod, hash-checked against docs/modstack.lock.json again while staging.
    scripts/stage-stack.sh --cache ${mods}

    nuget_root=''${NUGET_PACKAGES%/packages/}/
    dotnet build Valheim.Lembitu.proj --no-restore -p:Deterministic=true \
      -p:PathMap="$PWD/=${stamp.pathMap}%2C$nuget_root=/Users/ra/.nuget/" \
      -p:SourceRevisionId=${stamp.sourceRevisionId}

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    # Our build output is the top-level files of dist/plugins and dist/patchers; the staged mods
    # are directories beside them.
    mkdir -p $out/plugins $out/patchers
    find dist/plugins -maxdepth 1 -type f -name '*.dll' -exec cp {} $out/plugins/ \;
    find dist/patchers -maxdepth 1 -type f -name '*.dll' -exec cp {} $out/patchers/ \;
    runHook postInstall
  '';

  dontDotnetFixup = true;
}
