import {EdgesGeometry,LineBasicMaterial,LineSegments,OrthographicCamera,PerspectiveCamera,Vector3,DoubleSide} from 'three';

export const viewportModes=Object.freeze(['solid','edges','wireframe','xray']);
/** Call applyDisplayStyle({sourceRestored:true}) immediately after host appearance
 * copying. This preserves its current palette, textures, material alpha and section.
 * No source geometry or retained original material is disposed by this controller.
 */
export function createViewportDisplay({getMeshes,refreshAppearance,getClippingPlanes=()=>[]}={}) {
  if(typeof getMeshes!=='function')throw TypeError('getMeshes is required');
  let mode='solid',disposed=false;
  const snapshots=new Map(),helpers=new Map(),edgeGeometry=new Map();
  const materials=mesh=>[].concat(mesh.material||[]);
  const attributeIDs=new WeakMap();let nextAttributeID=0;const attributeID=attribute=>{if(!attribute)return 0;if(!attributeIDs.has(attribute))attributeIDs.set(attribute,++nextAttributeID);return attributeIDs.get(attribute)};
  const revision=geometry=>[attributeID(geometry.attributes.position),attributeID(geometry.index),geometry.attributes.position?.version??geometry.attributes.position?.data?.version,geometry.index?.version,geometry.attributes.position?.count,geometry.index?.count].join(',');
  function restoreDisplayStyle(){for(const [material,snapshot] of snapshots){material.copy(snapshot);material.clippingPlanes=snapshot.clippingPlanes;material.needsUpdate=true}}
  function cleanup(){
    const meshes=new Set(getMeshes());
    for(const [mesh,helper] of helpers)if(!meshes.has(mesh)||mesh.geometry!==helper.userData.sourceGeometry||revision(mesh.geometry)!==helper.userData.geometryRevision){mesh.remove(helper);helper.material.dispose();helpers.delete(mesh)}
    const used=new Set([...helpers.values()].map(helper=>helper.userData.sourceGeometry));
    for(const [geometry,edges] of edgeGeometry)if(!used.has(geometry)){edges.dispose();edgeGeometry.delete(geometry)}
    const usedMaterials=new Set([...meshes].flatMap(materials));
    for(const [material,snapshot] of snapshots)if(!usedMaterials.has(material)){snapshot.dispose();snapshots.delete(material)}
  }
  function edgeHelper(mesh){
    let helper=helpers.get(mesh);if(helper)return helper;
    let edges=edgeGeometry.get(mesh.geometry);
    if(!edges){edges=new EdgesGeometry(mesh.geometry,25);edgeGeometry.set(mesh.geometry,edges)}
    const material=new LineBasicMaterial({color:0x626b73,transparent:true,opacity:.62,depthWrite:false,clippingPlanes:getClippingPlanes()});
    helper=new LineSegments(edges,material);helper.name='Form display edges';helper.userData.formHelper=true;helper.userData.sourceGeometry=mesh.geometry;helper.userData.geometryRevision=revision(mesh.geometry);helper.raycast=()=>{};helper.renderOrder=1;
    helpers.set(mesh,helper);mesh.add(helper);return helper;
  }
  function applyDisplayStyle({sourceRestored=false}={}){
    if(disposed)return;
    if(!sourceRestored)restoreDisplayStyle();
    cleanup();const processed=new Set();
    for(const mesh of getMeshes()){
      for(const material of materials(mesh)){
        if(processed.has(material))continue;processed.add(material);
        let snapshot=snapshots.get(material);
        if(!snapshot){snapshot=material.clone();snapshot.clippingPlanes=material.clippingPlanes;snapshots.set(material,snapshot)}
        else if(sourceRestored){snapshot.copy(material);snapshot.clippingPlanes=material.clippingPlanes;}
        if(mode==='wireframe')material.wireframe=true;
        if(mode==='xray'){material.transparent=true;material.opacity=Math.min(snapshot.opacity,.25);material.depthWrite=false;material.side=DoubleSide;if('transmission' in material)material.transmission=0}
        if(mode==='edges'){material.polygonOffset=true;material.polygonOffsetFactor=1;material.polygonOffsetUnits=1}
        material.needsUpdate=true;
      }
      const helper=mode==='edges'?edgeHelper(mesh):helpers.get(mesh);
      if(helper){helper.visible=mode==='edges';helper.material.clippingPlanes=getClippingPlanes();helper.material.needsUpdate=true}
    }
  }
  function setMode(next){if(!viewportModes.includes(next))throw RangeError('Unknown display mode');if(disposed)return;restoreDisplayStyle();mode=next;if(refreshAppearance)refreshAppearance();applyDisplayStyle()}
  // Detach before a host's recursive source-object disposal; helpers own their GPU resources.
  function detachHelpers(root){
    const descendants=new Set();root?.traverse(object=>descendants.add(object));
    for(const [mesh,helper] of helpers)if(!root||descendants.has(mesh)){mesh.remove(helper);helper.material.dispose();helpers.delete(mesh)}
    const used=new Set([...helpers.values()].map(helper=>helper.userData.sourceGeometry));
    for(const [geometry,edges] of edgeGeometry)if(!used.has(geometry)){edges.dispose();edgeGeometry.delete(geometry)}
  }
  function updateClipping(){for(const helper of helpers.values()){helper.material.clippingPlanes=getClippingPlanes();helper.material.needsUpdate=true}}
  function dispose(){if(disposed)return;restoreDisplayStyle();for(const [mesh,helper] of helpers){mesh.remove(helper);helper.material.dispose()}for(const geometry of edgeGeometry.values())geometry.dispose();for(const snapshot of snapshots.values())snapshot.dispose();helpers.clear();edgeGeometry.clear();snapshots.clear();disposed=true}
  return {get mode(){return mode},setMode,applyDisplayStyle,restoreDisplayStyle,updateClipping,detachHelpers,dispose};
}

const directions={front:[0,-1,0],back:[0,1,0],left:[-1,0,0],right:[1,0,0],top:[0,0,1],bottom:[0,0,-1],iso:[1,-1,1]};
/** Owns two cameras. Caller rebinds OrbitControls.object, TransformControls.camera
 * and its active camera variable after switching. target is the shared controls
 * target Vector3; fit changes that same vector, never replaces it.
 */
export function createViewportCameras({camera=new PerspectiveCamera(38,1,.01,1e8),target=new Vector3(),aspect=camera.aspect||1}={}) {
  const perspective=camera,orthographic=new OrthographicCamera(-1,1,1,-1,.01,1e8);
  let active=perspective,projection='perspective',ratio=Number.isFinite(aspect)&&aspect>0?aspect:1;
  perspective.aspect=ratio;perspective.updateProjectionMatrix();orthographic.up.copy(perspective.up);
  const direction=()=>{const offset=active.position.clone().sub(target);return offset.lengthSq()?offset.normalize():new Vector3(1,-1,1).normalize()};
  const verticalSize=()=>active.isPerspectiveCamera?2*active.position.distanceTo(target)*Math.tan(active.fov*Math.PI/360)/active.zoom:(active.top-active.bottom)/active.zoom;
  function setOrthoHeight(height){orthographic.top=height/2;orthographic.bottom=-height/2;orthographic.left=-height*ratio/2;orthographic.right=height*ratio/2;orthographic.zoom=1;orthographic.updateProjectionMatrix()}
  function setProjection(next){
    if(!['perspective','orthographic'].includes(next))throw RangeError('Unknown projection');
    if(next===projection)return active;
    const source=active,viewDirection=direction(),height=Math.max(verticalSize(),1e-8);
    if(next==='orthographic'){active=orthographic;active.position.copy(source.position);setOrthoHeight(height)}
    else{active=perspective;active.zoom=1;const distance=height/(2*Math.tan(active.fov*Math.PI/360));active.position.copy(target).addScaledVector(viewDirection,distance);active.aspect=ratio;active.updateProjectionMatrix()}
    active.up.copy(source.up);active.near=source.near;active.far=source.far;active.lookAt(target);active.updateProjectionMatrix();active.updateMatrixWorld(true);projection=next;return active;
  }
  function setView(view){
    const vector=Array.isArray(view)&&view.length===3&&view.every(n=>[-1,0,1].includes(n))&&view.some(n=>n!==0)?view:directions[view];
    if(!vector)throw RangeError('Unknown standard view');
    const distance=Math.max(active.position.distanceTo(target),1);
    active.position.copy(target).addScaledVector(new Vector3(...vector).normalize(),distance);
    active.up.set(0,0,1);if(vector[2]===1&&vector[0]===0&&vector[1]===0)active.up.set(0,1,0);if(vector[2]===-1&&vector[0]===0&&vector[1]===0)active.up.set(0,-1,0);
    active.lookAt(target);active.updateMatrixWorld(true);return active;
  }
  function resize(width,height){if(!Number.isFinite(width)||!Number.isFinite(height)||width<=0||height<=0)return active;ratio=width/height;perspective.aspect=ratio;perspective.updateProjectionMatrix();const half=(orthographic.top-orthographic.bottom)/2;orthographic.left=-half*ratio;orthographic.right=half*ratio;orthographic.updateProjectionMatrix();return active}
  function fit(box,{padding=1.2}={}){
    if(!box||box.isEmpty())return active;
    const center=box.getCenter(new Vector3()),size=box.getSize(new Vector3());
    if(![...center,...size].every(Number.isFinite))return active;
    const radius=Math.max(size.length()/2,.001),viewDirection=direction(),margin=Number.isFinite(padding)&&padding>=1?padding:1.2;
    target.copy(center);let distance;
    if(active.isPerspectiveCamera){const vertical=Math.atan(Math.tan(active.fov*Math.PI/360)/active.zoom),horizontal=Math.atan(Math.tan(vertical)*ratio);distance=radius/Math.sin(Math.min(vertical,horizontal))*margin}
    else{setOrthoHeight(2*radius*margin/Math.min(ratio,1));distance=Math.max(radius*3,active.position.distanceTo(target))}
    active.position.copy(target).addScaledVector(viewDirection,distance);active.near=Math.max(radius/10000,.00001);active.far=Math.max(distance+radius*10,1000);active.lookAt(target);active.updateProjectionMatrix();active.updateMatrixWorld(true);return active;
  }
  return {get active(){return active},get projection(){return projection},perspective,orthographic,target,setProjection,setView,resize,fit};
}
