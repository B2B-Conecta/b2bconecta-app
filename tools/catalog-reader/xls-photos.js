import {CFB} from 'xlsx';
import {LIMITS} from './core.js';

const DRAWING_GROUP=0x00eb, DRAWING=0x00ec, CONTINUE=0x003c;
const BOUND_SHEET=0x0085, BOF=0x0809, EOF=0x000a, OBJECT=0x005d;
const BLIP_STORE=0xf001, BLIP_ENTRY=0xf007, SHAPE=0xf004;
const CLIENT_ANCHOR=0xf010, SHAPE_PROPERTIES=0xf00b, PICTURE_INDEX=0x0104;
const view=bytes=>new DataView(bytes.buffer,bytes.byteOffset,bytes.byteLength);

function concat(parts){
  const bytes=new Uint8Array(parts.reduce((total,part)=>total+part.length,0));
  let offset=0;
  for(const part of parts){bytes.set(part,offset);offset+=part.length;}
  return bytes;
}

function drawingStreams(bytes){
  const stream=view(bytes), group=[], sheets=new Map(), bounds=[];
  let sheet=null, drawing=null, previous;
  for(let offset=0;offset+4<=bytes.length;){
    const id=stream.getUint16(offset,true), length=stream.getUint16(offset+2,true);
    const end=offset+4+length;
    if(end>bytes.length)throw Error('El XLS contiene un registro incompleto.');
    const record=bytes.subarray(offset+4,end);
    if(id===BOUND_SHEET&&length>=6&&record[5]===0)bounds.push(view(record).getUint32(0,true));
    if(id===BOF&&length>=4&&view(record).getUint16(2,true)===0x10){
      sheet=[];sheets.set(offset,sheet);
    }
    if(id===EOF)sheet=null;
    if(id===DRAWING_GROUP)drawing=group;
    else if(id===DRAWING)drawing=sheet;
    else if(id!==CONTINUE)drawing=null;
    if(id===CONTINUE&&!drawing&&sheet?.length&&previous===OBJECT&&length>=8&&view(record).getUint16(2,true)===SHAPE)drawing=sheet;
    if(drawing)drawing.push(record);
    previous=id;
    offset=end;
  }
  return {group:concat(group),drawings:bounds.map(offset=>concat(sheets.get(offset)??[]))};
}

function* officeArt(bytes,start=0,end=bytes.length){
  const data=view(bytes);
  for(let offset=start;offset+8<=end;){
    const info=data.getUint16(offset,true),type=data.getUint16(offset+2,true);
    const from=offset+8,to=from+data.getUint32(offset+4,true);
    if(to>end)throw Error('El XLS contiene un dibujo incompleto.');
    yield {type,version:info&15,instance:info>>>4,from,to};
    offset=to;
  }
}

function imageFromEntry(bytes,entry){
  const first=entry.from+36;
  if(first>entry.to)return null;
  const start=first+bytes[entry.from+33];
  for(const record of officeArt(bytes,start,entry.to)){
    const extension=record.type===0xf01e?'png':[0xf01d,0xf02a].includes(record.type)?'jpg':null;
    if(!extension)continue;
    // Bitmap BLIPs carry one or two 16-byte UIDs, then one tag byte.
    const signature=extension==='png'?[137,80,78,71,13,10,26,10]:[255,216,255];
    for(const offset of [17,33]){
      const image=bytes.subarray(record.from+offset,record.to);
      if(signature.every((byte,i)=>image[i]===byte))return {image,extension};
    }
  }
  return null;
}

function embeddedImages(group){
  const images=[];
  const root=officeArt(group).next().value;
  if(!root)return images;
  for(const record of officeArt(group,root.from,root.to)){
    if(record.type!==BLIP_STORE)continue;
    for(const entry of officeArt(group,record.from,record.to)){
      images.push(entry.type===BLIP_ENTRY?imageFromEntry(group,entry):null);
    }
  }
  return images;
}

function anchoredPictures(bytes){
  const pictures=[],data=view(bytes);
  function read(start,end,depth){
    if(depth>16)throw Error('El XLS contiene dibujos demasiado anidados.');
    for(const record of officeArt(bytes,start,end)){
      if(record.type!==SHAPE){
        if(record.version===15)read(record.from,record.to,depth+1);
        continue;
      }
      let index,anchor;
      for(const child of officeArt(bytes,record.from,record.to)){
        if(child.type===CLIENT_ANCHOR&&child.to-child.from>=18){
          const at=child.from;
          anchor={column:data.getUint16(at+2,true),row:data.getUint16(at+6,true),
            end:data.getUint16(at+14,true),endOffset:data.getUint16(at+16,true)};
        }
        if(child.type===SHAPE_PROPERTIES){
          for(let i=0;i<child.instance&&child.from+(i+1)*6<=child.to;i++){
            const offset=child.from+i*6;
            if((data.getUint16(offset,true)&0x3fff)===PICTURE_INDEX)index=data.getUint32(offset+2,true);
          }
        }
      }
      if(index)pictures.push({index,anchor});
    }
  }
  read(0,bytes.length,0);
  return pictures;
}

export function legacyWorkbookPhotos(bytes,sheets){
  const compound=CFB.read(bytes,{type:'array'});
  const book=CFB.find(compound,'Workbook')??CFB.find(compound,'Book');
  if(!book?.content)throw Error('No se encontró el libro de Excel dentro del XLS.');
  const {group,drawings}=drawingStreams(new Uint8Array(book.content));
  const images=embeddedImages(group);
  let count=0,total=0,unsupported=0;
  for(const [i,sheet] of sheets.entries()){
    const bytes=drawings[i];
    if(!bytes?.length)continue;
    sheet.photos=[];
    for(const {index,anchor} of anchoredPictures(bytes)){
      const item=images[index-1];
      if(!item){unsupported++;continue;}
      const {image,extension}=item;
      total+=image.length;
      if(++count>LIMITS.photos||image.length>LIMITS.photoBytes||total>LIMITS.inventoryImageBytes)throw Error('Las fotos del XLS superan el límite de importación. Divide el inventario en lotes.');
      const valid=anchor&&anchor.row<sheet.rows.length&&
        (anchor.end===anchor.row||anchor.end===anchor.row+1&&anchor.endOffset===0);
      const file=new File([image],`xls-imagen-${count}.${extension}`);
      sheet.photos.push({row:valid?anchor.row+1:null,anchorRow:anchor?anchor.row+1:null,column:anchor?.column,file});
    }
  }
  return unsupported?[`${unsupported} imagen(es) incrustadas usan un formato que el lector XLS no pudo recuperar.`]:[];
}
