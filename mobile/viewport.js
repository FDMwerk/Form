/* Mobile-only progressive adapter. The desktop resource and controls stay shared. */
(() => {
  function createTouchTracker() {
    const active = new Map(), navigating = new Set();
    return {
      down(event) {
        if (event.pointerType !== 'touch') return;
        active.set(event.pointerId, [event.clientX, event.clientY]);
        if (active.size > 1) for (const id of active.keys()) navigating.add(id);
      },
      move(event) {
        const start = active.get(event.pointerId);
        if (start && Math.hypot(event.clientX - start[0], event.clientY - start[1]) > 5) navigating.add(event.pointerId);
      },
      up(event) {
        active.delete(event.pointerId);
        // Use a new task: native WebKit may run microtasks between event listeners.
        // Keep the flag through all pointerup listeners (measurement and selection).
        setTimeout(() => { if (!active.size) navigating.clear(); }, 0);
      },
      isNavigationGesture(event) { return event.pointerType === 'touch' && navigating.has(event.pointerId); },
      reset() { active.clear(); navigating.clear(); }
    };
  }
  globalThis.FormMobileTouchTracker = createTouchTracker;
  if (typeof document === 'undefined') return;
  const boot = () => {
    if (window.formMobileInput) return;
    document.documentElement.dataset.formMobile = 'true';
    const viewport = document.querySelector('meta[name="viewport"]');
    viewport?.setAttribute('content', 'width=device-width,initial-scale=1,viewport-fit=cover');
    const tracker = createTouchTracker();
    window.formMobileInput = tracker;
    const canvas = document.querySelector('#canvas canvas');
    if (canvas) {
      canvas.addEventListener('pointerdown', e => tracker.down(e), true);
      canvas.addEventListener('pointermove', e => tracker.move(e), true);
      canvas.addEventListener('pointerup', e => tracker.up(e), true);
      canvas.addEventListener('pointercancel', e => tracker.up(e), true);
    }
    window.addEventListener('blur', () => tracker.reset());
    const body = document.body, sidebar = document.querySelector('aside');
    const compact = matchMedia('(max-width: 999px)');
    if (compact.matches) body.classList.add('collapsed');
    const words = {
      de: ['Schließen', 'Ein Finger dreht · Zwei Finger verschieben und zoomen · Zum Messen tippen'],
      en: ['Close', 'Drag to rotate · Two fingers to pan and zoom · Tap to measure'],
      zh: ['关闭', '单指旋转 · 双指平移和缩放 · 轻点测量'],
      ja: ['閉じる', '1本指で回転 · 2本指で移動とズーム · タップして測定'],
      hi: ['बंद करें', 'एक उंगली से घुमाएँ · दो से खिसकाएँ और ज़ूम करें · मापने के लिए टैप करें'],
      ru: ['Закрыть', 'Один палец — вращение · Два — перемещение и масштаб · Касание — измерение']
    };
    const labels = () => words[(document.documentElement.lang || navigator.language).split('-')[0]] || words.en;
    const closeIcon = document.querySelector('#settings-close svg');
    function closeButton(parent, callback, className) {
      if (!parent) return;
      const button = document.createElement('button'); button.type = 'button'; button.className = className;
      if (closeIcon) button.append(closeIcon.cloneNode(true)); else button.textContent = '×';
      button.setAttribute('aria-label', labels()[0]); button.onclick = callback; parent.prepend(button); return button;
    }
    const sideClose = closeButton(sidebar, () => { body.classList.add('collapsed'); document.querySelector('#side')?.focus(); }, 'mobile-panel-close');
    const infoClose = closeButton(document.querySelector('#inspector'), () => document.querySelector('#info')?.click(), 'mobile-panel-close');
    const backdrop = document.createElement('button'); backdrop.type = 'button'; backdrop.id = 'mobile-panel-backdrop';
    backdrop.setAttribute('aria-label', labels()[0]); backdrop.onclick = () => {
      body.classList.add('collapsed'); if (body.classList.contains('inspecting')) document.querySelector('#info')?.click();
    }; body.append(backdrop);
    document.querySelector('#side')?.addEventListener('click', () => {
      if (!body.classList.contains('collapsed') && body.classList.contains('inspecting')) document.querySelector('#info')?.click();
    });
    document.querySelector('#info')?.addEventListener('click', () => { if (compact.matches) body.classList.add('collapsed'); });
    // Sidebar opening a native picker should not obscure the imported model afterward.
    for (const id of ['open', 'settings', 'legal', 'feedback']) document.getElementById(id)?.addEventListener('click', () => { if (compact.matches) body.classList.add('collapsed'); });
    const updateLabels = () => {
      for (const button of [sideClose, infoClose, backdrop]) button?.setAttribute('aria-label', labels()[0]);
      document.documentElement.dataset.mobileGestureHint = labels()[1];
      document.querySelector('#side')?.setAttribute('aria-expanded', String(!body.classList.contains('collapsed')));
    };
    new MutationObserver(updateLabels).observe(document.documentElement, {attributes:true, attributeFilter:['lang']});
    new MutationObserver(updateLabels).observe(body, {attributes:true, attributeFilter:['class']});
    updateLabels();
    // Deliberately do not change OrbitControls: one finger rotates, two pan/pinch.
    // The tracker prevents a navigation gesture ending as an extra measured point.
  };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', boot, {once:true}); else boot();
})();
