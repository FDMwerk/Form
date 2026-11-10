import fs from 'node:fs';
import vm from 'node:vm';
import assert from 'node:assert/strict';
import {parseHTML} from 'linkedom';
import {createViewerHarness} from '../scripts/viewer-test-harness.mjs';
const bridge=fs.readFileSync('mobile/native-chrome.js','utf8');
// Reproduce the shipping failure: accessibility mutations continue at display cadence.
// A debounce never reaches 80 ms; a bounded throttle must publish the loaded title anyway.
{
 const {window,document}=parseHTML(fs.readFileSync('Resources/Web/index.html','utf8'));
 let callback,now=0,next=0;const jobs=new Map(),messages=[];
 window.webkit={messageHandlers:{native:{postMessage:value=>messages.push({time:now,value})}}};
 const scheduler={setTimeout:(fn,delay)=>{const id=++next;jobs.set(id,{fn,time:now+delay});return id;},clearTimeout:id=>jobs.delete(id)};
 vm.runInNewContext(bridge,{window,document,Event:window.Event,MutationObserver:class{constructor(fn){callback=fn}observe(){}},...scheduler});
 document.getElementById('filename').textContent='3DBenchy.stl';document.getElementById('empty').hidden=true;
 const runTo=time=>{for(;;){const due=[...jobs].filter(([,job])=>job.time<=time).sort((a,b)=>a[1].time-b[1].time)[0];if(!due)break;now=due[1].time;jobs.delete(due[0]);due[1].fn();}now=time;};
 for(let frame=0;frame<30;frame++){runTo(frame*16);callback([{target:document.getElementById('fit')}]);}
 assert.ok(messages.some(message=>message.time<=96&&message.value.state.title==='3DBenchy.stl'&&message.value.state.hasModels),'native loaded state must publish during uninterrupted mutation frames');
 const before=messages.length;runTo(700);assert.equal(messages.length,before,'unchanged snapshots must be deduplicated');
}
// Exercise the bridge against actual renderer handlers rather than a mirror implementation.
{
 const h=createViewerHarness();h.context.Event=h.domWindow.Event;
 h.evaluate(fs.readFileSync('mobile/sidebar.js','utf8'));h.evaluate(bridge);
 assert.equal(await h.load('tests/fixtures/colored-box.obj','MobileFixture.obj','native-fixture'),true);
 let state=h.window.formNative.snapshot();assert.equal(state.modelCount,1);assert.equal(state.title,'MobileFixture.obj');assert.equal(state.selectedSourceID,'native-fixture');assert.ok(state.sidebar.rows.some(row=>row.name==='MobileFixture'));
 for(const key of ['settings','view','measurement','section','model','appearance','print','display','background','measure','cut','position','explode'])assert.ok(state.panels[key].sections.length,`missing native panel ${key}`);
 assert.equal(h.window.formNative.set('native-display-mode','wireframe'),true);assert.equal(h.read('viewportDisplay.mode'),'wireframe');
 assert.equal(h.window.formNative.set('native-projection','perspective'),true);assert.equal(h.read('viewportCameras.projection'),'perspective');
 assert.equal(h.window.formNative.set('cut-axis','x'),true);assert.equal(h.document.getElementById('cut-axis').value,'x');
 assert.equal(h.window.formNative.set('cut-value',250),true);assert.equal(h.document.getElementById('cut-value').value,'100');
 assert.equal(h.window.formNative.set('native-display-mode','not-a-mode'),false);
 assert.equal(h.window.formNative.set('background-color','javascript:bad'),false);
 assert.equal(h.window.formNative.set('scope-textures',false),true);assert.equal(h.document.getElementById('scope-textures').checked,false);
 h.window.formNative.click('remove');state=h.window.formNative.snapshot();assert.equal(state.hasModels,false);assert.equal(state.modelCount,0);assert.equal(state.controls.info.enabled,false);
}
console.log('Native renderer bridge passed: live-frame starvation regression, atomic import/title/sidebar, all native panel schemas, real display/projection/section/material handlers, validation and unload.');
