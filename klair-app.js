/**
 * Klair web — functional mirror of iOS tabs + Ask Klair coach (same Gemini contract as app).
 */
;(function () {
  const SUGGESTED = [
    'Why is my HRV lower tonight?',
    'How did my Pilates class affect my sleep?',
    'How does my cycle affect recovery?',
    'What drains my energy the most?',
    'Are my lab results concerning for PCOS?',
    'What should I eat in my luteal phase?',
    'How much sleep debt do I have?',
  ]

  const TAB_META = [
    { id: 'home', label: 'PULSE', cssVar: '--klair-cyan' },
    { id: 'fuel', label: 'FUEL', cssVar: '--klair-emerald' },
    { id: 'sleep', label: 'SLEEP', cssVar: '--klair-indigo' },
    { id: 'move', label: 'MOVE', cssVar: '--klair-orange' },
    { id: 'ask', label: 'KLAIR', cssVar: '--klair-amethyst' },
    { id: 'vault', label: 'VAULT', cssVar: '--klair-cyan' },
  ]

  const ICONS = {
    home: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M7 2v11h3v9l7-12h-4l4-8H7z"/></svg>',
    fuel: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M17 8C8 10 5.9 16.17 3.82 21.34L5.71 22l1-2.26A9.5 9.5 0 0 0 12 16a9.5 9.5 0 0 0 5.29-3.74l1 2.26 1.89-.66C18.1 16.17 16 10 7 8V6h10v2z"/></svg>',
    sleep: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M9.5 2c-1.82 0-3.53.5-5 1.35 2.99 1.73 5 4.95 5 8.65s-2.01 6.92-5 8.65c1.47.85 3.18 1.35 5 1.35 5.52 0 10-4.48 10-10S15.02 2 9.5 2z"/></svg>',
    move: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M13.5 5.5c1.1 0 2-.9 2-2s-.9-2-2-2-2 .9-2 2 .9 2 2 2zM9.8 8.9L7 23h2.1l1.8-8 2.1 2v6h2v-7.5l-2.1-2 .6-3c1.1 1.5 2.8 2.5 4.7 2.5v-2c-1.9 0-3.5-1-4.3-2.4l-1-1.6c-.4-.6-1-1-1.7-1-.3 0-.5.1-.8.1L6 8.3V13h2V9.6l1.8-.7"/></svg>',
    ask: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2l2.4 7.2h7.6l-6 4.6 2.3 7.2-6.3-4.8-6.3 4.8 2.3-7.2-6-4.6h7.6z"/></svg>',
    vault: '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z"/></svg>',
  }

  const state = {
    data: null,
    contextString: '',
    tab: 'home',
    energyRating: 3,
    messages: [],
    sending: false,
  }

  function escapeHtml(s) {
    const d = document.createElement('div')
    d.textContent = s
    return d.innerHTML
  }

  function formatTime(d) {
    return d.toLocaleTimeString(undefined, { hour: 'numeric', minute: '2-digit', hour12: false })
  }

  function greeting(name) {
    const h = new Date().getHours()
    const first = name.split(/\s+/)[0] || 'there'
    const g = h < 12 ? 'Buenos días' : h < 18 ? 'Buenas tardes' : 'Buenas noches'
    return `${g}, ${first}`
  }

  function scoreColor(score) {
    if (score >= 85) return 'var(--klair-emerald)'
    if (score >= 70) return 'var(--klair-cyan)'
    if (score >= 55) return 'var(--klair-orange)'
    return 'var(--klair-coral)'
  }

  function seedChatFromDemo(data) {
    const lines = [
      `Good evening, Marta. I've been analyzing your biometrics and nutrition patterns. Here's what stands out today.`,
    ]
    for (const a of (data.healthAlerts || []).slice(0, 2)) {
      lines.push(`${a.title}\n\n${a.message}`)
    }
    state.messages = lines.map((text) => ({ role: 'assistant', text }))
  }

  function renderTabBar() {
    const bar = document.getElementById('klair-tab-bar')
    if (!bar) return
    bar.innerHTML = TAB_META.map(
      (t) => `
      <button type="button" class="klair-tab-btn ${state.tab === t.id ? 'is-active' : ''}" data-tab="${t.id}" style="--tab-active: var(${t.cssVar})">
        ${ICONS[t.id] || ''}
        <span>${t.label}</span>
      </button>`
    ).join('')
    bar.querySelectorAll('.klair-tab-btn').forEach((btn) => {
      btn.addEventListener('click', () => {
        state.tab = btn.getAttribute('data-tab')
        renderTabBar()
        renderPanels()
      })
    })
  }

  function renderHome() {
    const d = state.data
    if (!d) return '<p>Cargando…</p>'
    const u = d.user
    const o = d.recentOura && d.recentOura[0]
    const readiness = o ? o.readiness : 82
    const stress = o ? o.stressScore : 55
    const stressLevel = stress > 60 ? 'Elevated' : stress > 40 ? 'Moderate' : 'Balanced'
    const stressColor = stress > 60 ? 'var(--klair-coral)' : stress > 40 ? 'var(--klair-orange)' : 'var(--klair-emerald)'
    const waterP = u.waterGoalMl > 0 ? Math.min(1, u.waterIntakeMl / u.waterGoalMl) : 0

    const energies = [
      { v: 1, label: 'Low', color: 'var(--klair-coral)', icon: '▂' },
      { v: 3, label: 'Steady', color: 'var(--klair-cyan)', icon: '▃' },
      { v: 5, label: 'Peak', color: 'var(--klair-emerald)', icon: '▆' },
    ]

    return `
      <div class="dashboard-home" style="padding-top:8px">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px;padding-top:8px">
          <span style="font-size:20px;font-weight:700">${escapeHtml(greeting(u.name))}</span>
          <span style="width:36px;height:36px;border-radius:50%;background:var(--klair-card);display:flex;align-items:center;justify-content:center;box-shadow:0 4px 14px var(--klair-shadow);color:var(--klair-cyan)">↻</span>
        </div>
        <div class="meta-label" style="margin-bottom:10px">HOW IS YOUR ENERGY?</div>
        <div class="energy-row">
          ${energies
            .map(
              (e) => `
            <button type="button" class="energy-btn ${state.energyRating === e.v ? 'selected' : 'unselected'}" data-energy="${e.v}"
              style="${state.energyRating === e.v ? `background:${e.color};color:#fff` : `background:color-mix(in srgb, ${e.color} 14%, #fff);color:${e.color}`}">
              <div style="font-size:18px;margin-bottom:4px">${e.icon}</div>${e.label}
            </button>`
            )
            .join('')}
        </div>
        <div class="quote-row">“Small, steady rhythms beat heroic sprints when your nervous system is listening.”</div>
        <div class="hero-gradient">
          <div class="hero-meta">⚡ DAILY ENERGY</div>
          <div class="hero-score">${readiness}</div>
          <div class="hero-sub">${escapeHtml(o ? `Sleep ${o.sleep} · HRV trend stable vs 7d baseline.` : 'Readiness snapshot (demo data).')}</div>
        </div>
        <div class="glass-card">
          <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:10px">
            <span class="meta-label" style="letter-spacing:1px">STRESS · HRV-BASED</span>
            <span style="font-size:9px;font-weight:700;padding:4px 8px;border-radius:999px;background:${stressColor}22;color:${stressColor}">${stressLevel.toUpperCase()}</span>
          </div>
          <div class="sleep-bar"><span style="width:${Math.min(100, stress)}%"></span></div>
          <p style="font-size:12px;color:var(--klair-text-2);margin-top:10px;line-height:1.45">Evening load can overlap with lower nocturnal HRV — prioritize wind-down.</p>
        </div>
        <div class="glass-card rings-row">
          <div class="ring-item"><div class="ring-val" style="color:${scoreColor(readiness)}">${readiness}</div><div class="ring-lab">READY</div></div>
          <div class="ring-item"><div class="ring-val" style="color:${scoreColor(o ? o.sleep : 78)}">${o ? o.sleep : 78}</div><div class="ring-lab">SLEEP</div></div>
          <div class="ring-item"><div class="ring-val" style="color:var(--klair-cyan)">${o ? Math.round(o.hrv) : 42}</div><div class="ring-lab">HRV</div></div>
        </div>
        <div class="glass-card">
          <div class="meta-label" style="margin-bottom:10px">HYDRATION</div>
          <div style="display:flex;justify-content:space-between;align-items:center">
            <div>
              <div style="font-size:17px;font-weight:700">${Math.round(u.waterIntakeMl)} / ${Math.round(u.waterGoalMl)} ml</div>
              ${waterP < 0.5 ? `<div style="font-size:11px;color:var(--klair-coral);margin-top:4px">Below target — may reduce HRV ~5%</div>` : ''}
            </div>
            <div style="font-size:24px;font-weight:700;color:var(--klair-cyan)">${Math.round(waterP * 100)}%</div>
          </div>
        </div>
        ${(d.healthAlerts || [])
          .slice(0, 3)
          .map(
            (a) => `
          <div class="alert-card ${a.severity === 'info' ? 'info' : ''}">
            <h4>${escapeHtml(a.title)}</h4>
            <p>${escapeHtml(a.message)}</p>
          </div>`
          )
          .join('')}
      </div>`
  }

  function renderFuel() {
    const meals = (state.data && state.data.recentMeals) || []
    return `
      <div style="padding-top:12px">
        <h2 style="font-size:22px;font-weight:700;margin:0 0 4px">Fuel</h2>
        <p class="meta-label" style="margin-bottom:16px;letter-spacing:0.5px">Food journal · demo</p>
        <div class="glass-card">
          <div class="meta-label" style="margin-bottom:8px">TODAY & RECENT</div>
          ${meals
            .map(
              (m) => `
            <div class="meal-row">
              <span>${escapeHtml(m.mealTitle)}${m.isLateNight ? ' 🌙' : ''}</span>
              <strong>${Math.round(m.calories)} kcal</strong>
            </div>`
            )
            .join('')}
        </div>
        <p style="font-size:12px;color:var(--klair-text-3);line-height:1.5">En la app iOS: escaneo de comida con cámara y análisis Gemini (no disponible en web).</p>
      </div>`
  }

  function renderSleep() {
    const o = state.data && state.data.recentOura && state.data.recentOura[0]
    if (!o) return '<p>No data</p>'
    const totalH = (o.totalMinutes / 60).toFixed(1)
    return `
      <div style="padding-top:12px">
        <h2 style="font-size:22px;font-weight:700;margin:0 0 16px">Sleep</h2>
        <div class="hero-gradient" style="background:linear-gradient(135deg, var(--klair-indigo), var(--klair-amethyst))">
          <div class="hero-meta">LAST NIGHT</div>
          <div class="hero-score">${o.sleep}</div>
          <div class="hero-sub">Score · ~${totalH}h total · efficiency ${Math.round(o.sleepEfficiency)}%</div>
        </div>
        <div class="glass-card stat-grid">
          <div class="stat-cell"><div class="v">${Math.round(o.deepMinutes)}m</div><div class="l">DEEP</div></div>
          <div class="stat-cell"><div class="v">${Math.round(o.remMinutes)}m</div><div class="l">REM</div></div>
          <div class="stat-cell"><div class="v">${Math.round(o.lightMinutes)}m</div><div class="l">LIGHT</div></div>
        </div>
        <div class="glass-card">
          <div class="meta-label">VITALS</div>
          <div style="margin-top:10px;font-size:14px;line-height:1.6">
            RHR ${Math.round(o.restingHeartRate)} bpm · Resp ${o.respiratoryRate} · SpO₂ ${Math.round(o.spo2)}%
          </div>
        </div>
      </div>`
  }

  function renderMove() {
    const a = state.data && state.data.recentActivity && state.data.recentActivity[0]
    const w = state.data && state.data.healthKitWorkouts && state.data.healthKitWorkouts[0]
    return `
      <div style="padding-top:12px">
        <h2 style="font-size:22px;font-weight:700;margin:0 0 16px">Move</h2>
        <div class="glass-card">
          <div class="meta-label">TODAY</div>
          <div style="font-size:36px;font-weight:700;margin-top:8px;color:var(--klair-orange)">${a ? a.steps.toLocaleString() : '—'}</div>
          <div style="font-size:13px;color:var(--klair-text-2)">steps · ${a ? Math.round(a.activeCalories) : '—'} active kcal</div>
        </div>
        ${
          w
            ? `<div class="glass-card"><div class="meta-label">LATEST WORKOUT</div><div style="margin-top:8px;font-weight:600">${escapeHtml(w.name)}</div><div style="font-size:13px;color:var(--klair-text-2)">${Math.round(w.durationMinutes)} min · ${w.kcal != null ? Math.round(w.kcal) : '—'} kcal</div></div>`
            : ''
        }
      </div>`
  }

  function renderVault() {
    const u = state.data && state.data.user
    if (!u) return ''
    return `
      <div style="padding-top:12px">
        <h2 style="font-size:22px;font-weight:700;margin:0 0 16px">Vault</h2>
        <div class="glass-card">
          <div class="meta-label">PROFILE</div>
          <div style="margin-top:10px;font-size:16px;font-weight:700">${escapeHtml(u.name)}</div>
          <div style="font-size:14px;color:var(--klair-text-2);margin-top:8px;line-height:1.5">
            Age ${u.age} · Cycle day ${u.cycleDay} · ${escapeHtml(u.cyclePhase)}<br/>
            ${escapeHtml(u.knownConditions)}
          </div>
        </div>
        <div class="glass-card">
          <div class="meta-label">GOALS</div>
          <p style="margin:8px 0 0;font-size:14px;color:var(--klair-text-2)">${escapeHtml(u.healthGoals)}</p>
        </div>
      </div>`
  }

  function renderAsk() {
    const bubbles = state.messages
      .map(
        (m) => `
      <div class="bubble-row ${m.role === 'user' ? 'user' : ''}">
        ${m.role === 'assistant' ? '<div class="ask-logo" style="width:28px;height:28px;font-size:12px">✦</div>' : ''}
        <div class="bubble ${m.role}"><pre>${escapeHtml(m.text)}</pre></div>
      </div>`
      )
      .join('')

    const typing = state.sending
      ? `<div class="bubble-row"><div class="ask-logo" style="width:28px;height:28px;font-size:12px">✦</div><div class="bubble assistant"><span class="typing-dot"></span><span class="typing-dot"></span><span class="typing-dot"></span></div></div>`
      : ''

    const chips = SUGGESTED.map(
      (q) =>
        `<button type="button" class="chip" data-q="${encodeURIComponent(q)}" ${state.sending ? 'disabled' : ''}>${escapeHtml(q)}</button>`
    ).join('')

    return `
      <div class="ask-panel" style="display:flex;flex-direction:column;height:100%;min-height:0">
        <div class="ask-header">
          <div>
            <h2>Ask Klair</h2>
            <div class="sub">Gemini · mismo contexto JSON que la app iOS (demo)</div>
          </div>
          <div class="ask-logo">✦</div>
        </div>
        <div class="chat-scroll" id="chat-scroll">${bubbles}${typing}</div>
        <div class="chips" id="ask-chips">${chips}</div>
        <div class="composer">
          <input type="text" id="ask-input" placeholder="Escribe a Klair…" autocomplete="off" ${state.sending ? 'disabled' : ''} />
          <button type="button" class="send-btn" id="ask-send" aria-label="Enviar" ${state.sending ? 'disabled' : ''}>⬆</button>
        </div>
      </div>`
  }

  function renderPanels() {
    const root = document.getElementById('app-tab-views')
    if (!root) return
    const panels = {
      home: renderHome(),
      fuel: renderFuel(),
      sleep: renderSleep(),
      move: renderMove(),
      ask: renderAsk(),
      vault: renderVault(),
    }
    root.innerHTML = TAB_META.map(
      (t) => `<div class="app-tab-panel ${state.tab === t.id ? 'is-active' : ''}" data-panel="${t.id}" role="tabpanel">${panels[t.id]}</div>`
    ).join('')

    root.querySelectorAll('.energy-btn').forEach((btn) => {
      btn.addEventListener('click', () => {
        state.energyRating = Number(btn.getAttribute('data-energy'))
        renderPanels()
        renderTabBar()
      })
    })

    if (state.tab === 'ask') {
      bindAsk()
      const sc = document.getElementById('chat-scroll')
      if (sc) sc.scrollTop = sc.scrollHeight
    }
  }

  function bindAsk() {
    const input = document.getElementById('ask-input')
    const send = document.getElementById('ask-send')
    document.getElementById('ask-chips')?.querySelectorAll('.chip').forEach((c) => {
      c.addEventListener('click', () => {
        const raw = c.getAttribute('data-q')
        if (raw) sendMessage(decodeURIComponent(raw))
      })
    })
    send?.addEventListener('click', () => sendMessage(input?.value || ''))
    input?.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') sendMessage(input.value)
    })
  }

  async function sendMessage(text) {
    const t = text.trim()
    if (!t || state.sending) return
    const input = document.getElementById('ask-input')
    if (input) input.value = ''
    state.messages.push({ role: 'user', text: t })
    state.sending = true
    renderPanels()
    renderTabBar()

    const conversation = state.messages.map((m) => ({
      role: m.role,
      content: m.text,
    }))

    try {
      const res = await fetch('/api/gemini', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          mode: 'klairCoach',
          conversation,
          contextJSON: state.contextString,
        }),
      })
      const data = await res.json()
      if (!res.ok) {
        state.messages.push({ role: 'assistant', text: data.error || 'Error al contactar Gemini.' })
      } else {
        state.messages.push({ role: 'assistant', text: data.text || '(vacío)' })
      }
    } catch (e) {
      state.messages.push({ role: 'assistant', text: 'Red: ' + (e.message || 'fallo') })
    }
    state.sending = false
    renderPanels()
    renderTabBar()
  }

  function tickClock() {
    const el = document.querySelector('.ios-time')
    if (el) el.textContent = formatTime(new Date())
  }

  async function init() {
    try {
      const res = await fetch('/klair-demo-context.json', { cache: 'no-store' })
      state.data = await res.json()
      state.contextString = JSON.stringify(state.data)
      seedChatFromDemo(state.data)
    } catch (e) {
      state.data = { user: { name: 'Marta' }, recentOura: [], recentMeals: [], healthAlerts: [] }
      state.contextString = '{}'
      state.messages = [{ role: 'assistant', text: 'No se pudo cargar el contexto demo.' }]
    }

    renderTabBar()
    renderPanels()
    tickClock()
    setInterval(tickClock, 30000)
    mountTestFlightBelow()
  }

  function mountTestFlightBelow() {
    const mount = document.getElementById('testflight-mount-below')
    if (!mount) return
    const raw = (typeof window.KLAIR_TESTFLIGHT_URL === 'string' && window.KLAIR_TESTFLIGHT_URL.trim()) || ''
    let ok = false
    try {
      const u = new URL(raw)
      ok = u.protocol === 'https:' && u.hostname === 'testflight.apple.com'
    } catch (_) {}
    mount.innerHTML = ''
    if (ok) {
      const a = document.createElement('a')
      a.href = raw
      a.className = 'btn-tf'
      a.rel = 'noopener noreferrer'
      a.target = '_blank'
      a.textContent = 'Abrir en TestFlight'
      a.style.cssText =
        'display:inline-block;margin-top:8px;padding:10px 16px;border-radius:12px;background:#4e5e6d;color:#fff;font-weight:600;text-decoration:none'
      mount.appendChild(a)
    }
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', init)
  else init()
})()
