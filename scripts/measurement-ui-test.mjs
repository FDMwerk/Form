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

// Sidebar values are data, and must update even when their 3D annotations cannot draw.
const hidden=createViewerHarness();hidden.window.applyViewportSettings({language:'en'});await hidden.load('samples/Montageblock.stl');
hidden.evaluate('measurementTools.setActive(true);measurementTools.setSnap(false);model.updateMatrixWorld(true);for(const x of [0,10])measurementTools.handlePointer({button:0,clientX:400,clientY:300},{object:meshes[0],point:meshes[0].localToWorld(new T.Vector3(x,0,0)),face:{a:0,b:1,c:2}});measurementTools.setActive(false)');
const hiddenLabel=()=>hidden.read('measurementTools.getState().objects[0].label'),hiddenRow=()=>hidden.document.querySelector('.measurement-value').textContent;
hidden.click('.measurement-row [data-measure-action="visibility"]');hidden.evaluate('select(assets[0])');hidden.change('#unit','25.4');assert.equal(hiddenLabel(),'254 mm');assert.equal(hiddenRow(),hiddenLabel(),'User-hidden measurement sidebar value became stale after unit scaling');hidden.click('.measurement-row [data-measure-action="visibility"]');
hidden.evaluate('cutEnabled=true;cutPlane.normal.set(1,0,0);globalThis.clipPoints=measurementTools.getState().objects[0].points.map(a=>a.mesh.localToWorld(a.local.clone()));cutPlane.constant=-(clipPoints[0].x+clipPoints[1].x)/2;measurementTools.update()');assert.equal(hidden.read('measurementTools.getLabels()[0].el.hidden'),true);hidden.evaluate('assets[0].scale.multiplyScalar(2);model.updateMatrixWorld(true);measurementTools.update()');assert.equal(hiddenLabel(),'508 mm');assert.equal(hiddenRow(),hiddenLabel(),'Clipped annotation sidebar value became stale after transform');
await hidden.load('samples/Montageblock.stl');hidden.evaluate('measurementTools.clear();cutEnabled=false;measurementTools.setActive(true);measurementTools.setSnap(false);model.updateMatrixWorld(true);for(const mesh of meshes)measurementTools.handlePointer({button:0,clientX:400,clientY:300},{object:mesh,point:mesh.localToWorld(new T.Vector3()),face:{a:0,b:1,c:2}});measurementTools.setActive(false)');hidden.click('.measurement-row [data-measure-action="visibility"]');hidden.evaluate('select(assets[1])');hidden.change('#pos-x','1000');assert.equal(hiddenRow(),hiddenLabel(),'User-hidden cross-file measurement sidebar value became stale after coordinate change');
console.log('PASS hidden/clipped measurement sidebar remains current through unit scaling, transforms and cross-file coordinate edits');

// Pointermove reports button=-1 in a real browser. It must preview rather than
// accidentally applying the primary-click guard, and it must never commit an anchor.
const hover=createViewerHarness();await hover.load('tests/fixtures/colored-box.obj');hover.click('#measure');hover.evaluate('fit(true);camera.updateMatrixWorld(true)');const hoverCanvas=hover.read('renderer.domElement'),center=hover.read('new T.Box3().setFromObject(assets[0]).getCenter(new T.Vector3()).project(camera)'),hx=(center.x+1)*400,hy=(1-center.y)*300;
function hoverFire(type,props={}){const ev=new hover.domWindow.Event(type,{bubbles:true,cancelable:true});Object.assign(ev,{pointerId:30,button:-1,buttons:0,clientX:hx,clientY:hy,...props});hoverCanvas.dispatchEvent(ev)}
hoverFire('pointermove');hover.frame();assert.ok(hover.read('measurementTools.getState().hover'),'Standard button=-1 hover was rejected');assert.equal(hover.read('measurementTools.getState().pending.length'),0);assert.equal(hover.read('measurementTools.getState().objects.length'),0);
const hoverMarkers=()=>hover.read('(()=>{const result=[];scene.traverse(o=>{if(o.userData.measurementMarker&&isVisible(o))result.push(o)});return result})()');assert.ok(hoverMarkers().length>0);assert.ok(hoverMarkers().every(marker=>marker.userData.pixelRadius>=8));
for(const zoom of [.4,3]){hover.evaluate(`camera.zoom=${zoom};camera.updateProjectionMatrix();measurementTools.update()`);for(const marker of hoverMarkers()){const cam=hover.read('camera'),point=marker.getWorldPosition(new T.Vector3()),up=new T.Vector3().setFromMatrixColumn(cam.matrixWorld,1),worldRadius=marker.getWorldScale(new T.Vector3()).x,a=point.clone().project(cam),b=point.clone().addScaledVector(up,worldRadius).project(cam);assert.ok(Math.abs(Math.abs(b.y-a.y)*300-marker.userData.pixelRadius)<1e-5)}}
hoverFire('pointerleave');assert.equal(hover.read('measurementTools.getState().hover'),null);assert.equal(hoverMarkers().length,0);hover.evaluate('camera.zoom=1;camera.updateProjectionMatrix()');hoverFire('pointermove');hover.frame();assert.ok(hover.read('measurementTools.getState().hover'));hoverFire('pointerdown',{button:0,buttons:1});assert.equal(hover.read('measurementTools.getState().hover'),null);hoverFire('pointermove',{shiftKey:true});hover.frame();assert.equal(hover.read('measurementTools.getState().hover'),null);hoverFire('pointermove',{buttons:1});hover.frame();assert.equal(hover.read('measurementTools.getState().hover'),null);
console.log('PASS actual RAF pointer hover with button=-1 previews larger constant-pixel markers, never commits, and clears on leave/down/navigation');

// Keeping the validated preview through pointerdown permits a nearby edge click
// when the exact pointer ray just misses the surface; stale candidates never commit.
hover.evaluate('measurementTools.cancelPending();measurementTools.setSnap(true);camera.zoom=1;camera.updateProjectionMatrix();model.updateMatrixWorld(true);camera.updateMatrixWorld(true);globalThis.closeVertex=new T.Vector3();globalThis.bestDistance=Infinity;globalThis.position=meshes[0].geometry.attributes.position;for(let i=0;i<position.count;i++){const candidate=meshes[0].localToWorld(new T.Vector3().fromBufferAttribute(position,i));const distance=candidate.distanceTo(camera.position);if(distance<bestDistance){bestDistance=distance;closeVertex.copy(candidate)}}globalThis.closeScreen=closeVertex.clone().project(camera);globalThis.previewEvent={button:-1,buttons:0,clientX:(closeScreen.x+1)*400,clientY:(1-closeScreen.y)*300};measurementTools.previewPointer(previewEvent,{object:meshes[0],point:closeVertex.clone(),face:{a:0,b:1,c:2}})');
assert.equal(hover.read('measurementTools.getState().hover.snap'),'vertex');const previewLocal=hover.read('measurementTools.getState().hover.local.clone()');hover.evaluate('measurementTools.clearHover({preserveCandidate:true})');assert.equal(hover.read('measurementTools.getState().hover'),null);assert.equal(hover.evaluate('measurementTools.handlePointer({...previewEvent,button:0},null)'),true);assert.equal(hover.read('measurementTools.getState().pending.length'),1);assert.ok(hover.read('measurementTools.getState().pending[0].local').equals(previewLocal));
assert.ok(hoverMarkers().length>0);for(const zoom of [.5,2]){hover.evaluate(`camera.zoom=${zoom};camera.updateProjectionMatrix();measurementTools.update()`);for(const marker of hoverMarkers()){assert.ok(marker.userData.pixelRadius>=8);const cam=hover.read('camera'),point=marker.getWorldPosition(new T.Vector3()),up=new T.Vector3().setFromMatrixColumn(cam.matrixWorld,1),a=point.clone().project(cam),b=point.clone().addScaledVector(up,marker.getWorldScale(new T.Vector3()).x).project(cam);assert.ok(Math.abs(Math.abs(b.y-a.y)*300-marker.userData.pixelRadius)<1e-5)}}hover.evaluate('camera.zoom=1;camera.updateProjectionMatrix()');
hover.evaluate('measurementTools.cancelPending();measurementTools.previewPointer(previewEvent,{object:meshes[0],point:closeVertex.clone(),face:{a:0,b:1,c:2}});measurementTools.clearHover()');assert.equal(hover.evaluate('measurementTools.handlePointer({...previewEvent,button:0},null)'),false);assert.equal(hover.read('measurementTools.getState().pending.length'),0);
hover.evaluate('measurementTools.previewPointer(previewEvent,{object:meshes[0],point:closeVertex.clone(),face:{a:0,b:1,c:2}});measurementTools.clearHover({preserveCandidate:true});camera.position.x+=10;camera.updateMatrixWorld(true)');assert.equal(hover.evaluate('measurementTools.handlePointer({...previewEvent,button:0},null)'),false);assert.equal(hover.read('measurementTools.getState().pending.length'),0);
console.log('PASS validated preview anchor commits through pointerdown/nearby surface miss, while cleared or camera-stale candidates cannot create measurements');
