import test from 'node:test';
import assert from 'node:assert/strict';
import {execFileSync} from 'node:child_process';
import {mkdtemp,writeFile,rm} from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
import path from 'node:path';
import os from 'node:os';
import {encodeCells} from '../lib/live-protocol.mjs';

const sample='FAI1;65b2c04200abcdef;12;auto;auto;default;de;'+encodeURIComponent('Wie komme ich nach Sturmwind?')+';'+encodeURIComponent('class=Krieger;level=23');
function bitmap(cells,columns,step){
 const width=Math.ceil(columns*step),height=Math.ceil(Math.ceil(cells.length/columns)*step);
 const rowSize=Math.ceil(width*3/4)*4,bytes=Buffer.alloc(54+rowSize*height);
 bytes.write('BM');bytes.writeUInt32LE(bytes.length,2);bytes.writeUInt32LE(54,10);
 bytes.writeUInt32LE(40,14);bytes.writeInt32LE(width,18);bytes.writeInt32LE(height,22);
 bytes.writeUInt16LE(1,26);bytes.writeUInt16LE(24,28);bytes.writeUInt32LE(rowSize*height,34);
 for(let i=0;i<cells.length;i++){
  const col=i%columns,row=Math.floor(i/columns),v=cells[i];
  for(let y=Math.ceil(row*step);y<Math.ceil((row+1)*step);y++){
   for(let x=Math.ceil(col*step);x<Math.ceil((col+1)*step);x++){
    const offset=54+(height-1-y)*rowSize+x*3;
    bytes[offset]=(v&1)?255:0;bytes[offset+1]=(v&2)?255:0;bytes[offset+2]=(v&4)?255:0;
   }
  }
 }
 return bytes;
}
test('capture decodes old and compact strips under fractional UI scales',{skip:process.platform!=='win32'},async t=>{
 const dir=await mkdtemp(path.join(os.tmpdir(),'fai-capture-'));
 t.after(()=>rm(dir,{recursive:true,force:true}));
 const capture=fileURLToPath(new URL('../lib/capture-foreverai.ps1',import.meta.url));
 const shell=path.join(process.env.SystemRoot||'C:\\Windows','System32','WindowsPowerShell','v1.0','powershell.exe');
 for(const [columns,step] of [[200,4],[200,7.5],[80,2],[80,3.75],[80,7.5]]){
  const file=path.join(dir,`strip-${columns}-${step}.bmp`);
  await writeFile(file,bitmap(encodeCells(sample),columns,step));
  const out=execFileSync(shell,['-NoProfile','-NonInteractive','-ExecutionPolicy','Bypass','-File',capture,'-TestImage',file],{encoding:'utf8',timeout:20000});
  const result=JSON.parse(out.trim());
  assert.equal(result.text,sample,`columns=${columns} scale=${step}`);
  assert.equal(result.id,12);
 }
});
