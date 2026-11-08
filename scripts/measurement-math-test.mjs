import assert from 'node:assert/strict';
import * as T from 'three';
import {createMeasurementAnchor,markerWorldRadius,createMeasurementSnapCache,measurementPointExposed} from '../measurement-tools.js';
const close=(a,b)=>assert.ok(a.distanceTo(b)<1e-7,`${a.toArray()} != ${b.toArray()}`);
const geometry=new T.BufferGeometry().setAttribute('position',new T.Float32BufferAttribute([-1,-1,0,1,-1,-10,0,2,-2],3));
const mesh=new T.Mesh(geometry),parent=new T.Group();parent.add(mesh);parent.updateMatrixWorld(true);
const camera=new T.PerspectiveCamera(50,1,.1,100);camera.position.z=10;camera.lookAt(0,0,0);camera.updateMatrixWorld(true);
const canvas={getBoundingClientRect:()=>({left:30,top:50,width:1000,height:1000})};
const screen=p=>{const v=p.clone().project(camera);return {clientX:30+(v.x*.5+.5)*1000,clientY:50+(-v.y*.5+.5)*1000}};
const hit={object:mesh,point:new T.Vector3(0,0,-2),face:{a:0,b:1,c:2}};
const a=new T.Vector3(-1,-1,0),b=new T.Vector3(1,-1,-10),sa=screen(a),sb=screen(b);
let anchor=createMeasurementAnchor({THREE:T,hit,event:{clientX:(sa.clientX+sb.clientX)/2,clientY:(sa.clientY+sb.clientY)/2},camera,canvas});
assert.equal(anchor.snap,'edge');close(anchor.local,a.clone().lerp(b,1/3));
// A linear screen interpolation of 1/2 would be wrong at these unequal depths.
assert.ok(anchor.local.distanceTo(a.clone().lerp(b,.5))>1);
console.log('PASS perspective-correct edge snap remains exactly on the true 3D edge at unequal depths');
anchor=createMeasurementAnchor({THREE:T,hit,event:screen(a),camera,canvas});assert.equal(anchor.snap,'vertex');close(anchor.local,a);
anchor=createMeasurementAnchor({THREE:T,hit,event:screen(a),camera,canvas,snap:false});assert.equal(anchor.snap,'surface');close(anchor.local,hit.point);
console.log('PASS vertex priority and disabled snap preserve exact mesh vertex / freely picked surface');
parent.scale.set(-2,3,4);parent.rotation.y=.4;parent.position.set(20,40,-10);parent.updateMatrixWorld(true);const local=new T.Vector3(.25,.5,-2),point=mesh.localToWorld(local.clone());
anchor=createMeasurementAnchor({THREE:T,hit:{...hit,point},event:{},camera,canvas,snap:false});close(anchor.local,local);
parent.position.x+=100;parent.scale.z=8;parent.updateMatrixWorld(true);close(mesh.localToWorld(anchor.local.clone()),mesh.localToWorld(local.clone()));
parent.scale.z=0;parent.updateMatrixWorld(true);assert.equal(createMeasurementAnchor({THREE:T,hit,event:{},camera,canvas}),null);
assert.equal(createMeasurementAnchor({THREE:T,hit:{...hit,point:new T.Vector3(NaN,0,0)},event:{},camera,canvas}),null);
console.log('PASS reflected/nonuniform parent transforms keep local anchors; singular matrices and nonfinite points are rejected');

// A pointer near a boundary must see the mesh's actual feature edges, even when
// the ray-hit triangle does not own that boundary/vertex.
const square=new T.Mesh(new T.BufferGeometry().setAttribute('position',new T.Float32BufferAttribute([-10,-10,0,10,-10,0,10,10,0,-10,10,0],3)).setIndex([0,1,2,0,2,3]));square.updateMatrixWorld(true);camera.position.set(0,0,60);camera.lookAt(0,0,0);camera.far=1000;camera.updateProjectionMatrix();camera.updateMatrixWorld(true);
const mismatch={object:square,point:new T.Vector3(0,0,0),face:{a:0,b:1,c:2}},corner=new T.Vector3(-10,10,0),boundary=new T.Vector3(0,10,0);
anchor=createMeasurementAnchor({THREE:T,hit:mismatch,event:screen(corner),camera,canvas,getMeshes:()=>[square]});assert.equal(anchor.snap,'vertex');close(anchor.local,corner);
anchor=createMeasurementAnchor({THREE:T,hit:mismatch,event:screen(boundary),camera,canvas,getMeshes:()=>[square]});assert.equal(anchor.snap,'edge');close(anchor.local,boundary);
for(const zoom of [.4,2]){camera.zoom=zoom;camera.updateProjectionMatrix();anchor=createMeasurementAnchor({THREE:T,hit:mismatch,event:screen(corner),camera,canvas,getMeshes:()=>[square]});assert.equal(anchor.snap,'vertex');close(anchor.local,corner)}
camera.zoom=1;camera.updateProjectionMatrix();anchor=createMeasurementAnchor({THREE:T,hit:mismatch,event:screen(corner),camera,canvas,getMeshes:()=>[square],isClipped:p=>p.y>9});assert.equal(anchor.snap,'surface');close(anchor.local,mismatch.point);
assert.equal(createMeasurementAnchor({THREE:T,hit:mismatch,event:screen(corner),camera,canvas,getMeshes:()=>[square],isVisible:()=>false}),null);
console.log('PASS adjacent feature vertices/edges beyond hit triangle, perspective zoom and rejection of clipped/invisible candidates');

for(const cam of [new T.PerspectiveCamera(40,1,.1,10000),new T.OrthographicCamera(-20,20,20,-20,.1,10000)])for(const distance of [20,2000])for(const zoom of [.25,4]){
 cam.position.set(0,-distance,distance*.3);cam.up.set(0,0,1);cam.lookAt(0,0,0);cam.zoom=zoom;cam.updateProjectionMatrix();cam.updateMatrixWorld(true);const point=new T.Vector3(),radius=markerWorldRadius({THREE:T,camera:cam,point,height:1000,pixels:9}),up=new T.Vector3().setFromMatrixColumn(cam.matrixWorld,1),a=point.clone().project(cam),b=point.clone().addScaledVector(up,radius).project(cam);assert.ok(Number.isFinite(radius)&&radius>0);assert.ok(Math.abs(Math.abs(b.y-a.y)*500-9)<1e-6);
}
console.log('PASS marker world radius projects to constant nine CSS pixels in perspective/orthographic, near/far and zoom extremes');

// The host feature-edge provider is actually consumed and reused, not ignored.
const customEdges=new T.BufferGeometry().setFromPoints([new T.Vector3(-5,3,0),new T.Vector3(5,3,0)]);let supplied=0;const snapCache=createMeasurementSnapCache({THREE:T,getSnapEdges:mesh=>{assert.equal(mesh,square);supplied++;return customEdges}});
anchor=createMeasurementAnchor({THREE:T,hit:mismatch,event:screen(new T.Vector3(0,3,0)),camera,canvas,snapCache,getMeshes:()=>[square]});assert.equal(anchor.snap,'edge');close(anchor.local,new T.Vector3(0,3,0));assert.ok(supplied>0);
console.log('PASS shared viewport feature-edge provider supplies the actual snap geometry');

camera.position.set(0,0,60);camera.zoom=1;camera.lookAt(0,0,0);camera.updateProjectionMatrix();camera.updateMatrixWorld(true);const occlusionBox=new T.Mesh(new T.BoxGeometry(10,10,10)),front=new T.Vector3(0,0,5),rear=new T.Vector3(0,0,-5);occlusionBox.updateMatrixWorld(true);
assert.equal(measurementPointExposed({THREE:T,point:front,camera,meshes:[occlusionBox]}),true);assert.equal(measurementPointExposed({THREE:T,point:rear,camera,meshes:[occlusionBox]}),false,'Rear feature of the same mesh must not snap through its front surface');
const foreground=new T.Mesh(new T.PlaneGeometry(30,30));foreground.position.z=20;foreground.updateMatrixWorld(true);assert.equal(measurementPointExposed({THREE:T,point:front,camera,meshes:[occlusionBox,foreground]}),false);foreground.visible=false;assert.equal(measurementPointExposed({THREE:T,point:front,camera,meshes:[occlusionBox,foreground]}),true);foreground.visible=true;assert.equal(measurementPointExposed({THREE:T,point:front,camera,meshes:[occlusionBox,foreground],isClipped:p=>p.z>10}),true);foreground.userData.formHelper=true;assert.equal(measurementPointExposed({THREE:T,point:front,camera,meshes:[occlusionBox,foreground]}),true);
console.log('PASS candidate-ray visibility rejects same-mesh rear features and foreground occluders while ignoring hidden/clipped/helper surfaces');
