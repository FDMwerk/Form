(() => {
 window.formMobileSidebarSnapshot = () => ({rows:[
  {id:'all',kind:'all',name:document.querySelector('.scene-select')?.textContent || '',selected:document.querySelector('.scene-row')?.getAttribute('aria-selected')==='true'},
  ...[...document.querySelectorAll('#parts .partrow')].map(row=>({id:row.dataset.nodeId,kind:'model',name:row.querySelector('.part-name')?.textContent,badge:row.querySelector('.file-badge')?.textContent || '',depth:Number(row.getAttribute('aria-level'))-1,selected:row.getAttribute('aria-selected')==='true',visible:!row.classList.contains('tree-hidden'),expandable:row.hasAttribute('aria-expanded'),expanded:row.getAttribute('aria-expanded')==='true',removable:row.classList.contains('tree-root')})),
  ...[...document.querySelectorAll('.measurement-row')].map(row=>({id:'measurement:'+row.dataset.measureId,kind:'measurement',name:row.querySelector('.measurement-focus')?.textContent,selected:row.classList.contains('selected'),visible:row.querySelector('button:last-child')?.getAttribute('aria-pressed')!=='false',removable:true}))
 ]});
 window.formMobileSidebarAction=(action,id,multi=false)=>{
  if(id==='all'){document.querySelector('.scene-select')?.click();return;}
  const measure=id.startsWith('measurement:');
  const row=measure?[...document.querySelectorAll('.measurement-row')].find(r=>r.dataset.measureId===id.slice(12)):[...document.querySelectorAll('#parts .partrow')].find(r=>r.dataset.nodeId===id);
  if(!row)return;
  if(action==='expand'&&!measure)row.querySelector('button.tree-toggle')?.click();
  if(action==='select')row.querySelector(measure?'.measurement-focus':'.part')?.dispatchEvent(new MouseEvent('click',{bubbles:true,metaKey:multi}));
  if(action==='visibility')row.querySelector(measure?'button:last-child':'.visibility')?.click();
  if(action==='remove'&&measure){row.dispatchEvent(new MouseEvent('contextmenu',{bubbles:true,clientX:100,clientY:100}));document.querySelector('.measurement-context button')?.click();}
  if(action==='remove'&&!measure&&row.classList.contains('tree-root')){row.querySelector('.part')?.click();document.getElementById('remove')?.click();}
 };
 if(window.FORM_NATIVE_SIDEBAR){document.documentElement.dataset.nativeSidebar='true';document.body.classList.add('collapsed');}
 document.dispatchEvent(new Event('change'));
})();
