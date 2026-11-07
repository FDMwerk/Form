import fs from 'node:fs/promises';import path from 'node:path';import {createHash} from 'node:crypto';
const manifest=JSON.parse(await fs.readFile('vendor-source-manifest.json','utf8'));
await fs.mkdir('vendor-source',{recursive:true});
for(const item of manifest.archives){const target=path.join('vendor-source',item.file);let bytes;try{bytes=await fs.readFile(target)}catch{}
 if(!bytes){console.log('Downloading exact source '+item.file);const response=await fetch(item.url,{signal:AbortSignal.timeout(120000)});if(!response.ok)throw Error(`${item.file}: HTTP ${response.status}`);bytes=Buffer.from(await response.arrayBuffer())}
 const digest=createHash('sha256').update(bytes).digest('hex');if(digest!==item.sha256||bytes.length!==item.bytes)throw Error(`Source verification failed for ${item.file}; refusing to accept changed archive`);
 await fs.writeFile(target,bytes);console.log('Verified '+item.file+' '+digest);
}
await fs.copyFile('vendor-source-manifest.json','vendor-source/manifest.json');
