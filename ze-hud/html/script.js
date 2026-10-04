/* ze-hud NUI. Vanilla JS, no build step, no CDNs.
   Lua sends: init, settings, tick, compass, money, menu, restart (see README.md).
   The UI sends back: ready, close, set {key, value}, action {name}. */

(() => {
    'use strict';

    const $ = (selector, parent = document) => parent.querySelector(selector);
    const body = document.body;

    // Outside the game (dev/preview.html) there is no resource name; ZE_POST lets the preview intercept calls.
    const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'ze-hud';

    function post(name, data) {
        if (window.ZE_POST) return window.ZE_POST(name, data || {});
        return fetch(`https://${RESOURCE}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).catch(() => {});
    }

    const state = {
        settings: {},
        mph: true,
        maxSpeed: 180,
        stress: true,
        voiceLevels: 3,
        mapFrame: null,
        currency: { locale: 'en-US', code: 'USD' },
        restarting: false,
    };

    // ------------------------------------------------------------------ helpers

    const hexToRgb = (hex) => {
        const m = /^#?([0-9a-f]{6})$/i.exec(String(hex).trim());
        if (!m) return null;
        const n = parseInt(m[1], 16);
        return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
    };

    function setAccent(hex) {
        const rgb = hexToRgb(hex);
        if (!rgb) return;
        const root = document.documentElement.style;
        root.setProperty('--accent', hex);
        root.setProperty('--accent-rgb', rgb.join(', '));
        const luminance = (0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]) / 255;
        root.setProperty('--accent-ink', luminance > 0.55 ? '#06100f' : '#ffffff');
    }

    function setHref(use, id) {
        if (use.dataset.id === id) return;
        use.dataset.id = id;
        use.setAttribute('href', `#${id}`);
    }

    const clamp = (v, min, max) => Math.max(min, Math.min(max, v));
    const num = (v, fallback = 0) => (typeof v === 'number' && isFinite(v) ? v : fallback);

    // ------------------------------------------------------------------ vitals dock

    const CELLS = [
        { id: 'voice' },
        { id: 'health', icon: 'i-heart', cls: 'c-health' },
        { id: 'armor', icon: 'i-shield', cls: 'c-armor' },
        { id: 'hunger', icon: 'i-utensils', cls: 'c-hunger' },
        { id: 'thirst', icon: 'i-droplet', cls: 'c-thirst' },
        { id: 'stress', icon: 'i-activity', cls: 'c-stress' },
        { id: 'stamina', icon: 'i-zap', cls: 'c-stamina' },
    ];

    const FLAGS = [
        { id: 'armed', icon: 'i-crosshair', text: 'Armed', cls: 'warn' },
        { id: 'chute', icon: 'i-parachute', text: 'Chute', cls: 'on' },
        { id: 'dev', icon: 'i-code', text: 'Dev', cls: 'on' },
    ];

    const cells = {};
    const flags = {};

    function buildDock() {
        const cellHost = $('#cells');
        CELLS.forEach((def) => {
            const el = document.createElement('div');
            el.className = `cell ${def.cls || ''} gone`.trim();
            if (def.id === 'voice') {
                el.classList.add('cell-voice');
                el.innerHTML = '<svg class="icon"><use href="#i-mic"/></svg><span class="cell-badge" hidden></span><div class="pips"></div>';
            } else {
                el.innerHTML = `<div class="cell-fill"></div><svg class="icon"><use href="#${def.icon}"/></svg><span class="cell-val">0</span>`;
            }
            cellHost.appendChild(el);
            cells[def.id] = {
                el,
                fill: $('.cell-fill', el),
                val: $('.cell-val', el),
                use: $('use', el),
                badge: $('.cell-badge', el),
                pips: $('.pips', el),
            };
        });
        cells.voice.el.classList.remove('gone');

        const flagHost = $('#flags');
        FLAGS.forEach((def) => {
            const el = document.createElement('div');
            el.className = `chip ${def.cls}`;
            el.hidden = true;
            el.innerHTML = `<svg class="icon"><use href="#${def.icon}"/></svg><span>${def.text}</span>`;
            flagHost.appendChild(el);
            flags[def.id] = el;
        });
    }

    function buildPips(levels) {
        const host = cells.voice.pips;
        host.textContent = '';
        for (let i = 0; i < levels; i++) {
            const pip = document.createElement('i');
            pip.style.height = `calc(var(--u) * ${0.8 + (i * 1) / Math.max(1, levels - 1)})`;
            host.appendChild(pip);
        }
    }

    function setCell(id, visible, pct, text) {
        const cell = cells[id];
        cell.el.classList.toggle('gone', !visible);
        if (!visible) return cell;
        cell.fill.style.height = `${clamp(pct, 0, 100)}%`;
        cell.val.textContent = text;
        return cell;
    }

    function updateDock(m) {
        const s = state.settings;

        // health
        const health = setCell('health', !(s.autoHealth && m.health >= 100 && !m.dead), m.dead ? 100 : m.health, m.dead ? '' : m.health);
        health.el.classList.toggle('dead', !!m.dead);
        health.el.classList.toggle('alert', !!m.dead || m.health <= 25);
        setHref(health.use, m.dead ? 'i-skull' : 'i-heart');

        setCell('armor', !(s.autoArmor && m.armor <= 0), m.armor, m.armor);

        const hunger = setCell('hunger', !(s.autoHunger && m.hunger >= 100), m.hunger, m.hunger);
        hunger.el.classList.toggle('alert', m.hunger <= 30);

        const thirst = setCell('thirst', !(s.autoThirst && m.thirst >= 100), m.thirst, m.thirst);
        thirst.el.classList.toggle('alert', m.thirst <= 30);

        const stress = setCell('stress', state.stress && !(s.autoStress && m.stress <= 0), m.stress, m.stress);
        stress.el.classList.toggle('alert', m.stress >= 75);

        // stamina on land, oxygen under water
        const stamina = setCell('stamina', !(s.autoStamina && m.stamina >= 100), m.stamina, m.stamina);
        stamina.el.classList.toggle('c-oxygen', !!m.underwater);
        stamina.el.classList.toggle('c-stamina', !m.underwater);
        stamina.el.classList.toggle('alert', m.stamina <= 15);
        setHref(stamina.use, m.underwater ? 'i-wind' : 'i-zap');

        // voice
        const voice = cells.voice;
        const radio = num(m.radio);
        voice.el.classList.toggle('talking', !!m.talking && !m.radioActive);
        voice.el.classList.toggle('tx', !!m.radioActive);
        setHref(voice.use, radio > 0 ? 'i-radio' : 'i-mic');
        voice.badge.hidden = radio <= 0;
        voice.badge.textContent = radio > 0 ? radio : '';
        Array.prototype.forEach.call(voice.pips.children, (pip, i) => pip.classList.toggle('on', i < m.voice));

        flags.armed.hidden = !m.armed;
        flags.chute.hidden = !m.chute;
        flags.dev.hidden = !m.dev;
    }

    // ------------------------------------------------------------------ vehicle

    const vehicle = {
        el: $('#vehicle'),
        gauge: $('.gauge'),
        speed: $('#gSpeed'),
        rpm: $('#gRpm'),
        speedVal: $('#speedVal'),
        ghost: $('#speedGhost'),
        unit: $('#speedUnit'),
        gearBox: $('#gearBox'),
        gear: $('#gear'),
        altUnit: $('#altUnit'),
        fuel: $('#barFuel'),
        engine: $('#barEngine'),
        nitro: $('#barNitro'),
        alt: $('#barAlt'),
        belt: $('#chipBelt'),
        harness: $('#chipHarness'),
        cruise: $('#chipCruise'),
    };

    function setBar(bar, visible, pct, text, tone) {
        bar.hidden = !visible;
        if (!visible) return;
        $('.track i', bar).style.width = `${clamp(pct, 0, 100)}%`;
        $('b', bar).textContent = text;
        bar.classList.remove('ok', 'warn', 'danger', 'hot', 'cool');
        if (tone) bar.classList.add(tone);
    }

    function updateVehicle(v) {
        const s = state.settings;
        vehicle.el.classList.toggle('on', !!v);
        if (!v) return;

        // speed
        const speed = Math.max(0, Math.round(num(v.speed)));
        const pct = clamp(speed / state.maxSpeed, 0, 1) * 100;
        vehicle.speed.style.strokeDasharray = `${pct} 100`;
        vehicle.speed.style.opacity = pct < 0.5 ? 0 : 1;
        vehicle.speed.classList.toggle('warn', pct > 75 && pct <= 92);
        vehicle.speed.classList.toggle('danger', pct > 92);
        const digits = String(speed);
        vehicle.speedVal.textContent = digits;
        vehicle.ghost.textContent = '0'.repeat(Math.max(0, 3 - digits.length));

        // rpm and gear
        const hasRpm = typeof v.rpm === 'number';
        vehicle.gauge.classList.toggle('no-rpm', !hasRpm);
        if (hasRpm) {
            vehicle.rpm.style.strokeDasharray = `${clamp(v.rpm, 0, 1) * 100} 100`;
            vehicle.rpm.style.opacity = v.rpm < 0.01 ? 0 : 1;
            vehicle.rpm.classList.toggle('red', v.rpm > 0.88);
        }
        vehicle.gearBox.hidden = !v.gear;
        if (v.gear) {
            vehicle.gear.textContent = v.gear;
            vehicle.gearBox.classList.toggle('reverse', v.gear === 'R');
            vehicle.gearBox.classList.toggle('neutral', v.gear === 'N');
        }

        // fuel (white, amber under 30, red under 20) and engine health
        const fuel = num(v.fuel, -1);
        setBar(vehicle.fuel, fuel >= 0, fuel, Math.round(fuel), fuel <= 20 ? 'danger' : fuel <= 30 ? 'warn' : '');
        const engine = num(v.engine);
        setBar(vehicle.engine, !(s.autoEngine && engine >= 95), engine, Math.round(engine), engine <= 45 ? 'danger' : engine <= 75 ? 'warn' : 'ok');

        // nitrous: hidden while empty unless the player turned auto-hide off and the vehicle has a kit
        const nitro = num(v.nitro);
        const showNitro = s.autoNitro ? nitro > 0 : nitro > 0 || !!v.nitroOn;
        setBar(vehicle.nitro, showNitro, nitro, Math.round(nitro), v.nitroOn ? 'hot' : 'cool');

        // altitude for aircraft
        vehicle.alt.hidden = !v.air;
        if (v.air) $('b', vehicle.alt).textContent = Math.round(num(v.alt)).toLocaleString('en-US');

        // chips
        vehicle.belt.hidden = !v.beltable;
        vehicle.belt.classList.toggle('ok', !!v.belt);
        vehicle.belt.classList.toggle('bad', !v.belt);
        $('span', vehicle.belt).textContent = v.belt ? 'Belt' : 'No belt';
        vehicle.harness.hidden = !v.harness;
        vehicle.harness.classList.toggle('on', !!v.harness);
        vehicle.cruise.hidden = !v.cruise;
        vehicle.cruise.classList.toggle('on', !!v.cruise);
    }

    // ------------------------------------------------------------------ tick

    function tick(m) {
        if (state.restarting) return;
        const show = !!m.show;
        body.classList.toggle('hud-hidden', !show);
        if (!show) return;

        body.classList.toggle('map-on', !!m.radar);
        body.classList.toggle('frame-on', !!m.frame);
        updateDock(m);
        updateVehicle(m.veh);
    }

    // ------------------------------------------------------------------ minimap frame

    function setShape(shape) {
        const next = shape === 'circle' ? 'circle' : 'square';
        body.classList.toggle('shape-circle', next === 'circle');
        body.classList.toggle('shape-square', next === 'square');
        const g = state.mapFrame && state.mapFrame[next];
        if (!g) return;
        const root = document.documentElement.style;
        root.setProperty('--map-l', g.left);
        root.setProperty('--map-b', g.bottom);
        root.setProperty('--map-w', g.width);
        root.setProperty('--map-h', g.height);
    }

    // ------------------------------------------------------------------ compass

    const compass = {
        el: $('#compass'),
        tape: $('#tape'),
        deg: $('#compassDeg'),
        street1: $('#street1'),
        street2: $('#street2'),
        area: $('#compassArea'),
        ppd: 5, // pixels per degree
        current: 0,
        target: 0,
        raf: 0,
    };

    const LABELS = { 0: 'N', 45: 'NE', 90: 'E', 135: 'SE', 180: 'S', 225: 'SW', 270: 'W', 315: 'NW' };

    function uPx() {
        return Math.max(7.2, Math.min(20, window.innerHeight / 100));
    }

    // The tape covers -360..720 degrees so the heading can wrap without a gap.
    function buildTape() {
        compass.ppd = uPx() * 0.55;
        const frag = document.createDocumentFragment();
        for (let d = -360; d < 720; d += 5) {
            const wrapped = ((d % 360) + 360) % 360;
            const x = d * compass.ppd;
            if (LABELS[wrapped] !== undefined) {
                const label = document.createElement('b');
                const cardinal = wrapped % 90 === 0;
                label.className = `lbl ${cardinal ? 'card' : 'ord'}${wrapped === 0 ? ' north' : ''}`;
                label.textContent = LABELS[wrapped];
                label.style.left = `${x}px`;
                frag.appendChild(label);
            } else if (wrapped % 30 === 0) {
                const label = document.createElement('b');
                label.className = 'lbl num';
                label.textContent = wrapped;
                label.style.left = `${x}px`;
                frag.appendChild(label);
            } else {
                const tick = document.createElement('i');
                tick.className = `t ${wrapped % 15 === 0 ? 'm' : 's'}`;
                tick.style.left = `${x}px`;
                frag.appendChild(tick);
            }
        }
        compass.tape.textContent = '';
        compass.tape.appendChild(frag);
        renderCompass();
    }

    function renderCompass() {
        const h = ((compass.current % 360) + 360) % 360;
        compass.tape.style.transform = `translateX(${-h * compass.ppd}px)`;
    }

    function stepCompass() {
        compass.raf = 0;
        const diff = ((compass.target - compass.current + 540) % 360) - 180;
        if (Math.abs(diff) < 0.05) {
            compass.current = compass.target;
        } else {
            compass.current += diff * 0.35;
        }
        compass.current = ((compass.current % 360) + 360) % 360;
        renderCompass();
        if (compass.current !== compass.target) compass.raf = requestAnimationFrame(stepCompass);
    }

    function onCompass(m) {
        if (state.restarting) return;
        compass.el.hidden = !m.show;
        if (!m.show) return;

        const heading = ((Math.round(num(m.heading)) % 360) + 360) % 360;
        compass.target = heading;
        compass.deg.textContent = `${heading}°`;
        compass.street1.textContent = m.street1 || '';
        compass.street2.textContent = m.street2 || '';
        compass.area.textContent = m.area || '';
        if (!compass.raf) compass.raf = requestAnimationFrame(stepCompass);
    }

    function applyCompassSettings() {
        const s = state.settings;
        compass.el.classList.toggle('no-pointer', s.compassPointer === false);
        compass.el.classList.toggle('no-deg', s.compassDegrees === false);
        compass.el.classList.toggle('no-street', s.streetNames === false);
    }

    // ------------------------------------------------------------------ money

    const money = {
        host: $('#money'),
        rows: {},
        format: null,
    };

    function makeFormatter() {
        try {
            money.format = new Intl.NumberFormat(state.currency.locale, {
                style: 'currency',
                currency: state.currency.code,
                maximumFractionDigits: 0,
            });
        } catch (e) {
            money.format = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD', maximumFractionDigits: 0 });
        }
    }

    function buildMoney() {
        [
            { id: 'cash', label: 'Cash', icon: 'i-cash' },
            { id: 'bank', label: 'Bank', icon: 'i-bank' },
        ].forEach((def) => {
            const el = document.createElement('div');
            el.className = `m-row ${def.id}`;
            el.innerHTML = `<div class="m-pill glass"><span class="m-ico"><svg class="icon"><use href="#${def.icon}"/></svg></span><span class="m-label">${def.label}</span><span class="m-amt">0</span></div>`;
            money.host.appendChild(el);
            money.rows[def.id] = { el, amt: $('.m-amt', el), value: 0, hide: 0, anim: 0 };
        });
    }

    function countTo(row, to) {
        cancelAnimationFrame(row.anim);
        const from = row.value;
        if (from === to) return;
        const start = performance.now();
        const duration = 650;
        const frame = (now) => {
            const t = clamp((now - start) / duration, 0, 1);
            const eased = 1 - Math.pow(1 - t, 3);
            row.value = Math.round(from + (to - from) * eased);
            row.amt.textContent = money.format.format(row.value);
            if (t < 1) row.anim = requestAnimationFrame(frame);
        };
        row.anim = requestAnimationFrame(frame);
    }

    function revealMoney(row, hold) {
        row.el.classList.add('on');
        clearTimeout(row.hide);
        row.hide = setTimeout(() => row.el.classList.remove('on'), hold);
    }

    function floatDelta(row, amount, minus) {
        const el = document.createElement('span');
        el.className = `m-delta${minus ? ' minus' : ''}`;
        el.textContent = `${minus ? '-' : '+'}${money.format.format(Math.abs(amount))}`;
        row.el.appendChild(el);
        setTimeout(() => el.remove(), 2000);
    }

    function onMoney(m) {
        if (state.restarting) return;
        const row = money.rows[m.type];
        if (!row) return;

        if (m.mode === 'show') {
            row.value = num(m.value);
            row.amt.textContent = money.format.format(row.value);
            revealMoney(row, 3500);
            return;
        }

        // change: the new balance arrives with the event, so the old one is balance -/+ amount
        const amount = num(m.amount);
        const balance = num(m[m.type], row.value);
        cancelAnimationFrame(row.anim);
        row.value = m.minus ? balance + amount : balance - amount;
        row.amt.textContent = money.format.format(row.value);
        revealMoney(row, 3200);
        floatDelta(row, amount, !!m.minus);
        countTo(row, balance);
    }

    // ------------------------------------------------------------------ menu

    const SCHEMA = [
        {
            id: 'status', label: 'Status', icon: 'i-heart',
            desc: 'Choose when each vital is shown.',
            rows: [
                { key: 'autoHealth', label: 'Auto-hide health', desc: 'Hide the health tile while you are at full health.' },
                { key: 'autoArmor', label: 'Auto-hide armor', desc: 'Hide the armor tile while you have none.' },
                { key: 'autoHunger', label: 'Auto-hide hunger', desc: 'Hide the hunger tile while you are full.' },
                { key: 'autoThirst', label: 'Auto-hide thirst', desc: 'Hide the thirst tile while you are fully hydrated.' },
                { key: 'autoStress', label: 'Auto-hide stress', desc: 'Hide the stress tile while you are calm.' },
                { key: 'autoStamina', label: 'Auto-hide stamina and oxygen', desc: 'Hide the tile while stamina or oxygen is full.' },
            ],
        },
        {
            id: 'vehicle', label: 'Vehicle', icon: 'i-car',
            desc: 'The speedometer and what it shows.',
            rows: [
                { key: 'autoEngine', label: 'Auto-hide engine health', desc: 'Only show engine health once the engine is damaged.' },
                { key: 'autoNitro', label: 'Auto-hide nitrous', desc: 'Hide the nitrous bar while the tank is empty.' },
                { key: 'optimized', label: 'Optimized refresh', desc: 'Update the HUD less often. Easier on low end machines; turn it off for a smoother speedometer.' },
            ],
        },
        {
            id: 'map', label: 'Map', icon: 'i-map',
            desc: 'Minimap shape, frame and visibility.',
            rows: [
                { key: 'mapShape', type: 'seg', label: 'Shape', desc: 'Square or circular minimap.', options: [['square', 'Square'], ['circle', 'Circle']] },
                { key: 'mapFrame', label: 'Map frame', desc: 'Draw the frame around the minimap.' },
                { key: 'hideMap', label: 'Hide the minimap', desc: 'Never show the minimap, not even in vehicles.' },
                { key: 'minimapOnFoot', label: 'Show the minimap on foot', desc: 'It always shows in vehicles.' },
            ],
        },
        {
            id: 'compass', label: 'Compass', icon: 'i-compass',
            desc: 'Heading tape and street names.',
            rows: [
                { key: 'compassShow', label: 'Show the compass', desc: 'The heading tape at the top of the screen.' },
                { key: 'compassOnFoot', label: 'Show on foot', desc: 'It always shows in vehicles.' },
                { key: 'compassFollowCam', label: 'Follow the camera', desc: 'Heading follows where you look instead of where your character faces.' },
                { key: 'streetNames', label: 'Street names', desc: 'Current street, cross street and area.' },
                { key: 'compassPointer', label: 'Centre pointer', desc: 'The marker at the middle of the tape.' },
                { key: 'compassDegrees', label: 'Degrees', desc: 'The numeric heading under the tape.' },
                { key: 'compassOptimized', label: 'Optimized updates', desc: 'Refresh the compass 20 times a second instead of every frame.' },
            ],
        },
        {
            id: 'alerts', label: 'Sound & alerts', icon: 'i-bell',
            desc: 'Menu sounds and notifications.',
            rows: [
                { key: 'soundMenu', label: 'Menu open / close sounds', desc: '' },
                { key: 'soundToggle', label: 'Toggle sounds', desc: 'A click when you change a setting.' },
                { key: 'soundReset', label: 'Reset sounds', desc: 'Played when the HUD restarts or resets.' },
                { key: 'notifyMap', label: 'Map notifications', desc: 'Tell me when the map shape changes.' },
                { key: 'notifyFuel', label: 'Low fuel alert', desc: 'Beep and notify when the tank is nearly empty.' },
                { key: 'notifyCinematic', label: 'Cinematic notifications', desc: 'Tell me when cinematic mode turns on or off.' },
            ],
        },
    ];

    const menu = {
        el: $('#menu'),
        tabs: $('#tabs'),
        rows: $('#rows'),
        title: $('#tabTitle'),
        desc: $('#tabDesc'),
        tab: SCHEMA[0].id,
        open: false,
    };

    function setSetting(key, value) {
        state.settings[key] = value;
        renderRows();
        applyCompassSettings();
        if (key === 'mapShape') setShape(value);
        post('set', { key, value });
    }

    function buildTabs() {
        menu.tabs.textContent = '';
        SCHEMA.forEach((group) => {
            const tab = document.createElement('button');
            tab.type = 'button';
            tab.className = `tab${group.id === menu.tab ? ' on' : ''}`;
            tab.innerHTML = `<svg class="icon"><use href="#${group.icon}"/></svg><span>${group.label}</span>`;
            tab.addEventListener('click', () => {
                menu.tab = group.id;
                buildTabs();
                renderRows();
            });
            menu.tabs.appendChild(tab);
        });
    }

    function renderRows() {
        const group = SCHEMA.find((g) => g.id === menu.tab) || SCHEMA[0];
        menu.title.textContent = group.label;
        menu.desc.textContent = group.desc;
        menu.rows.textContent = '';

        group.rows.forEach((def) => {
            const row = document.createElement('div');
            row.className = 'row';
            const text = document.createElement('div');
            text.className = 'row-text';
            text.innerHTML = `<div class="row-label"></div>${def.desc ? '<div class="row-desc"></div>' : ''}`;
            $('.row-label', text).textContent = def.label;
            if (def.desc) $('.row-desc', text).textContent = def.desc;
            row.appendChild(text);

            const value = state.settings[def.key];
            if (def.type === 'seg') {
                const seg = document.createElement('div');
                seg.className = 'seg';
                def.options.forEach(([optValue, optLabel]) => {
                    const button = document.createElement('button');
                    button.type = 'button';
                    button.textContent = optLabel;
                    button.className = value === optValue ? 'on' : '';
                    button.addEventListener('click', () => {
                        if (state.settings[def.key] !== optValue) setSetting(def.key, optValue);
                    });
                    seg.appendChild(button);
                });
                row.appendChild(seg);
            } else {
                const sw = document.createElement('button');
                sw.type = 'button';
                sw.className = 'sw';
                sw.setAttribute('role', 'switch');
                sw.setAttribute('aria-checked', value ? 'true' : 'false');
                sw.setAttribute('aria-label', def.label);
                sw.addEventListener('click', () => setSetting(def.key, !state.settings[def.key]));
                row.appendChild(sw);
                row.addEventListener('click', (e) => {
                    if (e.target === row || e.target.closest('.row-text')) sw.click();
                });
            }
            menu.rows.appendChild(row);
        });

        $('#actCinematic').classList.toggle('on', !!state.settings.cinematic);
    }

    function openMenu(settings) {
        if (settings) state.settings = settings;
        menu.open = true;
        menu.el.hidden = false;
        buildTabs();
        renderRows();
        requestAnimationFrame(() => menu.el.classList.add('open'));
        // some embedded browsers throttle rAF, make sure it opens either way
        setTimeout(() => menu.el.classList.add('open'), 60);
    }

    function closeMenu(notify) {
        if (!menu.open) return;
        menu.open = false;
        menu.el.classList.remove('open');
        setTimeout(() => {
            if (!menu.open) menu.el.hidden = true;
        }, 170);
        if (notify) post('close');
    }

    $('#menuClose').addEventListener('click', () => closeMenu(true));
    menu.el.addEventListener('mousedown', (e) => {
        if (e.target === menu.el) closeMenu(true);
    });
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && menu.open) closeMenu(true);
    });
    $('#actCinematic').addEventListener('click', () => setSetting('cinematic', !state.settings.cinematic));
    $('#actRestart').addEventListener('click', () => post('action', { name: 'restart' }));
    $('#actReset').addEventListener('click', () => post('action', { name: 'reset' }));

    // ------------------------------------------------------------------ messages

    function applySettings(settings) {
        if (!settings) return;
        state.settings = settings;
        setShape(settings.mapShape);
        applyCompassSettings();
        if (menu.open) renderRows();
    }

    function init(m) {
        if (m.accent) setAccent(m.accent);
        if (m.currency) state.currency = m.currency;
        makeFormatter();
        state.mph = m.mph !== false;
        state.maxSpeed = num(m.maxSpeed, 180) || 180;
        state.stress = m.stress !== false;
        state.mapFrame = m.mapFrame || state.mapFrame;
        vehicle.unit.textContent = state.mph ? 'MPH' : 'KM/H';
        vehicle.altUnit.textContent = state.mph ? 'ALT FT' : 'ALT M';

        const levels = num(m.voiceLevels, 3) || 3;
        if (levels !== state.voiceLevels || !cells.voice.pips.children.length) {
            state.voiceLevels = levels;
            buildPips(levels);
        }
        applySettings(m.settings);
    }

    function restart() {
        state.restarting = true;
        body.classList.add('hud-hidden');
        compass.el.hidden = true;
        vehicle.el.classList.remove('on');
        setTimeout(() => {
            state.restarting = false;
        }, 1400);
    }

    window.addEventListener('message', (event) => {
        const m = event.data;
        if (!m || !m.action) return;
        switch (m.action) {
            case 'init': init(m); break;
            case 'settings': applySettings(m.settings); break;
            case 'tick': tick(m); break;
            case 'compass': onCompass(m); break;
            case 'money': onMoney(m); break;
            case 'menu': m.open ? openMenu(m.settings) : closeMenu(false); break;
            case 'restart': restart(); break;
        }
    });

    window.addEventListener('resize', buildTape);

    // ------------------------------------------------------------------ boot

    makeFormatter();
    buildDock();
    buildPips(state.voiceLevels);
    buildMoney();
    buildTape();
    post('ready');
})();
