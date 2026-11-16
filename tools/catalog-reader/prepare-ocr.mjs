import { mkdir, copyFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { dirname, join } from 'node:path';

const require = createRequire(import.meta.url);
const tess = dirname(require.resolve('tesseract.js/package.json'));
const core = dirname(require.resolve('tesseract.js-core/package.json', {paths:[tess]}));
const lang = dirname(require.resolve('@tesseract.js-data/eng/package.json'));
const pdfjs = dirname(require.resolve('pdfjs-dist/package.json'));
const xlsx = dirname(require.resolve('xlsx'));
await mkdir('public/licenses', {recursive:true});
await copyFile(join(pdfjs,'LICENSE'),'public/licenses/PDFJS.txt');
await copyFile(join(xlsx,'LICENSE'),'public/licenses/SheetJS.txt');
await copyFile(join(tess,'LICENSE.md'),'public/licenses/Tesseract.txt');
await mkdir('public/ocr/core', {recursive:true});
await copyFile(join(tess,'dist/worker.min.js'),'public/ocr/worker.min.js');
await copyFile(join(lang,'4.0.0_best_int/eng.traineddata.gz'),'public/ocr/eng.traineddata.gz');
for (const name of ['tesseract-core-lstm', 'tesseract-core-simd-lstm', 'tesseract-core-relaxedsimd-lstm']) {
  for (const extension of ['wasm.js', 'wasm']) {
    const filename = name + '.' + extension;
    try {
      await copyFile(join(core,filename),'public/ocr/core/'+filename);
    } catch (error) {
      if (!name.includes('relaxedsimd') || error.code !== 'ENOENT') throw error;
    }
  }
}
await copyFile(join(core,'LICENSE'),'public/ocr/core/LICENSE');
