// Run from the assigned workspace after the owned server exits:
// bun .nt/evidence/retain-pair.js
// Reads complete file bytes, never reader-mode excerpts. Redacts without adding/removing lines.
import { createHash } from 'node:crypto';
const sha = bytes => createHash('sha256').update(bytes).digest('hex');
const root = process.cwd();
const patterns = [
  'HDR Render Texture not supported', 'Could not find material Hidden/VideoDecode',
  'Could not find material Hidden/VideoComposite', 'YCbCr_To_RGB1', 'YCbCrA_To_RGBAFull',
  'YCbCrA_To_RGBA in', 'Flip_RGBA_To_RGBA', 'Flip_RGBASplit_To_RGBA', 'shader pass Default',
  'This custom render path shader', 'Failed to play intro cinematic',
  'The shader Hidden/Dof/DepthOfFieldHdr',
  'The image effect Main Camera (UnityStandardAssets.ImageEffects.DepthOfField)',
  'The shader Hidden/SunShaftsComposite', 'The shader Hidden/SimpleClear',
  'The image effect Main Camera (UnityStandardAssets.ImageEffects.SunShafts)',
  'System does not support CopyTexture', 'GBuffer Normals only available',
  'AsyncResourceUpload failed', 'IMGUI module is stripped'
];
const sources = [
  ['unity', '.nt/review-fix-raw/server-unity.log', '.nt/evidence/server-unity.log'],
  ['bepinex', '.nt/server/BepInEx/LogOutput.log', '.nt/evidence/server-LogOutput.log']
];
const captures = {};
const texts = {};
for (const [kind, source, target] of sources) {
  const bytes = await Bun.file(source).bytes();
  const original = new TextDecoder('utf-8', { fatal: true, ignoreBOM: true }).decode(bytes);
  if (!Buffer.from(original).equals(Buffer.from(bytes))) throw new Error('UTF-8 roundtrip changed bytes');
  const redacted = original.replaceAll(root, '<RUN_WORKSPACE>')
    .replace(/(Server ID |Caching Steam ID:\s*)\d+/g, '$1<REDACTED>');
  if (/\[Showing lines |Use :\d+ to continue|lines elided/.test(redacted)) throw new Error('Reader framing in source');
  if (original.split('\n').length !== redacted.split('\n').length) throw new Error('Redaction changed line count');
  const markers = ['Opened Steam server', 'ZNet Shutdown', 'Steam manager on destroy'];
  if (kind === 'bepinex') markers.push('Chainloader startup complete');
  for (const marker of markers) {
    if (!redacted.includes(marker)) throw new Error(`${kind} missing lifecycle marker ${marker}`);
  }
  await Bun.write(target, redacted);
  const retained = await Bun.file(target).bytes();
  if (!Buffer.from(retained).equals(Buffer.from(redacted))) throw new Error('Retained bytes differ');
  texts[kind] = redacted;
  captures[kind] = {
    source, target, sourceBytes: bytes.length, retainedBytes: retained.length,
    sourceSha256: sha(bytes), retainedSha256: sha(retained),
    newlineCount: (original.match(/\n/g) ?? []).length,
    endsWithNewline: original.endsWith('\n'),
    fullSourceRead: true, redactionPreservesLineCount: true, retainedByteEquality: true,
    readerFramingAbsent: true,
    lifecycle: redacted.split('\n').flatMap((line, i) =>
      /NullGfxDevice|Renderer: Null|0 plugins to load|Valheim version:|Opened Steam server|OnApplicationQuit|ZNet Shutdown|Steam manager on destroy/.test(line)
        ? [{ line: i + 1, text: line }] : [])
  };
}
const index = patterns.map(family => ({
  family,
  unityLines: texts.unity.split('\n').flatMap((line, i) => line.includes(family) ? [i + 1] : []),
  bepinexLines: texts.bepinex.split('\n').flatMap((line, i) => line.includes(family) ? [i + 1] : [])
}));
const binaryHashes = {};
for (const path of ['valheim_server.x86_64', 'UnityPlayer.so', 'valheim_server_Data/Managed/assembly_valheim.dll', 'BepInEx/core/BepInEx.dll', 'BepInEx/config/BepInEx.cfg']) {
  binaryHashes[path] = sha(await Bun.file(`.nt/server/${path}`).bytes());
}
await Bun.write('.nt/evidence/warning-index.json', JSON.stringify(index, null, 2) + '\n');
await Bun.write('.nt/evidence/capture-integrity.json', JSON.stringify({
  sourceSha: 'e9d22a15ec5c86a5f2d21c062f9c015290c80ebe',
  run: 'amendment-106-107-fresh-pair', captures, binaryHashes
}, null, 2) + '\n');
console.log(JSON.stringify({ captures, counts: index.map(row => [row.family, row.unityLines.length, row.bepinexLines.length]), binaryHashes }, null, 2));
