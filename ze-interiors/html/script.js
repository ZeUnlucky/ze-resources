/* ze-interiors NUI. Vanilla JS, no build step, no CDNs, no jQuery.
   Lua sends: open, data, close.
   The UI sends back: getData, getPosition, lookupPlayer, createHouse, sellHouse, deleteHouse, close. (See README.md.) */

(() => {
    'use strict';

    const $ = (selector, parent = document) => parent.querySelector(selector);

    // Outside the game (dev/preview.html) there is no resource name; ZE_POST lets the preview intercept calls.
    const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'ze-interiors';

    function post(name, data) {
        if (window.ZE_POST) return Promise.resolve(window.ZE_POST(name, data || {}));
        return fetch(`https://${RESOURCE}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).then((r) => r.json()).catch(() => null);
    }

    // ------------------------------------------------------------------ accent (same code as ze-hud and ze-clothing)

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
        root.setProperty('--accent-2', gradientPartner(rgb[0], rgb[1], rgb[2]));
        const luminance = (0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]) / 255;
        root.setProperty('--accent-ink', luminance > 0.45 ? '#1a0c02' : '#ffffff');
    }

    // The accent gradient ends on the same colour with the hue rotated 30 degrees and a touch lighter.
    function gradientPartner(r, g, b) {
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
        return `#${out.map((v) => Math.round((v + m) * 255).toString(16).padStart(2, '0')).join('')}`;
    }

    // ------------------------------------------------------------------ dom helpers

    const SVG_NS = 'http://www.w3.org/2000/svg';

    function el(tag, cls, text) {
        const e = document.createElement(tag);
        if (cls) e.className = cls;
        if (text !== undefined && text !== null) e.textContent = text;
        return e;
    }

    function icon(name) {
        const svg = document.createElementNS(SVG_NS, 'svg');
        svg.setAttribute('class', 'icon');
        const use = document.createElementNS(SVG_NS, 'use');
        use.setAttribute('href', `#i-${name}`);
        svg.appendChild(use);
        return svg;
    }

    const toList = (v) => (Array.isArray(v) ? v : (v && typeof v === 'object' ? Object.values(v) : []));
    const plural = (n, one, many) => `${n} ${n === 1 ? one : many}`;

    // ------------------------------------------------------------------ state

    const COORD_KEYS = ['x', 'y', 'z', 'w'];

    const S = {
        open: false,
        tab: 'houses',
        busy: false,
        interiors: [],
        houses: [],
        add: { name: '', interior: null, entrances: [] },   // entrances: [{ x, y, z, w }] as the typed strings
        sell: { house: null, player: '' },
        lookup: { state: 'idle', seq: 0, timer: null },
        pendingDelete: null,
        hideTimer: null,
    };

    const interiorById = (id) => S.interiors.find((i) => String(i.id) === String(id)) || null;
    const houseById = (id) => S.houses.find((h) => String(h.id) === String(id)) || null;
    const ownerLabel = (h) => h.ownerName || h.owner || '';

    // ------------------------------------------------------------------ tabs

    const TITLES = { houses: null, add: 'Create house', sell: 'Sell house' };

    function selectTab(tab) {
        S.tab = tab;
        document.querySelectorAll('#tabs .tab').forEach((b) => b.classList.toggle('on', b.dataset.tab === tab));
        ['houses', 'add', 'sell'].forEach((t) => { $(`#pane-${t}`).hidden = t !== tab; });
        $('#foot').hidden = tab === 'houses';
        $('#submit-label').textContent = TITLES[tab] || '';
        if (tab === 'sell') renderSellSelect();
        refreshForm();
    }

    document.querySelectorAll('#tabs .tab').forEach((b) => b.addEventListener('click', () => selectTab(b.dataset.tab)));

    // ------------------------------------------------------------------ houses list

    function renderSubtitle() {
        const owned = S.houses.filter((h) => ownerLabel(h)).length;
        $('#subtitle').textContent = `${plural(S.houses.length, 'house', 'houses')} · ${owned} owned`;
    }

    function chip(cls, iconName, text) {
        const c = el('span', `chip ${cls}`);
        if (iconName) c.appendChild(icon(iconName));
        c.appendChild(document.createTextNode(text));
        return c;
    }

    function meta(iconName, label, value) {
        const m = el('span');
        m.appendChild(icon(iconName));
        if (label) m.appendChild(document.createTextNode(`${label} `));
        m.appendChild(el('b', null, value));
        return m;
    }

    function houseRow(h) {
        const owner = ownerLabel(h);
        const row = el('div', 'house');
        row.appendChild(el('div', 'house-id', `#${h.id}`));

        const main = el('div', 'house-main');
        main.appendChild(el('div', 'house-name', h.name || `House ${h.id}`));
        const metaRow = el('div', 'house-meta');
        metaRow.append(
            meta('home', '', h.interiorName || 'No interior'),
            meta('door', '', plural(Number(h.entrances) || 0, 'entrance', 'entrances')),
            meta('user', '', owner || 'Nobody'),
        );
        main.appendChild(metaRow);
        row.appendChild(main);

        const chips = el('div', 'chips');
        chips.appendChild(owner ? chip('owned', 'user', 'Owned') : chip('free', 'tag', 'For sale'));
        chips.appendChild(h.locked ? chip('locked', 'lock', 'Locked') : chip('', 'unlock', 'Unlocked'));
        row.appendChild(chips);

        const actions = el('div', 'house-actions');
        const sell = el('button', 'btn-sm');
        sell.type = 'button';
        sell.append(icon('tag'), document.createTextNode('Sell'));
        sell.addEventListener('click', () => {
            S.sell.house = h.id;
            selectTab('sell');
            $('#sell-player').focus();
        });
        const del = el('button', 'btn-sm danger');
        del.type = 'button';
        del.title = 'Delete house';
        del.appendChild(icon('trash'));
        del.addEventListener('click', () => askDelete(h));
        actions.append(sell, del);
        row.appendChild(actions);
        return row;
    }

    function renderHouses() {
        const list = $('#house-list');
        list.textContent = '';
        renderSubtitle();

        if (!S.houses.length) {
            const e = el('div', 'empty');
            e.append(el('b', null, 'No houses yet'), document.createTextNode('Use the Add house tab to create the first one.'));
            list.appendChild(e);
            return;
        }

        const q = $('#search').value.trim().toLowerCase();
        const shown = S.houses.filter((h) => !q
            || [h.name, h.interiorName, h.owner, h.ownerName, `#${h.id}`].join(' ').toLowerCase().includes(q));
        if (!shown.length) {
            const e = el('div', 'empty');
            e.append(el('b', null, 'No matches'), document.createTextNode('No house matches that search.'));
            list.appendChild(e);
            return;
        }
        shown.forEach((h) => list.appendChild(houseRow(h)));
    }

    $('#search').addEventListener('input', renderHouses);

    // ------------------------------------------------------------------ delete

    function askDelete(h) {
        S.pendingDelete = h.id;
        const owner = ownerLabel(h);
        const text = $('#modal-text');
        text.textContent = '';
        text.append(
            document.createTextNode('This removes '),
            el('b', null, h.name || `House ${h.id}`),
            document.createTextNode(` (#${h.id}) for good.`),
        );
        if (owner) {
            text.append(document.createTextNode(' It is currently owned by '), el('b', null, owner), document.createTextNode('.'));
        }
        $('#modal').hidden = false;
        $('#modal-cancel').focus();
    }

    function closeModal() {
        S.pendingDelete = null;
        $('#modal').hidden = true;
    }

    $('#modal-cancel').addEventListener('click', closeModal);
    $('#modal-ok').addEventListener('click', () => {
        const id = S.pendingDelete;
        closeModal();
        if (id === null) return;
        act(post('deleteHouse', { house: id }), 'House deleted', 'Could not delete the house');
    });

    // ------------------------------------------------------------------ add house

    function renderInteriors() {
        const wrap = $('#add-interiors');
        wrap.textContent = '';
        if (!S.interiors.length) {
            const e = el('div', 'empty');
            e.append(el('b', null, 'No interiors'), document.createTextNode('No interiors are set up in the config.'));
            wrap.appendChild(e);
            return;
        }
        S.interiors.forEach((it) => {
            const b = el('button', `interior${String(S.add.interior) === String(it.id) ? ' on' : ''}`);
            b.type = 'button';
            const ico = el('div', 'interior-ico');
            ico.appendChild(icon('home'));
            const txt = el('div');
            txt.append(el('div', 'interior-name', it.name || `Interior ${it.id}`), el('div', 'interior-sub', plural(Number(it.exits) || 0, 'exit', 'exits')));
            b.append(ico, txt);
            b.addEventListener('click', () => pickInterior(it.id));
            wrap.appendChild(b);
        });
    }

    function pickInterior(id) {
        S.add.interior = id;
        const exits = Number((interiorById(id) || {}).exits) || 0;
        // keep what was typed for the entrances that still exist, add or drop the rest
        const next = [];
        for (let i = 0; i < exits; i++) next.push(S.add.entrances[i] || { x: '', y: '', z: '', w: '' });
        S.add.entrances = next;
        renderInteriors();
        renderEntrances();
        refreshForm();
    }

    function renderEntrances() {
        const wrap = $('#add-entrances');
        const hint = $('#entrances-hint');
        wrap.textContent = '';
        hint.textContent = '';

        const it = interiorById(S.add.interior);
        if (!it) {
            hint.textContent = 'Pick an interior first. A house needs one entrance for every exit its interior has.';
            return;
        }

        const exits = S.add.entrances.length;
        hint.append(
            el('b', null, it.name || `Interior ${it.id}`),
            document.createTextNode(` has ${plural(exits, 'exit', 'exits')}, so this house needs `),
            el('b', null, plural(exits, 'entrance', 'entrances')),
            document.createTextNode('. Stand where the door is and press Use my position, or type the coordinates (a pasted vector4 fills all four).'),
        );

        S.add.entrances.forEach((ent, i) => {
            const card = el('div', 'entrance');
            const head = el('div', 'entrance-head');
            const label = el('div', 'entrance-label');
            label.append(icon('pin'), document.createTextNode(`Entrance ${i + 1}`));
            const use = el('button', 'btn-sm');
            use.type = 'button';
            use.append(icon('pin'), document.createTextNode('Use my position'));
            head.append(label, use);
            card.appendChild(head);

            const grid = el('div', 'coords');
            const inputs = {};
            COORD_KEYS.forEach((k) => {
                const cell = el('label', 'coord');
                cell.appendChild(el('span', null, k === 'w' ? 'H' : k.toUpperCase()));
                const input = el('input', 'num');
                input.type = 'text';
                input.inputMode = 'decimal';
                input.autocomplete = 'off';
                input.spellcheck = false;
                input.placeholder = k === 'w' ? '0.0' : '';
                input.value = ent[k];
                input.addEventListener('input', () => {
                    ent[k] = input.value;
                    refreshForm();
                });
                input.addEventListener('paste', (e) => {
                    // the letters go first so the 4 of "vector4(...)" is not read as a coordinate
                    const text = ((e.clipboardData || window.clipboardData).getData('text') || '').replace(/[a-z_]+\d*/gi, ' ');
                    const nums = text.match(/-?\d+(?:\.\d+)?/g);
                    if (!nums || nums.length < 3) return;
                    e.preventDefault();
                    COORD_KEYS.forEach((key, n) => {
                        ent[key] = nums[n] !== undefined ? nums[n] : (key === 'w' ? '0' : ent[key]);
                        inputs[key].value = ent[key];
                    });
                    refreshForm();
                });
                inputs[k] = input;
                cell.appendChild(input);
                grid.appendChild(cell);
            });
            card.appendChild(grid);

            use.addEventListener('click', () => {
                post('getPosition').then((p) => {
                    if (!p || !Number.isFinite(Number(p.x))) { toast('Could not read your position', 'err'); return; }
                    COORD_KEYS.forEach((k) => {
                        ent[k] = (Math.round(Number(p[k] || 0) * 100) / 100).toString();
                        inputs[k].value = ent[k];
                    });
                    refreshForm();
                });
            });

            card._ent = ent;
            wrap.appendChild(card);
        });
    }

    const filled = (v) => String(v).trim() !== '' && Number.isFinite(Number(v));
    const entranceDone = (e) => filled(e.x) && filled(e.y) && filled(e.z) && (String(e.w).trim() === '' || filled(e.w));

    $('#add-name').addEventListener('input', (e) => { S.add.name = e.target.value; refreshForm(); });

    // ------------------------------------------------------------------ sell house

    function renderSellSelect() {
        const sel = $('#sell-house');
        sel.textContent = '';
        if (!S.houses.length) {
            const o = el('option', null, 'No houses to sell');
            o.value = '';
            sel.appendChild(o);
            S.sell.house = null;
        } else {
            if (!houseById(S.sell.house)) S.sell.house = S.houses[0].id;
            S.houses.forEach((h) => {
                const owner = ownerLabel(h);
                const o = el('option', null, `#${h.id}  ${h.name || 'House ' + h.id}  —  ${owner ? 'owned by ' + owner : 'for sale'}`);
                o.value = String(h.id);
                sel.appendChild(o);
            });
            sel.value = String(S.sell.house);
        }
        renderSellInfo();
    }

    function renderSellInfo() {
        const info = $('#sell-info');
        info.textContent = '';
        const h = houseById(S.sell.house);
        if (!h) return;
        const owner = ownerLabel(h);
        info.append(
            meta('home', '', h.interiorName || 'No interior'),
            meta('door', '', plural(Number(h.entrances) || 0, 'entrance', 'entrances')),
            meta('user', owner ? 'Owner' : '', owner || 'Nobody'),
        );
    }

    $('#sell-house').addEventListener('change', (e) => {
        S.sell.house = e.target.value;
        renderSellInfo();
        refreshForm();
    });

    const playerId = () => {
        const n = Number(S.sell.player);
        return Number.isInteger(n) && n > 0 ? n : null;
    };

    function setLookup(state, text, extra) {
        S.lookup.state = state;
        const box = $('#sell-lookup');
        box.className = `lookup${state === 'ok' ? ' ok' : state === 'err' ? ' err' : ''}`;
        box.textContent = '';
        box.appendChild(icon(state === 'ok' ? 'check' : state === 'err' ? 'alert' : 'user'));
        box.appendChild(document.createTextNode(text));
        if (extra) box.appendChild(el('small', null, extra));
        refreshForm();
    }

    function lookupSoon() {
        clearTimeout(S.lookup.timer);
        const seq = ++S.lookup.seq;
        const id = playerId();
        if (!id) {
            setLookup('idle', S.sell.player.trim() ? 'Enter a valid player ID' : 'Enter the server ID of the buyer');
            return;
        }
        setLookup('loading', 'Looking up player…');
        S.lookup.timer = setTimeout(() => {
            post('lookupPlayer', { id }).then((res) => {
                if (seq !== S.lookup.seq) return;     // typed on since
                if (res && res.ok) setLookup('ok', res.name || `Player ${id}`, res.citizenid || `ID ${id}`);
                else if (res && res.error) setLookup('err', res.error);
                else setLookup('idle', 'Could not check that player');
            });
        }, 300);
    }

    $('#sell-player').addEventListener('input', (e) => { S.sell.player = e.target.value; lookupSoon(); });

    // ------------------------------------------------------------------ footer: validity, submit, clear

    function refreshForm() {
        const submit = $('#submit');
        if (S.tab === 'add') {
            const total = S.add.entrances.length;
            const done = S.add.entrances.filter(entranceDone).length;
            document.querySelectorAll('#add-entrances .entrance').forEach((c) => c.classList.toggle('done', entranceDone(c._ent)));
            submit.disabled = S.busy || !S.add.name.trim() || !S.add.interior || !total || done !== total;
            $('#status').textContent = total ? `${done} / ${plural(total, 'entrance', 'entrances')} set` : 'Pick an interior';
        } else if (S.tab === 'sell') {
            $('#status').textContent = '';
            submit.disabled = S.busy || !houseById(S.sell.house) || !playerId() || S.lookup.state === 'err' || S.lookup.state === 'loading';
        }
    }

    function resetAdd() {
        S.add = { name: '', interior: null, entrances: [] };
        $('#add-name').value = '';
        renderInteriors();
        renderEntrances();
    }

    function resetSell() {
        S.sell.player = '';
        $('#sell-player').value = '';
        clearTimeout(S.lookup.timer);
        S.lookup.seq++;
        setLookup('idle', 'Enter the server ID of the buyer');
    }

    $('#reset').addEventListener('click', () => {
        if (S.tab === 'add') resetAdd(); else if (S.tab === 'sell') resetSell();
        refreshForm();
    });

    $('#submit').addEventListener('click', () => {
        if ($('#submit').disabled) return;
        if (S.tab === 'add') {
            const entrances = S.add.entrances.map((e) => ({
                x: Number(e.x), y: Number(e.y), z: Number(e.z), w: String(e.w).trim() === '' ? 0 : Number(e.w),
            }));
            act(post('createHouse', { name: S.add.name.trim(), interior: S.add.interior, entrances }),
                'House created', 'Could not create the house', resetAdd);
        } else if (S.tab === 'sell') {
            act(post('sellHouse', { house: S.sell.house, player: playerId() }),
                'House sold', 'Could not sell the house', resetSell);
        }
    });

    // Waits for the Lua reply { ok, error?, message? }. On success: toast, run `after`, reload the data and go to the list.
    function act(request, okText, failText, after) {
        S.busy = true;
        refreshForm();
        return request.then((res) => {
            S.busy = false;
            if (res && res.ok) {
                toast(res.message || okText, 'ok');
                if (after) after();
                refreshData().then(() => selectTab('houses'));
            } else {
                toast((res && res.error) || failText, 'err');
                refreshForm();
            }
        });
    }

    // ------------------------------------------------------------------ data

    function setData(msg) {
        S.interiors = toList(msg.interiors);
        S.houses = toList(msg.houses);
        if (S.add.interior !== null && !interiorById(S.add.interior)) { S.add.interior = null; S.add.entrances = []; }
        renderHouses();
        renderInteriors();
        renderEntrances();
        if (S.tab === 'sell') renderSellSelect();
        refreshForm();
    }

    function refreshData() {
        return post('getData').then((d) => { if (d && d.houses) setData(d); });
    }

    // ------------------------------------------------------------------ toasts

    function toast(text, kind) {
        const t = el('div', `toast ${kind || 'ok'}`);
        t.append(icon(kind === 'err' ? 'alert' : 'check'), document.createTextNode(text));
        $('#toasts').appendChild(t);
        requestAnimationFrame(() => requestAnimationFrame(() => t.classList.add('show')));
        setTimeout(() => {
            t.classList.remove('show');
            setTimeout(() => t.remove(), 250);
        }, 3800);
    }

    // ------------------------------------------------------------------ open, close, keys

    function open(msg) {
        if (msg.accent) setAccent(msg.accent);
        S.busy = false;
        S.add = { name: '', interior: null, entrances: [] };
        S.sell = { house: null, player: '' };
        $('#add-name').value = '';
        $('#sell-player').value = '';
        $('#search').value = '';
        closeModal();
        setLookup('idle', 'Enter the server ID of the buyer');
        setData(msg);
        selectTab('houses');

        const app = $('#app');
        clearTimeout(S.hideTimer);
        app.hidden = false;
        S.open = true;
        requestAnimationFrame(() => requestAnimationFrame(() => app.classList.add('open')));
    }

    function hide() {
        const app = $('#app');
        S.open = false;
        closeModal();
        app.classList.remove('open');
        clearTimeout(S.hideTimer);
        S.hideTimer = setTimeout(() => { app.hidden = true; }, 220);
    }

    function finish() {
        if (!S.open) return;
        hide();
        post('close');
    }

    $('#close').addEventListener('click', finish);

    document.addEventListener('keydown', (e) => {
        if (!S.open || e.key !== 'Escape') return;
        if (!$('#modal').hidden) closeModal(); else finish();
    });

    // ------------------------------------------------------------------ messages from Lua

    window.addEventListener('message', (event) => {
        const msg = event.data;
        if (!msg || !msg.action) return;
        switch (msg.action) {
            case 'open':
                open(msg);
                break;
            case 'data':
                setData(msg);
                break;
            case 'close':
                hide();
                break;
        }
    });
})();
