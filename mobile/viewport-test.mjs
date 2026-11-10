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
 // A style injector is allowed to establish the CSS marker before adapter boot.
 document.documentElement.dataset.formMobile='true';
 const bootContext=vm.createContext({window,document,MutationObserver:window.MutationObserver,navigator:{language:'en-US'},matchMedia:()=>({matches:width<=999}),setTimeout});
 vm.runInContext(source,bootContext);
 document.dispatchEvent(new window.Event('DOMContentLoaded'));
 assert.ok(window.formMobileInput,`input tracker boots at ${width}px with existing CSS marker`);
 assert.match(document.querySelector('meta[name=viewport]').content,/viewport-fit=cover/);
 const originalTracker=window.formMobileInput;
 const emit=(type,event)=>{const e=new window.Event(type,{bubbles:true});Object.assign(e,event);canvas.dispatchEvent(e);};
 emit('pointerdown',point(7));emit('pointermove',point(7,45));emit('pointerup',point(7,45));
 await Promise.resolve();assert.equal(window.formMobileInput.isNavigationGesture(point(7)),true,'canvas listeners keep drag through microtasks');
 await tick();assert.equal(window.formMobileInput.isNavigationGesture(point(7)),false);
 vm.runInContext(source,bootContext);assert.equal(window.formMobileInput,originalTracker,'reinjection retains the same tracker, avoiding duplicate handlers');
 const mouseEvent={pointerType:'mouse',pointerId:9,clientX:10,clientY:10};emit('pointerdown',mouseEvent);emit('pointermove',{...mouseEvent,clientX:100});assert.equal(window.formMobileInput.isNavigationGesture(mouseEvent),false,'mouse modifiers remain owned by original viewport controls');
 emit('pointerdown',point(10));emit('pointermove',point(10,60));window.dispatchEvent(new window.Event('blur'));assert.equal(window.formMobileInput.isNavigationGesture(point(10)),false,'focus loss clears pending touch navigation');
}
console.log('Mobile touch adapter passed: tap/tremor/drag/pinch, WebKit microtask ordering, actual canvas bootstrap at393/768/1024, reinjection, mouse independence and focus-loss reset. Native layout is verified by hosted UIKit tests.');
