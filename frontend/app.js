(() => {
  const slides = [...document.querySelectorAll('.slide')];
  const dotsEl = document.getElementById('dots');
  const navLinks = [...document.querySelectorAll('.topbar ul a')];
  const progress = document.getElementById('progressBar');
  const presentBtn = document.getElementById('presentBtn');
  let current = 0;

  slides.forEach((s, i) => {
    const b = document.createElement('button');
    b.type = 'button';
    b.setAttribute('aria-label', `Ir a ${s.querySelector('h1,h2').textContent}`);
    b.addEventListener('click', () => go(i));
    dotsEl.appendChild(b);
    s.querySelectorAll('.layer,.card,.user,.tech,.timeline li,.diagram,.energy-compare,.sim,.matrix,.roadmap')
      .forEach(el => el.classList.add('reveal'));
  });
  const dots = [...dotsEl.children];

  function setActive(i) {
    current = i;
    dots.forEach((d, j) => d.classList.toggle('active', j === i));
    navLinks.forEach(a => a.classList.toggle('active', a.hash === '#' + slides[i].id));
    progress.style.width = `${((i + 1) / slides.length) * 100}%`;
    if (document.body.classList.contains('presenting')) {
      slides.forEach((s, j) => s.classList.toggle('current', j === i));
      slides[i].querySelectorAll('.reveal').forEach(el => el.classList.add('in-view'));
      slides[i].classList.add('in-view');
      document.querySelector("main").scrollTop = 0;
    }
  }

  function go(i) {
    i = Math.max(0, Math.min(slides.length - 1, i));
    if (document.body.classList.contains('presenting')) setActive(i);
    else slides[i].scrollIntoView({ behavior: 'smooth' });
  }

  const sectionObs = new IntersectionObserver(entries => {
    entries.forEach(e => {
      if (e.isIntersecting && !document.body.classList.contains('presenting')) setActive(slides.indexOf(e.target));
    });
  }, { threshold: 0.45 });
  slides.forEach(s => sectionObs.observe(s));

  const revealObs = new IntersectionObserver(entries => {
    entries.forEach(e => { if (e.isIntersecting) { e.target.classList.add('in-view'); revealObs.unobserve(e.target); } });
  }, { threshold: 0.15 });
  document.querySelectorAll('.reveal').forEach(el => revealObs.observe(el));

  function togglePresent(force) {
    const on = force ?? !document.body.classList.contains('presenting');
    document.body.classList.toggle('presenting', on);
    presentBtn.textContent = on ? '■ Salir' : '▶ Presentar';
    if (on) {
      setActive(current);
      document.documentElement.requestFullscreen?.().catch(() => {});
    } else {
      slides.forEach(s => s.classList.remove('current'));
      if (document.fullscreenElement) document.exitFullscreen?.();
      slides[current].scrollIntoView();
    }
  }
  presentBtn.addEventListener('click', () => togglePresent());
  document.addEventListener('fullscreenchange', () => {
    if (!document.fullscreenElement && document.body.classList.contains('presenting')) togglePresent(false);
  });

  document.addEventListener('keydown', e => {
    if (e.target.closest('input,textarea')) return;
    const k = e.key;
    if (k === 'p' || k === 'P') return togglePresent();
    if (k === 'Escape' && document.body.classList.contains('presenting')) return togglePresent(false);
    if (['ArrowRight', 'ArrowDown', 'PageDown', ' '].includes(k)) { e.preventDefault(); go(current + 1); }
    if (['ArrowLeft', 'ArrowUp', 'PageUp'].includes(k)) { e.preventDefault(); go(current - 1); }
    if (k === 'Home') go(0);
    if (k === 'End') go(slides.length - 1);
  });

  // Async sync simulator: tablet (SQLite) -> Valkey stream -> ODK Central
  const bT = document.getElementById('bTablet'), bQ = document.getElementById('bQueue'), bS = document.getElementById('bServer');
  const cT = document.getElementById('cTablet'), cQ = document.getElementById('cQueue'), cS = document.getElementById('cServer');
  const netBtn = document.getElementById('simNet');
  let n = 0, online = false, timer = null;

  const rec = id => { const d = document.createElement('div'); d.className = 'rec'; d.textContent = id; d.title = `instanceID uuid:${id}`; return d; };
  const count = () => {
    cT.textContent = `${bT.children.length} pendientes`;
    cQ.textContent = `${bQ.children.length} en cola`;
    cS.textContent = `${bS.children.length} almacenados`;
  };

  function tick() {
    if (online && bT.children.length) {
      [...bT.children].slice(0, 5).forEach(r => bQ.appendChild(rec(r.textContent)) && r.remove());
    } else if (bQ.children.length) {
      const r = bQ.firstElementChild; bS.appendChild(rec(r.textContent)); r.remove();
    }
    count();
    if (!bQ.children.length && !(online && bT.children.length)) { clearInterval(timer); timer = null; }
  }
  const run = () => { if (!timer) timer = setInterval(tick, 700); };

  document.getElementById('simCapture').addEventListener('click', () => { bT.appendChild(rec(++n)); count(); if (online) run(); });
  netBtn.addEventListener('click', () => {
    online = !online;
    netBtn.setAttribute('aria-pressed', online);
    netBtn.textContent = `Wi-Fi: ${online ? 'encendido' : 'apagado'}`;
    if (online) run();
  });
  document.getElementById('simReset').addEventListener('click', () => {
    [bT, bQ, bS].forEach(b => (b.innerHTML = '')); n = 0; count();
  });
  for (let i = 0; i < 3; i++) bT.appendChild(rec(++n));
  count();
})();
