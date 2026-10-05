/* ze-phone UI components. Everything is built with ZP.h (no innerHTML), so text from players can never become markup.
   The class names are styled in style.css. */

(() => {
    'use strict';

    const { h, icon } = ZP;
    const ui = ZP.ui = {};

    // modals (sheets, dialogs, the image viewer) in the order they were opened, so Esc closes the top one
    ZP.modals = [];
    const overlay = () => document.getElementById('overlay');
    const frame = (fn) => requestAnimationFrame(() => requestAnimationFrame(fn));

    // ------------------------------------------------------------------ small pieces

    const PALETTE = ['#ff7a1a', '#34d399', '#38bdf8', '#a78bfa', '#f472b6', '#fbbf24', '#2dd4bf', '#fb7185', '#a3e635', '#60a5fa'];
    const hash = (s) => { let x = 7; for (let i = 0; i < s.length; i++) x = (x * 31 + s.charCodeAt(i)) >>> 0; return x; };
    ui.colorFor = (key) => PALETTE[hash(String(key || '?')) % PALETTE.length];

    // size: 'sm' | 'md' | 'lg' | 'xl'
    ui.avatar = ({ name, src, size = 'md', color } = {}) => {
        const label = String(name || '?').trim();
        const initial = (label.match(/[\p{L}\p{N}]/u) || ['?'])[0].toUpperCase();
        const el = h(`div.avatar.${size}`, { style: { '--av': color || ui.colorFor(label) } }, h('span', initial));
        if (ZP.safeUrl(src)) {
            const img = h('img', { alt: '', draggable: 'false' });
            img.onerror = () => img.remove();
            img.src = src;
            el.appendChild(img);
        }
        return el;
    };

    ui.chip = (text, kind, iconName) => h(`span.chip${kind ? '.' + kind : ''}`, iconName ? icon(iconName) : null, text);

    ui.spinner = () => h('div.spinner');

    ui.loading = (text) => h('div.loading', ui.spinner(), text ? h('span', text) : null);

    ui.empty = ({ icon: ic, title, text, action } = {}) => h('div.empty',
        ic ? h('div.empty-ic', icon(ic)) : null,
        title ? h('div.empty-title', title) : null,
        text ? h('div.empty-text', text) : null,
        action || null);

    ui.btn = ({ text, icon: ic, kind = 'primary', onclick, block, small, disabled, title } = {}) => {
        const b = h(`button.btn.${kind}${block ? '.block' : ''}${small ? '.small' : ''}`, { onclick, title }, ic ? icon(ic) : null, text ? h('span', text) : null);
        if (disabled) b.disabled = true;
        return b;
    };

    ui.iconBtn = (ic, onclick, { title, kind, size } = {}) => h(`button.ibtn${kind ? '.' + kind : ''}${size ? '.' + size : ''}`, { onclick, title }, icon(ic));

    ui.fab = (ic, onclick, title) => h('button.fab', { onclick, title }, icon(ic));

    // ------------------------------------------------------------------ lists

    // o: { icon, color, avatar, lead, title, sub, right, chevron, onclick, danger, className }
    ui.row = (o) => {
        const lead = o.avatar || o.lead || (o.icon ? h('div.rico', { style: o.color ? { '--c': o.color } : null }, icon(o.icon)) : null);
        const el = h(`div.row${o.onclick ? '.tap' : ''}${o.danger ? '.danger' : ''}${o.className ? '.' + o.className : ''}`, { onclick: o.onclick },
            lead,
            h('div.rmain', o.title !== undefined ? h('div.rtitle', o.title) : null, o.sub !== undefined && o.sub !== null && o.sub !== '' ? h('div.rsub', o.sub) : null),
            o.right !== undefined && o.right !== null ? h('div.rright', o.right) : null,
            o.chevron ? icon('chevron-right', 'rchev') : null);
        return el;
    };

    ui.group = (title, ...rows) => h('div.group', title ? h('div.glabel', title) : null, h('div.gcard', rows));

    ui.toggle = (value, onChange) => {
        let on = !!value;
        const el = h('button.switch', { role: 'switch', type: 'button' }, h('span.knob'));
        const paint = () => { el.classList.toggle('on', on); el.setAttribute('aria-checked', on ? 'true' : 'false'); };
        paint();
        el.addEventListener('click', (e) => {
            e.stopPropagation();
            on = !on;
            paint();
            if (onChange) onChange(on);
        });
        return { el, get: () => on, set: (v) => { on = !!v; paint(); } };
    };

    ui.segmented = (options, value, onChange) => {
        let current = value;
        const buttons = options.map(o => h('button.seg', { type: 'button', onclick: () => select(o.id, true) }, o.label));
        const el = h('div.segmented', buttons);
        const paint = () => buttons.forEach((b, i) => b.classList.toggle('on', options[i].id === current));
        const select = (id, notify) => { current = id; paint(); if (notify && onChange) onChange(id); };
        paint();
        return { el, set: (id) => select(id, false), get: () => current };
    };

    ui.search = ({ placeholder = 'Search', onInput, value = '' } = {}) => {
        const input = h('input', { type: 'text', placeholder, value, autocomplete: 'off', spellcheck: 'false' });
        const clear = h('button.sclear', { type: 'button', hidden: !value, onclick: () => { input.value = ''; fire(); input.focus(); } }, icon('x'));
        const fire = () => { clear.hidden = !input.value; if (onInput) onInput(input.value); };
        input.addEventListener('input', fire);
        return { el: h('div.search', icon('search'), input, clear), input, value: () => input.value, clear: () => { input.value = ''; fire(); } };
    };

    // o: { label, value, placeholder, type, multiline, rows, max, inputmode, onInput, onEnter, prefix, hint, autofocus }
    ui.field = (o = {}) => {
        const attrs = { placeholder: o.placeholder || '', value: o.value || '', maxlength: o.max, autocomplete: 'off', spellcheck: 'false', inputmode: o.inputmode };
        const input = o.multiline
            ? h('textarea', { placeholder: attrs.placeholder, maxlength: o.max, rows: o.rows || 3, spellcheck: 'false' })
            : h('input', Object.assign({ type: o.type || 'text' }, attrs));
        if (o.multiline) input.value = o.value || '';
        const counter = (o.max && o.multiline) ? h('span.fcount', `0/${o.max}`) : null;
        const fire = () => {
            if (o.multiline && o.grow !== false) { input.style.height = 'auto'; input.style.height = Math.min(input.scrollHeight, o.maxHeight || 160) + 'px'; }
            if (counter) counter.textContent = `${input.value.length}/${o.max}`;
            if (o.onInput) o.onInput(input.value);
        };
        input.addEventListener('input', fire);
        if (o.onEnter) input.addEventListener('keydown', (e) => { if (e.key === 'Enter' && !(o.multiline && e.shiftKey)) { e.preventDefault(); o.onEnter(input.value); } });
        const el = h(`label.field${o.multiline ? '.multi' : ''}`,
            o.label ? h('span.flabel', o.label, counter) : (counter ? h('span.flabel', '', counter) : null),
            h('div.finput', o.prefix ? h('span.fprefix', o.prefix) : null, input),
            o.hint ? h('span.fhint', o.hint) : null);
        if (counter) counter.textContent = `${input.value.length}/${o.max}`;
        if (o.autofocus) setTimeout(() => input.focus(), 320);
        return { el, input, value: () => input.value, set: (v) => { input.value = v; fire(); }, focus: () => input.focus() };
    };

    ui.slider = ({ min = 0, max = 100, value = 0, step = 1, onInput, icons } = {}) => {
        const input = h('input.range', { type: 'range', min, max, step, value });
        const paint = () => input.style.setProperty('--p', ((input.value - min) / (max - min) * 100) + '%');
        input.addEventListener('input', () => { paint(); if (onInput) onInput(Number(input.value)); });
        paint();
        return { el: icons ? h('div.slider-row', icon(icons[0]), input, icon(icons[1])) : input, input, set: (v) => { input.value = v; paint(); } };
    };

    // items: [{ id, icon, label, badge }]
    ui.tabbar = (items, active, onChange) => {
        const buttons = {};
        const el = h('nav.tabbar', items.map((it) => {
            const badge = h('span.tbadge', { hidden: true });
            const b = h('button.tab', { type: 'button', onclick: () => select(it.id, true) }, h('span.tico', icon(it.icon), badge), h('span.tlabel', it.label));
            buttons[it.id] = { b, badge };
            return b;
        }));
        let current = active;
        const paint = () => Object.keys(buttons).forEach(id => buttons[id].b.classList.toggle('on', id === current));
        const select = (id, notify) => { current = id; paint(); if (notify && onChange) onChange(id); };
        paint();
        return {
            el,
            select: (id) => select(id, true),
            current: () => current,
            badge: (id, n) => { const t = buttons[id]; if (t) { t.badge.hidden = !n; t.badge.textContent = n > 99 ? '99+' : n; } },
        };
    };

    // ------------------------------------------------------------------ views (a screen inside an app, see shell.js for how they stack)

    // o: { title, large, root, backLabel, actions: [node], body, footer, className }
    ui.view = (o = {}) => {
        const v = { ctx: null };
        const titleEl = h('div.vtitle', o.title || '');
        const bodyEl = h('div.vbody', o.body || null);
        const back = o.root ? h('span.vb-ph') : h('button.vback', { type: 'button', onclick: () => (v.onBack ? v.onBack() : v.ctx && v.ctx.pop()) }, icon('chevron-left'), o.backLabel ? h('span', o.backLabel) : null);
        const actions = h('div.vactions', o.actions || null);
        const bar = h('header.vbar', back, o.large ? h('div.vspacer') : titleEl, actions);
        v.el = h(`section.view${o.large ? '.large' : ''}${o.className ? '.' + o.className : ''}`, bar, o.large ? h('h1.vlarge', o.title || '') : null, bodyEl, o.footer || null);
        v.body = bodyEl;
        v.actions = actions;
        v.setTitle = (t) => { titleEl.textContent = t; const big = v.el.querySelector('.vlarge'); if (big) big.textContent = t; };
        v.setActions = (nodes) => { ZP.clear(actions); [].concat(nodes || []).forEach(n => n && actions.appendChild(n)); };
        v.scrollTop = () => { bodyEl.scrollTop = 0; };
        return v;
    };

    // ------------------------------------------------------------------ modals

    const register = (m) => { ZP.modals.push(m); ZP.emit('modals'); };
    const unregister = (m) => { const i = ZP.modals.indexOf(m); if (i >= 0) ZP.modals.splice(i, 1); ZP.emit('modals'); };

    // build(bodyEl, sheet) fills the sheet. Returns { close, body, el }.
    ui.sheet = ({ title, build, onClose, tall, className } = {}) => {
        const body = h('div.sbody');
        const panel = h(`div.sheet${tall ? '.tall' : ''}${className ? '.' + className : ''}`,
            h('div.grab'),
            title ? h('div.stitle', title) : null,
            body);
        const back = h('div.sback', { onclick: () => sheet.close() });
        const wrap = h('div.swrap', back, panel);
        const sheet = {
            el: wrap, body, panel,
            close: () => {
                if (sheet.closed) return;
                sheet.closed = true;
                unregister(sheet);
                wrap.classList.remove('on');
                setTimeout(() => wrap.remove(), 260);
                if (onClose) onClose();
            },
        };
        overlay().appendChild(wrap);
        register(sheet);
        if (build) build(body, sheet);
        frame(() => wrap.classList.add('on'));
        return sheet;
    };

    ui.dialog = ({ title, text, build, buttons }) => new Promise((resolve) => {
        const body = h('div.dbody');
        const box = h('div.dialog', title ? h('div.dtitle', title) : null, text ? h('div.dtext', text) : null, body, h('div.dbtns', buttons.map(b => h(`button.dbtn${b.kind ? '.' + b.kind : ''}`, { type: 'button', onclick: () => finish(b.value) }, b.label))));
        const back = h('div.dback', { onclick: () => finish(null) });
        const wrap = h('div.dwrap', back, box);
        const modal = { el: wrap, close: () => finish(null) };
        let done = false;
        const finish = (value) => {
            if (done) return;
            done = true;
            unregister(modal);
            wrap.classList.remove('on');
            setTimeout(() => wrap.remove(), 200);
            resolve(value);
        };
        overlay().appendChild(wrap);
        register(modal);
        if (build) build(body, finish);
        frame(() => wrap.classList.add('on'));
    });

    ui.confirm = ({ title, text, ok = 'Confirm', cancel = 'Cancel', danger } = {}) => ui.dialog({
        title, text,
        buttons: [{ label: cancel, value: false }, { label: ok, value: true, kind: danger ? 'danger' : 'primary' }],
    }).then(v => v === true);

    ui.prompt = ({ title, text, value = '', placeholder = '', ok = 'Done', type = 'text', max = 60, inputmode } = {}) => {
        let field;
        return ui.dialog({
            title, text,
            build: (body, finish) => {
                field = ui.field({ value, placeholder, type, max, inputmode, onEnter: (v) => finish(v), autofocus: true });
                body.appendChild(field.el);
            },
            buttons: [{ label: 'Cancel', value: null }, { label: ok, value: '__ok__', kind: 'primary' }],
        }).then(v => (v === '__ok__' ? field.value() : (typeof v === 'string' ? v : null)));
    };

    // an action sheet: [{ icon, label, danger, onclick, sub }]
    ui.menu = (items, { title } = {}) => ui.sheet({
        title,
        build: (body, sheet) => {
            body.appendChild(h('div.gcard', items.filter(Boolean).map(it => ui.row({
                icon: it.icon, color: it.color, title: it.label, sub: it.sub, danger: it.danger,
                onclick: () => { sheet.close(); if (it.onclick) setTimeout(it.onclick, 60); },
            }))));
        },
    });

    ui.toast = (text, kind) => {
        let box = document.getElementById('toasts');
        if (!box) { box = h('div#toasts'); overlay().appendChild(box); }
        const t = h(`div.toast${kind ? '.' + kind : ''}`, text);
        box.appendChild(t);
        frame(() => t.classList.add('on'));
        setTimeout(() => { t.classList.remove('on'); setTimeout(() => t.remove(), 250); }, 2200);
    };

    // a full screen picture. actions: [{ icon, label, onclick, danger }]
    ui.viewer = ({ url, actions = [] }) => {
        const img = h('img.vimg', { alt: '', draggable: 'false' });
        img.src = url;
        const modal = { el: null, close: () => { unregister(modal); wrap.classList.remove('on'); setTimeout(() => wrap.remove(), 220); } };
        const wrap = h('div.viewer',
            h('button.vclose', { type: 'button', onclick: modal.close }, icon('x')),
            h('div.vstage', { onclick: modal.close }, img),
            actions.length ? h('div.vacts', actions.map(a => h(`button.vact${a.danger ? '.danger' : ''}`, { type: 'button', onclick: () => { if (a.keep !== true) modal.close(); a.onclick(); } }, icon(a.icon), h('span', a.label)))) : null);
        modal.el = wrap;
        overlay().appendChild(wrap);
        register(modal);
        frame(() => wrap.classList.add('on'));
        return modal;
    };

    // ------------------------------------------------------------------ pickers

    // pick one of the contacts (optionally only those that pass `filter`). Resolves with the contact or null.
    ui.contactPicker = ({ title = 'Choose a contact', filter, allowNumber } = {}) => new Promise((resolve) => {
        let picked = null;
        ui.sheet({
            title, tall: true,
            onClose: () => resolve(picked),
            build: (body, sheet) => {
                const list = h('div.gcard.flush');
                const paint = (q) => {
                    ZP.clear(list);
                    const needle = (q || '').toLowerCase();
                    const rows = ZP.state.contacts.filter(c => (!filter || filter(c)) && (!needle || c.name.toLowerCase().includes(needle) || c.number.includes(needle)));
                    if (allowNumber && /^\d{3,15}$/.test(needle)) rows.unshift({ name: ZP.fmt.number(needle), number: needle, raw: true });
                    if (!rows.length) list.appendChild(h('div.pad-empty', 'No contacts'));
                    rows.forEach(c => list.appendChild(ui.row({
                        avatar: ui.avatar({ name: c.name, size: 'sm' }), title: c.name, sub: c.raw ? 'Use this number' : ZP.fmt.number(c.number),
                        onclick: () => { picked = c; sheet.close(); },
                    })));
                };
                const s = ui.search({ placeholder: allowNumber ? 'Search or type a number' : 'Search contacts', onInput: paint });
                body.appendChild(s.el);
                body.appendChild(list);
                paint('');
            },
        });
    });

    // the players around you: Resolves with { id, name } or null
    ui.nearbyPicker = ({ title = 'Who is next to you?' } = {}) => new Promise((resolve) => {
        let picked = null;
        ui.sheet({
            title,
            onClose: () => resolve(picked),
            build: (body, sheet) => {
                const list = h('div.gcard.flush', ui.loading('Looking around'));
                body.appendChild(list);
                ZP.api('players:nearby', { radius: 10 }).then((res) => {
                    ZP.clear(list);
                    const players = res.players || [];
                    if (!players.length) list.appendChild(h('div.pad-empty', 'Nobody is close enough'));
                    players.forEach(p => list.appendChild(ui.row({
                        avatar: ui.avatar({ name: p.name, src: p.picture, size: 'sm' }), title: p.name, sub: `${p.distance} m away`,
                        onclick: () => { picked = p; sheet.close(); },
                    })));
                });
            },
        });
    });

    // a photo: from the gallery, from the camera, or a link. Resolves with the address or null.
    ui.photoPicker = ({ title = 'Add a photo', allowCamera = true } = {}) => new Promise((resolve) => {
        let picked = null;
        let deferred = false;   // the camera answers later: the sheet closing must not settle the promise
        ui.sheet({
            title, tall: true,
            onClose: () => { if (!deferred) resolve(picked); },
            build: (body, sheet) => {
                const grid = h('div.photo-grid', ui.loading());
                const actions = h('div.gcard',
                    allowCamera ? ui.row({
                        icon: 'camera', title: 'Take a photo', chevron: true,
                        onclick: () => {
                            deferred = true;
                            sheet.close();
                            setTimeout(() => ZP.camera.open((url) => resolve(url)), 120);
                        },
                    }) : null,
                    ui.row({
                        icon: 'link', title: 'Paste a link', chevron: true,
                        onclick: async () => {
                            const link = await ui.prompt({ title: 'Image link', placeholder: 'https://...', type: 'url', max: 500, ok: 'Use' });
                            if (link && ZP.safeUrl(link.trim())) { picked = link.trim(); sheet.close(); }
                            else if (link) ui.toast('That is not a usable link');
                        },
                    }));
                body.appendChild(actions);
                body.appendChild(h('div.glabel', 'Gallery'));
                body.appendChild(grid);
                ZP.gallery.list().then((photos) => {
                    ZP.clear(grid);
                    if (!photos.length) { grid.className = ''; grid.appendChild(h('div.pad-empty', 'Your gallery is empty')); return; }
                    photos.forEach(p => {
                        const cell = h('button.photo', { type: 'button', onclick: () => { picked = p.url; sheet.close(); } });
                        ZP.setBg(cell, p.url);
                        grid.appendChild(cell);
                    });
                });
            },
        });
    });

    // ------------------------------------------------------------------ misc

    ui.sparkline = (values, { width = 300, height = 90, color = 'var(--accent)' } = {}) => {
        const NS = 'http://www.w3.org/2000/svg';
        const svg = document.createElementNS(NS, 'svg');
        svg.setAttribute('viewBox', `0 0 ${width} ${height}`);
        svg.setAttribute('class', 'spark');
        svg.setAttribute('preserveAspectRatio', 'none');
        if (!values || values.length < 2) return svg;
        const min = Math.min(...values), max = Math.max(...values);
        const span = (max - min) || 1;
        const pts = values.map((v, i) => [i / (values.length - 1) * width, height - 6 - ((v - min) / span) * (height - 14)]);
        const line = pts.map((p, i) => (i ? 'L' : 'M') + p[0].toFixed(1) + ' ' + p[1].toFixed(1)).join(' ');
        const id = ZP.uid();
        svg.innerHTML = `<defs><linearGradient id="${id}" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="${color}" stop-opacity=".35"/><stop offset="1" stop-color="${color}" stop-opacity="0"/></linearGradient></defs>`
            + `<path d="${line} L${width} ${height} L0 ${height} Z" fill="url(#${id})"/>`
            + `<path d="${line}" fill="none" stroke="${color}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" vector-effect="non-scaling-stroke"/>`;
        return svg;
    };

    // debounce, used by search boxes
    ui.debounce = (fn, ms = 200) => { let t; return (...a) => { clearTimeout(t); t = setTimeout(() => fn(...a), ms); }; };

    // the text of a message with #hashtags and @mentions as spans
    ui.richPlain = (text, onTag, onMention) => {
        const frag = document.createDocumentFragment();
        const re = /([#@])([\w]+)/g;
        let last = 0, m;
        while ((m = re.exec(text))) {
            if (m.index > last) frag.appendChild(document.createTextNode(text.slice(last, m.index)));
            const kind = m[1], word = m[2];
            frag.appendChild(h('span.tag', { onclick: (e) => { e.stopPropagation(); (kind === '#' ? onTag : onMention)?.(word); } }, kind + word));
            last = m.index + m[0].length;
        }
        if (last < text.length) frag.appendChild(document.createTextNode(text.slice(last)));
        return frag;
    };
})();
