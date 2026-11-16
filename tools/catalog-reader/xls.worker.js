import * as XLSX from 'xlsx';
import {legacyWorkbookPhotos} from './xls-photos.js';

self.onmessage = ({data}) => {
  try {
    const bytes = new Uint8Array(data);
    if (bytes[0] !== 0xd0 || bytes[1] !== 0xcf || bytes[2] !== 0x11 || bytes[3] !== 0xe0) {
      throw Error('Selecciona un archivo Excel XLS de Excel 97–2003.');
    }
    const workbook = XLSX.read(bytes, {type:'array', raw:true, sheetRows:15002, cellText:true});
    const sheets = workbook.SheetNames.map(name => {
      const sheet = workbook.Sheets[name];
      const ref = sheet['!fullref'] || sheet['!ref'];
      const range = ref ? XLSX.utils.decode_range(ref) : null;
      if (range && (range.e.r > 15000 || range.e.c >= 200)) {
        throw Error('Divide el archivo en lotes de hasta 15.000 repuestos y 200 columnas.');
      }
      if (range) range.s = {r:0, c:0};
      return {
        name,
        rows: XLSX.utils.sheet_to_json(sheet,{header:1,raw:false,defval:'',blankrows:true,range:range||undefined}),
      };
    });
    const notes = legacyWorkbookPhotos(bytes, sheets);
    self.postMessage({sheets, notes});
  } catch (e) {
    self.postMessage({error: e.message});
  }
};
