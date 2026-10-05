/* ze-phone NUI core: the ZP namespace, DOM helper, talking to Lua, shared state, formatting.
   Lua -> UI: { action, data } through window 'message' (see main.js). UI -> Lua: ZP.api(name, args) for a server request,
   ZP.post(name, data) for a client callback. Outside the game (dev/preview.html) window.ZE_POST stands in for Lua. */

(() => {
    'use strict';

    const ZP = window.ZP = {};
    const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'ze-phone';

    // ------------------------------------------------------------------ talking to Lua

    ZP.post = (name, data) => {
        if (window.ZE_POST) return Promise.resolve(window.ZE_POST(name, data || {}));
        return fetch(`https://${RESOURCE}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).then(r => r.json()).catch(() => null);
    };

    // a request to the server through the Lua side. Always answers an object; { error } when it failed.
    ZP.api = (name, args) => ZP.post('rpc', { name, args: args || {} }).then(res => (res && typeof res === 'object' ? res : { error: 'No answer from the server' }));

    // ------------------------------------------------------------------ events

    const handlers = {};
    ZP.on = (event, fn) => {
        (handlers[event] = handlers[event] || []).push(fn);
        return () => { handlers[event] = (handlers[event] || []).filter(f => f !== fn); };
    };
    ZP.emit = (event, data, extra) => {
        (handlers[event] || []).slice().forEach(fn => {
            try { fn(data, extra); } catch (err) { console.error('[ze-phone]', event, err); }
        });
    };
    // things Lua pushes (new message, mail, tweet ...): ZP.onPush('message', (data, mute) => ...)
    ZP.onPush = (name, fn) => ZP.on('push:' + name, fn);

    // ------------------------------------------------------------------ DOM

    const NS = 'http://www.w3.org/2000/svg';

    // h('div.card#id', { onclick, class, style, dataset, ... }, children...)
    ZP.h = (tag, props, ...kids) => {
        const parts = /^([a-z0-9-]*)((?:[.#][\w-]+)*)$/i.exec(tag) || [null, 'div', ''];
        const el = document.createElement(parts[1] || 'div');
        const classes = [];
        parts[2].replace(/([.#])([\w-]+)/g, (_, kind, name) => {
            if (kind === '.') classes.push(name); else el.id = name;
        });
        if (props && (props.nodeType || Array.isArray(props) || typeof props === 'string' || typeof props === 'number')) {
            kids.unshift(props);
            props = null;
        }
        if (props) {
            for (const key of Object.keys(props)) {
                const value = props[key];
                if (value === undefined || value === null || value === false) continue;
                if (key === 'class' || key === 'className') classes.push(...String(value).split(/\s+/).filter(Boolean));
                else if (key === 'style') {
                    if (typeof value === 'string') el.style.cssText += value;
                    else Object.keys(value).forEach(k => { if (k[0] === '-') el.style.setProperty(k, value[k]); else el.style[k] = value[k]; });
                } else if (key === 'dataset') Object.assign(el.dataset, value);
                else if (key.startsWith('on') && typeof value === 'function') el.addEventListener(key.slice(2), value);
                else if (key === 'text') el.textContent = value;
                else if (value === true) el.setAttribute(key, '');
                else el.setAttribute(key, value);
            }
        }
        if (classes.length) el.className = classes.join(' ');
        const add = (kid) => {
            if (kid === null || kid === undefined || kid === false) return;
            if (Array.isArray(kid)) kid.forEach(add);
            else if (kid.nodeType) el.appendChild(kid);
            else el.appendChild(document.createTextNode(String(kid)));
        };
        kids.forEach(add);
        return el;
    };

    ZP.icon = (name, cls) => {
        const svg = document.createElementNS(NS, 'svg');
        svg.setAttribute('class', 'ic' + (cls ? ' ' + cls : ''));
        const use = document.createElementNS(NS, 'use');
        use.setAttribute('href', '#i-' + name);
        svg.appendChild(use);
        return svg;
    };

    ZP.clear = (el) => { while (el.firstChild) el.removeChild(el.firstChild); return el; };

    ZP.uid = (() => { let n = 0; return () => 'z' + (++n); })();

    // FontAwesome class names from other resources ('fas fa-phone') to one of our icons
    ZP.iconFromFa = (fa) => {
        const s = String(fa || '').toLowerCase();
        const table = [
            ['whatsapp', 'message'], ['comment', 'message'], ['sms', 'message'], ['phone', 'phone'], ['envelope', 'mail'], ['twitter', 'bird'],
            ['university', 'bank'], ['bank', 'bank'], ['coins', 'coins'], ['chart', 'coins'], ['car', 'car'], ['flag', 'flag'], ['home', 'home'],
            ['house', 'home'], ['ad', 'megaphone'], ['bullhorn', 'megaphone'], ['camera', 'camera'], ['image', 'image'], ['shield', 'shield'],
            ['politie', 'shield'], ['exclamation', 'alert'], ['bell', 'bell'], ['cog', 'settings'], ['briefcase', 'briefcase'],
            ['map', 'pin'], ['fire', 'fire'], ['ambulance', 'cross'], ['medkit', 'cross'],
        ];
        for (const [needle, icon] of table) if (s.includes(needle)) return icon;
        return 'bell';
    };

    // ------------------------------------------------------------------ formatting

    const DAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    const pad = n => String(n).padStart(2, '0');

    // a database or Lua time as milliseconds: seconds, milliseconds or a date string
    const toMs = (v) => {
        if (v === null || v === undefined || v === '') return 0;
        if (typeof v === 'number') return v < 1e11 ? v * 1000 : v;
        const parsed = Date.parse(v);
        return Number.isNaN(parsed) ? 0 : parsed;
    };

    ZP.fmt = {
        days: DAYS,
        months: MONTHS,
        pad,
        toMs,
        money: (n) => '$' + Math.round(Number(n) || 0).toLocaleString('en-US'),
        number: (n) => {
            const d = String(n || '').replace(/\D/g, '');
            if (d.length === 10) return `${d.slice(0, 3)}-${d.slice(3, 6)}-${d.slice(6)}`;
            return String(n || '');
        },
        hm: (ts) => { const d = new Date(toMs(ts)); return pad(d.getHours()) + ':' + pad(d.getMinutes()); },
        gameClock: () => { const t = ZP.state.time; return pad(t.h) + ':' + pad(t.m); },
        dur: (sec) => {
            sec = Math.max(0, Math.floor(sec));
            const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60), s = sec % 60;
            return (h ? h + ':' + pad(m) : m) + ':' + pad(s);
        },
        // Today / Yesterday / Mon 5 Oct. Takes a time or the 'YYYY-MM-DD' of a stored chat day (other text is returned as is).
        day: (v) => {
            let d;
            if (typeof v === 'string' && /^\d{4}-\d{2}-\d{2}$/.test(v)) d = new Date(v + 'T12:00:00');
            else if (typeof v === 'string' && Number.isNaN(Date.parse(v))) return v;
            else d = new Date(toMs(v));
            if (Number.isNaN(d.getTime())) return String(v || '');
            const today = new Date();
            const a = new Date(today.getFullYear(), today.getMonth(), today.getDate()).getTime();
            const b = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
            const diff = Math.round((a - b) / 86400000);
            if (diff === 0) return 'Today';
            if (diff === 1) return 'Yesterday';
            if (diff > 1 && diff < 7) return DAYS[d.getDay()];
            return `${DAYS[d.getDay()].slice(0, 3)} ${d.getDate()} ${MONTHS[d.getMonth()].slice(0, 3)}`;
        },
        // 3:45 for today, Yesterday, Mon, 5 Oct
        short: (v) => {
            const ms = toMs(v);
            if (!ms) return '';
            const label = ZP.fmt.day(ms);
            if (label === 'Today') return ZP.fmt.hm(ms);
            if (label === 'Yesterday') return label;
            const parts = label.split(' ');
            return parts.length > 1 ? parts.slice(1).join(' ') : label.slice(0, 3);
        },
        ago: (v) => {
            const s = Math.max(0, (Date.now() - toMs(v)) / 1000);
            if (s < 60) return 'now';
            if (s < 3600) return Math.floor(s / 60) + 'm';
            if (s < 86400) return Math.floor(s / 3600) + 'h';
            return Math.floor(s / 86400) + 'd';
        },
        compact: (n) => {
            n = Number(n) || 0;
            if (n >= 1e6) return (n / 1e6).toFixed(1).replace(/\.0$/, '') + 'M';
            if (n >= 1e3) return (n / 1e3).toFixed(1).replace(/\.0$/, '') + 'k';
            return String(n);
        },
    };

    // ------------------------------------------------------------------ safety

    ZP.safeUrl = (u) => typeof u === 'string' && /^https?:\/\//i.test(u) && !/[\s"'<>`\\]/.test(u);

    ZP.setBg = (el, url) => {
        el.style.backgroundImage = ZP.safeUrl(url) ? `url("${url}")` : '';
    };

    // mail bodies are small HTML snippets from other resources: keep a few harmless tags, drop everything else
    const ALLOWED = new Set(['B', 'STRONG', 'I', 'EM', 'U', 'BR', 'P', 'HR', 'SPAN', 'UL', 'OL', 'LI', 'DIV', 'H1', 'H2', 'H3', 'SMALL']);
    const DROP = new Set(['SCRIPT', 'STYLE', 'IFRAME', 'OBJECT', 'EMBED', 'LINK', 'META', 'TEMPLATE', 'NOSCRIPT', 'SVG', 'FORM']);
    ZP.richText = (html) => {
        const doc = new DOMParser().parseFromString('<body>' + String(html || '') + '</body>', 'text/html');
        const out = document.createDocumentFragment();
        const walk = (node, parent) => {
            node.childNodes.forEach((n) => {
                if (n.nodeType === 3) parent.appendChild(document.createTextNode(n.nodeValue));
                else if (n.nodeType === 1) {
                    if (DROP.has(n.tagName)) return;
                    if (ALLOWED.has(n.tagName)) {
                        const e = document.createElement(n.tagName.toLowerCase());
                        parent.appendChild(e);
                        walk(n, e);
                    } else walk(n, parent);
                }
            });
        };
        walk(doc.body, out);
        return out;
    };
    ZP.stripHtml = (html) => {
        const doc = new DOMParser().parseFromString('<body>' + String(html || '').replace(/<br\s*\/?>/gi, ' ') + '</body>', 'text/html');
        return (doc.body.textContent || '').replace(/\s+/g, ' ').trim();
    };

    ZP.copy = (text) => {
        const area = document.createElement('textarea');
        area.value = String(text);
        area.style.cssText = 'position:fixed;left:-999px;top:0;opacity:0';
        document.body.appendChild(area);
        area.select();
        let ok = false;
        try { ok = document.execCommand('copy'); } catch (e) { ok = false; }
        area.remove();
        if (ZP.ui && ZP.ui.toast) ZP.ui.toast(ok ? 'Copied' : 'Could not copy');
        return ok;
    };

    // ------------------------------------------------------------------ accent colour (same code as ze-hud and ze-clothing)

    const hexToRgb = (hex) => {
        const m = /^#?([0-9a-f]{6})$/i.exec(String(hex).trim());
        if (!m) return null;
        const n = parseInt(m[1], 16);
        return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
    };

    const gradientPartner = (r, g, b) => {
        const rn = r / 255, gn = g / 255, bn = b / 255;
        const max = Math.max(rn, gn, bn), min = Math.min(rn, gn, bn);
        const lig = (max + min) / 2;
        const d = max - min;
        let hue = 0, sat = 0;
        if (d) {
            sat = lig > 0.5 ? d / (2 - max - min) : d / (max + min);
            if (max === rn) hue = (gn - bn) / d + (gn < bn ? 6 : 0);
            else if (max === gn) hue = (bn - rn) / d + 2;
            else hue = (rn - gn) / d + 4;
            hue *= 60;
        }
        hue = (hue + 30) % 360;
        const l2 = Math.min(0.78, lig + 0.04);
        const c = (1 - Math.abs(2 * l2 - 1)) * sat;
        const x = c * (1 - Math.abs(((hue / 60) % 2) - 1));
        const m = l2 - c / 2;
        const out = hue < 60 ? [c, x, 0] : hue < 120 ? [x, c, 0] : hue < 180 ? [0, c, x] : hue < 240 ? [0, x, c] : hue < 300 ? [x, 0, c] : [c, 0, x];
        return '#' + out.map(v => Math.round((v + m) * 255).toString(16).padStart(2, '0')).join('');
    };

    ZP.setAccent = (hex) => {
        const rgb = hexToRgb(hex);
        if (!rgb) return;
        const root = document.documentElement.style;
        root.setProperty('--accent', hex);
        root.setProperty('--accent-rgb', rgb.join(', '));
        root.setProperty('--accent-2', gradientPartner(rgb[0], rgb[1], rgb[2]));
        const lum = (0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]) / 255;
        root.setProperty('--accent-ink', lum > 0.45 ? '#1a0c02' : '#ffffff');
    };

    // ------------------------------------------------------------------ shared state

    ZP.DEFAULT_SETTINGS = {
        background: 'ember', profilepicture: 'default', accent: false, ringtone: 'default', texttone: 'default',
        dnd: false, airplane: false, silent: false, anonymous: false, brightness: 100, favorites: [], order: [], muted: {},
    };

    ZP.state = {
        ready: false,
        open: false,
        ui: { apps: [], wallpapers: [], accents: [], ringtones: [], texttones: [], places: [], keys: {}, limits: {}, accent: '#ff7a1a' },
        me: { name: '', number: '', account: '', serial: '', citizenid: '', picture: 'default' },
        player: { id: 0, money: { cash: 0, bank: 0, crypto: 0 }, job: {}, mdt: false },
        settings: Object.assign({}, ZP.DEFAULT_SETTINGS),
        contacts: [],
        blocked: [],
        chats: [],
        calls: [],
        adverts: [],
        suggestions: [],
        time: { h: 12, m: 0, day: 1, month: 0, year: 2024, weekday: 1 },
        notifications: [],
        call: { phase: 'idle' },
    };

    // ------------------------------------------------------------------ settings

    ZP.applySettings = () => {
        const s = ZP.state.settings;
        const wall = document.getElementById('wall');
        if (wall) {
            const preset = ZP.state.ui.wallpapers.find(w => w.id === s.background);
            if (preset) { wall.style.backgroundImage = preset.css; }
            else if (ZP.safeUrl(s.background)) { wall.style.backgroundImage = `url("${s.background}")`; }
            else if (ZP.state.ui.wallpapers[0]) { wall.style.backgroundImage = ZP.state.ui.wallpapers[0].css; }
        }
        ZP.setAccent(s.accent || ZP.state.ui.accent || '#ff7a1a');
        const dim = document.getElementById('dim');
        if (dim) dim.style.opacity = String(Math.max(0, Math.min(0.7, (100 - (s.brightness || 100)) / 100)));
        ZP.emit('settings', s);
    };

    // optimistic: the phone changes at once, the server confirms
    let saveTimer = null;
    let pending = {};
    ZP.saveSettings = (patch) => {
        Object.assign(ZP.state.settings, patch);
        Object.assign(pending, patch);
        ZP.applySettings();
        clearTimeout(saveTimer);
        saveTimer = setTimeout(() => {
            const send = pending;
            pending = {};
            ZP.api('settings:save', { patch: send }).then((res) => {
                if (res.error) ZP.ui.toast(res.error);
            });
        }, 250);
    };

    // ------------------------------------------------------------------ contacts

    let byNumber = {};
    ZP.contacts = {
        set(list) {
            ZP.state.contacts = list.slice().sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: 'base' }));
            byNumber = {};
            ZP.state.contacts.forEach(c => { byNumber[c.number] = c; });
            ZP.emit('contacts', ZP.state.contacts);
        },
        byNumber: (n) => byNumber[String(n || '').replace(/\D/g, '')] || null,
        nameOf: (n) => {
            const c = byNumber[String(n || '').replace(/\D/g, '')];
            return c ? c.name : ZP.fmt.number(n);
        },
        isFavorite: (n) => (ZP.state.settings.favorites || []).includes(n),
        isBlocked: (n) => ZP.state.blocked.includes(n),
    };

    // ------------------------------------------------------------------ badges (unread counters on the app icons)

    ZP.badges = {};
    ZP.setBadge = (app, n) => {
        n = Math.max(0, Number(n) || 0);
        if ((ZP.badges[app] || 0) === n) return;
        ZP.badges[app] = n;
        ZP.emit('badges', ZP.badges);
    };
    ZP.addBadge = (app, d) => ZP.setBadge(app, (ZP.badges[app] || 0) + d);

    // ------------------------------------------------------------------ sound

    ZP.sound = (kind, id) => { ZP.post('sound', { kind, id }); };

    // ------------------------------------------------------------------ notifications
    // { app, title, text, icon, avatar, color, timeout, sound, onTap, force }
    // Do not disturb keeps them in the shade and drops the banner and the sound.

    ZP.notify = (n) => {
        const s = ZP.state.settings;
        const entry = Object.assign({ id: ZP.uid(), ts: Date.now() }, n);
        ZP.state.notifications.unshift(entry);
        if (ZP.state.notifications.length > 60) ZP.state.notifications.length = 60;
        ZP.emit('notifications', ZP.state.notifications);
        if (n.app && s.muted && s.muted[n.app] && !n.force) return entry;
        if (s.dnd && !n.force) return entry;
        if (ZP.shell) ZP.shell.banner(entry);
        if (n.sound !== false && !s.silent) ZP.sound(n.sound === 'alert' ? 'alert' : 'text');
        return entry;
    };
})();
