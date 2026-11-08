// Production viewer + real Three geometry; browser layout/GPU/native services substituted.
import assert from 'node:assert/strict';
import * as T from 'three';
import {createViewerHarness} from './viewer-test-harness.mjs';
const h=createViewerHarness(),{read:r,evaluate:e,document:d,click:c}=h;
h.window.applyViewportSettings({language:'en'});
const state=()=>r('measurementTools.getState()');
const near=(a,b)=>assert.ok(Math.abs(a-b)<1e-5,`${a} != ${b}`);
function fire(el,type,props={}){assert.ok(el,`Missing ${type} target`);const ev=new h.domWindow.Event(type,{bubbles:true,cancelable:true});Object.assign(ev,props);el.dispatchEvent(ev);return ev}
function hit(x,y,z,mesh='meshes[0]'){
 h.context.testPoint=new T.Vector3(x,y,z);
 e(`model.updateMatrixWorld(true);camera.updateMatrixWorld(true);globalThis.testMesh=${mesh};globalThis.testWorld=testMesh.localToWorld(testPoint.clone());globalThis.testScreen=testWorld.clone().project(camera);measurementTools.handlePointer({button:0,clientX:(testScreen.x+1)*400,clientY:(1-testScreen.y)*300,detail:1},{object:testMesh,point:testWorld.clone(),face:{a:0,b:1,c:2}})`);
}
function start(mode='distance'){e(`measurementTools.setActive(true,${JSON.stringify(mode)});measurementTools.setSnap(false)`)}
const action=(name,parent=d)=>fire(parent.querySelector(`[data-measure-action="${name}"]`),'click');
function record(mode='distance',mesh='meshes[0]'){start(mode);hit(0,0,0,mesh);hit(10,0,0,mesh);if(mode==='angle')hit(10,10,0,mesh);if(mode==='path'){hit(10,10,0,mesh);action('finish')}return state().objects.at(-1)}
await h.load('samples/Montageblock.stl','First.stl');
assert.equal(state().objects.length,0);assert.equal(state().pending.length,0);assert.equal(r('selectionActive'),false);assert.equal(r('selectionBox.visible'),false);
const line=record();assert.equal(line.mode,'distance');near(line.value,10);assert.equal(state().objects.length,1);assert.equal(state().pending.length,0);
start('path');hit(0,0,0);hit(10,0,0);hit(10,10,0);assert.equal(state().objects.length,1,'Path must wait for explicit Finish');action('finish');const path=state().objects.at(-1);near(path.value,20);assert.equal(path.points.length,3);
const angle=record('angle');near(angle.value,90);assert.equal(angle.points.length,3);
console.log('PASS no default measurement/selection; actual two-point distance, explicit path Finish and three-point 90° angle');

// Exact projected mesh vertex: snap anchor must retain real mesh-local vertex coordinates.
start();e('measurementTools.setSnap(true);globalThis.vertex=new T.Vector3().fromBufferAttribute(meshes[0].geometry.attributes.position,0)');const vertex=r('vertex');hit(vertex.x,vertex.y,vertex.z);assert.equal(state().pending.length,1);assert.equal(state().pending[0].snap,'vertex');assert.ok(state().pending[0].local.distanceTo(vertex)<1e-5);e('measurementTools.cancelPending()');assert.equal(state().pending.length,0);
console.log('PASS projected vertex snapping retains mesh-local anchor and cancel removes only pending geometry');

// Sidebar selection focuses the actual measurement, without altering model selection.
const beforeSelection=r('selected');const focus=d.querySelector(`[data-measure-id="${line.id}"] [data-measure-action="focus"]`);fire(focus,'click');assert.equal(state().selectedID,line.id);assert.equal(r('selected'),beforeSelection);
const row=()=>d.querySelector(`[data-measure-id="${line.id}"]`);action('visibility',row());assert.equal(state().objects.find(o=>o.id===line.id).visible,false);action('visibility',row());assert.equal(state().objects.find(o=>o.id===line.id).visible,true);
const label=d.querySelector(`button[data-measure-id="${line.id}"]`);fire(label,'contextmenu',{clientX:200,clientY:200});const menu=d.querySelector('[data-measure-context]');assert.ok(menu&&!menu.hidden);action('delete',menu);assert.ok(!state().objects.some(o=>o.id===line.id));assert.equal(state().objects.length,2);
e(`measurementTools.select(${JSON.stringify(path.id)})`);h.key('Delete');assert.ok(!state().objects.some(o=>o.id===path.id));assert.equal(state().objects.length,1);
console.log('PASS real sidebar focus/visibility, label context deletion and Delete key affect only the selected measurement');

// Follow asset transforms in world space instead of erasing measurements.
const follow=record();e('measurementTools.setActive(false);select(assets[0])');h.change('#pos-x','250');assert.ok(state().objects.some(o=>o.id===follow.id));near(state().objects.find(o=>o.id===follow.id).value,10);h.change('#unit','25.4');near(state().objects.find(o=>o.id===follow.id).value,254);near(state().objects.find(o=>o.id===angle.id).value,90);
await h.load('samples/Montageblock.stl','Second.stl');assert.ok(state().objects.some(o=>o.id===follow.id),'Appending a file must retain independent measurements');const second=record('distance','meshes[1]');e('removeAsset(assets[0])');assert.equal(state().objects.length,1);assert.equal(state().objects[0].id,second.id);e('removeAsset(assets[0])');assert.equal(state().objects.length,0);assert.equal(state().pending.length,0);
console.log('PASS coordinate/unit transforms update anchored values; append preserves records; removing one asset prunes only its dependent measurements');

// Real canvas pointer handlers must reject navigation modifiers, drags and gizmo drags.
await h.load('samples/Montageblock.stl');c('#measure');e('measurementTools.setSnap(false);fit(true);camera.updateMatrixWorld(true)');const canvas=r('renderer.domElement'),screen=r('new T.Box3().setFromObject(assets[0]).getCenter(new T.Vector3()).project(camera)'),x=(screen.x+1)*400,y=(1-screen.y)*300;
function pointer(props={},drag=0){fire(canvas,'pointerdown',{button:0,clientX:x,clientY:y,...props});fire(canvas,'pointerup',{button:0,clientX:x+drag,clientY:y,...props})}
for(const p of [{button:1},{button:2},{shiftKey:true},{ctrlKey:true},{metaKey:true},{altKey:true}])pointer(p);pointer({},20);assert.equal(state().pending.length,0);assert.equal(state().objects.length,0);pointer();assert.equal(state().pending.length,1);assert.equal(r('selectionActive'),false);e('transform.dragging=true');pointer();assert.equal(state().objects.length,0);e('transform.dragging=false');h.key('Escape');assert.equal(state().pending.length,0);
console.log('PASS actual ray-picked canvas click starts measurement without object selection; navigation, drag and transform events cannot create measurements');

// Keyboard path completion and true double-click completion share the production finish path.
e('measurementTools.clear();measurementTools.cancelPending()');start('path');hit(0,0,0);hit(10,0,0);h.key('Enter');assert.equal(state().objects.length,1);near(state().objects[0].value,10);
start('path');hit(0,0,0);hit(0,10,0);fire(canvas,'dblclick',{button:0,clientX:x,clientY:y});assert.equal(state().objects.length,2);near(state().objects[1].value,10);
start('angle');hit(0,0,0);hit(10,0,0);hit(0,0,0);assert.equal(state().objects.length,2,'Angle with identical first/third endpoint must not become a fake angle');assert.equal(state().pending.length,2);e('measurementTools.cancelPending()');
console.log('PASS Enter and actual double-click finish paths; degenerate three-point angle rejected without creating a bogus record');

// Context picking works on the 3D segment, not just its HTML label.
e('measurementTools.setActive(false);fit(true);measurementTools.update();camera.updateMatrixWorld(true)');
const recordID=state().objects[0].id;
const mid=state().objects[0].points.map(a=>a.mesh.localToWorld(a.local.clone())).reduce((a,b)=>a.add(b),new T.Vector3()).multiplyScalar(.5).project(r('camera'));
fire(canvas,'contextmenu',{clientX:(mid.x+1)*400,clientY:(1-mid.y)*300});assert.equal(state().selectedID,recordID);assert.ok(d.querySelector('[data-measure-context]'));action('delete',d.querySelector('[data-measure-context]'));assert.equal(state().objects.length,1);
const remaining=state().objects[0].id;fire(d.querySelector(`.measurement-row[data-measure-id="${remaining}"]`),'contextmenu',{clientX:50,clientY:50});assert.ok(d.querySelector('[data-measure-context]'));h.key('Escape');assert.equal(d.querySelector('[data-measure-context]'),null);assert.equal(state().objects.length,1,'Escape closes menu without deleting');
// Field editing must never delete the selected measurement.
e(`measurementTools.select(${remaining},{focus:false})`);h.key('Delete',d.querySelector('#pos-x'));assert.equal(state().objects.length,1);
h.key('Backspace');assert.equal(state().objects.length,0);
console.log('PASS actual canvas segment context-picking and sidebar context menu; Escape and editable-field guards; Backspace deletes only selected measurement');

// Integrated cube drag must rotate only the active camera while a point is pending.
e('setMeasuring(true);measurementTools.setMode("distance");measurementTools.setSnap(false);fit(true)');hit(0,0,0);const pendingBefore=state().pending[0].local.clone(),cameraBefore=r('camera.position.clone()'),targetBefore=r('controls.target.clone()'),projectionBefore=r('camera.projectionMatrix.clone()'),selectionBefore=r('[...selectedObjects].map(o=>o.uuid).join(",")'),zoomBefore=r('camera.zoom');
const stage=d.querySelector('.view-cube-stage');fire(stage,'pointerdown',{pointerId:22,button:0,clientX:110,clientY:110});fire(d,'pointermove',{pointerId:22,button:0,clientX:125,clientY:118});fire(d,'pointerup',{pointerId:22,button:0,clientX:125,clientY:118});assert.ok(r('camera.position').distanceTo(cameraBefore)>1e-6);assert.ok(r('controls.target').equals(targetBefore));assert.ok(r('camera.projectionMatrix').equals(projectionBefore));assert.equal(r('camera.zoom'),zoomBefore);assert.equal(r('[...selectedObjects].map(o=>o.uuid).join(",")'),selectionBefore);assert.equal(state().pending.length,1);assert.ok(state().pending[0].local.equals(pendingBefore));assert.equal(state().objects.length,0);assert.equal(r('controls.enabled'),true);
console.log('PASS integrated view-cube drag preserves pending measurement, model selection, camera target, zoom and projection');

// Angle values, labels and sidebar captions follow the chosen locale without changing geometry.
e('measurementTools.cancelPending()');start('angle');hit(0,0,0);hit(10,0,0);hit(5,8,0);const fractionalAngle=state().objects.at(-1);near(fractionalAngle.value,Math.atan2(8,5)*180/Math.PI);h.window.applyViewportSettings({language:'de'});e('measurementTools.update()');assert.equal(state().objects.at(-1).label,'57,99°');assert.equal(r('measurementTools.getLabels().at(-1).el.textContent'),'57,99°');assert.equal(d.querySelector(`.measurement-row[data-measure-id="${fractionalAngle.id}"] .measurement-value`).textContent,'57,99°');h.window.applyViewportSettings({language:'en'});e('measurementTools.update()');assert.equal(state().objects.at(-1).label,'57.99°');near(state().objects.at(-1).value,fractionalAngle.value);
console.log('PASS fractional angle label and sidebar switch comma/point with locale while preserving the actual angle');
