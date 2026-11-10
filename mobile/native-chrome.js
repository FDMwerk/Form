/* The native iOS UI reads one renderer snapshot; no native state depends on animation silence. */
(() => {
  const ids=['side','open','info','open-with','fit','measure','cut','screenshot','palette','grid','apple','selection-box-toggle','dimensions','clear','translate','rotate','explode','undo','scene-settings','settings','legal','feedback','display-menu','background-menu','unit'];
  const byID=id=>document.getElementById(id), german=()=>document.documentElement.lang.startsWith('de');
  const text=(de,en)=>german()?de:en;
  function label(el,fallback='') {
    if(!el)return fallback;
    const own=el.getAttribute('aria-label')||el.getAttribute('title');if(own)return own;
    const parent=el.closest('label');return parent?.querySelector('span[data-i18n]')?.textContent.trim()||parent?.textContent.trim()||el.textContent.trim()||fallback;
  }
  function ensureIDs(){
    const attributes=['display-mode','projection','background-preset','measure-action','nav-view','cut-axis'];
    for(const attribute of attributes)for(const el of document.querySelectorAll(attribute==='measure-action'?'#measurement-toolbar [data-measure-action]':`[data-${attribute}]`))if(!el.id)el.id=`native-${attribute}-${el.getAttribute('data-'+attribute)}`;
  }
  function descriptor(id,kind,title){
    const el=byID(id);if(!el)return null;
    const type=kind||(el.tagName==='SELECT'?'select':el.type==='checkbox'?'toggle':el.type==='range'?'range':el.type==='number'?'number':el.type==='color'?'color':'button');
    const item={id,title:title||label(el,id),kind:type,enabled:!el.disabled};
    if(type==='toggle')item.value=el.type==='checkbox'?el.checked:el.classList.contains('active')||el.getAttribute('aria-pressed')==='true';
    else if(['range','number'].includes(type)){item.value=Number(el.value);for(const key of ['min','max','step'])if(el.getAttribute(key)!==null)item[key]=Number(el.getAttribute(key));}
    else if(type==='select'){item.value=el.value;item.options=[...el.querySelectorAll('option')].map(o=>({value:o.value,title:o.textContent}));}
    else if(type==='color')item.value=el.value;
    else item.value=el.classList.contains('active')||el.getAttribute('aria-pressed')==='true';
    return item;
  }
  const items=values=>values.map(value=>typeof value==='string'?descriptor(value):descriptor(...value)).filter(Boolean);
  const section=(title,values,footer)=>({title,items:items(values),...(footer?{footer}: {})});
  const choice=(id,title,attribute)=>{
    const buttons=[...document.querySelectorAll(attribute==='measure-action'?'#measurement-toolbar [data-measure-action]':`[data-${attribute}]`)];
    return {id,title,kind:'select',enabled:true,value:buttons.find(b=>b.getAttribute('aria-pressed')==='true'||b.classList.contains('active'))?.getAttribute('data-'+attribute)||'',options:buttons.map(b=>({value:b.getAttribute('data-'+attribute),title:label(b,b.getAttribute('data-'+attribute))}))};
  };
  function panels(){
    ensureIDs();
    const view=section(text('Darstellung','Display'),[['grid','toggle'],['palette','toggle'],['apple','toggle'],'screenshot']);
    view.items.unshift(choice('native-projection',text('Projektion','Projection'),'projection'),choice('native-display-mode',text('Darstellung','Display'),'display-mode'));
    const orientations=section(text('Standardansicht','Standard view'),['view-home']);
    orientations.items.unshift(choice('native-standard-view',text('Ausrichtung','Orientation'),'nav-view'));
    const background=section(text('Hintergrund','Background'),['background-color']);background.items.unshift(choice('native-background-preset',text('Hintergrund','Background'),'background-preset'));
    const measurement=section(text('Messwerkzeuge','Measurement tools'),[['measure','toggle'],['native-measure-action-snap','toggle'],['dimensions','toggle'],['selection-box-toggle','toggle'],'native-measure-action-finish','native-measure-action-cancel','native-measure-action-delete','native-measure-action-visibility','unit']);
    measurement.items.splice(1,0,choice('native-measure-mode',text('Messart','Measurement mode'),'measure-action'));
    // Finish/delete are actions, never selectable measurement modes.
    measurement.items[1].options=measurement.items[1].options.filter(o=>['distance','path','angle'].includes(o.value));
    const result={
      view:{title:text('Ansicht','View'),sections:[view,orientations,background]},
      measurement:{title:text('Messen','Measure'),sections:[measurement]},
      section:{title:text('Schnitt','Section'),sections:[section(text('Schnittebene','Section plane'),[['cut','toggle'],'cut-axis','cut-value','cut-reverse'],document.querySelector('.section-note')?.getAttribute('aria-label')||'')]},
      model:{title:text('Modellwerkzeuge','Model tools'),sections:[section(text('Anordnen','Arrange'),['translate','rotate',['explode','toggle'],'explode-value','undo']),section(text('Position · mm','Position · mm'),[['pos-x','number','X'],['pos-y','number','Y'],['pos-z','number','Z']]),section(text('Andocken','Dock'),['dock-target','dock-axis','dock','remove'])]},
      appearance:{title:text('Farben & Texturen','Colors & textures'),sections:[section(text('Geltungsbereich','Scope'),['appearance-scope','scope-color','scope-textures','scope-palette','scope-reset'],byID('scope-note')?.textContent)]},
      settings:{title:text('Einstellungen','Settings'),sections:[section(text('Allgemein','General'),['language-select']),section(text('Navigation','Navigation'),['orbit-speed','zoom-speed','reverse-zoom']),section(text('Darstellung','Appearance'),['default-color','show-textures','component-colors','settings-reset'])]},
      print:{title:text('3D-Druck','3D printing'),sections:[section(text('Geometrische Schätzung','Geometric estimate'),['print-material','print-layer','print-infill','print-walls','print-nozzle','print-speed','print-flow','print-estimate'],document.querySelector('[data-i18n="printDisclaimer"]')?.textContent),{items:[{id:'native-print-result',kind:'note',title:byID('print-result')?.textContent||'',enabled:true}]}]}
    };
    // Semantic aliases used by the fully native navigation routes.
    result.display={title:text('Darstellung','Display'),sections:[view,orientations]};
    result.background={title:text('Hintergrund','Background'),sections:[background]};
    result.measure=result.measurement;result.cut=result.section;
    result.position={title:text('Position & Andocken','Position & docking'),sections:result.model.sections.slice(1)};
    result.explode={title:text('Explosionsansicht','Exploded view'),sections:[section(text('Explosionsansicht','Exploded view'),[['explode','toggle'],'explode-value','undo'])]};
    return result;
  }
  function snapshot(){
    ensureIDs();
    const controls={};for(const id of ids){const el=byID(id);if(!el)continue;controls[id]={label:label(el,id),enabled:!el.disabled,active:el.classList.contains('active')||el.getAttribute('aria-pressed')==='true'};}
    controls.open.label=document.querySelector('#open [data-i18n]')?.textContent.trim()||controls.open.label;
    const renderer=window.formRendererState?.();
    const hasModels=renderer?renderer.modelCount>0:byID('empty')?.hidden===true;
    for(const id of ['fit','measure','cut','dimensions','selection-box-toggle','translate','rotate','explode','info','scene-settings'])if(controls[id])controls[id].enabled=controls[id].enabled&&hasModels;
    for(const [id,title]of [['view-tools',text('Ansicht','View')],['measurement-tools',text('Messoptionen','Measurement options')],['model-tools',text('Modellwerkzeuge','Model tools')],['more',text('Mehr','More')],['openExample',text('3DBenchy öffnen','Open 3DBenchy')]])controls[id]={label:title,enabled:id!=='model-tools'||hasModels};
    controls['open-with'].label=text('Teilen','Share');controls.side.active=!document.body.classList.contains('collapsed');controls.info.active=document.body.classList.contains('inspecting');
    return {title:renderer?.title||byID('filename')?.textContent||'',hasModels,modelCount:renderer?.modelCount??document.querySelectorAll('#parts .tree-root').length,selectedSourceID:window.selectedSourceID?.()||null,language:document.documentElement.lang,controls,sidebar:window.formMobileSidebarSnapshot?.()||{},unit:byID('unit')?.value,units:[...document.querySelectorAll('#unit option')].map(o=>({value:o.value,label:o.textContent})),panels:panels(),information:{title:controls.info.label,note:byID('volume-note')?.textContent||'',rows:[...document.querySelectorAll('#file-info .info-row')].map(row=>({label:row.firstElementChild.textContent,value:row.lastElementChild.textContent}))},status:{text:byID('status')?.textContent||'',error:byID('status')?.classList.contains('error')||false}};
  }
  let timer=null,lastSerialized='';
  function sendState(){if(timer!==null)clearTimeout(timer);timer=null;const state=snapshot(),serialized=JSON.stringify(state);if(serialized===lastSerialized)return;lastSerialized=serialized;window.webkit?.messageHandlers.native.postMessage({type:'mobileChromeState',state});}
  function scheduleState(){if(timer===null)timer=setTimeout(sendState,80);}
  function click(id){ensureIDs();const el=byID(id);if(!el||el.disabled)return false;el.click();sendState();return true;}
  function set(id,value){
    ensureIDs();
    const mappings={'native-display-mode':'display-mode','native-projection':'projection','native-background-preset':'background-preset','native-measure-mode':'measure-action','native-standard-view':'nav-view'};
    if(mappings[id]){const el=[...document.querySelectorAll(`[data-${mappings[id]}]`)].find(b=>b.getAttribute('data-'+mappings[id])===String(value));return el?click(el.id):false;}
    const el=byID(id);if(!el||el.disabled)return false;
    if(el.tagName==='BUTTON'){const active=el.classList.contains('active')||el.getAttribute('aria-pressed')==='true';return active===Boolean(value)?true:click(id);}
    if(el.type==='checkbox')el.checked=Boolean(value);
    else if(el.tagName==='SELECT'){if(![...el.querySelectorAll('option')].some(o=>o.value===String(value)))return false;el.value=String(value);}
    else if(['number','range'].includes(el.type)){let number=Number(value);if(!Number.isFinite(number))return false;const min=el.getAttribute('min'),max=el.getAttribute('max');if(min!==null)number=Math.max(Number(min),number);if(max!==null)number=Math.min(Number(max),number);el.value=String(number);}
    else if(el.type==='color'){if(!/^#[0-9a-f]{6}$/i.test(String(value)))return false;el.value=String(value);}
    else return false;
    el.dispatchEvent(new Event('input',{bubbles:true}));el.dispatchEvent(new Event('change',{bubbles:true}));sendState();return true;
  }
  function command(id){if(id==='openExample'){window.webkit?.messageHandlers.native.postMessage(id);return true;}if(id.startsWith('unit:'))return set('unit',id.slice(5));return click(id==='model-tools'?'info':id);}
  window.formNative={snapshot,command,set,click,sidebarAction:(...args)=>{const result=window.formMobileSidebarAction?.(...args);sendState();return result;},notify:sendState};
  window.formMobileCommand=command;
  document.documentElement.dataset.nativeChrome='true';
  new MutationObserver(records=>{if(records.some(record=>!record.target.closest?.('#view-navigator')))scheduleState();}).observe(document.body,{subtree:true,childList:true,characterData:true,attributes:true,attributeFilter:['class','disabled','aria-pressed','aria-label','title','hidden']});
  document.addEventListener('change',sendState);document.addEventListener('form-renderer-state',sendState);
  sendState();
})();
