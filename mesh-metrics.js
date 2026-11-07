import {Vector3, Box3} from 'three';

// Geometry is in source units; matrixWorld must map those units to millimetres.
// Cache only local topology/data. Every call evaluates the current world transform.
const geometryCache = new WeakMap(), worldCache = new WeakMap();
const isVisible = object => {for(let p=object;p;p=p.parent)if(p.visible===false)return false;return true};

function localMetrics(geometry) {
  const position=geometry?.attributes?.position,index=geometry?.index;
  if(!position)return null;
  const old=geometryCache.get(geometry);
  if(old&&old.position===position&&old.index===index&&old.positionVersion===(position.version??position.data?.version)&&old.indexVersion===index?.version&&old.count===position.count&&old.indexCount===index?.count)return old.data;
  const bounds=new Box3(),point=new Vector3();let invalid=0;
  for(let i=0;i<position.count;i++){
    point.set(position.getX(i),position.getY(i),position.getZ(i));
    if([point.x,point.y,point.z].every(Number.isFinite))bounds.expandByPoint(point);else invalid++;
  }
  if(bounds.isEmpty())return null;
  const extent=bounds.getSize(new Vector3()),origin=bounds.getCenter(new Vector3());
  const tolerance=Math.max(extent.x,extent.y,extent.z)*1e-7||1e-9;
  const welded=new Map(),vertexIDs=new Int32Array(position.count);vertexIDs.fill(-1);
  for(let i=0;i<position.count;i++){
    const x=position.getX(i),y=position.getY(i),z=position.getZ(i);
    if(![x,y,z].every(Number.isFinite))continue;
    const key=[Math.round((x-bounds.min.x)/tolerance),Math.round((y-bounds.min.y)/tolerance),Math.round((z-bounds.min.z)/tolerance)].join(',');
    if(!welded.has(key))welded.set(key,welded.size);
    vertexIDs[i]=welded.get(key);
  }
  const count=index?.count??position.count,triangles=[],edges=new Map();
  if(count%3)invalid++;
  const a=new Vector3(),b=new Vector3(),c=new Vector3(),ab=new Vector3(),ac=new Vector3(),cross=new Vector3();
  let signedVolume=0;
  for(let i=0;i+2<count;i+=3){
    const ids=[0,1,2].map(j=>index?index.getX(i+j):i+j);
    if(ids.some(id=>!Number.isInteger(id)||id<0||id>=position.count||vertexIDs[id]<0)){invalid++;continue}
    const [ia,ib,ic]=ids.map(id=>vertexIDs[id]);
    a.set(position.getX(ids[0]),position.getY(ids[0]),position.getZ(ids[0]));b.set(position.getX(ids[1]),position.getY(ids[1]),position.getZ(ids[1]));c.set(position.getX(ids[2]),position.getY(ids[2]),position.getZ(ids[2]));
    cross.crossVectors(ab.subVectors(b,a),ac.subVectors(c,a));
    if(ia===ib||ib===ic||ic===ia||cross.lengthSq()===0){invalid++;continue}
    triangles.push(a.x,a.y,a.z,b.x,b.y,b.z,c.x,c.y,c.z);
    // Subtract a nearby origin to avoid translation-dependent cancellation.
    a.sub(origin);b.sub(origin);c.sub(origin);
    signedVolume+=a.dot(cross.crossVectors(b,c))/6;
    for(const [u,v] of [[ia,ib],[ib,ic],[ic,ia]]){
      const key=u<v?u+','+v:v+','+u,edge=edges.get(key)||{count:0,balance:0};
      edge.count++;edge.balance+=u<v?1:-1;edges.set(key,edge);
    }
  }
  let boundaryEdges=0,nonManifoldEdges=0,inconsistentEdges=0;
  for(const edge of edges.values()){
    if(edge.count===1)boundaryEdges++;
    else if(edge.count!==2)nonManifoldEdges++;
    if(edge.count===2&&edge.balance!==0)inconsistentEdges++;
  }
  const data={triangles:new Float64Array(triangles),signedVolume,invalid,boundaryEdges,nonManifoldEdges,inconsistentEdges,watertight:triangles.length>0&&!invalid&&!boundaryEdges&&!nonManifoldEdges&&!inconsistentEdges};
  geometryCache.set(geometry,{position,index,positionVersion:position.version??position.data?.version,indexVersion:index?.version,count:position.count,indexCount:index?.count,data});
  return data;
}

function transformedMetrics(mesh,data,matrix) {
  const linearKey=[0,1,2,4,5,6,8,9,10].map(index=>matrix.elements[index]).join(',');
  const cached=worldCache.get(mesh);
  if(cached?.data===data&&cached.linearKey===linearKey)return cached.result;
  const linear=matrix.clone().setPosition(0,0,0),bounds=new Box3();
  const a=new Vector3(),b=new Vector3(),c=new Vector3(),ab=new Vector3(),ac=new Vector3(),normal=new Vector3();
  const result={surface:0,horizontal:0,vertical:0,bounds,valid:true,count:0};
  const positions=data.triangles;
  for(let i=0;i<positions.length;i+=9){
    a.fromArray(positions,i).applyMatrix4(linear);b.fromArray(positions,i+3).applyMatrix4(linear);c.fromArray(positions,i+6).applyMatrix4(linear);
    normal.crossVectors(ab.subVectors(b,a),ac.subVectors(c,a)).multiplyScalar(.5);
    const area=normal.length();
    if(!Number.isFinite(area)){result.valid=false;continue}
    bounds.expandByPoint(a);bounds.expandByPoint(b);bounds.expandByPoint(c);
    result.surface+=area;result.horizontal+=Math.abs(normal.z);result.vertical+=Math.hypot(normal.x,normal.y);result.count++;
  }
  worldCache.set(mesh,{data,linearKey,result});return result;
}

/** Visible source meshes only. Volume is additive across meshes, not a Boolean union.
 * A welded, consistently oriented edge test cannot detect self-intersections,
 * overlapping solids or incorrect internal shells. It does not certify CAD solids.
 * Invalid/open meshes retain measured surface area but return no volume.
 * Attribute edits must follow Three.js convention: set needsUpdate=true.
 */
export function measureMeshes(object,{visibleOnly=true}={}) {
  const result={volumeMM3:null,surfaceMM2:0,horizontalAreaMM2:0,verticalAreaMM2:0,zHeightMM:0,zHeight:0,watertight:false,meshCount:0,triangleCount:0,invalidTriangleCount:0,additiveVolumes:false,warnings:[]};
  if(!object)return result;
  object.updateWorldMatrix?.(true,true);
  const worldBounds=new Box3(),translation=new Vector3();
  let volume=0,allClosed=true;const warnings=new Set();
  object.traverse(mesh=>{
    if(!mesh.isMesh||(visibleOnly&&!isVisible(mesh)))return;
    result.meshCount++;
    if(mesh.isSkinnedMesh||mesh.isInstancedMesh||mesh.morphTargetInfluences?.some(value=>value!==0)){warnings.add('unsupported-deformation');allClosed=false;return}
    const data=localMetrics(mesh.geometry),matrix=mesh.matrixWorld;
    if(!data){warnings.add('invalid-geometry');allClosed=false;return}
    const determinant=matrix.determinant();
    if(!matrix.elements.every(Number.isFinite)||!Number.isFinite(determinant)||Math.abs(determinant)<Number.MIN_VALUE||[3,7,11].some(i=>matrix.elements[i]!==0)||matrix.elements[15]!==1){warnings.add('invalid-transform');allClosed=false;return}
    allClosed=allClosed&&data.watertight;
    result.invalidTriangleCount+=data.invalid;
    if(data.invalid)warnings.add('invalid-triangles');
    if(data.boundaryEdges)warnings.add('open-surface');
    if(data.nonManifoldEdges)warnings.add('non-manifold');
    if(data.inconsistentEdges)warnings.add('inconsistent-winding');
    volume+=Math.abs(data.signedVolume*determinant);
    const transformed=transformedMetrics(mesh,data,matrix);
    if(!transformed.valid){warnings.add('invalid-transform');allClosed=false}
    result.surfaceMM2+=transformed.surface;
    result.horizontalAreaMM2+=transformed.horizontal;
    result.verticalAreaMM2+=transformed.vertical;
    result.triangleCount+=transformed.count;
    translation.setFromMatrixPosition(matrix);
    worldBounds.union(transformed.bounds.clone().translate(translation));
  });
  result.watertight=result.meshCount>0&&allClosed&&Number.isFinite(volume)&&volume>0;
  result.volumeMM3=result.watertight?volume:null;
  const height=worldBounds.isEmpty()?0:worldBounds.max.z-worldBounds.min.z;
  result.zHeightMM=result.zHeight=Number.isFinite(height)?height:0;
  result.additiveVolumes=result.meshCount>1;
  if(result.meshCount)warnings.add('self-intersection-not-tested');
  if(result.additiveVolumes)warnings.add('additive-volumes-overlap-not-removed');
  result.warnings=[...warnings];return result;
}
