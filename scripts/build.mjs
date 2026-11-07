import './locales.mjs';
import fs from 'node:fs';import {build} from 'esbuild';
fs.mkdirSync('Resources/Web/licenses',{recursive:true});fs.copyFileSync('node_modules/occt-import-js/dist/occt-import-js.js','Resources/Web/occt.js');fs.writeFileSync('Resources/Web/wasm.js','window.WASM='+JSON.stringify(fs.readFileSync('node_modules/occt-import-js/dist/occt-import-js.wasm').toString('base64'))+';');for(const name of ['license.occt-import-js.txt','license.occt.txt'])fs.copyFileSync('node_modules/occt-import-js/dist/'+name,'Resources/Web/licenses/'+name);for(const name of ['three','lucide'])fs.copyFileSync('node_modules/'+name+'/LICENSE','Resources/Web/licenses/'+name+'.txt');await build({entryPoints:['viewer.js'],bundle:true,format:'iife',outfile:'Resources/Web/viewer.js',minify:true,legalComments:'eof'});

if(fs.existsSync('Resources/Web/apple.glb'))fs.writeFileSync('Resources/Web/apple.js','window.APPLE='+JSON.stringify(fs.readFileSync('Resources/Web/apple.glb').toString('base64'))+';');
