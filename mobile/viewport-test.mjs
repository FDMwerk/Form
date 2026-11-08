import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';
import {parseHTML} from 'linkedom';
const source=fs.readFileSync(new URL('./viewport.js',import.meta.url),'utf8');
const tick=()=>new Promise(resolve=>setTimeout(resolve,0));
const context=vm.createContext({setTimeout});
vm.runInContext(source,context);
const tracker=context.FormMobileTouchTracker();
const point=(pointerId,x=10,y=10)=>({pointerType:'touch',pointerId,clientX:x,clientY:y});
tracker.down(point(1)); assert.equal(tracker.isNavigationGesture(point(1)),false,'stationary tap can measure');
tracker.move(point(1,13)); assert.equal(tracker.isNavigationGesture(point(1)),false,'minor tremor is tap');
tracker.move(point(1,30)); assert.equal(tracker.isNavigationGesture(point(1)),true,'orbit drag cannot add point');
tracker.up(point(1)); assert.equal(tracker.isNavigationGesture(point(1)),true,'flag survives pointerup listeners');
await Promise.resolve(); assert.equal(tracker.isNavigationGesture(point(1)),true,'flag survives native microtask checkpoint');
await tick(); assert.equal(tracker.isNavigationGesture(point(1)),false,'completed gesture cleared next task');
tracker.down(point(1)); tracker.down(point(2));
assert.equal(tracker.isNavigationGesture(point(1)),true); assert.equal(tracker.isNavigationGesture(point(2)),true);
tracker.up(point(2)); await tick();
assert.equal(tracker.isNavigationGesture(point(1)),true,'remaining pinch finger cannot create measurement');
tracker.up(point(1)); await tick();
tracker.down(point(3)); assert.equal(tracker.isNavigationGesture(point(3)),false,'new single tap after pinch works');
tracker.reset(); assert.equal(tracker.isNavigationGesture(point(3)),false);

// Bootstrap against the actual shared HTML rather than a duplicate fixture.
const html=fs.readFileSync(new URL('../Resources/Web/index.html',import.meta.url),'utf8');
for(const width of [393,768,1024]) {
 const {window}=parseHTML(html),{document}=window;
 // linkedom's window proxy shares expando globals between documents.
 delete window.formMobileInput;
 const canvas=document.createElement('canvas'); document.querySelector('#canvas').append(canvas);
 // Existing shared viewer handlers, without requiring WebGL in this DOM test.
 document.querySelector('#side').onclick=()=>document.body.classList.toggle('collapsed');
 document.querySelector('#info').onclick=()=>document.body.classList.toggle('inspecting');
 document.querySelector('#settings-close [data-icon]')?.append(document.createElementNS('http://www.w3.org/2000/svg','svg'));
 // A style injector is allowed to establish the CSS marker before adapter boot.
 document.documentElement.dataset.formMobile='true';
 const bootContext=vm.createContext({window,document,MutationObserver:window.MutationObserver,navigator:{language:'en-US'},matchMedia:()=>({matches:width<=999}),setTimeout});
 vm.runInContext(source,bootContext);
 document.dispatchEvent(new window.Event('DOMContentLoaded'));
 assert.ok(window.formMobileInput,`input tracker boots at ${width}px with existing CSS marker`);
 assert.equal(document.querySelectorAll('.mobile-panel-close').length,2);
 assert.equal(document.querySelectorAll('#mobile-panel-backdrop').length,1);
 assert.match(document.querySelector('meta[name=viewport]').content,/viewport-fit=cover/);
 assert.equal(document.body.classList.contains('collapsed'),width<=999,'phone/tablet overlay initial state');
 const emit=(type,event)=>{const e=new window.Event(type,{bubbles:true});Object.assign(e,event);canvas.dispatchEvent(e);};
 emit('pointerdown',point(7));emit('pointermove',point(7,45));emit('pointerup',point(7,45));
 await Promise.resolve();assert.equal(window.formMobileInput.isNavigationGesture(point(7)),true,'canvas listeners keep drag through microtasks');
 await tick();assert.equal(window.formMobileInput.isNavigationGesture(point(7)),false);
 document.querySelector('#side').click();
 if(width<=999)assert.equal(document.body.classList.contains('collapsed'),false,'sidebar opens');
 document.querySelector('#info').click();
 assert.equal(document.body.classList.contains('inspecting'),true,'info opens');
 if(width<=999)assert.equal(document.body.classList.contains('collapsed'),true,'opening info closes overlay sidebar');
 document.querySelector('#inspector .mobile-panel-close').click();
 assert.equal(document.body.classList.contains('inspecting'),false,'info close works');
 vm.runInContext(source,bootContext);assert.equal(document.querySelectorAll('#mobile-panel-backdrop').length,1,'reinjection remains idempotent');
}
const css=fs.readFileSync(new URL('./viewport.css',import.meta.url),'utf8');
assert.match(css,/#tools\s*\{[^}]*max-width:calc\(100%[^}]*overflow-x:auto/,'toolbar viewport constrained and scrollable');
assert.match(css,/#measurement-toolbar\s*\{[^}]*flex-wrap:nowrap[^}]*overflow-x:auto/,'measurement row scrolls within viewport');
console.log('Mobile interaction/bootstrap checks passed: tap, drag, pinch, WebKit microtask boundary, actual shared DOM at 393/768/1024 widths, panels, idempotence and constrained toolbar CSS. Layout dimensions still require simulator visual verification.');
