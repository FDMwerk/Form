import {attachCubeNavigation} from '../cube-navigation.js';
import {createMeasurementTools} from '../measurement-tools.js';
import {createSectionHighlight} from '../section-highlight.js';
import {createViewportDisplay,createViewportCameras} from '../viewport-display.js';
import {measureMeshes} from '../mesh-metrics.js';
import {estimatePrint,materialProfiles} from '../print-estimate.js';
// Executes the actual viewer source and event handlers with a real Three.js scene.
// WebGL and native window services are substituted; this is logic QA, not GPU/UI QA.
import {createI18n,languageCodes} from '../i18n.js';
import fs from 'node:fs';import vm from 'node:vm';
import {parseHTML,DOMParser} from 'linkedom';import * as Three from 'three';import * as Lucide from 'lucide';
import {STLLoader} from 'three/addons/loaders/STLLoader.js';import {OBJLoader} from 'three/addons/loaders/OBJLoader.js';import {PLYLoader} from 'three/addons/loaders/PLYLoader.js';import {ThreeMFLoader} from 'three/addons/loaders/3MFLoader.js';import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';import {toCreasedNormals} from 'three/addons/utils/BufferGeometryUtils.js';import {unzipSync,strFromU8} from 'three/addons/libs/fflate.module.js';import {navigationProfiles,navigationAction,orbitBinding} from '../navigation.js';
export function createViewerHarness(){
 const {document,window:domWindow}=parseHTML(fs.readFileSync('Resources/Web/index.html','utf8'));
 if(!domWindow.HTMLElement.prototype.getBoundingClientRect)domWindow.HTMLElement.prototype.getBoundingClientRect=function(){return {left:100,right:140,top:100,bottom:132,width:40,height:32}};
 let activeElement=document.body;Object.defineProperty(document,'activeElement',{configurable:true,get:()=>activeElement});domWindow.HTMLElement.prototype.focus=function(){if(activeElement!==this){activeElement?.dispatchEvent(new domWindow.Event('focusout',{bubbles:true}));activeElement=this;this.dispatchEvent(new domWindow.Event('focusin',{bubbles:true}))}};
 globalThis.document=document;globalThis.DOMParser=DOMParser;globalThis.ProgressEvent??=class{constructor(type,properties){this.type=type;Object.assign(this,properties)}};
 for(const element of document.querySelectorAll('select,input')){
  let current=element.getAttribute('value')??(element.tagName==='SELECT'?(element.querySelector('option[selected]')||element.querySelector('option'))?.getAttribute('value'):'')??'';
  Object.defineProperty(element,'value',{configurable:true,get:()=>current,set:value=>{current=String(value)}});
  if(element.tagName==='SELECT')Object.defineProperty(element,'options',{configurable:true,get:()=>[...element.querySelectorAll('option')]});
  if(element.getAttribute('type')==='checkbox')element.checked=element.hasAttribute('checked');
 }
 for(const dialog of document.querySelectorAll('dialog')){dialog.showModal=()=>{dialog.open=true};dialog.close=()=>{dialog.open=false}}
 class WebGLRenderer{constructor(){this.domElement=document.createElement('canvas');this.shadowMap={};this.domElement.getBoundingClientRect=()=>({left:0,top:0,width:800,height:600});}setPixelRatio(){}setClearColor(){}setSize(){}render(){}}
 class PMREMGenerator{fromScene(){return {texture:new Three.Texture()}}dispose(){}}
 class RoomEnvironment{dispose(){}}
 class OrbitControls{constructor(camera,element){this.target=new Three.Vector3();this.mouseButtons={};this.enableRotate=true;this.enabled=true;}update(){}}
 class TransformControls extends Three.EventDispatcher{constructor(){super();this.dragging=false;this.helper=new Three.Group();this.object=null}setSpace(){}getHelper(){return this.helper}attach(object){this.object=object}detach(){this.object=null}setMode(mode){this.mode=mode}}
 const frameCallbacks=[],messages=[],window={innerWidth:1200,innerHeight:800,addEventListener:domWindow.addEventListener.bind(domWindow),webkit:{messageHandlers:{native:{postMessage:message=>messages.push(message)}}}};
 const context=vm.createContext({console,crypto,attachCubeNavigation,createMeasurementTools,createSectionHighlight,createViewportDisplay,createViewportCameras,measureMeshes,estimatePrint,materialProfiles,createI18n,languageCodes,T:{...Three,WebGLRenderer,PMREMGenerator},document,window,innerWidth:1200,innerHeight:800,MutationObserver:domWindow.MutationObserver,devicePixelRatio:1,OrbitControls,TransformControls,RoomEnvironment,ResizeObserver:class{observe(){}},requestAnimationFrame:callback=>frameCallbacks.push(callback),setTimeout:callback=>setTimeout(callback,0),clearTimeout,atob,btoa,Uint8Array,ArrayBuffer,DataView,TextDecoder,TextEncoder,DOMParser,...Lucide,Infinity:Number.POSITIVE_INFINITY,Map,Set,STLLoader,OBJLoader,PLYLoader,ThreeMFLoader,GLTFLoader,toCreasedNormals,unzipSync,strFromU8,navigationProfiles,navigationAction,orbitBinding});
 const source=fs.readFileSync('viewer.js','utf8').replace(/^import .*;\n/gm,'');vm.runInContext(source,context,{filename:'viewer.js'});
 const read=expression=>vm.runInContext(expression,context);
 const evaluate=code=>vm.runInContext(code,context);
 const click=selector=>{const element=document.querySelector(selector);if(!element)throw Error('Missing '+selector);element.dispatchEvent(new domWindow.Event('click',{bubbles:true}));};
 const input=(selector,value)=>{const element=document.querySelector(selector);element.value=value;element.oninput?.({target:element})};
 const change=(selector,value)=>{const element=document.querySelector(selector);element.value=value;element.onchange?.({target:element})};
 const load=async(file,name=file.split('/').pop(),sourceID=null)=>window.openModel(name,fs.readFileSync(file).toString('base64'),sourceID);
 const key=(key,target=document.body,properties={})=>{const event=new domWindow.Event('keydown',{bubbles:true,cancelable:true});Object.assign(event,{key,...properties});target.dispatchEvent(event)};
 const frame=()=>{for(const callback of frameCallbacks.splice(0))callback()};
 return {context,document,window,messages,read,evaluate,click,input,change,load,key,domWindow,frame};
}
