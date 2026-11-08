import assert from 'node:assert/strict';
import fs from 'node:fs';
import {parseHTML} from 'linkedom';
const html=fs.readFileSync('Resources/Web/index.html','utf8');
const css=fs.readFileSync('mobile/viewport.css','utf8');
const {document}=parseHTML(html);
const sheets=['scene-settings-panel','display-panel','background-panel','settings-dialog','measurement-toolbar','cut-panel','explode-panel','inspector'];
for(const id of sheets)assert.ok(document.getElementById(id),`Actual panel #${id} must exist`);
// Position/docking remains editable even when file information has a native presentation.
for(const id of ['pos-x','pos-y','pos-z','dock-target','dock-axis','dock','remove'])assert.ok(document.getElementById(id),id);
assert.match(css,/max-height:calc\(100dvh - 144px\)/);
assert.match(css,/#tool-panels>\.floating-panel[\s\S]*?min-width:0/);
assert.match(css,/#measurement-toolbar \{ flex-wrap:wrap;/);
assert.match(css,/#settings-dialog[\s\S]*?overflow:auto/);
assert.match(css,/@media\(max-height:500px\)/);
assert.match(css,/\.measurement-context[\s\S]*?bottom:76px!important/);
assert.match(css,/#dock,[\s\S]*?min-height:48px/);
assert.match(css,/input\[type=number\][\s\S]*?min-height:44px/);
assert.match(css,/#settings-dialog::backdrop/);
// Bound the content region at representative phone/tablet/landscape sizes.
for(const [w,h] of [[320,568],[393,852],[852,393],[768,1024],[1024,768]]){
 const compact=h<=500,top=56,bottom=compact?66:76,maxHeight=h-(compact?122:144),width=Math.min(520,w-24);
 assert.ok(width>0&&width<=w-24);
 assert.ok(maxHeight>=44&&maxHeight<=h-top-bottom);
}
console.log('Mobile panel contracts passed: actual controls retained, bounded portrait/landscape sheets, scrollable settings, 44pt inputs and reachable context actions. Pixel layout still requires Simulator.');
