import assert from 'node:assert/strict';
import * as T from 'three';
import {parseHTML} from 'linkedom';
import {attachCubeNavigation} from '../cube-navigation.js';
const near=(a,b)=>assert.ok(Math.abs(a-b)<1e-7,`${a} != ${b}`);
const {document,window}=parseHTML('<main><div id="cube"><button data-nav-view="front">Y</button></div></main>'),element=document.querySelector('#cube'),face=element.firstElementChild;
element.getBoundingClientRect=()=>({width:100,height:100});let captured=null;element.setPointerCapture=id=>captured=id;element.hasPointerCapture=id=>captured===id;element.releasePointerCapture=id=>{if(captured===id)captured=null};
// Linkedom does not implement ancestor capture ordering. Route its capture-phase
// callbacks before target dispatch so a real browser's click phase is represented.
const captures=new Map(),add=element.addEventListener.bind(element),remove=element.removeEventListener.bind(element);
element.addEventListener=(type,fn,options)=>{if(options===true){captures.set(type,fn);return}add(type,fn,options)};
element.removeEventListener=(type,fn,options)=>{if(options===true){if(captures.get(type)===fn)captures.delete(type);return}remove(type,fn,options)};
let camera=new T.PerspectiveCamera(40,1,.1,10000);camera.position.set(40,-60,30);camera.up.set(0,0,1);const controls={target:new T.Vector3(10,20,5),enabled:true};camera.lookAt(controls.target);camera.zoom=1.7;camera.updateProjectionMatrix();let changes=0,clicks=0;
const api=attachCubeNavigation({element,THREE:T,getCamera:()=>camera,controls,onChange:()=>changes++});face.addEventListener('click',()=>clicks++);
function fire(type,props={},target=element){const e=new window.Event(type,{bubbles:true,cancelable:true});Object.assign(e,{button:0,pointerId:7,clientX:10,clientY:10,...props});captures.get(type)?.(e);if(!e.defaultPrevented||type!=='click')target.dispatchEvent(e);return e}
const target=controls.target.clone(),projection=camera.projectionMatrix.clone(),start=camera.position.clone(),distance=start.distanceTo(target);
fire('pointerdown',{},face);fire('pointermove',{clientX:12,clientY:12});fire('pointerup');fire('click',{detail:1},face);assert.equal(clicks,1);assert.equal(changes,0);assert.ok(camera.position.equals(start));
console.log('PASS ordinary cube face click and subthreshold pointer jitter retain host view-selection behavior');
fire('pointerdown',{},face);fire('pointermove',{clientX:35});assert.equal(controls.enabled,false);assert.equal(captured,7);near(camera.position.distanceTo(target),distance);assert.ok(controls.target.equals(target));assert.ok(camera.up.equals(new T.Vector3(0,0,1)));assert.equal(camera.zoom,1.7);assert.ok(camera.projectionMatrix.equals(projection));fire('pointerup',{clientX:35});assert.equal(controls.enabled,true);assert.equal(captured,null);const endClick=fire('click',{detail:1},face);assert.equal(endClick.defaultPrevented,true);assert.equal(clicks,1);assert.ok(camera.position.distanceTo(start)>1);
// Full widget-width drag is 360 degrees, with no cumulative orientation drift.
camera.position.copy(start);camera.lookAt(target);fire('pointerdown');fire('pointermove',{clientX:110});fire('pointerup',{clientX:110});assert.ok(camera.position.distanceTo(start)<1e-7);near(camera.position.distanceTo(target),distance);
console.log('PASS captured camera-only orbit preserves target, distance, zoom and projection; drag-end click suppressed; full yaw is 360°');
for(const y of [-100000,100000]){fire('pointerdown');fire('pointermove',{clientY:y});assert.ok(camera.position.toArray().every(Number.isFinite));assert.ok(camera.quaternion.toArray().every(Number.isFinite));const dir=camera.position.clone().sub(target).normalize();assert.ok(Math.abs(dir.z)<1);assert.ok(camera.up.equals(new T.Vector3(0,0,1)));fire('pointerup',{clientY:y})}
console.log('PASS extreme pitch clamps before either pole without flip, NaN or loss of world-Z up');
controls.enabled=false;const before=camera.position.clone(),quaternion=camera.quaternion.clone();fire('pointerdown');fire('pointermove',{clientX:45});fire('keydown',{key:'Escape'},document);assert.equal(controls.enabled,false);assert.ok(camera.position.equals(before));assert.ok(camera.quaternion.equals(quaternion));assert.equal(captured,null);controls.enabled=true;
fire('pointerdown');fire('pointermove',{clientX:45});fire('pointercancel');assert.equal(controls.enabled,true);assert.ok(camera.position.equals(before));
fire('click',{detail:0},face);assert.equal(clicks,2,'Keyboard activation must remain available after cancellation');
console.log('PASS Escape/pointer cancellation restore camera and original controls state; keyboard activation remains accessible');
const ortho=new T.OrthographicCamera(-20,20,20,-20,.1,10000);ortho.position.copy(start);ortho.up.set(0,0,1);ortho.lookAt(target);ortho.zoom=2.3;ortho.updateProjectionMatrix();camera=ortho;const op=camera.projectionMatrix.clone();fire('pointerdown');fire('pointermove',{clientX:30,clientY:20});fire('pointerup');assert.ok(camera.projectionMatrix.equals(op));assert.equal(camera.zoom,2.3);near(camera.position.distanceTo(target),distance);
for(const props of [{button:1},{button:2},{altKey:true},{shiftKey:true},{ctrlKey:true},{metaKey:true},{isPrimary:false}]){const n=changes;fire('pointerdown',props);fire('pointermove',{clientX:80});fire('pointerup');assert.equal(changes,n)}
// A press at the stage edge may leave the stage before reaching drag threshold.
fire('pointerdown',{clientX:99,clientY:50},face);fire('pointermove',{clientX:101,clientY:50},document);fire('pointerup',{clientX:101,clientY:50},document);const outsideStart=changes;
fire('pointerdown',{clientX:99,clientY:50},face);fire('pointermove',{clientX:140,clientY:50},document);assert.ok(changes>outsideStart);assert.equal(captured,7);fire('pointerup',{clientX:140,clientY:50},document);assert.equal(captured,null);assert.equal(controls.enabled,true);
console.log('PASS subthreshold pointer release outside stage and subsequent outside-stage drag recover correctly');
api.dispose();const n=changes;fire('pointerdown');fire('pointermove',{clientX:80});fire('pointerup');assert.equal(changes,n);
console.log('PASS orthographic zoom/projection preserved; secondary/modifier inputs ignored and disposal removes handlers');
