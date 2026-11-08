// Runs the actual viewer and DOM handlers with real Three.js geometry/cameras.
// Renderer/native services are substituted by the shared production-source harness.
import assert from 'node:assert/strict';
import * as T from 'three';
import {createViewerHarness} from './viewer-test-harness.mjs';
const close=(actual,expected,epsilon=1e-4)=>assert.ok(Math.abs(actual-expected)<=epsilon+Math.abs(expected)*1e-7,`${actual} != ${expected}`);
const isVisible=object=>{for(let p=object;p;p=p.parent)if(!p.visible)return false;return true};
function expectedBounds(objects){
 const box=new T.Box3(),point=new T.Vector3();
 for(const root of objects){root.updateWorldMatrix(true,true);root.traverse(mesh=>{if(!mesh.isMesh||mesh.userData.formHelper||!isVisible(mesh))return;const position=mesh.geometry.attributes.position;for(let i=0;i<position.count;i++)box.expandByPoint(point.fromBufferAttribute(position,i).applyMatrix4(mesh.matrixWorld))})}
 return box;
}
function equalBoxes(actual,expected){assert.equal(actual.isEmpty(),expected.isEmpty());if(expected.isEmpty())return;for(const axis of ['x','y','z']){close(actual.min[axis],expected.min[axis]);close(actual.max[axis],expected.max[axis])}}
const ids=h=>h.read('[...selectedObjects].map(object=>object.uuid).sort().join(",")');
const select=(h,expression,options='{}')=>h.evaluate(`select(${expression},${options})`);
const row=(h,object)=>h.document.querySelector(`[data-node-id="${object.uuid}"]`);
function fire(h,element,type,properties={}){const event=new h.domWindow.Event(type,{bubbles:true,cancelable:true});Object.assign(event,properties);element.dispatchEvent(event)}
function treeClick(h,object,properties={}){const button=row(h,object)?.querySelector('.part');assert.ok(button,'Missing actual tree row');fire(h,button,'click',properties)}
const dimensionLengths=h=>h.read('dimObjects.map(object=>new T.Vector3().fromBufferAttribute(object.geometry.attributes.position,0).distanceTo(new T.Vector3().fromBufferAttribute(object.geometry.attributes.position,1))).sort((a,b)=>a-b)');
function dimensionsMatch(h,box){const expected=box.getSize(new T.Vector3()).toArray().sort((a,b)=>a-b),actual=dimensionLengths(h);assert.equal(actual.length,3);for(let i=0;i<3;i++)close(actual[i],expected[i]);assert.equal(h.read('labels.filter(label=>label.kind==="dim").length'),3)}
const info=h=>Object.fromEntries([...h.document.querySelectorAll('#file-info .info-row')].map(element=>[element.children[0].textContent,element.children[1].textContent]));

const h=createViewerHarness();h.window.applyViewportSettings({language:'en'});
assert.equal(h.read('selectionBox.visible'),false,'Empty viewer must not draw an invalid selection box');
await h.load('samples/Montageblock.stl','First.stl','first-source');assert.equal(h.read('selectionActive'),false);assert.equal(h.read('selectionBox.visible'),false,'Import metadata focus must not draw a user selection box');
await h.load('tests/fixtures/colored-box.obj','Second.obj','second-source');assert.equal(h.read('selectionActive'),false);assert.equal(h.read('selectionBox.visible'),false,'Second import must not activate selection decoration');
await h.load('samples/Montageblock.stl','Third.stl','third-source');assert.equal(h.read('selectionActive'),false);assert.equal(h.read('selectionBox.visible'),false,'Later import must remain visually unselected until user action');
const assets=h.read('assets');
select(h,'assets[0]');assert.equal(h.read('selectionActive'),true);assert.equal(h.read('selectedObjects.size'),1);assert.equal(h.read('selected'),assets[0]);assert.equal(h.window.selectedSourceID(),'first-source');assert.equal(h.read('selectionBox.visible'),true);equalBoxes(h.read('selectionBox.box'),expectedBounds([assets[0]]));
h.click('#dimensions');dimensionsMatch(h,expectedBounds([assets[0]]));assert.ok(h.read('labels.filter(label=>label.kind==="dim").every(label=>label.el.textContent.endsWith(" mm"))'));
assert.ok(h.read('labels.some(label=>label.kind==="dim"&&label.el.textContent==="80 mm")'));
console.log('PASS single selection: visible exact world box, source identity and actual 80×55×24mm dimension geometry/labels');

treeClick(h,assets[1],{metaKey:true});assert.equal(h.read('selectedObjects.size'),2);equalBoxes(h.read('selectionBounds()'),expectedBounds([assets[0],assets[1]]));equalBoxes(h.read('selectionBox.box'),expectedBounds([assets[0],assets[1]]));dimensionsMatch(h,expectedBounds([assets[0],assets[1]]));assert.equal(h.window.selectedSourceID(),null);
for(const selector of ['#translate','#rotate','#unit','#open-with','#remove'])assert.equal(h.document.querySelector(selector).disabled,true,`${selector} must not act unexpectedly on primary-only while multiple items are selected`);
assert.equal(h.document.querySelector('#fit').disabled,false);
treeClick(h,assets[0],{ctrlKey:true});assert.equal(h.read('selectedObjects.size'),1);assert.ok(h.read('selectedObjects.has(assets[1])'));assert.equal(h.window.selectedSourceID(),'second-source');
treeClick(h,assets[1],{metaKey:true});assert.equal(h.read('selectedObjects.size'),0);assert.equal(h.read('selected'),null);assert.equal(h.read('selectionActive'),true);assert.equal(h.read('selectionBox.visible'),true,'All-models state draws a visible scene box');equalBoxes(h.read('selectionBox.box'),expectedBounds(assets));
treeClick(h,assets[0]);treeClick(h,assets[2],{shiftKey:true});assert.equal(h.read('selectedObjects.size'),3);for(const asset of assets)assert.equal(row(h,asset).getAttribute('aria-selected'),'true');
console.log('PASS actual sidebar Cmd/Ctrl toggles and Shift range; multi-operation safety, row ARIA and All-models scene box');

h.click('.scene-select');assert.equal(h.read('selectedObjects.size'),0);assert.equal(h.read('selected'),null);equalBoxes(h.read('selectionBounds()'),expectedBounds(assets));dimensionsMatch(h,expectedBounds(assets));
select(h,'assets[0]');h.change('#pos-x','-125');equalBoxes(h.read('selectionBox.box'),expectedBounds([assets[0]]));close(h.read('selectionBox.box.getCenter(new T.Vector3()).x'),-125);dimensionsMatch(h,expectedBounds([assets[0]]));
h.change('#unit','25.4');const scaled=expectedBounds([assets[0]]);equalBoxes(h.read('selectionBox.box'),scaled);dimensionsMatch(h,scaled);close(scaled.getSize(new T.Vector3()).x,2032);assert.ok(h.read('labels.some(label=>label.kind==="dim"&&label.el.textContent.includes("2,032"))'),'Inch conversion remains displayed in millimetres, not multiplied only in metadata');
h.evaluate('select(assets[1]);select(assets[2],{toggle:true});fit()');equalBoxes(h.read('selectionBox.box'),expectedBounds([assets[1],assets[2]]));assert.ok(h.read('controls.target').distanceTo(expectedBounds([assets[1],assets[2]]).getCenter(new T.Vector3()))<1e-5);
h.evaluate('fit(true)');assert.ok(h.read('controls.target').distanceTo(expectedBounds(assets).getCenter(new T.Vector3()))<1e-5);
console.log('PASS All models, coordinate edits, real inch→mm scaling and fit-selected versus fit-all use the correct bounds');

select(h,'assets[1]');const eye=row(h,assets[1]).querySelector('.visibility');fire(h,eye,'click');assert.equal(h.read('selectionBounds().isEmpty()'),true);assert.equal(h.read('selectionBox.visible'),false);assert.equal(h.read('dimObjects.length'),0,'Hidden selection must not retain stale dimensions');
fire(h,row(h,assets[1]).querySelector('.visibility'),'click');assert.equal(h.read('selectionBox.visible'),true);dimensionsMatch(h,expectedBounds([assets[1]]));
select(h,'assets[0]');h.click('#remove');assert.equal(h.read('assets.length'),2);assert.ok(h.read('[...selectedObjects].every(object=>owner(object)&&assets.includes(owner(object)))'),'Removed source retained in selection');equalBoxes(h.read('selectionBox.box'),expectedBounds(h.read('selectedObjects.size?[...selectedObjects]:assets')));
while(h.read('assets.length')){select(h,'assets[0]');h.click('#remove')}
assert.equal(h.read('selectedObjects.size'),0);assert.equal(h.read('selected'),null);assert.equal(h.read('selectionBox.visible'),false);assert.equal(h.read('dimObjects.length'),0);
console.log('PASS hiding/unhiding selected roots invalidates/restores box and dimensions; removing roots clears stale selection and final empty scene');
assert.equal(h.read('selectionActive'),false,'Empty scene must reset the active-user-selection flag');
await h.load('samples/Montageblock.stl','New-session.stl');assert.equal(h.read('selectionActive'),false);assert.equal(h.read('selectionBox.visible'),false);
select(h,'assets[0]');const beforeRejected=ids(h),beforeRejectedObject=h.read('selected');
assert.equal(await h.window.openModel('Rejected.xyz',btoa('not a model')),false);assert.equal(h.read('selectionActive'),true);assert.equal(h.read('selectionBox.visible'),true);assert.equal(ids(h),beforeRejected);assert.equal(h.read('selected'),beforeRejectedObject);
const acceptedQueued=h.load('tests/fixtures/colored-box.obj','New-import.obj'),rejectedQueued=h.window.openModel('Empty.obj',btoa('# rejected parse'));
assert.equal(await acceptedQueued,true);assert.equal(await rejectedQueued,false);assert.equal(h.read('assets.length'),2);assert.equal(h.read('selected'),h.read('assets[1]'));assert.equal(h.read('selectionActive'),false);assert.equal(h.read('selectionBox.visible'),false,'A following rejected queued import must not activate the last imported object');
h.click('.scene-select');assert.equal(h.read('selectionActive'),true);assert.equal(h.read('selectionBox.visible'),true);equalBoxes(h.read('selectionBox.box'),expectedBounds(h.read('assets')));
assert.equal(await h.window.openModel('Also-rejected.obj',btoa('# no geometry')),false);assert.equal(h.read('selectionActive'),true);assert.equal(h.read('selectedObjects.size'),0);assert.equal(h.read('selectionBox.visible'),true);
console.log('PASS imported metadata focus stays undecorated; explicit user/All-models activation survives rejected imports; successful queued import resets decoration without stale activation');


const nested=createViewerHarness();nested.window.applyViewportSettings({language:'en'});await nested.load('tests/fixtures/two-colored-parts.glb','Assembly.glb','assembly-source');
select(nested,'assets[0]');select(nested,'meshes[0]','{toggle:true}');equalBoxes(nested.read('selectionBounds()'),expectedBounds([nested.read('assets[0]')]));assert.equal(nested.read('selectionRoots().length'),1,'Parent and descendant must aggregate through one effective root');assert.equal(info(nested).Volume,'48 cm³','Parent and descendant must not double-count the two 24cm³ fixture components');
select(nested,'meshes[0]');select(nested,'meshes[1]','{toggle:true}');equalBoxes(nested.read('selectionBounds()'),expectedBounds(nested.read('meshes')));nested.click('#dimensions');dimensionsMatch(nested,expectedBounds(nested.read('meshes')));
nested.evaluate('assets[0].scale.multiply(new T.Vector3(-2,3,4));assets[0].rotation.z=Math.PI/6;assets[0].position.set(33,-17,5);updateScene()');equalBoxes(nested.read('selectionBox.box'),expectedBounds(nested.read('meshes')));dimensionsMatch(nested,expectedBounds(nested.read('meshes')));
nested.evaluate('assets[0].visible=false;updateScene()');assert.equal(nested.read('selectionBox.visible'),false);assert.equal(nested.read('selectionBounds().isEmpty()'),true);
console.log('PASS nested assembly deduplication, multiple components, mirrored/nonuniform world transforms and hidden ancestors');

const picking=createViewerHarness();await picking.load('samples/Montageblock.stl','Left.stl');await picking.load('samples/Montageblock.stl','Right.stl');
picking.evaluate('select(null);fit(true)');
const canvas=picking.read('renderer.domElement');
const pointFor=index=>picking.read(`new T.Box3().setFromObject(assets[${index}]).getCenter(new T.Vector3()).project(camera)`);
function pointer(index,properties={},drag=0){const p=pointFor(index),x=(p.x+1)*400,y=(1-p.y)*300;fire(picking,canvas,'pointerdown',{button:0,pointerType:'mouse',clientX:x,clientY:y,...properties});fire(picking,canvas,'pointerup',{button:0,pointerType:'mouse',clientX:x+drag,clientY:y,...properties})}
pointer(1);assert.equal(picking.read('owner(selected)'),picking.read('assets[1]'),'Actual surface single click must select its source component');
const before=ids(picking);pointer(0,{},20);assert.equal(ids(picking),before,'Orbit drag must not be interpreted as selection');
for(const properties of [{button:2},{button:1},{shiftKey:true},{ctrlKey:true},{altKey:true},{metaKey:true}]){pointer(0,properties);assert.equal(ids(picking),before,'Navigation-modified pointer changed selection')}
picking.click('#measure');pointer(0);pointer(1);assert.equal(ids(picking),before,'Measuring a surface must not change the current object selection');assert.equal(picking.read('measurementTools.getLabels().length'),1);assert.ok(picking.read('measurementTools.getLabels()[0].value')>0);const measurement=picking.read('measurementTools.getLabels()[0].el');picking.click('#dimensions');select(picking,'assets[0]');assert.equal(picking.read('measurementTools.getLabels()[0].el'),measurement,'Selection dimensions must not erase an independent point-to-point measurement');
console.log('PASS actual ray-picked single clicks; drags/navigation modifiers/measurement clicks do not change selection or erase point measurements');

// Box visibility is an independent session display choice, not a selection command.
const toggle=createViewerHarness();await toggle.load('samples/Montageblock.stl','Box A.stl');select(toggle,'assets[0]');toggle.click('#dimensions');
const boxToggle=()=>toggle.document.querySelector('#selection-box-toggle');
assert.equal(toggle.read('selectionBoxEnabled'),true);assert.equal(boxToggle().getAttribute('aria-pressed'),'true');const singleSelection=ids(toggle);toggle.click('#selection-box-toggle');assert.equal(toggle.read('selectionBoxEnabled'),false);assert.equal(toggle.read('selectionBox.visible'),false);assert.equal(ids(toggle),singleSelection);assert.equal(toggle.read('dimObjects.length'),3);assert.equal(boxToggle().getAttribute('aria-pressed'),'false');
await toggle.load('tests/fixtures/colored-box.obj','Box B.obj');assert.equal(toggle.read('selectionBoxEnabled'),false,'Successful imports retain the session display choice');assert.equal(toggle.read('selectionBox.visible'),false);select(toggle,'assets[0]');select(toggle,'assets[1]','{toggle:true}');assert.equal(toggle.read('selectedObjects.size'),2);dimensionsMatch(toggle,expectedBounds(toggle.read('assets')));assert.equal(toggle.read('selectionBox.visible'),false);const multiSelection=ids(toggle);toggle.click('#selection-box-toggle');assert.equal(ids(toggle),multiSelection);assert.equal(toggle.read('selectionBox.visible'),true);equalBoxes(toggle.read('selectionBox.box'),expectedBounds(toggle.read('assets')));
toggle.click('.scene-select');toggle.click('#selection-box-toggle');assert.equal(toggle.read('selectedObjects.size'),0);assert.equal(toggle.read('selectionActive'),true);assert.equal(toggle.read('selectionBox.visible'),false);dimensionsMatch(toggle,expectedBounds(toggle.read('assets')));toggle.click('#selection-box-toggle');assert.equal(toggle.read('selectionBox.visible'),true);
select(toggle,'assets[0]');fire(toggle,row(toggle,toggle.read('assets[0]')).querySelector('.visibility'),'click');assert.equal(toggle.read('selectionBox.visible'),false);assert.equal(toggle.read('dimObjects.length'),0);toggle.click('#selection-box-toggle');assert.equal(toggle.read('selectionBoxEnabled'),false);fire(toggle,row(toggle,toggle.read('assets[0]')).querySelector('.visibility'),'click');assert.equal(toggle.read('selectionBox.visible'),false);assert.equal(toggle.read('dimObjects.length'),3,'Unhiding restores dimensions while independently disabled box remains hidden');
while(toggle.read('assets.length')){select(toggle,'assets[0]');toggle.click('#remove')}
assert.equal(toggle.read('selectionBoxEnabled'),false);assert.equal(toggle.read('selectionBox.visible'),false);assert.equal(boxToggle().disabled,true);assert.equal(toggle.read('dimObjects.length'),0);await toggle.load('samples/Montageblock.stl');assert.equal(toggle.read('selectionBoxEnabled'),false);assert.equal(toggle.read('selectionActive'),false);assert.equal(toggle.read('selectionBox.visible'),false);assert.equal(boxToggle().disabled,false);select(toggle,'assets[0]');assert.equal(toggle.read('selectionBox.visible'),false);toggle.click('#selection-box-toggle');assert.equal(toggle.read('selectionBox.visible'),true);
console.log('PASS independent selection-box toggle for single/multiple/All models, dimensions, hidden roots and empty scene; session choice survives imports without changing selection');
