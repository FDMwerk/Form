import fs from 'node:fs';import vm from 'node:vm';import assert from 'node:assert/strict';import {parseHTML} from 'linkedom';
const {window,document}=parseHTML(fs.readFileSync('Resources/Web/index.html','utf8'));
const list=document.getElementById('parts');list.innerHTML='<div class="scene-row" aria-selected="false"><button class="scene-select">Alle Modelle</button></div><div class="partrow tree-root" data-node-id="root" aria-level="1" aria-selected="true" aria-expanded="false"><button class="tree-toggle"></button><button class="part"><span class="part-name">Benchy</span><small class="file-badge">STL</small></button><button class="visibility" aria-pressed="true"></button></div><div class="partrow" data-node-id="child" aria-level="2"><button class="part"><span class="part-name">Part</span></button><button class="visibility"></button></div>';
let multi=false,expanded=0,removed=0,all=0;
const root=list.querySelector('[data-node-id=root]');root.querySelector('.part').onclick=e=>{multi=!!e.metaKey};root.querySelector('.tree-toggle').onclick=()=>expanded++;
root.querySelector('.visibility').onclick=()=>root.classList.toggle('tree-hidden');document.getElementById('remove').onclick=()=>removed++;list.querySelector('.scene-select').onclick=()=>all++;
class Mouse extends window.Event {constructor(type,options){super(type,options);Object.assign(this,{metaKey:options.metaKey});}}
window.FORM_NATIVE_SIDEBAR=true;
vm.runInNewContext(fs.readFileSync('mobile/sidebar.js','utf8'),{window,document,Event:window.Event,MouseEvent:Mouse});
assert.equal(document.documentElement.dataset.nativeSidebar,'true');
let rows=window.formMobileSidebarSnapshot().rows;assert.equal(rows.length,3);assert.equal(rows[1].badge,'STL');assert.equal(rows[1].selected,true);assert.equal(rows[2].depth,1);
window.formMobileSidebarAction('select','root',true);assert.equal(multi,true);
window.formMobileSidebarAction('visibility','root');assert.equal(window.formMobileSidebarSnapshot().rows[1].visible,false);
window.formMobileSidebarAction('expand','root');assert.equal(expanded,1);
window.formMobileSidebarAction('remove','child');assert.equal(removed,0);
window.formMobileSidebarAction('remove','root');assert.equal(removed,1);assert.equal(multi,false);
window.formMobileSidebarAction('select','all');assert.equal(all,1);
window.formMobileSidebarAction('remove','missing');assert.equal(removed,1);
console.log('Native sidebar bridge passed: hierarchy, badges, multi-selection, visibility, expand, all-model focus and root-only removal.');
