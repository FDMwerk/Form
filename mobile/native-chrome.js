/* Native UIKit owns the primary controls; the web layer remains the model workspace. */
(() => {
  const ids = ['side','open','info','open-with','fit','measure','cut','screenshot','palette','grid','apple','selection-box-toggle','dimensions','clear','translate','rotate','explode','undo','scene-settings','settings','legal','feedback','display-menu','background-menu','unit'];
  const sendState = () => {
    const controls = {};
    for (const id of ids) {
      const el = document.getElementById(id); if (!el) continue;
      controls[id] = {label: el.getAttribute('aria-label') || el.title || el.textContent.trim(), enabled: !el.disabled, active: el.classList.contains('active') || el.getAttribute('aria-pressed') === 'true'};
    }
    controls.open.label = document.querySelector('#open [data-i18n]')?.textContent.trim() || controls.open.label;
    const german = document.documentElement.lang.startsWith('de');
    controls['view-tools']={label:german?'Ansicht':'View',enabled:true};
    controls['measurement-tools']={label:german?'Messoptionen':'Measurement options',enabled:true};
    controls['model-tools']={label:german?'Modellwerkzeuge':'Model tools',enabled:true};
    const hasModels = document.getElementById('empty')?.hidden === true;
    for(const id of ['fit','measure','cut','dimensions','selection-box-toggle','translate','rotate','explode','info','scene-settings']) controls[id].enabled = controls[id].enabled && hasModels;
    controls['model-tools'].enabled = hasModels;
    controls.side.active = !document.body.classList.contains('collapsed');
    controls.info.active = document.body.classList.contains('inspecting');
    const words = {de:['Mehr','3DBenchy öffnen','Teilen'],en:['More','Open 3DBenchy','Share'],zh:['更多','打开 3DBenchy','共享'],ja:['その他','3DBenchy を開く','共有'],hi:['और','3DBenchy खोलें','साझा करें'],ru:['Ещё','Открыть 3DBenchy','Поделиться']};
    const language = (document.documentElement.lang || 'en').split('-')[0], labels = words[language] || words.en;
    controls.more = {label:labels[0],enabled:true}; controls.openExample = {label:labels[1],enabled:true};
    controls['open-with'].label = labels[2];
    window.webkit?.messageHandlers.native.postMessage({type:'mobileChromeState',state:{sidebar:window.formMobileSidebarSnapshot?.() || {},title:document.getElementById('filename')?.textContent || '',language:document.documentElement.lang,controls,unit:document.getElementById('unit')?.value,units:[...document.querySelectorAll('#unit option')].map(o=>({value:o.value,label:o.textContent}))}});
  };
  window.formMobileCommand = command => {
    if (command === 'openExample') { window.webkit?.messageHandlers.native.postMessage(command); return; }
    if (command.startsWith('unit:')) { const el=document.getElementById('unit'); const value=command.slice(5); if (el && [...el.options].some(o=>o.value===value)) { el.value=value;el.dispatchEvent(new Event('change',{bubbles:true})); } }
    else if(command==='model-tools') document.getElementById('info')?.click();
    else if (ids.includes(command)) document.getElementById(command)?.click();
    sendState();
  };
  const addPanelCloses = () => {
    for(const [panelID,command] of [['display-panel','display-menu'],['background-panel','background-menu'],['scene-settings-panel','scene-settings']]) {
      const panel=document.getElementById(panelID);
      if(!panel || panel.querySelector('.mobile-subpanel-close')) continue;
      const close=document.createElement('button');close.type='button';close.className='mobile-subpanel-close';
      close.setAttribute('aria-label',document.querySelector('#settings-close')?.getAttribute('aria-label') || 'Close');
      const icon=document.querySelector('#settings-close svg');if(icon)close.append(icon.cloneNode(true));else close.textContent='×';
      close.onclick=()=>document.getElementById(command)?.click();panel.prepend(close);
    }
  };
  addPanelCloses();
  document.documentElement.dataset.nativeChrome = 'true';
  let timer;
  new MutationObserver(() => {addPanelCloses();clearTimeout(timer);timer=setTimeout(sendState,80);}).observe(document.body,{subtree:true,childList:true,characterData:true,attributes:true,attributeFilter:['class','disabled','aria-pressed','aria-label','title','hidden']});
  document.addEventListener('change',sendState);
  sendState();
})();
