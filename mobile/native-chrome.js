/* Native UIKit owns the primary controls; the web layer remains the model workspace. */
(() => {
  const ids = ['side','open','info','open-with','fit','measure','cut','screenshot','palette','grid','apple','selection-box-toggle','dimensions','clear','translate','rotate','explode','undo','scene-settings','settings','legal','feedback','display-menu','background-menu','unit'];
  const sendState = () => {
    const controls = {};
    for (const id of ids) {
      const el = document.getElementById(id); if (!el) continue;
      controls[id] = {label: el.getAttribute('aria-label') || el.title || el.textContent.trim(), enabled: !el.disabled, active: el.classList.contains('active') || el.getAttribute('aria-pressed') === 'true'};
    }
    controls.side.active = !document.body.classList.contains('collapsed');
    controls.info.active = document.body.classList.contains('inspecting');
    const words = {de:['Mehr','3DBenchy öffnen','Teilen'],en:['More','Open 3DBenchy','Share'],zh:['更多','打开 3DBenchy','共享'],ja:['その他','3DBenchy を開く','共有'],hi:['और','3DBenchy खोलें','साझा करें'],ru:['Ещё','Открыть 3DBenchy','Поделиться']};
    const language = (document.documentElement.lang || 'en').split('-')[0], labels = words[language] || words.en;
    controls.more = {label:labels[0],enabled:true}; controls.openExample = {label:labels[1],enabled:true};
    controls['open-with'].label = labels[2];
    window.webkit?.messageHandlers.native.postMessage({type:'mobileChromeState',state:{title:document.getElementById('filename')?.textContent || '',language:document.documentElement.lang,controls,unit:document.getElementById('unit')?.value,units:[...document.querySelectorAll('#unit option')].map(o=>({value:o.value,label:o.textContent}))}});
  };
  window.formMobileCommand = command => {
    if (command === 'openExample') { window.webkit?.messageHandlers.native.postMessage(command); return; }
    if (command.startsWith('unit:')) { const el=document.getElementById('unit'); const value=command.slice(5); if (el && [...el.options].some(o=>o.value===value)) { el.value=value;el.dispatchEvent(new Event('change',{bubbles:true})); } }
    else if (ids.includes(command)) document.getElementById(command)?.click();
    sendState();
  };
  document.documentElement.dataset.nativeChrome = 'true';
  let timer;
  new MutationObserver(() => {clearTimeout(timer);timer=setTimeout(sendState,80);}).observe(document.body,{subtree:true,childList:true,characterData:true,attributes:true,attributeFilter:['class','disabled','aria-pressed','aria-label','title','hidden']});
  document.addEventListener('change',sendState);
  sendState();
})();
