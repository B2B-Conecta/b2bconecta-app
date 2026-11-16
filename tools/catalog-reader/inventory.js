// Extracted from Conecta Fotos (034db65).
import {normalizeHeader} from './core.js';

export const inventoryFields = [
  ['price','precio','Precio USD',['precio usd','precio venta','precio de venta','pvp','precio unitario','precio mayor','precio $','precio us$']],
  ['offer','precio_oferta_usd','Oferta USD',['precio oferta','oferta usd']],
  ['stock','stock','Stock',['existencia','existencias','inventario','stock actual','disponible','cantidad en stock','cantidad disponible']],
  ['minimum','cantidad_minima','Cantidad mínima',['minimo','min','pedido minimo','compra minima','minimo de compra']],
  ['parent','parent_sku','SKU padre',['sku padre','codigo padre']],
  ['attribute','atributo','Atributo',[]],
  ['attributeValue','valor_atributo','Valor del atributo',['valor atributo']],
  ['attributes','atributos','Atributos',[]],
  ['category','categoria','Categoría',['familia','rubro']],
  ['compatibility','compatibilidad','Compatibilidad',['aplicacion','modelos compatibles','aplica a moto','aplica a']],
  ['imageUrl','url_imagen','URL de imagen',['url de la foto','url foto','link imagen','imagen','foto','foto producto','fotografia']],
  ['warranty','garantia','Garantía',[]],
  ['active','activo','Activo',['habilitado','publicado']]
];

const optional = ['offer','parent','attribute','attributeValue','attributes','category','compatibility','imageUrl','warranty','active'];
const optionalHeader = key => optional.includes(key) ? ' (opcional)' : '';
export const inventoryHeaders = ['sku','nombre','descripcion (opcional)',...inventoryFields.map(([key,header])=>header+optionalHeader(key))];

export function inferInventoryFields(headers) {
  const names = headers.map(normalizeHeader);
  return Object.fromEntries(inventoryFields.map(([key,header,,aliases]) => {
    const index = [header.replaceAll('_',' '),...aliases].map(name=>names.indexOf(name)).find(i=>i>=0);
    return [key,index===undefined?'':String(index)];
  }));
}
