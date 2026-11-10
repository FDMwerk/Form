import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createViewerHarness} from '../scripts/viewer-test-harness.mjs';

// Native controls replace the old browser panels. Verify that the actual renderer
// control store is hidden and every supported editing operation has a native field.
const h=createViewerHarness();h.context.Event=h.domWindow.Event;
h.evaluate(fs.readFileSync('mobile/sidebar.js','utf8'));
h.evaluate(fs.readFileSync('mobile/native-chrome.js','utf8'));
const state=h.window.formNative.snapshot();
const required=['display','background','measure','cut','position','explode','appearance','settings','print','model'];
const byID=new Map();
for(const key of required){
 const panel=state.panels[key];assert.ok(panel?.title&&Array.isArray(panel.sections),`native panel ${key} exists`);
 const seen=new Set();
 for(const section of panel.sections){
  assert.ok(Array.isArray(section.items));
  for(const item of section.items){
   assert.ok(item.id&&typeof item.title==='string',`${key} item has accessible identity and label`);
   assert.ok(['toggle','select','range','number','button','color','note'].includes(item.kind),`native UIKit type: ${item.kind}`);
   assert.equal(typeof item.enabled,'boolean',`${item.id} has explicit availability`);
   assert.equal(seen.has(item.id),false,`duplicate control in ${key}: ${item.id}`);seen.add(item.id);byID.set(item.id,item);
   if(item.kind==='select'){assert.ok(Array.isArray(item.options));for(const option of item.options)assert.ok('value'in option&&typeof option.title==='string');}
  }
 }
}
for(const id of ['language-select','orbit-speed','zoom-speed','reverse-zoom','default-color','show-textures','component-colors','settings-reset','grid','palette','apple','screenshot','measure','dimensions','selection-box-toggle','unit','cut','cut-axis','cut-value','cut-reverse','translate','rotate','explode','explode-value','undo','pos-x','pos-y','pos-z','dock-target','dock-axis','dock','remove','appearance-scope','scope-color','scope-textures','scope-palette','scope-reset','native-measure-action-snap','native-measure-action-finish','native-measure-action-delete'])assert.ok(byID.has(id),`existing feature retained in native panels: ${id}`);
assert.deepEqual(Array.from(byID.get('native-measure-mode').options,o=>o.value),['distance','path','angle']);
assert.equal(byID.get('cut-axis').kind,'select');assert.equal(byID.get('scope-color').kind,'color');assert.equal(byID.get('show-textures').kind,'toggle');

// CSS is only responsible for keeping browser chrome out of the renderer surface;
// native touch sizes, sheets and adaptation belong to the real UIKit UI tests.
const css=fs.readFileSync('mobile/viewport.css','utf8').replace(/\/\*[\s\S]*?\*\//g,'');
const hiddenSelectors=[];
for(const rule of css.matchAll(/([^{}]+)\{([^{}]*)\}/g))if(/display\s*:\s*none\s*!important/.test(rule[2]))for(const selector of rule[1].split(','))if(!selector.trim().startsWith('@'))hiddenSelectors.push(selector.trim());
function isSuppressed(element){for(let node=element;node?.matches;node=node.parentElement)if(hiddenSelectors.some(selector=>node.matches(selector)))return true;return false;}
for(const id of ['parts','inspector','settings-dialog','tools','empty','tool-panels','status','viewport-display-controls','view-navigator'])assert.ok(isSuppressed(h.document.getElementById(id)),`desktop UI must not leak into native app: #${id}`);
for(const id of ['canvas','labels'])assert.equal(isSuppressed(h.document.getElementById(id)),false,`3D surface and model annotations remain visible: ${id}`);
console.log('Native panel contracts passed: all supported editing features, typed descriptors, labels/availability, valid measurement modes and suppression of actual legacy chrome while preserving renderer content.');
