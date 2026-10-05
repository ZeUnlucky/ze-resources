/* Clock: the time in Los Santos (the game's clock) next to your real time, a stopwatch and a timer. The stopwatch and the timer
   keep running when the app is closed or the phone is put away; a finished timer rings with a banner and a sound. */

(() => {
    'use strict';

    const { h, icon } = ZP;
    const ui = ZP.ui;
    const NS = 'http://www.w3.org/2000/svg';

    // ------------------------------------------------------------------ stopwatch and timer state (outlives the app)

    const sw = { running: false, start: 0, base: 0, laps: [] };
    const tm = { running: false, end: 0, total: 0, left: 0, ringing: false };
    let driver = null;

    const swElapsed = () => sw.base + (sw.running ? Date.now() - sw.start : 0);
    const tmLeft = () => (tm.running ? Math.max(0, tm.end - Date.now()) : tm.left);

    const fmtSw = (ms) => {
        const cs = Math.floor(ms / 10) % 100, s = Math.floor(ms / 1000) % 60, m = Math.floor(ms / 60000);
        return `${String(m).padStart(2, '0')}:${String(s).padStart(2, '0')}.${String(cs).padStart(2, '0')}`;
    };
    const fmtTm = (ms) => {
        const t = Math.ceil(ms / 1000), hh = Math.floor(t / 3600), mm = Math.floor((t % 3600) / 60), ss = t % 60;
        return (hh ? hh + ':' + String(mm).padStart(2, '0') : String(mm)) + ':' + String(ss).padStart(2, '0');
    };

    function ensureDriver() {
        if (driver || !(sw.running || tm.running)) return;
        driver = setInterval(() => {
            if (tm.running && tmLeft() <= 0) ring();
            ZP.emit('clock:tick');
            if (!sw.running && !tm.running) { clearInterval(driver); driver = null; }
        }, 50);
    }

    function ring() {
        tm.running = false;
        tm.left = 0;
        tm.ringing = true;
        ZP.notify({ app: 'clock', title: 'Timer', text: "Time's up", icon: 'timer', force: true, sound: false, timeout: 9000 });
        let n = 0;
        const beep = () => { ZP.post('sound', { kind: 'timer' }); if (++n < 4 && tm.ringing) setTimeout(beep, 1300); };
        beep();
        ZP.emit('clock:tick');
    }

    // ------------------------------------------------------------------ panels

    function analog(t) {
        const svg = document.createElementNS(NS, 'svg');
        svg.setAttribute('viewBox', '-50 -50 100 100');
        svg.setAttribute('class', 'analog');
        let marks = '';
        for (let i = 0; i < 60; i++) {
            const a = i * 6 * Math.PI / 180, long = i % 5 === 0;
            const r1 = long ? 41 : 44, r2 = 47;
            marks += `<line x1="${(Math.sin(a) * r1).toFixed(2)}" y1="${(-Math.cos(a) * r1).toFixed(2)}" x2="${(Math.sin(a) * r2).toFixed(2)}" y2="${(-Math.cos(a) * r2).toFixed(2)}" stroke="${long ? 'currentColor' : 'rgba(255,240,225,.28)'}" stroke-width="${long ? 1.4 : .7}" stroke-linecap="round"/>`;
        }
        const hAng = ((t.h % 12) + t.m / 60) * 30, mAng = t.m * 6;
        svg.innerHTML = `<circle r="49" fill="rgba(255,240,225,.04)" stroke="rgba(255,240,225,.12)"/>${marks}`
            + `<line x1="0" y1="3" x2="0" y2="-26" stroke="#f6f2ee" stroke-width="3" stroke-linecap="round" transform="rotate(${hAng})"/>`
            + `<line x1="0" y1="4" x2="0" y2="-38" stroke="#f6f2ee" stroke-width="2" stroke-linecap="round" transform="rotate(${mAng})"/>`
            + `<circle r="3" fill="var(--accent)"/>`;
        return svg;
    }

    function worldPanel(ctx) {
        const el = h('div.panel');
        const draw = () => {
            const t = ZP.state.time;
            const real = new Date();
            ZP.clear(el);
            el.appendChild(h('div.wclock',
                h('div.w-city', icon('pin'), 'Los Santos'),
                analog(t),
                h('div.w-digital', ZP.fmt.gameClock()),
                h('div.w-day', `${ZP.fmt.days[t.weekday % 7]}, ${t.day} ${ZP.fmt.months[t.month % 12]} ${t.year}`)));
            el.appendChild(h('div.gcard',
                ui.row({ icon: 'globe', color: '#4a8cff', title: 'Real time', sub: real.toLocaleDateString([], { weekday: 'long', day: 'numeric', month: 'long' }), right: h('b', real.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })) })));
        };
        ctx.on('time', draw);
        draw();
        return { el, draw };
    }

    function stopwatchPanel(ctx) {
        const el = h('div.panel.swp');
        const time = h('div.sw-time', fmtSw(swElapsed()));
        const laps = h('div.gcard');
        const main = h('button.sw-btn.go', { type: 'button' });
        const side = h('button.sw-btn.ghost', { type: 'button' });
        const paint = () => {
            time.textContent = fmtSw(swElapsed());
            main.className = 'sw-btn ' + (sw.running ? 'stop' : 'go');
            main.textContent = sw.running ? 'Stop' : (sw.base ? 'Resume' : 'Start');
            side.textContent = sw.running ? 'Lap' : 'Reset';
            side.disabled = !sw.running && !sw.base;
            ZP.clear(laps);
            laps.hidden = !sw.laps.length;
            sw.laps.slice().reverse().forEach((l, i) => laps.appendChild(ui.row({ title: `Lap ${sw.laps.length - i}`, right: h('b', fmtSw(l.split)), sub: fmtSw(l.total) })));
        };
        main.onclick = () => {
            if (sw.running) { sw.base = swElapsed(); sw.running = false; } else { sw.start = Date.now(); sw.running = true; ensureDriver(); }
            paint();
        };
        side.onclick = () => {
            if (sw.running) { const total = swElapsed(); const last = sw.laps.length ? sw.laps[sw.laps.length - 1].total : 0; sw.laps.push({ total, split: total - last }); }
            else { sw.base = 0; sw.laps = []; }
            paint();
        };
        el.append(time, h('div.sw-btns', side, main), laps);
        ctx.on('clock:tick', () => { if (el.isConnected) time.textContent = fmtSw(swElapsed()); });
        paint();
        return { el, paint };
    }

    function timerPanel(ctx) {
        const el = h('div.panel.tmp');
        let min = 5, sec = 0;
        let paintRef = null;      // repaints the countdown while one is running
        const draw = () => {
            ZP.clear(el);
            paintRef = null;
            const running = tm.running || tm.left > 0;
            if (!running) {
                if (tm.ringing) {
                    el.appendChild(h('div.tm-done', icon('timer'), h('b', "Time's up"), ui.btn({ text: 'Dismiss', block: true, onclick: () => { tm.ringing = false; draw(); } })));
                    return;
                }
                const m = ui.field({ label: 'Minutes', value: String(min), max: 3, inputmode: 'numeric' });
                const s = ui.field({ label: 'Seconds', value: String(sec), max: 2, inputmode: 'numeric' });
                const start = (total) => {
                    if (total < 1) return ui.toast('Pick a time');
                    tm.total = total * 1000; tm.end = Date.now() + tm.total; tm.running = true; tm.left = 0; tm.ringing = false;
                    ensureDriver();
                    draw();
                };
                el.appendChild(h('div.tm-presets', [1, 3, 5, 10, 15, 30].map(n => h('button.preset', { type: 'button', onclick: () => start(n * 60) }, `${n} min`))));
                el.appendChild(h('div.tm-custom', m.el, s.el));
                el.appendChild(ui.btn({ text: 'Start', icon: 'play', block: true, onclick: () => {
                    min = Math.max(0, Math.min(999, parseInt(m.value(), 10) || 0));
                    sec = Math.max(0, Math.min(59, parseInt(s.value(), 10) || 0));
                    start(min * 60 + sec);
                } }));
                return;
            }
            const C = 2 * Math.PI * 46;
            const ring = document.createElementNS(NS, 'svg');
            ring.setAttribute('viewBox', '-50 -50 100 100');
            ring.setAttribute('class', 'tm-ring');
            ring.innerHTML = `<circle r="46" fill="none" stroke="rgba(255,240,225,.1)" stroke-width="4"/><circle id="tm-arc" r="46" fill="none" stroke="var(--accent)" stroke-width="4" stroke-linecap="round" stroke-dasharray="${C}" stroke-dashoffset="0" transform="rotate(-90)"/>`;
            const left = h('div.tm-left', fmtTm(tmLeft()));
            const wrap = h('div.tm-wrap', ring, left);
            const paintTick = () => {
                const l = tmLeft();
                left.textContent = fmtTm(l);
                const arc = ring.querySelector('#tm-arc');
                if (arc) arc.setAttribute('stroke-dashoffset', String(C * (1 - (tm.total ? l / tm.total : 0))));
            };
            paintRef = paintTick;
            paintTick();
            el.appendChild(wrap);
            el.appendChild(h('div.sw-btns',
                ui.btn({ text: 'Cancel', kind: 'ghost', onclick: () => { tm.running = false; tm.left = 0; draw(); } }),
                ui.btn({ text: tm.running ? 'Pause' : 'Resume', icon: tm.running ? 'pause' : 'play', onclick: () => {
                    if (tm.running) { tm.left = tmLeft(); tm.running = false; } else { tm.end = Date.now() + tm.left; tm.running = true; tm.left = 0; ensureDriver(); }
                    draw();
                } })));
        };
        // one listener for the whole panel: repaint the countdown, or show the end of it
        ctx.on('clock:tick', () => {
            if (!el.isConnected) return;
            if (tm.running || tm.left) { if (paintRef) paintRef(); }
            else if (paintRef || tm.ringing) draw();
        });
        draw();
        return { el, draw };
    }

    ZP.registerApp({
        id: 'clock', name: 'Clock', icon: 'clock', colors: ['#3a3532', '#161312'],
        mount(ctx) {
            const world = worldPanel(ctx), watch = stopwatchPanel(ctx), timer = timerPanel(ctx);
            const panes = { world: world.el, stopwatch: watch.el, timer: timer.el };
            const holder = h('div.panels');
            Object.keys(panes).forEach((k) => { const w = h('div.pwrap', { hidden: true }, panes[k]); holder.appendChild(w); panes[k] = w; });
            const tabs = ui.tabbar([
                { id: 'world', icon: 'globe', label: 'Clock' },
                { id: 'stopwatch', icon: 'clock', label: 'Stopwatch' },
                { id: 'timer', icon: 'timer', label: 'Timer' },
            ], 'world', (id) => show(id));
            const titles = { world: 'Clock', stopwatch: 'Stopwatch', timer: 'Timer' };
            const root = ui.view({ title: 'Clock', large: true, root: true, body: holder, footer: tabs.el, className: 'nopad' });
            const show = (id) => { Object.keys(panes).forEach(k => { panes[k].hidden = k !== id; }); root.setTitle(titles[id]); if (id === 'timer') timer.draw(); if (id === 'stopwatch') watch.paint(); };
            ctx.push(root);
            show(tm.running || tm.left ? 'timer' : 'world');
            tabs.select(tm.running || tm.left ? 'timer' : 'world');
        },
    });
})();
