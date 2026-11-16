import {inferMap,normalize} from './core.js';
import {inferInventoryFields} from './inventory.js';

function textLines(words) {
  const lines=[];
  for(const word of [...words].sort((a,b)=>a.y-b.y)){
    const line=lines.at(-1);
    if(line&&Math.abs(line.y-word.y)<=Math.max(2,Math.min(word.h,line.h)*.34)){
      line.words.push(word);
    }else lines.push({y:word.y,h:word.h,words:[word]});
  }
  return lines.map(line=>({...line,words:line.words.sort((a,b)=>a.x-b.x)}));
}
const fieldMap=headers=>({...inferMap(headers),...inferInventoryFields(headers)});
const headerKey=headers=>headers.map(normalize).join('|');
const orderLabel=/^(?:n|no|nro|numero|num|item)$/;
const productCode=/^[\p{L}\p{N}_.-]+$/u;
const center=word=>word.x+word.w/2;

function numberedHeader(cells,map,line){
  const order=cells.findIndex(cell=>orderLabel.test(normalize(cell.text).replace(/[^a-z]/g,'')));
  const photo=cells.findIndex(cell=>/^foto(?:grafia)?$|^imagen$/.test(normalize(cell.text)));
  if(order<0||photo<0||map.sku===''||map.name===''||String(order)===map.name)return null;
  const cuts=cells.slice(1).map((cell,i)=>(cell.x+cell.right+cells[i].x+cells[i].right)/4);
  const fields=[
    ['sku',map.sku],['nombre',map.name],['descripcion (opcional)',map.description===map.name?'':map.description],
    ['precio',map.price],['precio_oferta_usd (opcional)',map.offer],['stock',map.stock],
    ['cantidad_minima',map.minimum],['parent_sku',map.parent],['atributo',map.attribute],
    ['valor_atributo',map.attributeValue],['atributos',map.attributes],['categoria',map.category],
    ['compatibilidad',map.compatibility],['url_imagen',String(photo)],['garantia',map.warranty],['activo',map.active]
  ].filter(([,index])=>index!=='');
  for(const [index,cell] of cells.entries()){
    if(/^(?:cantidad|qty|cant\.?)(?:\s|$)/.test(normalize(cell.text))&&
      !fields.some(([,source])=>String(source)===String(index))){
      fields.push([cell.text,String(index)]);
    }
  }
  return {order,photo,cuts,fields,after:line.y+line.h/2};
}

function readNumberedRows(words,layout,{after,previousNumber,pageHeight}){
  const column=x=>layout.cuts.filter(cut=>x>=cut).length;
  const sku=Number(layout.fields[0][1]);
  const skuWords=words.filter(word=>column(center(word))===sku&&productCode.test(word.text));
  const candidates=words.filter(word=>word.y>=after&&column(center(word))===layout.order&&/^\d{1,6}$/.test(word.text))
    .filter(word=>skuWords.some(code=>Math.abs(code.y-word.y)<5))
    .sort((a,b)=>a.y-b.y);
  const runs=[];
  for(const word of candidates){
    const last=runs.at(-1);
    if(last&&Number(word.text)===Number(last.at(-1).text)+1)last.push(word);
    else runs.push([word]);
  }
  const continued=previousNumber!=null?runs.find(run=>Number(run[0].text)===previousNumber+1):null;
  const anchors=continued??runs.sort((a,b)=>b.length-a.length)[0];
  if(!anchors?.length||previousNumber!=null&&!continued&&anchors.length<2)return null;
  const gaps=anchors.slice(1).map((word,i)=>word.y-anchors[i].y).sort((a,b)=>a-b);
  const half=gaps.length?gaps[Math.floor(gaps.length/2)]/2:20;
  const points=[Math.max(after,anchors[0].y-half),
    ...anchors.slice(1).map((word,i)=>(word.y+anchors[i].y)/2),Math.min(pageHeight,anchors.at(-1).y+half)];
  const byRow=Array.from({length:anchors.length},()=>[]);
  const sorted=[...words].sort((a,b)=>a.y-b.y);
  let row=0;
  for(const word of sorted){
    if(word.y<points[0])continue;
    while(row<anchors.length&&word.y>=points[row+1])row++;
    if(row===anchors.length)break;
    byRow[row].push(word);
  }
  const records=byRow.map((rowWords,i)=>{
    const cells=layout.cuts.map(()=>[]);cells.push([]);
    for(const line of textLines(rowWords)){
      for(const word of line.words)cells[column(center(word))].push(word.text);
    }
    return {values:layout.fields.map(([,index])=>cells[Number(index)].join(' ')),
      y:anchors[i].y,h:anchors[i].h,top:points[i],bottom:points[i+1]};
  });
  return {records,last:Number(anchors.at(-1).text)};
}

function readHeader(line){
  const cells=[];
  for(const word of line.words){
    const previous=cells.at(-1);
    if(previous&&word.x-previous.right<=Math.max(5,line.h*.65)){
      previous.text+=' '+word.text;previous.right=word.x+word.w;
    }else cells.push({text:word.text,x:word.x,right:word.x+word.w});
  }
  const headers=cells.map(cell=>cell.text),map=fieldMap(headers);
  const meaningful=['sku','price','stock','minimum','imageUrl','category','description'].some(key=>map[key]!==''&&map[key]!==map.name);
  if(map.name===''||!meaningful)return null;
  const numbered=numberedHeader(cells,map,line);
  return {headers,map,cuts:cells.slice(1).map(cell=>cell.x),numbered};
}

export function pdfTable(words,previous,pageHeight=Infinity){
  const lines=textLines(words);
  let header,first=-1;
  for(const [index,line] of lines.slice(0,25).entries()){
    header=readHeader(line);
    if(header){first=index;break;}
  }
  header??=previous;
  if(!header)return null;
  if(header.numbered){
    const layout=header.numbered;
    const result=readNumberedRows(words,layout,{
      after:first<0?0:layout.after,previousNumber:first<0?header.lastNumber:null,pageHeight
    });
    if(result){
      const headers=layout.fields.map(([name])=>name);
      const photoColumn=[layout.cuts[layout.photo-1]??0,layout.cuts[layout.photo]??Infinity];
      return {header:{...header,headers,lastNumber:result.last},records:result.records,key:headerKey(headers),photoColumn};
    }
    return null;
  }
  const records=[];
  for(const line of lines.slice(first+1)){
    const repeated=readHeader(line);
    if(repeated&&headerKey(repeated.headers)===headerKey(header.headers))continue;
    const values=header.headers.map(()=>'');
    for(const word of line.words){
      const column=header.cuts.filter((cut,index)=>{
        const tolerance=Math.min(8,Math.max(2,word.h*.45));
        if(word.x>=cut)return true;
        if(cut-word.x>tolerance)return false;
        if(index+1===Number(header.map.name)&&index===Number(header.map.sku)&&values[index]){
          return /^[\p{L}\d._/-]+$/u.test(values[index]);
        }
        return true;
      }).length;
      values[column]=values[column]?values[column]+' '+word.text:word.text;
    }
    const name=values[header.map.name],sku=values[header.map.sku];
    if(!name||/^(?:sub)?total(?: general)?$/i.test(name))continue;
    const numeric=['price','stock','minimum','offer'].some(key=>/\d/.test(values[header.map[key]]??''));
    if(!numeric&&!(sku&&/^[\p{L}\d._/-]+$/u.test(sku)))continue;
    records.push({values,y:line.y,h:line.h});
  }
  return {header,records,key:headerKey(header.headers)};
}


export function pdfPhotoLabels(boxes,words){
  // Assign each text fragment to the nearest image it aligns with. Ambiguous fragments stay unused.
  const adjacent=boxes.map(()=>[]);
  for(const word of words){
    const center=word.y-word.h/2;
    const candidates=boxes.flatMap((box,index)=>{
      const gap=Math.max(word.x-box.x-box.w,box.x-word.x-word.w);
      const vertical=Math.abs(center-box.y-box.h/2);
      if(gap<1||gap>155||vertical>Math.max(box.h/2,65))return [];
      return [{index,distance:Math.hypot(gap,vertical)}];
    }).sort((a,b)=>a.distance-b.distance);
    if(candidates.length&&(!candidates[1]||candidates[1].distance-candidates[0].distance>word.h)){
      adjacent[candidates[0].index].push(word);
    }
  }
  return adjacent.map(words=>{
    const lines=textLines(words).map(line=>({
      ...line,x:line.words[0].x,text:line.words.map(word=>word.text).join(' ')
    })).filter(line=>!/^(?:precio(?:\s+de\s+venta)?\b|(?:USD|US\$|\$)\s*\d)/i.test(line.text));
    const [first,second]=lines;
    if(!first)return null;
    const code=first.text.replace(/^(?:sku|c[oó]d(?:igo)?|ref(?:erencia)?)\s*[:.]\s*/i,'');
    const looksLikeCode=/^[\p{L}\p{N}][\p{L}\p{N} ._/-]{0,39}$/u.test(code)&&
      (code!==first.text||!/\s/.test(code)&&(/\d/.test(code)||!!second)||/\d/.test(code)&&!!second&&code.split(/\s+/).length<=3);
    const aligned=second&&Math.abs(second.x-first.x)<=first.h&&second.y-first.y<=first.h*2.8;
    const sku=looksLikeCode&&(aligned||!second)?code:'';
    const text=(sku?lines.slice(1):lines).map(line=>line.text).join(' ').slice(0,500);
    return {sku,text};
  });
}

export function pdfPhotoRows(boxes,records,photoColumn){
  const rows=boxes.map(box=>pdfPhotoRow(box,records,photoColumn));
  if(!photoColumn)return rows;
  const candidates=new Map();
  for(const [index,row] of rows.entries()){
    if(row===null)continue;
    if(!candidates.has(row))candidates.set(row,[]);
    candidates.get(row).push(index);
  }
  for(const indexes of candidates.values()){
    if(indexes.length===1)continue;
    const last=boxes[indexes.at(-1)];
    // Overlaid objects represent one visible photo. Keep other crops available for review.
    const samePhoto=indexes.slice(0,-1).every(index=>{
      const box=boxes[index];
      const width=Math.max(0,Math.min(box.x+box.w,last.x+last.w)-Math.max(box.x,last.x));
      const height=Math.max(0,Math.min(box.y+box.h,last.y+last.h)-Math.max(box.y,last.y));
      return width*height>=.60*Math.min(box.w*box.h,last.w*last.h);
    });
    for(const index of samePhoto?indexes.slice(0,-1):indexes)rows[index]=null;
  }
  return rows;
}

export function pdfPhotoRow(box,records,photoColumn){
  const center=box.y+box.h/2;
  if(photoColumn){
    const x=box.x+box.w/2;
    if(x<photoColumn[0]||x>=photoColumn[1])return null;
    const candidates=records.flatMap((row,i)=>{
      const overlap=Math.max(0,Math.min(box.y+box.h,row.bottom)-Math.max(box.y,row.top));
      return overlap/box.h>=.72?[i]:[];
    });
    return candidates.length===1?candidates[0]:null;
  }
  const sorted=records.map((row,i)=>({i,d:Math.abs(center-row.y+row.h/2)})).sort((a,b)=>a.d-b.d);
  if(!sorted.length||sorted[0].d>Math.max(12,box.h/2))return null;
  if(sorted[1]&&sorted[1].d-sorted[0].d<5)return null;
  return sorted[0].i;
}
