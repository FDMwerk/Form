import fs from 'node:fs';
import path from 'node:path';
import {BoxGeometry,Mesh,MeshStandardMaterial,Float32BufferAttribute} from 'three';
import {OBJExporter} from 'three/addons/exporters/OBJExporter.js';
import {PLYExporter} from 'three/addons/exporters/PLYExporter.js';
import {zipSync,strToU8} from 'three/addons/libs/fflate.module.js';

export function createFormatFixtures(destination='tests/fixtures') {
 fs.mkdirSync(destination,{recursive:true});
 const geometry=new BoxGeometry(20,30,40);
 const colors=[];for(let i=0;i<geometry.attributes.position.count;i++)colors.push(i%2?.15:.85,.35,i%2?.8:.2);
 geometry.setAttribute('color',new Float32BufferAttribute(colors,3));
 const mesh=new Mesh(geometry,new MeshStandardMaterial({vertexColors:true}));mesh.name='Original colored box';mesh.updateMatrixWorld(true);
 fs.writeFileSync(path.join(destination,'colored-box.obj'),new OBJExporter().parse(mesh));
 fs.writeFileSync(path.join(destination,'colored-box.ply'),new PLYExporter().parse(mesh).trimEnd()+'\n');
 // Compact glTF/GLB authored here, not derived from a customer or third-party model.
 const position=Float32Array.from(geometry.attributes.position.array,v=>v/1000),normal=geometry.attributes.normal.array,index=geometry.index.array;
 const chunks=[Buffer.from(position.buffer),Buffer.from(normal.buffer),Buffer.from(index.buffer)];const offsets=[0,chunks[0].length,chunks[0].length+chunks[1].length];const binary=Buffer.concat(chunks);while(binary.length%4)throw Error('Unexpected unaligned fixture');
 const gltf={asset:{version:'2.0',generator:'Form original regression fixtures'},scene:0,scenes:[{nodes:[0,1]}],nodes:[{name:'Coral part',mesh:0},{name:'Blue part',mesh:1,translation:[.03,0,0]}],meshes:[{primitives:[{attributes:{POSITION:0,NORMAL:1},indices:2,material:0}]},{primitives:[{attributes:{POSITION:0,NORMAL:1},indices:2,material:1}]}],materials:[{name:'Coral',pbrMetallicRoughness:{baseColorFactor:[.8,.25,.15,1],metallicFactor:0,roughnessFactor:.5}},{name:'Blue',pbrMetallicRoughness:{baseColorFactor:[.15,.35,.8,1],metallicFactor:0,roughnessFactor:.5}}],buffers:[{byteLength:binary.length}],bufferViews:chunks.map((chunk,i)=>({buffer:0,byteOffset:offsets[i],byteLength:chunk.length,target:i===2?34963:34962})),accessors:[{bufferView:0,componentType:5126,count:position.length/3,type:'VEC3',min:[-.01,-.015,-.02],max:[.01,.015,.02]},{bufferView:1,componentType:5126,count:normal.length/3,type:'VEC3'},{bufferView:2,componentType:5123,count:index.length,type:'SCALAR'}]};
 fs.writeFileSync(path.join(destination,'two-colored-parts.gltf'),JSON.stringify({...gltf,buffers:[{byteLength:binary.length,uri:'data:application/octet-stream;base64,'+binary.toString('base64')}]},null,2));
 let json=Buffer.from(JSON.stringify(gltf));json=Buffer.concat([json,Buffer.alloc((4-json.length%4)%4,32)]);const header=Buffer.alloc(12),jh=Buffer.alloc(8),bh=Buffer.alloc(8);header.writeUInt32LE(0x46546c67);header.writeUInt32LE(2,4);header.writeUInt32LE(12+8+json.length+8+binary.length,8);jh.writeUInt32LE(json.length);jh.writeUInt32LE(0x4e4f534a,4);bh.writeUInt32LE(binary.length);bh.writeUInt32LE(0x004e4942,4);fs.writeFileSync(path.join(destination,'two-colored-parts.glb'),Buffer.concat([header,jh,json,bh,binary]));
 const vertices=[[-10,-15,-20],[10,-15,-20],[10,15,-20],[-10,15,-20],[-10,-15,20],[10,-15,20],[10,15,20],[-10,15,20]];
 const triangles=[[0,2,1],[0,3,2],[4,5,6],[4,6,7],[0,1,5],[0,5,4],[3,7,6],[3,6,2],[0,4,7],[0,7,3],[1,2,6],[1,6,5]];
 for(const [file,unit,divisor]of [['colored-box.3mf','millimeter',1],['inch-box.3mf','inch',25.4]]){
 const xml=`<?xml version="1.0" encoding="UTF-8"?><model xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02" unit="${unit}" xml:lang="en-US"><metadata name="Title">Form original colored box</metadata><resources><basematerials id="1"><base name="Coral" displaycolor="#CC5033FF"/><base name="Blue" displaycolor="#3366CCFF"/></basematerials><object id="2" name="Colored box" type="model" pid="1" pindex="0"><mesh><vertices>${vertices.map(v=>`<vertex x="${v[0]/divisor}" y="${v[1]/divisor}" z="${v[2]/divisor}"/>`).join('')}</vertices><triangles>${triangles.map((t,i)=>`<triangle v1="${t[0]}" v2="${t[1]}" v3="${t[2]}" pid="1" p1="${i%2}"/>`).join('')}</triangles></mesh></object></resources><build><item objectid="2"/></build></model>`;
 const rels=`<?xml version="1.0"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Target="/3D/3dmodel.model" Id="rel0" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/></Relationships>`;
 const content=`<?xml version="1.0"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/></Types>`;
 fs.writeFileSync(path.join(destination,file),zipSync({'[Content_Types].xml':strToU8(content),'_rels/.rels':strToU8(rels),'3D/3dmodel.model':strToU8(xml)}));
 }
 geometry.dispose();mesh.material.dispose();return destination;
}
if(import.meta.url===new URL(process.argv[1],'file:').href)console.log(createFormatFixtures(process.argv[2]));
