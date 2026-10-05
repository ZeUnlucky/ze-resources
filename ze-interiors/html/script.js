/* ze-interiors NUI. Vanilla JS, no build step, no CDNs, no jQuery.
   Lua sends: open, data, close.
   The UI sends back: getData, getPosition, setWaypoint, lookupPlayer, createHouse, updateHouse, sellHouse, deleteHouse,
   createBuilding, deleteBuilding, close. (See README.md.) */

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

    // The Add house form. entrances: one { x, y, z, w } of typed strings per exit (index 0 = exit 1); editing: id of the house
    // being edited, or null. An apartment has building (id) and floor instead of entrances.
    const blankAdd = () => ({ name: '', interior: null, entrances: [], editing: null, apartment: false, building: null, floor: null });
    const blankBuilding = () => ({ name: '', floors: '', entrance: { x: '', y: '', z: '', w: '' } });

    const S = {
        open: false,
        tab: 'houses',
        busy: false,
        interiors: [],
        buildings: [],
        houses: [],
        add: blankAdd(),
        nb: blankBuilding(),
        sell: { house: null, player: '' },
        lookup: { state: 'idle', seq: 0, timer: null },
        pendingDelete: null,       // { kind: 'house' | 'building', id }
        hideTimer: null,
    };

    const interiorById = (id) => S.interiors.find((i) => String(i.id) === String(id)) || null;
    const buildingById = (id) => S.buildings.find((b) => String(b.id) === String(id)) || null;
    const houseById = (id) => S.houses.find((h) => String(h.id) === String(id)) || null;
    const ownerLabel = (h) => h.ownerName || h.owner || '';
    const isApartment = (h) => h.building !== undefined && h.building !== null;

    // What the "door" line of a house shows: the entrances of a house, or the building and floor of an apartment.
    function doorLabel(h) {
        return isApartment(h) ? `${h.buildingName || 'Building'} · floor ${h.floor}` : entranceCount(h);
    }

    // "2 of 3 entrances" when the interior has more exits than the house has entrances, else "2 entrances".
    function entranceCount(h) {
        const n = Number(h.entrances) || 0;
        const exits = Number(h.exits) || 0;
        return exits > n ? `${n} of ${plural(exits, 'entrance', 'entrances')}` : plural(n, 'entrance', 'entrances');
    }

    // ------------------------------------------------------------------ tabs

    const TITLES = { houses: null, add: 'Create house', buildings: 'Create building', sell: 'Sell house' };

    function selectTab(tab) {
        S.tab = tab;
        document.querySelectorAll('#tabs .tab').forEach((b) => b.classList.toggle('on', b.dataset.tab === tab));
        ['houses', 'add', 'buildings', 'sell'].forEach((t) => { $(`#pane-${t}`).hidden = t !== tab; });
        $('#foot').hidden = tab === 'houses';
        updateAddLabels();
        if (tab === 'sell') renderSellSelect();
        refreshForm();
    }

    // The Add house form doubles as the edit form: the button texts follow S.add.editing.
    function updateAddLabels() {
        const editing = S.add.editing !== null;
        $('#submit-label').textContent = S.tab === 'add' && editing ? 'Save changes' : (TITLES[S.tab] || '');
        $('#reset').textContent = S.tab === 'add' && editing ? 'Cancel' : 'Clear';
        $('#interior-hint').hidden = !editing;
        // the house / apartment switch is only for new ones; an existing house keeps its type
        $('#type-block').hidden = editing;
        document.querySelectorAll('#add-type button').forEach((b) => b.classList.toggle('on', (b.dataset.type === 'apartment') === S.add.apartment));
        $('#apartment-block').hidden = !S.add.apartment;
        $('#entrances-block').hidden = S.add.apartment;
        renderAccess();
        $('#tabs .tab[data-tab="add"] span').textContent = editing ? 'Edit house' : 'Add house';
    }

    document.querySelectorAll('#tabs .tab').forEach((b) => b.addEventListener('click', () => {
        // the tab is "Add house" again once you leave the edit form
        if (b.dataset.tab === 'add' && S.add.editing !== null && S.tab !== 'add') resetAdd();
        selectTab(b.dataset.tab);
    }));

    // ------------------------------------------------------------------ houses list

    function renderSubtitle() {
        const owned = S.houses.filter((h) => ownerLabel(h)).length;
        $('#subtitle').textContent = `${plural(S.houses.length, 'house', 'houses')} · ${owned} owned · ${plural(S.buildings.length, 'building', 'buildings')}`;
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
            meta(isApartment(h) ? 'building' : 'door', '', doorLabel(h)),
            meta('user', '', owner || 'Nobody'),
        );
        main.appendChild(metaRow);
        row.appendChild(main);

        const chips = el('div', 'chips');
        chips.appendChild(owner ? chip('owned', 'user', 'Owned') : chip('free', 'tag', 'For sale'));
        chips.appendChild(h.locked ? chip('locked', 'lock', 'Locked') : chip('', 'unlock', 'Unlocked'));
        row.appendChild(chips);

        const actions = el('div', 'house-actions');
        const waypoint = el('button', 'btn-sm');
        waypoint.type = 'button';
        waypoint.title = 'Mark the front door on the map';
        waypoint.append(icon('pin'), document.createTextNode('Set waypoint'));
        waypoint.addEventListener('click', () => {
            post('setWaypoint', { house: h.id }).then((res) => {
                if (res && res.ok) toast(res.message || 'Waypoint set', 'ok');
                else toast((res && res.error) || 'Could not set the waypoint', 'err');
            });
        });
        const edit = el('button', 'btn-sm');
        edit.type = 'button';
        edit.title = 'Change the name and the entrances';
        edit.append(icon('edit'), document.createTextNode('Edit'));
        edit.addEventListener('click', () => startEdit(h));
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
        actions.append(waypoint, edit, sell, del);
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
            || [h.name, h.interiorName, h.buildingName, h.owner, h.ownerName, `#${h.id}`].join(' ').toLowerCase().includes(q));
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
        S.pendingDelete = { kind: 'house', id: h.id };
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
        $('#modal-title').textContent = 'Delete house?';
        $('#modal').hidden = false;
        $('#modal-cancel').focus();
    }

    function askDeleteBuilding(b) {
        S.pendingDelete = { kind: 'building', id: b.id };
        const text = $('#modal-text');
        text.textContent = '';
        text.append(
            document.createTextNode('This removes '),
            el('b', null, b.name || `Building ${b.id}`),
            document.createTextNode(` (#${b.id}) for good.`),
        );
        $('#modal-title').textContent = 'Delete building?';
        $('#modal').hidden = false;
        $('#modal-cancel').focus();
    }

    function closeModal() {
        S.pendingDelete = null;
        $('#modal').hidden = true;
    }

    $('#modal-cancel').addEventListener('click', closeModal);
    $('#modal-ok').addEventListener('click', () => {
        const pending = S.pendingDelete;
        closeModal();
        if (!pending) return;
        if (pending.kind === 'building') {
            act(post('deleteBuilding', { building: pending.id }), 'Building deleted', 'Could not delete the building', null, 'buildings');
        } else {
            act(post('deleteHouse', { house: pending.id }), 'House deleted', 'Could not delete the house');
        }
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
        // editing a house: its interior is fixed, so only that one is shown
        const shown = S.add.editing !== null ? S.interiors.filter((it) => String(it.id) === String(S.add.interior)) : S.interiors;
        shown.forEach((it) => {
            const b = el('button', `interior${String(S.add.interior) === String(it.id) ? ' on' : ''}`);
            b.type = 'button';
            b.disabled = S.add.editing !== null;
            const ico = el('div', 'interior-ico');
            ico.appendChild(icon('home'));
            const txt = el('div');
            txt.append(el('div', 'interior-name', it.name || `Interior ${it.id}`), el('div', 'interior-sub', plural(Number(it.exits) || 0, 'exit', 'exits')));
            b.append(ico, txt);
            b.addEventListener('click', () => pickInterior(it.id));
            wrap.appendChild(b);
        });
    }

    // ------------------------------------------------------------------ lock, owner and keys (edit form)
    // Each change is saved on its own as soon as it is made; the lists reload from the server afterwards.

    const AC = { owner: '', key: '', busy: false };

    function accessAct(request, failText) {
        AC.busy = true;
        renderAccess();
        return request.then((res) => {
            AC.busy = false;
            if (res && res.ok) {
                toast(res.message || 'Saved', 'ok');
                return refreshData();
            }
            toast((res && res.error) || failText, 'err');
            renderAccess();
        });
    }

    // A "Player ID" box with a button next to it. Returns the row; `run(playerId)` is called when the button is pressed.
    function playerAdd(key, placeholder, label, run, disabled) {
        const row = el('div', 'access-add');
        const input = el('input', 'text');
        input.type = 'text';
        input.inputMode = 'numeric';
        input.placeholder = placeholder;
        input.autocomplete = 'off';
        input.value = AC[key];
        input.disabled = disabled || AC.busy;
        input.addEventListener('input', () => { AC[key] = input.value; });
        const go = el('button', 'btn-sm');
        go.type = 'button';
        go.textContent = label;
        go.disabled = disabled || AC.busy;
        const submit = () => {
            const n = Number(AC[key]);
            if (!Number.isInteger(n) || n <= 0) { toast('Enter a valid player ID', 'err'); return; }
            AC[key] = '';
            run(n);
        };
        go.addEventListener('click', submit);
        input.addEventListener('keydown', (e) => { if (e.key === 'Enter') submit(); });
        row.append(input, go);
        return row;
    }

    function renderAccess() {
        const h = S.add.editing !== null ? houseById(S.add.editing) : null;
        $('#access').hidden = !h;
        const body = $('#access-body');
        body.textContent = '';
        if (!h) return;

        const owner = ownerLabel(h);

        // lock
        const lock = el('div', 'access-row');
        const lockHead = el('div', 'access-head');
        const lockLabel = el('div', 'access-label');
        lockLabel.append(icon(h.locked ? 'lock' : 'unlock'), document.createTextNode('Door'), el('span', 'access-value', h.locked ? 'Locked' : 'Unlocked'));
        const toggle = el('button', 'btn-sm');
        toggle.type = 'button';
        toggle.disabled = AC.busy;
        toggle.append(icon(h.locked ? 'unlock' : 'lock'), document.createTextNode(h.locked ? 'Unlock' : 'Lock'));
        toggle.addEventListener('click', () => accessAct(post('setLocked', { house: h.id, locked: !h.locked }), 'Could not change the lock'));
        lockHead.append(lockLabel, toggle);
        lock.appendChild(lockHead);
        body.appendChild(lock);

        // owner
        const own = el('div', 'access-row');
        const ownHead = el('div', 'access-head');
        const ownLabel = el('div', 'access-label');
        const ownValue = el('span', 'access-value');
        ownValue.appendChild(owner ? el('b', null, owner) : document.createTextNode('Nobody (for sale)'));
        ownLabel.append(icon('user'), document.createTextNode('Owner'), ownValue);
        ownHead.appendChild(ownLabel);
        if (owner) {
            const remove = el('button', 'btn-sm danger');
            remove.type = 'button';
            remove.disabled = AC.busy;
            remove.append(icon('x'), document.createTextNode('Remove'));
            remove.addEventListener('click', () => accessAct(post('removeOwner', { house: h.id }), 'Could not remove the owner'));
            ownHead.appendChild(remove);
        }
        own.appendChild(ownHead);
        own.appendChild(playerAdd('owner', 'Player ID of the new owner', owner ? 'Change owner' : 'Set owner',
            (id) => accessAct(post('setOwner', { house: h.id, player: id }), 'Could not set the owner')));
        own.appendChild(el('p', 'access-note', 'A new owner starts without the keys of the previous one.'));
        body.appendChild(own);

        // keys
        const keyRow = el('div', 'access-row');
        const keyHead = el('div', 'access-head');
        const keyLabel = el('div', 'access-label');
        const keys = toList(h.keyholders);
        keyLabel.append(icon('lock'), document.createTextNode('Keys'), el('span', 'access-value', plural(keys.length, 'key', 'keys')));
        keyHead.appendChild(keyLabel);
        keyRow.appendChild(keyHead);
        if (keys.length) {
            const chips = el('div', 'keys');
            keys.forEach((k) => {
                const c = el('span', 'key');
                c.appendChild(document.createTextNode(k.name || k.citizenid));
                if (k.name) c.appendChild(el('small', null, k.citizenid));
                const x = el('button');
                x.type = 'button';
                x.title = 'Take this key back';
                x.disabled = AC.busy;
                x.appendChild(icon('x'));
                x.addEventListener('click', () => accessAct(post('removeKey', { house: h.id, citizenid: k.citizenid }), 'Could not remove the key'));
                c.appendChild(x);
                chips.appendChild(c);
            });
            keyRow.appendChild(chips);
        }
        keyRow.appendChild(playerAdd('key', 'Player ID to give a key to', 'Give key',
            (id) => accessAct(post('addKey', { house: h.id, player: id }), 'Could not give the key'), !owner));
        if (!owner) keyRow.appendChild(el('p', 'access-note', 'Keys belong to an owner. Set an owner first.'));
        body.appendChild(keyRow);
    }

    // Opens the form filled in with a house. The server sends each entrance's coordinates in h.entranceList.
    function startEdit(h) {
        const exits = Number(h.exits) || 0;
        const round = (v) => (Math.round(Number(v) * 100) / 100).toString();
        const list = toList(h.entranceList);
        const entrances = [];
        for (let i = 0; i < exits; i++) {
            const e = list.find((x) => Number(x.exit) === i + 1);
            entrances.push(e ? { x: round(e.x), y: round(e.y), z: round(e.z), w: round(e.w || 0) } : { x: '', y: '', z: '', w: '' });
        }
        S.add = {
            ...blankAdd(),
            name: h.name || '',
            interior: h.interior,
            entrances: isApartment(h) ? [] : entrances,   // an apartment has no entrances of its own
            editing: h.id,
            apartment: isApartment(h),
            building: isApartment(h) ? h.building : null,
            floor: isApartment(h) ? h.floor : null,
        };
        $('#add-name').value = S.add.name;
        AC.owner = '';
        AC.key = '';
        renderInteriors();
        renderEntrances();
        renderApartment();
        selectTab('add');
    }

    // The House / Apartment switch (new houses only).
    document.querySelectorAll('#add-type button').forEach((b) => b.addEventListener('click', () => {
        S.add.apartment = b.dataset.type === 'apartment';
        updateAddLabels();
        renderApartment();
        refreshForm();
    }));

    // The building and floor selects of an apartment. The floors are 1 to the number of floors of the chosen building.
    function renderApartment() {
        const buildingSel = $('#add-building');
        const floorSel = $('#add-floor');
        const hint = $('#apartment-hint');
        buildingSel.textContent = '';
        floorSel.textContent = '';
        hint.textContent = '';
        if (!S.add.apartment) return;

        if (!S.buildings.length) {
            const none = el('option', null, 'No buildings yet');
            none.value = '';
            buildingSel.appendChild(none);
            buildingSel.disabled = true;
            floorSel.disabled = true;
            hint.append(document.createTextNode('Create a building in the '), el('b', null, 'Buildings'), document.createTextNode(' tab first: an apartment belongs to a building.'));
            return;
        }
        buildingSel.disabled = false;

        const pick = el('option', null, 'Pick a building');
        pick.value = '';
        buildingSel.appendChild(pick);
        S.buildings.forEach((b) => {
            const o = el('option', null, `${b.name || 'Building ' + b.id}  —  ${plural(Number(b.floors) || 0, 'floor', 'floors')}`);
            o.value = String(b.id);
            buildingSel.appendChild(o);
        });
        buildingSel.value = S.add.building === null ? '' : String(S.add.building);

        const b = buildingById(S.add.building);
        floorSel.disabled = !b;
        const floorPick = el('option', null, b ? 'Pick a floor' : 'Pick a building first');
        floorPick.value = '';
        floorSel.appendChild(floorPick);
        if (b) {
            for (let f = 1; f <= Number(b.floors); f++) {
                const o = el('option', null, `Floor ${f}`);
                o.value = String(f);
                floorSel.appendChild(o);
            }
            floorSel.value = S.add.floor === null ? '' : String(S.add.floor);
            hint.append(el('b', null, b.name || `Building ${b.id}`), document.createTextNode(` has ${plural(Number(b.floors) || 0, 'floor', 'floors')}. The apartment uses the entrance of the building: players enter and leave through its door.`));
        }
    }

    $('#add-building').addEventListener('change', (e) => {
        S.add.building = e.target.value === '' ? null : Number(e.target.value);
        S.add.floor = null;   // the floors belong to the building
        renderApartment();
        refreshForm();
    });
    $('#add-floor').addEventListener('change', (e) => {
        S.add.floor = e.target.value === '' ? null : Number(e.target.value);
        refreshForm();
    });

    function pickInterior(id) {
        S.add.interior = id;
        const exits = Number((interiorById(id) || {}).exits) || 0;
        // one slot per exit: keep what was typed for the exits that still exist, add or drop the rest
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
            hint.textContent = 'Pick an interior first. Its first exit needs an entrance, the other exits are optional.';
            return;
        }

        const exits = S.add.entrances.length;
        hint.append(
            el('b', null, it.name || `Interior ${it.id}`),
            document.createTextNode(` has ${plural(exits, 'exit', 'exits')}. `),
            el('b', null, 'Entrance 1 is required'),
            document.createTextNode(exits > 1
                ? '. Fill in the others only for the exits this house should have: an exit without an entrance is not shown inside the house. '
                : '. '),
            document.createTextNode('Stand where the door is and press Use my position, or type the coordinates (a pasted vector4 fills all four).'),
        );

        S.add.entrances.forEach((ent, i) => {
            wrap.appendChild(entranceCard(ent, `Entrance ${i + 1}`, i === 0 ? 'Required' : 'Optional', i === 0,
                i > 0 ? 'Leave this exit without an entrance' : null));
        });
    }

    // A card with the x, y, z and heading boxes of one { x, y, z, w } (typed strings), a Use my position button and, when
    // `clearTitle` is given, an X that empties the card. Used for the entrances of a house and the entrance of a building.
    function entranceCard(ent, title, tag, required, clearTitle) {
        const card = el('div', 'entrance');
        const head = el('div', 'entrance-head');
        const label = el('div', 'entrance-label');
        label.append(icon('pin'), document.createTextNode(title), el('span', `entrance-tag${required ? ' required' : ''}`, tag));
        const use = el('button', 'btn-sm');
        use.type = 'button';
        use.append(icon('pin'), document.createTextNode('Use my position'));
        const actions = el('div', 'entrance-actions');
        const inputs = {};
        if (clearTitle) {
            const clear = el('button', 'btn-sm danger');
            clear.type = 'button';
            clear.title = clearTitle;
            clear.appendChild(icon('x'));
            clear.addEventListener('click', () => {
                COORD_KEYS.forEach((k) => { ent[k] = ''; inputs[k].value = ''; });
                refreshForm();
            });
            actions.appendChild(clear);
        }
        actions.appendChild(use);
        head.append(label, actions);
        card.appendChild(head);

        const grid = el('div', 'coords');
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
        return card;
    }

    // ------------------------------------------------------------------ buildings

    function buildingRow(b) {
        const row = el('div', 'house');
        row.appendChild(el('div', 'house-id', `#${b.id}`));

        const main = el('div', 'house-main');
        main.appendChild(el('div', 'house-name', b.name || `Building ${b.id}`));
        const metaRow = el('div', 'house-meta');
        metaRow.append(
            meta('building', '', plural(Number(b.floors) || 0, 'floor', 'floors')),
            meta('home', '', plural(Number(b.apartments) || 0, 'apartment', 'apartments')),
        );
        main.appendChild(metaRow);
        row.appendChild(main);

        const actions = el('div', 'house-actions');
        const del = el('button', 'btn-sm danger');
        del.type = 'button';
        const used = Number(b.apartments) > 0;
        del.title = used ? 'Delete its apartments first' : 'Delete building';
        del.disabled = used;
        del.appendChild(icon('trash'));
        del.addEventListener('click', () => askDeleteBuilding(b));
        actions.appendChild(del);
        row.appendChild(actions);
        return row;
    }

    function renderBuildings() {
        const list = $('#building-list');
        list.textContent = '';
        if (!S.buildings.length) {
            const e = el('div', 'empty');
            e.append(el('b', null, 'No buildings yet'), document.createTextNode('Fill in the form below to create the first one.'));
            list.appendChild(e);
        } else {
            S.buildings.forEach((b) => list.appendChild(buildingRow(b)));
        }
    }

    // The entrance card of the new-building form. Rebuilt only when the form is cleared, so typing is never interrupted.
    function renderNewBuilding() {
        const wrap = $('#nb-entrance');
        wrap.textContent = '';
        wrap.appendChild(entranceCard(S.nb.entrance, 'Entrance', 'Required', true, null));
    }

    $('#nb-name').addEventListener('input', (e) => { S.nb.name = e.target.value; refreshForm(); });
    $('#nb-floors').addEventListener('input', (e) => { S.nb.floors = e.target.value; refreshForm(); });

    const MAX_FLOORS = 200;
    const floorsValid = (v) => /^\d+$/.test(String(v).trim()) && Number(v) >= 1 && Number(v) <= MAX_FLOORS;

    function resetBuilding() {
        S.nb = blankBuilding();
        $('#nb-name').value = '';
        $('#nb-floors').value = '';
        renderNewBuilding();
    }

    const filled = (v) => String(v).trim() !== '' && Number.isFinite(Number(v));
    const entranceDone = (e) => filled(e.x) && filled(e.y) && filled(e.z) && (String(e.w).trim() === '' || filled(e.w));
    const entranceEmpty = (e) => COORD_KEYS.every((k) => String(e[k]).trim() === '');

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
            meta(isApartment(h) ? 'building' : 'door', '', doorLabel(h)),
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
        if (S.tab === 'add' && S.add.apartment) {
            // an apartment needs a name, an interior (already fixed when editing), a building and one of its floors
            const ready = S.add.name.trim() && S.add.interior && S.add.building !== null && S.add.floor !== null;
            submit.disabled = S.busy || !ready;
            $('#status').textContent = !S.add.interior ? 'Pick an interior'
                : S.add.building === null ? 'Pick a building'
                : S.add.floor === null ? 'Pick a floor'
                : !S.add.name.trim() ? 'Enter a name'
                : `Floor ${S.add.floor}`;
        } else if (S.tab === 'add') {
            // Entrance 1 has to be complete; every other one is either complete or left empty (half filled blocks the form)
            const list = S.add.entrances;
            const total = list.length;
            const done = list.filter(entranceDone).length;
            const partial = list.findIndex((e, i) => !entranceDone(e) && !(i > 0 && entranceEmpty(e)));
            document.querySelectorAll('#add-entrances .entrance').forEach((c, i) => {
                c.classList.toggle('done', entranceDone(c._ent));
                c.classList.toggle('partial', !entranceDone(c._ent) && !entranceEmpty(c._ent));
            });
            submit.disabled = S.busy || !S.add.name.trim() || !S.add.interior || !total || partial !== -1;
            $('#status').textContent = !total ? 'Pick an interior'
                : partial === 0 && entranceEmpty(list[0]) ? 'Entrance 1 is required'
                : partial !== -1 ? `Finish or clear entrance ${partial + 1}`
                : `${done} of ${plural(total, 'entrance', 'entrances')} set`;
        } else if (S.tab === 'buildings') {
            document.querySelectorAll('#nb-entrance .entrance').forEach((c) => c.classList.toggle('done', entranceDone(c._ent)));
            const ready = S.nb.name.trim() && floorsValid(S.nb.floors) && entranceDone(S.nb.entrance) && filled(S.nb.entrance.x);
            submit.disabled = S.busy || !ready;
            $('#status').textContent = !S.nb.name.trim() ? 'Enter a name'
                : !floorsValid(S.nb.floors) ? `Floors: a whole number from 1 to ${MAX_FLOORS}`
                : !entranceDone(S.nb.entrance) ? 'Set the entrance'
                : plural(Number(S.nb.floors), 'floor', 'floors');
        } else if (S.tab === 'sell') {
            $('#status').textContent = '';
            submit.disabled = S.busy || !houseById(S.sell.house) || !playerId() || S.lookup.state === 'err' || S.lookup.state === 'loading';
        }
    }

    function resetAdd() {
        S.add = blankAdd();
        $('#add-name').value = '';
        renderInteriors();
        renderEntrances();
        renderApartment();
        updateAddLabels();
    }

    function resetSell() {
        S.sell.player = '';
        $('#sell-player').value = '';
        clearTimeout(S.lookup.timer);
        S.lookup.seq++;
        setLookup('idle', 'Enter the server ID of the buyer');
    }

    $('#reset').addEventListener('click', () => {
        if (S.tab === 'add') {
            const wasEditing = S.add.editing !== null;
            resetAdd();
            if (wasEditing) { selectTab('houses'); return; }   // Cancel goes back to the list
        } else if (S.tab === 'buildings') {
            resetBuilding();
        } else if (S.tab === 'sell') {
            resetSell();
        }
        refreshForm();
    });

    $('#submit').addEventListener('click', () => {
        if ($('#submit').disabled) return;
        if (S.tab === 'add') {
            const name = S.add.name.trim();
            if (S.add.apartment) {
                // an apartment sends its building and floor, the entrance is the door of the building
                if (S.add.editing !== null) {
                    act(post('updateHouse', { house: S.add.editing, name, building: S.add.building, floor: S.add.floor }),
                        'Apartment saved', 'Could not save the apartment', resetAdd);
                } else {
                    act(post('createHouse', { name, interior: S.add.interior, apartment: true, building: S.add.building, floor: S.add.floor }),
                        'Apartment created', 'Could not create the apartment', resetAdd);
                }
                return;
            }
            // `exit` is the exit of the interior the entrance leads to; the exits left empty are not sent
            const entrances = [];
            S.add.entrances.forEach((e, i) => {
                if (!entranceDone(e)) return;
                entrances.push({ exit: i + 1, x: Number(e.x), y: Number(e.y), z: Number(e.z), w: String(e.w).trim() === '' ? 0 : Number(e.w) });
            });
            if (S.add.editing !== null) {
                act(post('updateHouse', { house: S.add.editing, name, entrances }),
                    'House saved', 'Could not save the house', resetAdd);
            } else {
                act(post('createHouse', { name, interior: S.add.interior, entrances }),
                    'House created', 'Could not create the house', resetAdd);
            }
        } else if (S.tab === 'buildings') {
            const e = S.nb.entrance;
            const entrance = { x: Number(e.x), y: Number(e.y), z: Number(e.z), w: String(e.w).trim() === '' ? 0 : Number(e.w) };
            act(post('createBuilding', { name: S.nb.name.trim(), floors: Number(S.nb.floors), entrance }),
                'Building created', 'Could not create the building', resetBuilding, 'buildings');
        } else if (S.tab === 'sell') {
            act(post('sellHouse', { house: S.sell.house, player: playerId() }),
                'House sold', 'Could not sell the house', resetSell);
        }
    });

    // Waits for the Lua reply { ok, error?, message? }. On success: toast, run `after`, reload the data and go to a tab
    // (the houses list unless `tab` says otherwise).
    function act(request, okText, failText, after, tab) {
        S.busy = true;
        refreshForm();
        return request.then((res) => {
            S.busy = false;
            if (res && res.ok) {
                toast(res.message || okText, 'ok');
                if (after) after();
                refreshData().then(() => selectTab(tab || 'houses'));
            } else {
                toast((res && res.error) || failText, 'err');
                refreshForm();
            }
        });
    }

    // ------------------------------------------------------------------ data

    function setData(msg) {
        S.interiors = toList(msg.interiors);
        S.buildings = toList(msg.buildings);
        S.houses = toList(msg.houses);
        if (S.add.editing !== null && !houseById(S.add.editing)) {
            // the house being edited was deleted meanwhile
            S.add = blankAdd();
            $('#add-name').value = '';
        } else if (S.add.interior !== null && !interiorById(S.add.interior)) {
            S.add.interior = null;
            S.add.entrances = [];
        }
        if (S.add.building !== null && !buildingById(S.add.building)) {
            // the chosen building is gone
            S.add.building = null;
            S.add.floor = null;
        }
        updateAddLabels();
        renderHouses();
        renderBuildings();
        renderInteriors();
        renderEntrances();
        renderApartment();
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
        S.add = blankAdd();
        S.nb = blankBuilding();
        S.sell = { house: null, player: '' };
        $('#add-name').value = '';
        $('#nb-name').value = '';
        $('#nb-floors').value = '';
        renderNewBuilding();
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
