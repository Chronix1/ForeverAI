import {AppError,modelID,validString} from './common.mjs';
export function cleanLabel(value,max=180){return [...String(value||'').replace(/[|;\x00-\x1f\x7f]/g,' ')].slice(0,max).join('');}
export function truncateUTF8(text,maxBytes){let size=0,result='';for(const c of String(text)){const n=Buffer.byteLength(c);if(size+n>maxBytes)break;result+=c;size+=n;}return result;}
export function replyPacket(text,provider='web',model='manual'){
  if(!validString(text,60000)||!text.trim())throw new AppError('invalid_reply');
  const clean=truncateUTF8(text.replace(/\r/g,''),6500);
  const packet=`FGA1;${cleanLabel(provider,30)};${cleanLabel(model,100)}\nT;${encodeURIComponent(clean)}\nEND`;
  if(Buffer.byteLength(packet)>24000)throw new AppError('reply_too_large');
  return {packet,truncated:clean!==text.replace(/\r/g,'')};
}
export function catalogPacket(provider,models){
  const rows=[`FGC1;${cleanLabel(provider,30)}`];let count=0;
  for(const m of models){if(!modelID(m.id))continue;
    const row=`M;${m.id};${encodeURIComponent(cleanLabel(m.name,90))};${m.efforts.join(',')}`;
    if(Buffer.byteLength(rows.join('\n'))+Buffer.byteLength(row)>23000||count>=80)break;
    rows.push(row);count++;
  }if(!count)throw new AppError('empty_catalog');rows.push('END');return {packet:rows.join('\n'),count,total:models.length};
}
export function extractRoute(text){
  // A candidate only: addon performs numeric/map validation and requires user approval.
  const match=String(text).match(/(?:^|\n)(FG[12];[^\n]+\n(?:P;[^\n]+\n){1,100}END)(?=\r?\n|$)/);
  return match&&match[1].length<=24000?match[1]:'';
}

// Structured web lookup results; data only. No executable code or arbitrary map coordinates.
export function searchPacket({query,updatedAt,results}){
  if(!Array.isArray(results)||results.length<1||results.length>40)throw new AppError('invalid_online_results');
  const when=updatedAt&&Number.isFinite(Date.parse(updatedAt))?updatedAt:'unknown';
  const out=[`FGS1;forevercompanion;${when};${encodeURIComponent(cleanLabel(query,180))}`];
  const kinds={dungeon:'D',item:'I',quest:'Q',rare:'R'};
  for(const r of results){
    const code=kinds[r.kind],id=String(r.id??''),target=String(r.target||'');
    if(!code||!/^[-_a-zA-Z0-9]{1,80}$/.test(id)||target&&!/^[a-z0-9-]{1,80}$/.test(target))throw new AppError('invalid_online_result');
    const line=`R;${code};${id};${target||'-'};${encodeURIComponent(cleanLabel(r.name,125))};${encodeURIComponent(cleanLabel(r.detail,210))}`;
    if(Buffer.byteLength(out.join('\n'))+Buffer.byteLength(line)>21000)break;
    out.push(line);
  }
  if(out.length<2)throw new AppError('online_results_too_long');
  out.push('END');return out.join('\n');
}
