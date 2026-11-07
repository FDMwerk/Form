import {Box3,BufferGeometry,Float32BufferAttribute,Group,LineBasicMaterial,LineSegments,Vector3} from 'three';

const localCache=new WeakMap(),worldCache=new WeakMap();
const visible=mesh=>{for(let object=mesh;object;object=object.parent)if(object.visible===false)return false;return true};
function localData(geometry){
  const position=geometry?.attributes?.position,index=geometry?.index;if(!position)return null;
  const positionVersion=position.version??position.data?.version,indexVersion=index?.version;
  const old=localCache.get(geometry);
  if(old&&old.position===position&&old.index===index&&old.positionVersion===positionVersion&&old.indexVersion===indexVersion&&old.count===position.count&&old.indexCount===index?.count)return old.data;
  const positions=new Float64Array(position.count*3),valid=new Uint8Array(position.count),indices=[];
  for(let i=0;i<position.count;i++){const x=position.getX(i),y=position.getY(i),z=position.getZ(i);positions.set([x,y,z],i*3);valid[i]=Number.isFinite(x)&&Number.isFinite(y)&&Number.isFinite(z)?1:0}
  const count=index?.count??position.count;
  for(let i=0;i+2<count;i+=3){const ids=[0,1,2].map(j=>index?index.getX(i+j):i+j);if(ids.every(id=>Number.isInteger(id)&&id>=0&&id<position.count&&valid[id]))indices.push(...ids)}
  const data={positions,indices:new Uint32Array(indices)};
  localCache.set(geometry,{position,index,positionVersion,indexVersion,count:position.count,indexCount:index?.count,data});return data;
}
function worldData(mesh){
  if(!mesh?.isMesh||mesh.userData.formHelper||mesh.isInstancedMesh||mesh.isSkinnedMesh||mesh.morphTargetInfluences?.some(value=>value!==0))return null;
  const local=localData(mesh.geometry);if(!local)return null;
  mesh.updateWorldMatrix(true,false);const matrix=mesh.matrixWorld;
  if(!matrix.elements.every(Number.isFinite))return null;
  const key=matrix.elements.join(','),cached=worldCache.get(mesh);
  if(cached?.local===local&&cached.key===key)return cached.data;
  const positions=new Float64Array(local.positions.length),point=new Vector3(),bounds=new Box3();
  for(let i=0;i<positions.length;i+=3){point.fromArray(local.positions,i).applyMatrix4(matrix);positions.set([point.x,point.y,point.z],i)}
  for(const index of local.indices){point.fromArray(positions,index*3);if(![point.x,point.y,point.z].every(Number.isFinite))return null;bounds.expandByPoint(point)}
  const data={positions,indices:local.indices,bounds};worldCache.set(mesh,{local,key,data});return data;
}
function normalizedPlane(plane){if(!plane||![plane.normal.x,plane.normal.y,plane.normal.z,plane.constant].every(Number.isFinite)||plane.normal.lengthSq()===0)return null;return plane.clone().normalize()}
function intersect(data,plane,tolerance){
  if(!data||data.bounds.isEmpty()||!plane)return new Float64Array();
  const scale=data.bounds.getSize(new Vector3()).length(),epsilon=Number.isFinite(tolerance)&&tolerance>0?tolerance:Math.max(scale*1e-8,1e-10);
  if(!data.bounds.intersectsPlane(plane))return new Float64Array();
  const segments=new Map(),coplanar=new Map(),origin=data.bounds.min;
  const vertexKey=point=>[Math.round((point.x-origin.x)/epsilon),Math.round((point.y-origin.y)/epsilon),Math.round((point.z-origin.z)/epsilon)].join(',');
  const edgeKey=(a,b)=>{const u=vertexKey(a),v=vertexKey(b);return u<v?u+'|'+v:v+'|'+u};
  function add(a,b){if(a.distanceToSquared(b)<=epsilon*epsilon)return;segments.set(edgeKey(a,b),[a.x,a.y,a.z,b.x,b.y,b.z])}
  const vertices=[new Vector3(),new Vector3(),new Vector3()],edgeA=new Vector3(),edgeB=new Vector3(),normal=new Vector3();
  for(let i=0;i<data.indices.length;i+=3){
    for(let j=0;j<3;j++)vertices[j].fromArray(data.positions,data.indices[i+j]*3);
    if(normal.crossVectors(edgeA.subVectors(vertices[1],vertices[0]),edgeB.subVectors(vertices[2],vertices[0])).lengthSq()===0)continue;
    const distances=vertices.map(point=>plane.distanceToPoint(point)),sides=distances.map(distance=>Math.abs(distance)<=epsilon?0:Math.sign(distance));
    if(sides.every(side=>side===0)){
      // Retain only the boundary of a coplanar triangulated patch, not its diagonals.
      for(const [j,k] of [[0,1],[1,2],[2,0]]){const a=vertices[j],b=vertices[k],key=edgeKey(a,b),entry=coplanar.get(key)||{count:0,points:[a.clone(),b.clone()]};entry.count++;coplanar.set(key,entry)}
      continue;
    }
    if(sides.every(side=>side>0)||sides.every(side=>side<0))continue;
    const points=[];
    for(let j=0;j<3;j++)if(sides[j]===0)points.push(vertices[j].clone());
    for(const [j,k] of [[0,1],[1,2],[2,0]])if(sides[j]*sides[k]<0)points.push(vertices[j].clone().lerp(vertices[k],distances[j]/(distances[j]-distances[k])));
    if(points.length===2)add(points[0],points[1]);
  }
  for(const entry of coplanar.values())if(entry.count===1)add(...entry.points);
  return new Float64Array([...segments.values()].flat());
}

/** World-coordinate line segments (six numbers each), never filled caps.
 * Open or defective meshes produce their actual intersected triangle contours;
 * this is a display operation, not a claim that the section is a valid solid.
 * Geometry edits follow Three's needsUpdate convention for cache invalidation.
 */
export function intersectMeshPlane(mesh,plane,{visibleOnly=true,tolerance}={}){
  if(visibleOnly&&!visible(mesh))return new Float64Array();
  return intersect(worldData(mesh),normalizedPlane(plane),tolerance);
}

/** Helpers live outside the source model and never participate in ray picking.
 * Call update after cut movement, transforms, visibility changes and removal.
 * flip uses the same geometric contour; only the host's retained side changes.
 */
export function createSectionHighlight({scene,getMeshes,color=0xeb8c2e}={}){
  if(!scene||typeof getMeshes!=='function')throw TypeError('scene and getMeshes are required');
  const group=new Group();group.name='Form section contours';group.userData.formHelper=true;group.visible=false;scene.add(group);
  const material=new LineBasicMaterial({color,depthTest:false,depthWrite:false,toneMapped:false});
  const records=new Map();let disposed=false;
  function remove(mesh){const record=records.get(mesh);if(!record)return;group.remove(record.line);record.line.geometry.dispose();records.delete(mesh)}
  function update({enabled=false,plane}={}){
    if(disposed)return;
    const meshes=new Set(getMeshes());for(const mesh of records.keys())if(!meshes.has(mesh))remove(mesh);
    const normalized=normalizedPlane(plane);group.visible=!!enabled&&!!normalized;
    if(!group.visible)return;
    // Negating the plane must not rebuild or change the same geometric contour.
    const first=[normalized.normal.x,normalized.normal.y,normalized.normal.z].find(value=>Math.abs(value)>1e-15);
    if(first<0)normalized.negate();
    const planeKey=[...normalized.normal,normalized.constant].join(',');
    for(const mesh of meshes){
      let record=records.get(mesh);
      if(!visible(mesh)){if(record)record.line.visible=false;continue}
      const data=worldData(mesh);
      if(!data){remove(mesh);continue}
      if(record&&record.data===data&&record.planeKey===planeKey){record.line.visible=record.segmentCount>0;continue}
      const segments=intersect(data,normalized),origin=data.bounds.getCenter(new Vector3()),positions=new Float32Array(segments.length);
      for(let i=0;i<segments.length;i+=3){positions[i]=segments[i]-origin.x;positions[i+1]=segments[i+1]-origin.y;positions[i+2]=segments[i+2]-origin.z}
      const geometry=new BufferGeometry();geometry.setAttribute('position',new Float32BufferAttribute(positions,3));
      if(!record){const line=new LineSegments(geometry,material);line.name='Section contour';line.userData.formHelper=true;line.raycast=()=>{};line.renderOrder=30;group.add(line);record={line};records.set(mesh,record)}
      else{record.line.geometry.dispose();record.line.geometry=geometry}
      record.line.position.copy(origin);record.line.visible=segments.length>0;record.data=data;record.planeKey=planeKey;record.segmentCount=segments.length/6;
    }
  }
  function dispose(){if(disposed)return;for(const mesh of [...records.keys()])remove(mesh);material.dispose();group.removeFromParent();disposed=true}
  return {group,update,dispose};
}
