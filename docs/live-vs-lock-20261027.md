# Live server versus the lock, 2026-10-27

This compares the lock (`docs/server-inputs.lock.json` and what the flake builds from it) with ra's
agent's read of the live server on astral-bicep, taken at about 10:05Z on 2026-10-27 (#112; slice
04 item A1 of astral-fleet's lembitu-cluster mission). The read covers:

- `appmanifest_896660.acf`, which lives at `~ra/lembitu/data/dl/server/steamapps/`;
- the sha256s of the 18 files in `BepInEx/core` (`BepInEx/patchers` holds none);
- the sha256s of the 333 files under `BepInEx/plugins`;
- the BepInEx version that the pack's manifest and the core log name.

The read's plugin list is intact: re-extracted, it hashes to the
`eb608dc2…b97f` the agent recorded for `plugins.sha256` on bicep.

The read has no per-file sha256s of the game install, so that comparison is still owed (row 2).

## Summary

| # | What | Lock | Live | Result |
| --- | --- | --- | --- | --- |
| 1 | App 896660 build | 25909431 | `buildid` 25909431, `TargetBuildID` 25909431 | identical |
| 2 | Depot 896661 | manifest 4001404753685205688, 2,075,353,104 bytes | manifest 4001404753685205688, `size` 2075353104 | identical; per-file sha256s not in the read |
| 3 | Depot 1006 | not locked before this change | manifest 4559160656493359681, `size` 111284048 | **now locked** (decision 1) |
| 4 | Install size | 2,075,353,104 + 111,284,048 bytes | `SizeOnDisk` 2186637152 | identical (the sum) |
| 5 | BepInEx core, 18 files | BepInExPack 5.4.2351, zip `bce63149…e29f` | 18 sha256s | identical, file for file |
| 6 | BepInEx version | pack 5.4.2351 | the log says "BepInEx 5.4.23.5" | same thing (decision 2) |
| 7 | Adopted mods under `plugins/` | 72 locked zips, staged and installed | 325 files in 64 package trees | 325 of 325 identical |
| 8 | Our plugins under `plugins/` | `.#plugins`, 6 server DLLs | 6 DLLs | 6 differ: 4 proven same source, 2 unproven (decision 3) |
| 9 | Files only on the live side | — | 2 files under `SeparateSpawns/reports/` | runtime output, not an input (decision 4) |
| 10 | Files only on the lock side | — | — | none in `plugins/` (see row 7's note) |

**How rows 7 to 10 were made.** The lock side is not the raw `.#plugins` output. It is what the
repository's own deploy path puts under `plugins/` from the locked inputs:

1. `scripts/stage-stack.sh --cache <.#mods>` staged all 72 locked zips. Every hash was verified.
2. `.#plugins`'s DLLs were added to `dist/`.
3. `scripts/install-plugins.sh` installed `dist/` into an empty `BepInEx` directory.

That produced 331 files, which were joined with the live list by path.

The installer withholds `CLIENT_ONLY`: eight adopted packages and our `Lembitu.Updater` and
`Lembitu.Updater.Patcher`. So 64 + 8 = 72 packages, and neither side has the withheld ones, as
expected. The installer also writes `config/` seeds. The read covers no `config/`, so those aren't
compared.

## 1. Depot 896661: the server

The acf names depot 896661 at manifest 4001404753685205688 with size 2075353104. The lock names the
same manifest. DepotDownloader reported exactly 2,075,353,104 uncompressed bytes for it in both
fetches, and in the Nix build.

The per-file comparison needs the live install's own hashes, which the read doesn't have. The acf
was read from `~ra/lembitu/data/dl/server`, the download, which is not necessarily the tree the
container runs (#129's review, r1 and r2). So the check names the running tree first, then hashes it.

1. **Which tree runs.** The container's mounts, and the server process's executable and working
   directory inside it:

   ```sh
   docker inspect lembitu --format '{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}'
   docker exec lembitu sh -c 'for p in /proc/[0-9]*; do
     case "$(readlink "$p/exe")" in *valheim_server.x86_64)
       echo "exe=$(readlink "$p/exe") cwd=$(readlink "$p/cwd")";; esac; done'
   ```

   Map the `cwd` back to the host through the mounts (`/opt/valheim` is `~/lembitu/data`).
2. **Its bytes.** From that directory on the host (the lists' paths are read relative to it). The
   lists are on `dev`; bicep's checkout tracks `main`, so take them from a `dev` checkout, here
   `<dev-checkout>`:

   ```sh
   sha256sum -c --quiet <dev-checkout>/docs/server-files.sha256 \
     <dev-checkout>/docs/redist-files.sha256
   ```

   This checks every listed file and is silent about the rest, which is right here: the running
   tree also holds BepInEx, the doorstop files and `steamapps/`, which neither depot list has.
   `scripts/verify-server-inputs.sh --server <dir> --redist <dir>` is for a tree holding the two
   depots alone. On the running tree or on `dl/server` it refuses those extras by design, so its
   refusals there are not a mismatch. Exit 0 and no output from `sha256sum -c` is the pass.
3. **The download too, optionally.** The same `sha256sum -c` in `~ra/lembitu/data/dl/server`,
   which is what `steamcmd` fetched.

**Pending:** ra's agent runs steps 1 and 2, and records the mounts, the cwd and the output.

## 2. Depot 1006: fetched and locked

**Decision: fetch it.** It is now `.#redist`, a second fixed-output derivation, added to the lock,
the verifier and the tests.

**What it holds** (`docs/redist-files.sha256`):

| File | Size | Kind |
| --- | --- | --- |
| `linux64/steamclient.so` | 46,728,928 B | ELF 64-bit x86-64 |
| `linux64/libsteamwebrtc.so` | 7,817,336 B | ELF 64-bit x86-64 |
| `steamclient.so` | 49,104,528 B | ELF 32-bit i386 |
| `libsteamwebrtc.so` | 7,633,256 B | ELF 32-bit i386 |

**Why the server needs it:**

- `valheim_server.x86_64` needs only `UnityPlayer.so` and libc's libraries (`readelf -d`, NEEDED).
  Nothing from 1006 is linked.
- `valheim_server_Data/Plugins/libsteam_api.so` links no `steamclient.so` either. It **loads it at
  run time**: its strings include `steamclient.so`, `dlopen failed trying to load:` and
  `%s/.steam/%s`. A bare-name `dlopen` searches `LD_LIBRARY_PATH`.
- The server depot's own `start_server.sh` sets `export LD_LIBRARY_PATH=./linux64:$LD_LIBRARY_PATH`
  before starting the server. `linux64/` comes only from depot 1006, and 896661 has no
  `linux64/`.
- The live container's launcher, `valheim-server` from community-valheim-tools, in BepInEx mode
  sets `LD_LIBRARY_PATH="$bepinex_install_path/linux64/:$bepinex_install_path/doorstop_libs/"`.
  That is the script on the image repository's `main`. [INFERENCE: the live image is the unpinned
  `:latest`, so its exact copy of that script was not read.]
- The server depot carries `docker/steamclient.so` for Iron Gate's sample Dockerfile, which copies
  it to `/usr/lib`. It is a **different build** from 1006's `linux64/steamclient.so`:
  - docker copy: 34,515,169 B, sha256 `12c77f9b…34f7`, BuildID `be261d28…`;
  - 1006 copy: 46,728,928 B, BuildID `04049c66…`.

  So using it instead would not run the live server's bytes.

**The fetch:**

- `DepotDownloader -app 896660 -depot 1006 -manifest 4559160656493359681` ran anonymously, twice,
  in clean directories. Both runs gave NAR hash `sha256-I3vbf2bQIAcymEwRVlg1pBiJzYubLPusbpPziofJazY=`,
  and `diff -r` found nothing between them.
- `nix build .#redist` and `nix build --rebuild .#redist` both gave
  `/nix/store/pgrnhvc4…-valheim-server-redist-25909431`. The NAR size is 111,285,096 bytes, and each
  fetch takes about 4 s. Since #129's review the derivation is named by its own depot and manifest,
  `steamworks-redist-1006-4559160656493359681`; its content, the NAR hash, is unchanged.
- A deliberately wrong `narHash` was refused with `hash mismatch … got: sha256-I3vbf2…JazY=`.
- `.#server` keeps its store path (`g5693h43…-valheim-server-25909431`): the FOD's name and hash
  are unchanged.

**What the image (A2) takes from this:** it needs `linux64/steamclient.so` on the server's
`LD_LIBRARY_PATH`, as `start_server.sh` and the live launcher arrange.

## 3. BepInEx: pack 5.4.2351 is BepInEx 5.4.23.5

These are two numbering schemes, not a difference. The pack's own files show it:

- `manifest.json` gives `"version_number": "5.4.2351"`. That is the Thunderstore package number of
  `denikson/BepInExPack_Valheim` (its `website_url` is AzumattDev's BepInEx fork).
- `CHANGELOG.md`, under `### 5.4.2350`, says: "Updated to BepInEx 5.4.23.5 from 5.4.23.3". Under
  `### 5.4.2351`, it lists logging and doorstop changes only.
- `BepInEx/core/BepInEx.dll` in the pack carries the version string `5.4.23.5`, which is the one
  `LogOutput.log` prints.
- All 18 live `core/` files are byte-identical to the pack's `BepInExPack_Valheim/BepInEx/core/`.

The live log's "BepInEx 5.4.23.5" is therefore the core assembly that pack 5.4.2351 ships.

## 4. Our plugins: same source, different build

| DLL | Live sha256 | `.#plugins` sha256 | Classification |
| --- | --- | --- | --- |
| `Lembitu.Callings.dll` | `893d27a9…0778` | `7883ea68…0936` | same source; other build path, commit stamp, compiler (proven) |
| `Lembitu.Guide.dll` | `87a66f2e…8283` | `a9f6b606…e97a` | same (proven) |
| `Lembitu.Guilds.dll` | `79858862…d38f` | `b67ded68…3497` | same (proven) |
| `Lembitu.Oathbound.dll` | `f6fc4015…3a7b` | `cb1ba44b…212f` | same (proven) |
| `Lembitu.Harness.dll` | `65a8d256…6133` | `be0789a7…0f1e` | differs, cause **unproven**: no live bytes to inspect |
| `ValheimWebMap.dll` | `7c5f98a4…e13d` | `428bd395…281d` | differs, cause **unproven**: no live bytes to inspect |

### Where the four live DLLs came from

The published release `client-pack-2026-10-19-v23` (zip sha256 `c65cafe6…c2be0`) ships
`Lembitu.Callings`, `Guide`, `Guilds` and `Oathbound`. Their sha256s equal the live ones exactly, so
the live server runs the Pack v23 build of them, and its bytes can be inspected.

Each embeds:

- its PDB path, `/Users/ra/code/valheim-lembitu/src/plugins/<Name>/obj/Debug/<Name>.pdb`;
- an informational version stamped with commit `+b3e608489924babc1dcee3de700f048fdd476778`.

That commit (2026-10-17, "Wiki: Pack v22 …") is on `dev`'s history, but `src/` differs from it by 9
files. The Mac's checkout was building uncommitted changes, which became 1bd1871 (#123, Pack v23).
No file under `src/` or the build files has changed from 1bd1871 to `dev`.

### What was proven, by rebuilding `dev`'s sources

- **Exact path and commit stamp:** the root build ran with
  `-p:PathMap=<checkout>/=/Users/ra/code/valheim-lembitu/` and
  `-p:SourceRevisionId=b3e608489924babc1dcee3de700f048fdd476778`.
- **With SDK 9.0.317 or 10.0.400** (nixpkgs `dotnet-sdk_9` and `dotnet-sdk_10`):
  - each of the four DLLs has the live size;
  - they differ from the live bytes in 69 to 72 bytes. Those bytes lie wholly in the
    content-derived build IDs: the COFF timestamp, the module MVID, the debug directory's
    timestamps, the CodeView GUID and the PdbChecksum hash;
  - a small PE parser zeroed exactly those fields in both files, and the rest was then
    byte-identical for all four DLLs, on both SDKs;
  - the IL (`ilspycmd -il`, ignoring RVA and MVID comments) is identical to live.

  SDK 9.0.317 and 10.0.400 also differ from each other in exactly those fields. The IDs follow the
  compiler version, and the DLL does not record which version ra's Mac used. So exact bytes are
  out of reach without that SDK.
- **With `.#plugins`** (SDK 8.0.424, as the dev shell and `nix/plugins.nix` use):
  - the IL differs from live **only inside iterator state machines'
    `System.IDisposable.Dispose()`**. That is Guide 4 diff hunks, Guilds 6, Callings 66 and
    Oathbound 22, with no hunk anywhere else;
  - the newer compiler's `Dispose` clears the hoisted locals and sets the state to −2. SDK 8's
    `Dispose` is a bare `ret`;
  - the method-header and size changes that follow from that are the only other differences.

### What stays unproven

`Lembitu.Harness.dll` and `ValheimWebMap.dll` aren't in any release: Harness is a test client
plugin, and the map is server-only. Only their live hashes are known. They differ from `.#plugins`,
and the same mechanism is likely, but that is **not shown**. Proving it needs the two files'
bytes from bicep, `~ra/lembitu/data/bepinex/BepInEx/plugins/{Lembitu.Harness,ValheimWebMap}.dll`.

## 5. The two live-only files

`SeparateSpawns/reports/918809704/layout_01.png` and `…/summary.txt` sit inside the SeparateSpawns
package tree. Neither is in the package zip. `SeparateSpawns.dll` contains the strings `reports`,
`layout_` and `summary.txt`, so the mod writes them itself at run time, under its own plugin
directory.

They are state, not inputs, and the lock is right not to have them. **What A2 takes from this:**
the image's plugins tree is read-only, so this write needs a writable path, which A2's writable
paths list must name. `scripts/backup-world.sh` doesn't capture the reports today.

## Decisions

1. **Depot 1006 is locked and fetched** (section 2). It is decided here, because the live server's
   Steam client library comes from it and the server depot's copy is a different build. The change:
   - the lock gains `redist`: depot 1006, manifest 4559160656493359681, NAR hash
     `sha256-I3vbf2bQIAcymEwRVlg1pBiJzYubLPusbpPziofJazY=`, and `docs/redist-files.sha256`;
   - the flake gains `.#redist`, and `nix flake check` verifies it;
   - `scripts/verify-server-inputs.sh` gains `--redist`, and a live install is checked by giving
     its directory as both `--server` and `--redist`. Each file is then checked against its own
     depot's list, and anything neither list has is refused. A path listed by both depots is
     refused as a lock error;
   - `test/server-input-lock.test.sh` has 11 new cases. Against `dev`'s verifier, 33 cases fail,
     and each of the 8 checks added was disabled in turn and made the test fail.
2. **BepInEx: no difference** (section 3). Nothing changes.
3. **Our plugins: a difference, recorded, not decided here.** The lock builds them from the same
   source, but `.#plugins` is not byte-identical to live, and with the compiler it uses it is not
   IL-identical either. #112 and #113 ask for the live bytes ("Reuse the modstack lock; do not
   rebuild own DLLs into different bytes"; byte identity of every own-plugin file). Which way to
   go is ra's call, through the lead:
   - **(a)** Lock the live DLLs by sha256 and ship those bytes:
     - the four player plugins come from the `client-pack-2026-10-19-v23` release asset, by its
       sha256;
     - `Lembitu.Harness.dll` and `ValheimWebMap.dll` need a hashed archive from bicep, as for the
       server's `requireFile` fallback.

     This gives byte identity, but these DLLs are not built from source in Nix.
   - **(b)** Build in Nix with an SDK 9 or 10 compiler, the PathMap and the commit stamp. That
     makes the four IL-identical to live and byte-identical apart from 72 build-ID bytes. Exact
     identity would need the Mac's SDK version, which nothing records.
   - **(c)** Keep SDK 8 and accept the `Dispose` differences as a recorded change from live.
4. **The SeparateSpawns reports are runtime state**, not a difference in inputs (section 5). They go
   to A2's writable paths.
5. **Still owed from bicep:**
   - the per-file check of the live install (section 1);
   - the bytes of `Lembitu.Harness.dll` and `ValheimWebMap.dll` (section 4);
   - [not part of the read] the doorstop files and `config/` seeds, which weren't read and so aren't
     compared.

## Appendix: all 333 live files under `BepInEx/plugins`

"Lock sha256" is the file the deploy path installs from the locked inputs (see "How rows 7 to 10
were made"). "—" means the lock side has no such file.

| File | Classification | Live sha256 | Lock sha256 |
| --- | --- | --- | --- |
| `AdditiveDamageModifier/AdditiveDamageModifier.English.yml` | identical | `52e1876e89417c5990ecd076efbfade354693bae4ba888de59785b4712003523` | `52e1876e89417c5990ecd076efbfade354693bae4ba888de59785b4712003523` |
| `AdditiveDamageModifier/AdditiveDamageModifier.dll` | identical | `a7e96a3cf060021303be97b7cc609701ef5f82dcf5b65cb00e6c9e288306f5dd` | `a7e96a3cf060021303be97b7cc609701ef5f82dcf5b65cb00e6c9e288306f5dd` |
| `AdventureBackpacks/AdventureBackpacks.dll` | identical | `880274426d9a2af116c277950b32d20f55ea6970031fe82f4f2d277f6ccb9048` | `880274426d9a2af116c277950b32d20f55ea6970031fe82f4f2d277f6ccb9048` |
| `AdventureBackpacks/AdventureBackpacks.xml` | identical | `a968ac3f1e3a2b61ac01378e77a7042d6f3bec891b90eb1509bcba45cec0eb55` | `a968ac3f1e3a2b61ac01378e77a7042d6f3bec891b90eb1509bcba45cec0eb55` |
| `AdventureBackpacks/LICENSE.md` | identical | `bbe8165a2cde56244ae35f10ae147746aa7a26022d00d4434d849f89ecaffba2` | `bbe8165a2cde56244ae35f10ae147746aa7a26022d00d4434d849f89ecaffba2` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Abenaki.json` | identical | `211b4679cc5e288844b638b729dc723971bf3790a720cf26ac10f56e69756bd8` | `211b4679cc5e288844b638b729dc723971bf3790a720cf26ac10f56e69756bd8` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Bulgarian.json` | identical | `5d7cc2f48dfb7d1bbfaf1f9cda994d9ebf8dbfbb257bd13a54cca0b0f69a8204` | `5d7cc2f48dfb7d1bbfaf1f9cda994d9ebf8dbfbb257bd13a54cca0b0f69a8204` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Chinese.json` | identical | `0d696ee2f09156ecd8ccf98f6e054190ac52a5d126579b0034422da255b485ad` | `0d696ee2f09156ecd8ccf98f6e054190ac52a5d126579b0034422da255b485ad` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Chinese_Trad.json` | identical | `66f79fcb77fb26d25dca0b0c921e62ae398f1c25092417360dcf8c4d1bfdbd9b` | `66f79fcb77fb26d25dca0b0c921e62ae398f1c25092417360dcf8c4d1bfdbd9b` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Croatian.json` | identical | `8cc0d62da9557408dcbd58944e133d95937b72507bd485839479f760945434d1` | `8cc0d62da9557408dcbd58944e133d95937b72507bd485839479f760945434d1` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Czech.json` | identical | `635e2f0af5fe42babec8009c5cba9e05ac7aa5a985241dd173a2f5abc52f7a11` | `635e2f0af5fe42babec8009c5cba9e05ac7aa5a985241dd173a2f5abc52f7a11` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Danish.json` | identical | `7c63823d42a3d96a1b255f4b19f2f4b4a0c5c41ed2cef37631378e89adfdd286` | `7c63823d42a3d96a1b255f4b19f2f4b4a0c5c41ed2cef37631378e89adfdd286` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Dutch.json` | identical | `faca52a2f827709d5f8b2a2a91e0e6f7dc63eb74cea0e6c5122ff5326593d5cc` | `faca52a2f827709d5f8b2a2a91e0e6f7dc63eb74cea0e6c5122ff5326593d5cc` |
| `AdventureBackpacks/Translations/AdventureBackpacks.English.json` | identical | `3497278950f68dcbb5cade9f2665c889aaf1e1a5bcd7d294f82dde04897abe46` | `3497278950f68dcbb5cade9f2665c889aaf1e1a5bcd7d294f82dde04897abe46` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Finnish.json` | identical | `c5817f7f436eaaab6b8e4510dc7ebd6d9ee0404196d8d791f63620de7113f428` | `c5817f7f436eaaab6b8e4510dc7ebd6d9ee0404196d8d791f63620de7113f428` |
| `AdventureBackpacks/Translations/AdventureBackpacks.French.json` | identical | `f06d696ae8cd1a8fb6ee93547490f83857062f30ea062620c40d8f0513b411b1` | `f06d696ae8cd1a8fb6ee93547490f83857062f30ea062620c40d8f0513b411b1` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Georgian.json` | identical | `af1e02a803d3c183f150a2727f1223b48718c8631f6aefca3560e96f89413ef0` | `af1e02a803d3c183f150a2727f1223b48718c8631f6aefca3560e96f89413ef0` |
| `AdventureBackpacks/Translations/AdventureBackpacks.German.json` | identical | `038cc5882dafce26268f5a3a4b4f39e49197b2a602268d9cf9a12f1f8a1139ad` | `038cc5882dafce26268f5a3a4b4f39e49197b2a602268d9cf9a12f1f8a1139ad` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Greek.json` | identical | `fc6ad464c9ca027a144f377a513e1d5873a43db2eb65c8788e897293b3cebb0b` | `fc6ad464c9ca027a144f377a513e1d5873a43db2eb65c8788e897293b3cebb0b` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Hindi.json` | identical | `11f43e155c422557b0181a7eab1f39fce13b315b4b0fd8a967066f8c4124ce89` | `11f43e155c422557b0181a7eab1f39fce13b315b4b0fd8a967066f8c4124ce89` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Hungarian.json` | identical | `ceff5c974ede24c9415c9cdae6ca46d55772af6df4d596e5dc6ca1b40dcc41bc` | `ceff5c974ede24c9415c9cdae6ca46d55772af6df4d596e5dc6ca1b40dcc41bc` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Icelandic.json` | identical | `c56ecd44a33e9b51b1407f37e86e281c6c5aa7fd3644eecfb13555ab3861ef5f` | `c56ecd44a33e9b51b1407f37e86e281c6c5aa7fd3644eecfb13555ab3861ef5f` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Italian.json` | identical | `cca9dd4c3afd9177dd88f93aa1c81da12fdc85474c37ea4a705be352334a726e` | `cca9dd4c3afd9177dd88f93aa1c81da12fdc85474c37ea4a705be352334a726e` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Japanese.json` | identical | `15603807e0505e2f4d4e3f40ad8ca7cda1fa15a88589371a80ae3852011cebc7` | `15603807e0505e2f4d4e3f40ad8ca7cda1fa15a88589371a80ae3852011cebc7` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Korean.json` | identical | `ea019ac9d665e0f808d9cba5489948b39224c04aec9c8b5f07cb12d3b6a6054d` | `ea019ac9d665e0f808d9cba5489948b39224c04aec9c8b5f07cb12d3b6a6054d` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Lithuanian.json` | identical | `f6c7fee6ea71199bceeb44be24d6b2717dba64ae8035dde0fa1284855cb1784f` | `f6c7fee6ea71199bceeb44be24d6b2717dba64ae8035dde0fa1284855cb1784f` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Macedonian.json` | identical | `d37bf6bc573eb7e0a45a09c304f3f0ba7a04b6c8cc5708c7807cdbd76e714514` | `d37bf6bc573eb7e0a45a09c304f3f0ba7a04b6c8cc5708c7807cdbd76e714514` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Norwegian.json` | identical | `151949a7c55f8fbdf21dea8f42d76304085863d6080394976928dac52235b957` | `151949a7c55f8fbdf21dea8f42d76304085863d6080394976928dac52235b957` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Polish.json` | identical | `dbb7a34d7acd5c4b5b98e9ab4e48147f42be50dbb7ab3ee807c8b2210bc3cdd6` | `dbb7a34d7acd5c4b5b98e9ab4e48147f42be50dbb7ab3ee807c8b2210bc3cdd6` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Portuguese_Brazilian.json` | identical | `d4040ac2450748695de0c9301bbca606938e17d27e0b21627225bc99d9615f73` | `d4040ac2450748695de0c9301bbca606938e17d27e0b21627225bc99d9615f73` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Portuguese_European.json` | identical | `4300727c912ea6d7a434727181609b15664b21ce324eecfd558d60af450d7101` | `4300727c912ea6d7a434727181609b15664b21ce324eecfd558d60af450d7101` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Romanian.json` | identical | `9c156300d13fa249a9000ca9299324231b9ba8d5fc650cf6d285ef9353a7826e` | `9c156300d13fa249a9000ca9299324231b9ba8d5fc650cf6d285ef9353a7826e` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Russian.json` | identical | `25a6649b887ae66bdcc4878236622b9b5b5cbb3f1ae8899871815d0f406ce20f` | `25a6649b887ae66bdcc4878236622b9b5b5cbb3f1ae8899871815d0f406ce20f` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Serbian.json` | identical | `61ccca3bda5cba5874797ad764d5e2b37078d903fbb424d9125f89fc9a8ecd81` | `61ccca3bda5cba5874797ad764d5e2b37078d903fbb424d9125f89fc9a8ecd81` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Slovak.json` | identical | `f09fc5835bfe7222f0f0de972f16fb94bf19fb873b135806ba1aa268b24b4f41` | `f09fc5835bfe7222f0f0de972f16fb94bf19fb873b135806ba1aa268b24b4f41` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Spanish.json` | identical | `9c87a5ee9d35b1a2d2ade653bdf92bedbf656c88c90b3c339c00b4b9dfea6c9a` | `9c87a5ee9d35b1a2d2ade653bdf92bedbf656c88c90b3c339c00b4b9dfea6c9a` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Swedish.json` | identical | `43abd8d5e7d6e90248b22d579fe9e504b914df25354b5edeb7869417315d4918` | `43abd8d5e7d6e90248b22d579fe9e504b914df25354b5edeb7869417315d4918` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Thai.json` | identical | `f187e7782c432ccdf7b3554cf26681758a6688da000dede8a9242b0181196593` | `f187e7782c432ccdf7b3554cf26681758a6688da000dede8a9242b0181196593` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Turkish.json` | identical | `f63b477f653476ecfd5d516c7b5d2758a17cd53796892b2a26cedccf7b1891d2` | `f63b477f653476ecfd5d516c7b5d2758a17cd53796892b2a26cedccf7b1891d2` |
| `AdventureBackpacks/Translations/AdventureBackpacks.Ukrainian.json` | identical | `4fd0bad54763cc23a2d73b908e5c7ec0396035b1522008c65f8dce564dc501f6` | `4fd0bad54763cc23a2d73b908e5c7ec0396035b1522008c65f8dce564dc501f6` |
| `AutoServerPassword/AutoServerPassword.dll` | identical | `5faebea7b8f4d8b2d9a7f87b5d29e52b25b2b54537f3a1d579e04d95891da038` | `5faebea7b8f4d8b2d9a7f87b5d29e52b25b2b54537f3a1d579e04d95891da038` |
| `AzuCraftyBoxes/AzuCraftyBoxes.dll` | identical | `381883fe4625d1dd119bb425a2f3c7522457fbc08ae1db60159f8256de940d6e` | `381883fe4625d1dd119bb425a2f3c7522457fbc08ae1db60159f8256de940d6e` |
| `AzuExtendedPlayerInventory/AzuExtendedPlayerInventory.dll` | identical | `0c8702f9f9a3f4ae2a0e9977801f40e1691e42d1b5ce60863c1b01ff5697c52e` | `0c8702f9f9a3f4ae2a0e9977801f40e1691e42d1b5ce60863c1b01ff5697c52e` |
| `BetterArchery/BetterArchery/plugins/BetterArchery.dll` | identical | `86d9594c2151e2afe56b609e34cb398d27ea2e6bcba6ff360c12568bf1285c54` | `86d9594c2151e2afe56b609e34cb398d27ea2e6bcba6ff360c12568bf1285c54` |
| `BetterArchery/BetterArchery/plugins/BetterArcheryRecipes.json` | identical | `f52015368c59c23062ce3ba2471f2dc9cf3891d122f504bb6c56857543167995` | `f52015368c59c23062ce3ba2471f2dc9cf3891d122f504bb6c56857543167995` |
| `BetterArchery/BetterArchery/plugins/SFX/exhale/exhale_1.wav` | identical | `c715fa858cda248b53ec86ccd895b45424f5680a1156bff0317d2c10b1d89be4` | `c715fa858cda248b53ec86ccd895b45424f5680a1156bff0317d2c10b1d89be4` |
| `BetterArchery/BetterArchery/plugins/SFX/exhale/exhale_2.wav` | identical | `756fcb3a72bfa8a663bf61db53a6296a8dcc64451cb4c550e7d802f38d62778c` | `756fcb3a72bfa8a663bf61db53a6296a8dcc64451cb4c550e7d802f38d62778c` |
| `BetterArchery/BetterArchery/plugins/SFX/exhale/exhale_3.wav` | identical | `0c04cdbd9271e77c9aa08674bdcc242cb0bc2298bcb28c9d250990e70e8b5082` | `0c04cdbd9271e77c9aa08674bdcc242cb0bc2298bcb28c9d250990e70e8b5082` |
| `BetterArchery/BetterArchery/plugins/SFX/inhale/inhale_1.wav` | identical | `f3ea81472e9c8082875c3d6795ec1651c4bb7d94c56703969eb9fa90dc28e598` | `f3ea81472e9c8082875c3d6795ec1651c4bb7d94c56703969eb9fa90dc28e598` |
| `BetterArchery/BetterArchery/plugins/SFX/inhale/inhale_2.wav` | identical | `09065dfdac9f17b8f0a836f7517f73688ec8897dedf80bd9385987ba0781cc03` | `09065dfdac9f17b8f0a836f7517f73688ec8897dedf80bd9385987ba0781cc03` |
| `BetterArchery/BetterArchery/plugins/SFX/inhale/inhale_3.wav` | identical | `d031a5ceb2d2fa396bb49c5c2da2801270e3d5b775bdf4d99477c6dc3a6f8b6d` | `d031a5ceb2d2fa396bb49c5c2da2801270e3d5b775bdf4d99477c6dc3a6f8b6d` |
| `BetterArchery/BetterArchery/plugins/betterarchery_translations.json` | identical | `bcd0c6e2ea95d4454ad33fe1237759d1023f817ff909566706a73fdac212197a` | `bcd0c6e2ea95d4454ad33fe1237759d1023f817ff909566706a73fdac212197a` |
| `BetterChat/BetterChat.dll` | identical | `9c37672fde8b866bc550e24e1e9669e4ca38fb3225a29a06d15e09042f891d6a` | `9c37672fde8b866bc550e24e1e9669e4ca38fb3225a29a06d15e09042f891d6a` |
| `BetterChat/ConfigSync_Readme.txt` | identical | `82c0171bf7a9d808e30ae9b53bcd6e760d0e215494e8a870c8034e3bcc044665` | `82c0171bf7a9d808e30ae9b53bcd6e760d0e215494e8a870c8034e3bcc044665` |
| `BetterMap/BetterMap.dll` | identical | `bb0a0a2e4e9ea2b388cd55f486a61057bf57f982d5647aa649375d4b1e7bae04` | `bb0a0a2e4e9ea2b388cd55f486a61057bf57f982d5647aa649375d4b1e7bae04` |
| `BlacksmithingExpanded/BlacksmithingExpanded.dll` | identical | `4afcea4296ad4406d415c311de2ffc0764ea0805be79a510a41e86b6ccf29e6d` | `4afcea4296ad4406d415c311de2ffc0764ea0805be79a510a41e86b6ccf29e6d` |
| `Blasted_Swimming_Tarred_Bug_Fix/BlastedSwimmingTarredBugFix.dll` | identical | `3edc04d037dfde80ae3e5297f3fb3d683622daa51f75bd5d44c7be2b474f4c62` | `3edc04d037dfde80ae3e5297f3fb3d683622daa51f75bd5d44c7be2b474f4c62` |
| `Blasted_Swimming_Tarred_Bug_Fix/LICENSE` | identical | `230184f60bae2feaf244f10a8bac053c8ff33a183bcc365b4d8b876d2b7f4809` | `230184f60bae2feaf244f10a8bac053c8ff33a183bcc365b4d8b876d2b7f4809` |
| `ConditionalConfigSync/ConditionalConfigSync.Plugin.dll` | identical | `9aa35c2ce769dfefb01bcdec77cf2c64227ce7c41b995a2b982516449c18290f` | `9aa35c2ce769dfefb01bcdec77cf2c64227ce7c41b995a2b982516449c18290f` |
| `ConditionalConfigSync/ConditionalConfigSync.dll` | identical | `9e3aa79de10b31a4ee06e7cd94faf46d87b3bf3ec64ea3d15b07a396836f8b8a` | `9e3aa79de10b31a4ee06e7cd94faf46d87b3bf3ec64ea3d15b07a396836f8b8a` |
| `ConditionalConfigSync/ConditionalConfigSync.xml` | identical | `ff51e0b3fac5bf3d094f04299677d704b2360004d47ddbe5f071f6ee3066e3f1` | `ff51e0b3fac5bf3d094f04299677d704b2360004d47ddbe5f071f6ee3066e3f1` |
| `CreatureManager/CreatureManager.English.yml` | identical | `77019810d2219687e6954a436ca8788ef6517cda788ef052b8a2493bdcfa8518` | `77019810d2219687e6954a436ca8788ef6517cda788ef052b8a2493bdcfa8518` |
| `CreatureManager/CreatureManager.dll` | identical | `96f1405702d05330aa2c27b77715fbe6ed71982ead79a0a3980af8e036d60de1` | `96f1405702d05330aa2c27b77715fbe6ed71982ead79a0a3980af8e036d60de1` |
| `DataForge/API.md` | identical | `9fd114ba433a33a2d642173b893cce35909e1a9cc87ec891d79b85d58656365e` | `9fd114ba433a33a2d642173b893cce35909e1a9cc87ec891d79b85d58656365e` |
| `DataForge/DataForge.dll` | identical | `1c1658751b63f57e9c309f332f78468edd3f3300267c782fa3f003101360290e` | `1c1658751b63f57e9c309f332f78468edd3f3300267c782fa3f003101360290e` |
| `Deluxe_Particles/Plugins/VentureValheim.DeluxeParticles.dll` | identical | `93058239c1c1f7d916930407a564359fd12f463524743f08253dd00851a14e0d` | `93058239c1c1f7d916930407a564359fd12f463524743f08253dd00851a14e0d` |
| `DetailedLevels/DetailedLevels.dll` | identical | `2f26c4a2d0b8a7ac36bd4a546b80144400ef30afab5b43e8207887bb0b958dde` | `2f26c4a2d0b8a7ac36bd4a546b80144400ef30afab5b43e8207887bb0b958dde` |
| `Dive_In/DiveIn.dll` | identical | `8ecf7ac50be64d324031c43d9f6e75b47c255c2af1ae6b73d39b5bf32834be2d` | `8ecf7ac50be64d324031c43d9f6e75b47c255c2af1ae6b73d39b5bf32834be2d` |
| `Dive_In/LICENSE.txt` | identical | `230184f60bae2feaf244f10a8bac053c8ff33a183bcc365b4d8b876d2b7f4809` | `230184f60bae2feaf244f10a8bac053c8ff33a183bcc365b4d8b876d2b7f4809` |
| `DodgeShortcut/DodgeShortcut.dll` | identical | `aabe601db0eb83a4bc7a2b9654a1c8a35730aee29a2c9be2b6da712b49a66a5a` | `aabe601db0eb83a4bc7a2b9654a1c8a35730aee29a2c9be2b6da712b49a66a5a` |
| `DynamicStoragePiles/DynamicStoragePiles.dll` | identical | `3de96602c036bdb37518a9ee4cd938f38352d4cf5c00f5f6cfcaa4e66e799671` | `3de96602c036bdb37518a9ee4cd938f38352d4cf5c00f5f6cfcaa4e66e799671` |
| `EpicLoot/EpicLoot.dll` | identical | `802790e0cbd8a6f951627619a488b84e6a406e8770e2687b2fff8b63d2adf9ea` | `802790e0cbd8a6f951627619a488b84e6a406e8770e2687b2fff8b63d2adf9ea` |
| `Expand_World_Size/ExpandWorldSize.dll` | identical | `7825c8587932f7ca817daaa6e5a765cd3018745aca62980b3a6ef7f6a203ad15` | `7825c8587932f7ca817daaa6e5a765cd3018745aca62980b3a6ef7f6a203ad15` |
| `Explorer/Explorer.dll` | identical | `c2f1095ffe62313c42944f749ad825984964e0c47130794a125b3304a250412c` | `c2f1095ffe62313c42944f749ad825984964e0c47130794a125b3304a250412c` |
| `Extra_Snap_Points_Made_Easy/ExtraSnapsMadeEasy.dll` | identical | `71add38352ddf9b9626b16263c969340ca4e46ffac7c58b5b260f9b30184c094` | `71add38352ddf9b9626b16263c969340ca4e46ffac7c58b5b260f9b30184c094` |
| `FineDining/FineDining.English.yml` | identical | `f7c123f3031b3efcd6cd5dfa8c4e0affc69c7b92d3ff4262f07ce9efd662bb69` | `f7c123f3031b3efcd6cd5dfa8c4e0affc69c7b92d3ff4262f07ce9efd662bb69` |
| `FineDining/FineDining.dll` | identical | `ddc51c13288e265a84e22149c17471be75bcc2551b7463abda6c20ece598172f` | `ddc51c13288e265a84e22149c17471be75bcc2551b7463abda6c20ece598172f` |
| `GlassPieces/GlassPieces.dll` | identical | `83da4469bc2c52c8276e188f3afa03356ebe446946b4f4c3d3d9af4e4930c6d5` | `83da4469bc2c52c8276e188f3afa03356ebe446946b4f4c3d3d9af4e4930c6d5` |
| `GlassPieces/LocalizationExample.zip` | identical | `4438109664f8f9aa42a713588721bea98f9a0e954d3b0523eb4656aaf0ea4c15` | `4438109664f8f9aa42a713588721bea98f9a0e954d3b0523eb4656aaf0ea4c15` |
| `Guilds/Guilds.dll` | identical | `1e6421079246f52aa31561adb5c6e01c971cc417cc4ca0f9d5a33c1896e4ce44` | `1e6421079246f52aa31561adb5c6e01c971cc417cc4ca0f9d5a33c1896e4ce44` |
| `Herbalist/Herbalist.dll` | identical | `e69df21f48e50324be0c3b0b5bf855e94da336e873f5e6660dee4329a2c12ad6` | `e69df21f48e50324be0c3b0b5bf855e94da336e873f5e6660dee4329a2c12ad6` |
| `Herbalist/LocalizationExample.zip` | identical | `c775db45214c0639495b58c2f3dce7cff9b6821be4bfe3b55692d7b98589740b` | `c775db45214c0639495b58c2f3dce7cff9b6821be4bfe3b55692d7b98589740b` |
| `ImpactfulSkills/ImpactfulSkills.dll` | identical | `5b9cd6a20531e33bce52e4efd37631a82b0f0aa40d66860d8e1cddc597736f66` | `5b9cd6a20531e33bce52e4efd37631a82b0f0aa40d66860d8e1cddc597736f66` |
| `Jotunn/Jotunn.dll` | identical | `9509221046842a70f94b98bab4cb41005dee026823a7a79345829ed46a30f796` | `9509221046842a70f94b98bab4cb41005dee026823a7a79345829ed46a30f796` |
| `Jotunn/Jotunn.dll.mdb` | identical | `0e4caf66e7b3ae3344779f4d3f2c85a1a4204e734a94a0cd47888bf76a732e5d` | `0e4caf66e7b3ae3344779f4d3f2c85a1a4204e734a94a0cd47888bf76a732e5d` |
| `Jotunn/Jotunn.pdb` | identical | `1f3e60d5b60ad2b187233d50d2aaaaace5af3a8a14da6ee8ed7c4e41a3027d82` | `1f3e60d5b60ad2b187233d50d2aaaaace5af3a8a14da6ee8ed7c4e41a3027d82` |
| `Jotunn/Jotunn.xml` | identical | `f1514f61744160645cf503b7286ca1f9198fbbeb4caa38dfeb8f4adab39021dc` | `f1514f61744160645cf503b7286ca1f9198fbbeb4caa38dfeb8f4adab39021dc` |
| `JsonDotNET/LICENSE.md` | identical | `d7f83bbea3264a8e23d7739e44d9db1a4994b357274df6f00876eb2e623827ad` | `d7f83bbea3264a8e23d7739e44d9db1a4994b357274df6f00876eb2e623827ad` |
| `JsonDotNET/Newtonsoft.Json.dll` | identical | `d134937ec381729074694490e81983b08ec7991b31550eabafb9202e5b404f89` | `d134937ec381729074694490e81983b08ec7991b31550eabafb9202e5b404f89` |
| `JsonDotNET/NewtonsoftJsonDetector.dll` | identical | `513f2b88dfea6b96336a63d4120cdfc05011391ab45d981989e88844722d84b7` | `513f2b88dfea6b96336a63d4120cdfc05011391ab45d981989e88844722d84b7` |
| `Lembitu.Callings.dll` | differs: same source, other build path, commit stamp and compiler (proven, section 4) | `893d27a9cda7a03729cd9e0593d14c72d43bad9c33bd224214f044f490680778` | `7883ea68d1577f5dca8ecb861a71fddc8ef3432c2a25caaedfcd091b72f20936` |
| `Lembitu.Guide.dll` | differs: same source, other build path, commit stamp and compiler (proven, section 4) | `87a66f2e317c64bd67ce72e992509595d8424930ed667b8f7fdd23d557088283` | `a9f6b6069610788e380069158fba275aa575c6fb9b0b35e40535dafd328be97a` |
| `Lembitu.Guilds.dll` | differs: same source, other build path, commit stamp and compiler (proven, section 4) | `798588625912cca1597bf5dc5081202faa5f0b4a1a376d94041ba61b5156d38f` | `b67ded6893f86105a6df80b1409c2441f60398f54b9952910e00f50f197c3497` |
| `Lembitu.Harness.dll` | differs: cause unproven (section 4) | `65a8d25619daa4214e32adc334351b338982fc45c31ea217f9851de6e4e16133` | `be0789a7b45a7ca26a90f3d51626fcc616901bca542d1c14c1e4f7d5ffab0f1e` |
| `Lembitu.Oathbound.dll` | differs: same source, other build path, commit stamp and compiler (proven, section 4) | `f6fc4015619368b0269d1d2f6ad5ac1aa018a83b0b795503660103c5c75e3a7b` | `cb1ba44b1191501d333c192fda38f248a7d01a4e06ae3dca6423c19fe77d212f` |
| `Marketplace/Marketplace.dll` | identical | `af0ab0a17e3c22f1ccf9def1330f8a0b7ddc4118d4ab64f00e94c7041e426a96` | `af0ab0a17e3c22f1ccf9def1330f8a0b7ddc4118d4ab64f00e94c7041e426a96` |
| `MultiUserChest/MultiUserChest.dll` | identical | `afe0d6b437495fb6624a049ba72c2393572c8c02e1221ac090f16c0d99914514` | `afe0d6b437495fb6624a049ba72c2393572c8c02e1221ac090f16c0d99914514` |
| `MultiUserChest/MultiUserChest.dll.mdb` | identical | `2da69a97c2e4f8a303860f39f379851ca467584e3eb5e14374d4db6103272939` | `2da69a97c2e4f8a303860f39f379851ca467584e3eb5e14374d4db6103272939` |
| `OOD_LIB/Microsoft.Bcl.AsyncInterfaces.dll` | identical | `38309da92aecdab1a8631c2984075a67a7c1675575f851fb6488c02652563937` | `38309da92aecdab1a8631c2984075a67a7c1675575f851fb6488c02652563937` |
| `OOD_LIB/SoundCloudExplode.dll` | identical | `82d2c8efe88e4dc4b30ba532b8af4765cbab7008bfaf05c569336ed87570d498` | `82d2c8efe88e4dc4b30ba532b8af4765cbab7008bfaf05c569336ed87570d498` |
| `OOD_LIB/System.Buffers.dll` | identical | `2d78d770c9cb997199154ae8c018b9f1d1efbc86729f7264dde6dbad2a12cac3` | `2d78d770c9cb997199154ae8c018b9f1d1efbc86729f7264dde6dbad2a12cac3` |
| `OOD_LIB/System.Threading.Tasks.Extensions.dll` | identical | `af4e13ef418fd89b432de20cd1dfb7fa10a7179c8dd049c9856316e50c5949ca` | `af4e13ef418fd89b432de20cd1dfb7fa10a7179c8dd049c9856316e50c5949ca` |
| `OOD_LIB/System.ValueTuple.dll` | identical | `bba392236cbd15717a456327d4372f6d27c6299c42aad52625f5d5502a4963c2` | `bba392236cbd15717a456327d4372f6d27c6299c42aad52625f5d5502a4963c2` |
| `OOD_LIB/YoutubeDLSharp.LICENSE.txt` | identical | `c7155930355ea69fab48daff63718bd2a192ae3fbfcc96f573eb526d9da65277` | `c7155930355ea69fab48daff63718bd2a192ae3fbfcc96f573eb526d9da65277` |
| `OOD_LIB/YoutubeDLSharp.dll` | identical | `864f897ce479d5536dba87b9f76673ecf88ffeb63fad8f06fac87d8add3e5860` | `864f897ce479d5536dba87b9f76673ecf88ffeb63fad8f06fac87d8add3e5860` |
| `OOD_LIB/YoutubeExplode.LICENSE.txt` | identical | `909b446101981298b853591e88d63070009c2e18eba3d9af28cd409a0531f8ed` | `909b446101981298b853591e88d63070009c2e18eba3d9af28cd409a0531f8ed` |
| `OOD_LIB/YoutubeExplode.dll` | identical | `48fbd491a03ebf9f69b2eabebafe763e536d30e9f92c4c7c0fbb7c0d58f073a3` | `48fbd491a03ebf9f69b2eabebafe763e536d30e9f92c4c7c0fbb7c0d58f073a3` |
| `Oathbound/CONFIGURATION-DEFAULTS.cfg.example` | identical | `b856f378619282102132d96dcb0cb6a0cec1ab3d55b5f48b5b1b8367354a2935` | `b856f378619282102132d96dcb0cb6a0cec1ab3d55b5f48b5b1b8367354a2935` |
| `Oathbound/CONFIGURATION-REFERENCE.md` | identical | `ed4e74a8810a90ddb785ae97019b2c41e8b572352102c2f3b73adb7e5086abd2` | `ed4e74a8810a90ddb785ae97019b2c41e8b572352102c2f3b73adb7e5086abd2` |
| `Oathbound/CONFIGURATION.md` | identical | `95a3be6e2285aa9779d27054f0eca3680dc3675e90c144c918272cbcd43e32be` | `95a3be6e2285aa9779d27054f0eca3680dc3675e90c144c918272cbcd43e32be` |
| `Oathbound/PLAYER-GUIDE.md` | identical | `a4de2c11e2ede9638bb4152f50584975f2bbf261c543c3bf8ab1e6da9d22ed4a` | `a4de2c11e2ede9638bb4152f50584975f2bbf261c543c3bf8ab1e6da9d22ed4a` |
| `Oathbound/WarriorRpg/Warrior.Core.dll` | identical | `4692a2dba8c66e560ab19fd2fd09302ff16cb0f23f4f2224b0b24c6012759a9b` | `4692a2dba8c66e560ab19fd2fd09302ff16cb0f23f4f2224b0b24c6012759a9b` |
| `Oathbound/WarriorRpg/WarriorRpg.dll` | identical | `1b3d30897eda3d349baaa2db4de7b65c3c65c738ff249e42a4924fc69c64b31e` | `1b3d30897eda3d349baaa2db4de7b65c3c65c738ff249e42a4924fc69c64b31e` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Chinese/big.json` | identical | `c3c5267d94950ad682fdb83b7a111d78c4623370aee3d3e1aa30a9fe05bbe22d` | `c3c5267d94950ad682fdb83b7a111d78c4623370aee3d3e1aa30a9fe05bbe22d` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Chinese/decors.json` | identical | `ac213ecd95f2a57ee5be829ce2f909409f52ee46a7af975e91f8606461af5085` | `ac213ecd95f2a57ee5be829ce2f909409f52ee46a7af975e91f8606461af5085` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Chinese/doors.json` | identical | `13624daa1136f4d3c89b6a59160682f342b4825e6ed7d5dd54f9376d00ac1184` | `13624daa1136f4d3c89b6a59160682f342b4825e6ed7d5dd54f9376d00ac1184` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Chinese/dvergr.json` | identical | `c3435df74779d940d28d01a1726ddccc9083bbaf5d27f8cb76948e4a1a32f46b` | `c3435df74779d940d28d01a1726ddccc9083bbaf5d27f8cb76948e4a1a32f46b` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Chinese/misc.json` | identical | `503d5e3b056d71872293ae83cceee834f3d6a5b6cd5d5665866a1eb5c7c0fab4` | `503d5e3b056d71872293ae83cceee834f3d6a5b6cd5d5665866a1eb5c7c0fab4` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Chinese/pieces.json` | identical | `8e2d47aabb59d2ddca179d019e346bc2e9f5b22521416d616359cd2a681ce021` | `8e2d47aabb59d2ddca179d019e346bc2e9f5b22521416d616359cd2a681ce021` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Chinese/translations.json` | identical | `4223ec279a7abd15fbbcf1efa22d5c1128ef749d530dce438dded5f2b00e1026` | `4223ec279a7abd15fbbcf1efa22d5c1128ef749d530dce438dded5f2b00e1026` |
| `OdinArchitect/OdinArchitect/Assets/Translations/English/big.json` | identical | `e60999636be8c366db8441c63c933291e1e5216f1be44b56c52a073ad27867c6` | `e60999636be8c366db8441c63c933291e1e5216f1be44b56c52a073ad27867c6` |
| `OdinArchitect/OdinArchitect/Assets/Translations/English/decors.json` | identical | `6ad0c0a9ba05b8556adec2c2e5297a4dc3ffda9cd280e4cca9d434c29bbaa86a` | `6ad0c0a9ba05b8556adec2c2e5297a4dc3ffda9cd280e4cca9d434c29bbaa86a` |
| `OdinArchitect/OdinArchitect/Assets/Translations/English/doors.json` | identical | `0ef1f5ae09b45dd899d92f241df6e98240d0efa5ba33d51940d4bbb19a474fbb` | `0ef1f5ae09b45dd899d92f241df6e98240d0efa5ba33d51940d4bbb19a474fbb` |
| `OdinArchitect/OdinArchitect/Assets/Translations/English/dvergr.json` | identical | `eb7c8149b625acc27c4b01be23500f488248bf95330fdccd230ae7540a7577f6` | `eb7c8149b625acc27c4b01be23500f488248bf95330fdccd230ae7540a7577f6` |
| `OdinArchitect/OdinArchitect/Assets/Translations/English/misc.json` | identical | `83d8f666248aade5b8e3289dd1ca47cb0b95fece8c1302df7e8cf045a6987f07` | `83d8f666248aade5b8e3289dd1ca47cb0b95fece8c1302df7e8cf045a6987f07` |
| `OdinArchitect/OdinArchitect/Assets/Translations/English/pieces.json` | identical | `91046275c91023b98afeb4dc71ab3306a65e72de80791f463e08d5cd77a4afcc` | `91046275c91023b98afeb4dc71ab3306a65e72de80791f463e08d5cd77a4afcc` |
| `OdinArchitect/OdinArchitect/Assets/Translations/English/translations.json` | identical | `752a3e4f096a480db2636097f8ebe9b33b03f3514dca6ce589b3ad1b671b3765` | `752a3e4f096a480db2636097f8ebe9b33b03f3514dca6ce589b3ad1b671b3765` |
| `OdinArchitect/OdinArchitect/Assets/Translations/French/big.json` | identical | `b010173897a24b014bbf97db9edce72b7c798d5b8f807b496799e925379ae285` | `b010173897a24b014bbf97db9edce72b7c798d5b8f807b496799e925379ae285` |
| `OdinArchitect/OdinArchitect/Assets/Translations/French/decors.json` | identical | `9bd4754c364d51d3252766a50846064b164bbc37c3f0cb70ceff9bb0ee0b227d` | `9bd4754c364d51d3252766a50846064b164bbc37c3f0cb70ceff9bb0ee0b227d` |
| `OdinArchitect/OdinArchitect/Assets/Translations/French/doors.json` | identical | `aedca38f1bd4c0ed29844b2f12a6d7f88f288ddad1f69f7a04caf28639ee8b53` | `aedca38f1bd4c0ed29844b2f12a6d7f88f288ddad1f69f7a04caf28639ee8b53` |
| `OdinArchitect/OdinArchitect/Assets/Translations/French/dvergr.json` | identical | `7361a50196bf0b8a62300ca1951a6f52972d5079c0c222bf779817f04496877c` | `7361a50196bf0b8a62300ca1951a6f52972d5079c0c222bf779817f04496877c` |
| `OdinArchitect/OdinArchitect/Assets/Translations/French/misc.json` | identical | `0a2124137148e1dc721a6f70e9cd707acae27147a9491bc16cad51acf6f8fc0b` | `0a2124137148e1dc721a6f70e9cd707acae27147a9491bc16cad51acf6f8fc0b` |
| `OdinArchitect/OdinArchitect/Assets/Translations/French/pieces.json` | identical | `c1024080940e74ba3bd0c34c0cd2e033007f8a6abb70cbd8840163e40cc0eb24` | `c1024080940e74ba3bd0c34c0cd2e033007f8a6abb70cbd8840163e40cc0eb24` |
| `OdinArchitect/OdinArchitect/Assets/Translations/German/big.json` | identical | `0051fbf0c4b709668814edb14d995bfc2774e07fcaff9f979165df87ddb3bfd5` | `0051fbf0c4b709668814edb14d995bfc2774e07fcaff9f979165df87ddb3bfd5` |
| `OdinArchitect/OdinArchitect/Assets/Translations/German/decors.json` | identical | `aaadf44357d1577a3876867341d77225a6bc77eebb1c8b75728f57014460c096` | `aaadf44357d1577a3876867341d77225a6bc77eebb1c8b75728f57014460c096` |
| `OdinArchitect/OdinArchitect/Assets/Translations/German/doors.json` | identical | `1e59a927a76bf210e751d9f02738a83d492860bc979ce89731703799d3e503cb` | `1e59a927a76bf210e751d9f02738a83d492860bc979ce89731703799d3e503cb` |
| `OdinArchitect/OdinArchitect/Assets/Translations/German/dvergr.json` | identical | `374fb894ae3c5c8e12418c90e86bba633ac5456ba0b68d6a8f2a85306b8b08f2` | `374fb894ae3c5c8e12418c90e86bba633ac5456ba0b68d6a8f2a85306b8b08f2` |
| `OdinArchitect/OdinArchitect/Assets/Translations/German/misc.json` | identical | `f6a3808b50bd6eeaa319f19902bbbea003743eefba044101bae9576593bc9f03` | `f6a3808b50bd6eeaa319f19902bbbea003743eefba044101bae9576593bc9f03` |
| `OdinArchitect/OdinArchitect/Assets/Translations/German/pieces.json` | identical | `eb303a6ac8ca2ca178f00adccbcf024e048982cf4de779a03f4d965d22260487` | `eb303a6ac8ca2ca178f00adccbcf024e048982cf4de779a03f4d965d22260487` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Italian/big.json` | identical | `ececde5d47fc413ac5eace96349bdeef95b566933addbaef355f378ae34ca7a4` | `ececde5d47fc413ac5eace96349bdeef95b566933addbaef355f378ae34ca7a4` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Italian/decors.json` | identical | `596a9cbcd2144a83bd52378c989912528769c2ccc5d0f6a307c0fb82c85eee56` | `596a9cbcd2144a83bd52378c989912528769c2ccc5d0f6a307c0fb82c85eee56` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Italian/doors.json` | identical | `c99520d53cf31a22f7d7b03c820136dacaa0ee7a44f7728921069c34f87d1633` | `c99520d53cf31a22f7d7b03c820136dacaa0ee7a44f7728921069c34f87d1633` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Italian/dvergr.json` | identical | `ccde825bb6fddd24281488c00f19371fb5c850456ddd95198798c074af261675` | `ccde825bb6fddd24281488c00f19371fb5c850456ddd95198798c074af261675` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Italian/misc.json` | identical | `4062c258f5f72890817a380708b8c16c177e78c33464b5c8cfce2f11b4e74ff2` | `4062c258f5f72890817a380708b8c16c177e78c33464b5c8cfce2f11b4e74ff2` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Italian/pieces.json` | identical | `0528a26cdb97dacb6e7a1978478e7c8caa033c9451bb0acf0288fbb8695e4f72` | `0528a26cdb97dacb6e7a1978478e7c8caa033c9451bb0acf0288fbb8695e4f72` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Japanese/big.json` | identical | `b4b263889ad01e7e9b018edfefc0e2548ebc8ffd4be5efc5a2ecbac239fa3f22` | `b4b263889ad01e7e9b018edfefc0e2548ebc8ffd4be5efc5a2ecbac239fa3f22` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Japanese/decors.json` | identical | `8b645bcc1335468b59b5f32ab32470f42b01cd4fe27572ea525a10b0bf593814` | `8b645bcc1335468b59b5f32ab32470f42b01cd4fe27572ea525a10b0bf593814` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Japanese/doors.json` | identical | `25014039b0c9ccf7cc35e6a04e8465f7a67caa5fb95a3ab92754d314c08ca23f` | `25014039b0c9ccf7cc35e6a04e8465f7a67caa5fb95a3ab92754d314c08ca23f` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Japanese/dvergr.json` | identical | `202a4e77e87630b783b7169fdc34c7b5bb8de0c47afa4c92d05ce3c9b5ac7f15` | `202a4e77e87630b783b7169fdc34c7b5bb8de0c47afa4c92d05ce3c9b5ac7f15` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Japanese/misc.json` | identical | `c5470b39f4b8ad0183d47f228abca7fed1b45c3264e1e7984bc0ef13d0e04a43` | `c5470b39f4b8ad0183d47f228abca7fed1b45c3264e1e7984bc0ef13d0e04a43` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Japanese/pieces.json` | identical | `1cc04b7fa6757246833d8902af3810c9878f2b7d2ababd93018b4d2a96dd9460` | `1cc04b7fa6757246833d8902af3810c9878f2b7d2ababd93018b4d2a96dd9460` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Korean/big.json` | identical | `d2bc12b83c6ab33b546e00d2d959d451ed283955115e4c3bdc349b340bc2b201` | `d2bc12b83c6ab33b546e00d2d959d451ed283955115e4c3bdc349b340bc2b201` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Korean/decors.json` | identical | `2dbd8c1767a92c6a9cf68967d149c3e470b9bc5fbdafd1e1d183920a1fcde476` | `2dbd8c1767a92c6a9cf68967d149c3e470b9bc5fbdafd1e1d183920a1fcde476` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Korean/doors.json` | identical | `f4fa0628b44830a9bc8a36193e6fab00d6c19b0cc43ae005d98dd20811b34401` | `f4fa0628b44830a9bc8a36193e6fab00d6c19b0cc43ae005d98dd20811b34401` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Korean/dvergr.json` | identical | `49dbc530053e8227a62570c7c266a2ec3f3872c36882252c7357959343c1f8a1` | `49dbc530053e8227a62570c7c266a2ec3f3872c36882252c7357959343c1f8a1` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Korean/misc.json` | identical | `5716238dc9a0a28b5523baf8e3eadd15d127d5fb661b8bbe199bf4da22340bb6` | `5716238dc9a0a28b5523baf8e3eadd15d127d5fb661b8bbe199bf4da22340bb6` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Korean/pieces.json` | identical | `d4c52ae344ab06281f24e412bcc6786dbba06cc909df5c4af14f3c6fc66ef082` | `d4c52ae344ab06281f24e412bcc6786dbba06cc909df5c4af14f3c6fc66ef082` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Polish/big.json` | identical | `81c729250fd1cfc2fd468258925400f420cf1f5615fd3ccbfa84397d6b3aa347` | `81c729250fd1cfc2fd468258925400f420cf1f5615fd3ccbfa84397d6b3aa347` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Polish/decors.json` | identical | `55c15e3a0e8b44d103d2cc3ee5686eb524ab2da11674a8b38879aa849a2fdc9d` | `55c15e3a0e8b44d103d2cc3ee5686eb524ab2da11674a8b38879aa849a2fdc9d` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Polish/doors.json` | identical | `81bc95b357d1a4a200951d7f9ddf74ce79fb48c5c5e641ef5543d7b6af1df3ff` | `81bc95b357d1a4a200951d7f9ddf74ce79fb48c5c5e641ef5543d7b6af1df3ff` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Polish/dvergr.json` | identical | `b891f7c2899e91eb2b7577d00ed3c60627cc1cc5673032c7224472f769a8fb35` | `b891f7c2899e91eb2b7577d00ed3c60627cc1cc5673032c7224472f769a8fb35` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Polish/misc.json` | identical | `631d10bcc9e64ba182dcc4e49b00f5b6e27c548a79e8aa9732ac1ce91852d382` | `631d10bcc9e64ba182dcc4e49b00f5b6e27c548a79e8aa9732ac1ce91852d382` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Polish/pieces.json` | identical | `6f17f2d6141468a9614dee056dc5effa827af8c634aa6e76bc7850798cbad156` | `6f17f2d6141468a9614dee056dc5effa827af8c634aa6e76bc7850798cbad156` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Portuguese_Brazilian/big.json` | identical | `0f236d95d88073236fbce8836ad6ba5bf26a344a0737d3ed9bb788e5851cfd1f` | `0f236d95d88073236fbce8836ad6ba5bf26a344a0737d3ed9bb788e5851cfd1f` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Portuguese_Brazilian/decors.json` | identical | `e20a66c3e3e9415cbb6f7491f4a2bb4a97909030d2058ce780e4f3b9188ab767` | `e20a66c3e3e9415cbb6f7491f4a2bb4a97909030d2058ce780e4f3b9188ab767` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Portuguese_Brazilian/doors.json` | identical | `4d99f4f2ccaa03c4cdc79b7988b188f32d5b31e79eb07a4ef0ee88d04d0f4567` | `4d99f4f2ccaa03c4cdc79b7988b188f32d5b31e79eb07a4ef0ee88d04d0f4567` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Portuguese_Brazilian/dvergr.json` | identical | `328b2854a035b6d154c915f7c439664de9f9c7db5cd67b827e942204bd38becd` | `328b2854a035b6d154c915f7c439664de9f9c7db5cd67b827e942204bd38becd` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Portuguese_Brazilian/misc.json` | identical | `075ecf37b4121cee49bd5776593c3a94162e2eca10e3abaf1a21dc75941aa7b2` | `075ecf37b4121cee49bd5776593c3a94162e2eca10e3abaf1a21dc75941aa7b2` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Portuguese_Brazilian/pieces.json` | identical | `19f04f5372d45ede62a3e56c8e4322144ba4dac1e4f294a2da2dc875e9e3b702` | `19f04f5372d45ede62a3e56c8e4322144ba4dac1e4f294a2da2dc875e9e3b702` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Russian/big.json` | identical | `de1981c8b046784f70e3e5e5d70113c78e81fe9477bbe5075de9135a0b872e0a` | `de1981c8b046784f70e3e5e5d70113c78e81fe9477bbe5075de9135a0b872e0a` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Russian/decors.json` | identical | `ddc33385ad7eac7f9fd4665a8a6fde5a504d99057a8362c37985be608a119f42` | `ddc33385ad7eac7f9fd4665a8a6fde5a504d99057a8362c37985be608a119f42` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Russian/doors.json` | identical | `d0a355bff95abfdb750a3d6697698d5fd3d227cbe0f01a9b68d2353c592f4b8e` | `d0a355bff95abfdb750a3d6697698d5fd3d227cbe0f01a9b68d2353c592f4b8e` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Russian/dvergr.json` | identical | `e43270e4fca25b465f07863a9ed4b8a54c2de8aa8de337baddd50c93747a5b1e` | `e43270e4fca25b465f07863a9ed4b8a54c2de8aa8de337baddd50c93747a5b1e` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Russian/misc.json` | identical | `6c40dc6a723d2e83f4e3c4a8c90c7f0c8aa3866dc7676b73b4c8073e58d32c60` | `6c40dc6a723d2e83f4e3c4a8c90c7f0c8aa3866dc7676b73b4c8073e58d32c60` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Russian/pieces.json` | identical | `b571e44f7ecb88cf45eb4422bab90ba3f8edb8e345caeac2f479847003d1c907` | `b571e44f7ecb88cf45eb4422bab90ba3f8edb8e345caeac2f479847003d1c907` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Spanish/big.json` | identical | `4e1fd9045eae6464e371a7e138ff19d235e8ed6a1f677c0a565b96f7110dda93` | `4e1fd9045eae6464e371a7e138ff19d235e8ed6a1f677c0a565b96f7110dda93` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Spanish/decors.json` | identical | `bdec3a1589d6e8aed87e71255164c57fc48f89ca81507b78831e6a8e787e597b` | `bdec3a1589d6e8aed87e71255164c57fc48f89ca81507b78831e6a8e787e597b` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Spanish/doors.json` | identical | `1595b9d46884dc97b3cdb9c562f0a26ea6808ee6f7492ddf0d3090dea01f84e4` | `1595b9d46884dc97b3cdb9c562f0a26ea6808ee6f7492ddf0d3090dea01f84e4` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Spanish/dvergr.json` | identical | `475719546681a4b673193d0148f84a0a2b5524185cdb4df3d18a4f626fa48fe1` | `475719546681a4b673193d0148f84a0a2b5524185cdb4df3d18a4f626fa48fe1` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Spanish/misc.json` | identical | `bc332bf3fcf8cb477d4a518811d8e0136834d5d89d9d7b3da0ccd645e80f736c` | `bc332bf3fcf8cb477d4a518811d8e0136834d5d89d9d7b3da0ccd645e80f736c` |
| `OdinArchitect/OdinArchitect/Assets/Translations/Spanish/pieces.json` | identical | `24b3ed1177e2a1f0fc72078821c04d69aa5d0c41360983dfb06a365838752630` | `24b3ed1177e2a1f0fc72078821c04d69aa5d0c41360983dfb06a365838752630` |
| `OdinArchitect/OdinArchitect/OdinArchitect.dll` | identical | `83e256b6502ee4adbf31e9ddaedf0242f87f926eec5b1609e06105c66bf6bc7a` | `83e256b6502ee4adbf31e9ddaedf0242f87f926eec5b1609e06105c66bf6bc7a` |
| `OdinCampsite/LocalizationExamples.zip` | identical | `80b33f539282d862625e313c610f17e11d12b4459fd63b6e9dd6851a8a1da21e` | `80b33f539282d862625e313c610f17e11d12b4459fd63b6e9dd6851a8a1da21e` |
| `OdinCampsite/OdinCampsite.dll` | identical | `c81e8e6ad803be05ed3f32a3113b03faaca82d7fadc68c960c3b66082cd6a0a5` | `c81e8e6ad803be05ed3f32a3113b03faaca82d7fadc68c960c3b66082cd6a0a5` |
| `OdinEye/NGuid.dll` | identical | `8b605225496e25237e5dec6daaf22022c99b4a4fa79977a00d6c64e5be176b0d` | `8b605225496e25237e5dec6daaf22022c99b4a4fa79977a00d6c64e5be176b0d` |
| `OdinEye/OdinEye.Models.dll` | identical | `5645083275daf62d63e8283909c38ddb7875cc8c5f63b47f4880c6069c1dbb3d` | `5645083275daf62d63e8283909c38ddb7875cc8c5f63b47f4880c6069c1dbb3d` |
| `OdinEye/OdinEye.dll` | identical | `47f4eecc44b7c6aeb09216e33b5c66d7ccab82f87c4191a77ba5112eb3d10a23` | `47f4eecc44b7c6aeb09216e33b5c66d7ccab82f87c4191a77ba5112eb3d10a23` |
| `OdinEye/System.Buffers.dll` | identical | `accccfbe45d9f08ffeed9916e37b33e98c65be012cfff6e7fa7b67210ce1fefb` | `accccfbe45d9f08ffeed9916e37b33e98c65be012cfff6e7fa7b67210ce1fefb` |
| `OdinEye/System.Collections.Immutable.dll` | identical | `d168af8e4a1263b5844180b1b371c5879b21b5b666feef7ca749b10192688006` | `d168af8e4a1263b5844180b1b371c5879b21b5b666feef7ca749b10192688006` |
| `OdinEye/System.Memory.dll` | identical | `bf3fb84664f4097f1a8a9bc71a51dcf8cf1a905d4080a4d290da1730866e856f` | `bf3fb84664f4097f1a8a9bc71a51dcf8cf1a905d4080a4d290da1730866e856f` |
| `OdinEye/System.Runtime.CompilerServices.Unsafe.dll` | identical | `37768488e8ef45729bc7d9a2677633c6450042975bb96516e186da6cb9cd0dcf` | `37768488e8ef45729bc7d9a2677633c6450042975bb96516e186da6cb9cd0dcf` |
| `OdinEye/System.Threading.Tasks.Extensions.dll` | identical | `64a9dac7b276d34ef904d94e88dc85f9fb4053bb90966b9a250b41771ba3f9fd` | `64a9dac7b276d34ef904d94e88dc85f9fb4053bb90966b9a250b41771ba3f9fd` |
| `OdinEye/Utf8Json.dll` | identical | `ffa2062c78bac6010a13c4457756b04f86fbdf234b2d6b40f3198ec09b0006a5` | `ffa2062c78bac6010a13c4457756b04f86fbdf234b2d6b40f3198ec09b0006a5` |
| `OdinEye/WebsocketSharp.Core.dll` | identical | `267df795c67c0cdd88661752c6174bb79e6dfaa047f472fa25d350b9182f5f46` | `267df795c67c0cdd88661752c6174bb79e6dfaa047f472fa25d350b9182f5f46` |
| `OdinEye/protobuf-net.Core.dll` | identical | `716e5dc398bca7c4b13b38d2ed72f04b8d76b03fb6f3293e2225b17614533517` | `716e5dc398bca7c4b13b38d2ed72f04b8d76b03fb6f3293e2225b17614533517` |
| `OdinEye/protobuf-net.dll` | identical | `ca62620b36b834c4d345831f467d40c24e5dc5606c688521e0a277470a1c24f5` | `ca62620b36b834c4d345831f467d40c24e5dc5606c688521e0a277470a1c24f5` |
| `OdinOnDemand/LibVLC.LICENSE.txt` | identical | `3772d22d9fb80d7d7abb3f142ce6b16e5ff4112620ab58e5c38680269987d63d` | `3772d22d9fb80d7d7abb3f142ce6b16e5ff4112620ab58e5c38680269987d63d` |
| `OdinOnDemand/LibVLCSharp.dll` | identical | `c69b4a45dbeb554d99090941273731a88bd4636a054c09c846633d6d50dc4adc` | `c69b4a45dbeb554d99090941273731a88bd4636a054c09c846633d6d50dc4adc` |
| `OdinOnDemand/OdinOnDemand.dll` | identical | `85be0e140079e05747d1af7f57fe49f7923c33a0175848aac45224aeb9ee1d05` | `85be0e140079e05747d1af7f57fe49f7923c33a0175848aac45224aeb9ee1d05` |
| `OdinOnDemand/libvlc/win-x64/libvlc.dll` | identical | `8ae9f16a72441f43fb4ae8f72c843736726e067ea4a8def2646748631cc4e872` | `8ae9f16a72441f43fb4ae8f72c843736726e067ea4a8def2646748631cc4e872` |
| `OdinOnDemand/libvlc/win-x64/libvlccore.dll` | identical | `d3475b834dd3eb77910f37f71b0341d358bcbdda5b9f04cc4a3a8e2be1bc8e35` | `d3475b834dd3eb77910f37f71b0341d358bcbdda5b9f04cc4a3a8e2be1bc8e35` |
| `OdinOnDemand/libvlc/win-x64/plugins/access/libaccess_imem_plugin.dll` | identical | `548c86ac90fb6de9b3972182e0255feede9ed3e5eb99fe3bd6bac9a976872de4` | `548c86ac90fb6de9b3972182e0255feede9ed3e5eb99fe3bd6bac9a976872de4` |
| `OdinOnDemand/libvlc/win-x64/plugins/access/libfilesystem_plugin.dll` | identical | `0369ada8df130e85f08c2a102943b96ddce753de31299d7b71bc61971be27203` | `0369ada8df130e85f08c2a102943b96ddce753de31299d7b71bc61971be27203` |
| `OdinOnDemand/libvlc/win-x64/plugins/access/libhttp_plugin.dll` | identical | `ac382cfa5598a9baaaad596fddc454dbac07eee7407793c9212f39e39d3db59b` | `ac382cfa5598a9baaaad596fddc454dbac07eee7407793c9212f39e39d3db59b` |
| `OdinOnDemand/libvlc/win-x64/plugins/access/libhttps_plugin.dll` | identical | `f6d8b1845059b00d9efe09a10631591b39ea04e12fc4b3524f7360b2add713b0` | `f6d8b1845059b00d9efe09a10631591b39ea04e12fc4b3524f7360b2add713b0` |
| `OdinOnDemand/libvlc/win-x64/plugins/access/libimem_plugin.dll` | identical | `c0cee305070cf30867f2897b01b5516ec328c9770e0a0c950b638631e13d2402` | `c0cee305070cf30867f2897b01b5516ec328c9770e0a0c950b638631e13d2402` |
| `OdinOnDemand/libvlc/win-x64/plugins/audio_filter/libaudio_format_plugin.dll` | identical | `4db067f9f9061c68922eb3335fc961d13df8c7d9bd7f2decfa5b6aa969e2d570` | `4db067f9f9061c68922eb3335fc961d13df8c7d9bd7f2decfa5b6aa969e2d570` |
| `OdinOnDemand/libvlc/win-x64/plugins/audio_filter/libscaletempo_plugin.dll` | identical | `438f57a1776ab2ae8bd7eb06e02a0137ce6068757c6f5ed409a446fed4c6c898` | `438f57a1776ab2ae8bd7eb06e02a0137ce6068757c6f5ed409a446fed4c6c898` |
| `OdinOnDemand/libvlc/win-x64/plugins/audio_filter/libsimple_channel_mixer_plugin.dll` | identical | `6910104688f499299be592541fecb3bcaadb65ffd3eec76fee0bd22af1ceab2b` | `6910104688f499299be592541fecb3bcaadb65ffd3eec76fee0bd22af1ceab2b` |
| `OdinOnDemand/libvlc/win-x64/plugins/audio_filter/libspeex_resampler_plugin.dll` | identical | `1dc9a9f1bf62b7d5398bec72fd8a9b2fe52441855ce1cf1e99ee34adc1fd8831` | `1dc9a9f1bf62b7d5398bec72fd8a9b2fe52441855ce1cf1e99ee34adc1fd8831` |
| `OdinOnDemand/libvlc/win-x64/plugins/audio_filter/libtrivial_channel_mixer_plugin.dll` | identical | `67a277e9d4817e08066307745e7acd51c7a38119654798909e4768a5f8aa9f0c` | `67a277e9d4817e08066307745e7acd51c7a38119654798909e4768a5f8aa9f0c` |
| `OdinOnDemand/libvlc/win-x64/plugins/audio_filter/libugly_resampler_plugin.dll` | identical | `0f97bf8cc2caa9f7506693ea3cdc061dc9406ae255f20bffbab6cc610a9dd663` | `0f97bf8cc2caa9f7506693ea3cdc061dc9406ae255f20bffbab6cc610a9dd663` |
| `OdinOnDemand/libvlc/win-x64/plugins/audio_mixer/libfloat_mixer_plugin.dll` | identical | `9d4e029f8c03096f59f4ee935f60910600200b482d905e32faebb5bdb3ded51c` | `9d4e029f8c03096f59f4ee935f60910600200b482d905e32faebb5bdb3ded51c` |
| `OdinOnDemand/libvlc/win-x64/plugins/audio_mixer/libinteger_mixer_plugin.dll` | identical | `ca524439ce9829df40fc546e0eefbce6ba5449d6962847d6c59d6a2b6fed0d61` | `ca524439ce9829df40fc546e0eefbce6ba5449d6962847d6c59d6a2b6fed0d61` |
| `OdinOnDemand/libvlc/win-x64/plugins/audio_output/libamem_plugin.dll` | identical | `1cc3f2ede0efb9c7d464799cee46392f9eee330c5529516ff6c048dbb8689218` | `1cc3f2ede0efb9c7d464799cee46392f9eee330c5529516ff6c048dbb8689218` |
| `OdinOnDemand/libvlc/win-x64/plugins/codec/libaraw_plugin.dll` | identical | `6c80d21f5286f2ae6e4e788ce1bb21f439a33008cc590df261972f241fb10af7` | `6c80d21f5286f2ae6e4e788ce1bb21f439a33008cc590df261972f241fb10af7` |
| `OdinOnDemand/libvlc/win-x64/plugins/codec/libavcodec_plugin.dll` | identical | `ded0566aef7b4e9a527cdfeb12f92b9a3b2736b824b687071359244979ee02c7` | `ded0566aef7b4e9a527cdfeb12f92b9a3b2736b824b687071359244979ee02c7` |
| `OdinOnDemand/libvlc/win-x64/plugins/codec/libflac_plugin.dll` | identical | `9a8f89f4da4824cd1ab3f9845566a2e7f7252a2f6b8f50bfe4476eda68dd736e` | `9a8f89f4da4824cd1ab3f9845566a2e7f7252a2f6b8f50bfe4476eda68dd736e` |
| `OdinOnDemand/libvlc/win-x64/plugins/codec/libmpg123_plugin.dll` | identical | `9fac41cb8c4e2b689861bd05fb9ca6d2e56d27c268f394e5b293cc6bd9dbd603` | `9fac41cb8c4e2b689861bd05fb9ca6d2e56d27c268f394e5b293cc6bd9dbd603` |
| `OdinOnDemand/libvlc/win-x64/plugins/codec/libopus_plugin.dll` | identical | `ba1981e08ff674b703af48dccbfe57800fed73d691cab244ff11acc9b22af1fe` | `ba1981e08ff674b703af48dccbfe57800fed73d691cab244ff11acc9b22af1fe` |
| `OdinOnDemand/libvlc/win-x64/plugins/codec/libvorbis_plugin.dll` | identical | `d4085b983525314903bf070eb7f60ed5700185d033f6c7d2ad94f159632f77cf` | `d4085b983525314903bf070eb7f60ed5700185d033f6c7d2ad94f159632f77cf` |
| `OdinOnDemand/libvlc/win-x64/plugins/demux/libadaptive_plugin.dll` | identical | `138d1f535257f9e1a8aa6059929d63196ea17fd7784638cb4d36108ffe78c6fe` | `138d1f535257f9e1a8aa6059929d63196ea17fd7784638cb4d36108ffe78c6fe` |
| `OdinOnDemand/libvlc/win-x64/plugins/demux/libes_plugin.dll` | identical | `bc8028002b61dd2e35aa59ba49fac85509afaff99805a7027ed49bed0523b67d` | `bc8028002b61dd2e35aa59ba49fac85509afaff99805a7027ed49bed0523b67d` |
| `OdinOnDemand/libvlc/win-x64/plugins/demux/libh26x_plugin.dll` | identical | `de0499795161a54c376ef8241ac9c20285d157f09236b16af414e03baac63316` | `de0499795161a54c376ef8241ac9c20285d157f09236b16af414e03baac63316` |
| `OdinOnDemand/libvlc/win-x64/plugins/demux/libmp4_plugin.dll` | identical | `a54eb7b815780f224837bf8af9d34bedf1a33a5be2cc69167f25a86bae815df4` | `a54eb7b815780f224837bf8af9d34bedf1a33a5be2cc69167f25a86bae815df4` |
| `OdinOnDemand/libvlc/win-x64/plugins/demux/libogg_plugin.dll` | identical | `baf883d342bc67ccb50724770fed5625116addf6904858b17cfb292d26092a69` | `baf883d342bc67ccb50724770fed5625116addf6904858b17cfb292d26092a69` |
| `OdinOnDemand/libvlc/win-x64/plugins/demux/libts_plugin.dll` | identical | `c7661fec4320ac364394d6869cefde7934c892f972a34ff9d7c5a8323094dfa4` | `c7661fec4320ac364394d6869cefde7934c892f972a34ff9d7c5a8323094dfa4` |
| `OdinOnDemand/libvlc/win-x64/plugins/demux/libwav_plugin.dll` | identical | `89b543aceee02f3719e55744bdb632142d58ead33dcf3013069843a12a421bb9` | `89b543aceee02f3719e55744bdb632142d58ead33dcf3013069843a12a421bb9` |
| `OdinOnDemand/libvlc/win-x64/plugins/misc/libgnutls_plugin.dll` | identical | `021afe1f20aa98fd434ca858a70745de511b99b4ee56c82f5eb6765c6e24048f` | `021afe1f20aa98fd434ca858a70745de511b99b4ee56c82f5eb6765c6e24048f` |
| `OdinOnDemand/libvlc/win-x64/plugins/packetizer/libpacketizer_copy_plugin.dll` | identical | `b3eca16f497983ceb34f065b650c14cd1d578febdb13bfc2c09b071d3a2922a2` | `b3eca16f497983ceb34f065b650c14cd1d578febdb13bfc2c09b071d3a2922a2` |
| `OdinOnDemand/libvlc/win-x64/plugins/packetizer/libpacketizer_flac_plugin.dll` | identical | `b63f7677bca053bb8176a03297b7d7a3f92dad714a7fcfa7b06a678020b281fc` | `b63f7677bca053bb8176a03297b7d7a3f92dad714a7fcfa7b06a678020b281fc` |
| `OdinOnDemand/libvlc/win-x64/plugins/packetizer/libpacketizer_h264_plugin.dll` | identical | `42a612c1022938a2186a84ddb3da5b4762c7a7dd0e99efa4bf89abd9ab215aa5` | `42a612c1022938a2186a84ddb3da5b4762c7a7dd0e99efa4bf89abd9ab215aa5` |
| `OdinOnDemand/libvlc/win-x64/plugins/packetizer/libpacketizer_hevc_plugin.dll` | identical | `2a09bd981a21a1e790648082bd3d19794caf5ea932aadfd509c0e852d9e6069a` | `2a09bd981a21a1e790648082bd3d19794caf5ea932aadfd509c0e852d9e6069a` |
| `OdinOnDemand/libvlc/win-x64/plugins/packetizer/libpacketizer_mpeg4audio_plugin.dll` | identical | `126374adc41b752e7389370771b32a31cde7b858d28b7b575ff6e45f7cc54825` | `126374adc41b752e7389370771b32a31cde7b858d28b7b575ff6e45f7cc54825` |
| `OdinOnDemand/libvlc/win-x64/plugins/packetizer/libpacketizer_mpegaudio_plugin.dll` | identical | `9f80f801306c792fea81f923a78deb66f6bc4316ed20c5d01a108c35c5ab51f1` | `9f80f801306c792fea81f923a78deb66f6bc4316ed20c5d01a108c35c5ab51f1` |
| `OdinOnDemand/libvlc/win-x64/plugins/stream_filter/libcache_block_plugin.dll` | identical | `a4020b826c40aea8965474caf9e3d8926c8d0bf1d940ca694e1e6178b1d0671c` | `a4020b826c40aea8965474caf9e3d8926c8d0bf1d940ca694e1e6178b1d0671c` |
| `OdinOnDemand/libvlc/win-x64/plugins/stream_filter/libcache_read_plugin.dll` | identical | `b4254e1e469648754b4790af6beecfdbb7798e6ec65c9bb522e4bdd4200b183d` | `b4254e1e469648754b4790af6beecfdbb7798e6ec65c9bb522e4bdd4200b183d` |
| `OdinOnDemand/libvlc/win-x64/plugins/stream_filter/libinflate_plugin.dll` | identical | `008c5137f9a67977587f4b7e57ea0f9a33af0eb59bea98a9fe137a5e1333fee6` | `008c5137f9a67977587f4b7e57ea0f9a33af0eb59bea98a9fe137a5e1333fee6` |
| `OdinOnDemand/libvlc/win-x64/plugins/stream_filter/libprefetch_plugin.dll` | identical | `7b1461cb2269d2d754da1af04e15e21e193c74af1202ee833843c10acbd89a53` | `7b1461cb2269d2d754da1af04e15e21e193c74af1202ee833843c10acbd89a53` |
| `OdinOnDemand/libvlc/win-x64/plugins/stream_filter/libskiptags_plugin.dll` | identical | `249c3b44e94b5fb1e57103948125fc5e0e4c302398b004460b8b847e60d9a00e` | `249c3b44e94b5fb1e57103948125fc5e0e4c302398b004460b8b847e60d9a00e` |
| `OdinOnDemand/libvlc/win-x64/plugins/video_chroma/libchain_plugin.dll` | identical | `88b66b96f53da31b57e76dab207eb5f66cca97dacc9d8f593eccd9d27627459a` | `88b66b96f53da31b57e76dab207eb5f66cca97dacc9d8f593eccd9d27627459a` |
| `OdinOnDemand/libvlc/win-x64/plugins/video_chroma/libi420_rgb_mmx_plugin.dll` | identical | `fb398cd60810009228159a6cd0e4d210e1cdd461f70f9d1b1e1da6548e1f01d4` | `fb398cd60810009228159a6cd0e4d210e1cdd461f70f9d1b1e1da6548e1f01d4` |
| `OdinOnDemand/libvlc/win-x64/plugins/video_chroma/libi420_rgb_plugin.dll` | identical | `f4eb9cca44f7edf1b5c26551a1b193999fbe97c5175f713af3d8453391f69c17` | `f4eb9cca44f7edf1b5c26551a1b193999fbe97c5175f713af3d8453391f69c17` |
| `OdinOnDemand/libvlc/win-x64/plugins/video_chroma/libi420_rgb_sse2_plugin.dll` | identical | `1f3fbde84677e31386f6982acade1332a27c2fb6f1b091c5a1a874b953b8084f` | `1f3fbde84677e31386f6982acade1332a27c2fb6f1b091c5a1a874b953b8084f` |
| `OdinOnDemand/libvlc/win-x64/plugins/video_chroma/librv32_plugin.dll` | identical | `6c0cc8c5afffc92cde2ce88c365ddf6703de964d9bbc408ec463d5154be8b0d3` | `6c0cc8c5afffc92cde2ce88c365ddf6703de964d9bbc408ec463d5154be8b0d3` |
| `OdinOnDemand/libvlc/win-x64/plugins/video_chroma/libswscale_plugin.dll` | identical | `51ef783c1addd748d31fa1e53765f0d8d787d348f9bdf0f00eb7c5bead25f9d0` | `51ef783c1addd748d31fa1e53765f0d8d787d348f9bdf0f00eb7c5bead25f9d0` |
| `OdinOnDemand/libvlc/win-x64/plugins/video_output/libvmem_plugin.dll` | identical | `4255f130215013044644f418b355aada781032b1d0ae28cf27b4eda57a9fe863` | `4255f130215013044644f418b355aada781032b1d0ae28cf27b4eda57a9fe863` |
| `OdinShip/OdinShip/OdinShip.dll` | identical | `5d5817bc169677db49cae55986b3f6a178ab3bf0b1d681a2aba4ecc5dac067d0` | `5d5817bc169677db49cae55986b3f6a178ab3bf0b1d681a2aba4ecc5dac067d0` |
| `OdinsFoodBarrels/OdinsFoodBarrels.dll` | identical | `fc9cf4574ccd46147afaec3c4240f0d402160fc81209b55ff5f50091fcaeec0b` | `fc9cf4574ccd46147afaec3c4240f0d402160fc81209b55ff5f50091fcaeec0b` |
| `OdinsKingdom/OdinsKingdom.dll` | identical | `46a05156036e8b16a8323313f3ee99f20bdcc4ad2903ce34a04e2f4b56e77504` | `46a05156036e8b16a8323313f3ee99f20bdcc4ad2903ce34a04e2f4b56e77504` |
| `PlanBuild/PlanBuild/CHANGELOG.md` | identical | `43ae43600b73de602275b6b0a34ad43f193fd8c0de99d84ead05fc40bae84b35` | `43ae43600b73de602275b6b0a34ad43f193fd8c0de99d84ead05fc40bae84b35` |
| `PlanBuild/PlanBuild/PlanBuild.dll` | identical | `27e3d8f28393572bef8ee1ea311e77628a37b3f3aac802022cf413d329246de6` | `27e3d8f28393572bef8ee1ea311e77628a37b3f3aac802022cf413d329246de6` |
| `PlanBuild/PlanBuild/README.md` | identical | `b8b2e19dbc6ebbbb97c9cec8d529abf24b1e0e48c6f85a6a0289ab6ced632332` | `b8b2e19dbc6ebbbb97c9cec8d529abf24b1e0e48c6f85a6a0289ab6ced632332` |
| `PlanBuild/PlanBuild/Translations/Chinese/PlanBuild.chinese.json` | identical | `8fcdb14eae2d220dd421b1dc90e8e1f0fdfa27d29e247a72a7c98e3947531264` | `8fcdb14eae2d220dd421b1dc90e8e1f0fdfa27d29e247a72a7c98e3947531264` |
| `PlanBuild/PlanBuild/Translations/English/PlanBuild.english.json` | identical | `de049812a36255e804f7cd24aa2a469c3b9b12f7f80dd1ceec61dda4c08eb179` | `de049812a36255e804f7cd24aa2a469c3b9b12f7f80dd1ceec61dda4c08eb179` |
| `PlanBuild/PlanBuild/Translations/German/PlanBuild.Deutsch.json` | identical | `76b6727d1205f55af17ed2f553b2623f427e39083466d61331734c4b5e28f347` | `76b6727d1205f55af17ed2f553b2623f427e39083466d61331734c4b5e28f347` |
| `PlanBuild/PlanBuild/Translations/Korean/PlanBuild.korean.json` | identical | `92c0df80a8d6347ed1ea6ed4d6ae5b2b21e43b10de003b071e52b4a4554140fb` | `92c0df80a8d6347ed1ea6ed4d6ae5b2b21e43b10de003b071e52b4a4554140fb` |
| `PlanBuild/PlanBuild/Translations/Portuguese_Brazilian/PlanBuild.Portuguese_Brazilian.json` | identical | `77fb90015ea52a30630770ca42423ecc9ef0ad1837b40c238959937cb5ff3fb5` | `77fb90015ea52a30630770ca42423ecc9ef0ad1837b40c238959937cb5ff3fb5` |
| `PlanBuild/PlanBuild/Translations/Russian/PlanBuild.russian.json` | identical | `1d43f53dff5f758ed0f10af7e89ac55bd05f86ff66e1ea0d3d9b556695df15e2` | `1d43f53dff5f758ed0f10af7e89ac55bd05f86ff66e1ea0d3d9b556695df15e2` |
| `PlanBuild/PlanBuild/Translations/Spanish/PlanBuild.Spanish.json` | identical | `652bce0a968dcefa94972f36c89f7f3ebf775150a8a7de138a87a3f65a884d7e` | `652bce0a968dcefa94972f36c89f7f3ebf775150a8a7de138a87a3f65a884d7e` |
| `PlantEverything/Advize_PlantEverything.dll` | identical | `313d57d5d9df2a27bff04ab184487d544a0749bbbe2c10cb1c41a0ae964cac62` | `313d57d5d9df2a27bff04ab184487d544a0749bbbe2c10cb1c41a0ae964cac62` |
| `ProgressivePowers/ProgressivePowers.dll` | identical | `47bc7eeea04be0f3f956d88625f9c8de49d369162c81c6428115b0fae25d39e4` | `47bc7eeea04be0f3f956d88625f9c8de49d369162c81c6428115b0fae25d39e4` |
| `ProximityVoiceChat/Concentus-LICENSE.txt` | identical | `c17f3900e66526e46b23839b62e4b507b03a51cc262d925fb8ad5c753afc0026` | `c17f3900e66526e46b23839b62e4b507b03a51cc262d925fb8ad5c753afc0026` |
| `ProximityVoiceChat/MetaVoiceChat-LICENSE.txt` | identical | `674150c56ee33a7e55eee99d2b5a8e43b333e7709b4084c11a8d1dc56be62baa` | `674150c56ee33a7e55eee99d2b5a8e43b333e7709b4084c11a8d1dc56be62baa` |
| `ProximityVoiceChat/ProximityVoiceChat.dll` | identical | `96d986454319f8812fab978af44ded57b01159bed2226a89986eae3b549b019e` | `96d986454319f8812fab978af44ded57b01159bed2226a89986eae3b549b019e` |
| `ProximityVoiceChat/YamlDotNet-LICENSE.txt` | identical | `5d9812ce65210d7c967dda6bcedc84e85a908af1b9b7587e0947b7e5c77b8817` | `5d9812ce65210d7c967dda6bcedc84e85a908af1b9b7587e0947b7e5c77b8817` |
| `Quick_Stack_Store_Sort_Trash_Restock/LICENSE` | identical | `11787fe389337c83955e7aae58a54c690788d6f89561cf14e87f31daf28e5235` | `11787fe389337c83955e7aae58a54c690788d6f89561cf14e87f31daf28e5235` |
| `Quick_Stack_Store_Sort_Trash_Restock/QuickStackStore.dll` | identical | `71ccc644da95d4fa94897968d5d90331210a574a6c65129dc8ec6032e3cf6eeb` | `71ccc644da95d4fa94897968d5d90331210a574a6c65129dc8ec6032e3cf6eeb` |
| `Quick_Stack_Store_Sort_Trash_Restock/Translations/Credits` | identical | `df3a3d701f7364f3b6cffd2f1dc53c9d764e0b381449b68d98868bedb9a868dd` | `df3a3d701f7364f3b6cffd2f1dc53c9d764e0b381449b68d98868bedb9a868dd` |
| `Quick_Stack_Store_Sort_Trash_Restock/Translations/QuickStackStore.Chinese.json` | identical | `920a3f7dac53e42e45a36fbb0acaf186fc119f5724f78bbf05a50a19e36fd34c` | `920a3f7dac53e42e45a36fbb0acaf186fc119f5724f78bbf05a50a19e36fd34c` |
| `Quick_Stack_Store_Sort_Trash_Restock/Translations/QuickStackStore.English.json` | identical | `c0e39e22afc2a2547ac6d36d838cec57ecfd8ad847c025295e56dcc3a05e462f` | `c0e39e22afc2a2547ac6d36d838cec57ecfd8ad847c025295e56dcc3a05e462f` |
| `Quick_Stack_Store_Sort_Trash_Restock/Translations/QuickStackStore.French.json` | identical | `79991f19fd67e32c9e07002b5d304554a6308b995d05cb6ce0e411378485da26` | `79991f19fd67e32c9e07002b5d304554a6308b995d05cb6ce0e411378485da26` |
| `Quick_Stack_Store_Sort_Trash_Restock/Translations/QuickStackStore.German.json` | identical | `5bae7e1b117d7806a28506d0fe5c86d1e4cf0697f83880b658d982ebe6dc6c1d` | `5bae7e1b117d7806a28506d0fe5c86d1e4cf0697f83880b658d982ebe6dc6c1d` |
| `Quick_Stack_Store_Sort_Trash_Restock/Translations/QuickStackStore.Italian.json` | identical | `635e6fb8df3b711541a112d7b37ff324e393dc583d95cea9a450964f859f6168` | `635e6fb8df3b711541a112d7b37ff324e393dc583d95cea9a450964f859f6168` |
| `Quick_Stack_Store_Sort_Trash_Restock/Translations/QuickStackStore.Korean.json` | identical | `2ac7dec1f85f47021c242fd83a98f3a75246f07940f65bafc825091cf3e696c7` | `2ac7dec1f85f47021c242fd83a98f3a75246f07940f65bafc825091cf3e696c7` |
| `Quick_Stack_Store_Sort_Trash_Restock/Translations/QuickStackStore.Polish.json` | identical | `fc1aee697765cfe7facf7054f6f3802fdbe79fb8256d4d53fd6df82956b8fa98` | `fc1aee697765cfe7facf7054f6f3802fdbe79fb8256d4d53fd6df82956b8fa98` |
| `Quick_Stack_Store_Sort_Trash_Restock/Translations/QuickStackStore.Portuguese_Brazilian.json` | identical | `162e7127236a34c96e9edf225ad70f860d36719045bad18da99f2f296e2dc7ae` | `162e7127236a34c96e9edf225ad70f860d36719045bad18da99f2f296e2dc7ae` |
| `Quick_Stack_Store_Sort_Trash_Restock/Translations/QuickStackStore.Russian.json` | identical | `fceeea57808fc8953fbd1954d5fc0bdb3e4adf7ebde32095b221fddaf0e47687` | `fceeea57808fc8953fbd1954d5fc0bdb3e4adf7ebde32095b221fddaf0e47687` |
| `Quick_Stack_Store_Sort_Trash_Restock/Translations/QuickStackStore.Spanish.json` | identical | `62af6d30f30edec862fe8b0b74150f0b30f9041622f8ee03634d504f829c8747` | `62af6d30f30edec862fe8b0b74150f0b30f9041622f8ee03634d504f829c8747` |
| `Quick_Stack_Store_Sort_Trash_Restock/Translations/QuickStackStore.Swedish.json` | identical | `dd26f5bbb37370059a4abe440ed45ea287e0117215797dea5583014eac9f9608` | `dd26f5bbb37370059a4abe440ed45ea287e0117215797dea5583014eac9f9608` |
| `Quick_Stack_Store_Sort_Trash_Restock/Translations/QuickStackStore.Ukrainian.json` | identical | `ca801f39248ba0ab36fe476efb56e356e61205886113304e92caeedf7516f5de` | `ca801f39248ba0ab36fe476efb56e356e61205886113304e92caeedf7516f5de` |
| `SaunaMod/SaunaMod.dll` | identical | `2cc21e60f607b48c93a45e577dce7a5c2b85e85dddc2a163b7074d6f5c016999` | `2cc21e60f607b48c93a45e577dce7a5c2b85e85dddc2a163b7074d6f5c016999` |
| `SaunaMod/icons/steaming.png` | identical | `b47ff6497b91d1975ae45cc6767fec2fb5cda2829c3d12bd563a2ff9366a522d` | `b47ff6497b91d1975ae45cc6767fec2fb5cda2829c3d12bd563a2ff9366a522d` |
| `SaunaMod/icons/stove.png` | identical | `1673cfc5c6147f0ccc1958b4a9471cc0152fe594be7dbe0bffe2e302b5031702` | `1673cfc5c6147f0ccc1958b4a9471cc0152fe594be7dbe0bffe2e302b5031702` |
| `SaunaMod/icons/wellsteamed.png` | identical | `99a0ef4caa132bfc65691ba1ccf15f12c8a6a4167e43af2a1760021afb34a257` | `99a0ef4caa132bfc65691ba1ccf15f12c8a6a4167e43af2a1760021afb34a257` |
| `SaunaMod/sounds/pour.wav` | identical | `490529d1b7e02bbe0b24497fcb28bd345731f527d5ddbcedfc44a17c696aed3e` | `490529d1b7e02bbe0b24497fcb28bd345731f527d5ddbcedfc44a17c696aed3e` |
| `SeaAnimals/SeaAnimals/SeaAnimals.dll` | identical | `3f57f6ad089d5616a924d5917851a0a7c99715cc0b2062ef23b2fa15d07c721a` | `3f57f6ad089d5616a924d5917851a0a7c99715cc0b2062ef23b2fa15d07c721a` |
| `SearsCatalog/SearsCatalog.dll` | identical | `07767da939e2647d6868962eecf78f58ff5116ec89dfa313d495ddd38af2ed53` | `07767da939e2647d6868962eecf78f58ff5116ec89dfa313d495ddd38af2ed53` |
| `SeedBed/47-Items-FromDifferentMods.zip` | identical | `761459b381cce6efc038fd85121bf140028625a10d9a3b3fdc8bab834a1c1067` | `761459b381cce6efc038fd85121bf140028625a10d9a3b3fdc8bab834a1c1067` |
| `SeedBed/LocalizationExample.zip` | identical | `f591d41764d9cbb7138817911ae8d4eb258c7652dcb0c87b3ee5234191a61acb` | `f591d41764d9cbb7138817911ae8d4eb258c7652dcb0c87b3ee5234191a61acb` |
| `SeedBed/SeedBed.dll` | identical | `e11f04bf3b267ceeac0bb990d89b21d77a190ca074058d327c88a0712d0d9ce5` | `e11f04bf3b267ceeac0bb990d89b21d77a190ca074058d327c88a0712d0d9ce5` |
| `SeparateSpawns/SeparateSpawns.dll` | identical | `d1321879e55c8080ff7001cba59be896156179197b608f5851b649b4b95a84a8` | `d1321879e55c8080ff7001cba59be896156179197b608f5851b649b4b95a84a8` |
| `SeparateSpawns/reports/918809704/layout_01.png` | live-only: runtime output of SeparateSpawns | `43548d4ece1e76d1357e7d0f424748e86d88ba652299078cd885fa55f9856457` | — |
| `SeparateSpawns/reports/918809704/summary.txt` | live-only: runtime output of SeparateSpawns | `5578e282c88dac3c1f3d92a68313e9dff0ff3ba16e61f0650353d6ed0d775e08` | — |
| `ServerManager/ServerManager.English.yml` | identical | `9a30fc29cf774c58b93aa47529f96cd27b83667dcce4a80a5881b940fc4e763f` | `9a30fc29cf774c58b93aa47529f96cd27b83667dcce4a80a5881b940fc4e763f` |
| `ServerManager/ServerManager.dll` | identical | `779590b133f8aea81b3c3fdb7f0f01938994bd3d0da34b3d424484c015ac2aae` | `779590b133f8aea81b3c3fdb7f0f01938994bd3d0da34b3d424484c015ac2aae` |
| `ServerQuickConnect/ServerQuickConnect.dll` | identical | `798f08273d2de07d4c8c792f241fd65cb2e830dff4076733da65ed93a4c1fec9` | `798f08273d2de07d4c8c792f241fd65cb2e830dff4076733da65ed93a4c1fec9` |
| `Server_devcommands/ServerDevcommands.dll` | identical | `f41812ac8c7c759ca60e84beef716c438fb766adda592f8a9365a86514bbda15` | `f41812ac8c7c759ca60e84beef716c438fb766adda592f8a9365a86514bbda15` |
| `SkadiNet/SkadiNet.dll` | identical | `7a419144fd8fc38cfb521d0479628236ba9d847d708f3eae94632cf8f579ead9` | `7a419144fd8fc38cfb521d0479628236ba9d847d708f3eae94632cf8f579ead9` |
| `TheFisher/TheFisher/TheFisher.dll` | identical | `7e20ed6e3d68fda613be9261924644bc834356e4f7c06f6d8f120dc4cb3894dc` | `7e20ed6e3d68fda613be9261924644bc834356e4f7c06f6d8f120dc4cb3894dc` |
| `TheFisher/TheFisher/translations/TheFisher.French.yml` | identical | `3a9eb8cddb0d4fd3d53563f5ecc4db1c11150c495da32f2d652ea8daec51ec43` | `3a9eb8cddb0d4fd3d53563f5ecc4db1c11150c495da32f2d652ea8daec51ec43` |
| `TheFisher/TheFisher/translations/TheFisher.German.yml` | identical | `290384b15ed4203c50ed5c439e8220f112d568f41c3c652071db7acd8ac12a4c` | `290384b15ed4203c50ed5c439e8220f112d568f41c3c652071db7acd8ac12a4c` |
| `TheFisher/TheFisher/translations/TheFisher.Portuguese_Brazilian.yml` | identical | `6afea815823dbfc9c028bb949e48d363d5e882894038806f0434c03009a8e30c` | `6afea815823dbfc9c028bb949e48d363d5e882894038806f0434c03009a8e30c` |
| `TheFisher/TheFisher/translations/TheFisher.Russian.yml` | identical | `2c0ab083c635f2a4fa986dad26b1da2313fe21586f12c5fc21a65ef2e160d2d9` | `2c0ab083c635f2a4fa986dad26b1da2313fe21586f12c5fc21a65ef2e160d2d9` |
| `TheFisher/TheFisher/translations/TheFisher.Spanish.yml` | identical | `c52c7d0296315c059d9b55dd01b48f649c7ecb165573037a25604bc0a6a616da` | `c52c7d0296315c059d9b55dd01b48f649c7ecb165573037a25604bc0a6a616da` |
| `ValheimVisualEnhanced/ValheimVisualEnhanced/ValheimVisualEnhanced.dll` | identical | `e1f611ad5d1b3a59a79dd9926cd5fd813c4e24265f0626554db52ab51bb25f2e` | `e1f611ad5d1b3a59a79dd9926cd5fd813c4e24265f0626554db52ab51bb25f2e` |
| `ValheimVisualEnhanced/ValheimVisualEnhanced/assets/valheimvisualenhanced` | identical | `5cf578e009c69e8afca6091b7012ba5e56d3a20fbaa41a7d2965db36834b5ae0` | `5cf578e009c69e8afca6091b7012ba5e56d3a20fbaa41a7d2965db36834b5ae0` |
| `ValheimWebMap.dll` | differs: cause unproven (section 4) | `7c5f98a44c43d06346d702f9c6039cbd6a2dca47fde0d38954751b43b38ce13d` | `428bd3956e54e662a6603ee900e52d5f69f4f014fa01ad689698134e934c281d` |
| `Venture_Logout_Tweaks/Plugins/VentureValheim.LogoutTweaks.dll` | identical | `1b8ead5a9615ac4db706c0bf05063debcc429a2ab5e3ca15685a6c40d8fd7f63` | `1b8ead5a9615ac4db706c0bf05063debcc429a2ab5e3ca15685a6c40d8fd7f63` |
| `Venture_Multiplayer_Tweaks/Plugins/VentureValheim.MultiplayerTweaks.dll` | identical | `d08aa6837ddae4bd4e6000e631a023764945a957cae249d437d7ec69425c3662` | `d08aa6837ddae4bd4e6000e631a023764945a957cae249d437d7ec69425c3662` |
| `WhichModAddedThis/WhichModAddedThis.dll` | identical | `11700461ec7d2bdaa22502db4061b945187c5b8004fdbce03dc91dc74ef56fb8` | `11700461ec7d2bdaa22502db4061b945187c5b8004fdbce03dc91dc74ef56fb8` |
| `World_Advancement_Progression/Plugins/VentureValheim.Progression.dll` | identical | `ff126cc55c001f188e20bfae2e8a2c056b4a8144a0c0f1e4f90c6b7aacdbe622` | `ff126cc55c001f188e20bfae2e8a2c056b4a8144a0c0f1e4f90c6b7aacdbe622` |
| `XPortal/XPortal/Translations/Chinese/xportal-translation-chinese.json` | identical | `8931e588bf322a7a8ceab49ff494eb2bd9241a053761dfc038082796856d205e` | `8931e588bf322a7a8ceab49ff494eb2bd9241a053761dfc038082796856d205e` |
| `XPortal/XPortal/Translations/Dutch/xportal-translations-dutch.json` | identical | `ec632b470d90f1466548ae8f7099f604084460681dfe18294823fe958ee83df2` | `ec632b470d90f1466548ae8f7099f604084460681dfe18294823fe958ee83df2` |
| `XPortal/XPortal/Translations/English/xportal-translations-english.json` | identical | `38c9b0d469b18cc51feb3b84cbb60445b262f5f74709e5a3c5d4cf967d553929` | `38c9b0d469b18cc51feb3b84cbb60445b262f5f74709e5a3c5d4cf967d553929` |
| `XPortal/XPortal/Translations/French/xportal-translations-french.json` | identical | `3549282fe06d9e24b027e2f8974f07736892948b72b3af82cc219b4516240ee3` | `3549282fe06d9e24b027e2f8974f07736892948b72b3af82cc219b4516240ee3` |
| `XPortal/XPortal/Translations/German/xportal-translations-german.json` | identical | `0b4c95250d7262fea38aa4c5cdd289d87be857578daccd495c41dabe29a894d7` | `0b4c95250d7262fea38aa4c5cdd289d87be857578daccd495c41dabe29a894d7` |
| `XPortal/XPortal/Translations/Italian/xportal-translations-italian.json` | identical | `9aca740196380462d575f3c1f71d14cb8373520cad5cf91f862e0147bcaee7d6` | `9aca740196380462d575f3c1f71d14cb8373520cad5cf91f862e0147bcaee7d6` |
| `XPortal/XPortal/Translations/Japanese/xportal-translations-japanese.json` | identical | `a8e2afaafe4a8e9cdf9bccee9fe4c2b7d3d777aa7ddd641bec02e333a02e2ead` | `a8e2afaafe4a8e9cdf9bccee9fe4c2b7d3d777aa7ddd641bec02e333a02e2ead` |
| `XPortal/XPortal/Translations/Korean/xportal-translations-korean.json` | identical | `2635d2c7445de9fc663763c5ceaf1b3e73a81318dba20c9ff675cd5082938780` | `2635d2c7445de9fc663763c5ceaf1b3e73a81318dba20c9ff675cd5082938780` |
| `XPortal/XPortal/Translations/Polish/xportal-translations-polish.json` | identical | `66bfd72bca72ba82e9b2f46ea6a95581d73efa61d4b9f79ea8cec31818379773` | `66bfd72bca72ba82e9b2f46ea6a95581d73efa61d4b9f79ea8cec31818379773` |
| `XPortal/XPortal/Translations/Portuguese_Brazilian/xportal-translations-portuguese_brazillian.json` | identical | `130917fdcfb8abff8ce5a462cca4fbaa44bf0f844b7bfbcd940cb128700f0ddc` | `130917fdcfb8abff8ce5a462cca4fbaa44bf0f844b7bfbcd940cb128700f0ddc` |
| `XPortal/XPortal/Translations/Russian/xportal-translations-russian.json` | identical | `808337c876814385cd87cdc7732a86dc3f821185796ef93cab969f2e2acd060e` | `808337c876814385cd87cdc7732a86dc3f821185796ef93cab969f2e2acd060e` |
| `XPortal/XPortal/Translations/Spanish/xportal-translations-spanish.json` | identical | `49c49fc9e42e31dada26ddb65e8b793b413b19632e8a6a91bf61c0d51e2f32a2` | `49c49fc9e42e31dada26ddb65e8b793b413b19632e8a6a91bf61c0d51e2f32a2` |
| `XPortal/XPortal/Translations/Ukrainian/xportal-translations-ukrainian.json` | identical | `fbd4a99b0e00474fe57f896b777cb12ddfbaa1b5ba133a833860cb31da69789a` | `fbd4a99b0e00474fe57f896b777cb12ddfbaa1b5ba133a833860cb31da69789a` |
| `XPortal/XPortal/XPortal.dll` | identical | `955e39351e0aa5c90a1a9ff6f4487983b5fa75bcd2a0e4503517604425ae7ebe` | `955e39351e0aa5c90a1a9ff6f4487983b5fa75bcd2a0e4503517604425ae7ebe` |
| `YamlDotNet/LICENSE.txt` | identical | `daea8b7f1b2bab48ea12ad50b0ce91634669d99d7dd0cb64aed8dffeeef69ed3` | `daea8b7f1b2bab48ea12ad50b0ce91634669d99d7dd0cb64aed8dffeeef69ed3` |
| `YamlDotNet/YamlDotNet.dll` | identical | `9172f0758ed76963e0ede3b5ca9a1fb5b82f64c7e7a92cb3a6de39efa933a668` | `9172f0758ed76963e0ede3b5ca9a1fb5b82f64c7e7a92cb3a6de39efa933a668` |
| `YamlDotNet/YamlDotNetDetector.dll` | identical | `db5a75085f60d69a05979af303d6b0f1db15b1d5d84c77f606d876547ef1f482` | `db5a75085f60d69a05979af303d6b0f1db15b1d5d84c77f606d876547ef1f482` |
| `ZenRaids/ZenRaids.dll` | identical | `19ec4731fb0be8512374cf15c6716963730183919c8cfa4ad2f6508f735a5006` | `19ec4731fb0be8512374cf15c6716963730183919c8cfa4ad2f6508f735a5006` |
| `Zen_ModLib/Translations/English/english.json` | identical | `6b5865778b4b7f282a872c3aa761604a73577582631445b08221c0583f35651d` | `6b5865778b4b7f282a872c3aa761604a73577582631445b08221c0583f35651d` |
| `Zen_ModLib/Translations/Portuguese_Brazilian/Portuguese_Brazilian.json` | identical | `2d07ac042164e8030092f13964595262161f1699211d1bbf2611700e83299b64` | `2d07ac042164e8030092f13964595262161f1699211d1bbf2611700e83299b64` |
| `Zen_ModLib/Zen.ModLib.dll` | identical | `73703e097014d2488a893499714de0b53775fe357ba3b421bff6dccd691438e7` | `73703e097014d2488a893499714de0b53775fe357ba3b421bff6dccd691438e7` |
