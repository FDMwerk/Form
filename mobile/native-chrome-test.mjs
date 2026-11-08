import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {parseHTML} from 'linkedom';
const {window,document}=parseHTML(fs.readFileSync('Resources/Web/index.html','utf8'));
let last, example=0;
window.webkit={messageHandlers:{native:{postMessage(message){if(message==='openExample')example++;else last=message;}}}};
const sandbox={window,document,MutationObserver:class{observe(){}},Event:window.Event,setTimeout,clearTimeout};
vm.runInNewContext(fs.readFileSync('mobile/native-chrome.js','utf8'),sandbox);
assert.equal(document.documentElement.dataset.nativeChrome,'true');
// Every original toolbar action remains reachable after web toolbar is replaced.
for(const button of document.querySelectorAll('#tools button')){
 let clicks=0;button.addEventListener('click',()=>clicks++);
 window.formMobileCommand(button.id);
 assert.equal(clicks,1,`Missing native command: ${button.id}`);
}
const unit=document.getElementById('unit');let selectedUnit='1';Object.defineProperty(unit,'value',{get:()=>selectedUnit,set:value=>{selectedUnit=value;}});let changes=0;unit.addEventListener('change',()=>changes++);
window.formMobileCommand('unit:10');assert.equal(unit.value,'10');assert.equal(changes,1);
window.formMobileCommand('unit:INVALID');assert.equal(unit.value,'10');assert.equal(changes,1);
window.formMobileCommand('openExample');assert.equal(example,1);
assert.equal(last.type,'mobileChromeState');assert.equal(last.state.units.length,6);assert.equal(last.state.controls.unit.enabled,true);
assert.ok(last.state.controls['open-with'].label);
assert.ok(last.state.controls.clear);
console.log('Native toolbar command coverage passed for all original tools, units, example and scene state.');
