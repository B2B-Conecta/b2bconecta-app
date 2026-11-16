import {getDocument,GlobalWorkerOptions,OPS,Util,PasswordResponses} from 'pdfjs-dist';
import workerUrl from 'pdfjs-dist/build/pdf.worker.min.mjs?url';
import {pdfTable,pdfPhotoRows,pdfPhotoLabels} from './pdf-layout.js';
import {LIMITS} from './core.js';

GlobalWorkerOptions.workerSrc=workerUrl;
const MAX_PAGES=100;

function textWords(items,viewport){
  return items.flatMap(item=>{
    if(!item.str?.trim())return [];
    const t=Util.transform(viewport.transform,item.transform),h=Math.hypot(t[2],t[3]);
    return [{text:item.str.trim(),x:t[4],y:t[5],w:item.width,h}];
  });
}

function imageBoxes(ops,viewport){
  let matrix=viewport.transform;
  const stack=[], boxes=[];
  function add(transform){
    const points=[[0,0],[1,0],[0,1],[1,1]].map(point=>{Util.applyTransform(point,transform);return point;});
    const xs=points.map(p=>p[0]),ys=points.map(p=>p[1]);
    const x=Math.max(0,Math.min(...xs)),y=Math.max(0,Math.min(...ys));
    const w=Math.min(viewport.width,Math.max(...xs))-x,h=Math.min(viewport.height,Math.max(...ys))-y;
    if(Math.min(w,h)<15||w*h>viewport.width*viewport.height*.78)return;
    if(!boxes.some(box=>Math.abs(box.x-x)+Math.abs(box.y-y)+Math.abs(box.w-w)+Math.abs(box.h-h)<4))boxes.push({x,y,w,h});
  }
  for(const [index,op] of ops.fnArray.entries()){
    const args=ops.argsArray[index];
    if(op===OPS.save)stack.push(matrix);
    if(op===OPS.restore)matrix=stack.pop()??viewport.transform;
    if(op===OPS.transform)matrix=Util.transform(matrix,args);
    if(op===OPS.paintFormXObjectBegin){stack.push(matrix);if(args[0])matrix=Util.transform(matrix,args[0]);}
    if(op===OPS.paintFormXObjectEnd)matrix=stack.pop()??viewport.transform;
    if(op===OPS.paintImageXObject||op===OPS.paintInlineImageXObject)add(matrix);
    if(op===OPS.paintImageXObjectRepeat){
      const [,sx,sy,positions]=args;
      for(let i=0;i<positions.length;i+=2)add(Util.transform(matrix,[sx,0,0,sy,positions[i],positions[i+1]]));
    }
  }
  return boxes;
}

async function renderPage(page,viewport,scale){
  const canvas=document.createElement('canvas');
  canvas.width=Math.ceil(viewport.width*scale);canvas.height=Math.ceil(viewport.height*scale);
  const context=canvas.getContext('2d',{alpha:false});
  await page.render({canvasContext:context,viewport:page.getViewport({scale}),annotationMode:0}).promise;
  return canvas;
}
function tsvWords(tsv,scale){
  return (tsv??'').split('\n').slice(1).flatMap(line=>{
    const cells=line.split('\t');
    if(cells[0]!=='5'||!cells[11]?.trim())return [];
    const [x,y,w,h]=cells.slice(6,10).map(value=>Number(value)/scale);
    return [{text:cells[11].trim(),x,y:y+h,w,h}];
  });
}
async function imageFile(canvas,box,scale,name){
  const crop=document.createElement('canvas');
  crop.width=Math.max(1,Math.round(box.w*scale));crop.height=Math.max(1,Math.round(box.h*scale));
  crop.getContext('2d').drawImage(canvas,box.x*scale,box.y*scale,box.w*scale,box.h*scale,0,0,crop.width,crop.height);
  const blob=await new Promise(resolve=>crop.toBlob(resolve,'image/jpeg',.92));
  crop.width=crop.height=0;
  if(!blob)throw Error('No se pudo extraer una foto del PDF.');
  return new File([blob],name,{type:'image/jpeg'});
}

async function readPdfPages(file,onProgress,readPage){
  if(file.size>LIMITS.inventoryBytes)throw Error('El PDF supera 100 MiB. Divide el documento en lotes.');
  const task=getDocument({
    data:await file.arrayBuffer(),isEvalSupported:false,useWasm:false,
    maxImageSize:LIMITS.pixels,stopAtErrors:true,enableXfa:false
  });
  try{
    const document=await task.promise;
    if(document.numPages>MAX_PAGES)throw Error('Divide el PDF en archivos de hasta 100 páginas.');
    for(let number=1;number<=document.numPages;number++){
      onProgress(`Leyendo PDF · página ${number} de ${document.numPages}.`);
      const page=await document.getPage(number),viewport=page.getViewport({scale:1});
      const scale=Math.min(3,2000/Math.max(viewport.width,viewport.height));
      try{await readPage(page,viewport,scale,number,document.numPages);}
      finally{page.cleanup();}
    }
  }catch(error){
    if(error.name==='PasswordException'&&[PasswordResponses.NEED_PASSWORD,PasswordResponses.INCORRECT_PASSWORD].includes(error.code))throw Error('Quita la contraseña del PDF y vuelve a intentarlo.');
    throw error;
  }finally{
    await task.destroy();
  }
}

function pdfPhotoExtractor(){
  let count=0,bytes=0;
  return async (page,viewport,scale,boxes,name)=>{
    if(!boxes.length)return [];
    if(count+boxes.length>LIMITS.photos)throw Error('El PDF contiene más de 1.500 imágenes. Divide el documento.');
    const canvas=await renderPage(page,viewport,scale),files=[];
    try{
      for(const [index,box] of boxes.entries()){
        const file=await imageFile(canvas,box,scale,name(index,++count));
        bytes+=file.size;
        if(bytes>LIMITS.inventoryImageBytes)throw Error(`Las fotos extraídas del PDF superan ${LIMITS.inventoryImageBytes/1024**2} MiB. Divide el documento en lotes.`);
        files.push(file);
      }
      return files;
    }finally{
      canvas.width=canvas.height=0;
    }
  };
}

export async function readPdfPhotos(file,onProgress=()=>{}){
  const extract=pdfPhotoExtractor(),photos=[];
  const name=file.name.replace(/\.pdf$/i,'');
  let skipped=0;
  await readPdfPages(file,onProgress,async(page,viewport,scale,number)=>{
    const boxes=imageBoxes(await page.getOperatorList(),viewport);
    if(!boxes.length){skipped++;return;}
    const labels=pdfPhotoLabels(boxes,textWords((await page.getTextContent()).items,viewport));
    const crops=await extract(page,viewport,scale,boxes,index=>`pdf-${name}-pag-${number}-foto-${index+1}.jpg`);
    for(const [index,file] of crops.entries())photos.push({file,label:labels[index]});
  });
  if(!photos.length)throw Error('No se encontraron fotos separables en el PDF. Si las páginas son una sola imagen, recorta las fotos y adjúntalas como JPG o PNG.');
  return {photos,skipped};
}

export async function readPdfCatalog(file,onProgress=()=>{}){
  const sheets=new Map(),notes=[],extract=pdfPhotoExtractor();
  let ocr,previous,scanned=0,skipped=0;
  try{
    await readPdfPages(file,onProgress,async(page,viewport,scale,number,total)=>{
      const content=await page.getTextContent();
      let words=textWords(content.items,viewport);
      const isScan=!words.length;
      if(isScan){
        scanned++;
        onProgress(`Reconociendo texto del escaneo · página ${number} de ${total}.`);
        if(!ocr){
          const {createWorker}=await import('tesseract.js');
          const ocrRoot=new URL(/* @vite-ignore */ '../ocr/',import.meta.url);
          ocr=await createWorker('eng',1,{
            workerPath:new URL('worker.min.js',ocrRoot).href,
            corePath:new URL('core',ocrRoot).href,
            langPath:ocrRoot.href,workerBlobURL:false,
          });
          await ocr.setParameters({tessedit_pageseg_mode:'6'});
        }
        const canvas=await renderPage(page,viewport,scale);
        try{
          const {data}=await ocr.recognize(canvas,{}, {text:false,tsv:true});
          words=tsvWords(data.tsv,scale);
        }finally{
          canvas.width=canvas.height=0;
        }
      }
      const table=pdfTable(words,previous,viewport.height);
      if(!table?.records.length){skipped++;return;}
      previous=table.header;
      let sheet=sheets.get(table.key);
      if(!sheet){
        sheet={name:`PDF · tabla ${sheets.size+1}`,header:0,rows:[table.header.headers],photos:[]};
        sheets.set(table.key,sheet);
      }
      const offset=sheet.rows.length;
      if(offset+table.records.length>LIMITS.rows+1)throw Error('El inventario supera 15.000 productos.');
      sheet.rows.push(...table.records.map(row=>row.values));
      if(isScan)return;
      const boxes=imageBoxes(await page.getOperatorList(),viewport);
      const rows=pdfPhotoRows(boxes,table.records,table.photoColumn);
      const files=await extract(page,viewport,scale,boxes,(_,index)=>`pdf-imagen-${index}.jpg`);
      for(const [index,file] of files.entries()){
        const row=rows[index];
        sheet.photos.push({row:row===null?null:offset+row+1,file});
      }
    });
    if(!sheets.size)throw Error('No se encontró una tabla reconocible en el PDF. Comprueba que tenga encabezados de producto y datos en columnas, o usa Excel o CSV.');
    if(scanned)notes.push(`${scanned} página(s) procesada(s) con OCR. Verifica SKU, precios y cantidades. Las imágenes en páginas escaneadas se pueden adjuntar manualmente.`);
    if(skipped)notes.push(`${skipped} página(s) sin filas reconocidas. Comprueba que el lote esté completo.`);
    return {sheets:[...sheets.values()],notes};
  }finally{
    await ocr?.terminate();
  }
}
