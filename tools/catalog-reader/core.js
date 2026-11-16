// Extracted from Conecta Fotos (034db65).
export const LIMITS = { inventoryBytes: 100 * 1024 * 1024, inventoryImageBytes: 100 * 1024 * 1024, photos: 1500, photoBytes: 25 * 1024 * 1024, totalBytes: 350 * 1024 * 1024, rows: 15000, pixels: 40_000_000 };
export const normalize = value => String(value ?? '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().trim();
export const normalizeHeader = value => normalize(value).trim().replace(/\s*\(opcional\)$/, '').replaceAll('_',' ').replace(/\s+/g,' ').trim();

export function inferMap(headers) {
  const aliases = { sku: ['sku', 'codigo', 'codigo producto', 'codigo del producto', 'referencia', 'ref', 'id producto', 'cod'], code: ['cod', 'cod.', 'codigo auxiliar'], name: ['nombre del producto', 'nombre', 'producto', 'descripcion corta', 'descripcion del producto', 'descripcion producto', 'descripcion', 'nombre producto', 'articulo', 'item', 'titulo', 'denominacion', 'material'], gtin: ['ean', 'gtin', 'upc', 'codigo de barras', 'ean/upc/gtin'], brand: ['marca', 'brand'], model: ['modelo', 'referencia', 'referencia fabricante'], description: ['descripcion', 'description'] };
  const normalized=headers.map(normalizeHeader);
  const basic=Object.fromEntries(Object.entries(aliases).map(([key,names])=>{
    const i=names.map(name=>normalized.indexOf(name)).find(index=>index>=0);
    return [key,i==null?'':String(i)];
  }));
  if(basic.code===basic.sku)basic.code='';
  return basic;
}
