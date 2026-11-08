// Camera-only drag on the view navigator. Face/edge/corner clicks remain owned by the host.
export function attachCubeNavigation({element,THREE:T,getCamera,controls,onChange=()=>{}}){
 if(!element||!T||typeof getCamera!=='function'||!controls?.target)throw new TypeError('Incomplete cube navigation host');
 let gesture=null,suppressClick=false,disposed=false;
 const doc=element.ownerDocument,previousTouchAction=element.style.touchAction;
 element.style.touchAction='none';
 function restoreControls(g){if(g?.dragged)controls.enabled=g.enabled}
 function release(g){try{if(element.hasPointerCapture?.(g.id))element.releasePointerCapture(g.id)}catch{}}
 function finish(cancelled=false){const g=gesture;if(!g)return;gesture=null;restoreControls(g);release(g);if(g.dragged){suppressClick=true;if(cancelled){g.camera.position.copy(g.position);g.camera.quaternion.copy(g.quaternion);g.camera.up.copy(g.up);g.camera.updateMatrixWorld();onChange(g.camera)}}}
 function down(event){
  if(disposed||gesture||event.button!==0||event.isPrimary===false||event.altKey||event.ctrlKey||event.metaKey||event.shiftKey)return;
  const camera=getCamera(),target=controls.target;if(!camera?.position||!target)return;
  const offset=camera.position.clone().sub(target),distance=offset.length();if(!Number.isFinite(distance)||distance<=1e-9)return;
  const rect=element.getBoundingClientRect();suppressClick=false;
  gesture={id:event.pointerId??1,x:event.clientX,y:event.clientY,camera,target:target.clone(),position:camera.position.clone(),quaternion:camera.quaternion.clone(),up:camera.up.clone(),distance,yaw:Math.atan2(offset.y,offset.x),pitch:Math.asin(T.MathUtils.clamp(offset.z/distance,-1,1)),width:Math.max(rect.width||100,40),height:Math.max(rect.height||100,40),enabled:controls.enabled,dragged:false};
 }
 function move(event){
  const g=gesture;if(!g||(event.pointerId??1)!==g.id)return;
  if(getCamera()!==g.camera){finish(true);return}
  const dx=event.clientX-g.x,dy=event.clientY-g.y;if(!Number.isFinite(dx)||!Number.isFinite(dy))return;
  if(!g.dragged){if(Math.hypot(dx,dy)<4)return;g.dragged=true;controls.enabled=false;try{element.setPointerCapture?.(g.id)}catch{}}
  event.preventDefault();event.stopPropagation();
  const limit=Math.PI/2-1e-4,yaw=g.yaw-dx/g.width*Math.PI*2,pitch=T.MathUtils.clamp(g.pitch+dy/g.height*Math.PI,-limit,limit),horizontal=g.distance*Math.cos(pitch);
  g.camera.position.set(g.target.x+horizontal*Math.cos(yaw),g.target.y+horizontal*Math.sin(yaw),g.target.z+g.distance*Math.sin(pitch));g.camera.up.set(0,0,1);g.camera.lookAt(g.target);g.camera.updateMatrixWorld();onChange(g.camera);
 }
 function up(event){if(gesture&&(event.pointerId??1)===gesture.id)finish(false)}
 function cancelled(event){if(gesture&&(event.pointerId??1)===gesture.id)finish(true)}
 function key(event){if(event.key==='Escape'&&gesture){event.preventDefault();finish(true)}}
 function click(event){if(suppressClick&&event.detail!==0){suppressClick=false;event.preventDefault();event.stopImmediatePropagation()}}
 function lost(event){if(gesture?.dragged&&(event.pointerId??1)===gesture.id)finish(true)}
 element.addEventListener('pointerdown',down);doc.addEventListener('pointermove',move);element.addEventListener('pointerup',up);element.addEventListener('pointercancel',cancelled);element.addEventListener('lostpointercapture',lost);element.addEventListener('click',click,true);doc.addEventListener('keydown',key);doc.addEventListener('pointerup',up);doc.addEventListener('pointercancel',cancelled);
 return {cancel:()=>finish(true),dispose(){if(disposed)return;finish(true);disposed=true;element.removeEventListener('pointerdown',down);doc.removeEventListener('pointermove',move);element.removeEventListener('pointerup',up);element.removeEventListener('pointercancel',cancelled);element.removeEventListener('lostpointercapture',lost);element.removeEventListener('click',click,true);doc.removeEventListener('keydown',key);doc.removeEventListener('pointerup',up);doc.removeEventListener('pointercancel',cancelled);element.style.touchAction=previousTouchAction}};
}
