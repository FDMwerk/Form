// Session-only measurements on the rendered triangle mesh, never analytic CAD features.
// Anchors live in mesh-local coordinates so parent/unit/assembly transforms stay meaningful.
export function createMeasurementTools({THREE:T,scene,camera,getCamera=()=>camera,controls,canvas,container,sidebar,toolbar,t=k=>k,icon=()=>'',format=v=>`${v.toFixed(2)} mm`,formatAngle=v=>`${Number(v.toFixed(2))}°`,getMeshes=()=>[],isVisible=visibleParents,isClipped=()=>false,status=()=>{},onChange=()=>{},getRadius=()=>100,fitBox=()=>{}}){
 const document=container.ownerDocument,objects=[],pending=[];let active=false,mode='distance',snap=true,selectedID=null,nextID=1,disposed=false,menu=null,notifying=false;
 const group=new T.Group();group.name='Form measurements';group.userData.formHelper=true;group.raycast=()=>{};scene.add(group);
 const style=document.createElement('style');style.textContent=`
 .measurement-tools{display:flex;align-items:center;gap:3px;padding:6px;border:1px solid #dededeb8;border-radius:22px;background:#fffffff2;box-shadow:0 5px 24px #0000000d;backdrop-filter:blur(16px)}
 .measurement-tools button,.measurement-row button,.measurement-label{font:inherit;cursor:pointer}.measurement-tools button{display:grid;place-items:center;width:34px;height:34px;border:0;border-radius:50%;background:transparent;color:#626262}.measurement-tools button:hover,.measurement-tools button:focus-visible{background:#eee;outline:2px solid #b6b0ef;outline-offset:1px}.measurement-tools button[aria-pressed=true]{color:#087f63;background:#e4f4ee}.measurement-tools button:disabled{opacity:.3;cursor:default}.measurement-tools .measurement-separator{width:1px;height:19px;background:#e4e4e4;margin:0 4px}
 #measurement-toolbar{position:static;transform:none;pointer-events:auto;width:max-content;max-width:100%;align-self:center;flex-wrap:wrap;z-index:26}#measurement-toolbar[hidden]{display:none}
 .measurement-section{padding:8px 10px 10px;border-top:1px solid #e5e5e5;flex-shrink:0}.measurement-section[hidden]{display:none}.measurement-heading{font-size:11px;font-weight:600;color:#858585;margin:4px 6px 7px}.measurement-list{max-height:170px;overflow:auto;display:grid;gap:3px}.measurement-row{display:flex;align-items:center;min-height:35px;border-radius:10px;padding-inline:6px;gap:3px;color:#656565}.measurement-row.selected{background:#e7e7e7;color:#222}.measurement-row button{border:0;background:transparent;color:inherit;border-radius:7px;padding:5px;display:flex;align-items:center;gap:7px}.measurement-row button:hover{background:#00000008}.measurement-row .measurement-focus{flex:1;min-width:0;text-align:start}.measurement-name{overflow:hidden;text-overflow:ellipsis;white-space:nowrap;font-size:11px}.measurement-value{display:block;font-variant-numeric:tabular-nums;color:#777;font-size:10px}.measurement-row svg{width:15px;height:15px;flex-shrink:0}.measurement-empty{font-size:11px;color:#888;padding:7px}
 .measurement-label{position:absolute;pointer-events:auto;transform:translate(-50%,-50%);padding:4px 8px;border:1px solid #8bc9b5;border-radius:7px;white-space:nowrap;background:#fffffff2;color:#087f63;font-size:11px;font-variant-numeric:tabular-nums;box-shadow:0 1px 4px #00000009}.measurement-label.selected{border-color:#087f63;box-shadow:0 0 0 2px #10a37f25}.measurement-label[hidden]{display:none}.measurement-context{position:fixed;z-index:10000;padding:5px;background:white;border:1px solid #ddd;box-shadow:0 8px 25px #0002;border-radius:10px}.measurement-context button{border:0;border-radius:7px;background:white;padding:8px 12px;display:flex;gap:8px;align-items:center;color:#a33;cursor:pointer}.measurement-context button:hover{background:#f8eeee}
 @media(max-width:1100px){.measurement-tools button{width:30px;height:30px}.measurement-tools{gap:1px;padding:5px}}
 `;document.head.append(style);
 const ownToolbar=!toolbar,ownSidebar=!sidebar;toolbar ||= document.createElement('div');sidebar ||= document.createElement('section');
 if(ownToolbar){toolbar.id='measurement-toolbar';container.parentElement.append(toolbar)}if(ownSidebar){sidebar.hidden=true}
 toolbar.classList.add('measurement-tools');toolbar.setAttribute('role','toolbar');sidebar.classList.add('measurement-section');
 const heading=document.createElement('div');heading.className='measurement-heading';const list=document.createElement('div');list.className='measurement-list';sidebar.replaceChildren(heading,list);
 const toolButtons={};const modes=['distance','path','angle'];const iconNames={distance:'ruler',path:'path',angle:'angle',snap:'snap',finish:'finish',cancel:'close',delete:'trash',visibility:'eye'};
 const keyNames={distance:'measurementDistance',path:'measurementPath',angle:'measurementAngle',snap:'measurementSnap',finish:'measurementFinish',cancel:'measurementCancel',delete:'measurementDelete',visibility:'measurementHideAll'};
 const translate=(key,params)=>t(key,params);
 function describe(button,key,params){const value=translate(key,params);button.setAttribute('aria-label',value);button.dataset.tooltip=value;button.removeAttribute('title')}
 function button(action,key,fn){const el=document.createElement('button');el.type='button';el.dataset.measureAction=action;el.innerHTML=icon(iconNames[action]||action);describe(el,key);el.addEventListener('click',event=>{event.stopPropagation();hideMenu();fn()});return el}
 for(const action of [...modes,'snap','finish','cancel','delete','visibility']){
  if(action==='snap'||action==='delete'){const sep=document.createElement('span');sep.className='measurement-separator';sep.setAttribute('aria-hidden','true');toolbar.append(sep)}
  toolButtons[action]=button(action,keyNames[action],()=>{if(modes.includes(action))setMode(action);else if(action==='snap')setSnap(!snap);else if(action==='finish')finish();else if(action==='cancel')cancelPending();else if(action==='delete')remove(selectedID);else toggleAll()});toolbar.append(toolButtons[action]);
 }
 function cameraNow(){return getCamera()}
 function notify(){refresh();if(notifying)return;notifying=true;try{onChange()}finally{notifying=false}}
 function prompt(){if(!active)return;status(translate(!pending.length?'measurementFirst':mode==='path'?'measurementPathNext':mode==='angle'?(pending.length===1?'measurementAngleSecond':'measurementAngleThird'):'measurementNext'))}
 function world(anchor){anchor.mesh.updateWorldMatrix(true,false);return anchor.mesh.localToWorld(anchor.local.clone())}
 function anchorVisible(anchor){return isVisible(anchor.mesh)&&!isClipped(world(anchor))}
 function pointsOf(object){return object.points.map(world)}
 function measure(object){const p=pointsOf(object);if(object.mode==='angle'){const a=p[0].clone().sub(p[1]),b=p[2].clone().sub(p[1]);return a.lengthSq()>1e-20&&b.lengthSq()>1e-20?a.angleTo(b)*180/Math.PI:NaN}let value=0;for(let i=1;i<p.length;i++)value+=p[i].distanceTo(p[i-1]);return value}
 function valueText(object){const value=measure(object);return object.mode==='angle'?(Number.isFinite(value)?formatAngle(value):'—'):format(value)}
 function name(object){return translate(object.mode==='angle'?'measurementAngleName':object.mode==='path'?'measurementPathName':'measurementDistanceName',{id:object.id})}
 function helper(object){object.userData.formHelper=true;object.raycast=()=>{};object.renderOrder=30;return object}
 const dotGeometry=new T.SphereGeometry(1,10,6);
 function makeVisual(){const node=helper(new T.Group()),geometry=new T.BufferGeometry(),material=new T.LineBasicMaterial({color:0x10a37f,depthTest:false,transparent:true,opacity:.95});const line=helper(new T.Line(geometry,material));node.add(line);group.add(node);return {node,line,dots:[]}}
 const preview=makeVisual();
 function disposeVisual(visual){visual.node.removeFromParent();visual.line.geometry.dispose();visual.line.material.dispose();for(const dot of visual.dots)dot.material.dispose()}
 function renderVisual(visual,points,selected=false){
  const current=visual.line.geometry.getAttribute('position');if(!current||current.count!==points.length){visual.line.geometry.dispose();visual.line.geometry=new T.BufferGeometry().setFromPoints(points)}else{for(let i=0;i<points.length;i++)current.setXYZ(i,points[i].x,points[i].y,points[i].z);current.needsUpdate=true;visual.line.geometry.computeBoundingSphere()}
  visual.line.material.color.setHex(selected?0x067a60:0x10a37f);
  while(visual.dots.length>points.length){const dot=visual.dots.pop();dot.removeFromParent();dot.material.dispose()}
  while(visual.dots.length<points.length){const dot=helper(new T.Mesh(dotGeometry,new T.MeshBasicMaterial({color:0x10a37f,depthTest:false})));visual.node.add(dot);visual.dots.push(dot)}
  const size=Math.max(.02,getRadius()*.004);visual.dots.forEach((dot,i)=>{dot.position.copy(points[i]);dot.scale.setScalar(size);dot.material.color.setHex(selected?0x067a60:0x10a37f)});
 }
 function labelPosition(object,points){if(object.mode==='angle')return points[1].clone().add(points[0].clone().sub(points[1]).normalize().add(points[2].clone().sub(points[1]).normalize()).normalize().multiplyScalar(Math.max(getRadius()*.06,.5)));let total=0;for(let i=1;i<points.length;i++)total+=points[i].distanceTo(points[i-1]);let remaining=total/2;for(let i=1;i<points.length;i++){const len=points[i].distanceTo(points[i-1]);if(remaining<=len)return points[i-1].clone().lerp(points[i],len?remaining/len:0);remaining-=len}return points[0].clone()}
 function arcPoints(points){const [a,b,c]=points,u=a.clone().sub(b),v=c.clone().sub(b),angle=u.angleTo(v),normal=u.clone().cross(v);if(normal.lengthSq()<1e-18)return points;normal.normalize();const r=Math.min(u.length(),v.length())*.22;u.normalize();const path=[a,b,c]; // Mesh legs plus an independent arc use line segments to avoid a false join.
  return {legs:path,arc:Array.from({length:25},(_,i)=>u.clone().applyAxisAngle(normal,angle*i/24).multiplyScalar(r).add(b))}}
 function addObject(){const object={id:nextID++,mode,visible:true,points:pending.splice(0),visual:makeVisual(),el:document.createElement('button'),value:0};object.el.type='button';object.el.className='measurement-label';object.el.dataset.measureId=String(object.id);object.el.addEventListener('click',event=>{event.stopPropagation();select(object.id)});object.el.addEventListener('contextmenu',event=>showMenu(event,object.id));container.append(object.el);if(mode==='angle'){object.arc=makeVisual()}
  objects.push(object);selectedID=object.id;update();notify();prompt();return object}
 function finish(){if(mode==='path'&&pending.length>=2){addObject();return true}return false}
 function handlePointer(event,hit){if(disposed||!active||!hit?.object?.isMesh||event.button>0||event.altKey||event.ctrlKey||event.metaKey||event.shiftKey)return false;
  if(!getMeshes().includes(hit.object)||!isVisible(hit.object)||!hit.point||isClipped(hit.point))return false;
  const anchor=createMeasurementAnchor({THREE:T,hit,event,camera:cameraNow(),canvas,snap});if(!anchor||isClipped(world(anchor)))return false;
  const previous=pending.at(-1);if(previous&&world(previous).distanceToSquared(world(anchor))<=1e-16){if(mode==='path'&&event.detail>=2)return finish();return true}
  pending.push(anchor);if((mode==='distance'&&pending.length===2)||(mode==='angle'&&pending.length===3)){
   if(mode==='angle'&&(!Number.isFinite(measure({mode,points:pending}))||world(pending[0]).distanceToSquared(world(pending[2]))<=1e-16)){pending.pop();status(translate('measurementInvalidAngle'));notify();return true}addObject();
  }else if(mode==='path'&&event.detail>=2)finish();else{update();notify();prompt()}return true;
 }
 function hideMenu(){menu?.remove();menu=null}
 function showMenu(event,id){event.preventDefault();event.stopPropagation();hideMenu();selectedID=id;refresh();menu=document.createElement('div');menu.className='measurement-context';menu.dataset.measureContext=String(id);menu.setAttribute('role','menu');const del=button('delete','measurementDelete',()=>remove(id));del.setAttribute('role','menuitem');const text=document.createElement('span');text.textContent=translate('measurementDelete');del.append(text);menu.append(del);document.body.append(menu);const w=document.defaultView?.innerWidth||1920,h=document.defaultView?.innerHeight||1080;menu.style.left=`${Math.max(8,Math.min(event.clientX,w-220))}px`;menu.style.top=`${Math.max(8,Math.min(event.clientY,h-60))}px`;del.focus();notify()}
 const outside=event=>{if(menu&&!menu.contains(event.target))hideMenu()};document.addEventListener('pointerdown',outside);
 function select(id,{focus=true}={}){const object=objects.find(o=>o.id===Number(id));if(!object)return false;selectedID=object.id;if(focus){object.visible=true;const box=new T.Box3().setFromPoints(pointsOf(object));if(box.getSize(new T.Vector3()).lengthSq()<1e-12)box.expandByScalar(Math.max(getRadius()*.05,1));fitBox(box)}update();notify();return true}
 function deselect(){if(selectedID===null&&!menu)return;selectedID=null;hideMenu();update();notify()}
 function handleContextMenu(event){
  const cam=cameraNow();if(!cam||!Number.isFinite(event.clientX)||!Number.isFinite(event.clientY))return false;
  cam.updateMatrixWorld();const rect=canvas.getBoundingClientRect();let nearest=null,best=9;
  const project=point=>{const p=point.clone().project(cam);return {x:rect.left+(p.x*.5+.5)*rect.width,y:rect.top+(-p.y*.5+.5)*rect.height,z:p.z}};
  for(const object of objects){if(!object.visible||!object.visual.node.visible)continue;const worldPoints=pointsOf(object);const lines=[worldPoints];if(object.arc){const arc=arcPoints(worldPoints);if(arc.arc)lines.push(arc.arc)}
   for(const line of lines){const pts=line.map(project);for(let i=0;i<pts.length;i++){const a=pts[i];if(a.z< -1||a.z>1)continue;let distance=Math.hypot(event.clientX-a.x,event.clientY-a.y);if(i+1<pts.length){const b=pts[i+1];if(b.z>=-1&&b.z<=1){const dx=b.x-a.x,dy=b.y-a.y,length=dx*dx+dy*dy;const u=length?Math.max(0,Math.min(1,((event.clientX-a.x)*dx+(event.clientY-a.y)*dy)/length)):0;distance=Math.min(distance,Math.hypot(event.clientX-a.x-u*dx,event.clientY-a.y-u*dy))}}
    if(distance<=best){nearest=object;best=distance}
   }}
  }
  if(!nearest)return false;showMenu(event,nearest.id);return true;
 }
 function remove(id){const index=objects.findIndex(o=>o.id===Number(id));if(index<0)return false;const [object]=objects.splice(index,1);disposeVisual(object.visual);if(object.arc)disposeVisual(object.arc);object.el.remove();if(selectedID===object.id)selectedID=null;hideMenu();notify();return true}
 function clear(){for(const object of [...objects])remove(object.id);cancelPending();selectedID=null;hideMenu();notify()}
 function cancelPending(){if(!pending.length)return;pending.length=0;preview.node.visible=false;notify();prompt()}
 function setMode(next){if(!modes.includes(next))return false;if(mode!==next)cancelPending();mode=next;setActive(true);return true}
 function setActive(next,nextMode){if(active===!!next&&(!modes.includes(nextMode)||mode===nextMode)&&(!pending.length||next))return active;if(modes.includes(nextMode)&&nextMode!==mode){pending.length=0;mode=nextMode}active=!!next;if(!active)pending.length=0;preview.node.visible=false;hideMenu();notify();prompt();return active}
 function setSnap(next){snap=!!next;notify()}
 function toggleAll(){const show=!objects.some(o=>o.visible);for(const object of objects)object.visible=show;update();notify()}
 function disposeRemovedMeshes(){const current=new Set(getMeshes());for(const object of [...objects])if(object.points.some(p=>!current.has(p.mesh)))remove(object.id);if(pending.some(p=>!current.has(p.mesh)))cancelPending();if(!current.size)setActive(false);update()}
 function refresh(){if(disposed)return;toolbar.hidden=!active&&!selectedID&&!pending.length;toolbar.setAttribute('aria-label',translate('measurementList'));toolbar.dataset.tooltip=translate('measurementAccuracy');heading.textContent=translate('measurementList');
  for(const action of Object.keys(toolButtons))describe(toolButtons[action],action==='visibility'?(objects.some(o=>o.visible)?'measurementHideAll':'measurementShowAll'):keyNames[action]);for(const action of modes)toolButtons[action].setAttribute('aria-pressed',String(active&&mode===action));toolButtons.snap.setAttribute('aria-pressed',String(snap));toolButtons.finish.disabled=mode!=='path'||pending.length<2;toolButtons.cancel.disabled=!pending.length;toolButtons.delete.disabled=!selectedID;toolButtons.visibility.disabled=!objects.length;
  list.replaceChildren();sidebar.hidden=!objects.length;for(const object of objects){const row=document.createElement('div');row.className='measurement-row'+(selectedID===object.id?' selected':'');row.dataset.measureId=String(object.id);row.addEventListener('contextmenu',event=>showMenu(event,object.id));const focus=button('focus','measurementFocus',()=>select(object.id));focus.className='measurement-focus';focus.innerHTML=icon(iconNames[object.mode]);const caption=document.createElement('span');caption.className='measurement-name';caption.textContent=name(object);const value=document.createElement('span');value.className='measurement-value';value.textContent=valueText(object);caption.append(value);focus.append(caption);focus.setAttribute('aria-pressed',String(selectedID===object.id));const eye=button('visibility',object.visible?'measurementVisible':'measurementHidden',()=>{object.visible=!object.visible;update();notify()});eye.innerHTML=icon(object.visible?'eye':'eyeOff');eye.setAttribute('aria-pressed',String(object.visible));row.append(focus,eye);list.append(row);object.el.classList.toggle('selected',selectedID===object.id);describe(object.el,'measurementFocus');object.el.setAttribute('aria-label',`${name(object)}: ${valueText(object)} · ${translate('measurementFocus')}`);object.el.dataset.tooltip=object.el.getAttribute('aria-label')}
 }
 function update(){if(disposed)return;const cam=cameraNow();if(!cam)return;cam.updateMatrixWorld();const rect=canvas.getBoundingClientRect(),parentRect=container.getBoundingClientRect();const current=new Set(getMeshes());
  for(const object of objects){const points=pointsOf(object),show=object.visible&&object.points.every(p=>current.has(p.mesh)&&anchorVisible(p));object.visual.node.visible=show;if(object.arc)object.arc.node.visible=show;object.el.hidden=!show;if(!show)continue;
   renderVisual(object.visual,points,selectedID===object.id);if(object.arc){const arc=arcPoints(points);renderVisual(object.arc,arc.arc||[],selectedID===object.id)}
   object.value=measure(object);object.label=valueText(object);object.el.textContent=object.label;object.point=labelPosition(object,points);const projected=object.point.clone().project(cam);if(!Number.isFinite(projected.x)||!Number.isFinite(projected.y)||projected.z< -1||projected.z>1||Math.abs(projected.x)>1.1||Math.abs(projected.y)>1.1){object.el.hidden=true;continue}object.el.style.left=`${rect.left-parentRect.left+(projected.x*.5+.5)*rect.width}px`;object.el.style.top=`${rect.top-parentRect.top+(-projected.y*.5+.5)*rect.height}px`;
   const row=list.querySelector(`[data-measure-id="${object.id}"] .measurement-value`);if(row)row.textContent=object.label;
  }
  preview.node.visible=active&&pending.length>0&&pending.every(p=>current.has(p.mesh)&&anchorVisible(p));if(preview.node.visible)renderVisual(preview,pending.map(world));
 }
 function handleKey(event){if(disposed)return false;const target=event.target;if(target?.closest?.('input,textarea,select,[contenteditable="true"]'))return false;if(event.key==='Escape'){if(menu){hideMenu();return true}if(pending.length){cancelPending();return true}if(active){setActive(false);return true}if(selectedID){selectedID=null;notify();return true}return false}if(!active&& !selectedID)return false;if(event.key==='Enter'&&mode==='path'&&pending.length>=2){event.preventDefault?.();return finish()}if((event.key==='Delete'||event.key==='Backspace')&&selectedID){event.preventDefault?.();return remove(selectedID)}return false}
 function getState(){return {active,mode,snap,selectedID,pending:pending.map(p=>({...p,local:p.local.clone()})),objects:objects.map(o=>({id:o.id,mode:o.mode,visible:o.visible,points:o.points.map(p=>({...p,local:p.local.clone()})),value:measure(o),label:valueText(o)}))}}
 function getLabels(){return objects.map(o=>({el:o.el,kind:'measure',point:o.point?.clone(),value:measure(o)}))}
 function dispose(){if(disposed)return;clear();disposed=true;disposeVisual(preview);dotGeometry.dispose();group.removeFromParent();hideMenu();document.removeEventListener('pointerdown',outside);style.remove();if(ownToolbar)toolbar.remove();else toolbar.replaceChildren();if(ownSidebar)sidebar.remove();else{sidebar.replaceChildren();sidebar.hidden=true}}
 refresh();return {setActive,setMode,setSnap,handlePointer,handleKey,update,refresh,clear,cancelPending,disposeRemovedMeshes,dispose,hasObjects:()=>objects.length>0,select,deselect,remove,finish,toggleAll,getState,getLabels,handleContextMenu};
}
function visibleParents(object){for(let parent=object;parent;parent=parent.parent)if(!parent.visible)return false;return true}

// Pixel-space snap uses only the hit triangle; perspective-correct interpolation
// keeps edge anchors exactly on the original 3D segment, even with a perspective camera.
export function createMeasurementAnchor({THREE:T,hit,event,camera,canvas,snap=true,vertexRadius=12,edgeRadius=8}){
 const mesh=hit?.object;if(!mesh?.isMesh||!hit.point||!hit.point.toArray().every(Number.isFinite))return null;mesh.updateWorldMatrix(true,false);let point=hit.point.clone(),kind='surface';
 if(snap&&camera&&hit.face&&Number.isFinite(event?.clientX)&&Number.isFinite(event?.clientY)){
  camera.updateMatrixWorld();const rect=canvas.getBoundingClientRect(),position=mesh.geometry.getAttribute('position'),indices=[hit.face.a,hit.face.b,hit.face.c];
  if(position&&indices.every(i=>Number.isInteger(i)&&i>=0&&i<position.count)){
   const vertices=indices.map(i=>new T.Vector3().fromBufferAttribute(position,i).applyMatrix4(mesh.matrixWorld));const clip=vertices.map(p=>new T.Vector4(p.x,p.y,p.z,1).applyMatrix4(camera.matrixWorldInverse).applyMatrix4(camera.projectionMatrix));
   const projected=clip.map(p=>({x:rect.left+(p.x/p.w*.5+.5)*rect.width,y:rect.top+(-p.y/p.w*.5+.5)*rect.height,w:p.w}));let best=vertexRadius;
   projected.forEach((p,i)=>{const distance=Math.hypot(event.clientX-p.x,event.clientY-p.y);if(p.w>0&&distance<=best){best=distance;point.copy(vertices[i]);kind='vertex'}});
   if(kind==='surface'){best=edgeRadius;for(let i=0;i<3;i++){const j=(i+1)%3,a=projected[i],b=projected[j];if(a.w<=0||b.w<=0)continue;const dx=b.x-a.x,dy=b.y-a.y,denom=dx*dx+dy*dy;if(denom<1e-12)continue;const s=Math.max(0,Math.min(1,((event.clientX-a.x)*dx+(event.clientY-a.y)*dy)/denom));const distance=Math.hypot(event.clientX-a.x-s*dx,event.clientY-a.y-s*dy);if(distance<=best){const u=s*a.w/((1-s)*b.w+s*a.w);point.copy(vertices[i]).lerp(vertices[j],u);best=distance;kind='edge'}}}
  }
 }
 const determinant=mesh.matrixWorld.determinant();if(!Number.isFinite(determinant)||Math.abs(determinant)<1e-20)return null;const local=mesh.worldToLocal(point);if(!local.toArray().every(Number.isFinite))return null;return {mesh,local,snap:kind};
}
