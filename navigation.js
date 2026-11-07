// Fundamental mouse gestures, based on the applications' published navigation guides.
export const navigationProfiles={
 bambu:{name:'Bambu Studio',hint:'Drehen: links ziehen · Verschieben: rechts oder mittig ziehen · Zoom: Mausrad'},
 fusion:{name:'Autodesk Fusion 360',hint:'Drehen: Umschalt + mittlere Maustaste · Verschieben: mittlere Maustaste · Zoom: Mausrad'},
 blender:{name:'Blender',hint:'Drehen: mittlere Maustaste · Verschieben: Umschalt + mittlere Maustaste · Zoom: Mausrad oder Strg + mittlere Maustaste'},
 solidworks:{name:'SOLIDWORKS',hint:'Drehen: mittlere Maustaste · Verschieben: Strg + mittlere Maustaste · Zoom: Mausrad oder Umschalt + mittlere Maustaste'},
 onshape:{name:'Onshape',hint:'Drehen: rechts ziehen · Verschieben: mittlere Maustaste oder Strg + rechts · Zoom: Mausrad'}
};
export function navigationAction(preset,button,{shiftKey:shift=false,ctrlKey:ctrl=false,metaKey:meta=false}={}){
 const mod=ctrl||meta;
 if(preset==='fusion')return button===1?(shift?'rotate':'pan'):null;
 if(preset==='blender')return button===1?(shift?'pan':mod?'zoom':'rotate'):null;
 if(preset==='solidworks')return button===1?(shift?'zoom':mod?'pan':'rotate'):null;
 if(preset==='onshape')return button===2?(mod?'pan':'rotate'):button===1?'pan':null;
 return button===0?(shift?'pan':'rotate'):(button===1||button===2)?'pan':null;
}
export function orbitBinding(action,event){if(action==='zoom')return 1;if(!action)return -1;const swapped=event.shiftKey||event.ctrlKey||event.metaKey;return action==='rotate'?(swapped?2:0):(swapped?0:2)}
