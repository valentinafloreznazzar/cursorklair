/**
 * Klair web — iPhone-first UI aligned with KlairTheme + MockData (klair-demo-context.json).
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
    sickDay: false,
    messages: [],
    sending: false,
    fuelSegment: 0,
    trendRange: '7d',
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

  function wc(key, fallback) {
    const w = state.data && state.data.webCopy
    return (w && w[key]) || fallback
  }

  function startOfLocalDay(d) {
    const x = new Date(d)
    x.setHours(0, 0, 0, 0)
    return x.getTime()
  }

  function isToday(ts) {
    return startOfLocalDay(new Date(ts)) === startOfLocalDay(new Date())
  }

  function todayMeals() {
    const meals = (state.data && state.data.recentMeals) || []
    return meals.filter((m) => isToday(m.timestamp))
  }

  function sumTodayMacros() {
    return todayMeals().reduce(
      (a, m) => ({
        cal: a.cal + (m.calories || 0),
        p: a.p + (m.protein || 0),
        c: a.c + (m.carbs || 0),
        f: a.f + (m.fat || 0),
      }),
      { cal: 0, p: 0, c: 0, f: 0 }
    )
  }

  function contributorColor(val) {
    const v = String(val || '').toLowerCase()
    if (v === 'optimal' || v === 'restored') return 'var(--klair-emerald)'
    if (v === 'good' || v === 'normal') return 'var(--klair-cyan)'
    if (v === 'fair' || v === 'moderate' || v === 'slightly_elevated') return 'var(--klair-orange)'
    return 'var(--klair-coral)'
  }

  function formatShort(d) {
    return new Date(d).toLocaleDateString(undefined, { weekday: 'short', month: 'short', day: 'numeric' })
  }

  function ouraSortedAsc() {
    const o = (state.data && state.data.recentOura) || []
    return [...o].sort((a, b) => new Date(a.date) - new Date(b.date))
  }

  function trendSlice() {
    const asc = ouraSortedAsc()
    const n = state.trendRange === '30d' ? 14 : 7
    return asc.slice(-n)
  }

  function renderTrendSvg() {
    const pts = trendSlice()
    if (!pts.length) return ''
    const w = 300
    const h = 100
    const pad = 8
    const maxY = 55
    const minY = 0
    const xs = pts.map((_, i) => pad + (i * (w - 2 * pad)) / Math.max(1, pts.length - 1))
    const ys = pts.map((p) => {
      const v = Math.min(maxY, Math.max(minY, p.hrv || 0))
      return h - pad - ((v - minY) / (maxY - minY)) * (h - 2 * pad)
    })
    const lineD = xs.map((x, i) => `${i === 0 ? 'M' : 'L'} ${x} ${ys[i]}`).join(' ')
    const areaD = `M ${xs[0]} ${h - pad} L ${xs.map((x, i) => `${x} ${ys[i]}`).join(' L ')} L ${xs[xs.length - 1]} ${h - pad} Z`
    return `<svg class="chart-svg" viewBox="0 0 ${w} ${h}" preserveAspectRatio="none">
      <path d="${areaD}" fill="rgba(0,212,255,0.12)" />
      <path d="${lineD}" fill="none" stroke="var(--klair-cyan)" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round" />
      ${xs.map((x, i) => `<circle cx="${x}" cy="${ys[i]}" r="3" fill="var(--klair-cyan)" />`).join('')}
    </svg>`
  }

  function weekSummaryBlock() {
    const o = (state.data && state.data.recentOura) || []
    const w = o.slice(0, 7)
    if (!w.length) return ''
    const avg = (k) => Math.round(w.reduce((s, x) => s + (x[k] || 0), 0) / w.length)
    const avgHrv = w.reduce((s, x) => s + (x.hrv || 0), 0) / w.length
    return `
      <div class="glass-card">
        <div class="meta-label" style="margin-bottom:12px">WEEKLY SUMMARY (7D)</div>
        <div class="stat-grid">
          <div class="stat-cell"><div class="v" style="color:${scoreColor(avg('readiness'))}">${avg('readiness')}</div><div class="l">AVG READY</div></div>
          <div class="stat-cell"><div class="v" style="color:${scoreColor(avg('sleep'))}">${avg('sleep')}</div><div class="l">AVG SLEEP</div></div>
          <div class="stat-cell"><div class="v" style="color:var(--klair-cyan)">${Math.round(avgHrv)}</div><div class="l">AVG HRV</div></div>
        </div>
      </div>`
  }

  function showToast(msg) {
    const t = document.createElement('div')
    t.className = 'toast'
    t.textContent = msg
    document.body.appendChild(t)
    setTimeout(() => t.remove(), 2200)
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
    const contrib = o && o.readinessContributors ? o.readinessContributors : null

    const energies = [
      { v: 1, label: 'Low', color: 'var(--klair-coral)', icon: '▂' },
      { v: 3, label: 'Steady', color: 'var(--klair-cyan)', icon: '▃' },
      { v: 5, label: 'Peak', color: 'var(--klair-emerald)', icon: '▆' },
    ]
    const er = state.sickDay ? 0 : state.energyRating

    return `
      <div class="dashboard-home" style="padding-top:8px">
        <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:16px;padding-top:8px">
          <span style="font-size:20px;font-weight:700">${escapeHtml(greeting(u.name))}</span>
          <button type="button" class="sync-btn" data-action="sync" aria-label="Sync">↻</button>
        </div>
        <div class="meta-label" style="margin-bottom:10px">HOW IS YOUR ENERGY?</div>
        <div class="energy-row">
          ${energies
            .map(
              (e) => `
            <button type="button" class="energy-btn ${er === e.v ? 'selected' : 'unselected'}" data-energy="${e.v}"
              style="${er === e.v ? `background:${e.color};color:#fff` : `background:color-mix(in srgb, ${e.color} 14%, #fff);color:${e.color}`}">
              <div style="font-size:18px;margin-bottom:4px">${e.icon}</div>${e.label}
            </button>`
            )
            .join('')}
          <div style="width:1px;background:rgba(0,0,0,0.08);margin:4px 0"></div>
          <button type="button" class="sick-day-btn ${state.sickDay ? 'selected' : ''}" data-action="sick"
            style="${state.sickDay ? 'background:#C4841D;color:#fff' : 'background:#FFF3DC;color:#C4841D'}">
            <div style="font-size:16px">${state.sickDay ? '✓' : '✕'}</div>${state.sickDay ? 'Active' : 'Sick'}
          </button>
        </div>
        <div class="quote-row">“${escapeHtml(wc('inspirationalQuote', 'Small, steady rhythms…'))}”</div>
        <div class="hero-gradient">
          <div class="hero-meta">⚡ DAILY ENERGY</div>
          <div class="hero-score">${readiness}</div>
          <div class="hero-sub">${escapeHtml(wc('dailyInsight', o ? `Sleep ${o.sleep} · HRV vs 7d.` : ''))}</div>
        </div>
        <div class="glass-card">
          <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:10px">
            <span class="meta-label" style="letter-spacing:1px">STRESS · HRV-BASED</span>
            <span style="font-size:9px;font-weight:700;padding:4px 8px;border-radius:999px;background:${stressColor}22;color:${stressColor}">${stressLevel.toUpperCase()}</span>
          </div>
          <div class="sleep-bar"><span class="stress-bar-fill" style="width:${Math.min(100, stress)}%"></span></div>
          <p style="font-size:12px;color:var(--klair-text-2);margin-top:10px;line-height:1.45">${escapeHtml(wc('stressDescription', ''))}</p>
        </div>
        <div class="glass-card rings-row">
          <div class="ring-item"><div class="ring-val" style="color:${scoreColor(readiness)}">${readiness}</div><div class="ring-lab">READY</div></div>
          <div class="ring-item"><div class="ring-val" style="color:${scoreColor(o ? o.sleep : 78)}">${o ? o.sleep : 78}</div><div class="ring-lab">SLEEP</div></div>
          <div class="ring-item"><div class="ring-val" style="color:var(--klair-cyan)">${o ? Math.round(o.hrv) : 42}</div><div class="ring-lab">HRV</div></div>
        </div>
        ${
          contrib
            ? `<div class="glass-card">
          <div class="meta-label" style="margin-bottom:10px">READINESS CONTRIBUTORS</div>
          ${Object.entries(contrib)
            .map(
              ([k, v]) => `
            <div class="contrib-row">
              <span class="contrib-dot" style="background:${contributorColor(v)}"></span>
              <span style="flex:1">${escapeHtml(k.replace(/_/g, ' '))}</span>
              <strong style="color:${contributorColor(v)}">${escapeHtml(String(v).replace(/_/g, ' '))}</strong>
            </div>`
            )
            .join('')}
        </div>`
            : ''
        }
        <div class="glass-card">
          <div style="display:flex;justify-content:space-between;align-items:center;margin-bottom:8px">
            <span class="meta-label">TRENDS</span>
            <div class="trend-toggle">
              <button type="button" class="${state.trendRange === '7d' ? 'is-on' : ''}" data-trend="7d">7D</button>
              <button type="button" class="${state.trendRange === '30d' ? 'is-on' : ''}" data-trend="30d">30D</button>
            </div>
          </div>
          <div style="font-size:10px;color:var(--klair-text-3);margin-bottom:4px">HRV (Oura)</div>
          <div class="chart-wrap">${renderTrendSvg()}</div>
          <div style="display:flex;gap:12px;margin-top:8px;font-size:10px;color:var(--klair-text-3)">
            <span>● HRV</span><span style="color:var(--klair-orange)">■ Glycemic proxy</span>
          </div>
        </div>
        ${weekSummaryBlock()}
        ${
          (d.correlations || [])
            .map(
              (c) => `
          <div class="glass-card correlation-block">
            <div style="font-size:12px;font-weight:700">${escapeHtml(c.label)}
              <span class="r-pill" style="background:${c.r >= 0 ? 'rgba(0,201,167,0.15)' : 'rgba(255,71,87,0.12)'};color:${c.r >= 0 ? 'var(--klair-emerald)' : 'var(--klair-coral)'}">r = ${c.r.toFixed(2)}</span>
            </div>
            <p style="margin:6px 0 0;font-size:12px;color:var(--klair-text-2);line-height:1.4">${escapeHtml(c.description)}</p>
          </div>`
            )
            .join('') || ''
        }
        <div class="glass-card">
          <div class="meta-label" style="margin-bottom:10px">CONTEXTUAL INSIGHTS</div>
          ${(d.healthAlerts || [])
            .map(
              (a) => `
            <div class="insight-tile"><strong>${escapeHtml(a.title)}</strong> — ${escapeHtml(a.message)}</div>`
            )
            .join('')}
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
        <div class="glass-card">
          <div class="meta-label" style="margin-bottom:8px">BIO-NARRATIVE</div>
          <p style="margin:0;font-size:13px;color:var(--klair-text-2);line-height:1.5">${escapeHtml(wc('bioNarrative', ''))}</p>
        </div>
      </div>`
  }

  function macroRingHtml(mac, goal) {
    const pct = goal > 0 ? Math.min(1, mac.cal / goal) : 0
    const deg = pct * 360
    return `
      <div class="macro-ring-wrap">
        <div class="macro-ring" style="background:conic-gradient(var(--klair-cyan) ${deg}deg, rgba(0,0,0,0.06) 0)">
          <div style="width:100px;height:100px;border-radius:50%;background:var(--klair-card);display:flex;flex-direction:column;align-items:center;justify-content:center">
            <span class="ring-label">TODAY</span>
            <span class="ring-cal">${Math.round(mac.cal)}</span>
            <span class="ring-label">kcal</span>
          </div>
        </div>
      </div>
      <div class="macro-legend"><span class="legend-p">P ${Math.round(mac.p)}g</span><span class="legend-c">C ${Math.round(mac.c)}g</span><span class="legend-f">F ${Math.round(mac.f)}g</span></div>`
  }

  function renderFuel() {
    const d = state.data
    const meals = (d && d.recentMeals) || []
    const goal = (d && d.user && d.user.dailyCalorieGoal) || 1950
    const mac = sumTodayMacros()
    const recipes = (d && d.chefRecipes) || []

    const journal = `
      <div class="segment-control">
        <button type="button" class="segment-btn ${state.fuelSegment === 0 ? 'is-on' : ''}" data-seg="0">JOURNAL</button>
        <button type="button" class="segment-btn ${state.fuelSegment === 1 ? 'is-on' : ''}" data-seg="1">CHEF PANTRY</button>
      </div>
      ${
        state.fuelSegment === 0
          ? `
        ${macroRingHtml(mac, goal)}
        <div class="glass-card">
          <div class="meta-label" style="margin-bottom:8px">FOOD JOURNAL (SYNCED MOCK)</div>
          ${meals
            .slice(0, 24)
            .map(
              (m) => `
            <div class="meal-row">
              <span>${escapeHtml(m.mealTitle)}${m.isLateNight ? ' 🌙' : ''}${m.isHighGlycemic ? ' ⚡' : ''}<br/><small style="color:var(--klair-text-3)">${formatShort(m.timestamp)}</small></span>
              <strong>${Math.round(m.calories)} kcal</strong>
            </div>`
            )
            .join('')}
        </div>
        <div class="glass-card" style="text-align:center;padding:20px">
          <div class="meta-label" style="margin-bottom:8px">SCAN MEAL</div>
          <p style="font-size:13px;color:var(--klair-text-2);margin:0">En iOS: cámara + Gemini. En web: demo estática.</p>
          <button type="button" class="chip" data-action="mock-camera" style="margin-top:12px">Simular escaneo (demo)</button>
        </div>`
          : `
        <div class="meta-label" style="margin-bottom:12px">KLAIR CHEF · RECETAS (MOCK)</div>
        ${recipes
          .map(
            (r) => `
          <div class="recipe-card">
            <h4>${escapeHtml(r.title)}</h4>
            <div class="macros">${Math.round(r.calories)} kcal · P ${Math.round(r.protein)}g · C ${Math.round(r.carbs)}g · F ${Math.round(r.fat)}g</div>
            <div class="why">${escapeHtml(r.why)}</div>
            <div style="font-size:11px;color:var(--klair-text-3);margin-top:8px">${(r.ingredients || []).map((x) => escapeHtml(x)).join(' · ')}</div>
          </div>`
          )
          .join('')}
        <p style="font-size:12px;color:var(--klair-text-3)">Misma lógica que iOS: recetas según contexto; aquí datos fijos del JSON.</p>`
      }`

    return `<div style="padding-top:8px"><h1 class="screen-title">Fuel</h1>${journal}</div>`
  }

  function renderSleep() {
    const d = state.data
    const rows = (d && d.recentOura) || []
    const o = rows[0]
    if (!o) return '<p>No data</p>'
    const totalH = (o.totalMinutes / 60).toFixed(1)
    const maxTot = Math.max(...rows.map((x) => x.totalMinutes || 1), 1)

    return `
      <div style="padding-top:8px">
        <h1 class="screen-title">Sleep</h1>
        <div class="hero-gradient" style="background:linear-gradient(135deg, var(--klair-indigo), var(--klair-amethyst))">
          <div class="hero-meta">LAST NIGHT</div>
          <div class="hero-score">${o.sleep}</div>
          <div class="hero-sub">~${totalH}h total · efficiency ${Math.round(o.sleepEfficiency)}%</div>
        </div>
        <div class="glass-card stat-grid">
          <div class="stat-cell"><div class="v">${Math.round(o.deepMinutes)}m</div><div class="l">DEEP</div></div>
          <div class="stat-cell"><div class="v">${Math.round(o.remMinutes)}m</div><div class="l">REM</div></div>
          <div class="stat-cell"><div class="v">${Math.round(o.lightMinutes)}m</div><div class="l">LIGHT</div></div>
        </div>
        <div class="glass-card">
          <div class="meta-label">VITALS</div>
          <div style="margin-top:10px;font-size:14px;line-height:1.7">
            RHR ${Math.round(o.restingHeartRate)} bpm · Resp ${o.respiratoryRate} · SpO₂ ${Math.round(o.spo2)}%<br/>
            Latency ${Math.round(o.sleepLatency)} min · Temp Δ ${o.temperatureDeviation >= 0 ? '+' : ''}${o.temperatureDeviation}°
          </div>
        </div>
        <div class="glass-card">
          <div class="meta-label" style="margin-bottom:12px">LAST 7 NIGHTS</div>
          ${rows
            .slice(0, 7)
            .map((x) => {
              const tot = x.totalMinutes || 1
              const dw = (x.deepMinutes / tot) * 100
              const rw = (x.remMinutes / tot) * 100
              const lw = 100 - dw - rw
              return `
            <div class="sleep-history-row">
              <div class="row-top"><span>${formatShort(x.date)}</span><span>Sleep ${x.sleep}</span></div>
              <div class="sleep-stacks">
                <span class="stack-deep" style="width:${dw}%"></span>
                <span class="stack-rem" style="width:${rw}%"></span>
                <span class="stack-light" style="width:${lw}%"></span>
              </div>
            </div>`
            })
            .join('')}
        </div>
        <div class="glass-card">
          <div class="meta-label">SLEEP DURATION TREND</div>
          <div style="display:flex;margin-top:12px;height:12px;border-radius:6px;overflow:hidden;gap:2px">
            ${rows
              .slice(0, 7)
              .reverse()
              .map(
                (x) =>
                  `<span style="flex:1;height:100%;background:var(--klair-indigo);opacity:${0.35 + (0.65 * (x.totalMinutes || 0)) / maxTot}"></span>`
              )
              .join('')}
          </div>
        </div>
      </div>`
  }

  function renderMove() {
    const d = state.data
    const acts = (d && d.recentActivity) || []
    const wk = (d && d.healthKitWorkouts) || []
    const en = (d && d.energyActivities) || []
    const today = acts[0]
    return `
      <div style="padding-top:8px">
        <h1 class="screen-title">Move</h1>
        <div class="glass-card">
          <div class="meta-label">TODAY</div>
          <div style="font-size:36px;font-weight:700;margin-top:8px;color:var(--klair-orange)">${today ? today.steps.toLocaleString() : '—'}</div>
          <div style="font-size:13px;color:var(--klair-text-2)">steps · ${today ? Math.round(today.activeCalories) : '—'} kcal · ${today ? escapeHtml(today.workoutType) : '—'}</div>
        </div>
        <div class="glass-card">
          <div class="meta-label" style="margin-bottom:8px">14-DAY ACTIVITY</div>
          ${acts
            .map(
              (a) => `
            <div class="activity-list-row">
              <span>${formatShort(a.date)} · ${escapeHtml(a.workoutType)}</span>
              <strong>${a.steps.toLocaleString()} st</strong>
            </div>`
            )
            .join('')}
        </div>
        <div class="glass-card">
          <div class="meta-label" style="margin-bottom:8px">WORKOUTS (HEALTHKIT)</div>
          ${wk
            .map(
              (w) => `
            <div class="activity-list-row">
              <span>${escapeHtml(w.name)}</span>
              <span>${Math.round(w.durationMinutes)} min</span>
            </div>`
            )
            .join('')}
        </div>
        <div class="glass-card">
          <div class="meta-label" style="margin-bottom:8px">ENERGY LEDGER</div>
          ${en
            .map(
              (e) => `
            <div class="activity-list-row">
              <span>${escapeHtml(e.context)} (${e.effect})</span>
              <span>${e.energyDelta > 0 ? '+' : ''}${e.energyDelta}</span>
            </div>`
            )
            .join('')}
        </div>
      </div>`
  }

  function renderVault() {
    const d = state.data
    const u = d && d.user
    if (!u) return ''
    const labs = (d && d.labResults) || []
    const sym = (d && d.cycleSymptoms) || []
    const mens = (d && d.healthKitMenstrual) || []
    return `
      <div style="padding-top:8px">
        <h1 class="screen-title">Vault</h1>
        <div class="glass-card">
          <div class="meta-label">PROFILE</div>
          <div style="margin-top:10px;font-size:17px;font-weight:700">${escapeHtml(u.name)}</div>
          <div style="font-size:13px;color:var(--klair-text-2);margin-top:10px;line-height:1.6">
            ${u.age} años · ${u.heightCm} cm · ${u.weightKg} kg · BMI ${u.bmi}<br/>
            Ciclo día ${u.cycleDay}/${u.cycleLength} · fase <strong>${escapeHtml(u.cyclePhase)}</strong>
          </div>
        </div>
        <div class="glass-card">
          <div class="meta-label">CONDITIONS & MEDS</div>
          <p style="margin:8px 0 0;font-size:13px;color:var(--klair-text-2)">${escapeHtml(u.knownConditions)}</p>
          <p style="margin:8px 0 0;font-size:13px;color:var(--klair-text-2)">${escapeHtml(u.medications)}</p>
        </div>
        <div class="glass-card">
          <div class="meta-label">VITALS</div>
          <p style="margin:8px 0 0;font-size:13px">BP ${escapeHtml(u.bloodPressure)} (${escapeHtml(u.bpCategory)}) · Glucose ${u.glucoseMgDl} mg/dL</p>
        </div>
        <div class="glass-card">
          <div class="meta-label">LABS</div>
          ${labs
            .map(
              (l) => `
            <div class="lab-row">
              <span>${escapeHtml(l.testType)}</span>
              <strong>${l.value} ${escapeHtml(l.unit)}</strong>
              <span style="font-size:11px;color:var(--klair-text-3)">${escapeHtml(l.status)}</span>
            </div>`
            )
            .join('')}
        </div>
        <div class="glass-card">
          <div class="meta-label">CYCLE & SYMPTOMS</div>
          ${sym
            .map(
              (s) => `
            <p style="font-size:13px;margin:8px 0 0">${escapeHtml(s.topSymptoms)} · day ${s.cycleDay} · ${escapeHtml(s.phase)}</p>`
            )
            .join('')}
          ${mens.map((m) => `<p style="font-size:12px;color:var(--klair-text-3);margin:6px 0 0">${formatShort(m.date)} · ${escapeHtml(m.flow)}</p>`).join('')}
        </div>
        <div class="glass-card">
          <div class="meta-label">GOALS</div>
          <p style="margin:8px 0 0;font-size:13px;color:var(--klair-text-2)">${escapeHtml(u.healthGoals)}</p>
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
            <div class="sub">Gemini · mismo JSON que buildContextJSON (demo)</div>
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
        state.sickDay = false
        renderPanels()
        renderTabBar()
      })
    })

    root.querySelectorAll('[data-action="sick"]').forEach((btn) => {
      btn.addEventListener('click', () => {
        state.sickDay = !state.sickDay
        if (state.sickDay) state.energyRating = 0
        renderPanels()
        renderTabBar()
      })
    })

    root.querySelectorAll('[data-action="sync"]').forEach((btn) => {
      btn.addEventListener('click', () => showToast('Demo: datos estáticos (mismo mock que iOS).'))
    })

    root.querySelectorAll('[data-action="mock-camera"]').forEach((btn) => {
      btn.addEventListener('click', () => showToast('En la app iOS esto abre la cámara y Gemini.'))
    })

    root.querySelectorAll('[data-trend]').forEach((btn) => {
      btn.addEventListener('click', () => {
        state.trendRange = btn.getAttribute('data-trend')
        renderPanels()
        renderTabBar()
      })
    })

    root.querySelectorAll('[data-seg]').forEach((btn) => {
      btn.addEventListener('click', () => {
        state.fuelSegment = Number(btn.getAttribute('data-seg'))
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
