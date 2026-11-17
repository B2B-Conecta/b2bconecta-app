import {inferMap} from './core.js';
import {inferInventoryFields} from './inventory.js';

function findHeader(rows) {
  const first = rows.findIndex(row => row.some(value => String(value).trim()));
  let candidate = first;
  let bestScore = 0;
  for (const [index, row] of rows.slice(0, 100).entries()) {
    const {sku, name} = inferMap(row);
    const {price, stock} = inferInventoryFields(row);
    if (sku === '' && name === '') continue;
    const score = new Set([sku, name, price, stock].filter(value => value !== '')).size;
    if (score < 2 || score <= bestScore) continue;
    candidate = index;
    bestScore = score;
    if (score === 4) break;
  }
  return candidate;
}

function readLegacy(bytes) {
  return new Promise((resolve, reject) => {
    const worker = new Worker(new URL('./xls.worker.js', import.meta.url), {type:'module'});
    const finish = (error, result) => {
      clearTimeout(timer);
      worker.terminate();
      if (error) reject(Error(error));
      else resolve(result);
    };
    const timer = setTimeout(() => finish('La lectura del XLS excedió el tiempo. Divide el archivo.'), 45000);
    worker.onmessage = ({data}) => finish(data.error, data);
    worker.onerror = () => finish('No se pudo leer el XLS.');
    const copy = bytes.slice();
    worker.postMessage(copy.buffer, [copy.buffer]);
  });
}

export async function read(bytes, name, progress) {
  try {
    if (bytes.length > 100 * 1024 * 1024) throw Error('El archivo supera 100 MiB. Divide el catálogo.');
    const pdf = /\.pdf$/i.test(name);
    const file = pdf ? new File([bytes], name) : null;
    const result = pdf
      ? await (await import('./pdf-catalog.js')).readPdfCatalog(file, progress)
      : await readLegacy(bytes);

    return {
      notes: result.notes ?? [],
      sheets: await Promise.all(result.sheets.filter(sheet => sheet.rows.some(
        row => row.some(value => String(value).trim())
      )).map(async sheet => {
        const header = sheet.header ?? findHeader(sheet.rows);
        const photos = [];
        const notes = [];
        for (const photo of sheet.photos ?? []) {
          const row = photo.anchorRow ?? photo.row ?? null;
          if (!pdf && row != null && row <= header + 1) continue;
          if (photo.file.size > 10 * 1024 * 1024) {
            notes.push(photo.file.name + ': imagen de más de 10 MiB.');
            continue;
          }
          photos.push({
            name: photo.file.name,
            bytes: new Uint8Array(await photo.file.arrayBuffer()),
            row,
            singleRow: pdf ? row != null : photo.row != null,
          });
        }
        const rows = sheet.rows.slice(header).map(row => row.map(value => '"' + String(value).replaceAll('"','""').replace(/[\r\n]+/g,' ') + '"').join(','));
        return {name: sheet.name, csv: rows.join('\n'), photos, notes, headerOffset: header};
      })),
      error: null,
    };
  } catch (e) {
    return {error:e.message || 'No se pudo leer este documento.'};
  }
}
export async function preparePhoto(bytes) { return (await import('./photo.js')).segment(bytes); }

export async function readPhotoQrs(bytes) {
  return (await import('./qr-photo.js')).readPhotoQrs(bytes);
}
