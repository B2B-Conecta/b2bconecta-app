import { mkdir, copyFile, readFile, writeFile } from 'node:fs/promises';
import { createHash } from 'node:crypto';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';

const require = createRequire(import.meta.url);
const runtime = dirname(require.resolve('onnxruntime-web/wasm'));
const modelPath = 'public/segmentation/u2netp.onnx';
const modelUrl = 'https://github.com/danielgatis/rembg/releases/download/v0.0.0/u2netp.onnx';
const expectedHash = '309c8469258dda742793dce0ebea8e6dd393174f89934733ecc8b14c76f4ddd8';

await mkdir('public/segmentation', { recursive: true });
for (const name of ['ort-wasm-simd-threaded.mjs', 'ort-wasm-simd-threaded.wasm']) {
  await copyFile(join(runtime, name), 'public/segmentation/' + name);
}
await mkdir('public/licenses', { recursive: true });
await copyFile('ONNX-RUNTIME-LICENSE.txt', 'public/licenses/ONNX-RUNTIME.txt');
await copyFile('U2NET-LICENSE.txt', 'public/licenses/U2NET.txt');

let bytes;
try {
  bytes = await readFile(process.env.B2B_PHOTO_MODEL || modelPath);
} catch (error) {
  if (error.code !== 'ENOENT' || process.env.B2B_PHOTO_MODEL) throw error;
  const response = await fetch(modelUrl, { signal: AbortSignal.timeout(120000) });
  if (!response.ok) throw Error('U2NetP: HTTP ' + response.status);
  const chunks = [];
  let size = 0;
  for await (const chunk of response.body) {
    size += chunk.length;
    if (size > 8 * 1024 * 1024) throw Error('U2NetP excede el tamaño esperado.');
    chunks.push(chunk);
  }
  bytes = Buffer.concat(chunks);
}
if (createHash('sha256').update(bytes).digest('hex') !== expectedHash) {
  throw Error('U2NetP no coincide con el SHA-256 esperado.');
}
await writeFile(modelPath, bytes);
