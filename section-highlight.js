import {Box3,BufferGeometry,Float32BufferAttribute,Group,LineBasicMaterial,LineSegments,Vector3,Vector2,ShapeUtils,Mesh,MeshStandardMaterial,DoubleSide} from 'three';

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
  // A closed intersection loop alone is insufficient: an open source shell can
  // also intersect in a loop. Require a consistently oriented welded manifold.
  const bounds=new Box3(),point=new Vector3();for(let i=0;i<positions.length;i+=3)if(valid[i/3])bounds.expandByPoint(point.fromArray(positions,i));
  const tolerance=Math.max(bounds.getSize(new Vector3()).length()*1e-7,1e-10),welded=new Map(),ids=new Int32Array(position.count),edges=new Map();
  let malformed=count%3!==0||indices.length!==count||valid.some(value=>!value);
  for(let i=0;i<position.count;i++){const key=[0,1,2].map(j=>Math.round((positions[i*3+j]-[bounds.min.x,bounds.min.y,bounds.min.z][j])/tolerance)).join(',');if(!welded.has(key))welded.set(key,welded.size);ids[i]=welded.get(key)}
  const a=new Vector3(),b=new Vector3(),c=new Vector3();
  for(let i=0;i<indices.length;i+=3){const face=indices.slice(i,i+3).map(index=>ids[index]);a.fromArray(positions,indices[i]*3);b.fromArray(positions,indices[i+1]*3);c.fromArray(positions,indices[i+2]*3);if(new Set(face).size!==3||b.sub(a).cross(c.sub(a)).lengthSq()===0){malformed=true;continue}for(const [u,v]of[[face[0],face[1]],[face[1],face[2]],[face[2],face[0]]]){const key=u<v?u+','+v:v+','+u,edge=edges.get(key)||{count:0,balance:0};edge.count++;edge.balance+=u<v?1:-1;edges.set(key,edge)}}
  const watertight=!malformed&&indices.length>0&&[...edges.values()].every(edge=>edge.count===2&&edge.balance===0);
  const parents=Array.from({length:welded.size},(_,i)=>i),find=id=>{while(parents[id]!==id){parents[id]=parents[parents[id]];id=parents[id]}return id};
  for(let i=0;i<indices.length;i+=3){const root=find(ids[indices[i]]);parents[find(ids[indices[i+1]])]=root;parents[find(ids[indices[i+2]])]=root}
  const shells=new Int32Array(indices.length/3),shellVolumes=new Map(),center=bounds.getCenter(new Vector3());
  for(let i=0;i<indices.length;i+=3){const shell=find(ids[indices[i]]);shells[i/3]=shell;a.fromArray(positions,indices[i]*3).sub(center);b.fromArray(positions,indices[i+1]*3).sub(center);c.fromArray(positions,indices[i+2]*3).sub(center);shellVolumes.set(shell,(shellVolumes.get(shell)||0)+a.dot(b.cross(c))/6)}
  const shellSigns=new Map([...shellVolumes].map(([id,volume])=>[id,Math.sign(volume)]));
  const data={positions,indices:new Uint32Array(indices),watertight,shells,shellSigns};
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
  const data={positions,indices:local.indices,bounds,watertight:local.watertight,shells:local.shells,shellSigns:local.shellSigns};worldCache.set(mesh,{local,key,data});return data;
}
function normalizedPlane(plane){if(!plane||![plane.normal.x,plane.normal.y,plane.normal.z,plane.constant].every(Number.isFinite)||plane.normal.lengthSq()===0)return null;return plane.clone().normalize()}
function intersect(data,plane,tolerance){
  if(!data||data.bounds.isEmpty()||!plane)return new Float64Array();
  const scale=data.bounds.getSize(new Vector3()).length(),epsilon=Number.isFinite(tolerance)&&tolerance>0?tolerance:Math.max(scale*1e-8,1e-10);
  if(!data.bounds.intersectsPlane(plane))return new Float64Array();
  const segments=new Map(),segmentShells=new Map(),coplanar=new Map(),origin=data.bounds.min;
  const vertexKey=point=>[Math.round((point.x-origin.x)/epsilon),Math.round((point.y-origin.y)/epsilon),Math.round((point.z-origin.z)/epsilon)].join(',');
  const edgeKey=(a,b)=>{const u=vertexKey(a),v=vertexKey(b);return u<v?u+'|'+v:v+'|'+u};
  function add(a,b,shell){if(a.distanceToSquared(b)<=epsilon*epsilon)return;const key=edgeKey(a,b);segments.set(key,[a.x,a.y,a.z,b.x,b.y,b.z]);if(segmentShells.has(key)&&segmentShells.get(key)!==shell)segmentShells.set(key,-1);else segmentShells.set(key,shell)}
  const vertices=[new Vector3(),new Vector3(),new Vector3()],edgeA=new Vector3(),edgeB=new Vector3(),normal=new Vector3();
  for(let i=0;i<data.indices.length;i+=3){
    for(let j=0;j<3;j++)vertices[j].fromArray(data.positions,data.indices[i+j]*3);
    if(normal.crossVectors(edgeA.subVectors(vertices[1],vertices[0]),edgeB.subVectors(vertices[2],vertices[0])).lengthSq()===0)continue;
    const distances=vertices.map(point=>plane.distanceToPoint(point)),sides=distances.map(distance=>Math.abs(distance)<=epsilon?0:Math.sign(distance));
    if(sides.every(side=>side===0)){
      // Retain only the boundary of a coplanar triangulated patch, not its diagonals.
      for(const [j,k] of [[0,1],[1,2],[2,0]]){const a=vertices[j],b=vertices[k],key=edgeKey(a,b),entry=coplanar.get(key)||{count:0,points:[a.clone(),b.clone()],shell:data.shells[i/3]};entry.count++;coplanar.set(key,entry)}
      continue;
    }
    if(sides.every(side=>side>0)||sides.every(side=>side<0))continue;
    const points=[];
    for(let j=0;j<3;j++)if(sides[j]===0)points.push(vertices[j].clone());
    for(const [j,k] of [[0,1],[1,2],[2,0]])if(sides[j]*sides[k]<0)points.push(vertices[j].clone().lerp(vertices[k],distances[j]/(distances[j]-distances[k])));
    if(points.length===2)add(points[0],points[1],data.shells[i/3]);
  }
  for(const entry of coplanar.values())if(entry.count===1)add(...entry.points,entry.shell);
  const result=new Float64Array([...segments.values()].flat());result.formShells=new Int32Array([...segments.keys()].map(key=>segmentShells.get(key)));return result;
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

function capFromSegments(data,segments,plane){
  if(!data?.watertight||segments.length<18)return null;
  const origin=data.bounds.getCenter(new Vector3()),epsilon=Math.max(data.bounds.getSize(new Vector3()).length()*1e-7,1e-9),nodes=new Map(),links=new Set();
  const key=point=>[point.x,point.y,point.z].map((value,i)=>Math.round((value-[origin.x,origin.y,origin.z][i])/epsilon)).join(',');
  for(let i=0;i<segments.length;i+=6){const a=new Vector3().fromArray(segments,i),b=new Vector3().fromArray(segments,i+3),ka=key(a),kb=key(b);if(ka===kb)continue;const edge=ka<kb?ka+'|'+kb:kb+'|'+ka;if(links.has(edge))continue;links.add(edge);for(const [id,p,other]of[[ka,a,kb],[kb,b,ka]]){if(!nodes.has(id))nodes.set(id,{point:p,neighbors:[],shells:new Set()});nodes.get(id).neighbors.push(other);nodes.get(id).shells.add(segments.formShells?.[i/6]??-1)}}
  if([...nodes.values()].some(node=>node.neighbors.length!==2))return null;
  const loops=[],visited=new Set();
  for(const start of nodes.keys()){
    if(visited.has(start))continue;const loop=[],shells=new Set();let previous=null,current=start;
    do{if(visited.has(current))return null;visited.add(current);const node=nodes.get(current);loop.push(node.point);for(const shell of node.shells)shells.add(shell);const next=node.neighbors.find(id=>id!==previous);previous=current;current=next}while(current!==start);
    if(loop.length<3||shells.size!==1||shells.has(-1))return null;loops.push({points:loop,shell:[...shells][0]});
  }
  const n=plane.normal,u=new Vector3().crossVectors(Math.abs(n.z)<.9?new Vector3(0,0,1):new Vector3(0,1,0),n).normalize(),v=new Vector3().crossVectors(n,u);
  const polygons=loops.map(loop=>{const points=loop.points.map(point=>{const delta=point.clone().sub(origin);return new Vector2(delta.dot(u),delta.dot(v))});return {points,shell:loop.shell,area:Math.abs(ShapeUtils.area(points)),parent:-1,depth:0}});
  if(polygons.some(polygon=>polygon.area<=epsilon*epsilon))return null;
  const contains=(polygon,point)=>{let inside=false;for(let i=0,j=polygon.length-1;i<polygon.length;j=i++){const a=polygon[i],b=polygon[j];if((a.y>point.y)!==(b.y>point.y)&&point.x<(b.x-a.x)*(point.y-a.y)/(b.y-a.y)+a.x)inside=!inside}return inside};
  for(let i=0;i<polygons.length;i++){let best=Infinity;for(let j=0;j<polygons.length;j++)if(i!==j&&polygons[j].area>polygons[i].area+epsilon*epsilon&&polygons[j].area<best&&contains(polygons[j].points,polygons[i].points[0])){polygons[i].parent=j;best=polygons[j].area}}
  for(const polygon of polygons){let parent=polygon.parent;while(parent!==-1){polygon.depth++;parent=polygons[parent].parent}}
  // A separate same-winding solid nested inside another solid is overlap,
  // not a cavity. Conservatively skip its fill instead of manufacturing a hole.
  // Connected tube boundaries and opposite-winding cavity shells remain valid.
  for(const polygon of polygons)if(polygon.depth%2&&polygon.parent!==-1){const parent=polygons[polygon.parent];if(polygon.shell!==parent.shell&&data.shellSigns.get(polygon.shell)===data.shellSigns.get(parent.shell))return null}
  const planeOffset=plane.projectPoint(origin,new Vector3()).sub(origin);
  const positions=[],indices=[];let expectedArea=0,triangleArea=0,holeCount=0;
  for(let i=0;i<polygons.length;i++){
    const polygon=polygons[i];if(polygon.depth%2)continue;
    const holes=polygons.filter(child=>child.parent===i&&child.depth%2===1);holeCount+=holes.length;expectedArea+=polygon.area-holes.reduce((sum,hole)=>sum+hole.area,0);
    const flat=[...polygon.points,...holes.flatMap(hole=>hole.points)],triangles=ShapeUtils.triangulateShape(polygon.points,holes.map(hole=>hole.points)),offset=positions.length/3;
    for(const point of flat){const world=planeOffset.clone().addScaledVector(u,point.x).addScaledVector(v,point.y);positions.push(world.x,world.y,world.z)}
    for(let [a,b,c]of triangles){const pa=flat[a],pb=flat[b],pc=flat[c],signed=(pb.x-pa.x)*(pc.y-pa.y)-(pb.y-pa.y)*(pc.x-pa.x);triangleArea+=Math.abs(signed)/2;if(signed>0)[b,c]=[c,b];indices.push(offset+a,offset+b,offset+c)}
  }
  // Earcut area mismatch is a conservative rejection for ambiguous/invalid loops.
  if(!indices.length||expectedArea<=0||Math.abs(triangleArea-expectedArea)>Math.max(expectedArea*1e-5,epsilon*epsilon*indices.length))return null;
  const geometry=new BufferGeometry();geometry.setAttribute('position',new Float32BufferAttribute(positions,3));geometry.setIndex(indices);const normals=[];for(let i=0;i<positions.length;i+=3)normals.push(-n.x,-n.y,-n.z);geometry.setAttribute('normal',new Float32BufferAttribute(normals,3));
  geometry.userData.formSectionCap=true;return {geometry,origin,epsilon,loopCount:loops.length,holeCount,area:expectedArea};
}

/** Conservative visual cap of a closed source mesh. Returns null for open or
 * ambiguous sections; it neither repairs source geometry nor creates CAD solids.
 */
export function createSectionCap(mesh,plane,{visibleOnly=true}={}){
  if(visibleOnly&&!visible(mesh))return null;const normalized=normalizedPlane(plane),data=worldData(mesh);return normalized?capFromSegments(data,intersect(data,normalized),normalized):null;
}

/** Helpers live outside the source model and never participate in ray picking.
 * Caps are triangulated closed cross sections with even/odd holes, not CAD export.
 * Call update after cut movement, transforms, visibility changes and removal.
 */
export function createSectionHighlight({scene,getMeshes,color=0xeb8c2e}={}){
  if(!scene||typeof getMeshes!=='function')throw TypeError('scene and getMeshes are required');
  const group=new Group();group.name='Form section contours and caps';group.userData.formHelper=true;group.visible=false;scene.add(group);
  const material=new LineBasicMaterial({color,depthTest:false,depthWrite:false,toneMapped:false});
  const capMaterial=new MeshStandardMaterial({color:0xf0aa61,roughness:.78,metalness:0,side:DoubleSide,polygonOffset:true,polygonOffsetFactor:-1,polygonOffsetUnits:-1});
  const records=new Map();let disposed=false;
  function remove(mesh){const record=records.get(mesh);if(!record)return;group.remove(record.line);record.line.geometry.dispose();record.cap?.geometry.dispose();records.delete(mesh)}
  function orientCap(record,plane,sign){
    if(!record.cap)return;
    if(record.capSign!==sign){const normals=record.cap.geometry.attributes.normal,index=record.cap.geometry.index;for(let i=0;i<normals.count;i++)normals.setXYZ(i,-normals.getX(i),-normals.getY(i),-normals.getZ(i));for(let i=0;i<index.count;i+=3){const b=index.getX(i+1);index.setX(i+1,index.getX(i+2));index.setX(i+2,b)}normals.needsUpdate=true;index.needsUpdate=true;record.capSign=sign}
    record.cap.position.copy(plane.normal).multiplyScalar(-record.epsilon*2);
  }
  function update({enabled=false,plane}={}){
    if(disposed)return;
    const meshes=new Set(getMeshes());for(const mesh of records.keys())if(!meshes.has(mesh))remove(mesh);
    const original=normalizedPlane(plane);group.visible=!!enabled&&!!original;if(!group.visible)return;
    const normalized=original.clone(),first=[normalized.normal.x,normalized.normal.y,normalized.normal.z].find(value=>Math.abs(value)>1e-15),sign=first<0?-1:1;if(sign<0)normalized.negate();
    const planeKey=[...normalized.normal,normalized.constant].join(',');
    for(const mesh of meshes){
      let record=records.get(mesh);if(!visible(mesh)){if(record)record.line.visible=false;continue}
      const data=worldData(mesh);if(!data){remove(mesh);continue}
      if(record&&record.data===data&&record.planeKey===planeKey){record.line.visible=record.segmentCount>0;orientCap(record,original,sign);continue}
      const segments=intersect(data,normalized),origin=data.bounds.getCenter(new Vector3()),positions=new Float32Array(segments.length);
      for(let i=0;i<segments.length;i+=3){positions[i]=segments[i]-origin.x;positions[i+1]=segments[i+1]-origin.y;positions[i+2]=segments[i+2]-origin.z}
      const geometry=new BufferGeometry();geometry.setAttribute('position',new Float32BufferAttribute(positions,3));
      if(!record){const line=new LineSegments(geometry,material);line.name='Section contour';line.userData.formHelper=true;line.raycast=()=>{};line.renderOrder=30;group.add(line);record={line};records.set(mesh,record)}else{record.line.geometry.dispose();record.line.geometry=geometry}
      if(record.cap){record.line.remove(record.cap);record.cap.geometry.dispose();record.cap=null}
      const fill=capFromSegments(data,segments,normalized);
      if(fill){const cap=new Mesh(fill.geometry,capMaterial);cap.name='Closed section cap';cap.userData.formHelper=true;cap.raycast=()=>{};cap.renderOrder=2;record.line.add(cap);record.cap=cap;record.capSign=1;record.epsilon=fill.epsilon;orientCap(record,original,sign)}
      record.line.position.copy(origin);record.line.visible=segments.length>0;record.data=data;record.planeKey=planeKey;record.segmentCount=segments.length/6;
    }
  }
  function dispose(){if(disposed)return;for(const mesh of [...records.keys()])remove(mesh);material.dispose();capMaterial.dispose();group.removeFromParent();disposed=true}
  return {group,update,dispose};
}
