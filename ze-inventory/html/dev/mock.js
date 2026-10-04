// Browser-only preview helper. Loaded by script.js when the page is NOT running inside FiveM,
// and deliberately left out of fxmanifest.lua. Open html/index.html in a browser to use it.
//
// It sends the same messages your Lua will (window.postMessage == SendNUIMessage), including the
// awkward shapes Lua produces: a table keyed by slot becomes an object, and an empty table becomes [].
(() => {
    'use strict';

    const IMAGE_PATH = 'images/';

    const ITEMS = {
        weapon_pistol:  { label: 'Walther P99', weight: 1000, type: 'weapon', unique: true, useable: true, description: 'A small firearm designed to be held in one hand' },
        pistol_ammo:    { label: 'Pistol Ammo', weight: 100, description: 'Ammo for pistols' },
        bandage:        { label: 'Bandage', weight: 100, useable: true, description: 'A simple bandage to stop minor bleeding' },
        painkillers:    { label: 'Painkillers', weight: 100, useable: true, description: 'For pain you cannot stand anymore' },
        firstaid:       { label: 'First Aid', weight: 2500, useable: true, description: 'You can use this First Aid kit to get people up' },
        water_bottle:   { label: 'Water Bottle', weight: 500, useable: true, description: 'For all the thirsty out there' },
        sandwich:       { label: 'Sandwich', weight: 200, useable: true, description: 'Nice bread for your stomach' },
        coffee:         { label: 'Coffee', weight: 200, useable: true, description: 'Pump that energy' },
        beer:           { label: 'Beer', weight: 500, useable: true, description: 'Nothing like a good cold beer!' },
        phone:          { label: 'Phone', weight: 700, unique: true, useable: true, description: 'Neat phone with some good applications' },
        radio:          { label: 'Radio', weight: 1000, unique: true, useable: true, description: 'You can communicate with this through a signal' },
        lockpick:       { label: 'Lockpick', weight: 300, useable: true, description: 'Very useful if you lose your keys a lot... or if you want to use it for something else' },
        advancedlockpick: { label: 'Advanced Lockpick', weight: 500, useable: true, description: 'If you lose your keys a lot this is very useful' },
        repairkit:      { label: 'Repair Kit', weight: 2500, useable: true, description: 'A nice toolbox with stuff to repair your vehicle' },
        id_card:        { label: 'ID Card', weight: 0, unique: true, useable: true, description: 'A card containing all your information to identify yourself' },
        driver_license: { label: "Driver's License", weight: 0, unique: true, useable: true, description: 'Permission to drive on the open road' },
        markedbills:    { label: 'Marked Money', weight: 1000, unique: true, useable: false, description: 'Money?' },
        goldbar:        { label: 'Gold Bar', weight: 7000, description: 'Looks expensive' },
        laptop:         { label: 'Laptop', weight: 4000, unique: true, useable: true, description: 'Expensive laptop' },
        joint:          { label: 'Joint', weight: 200, useable: true, description: 'Sidney would be very proud at you' },
        binoculars:     { label: 'Binoculars', weight: 600, useable: true, description: 'Sneaky Breaky...' },
        handcuffs:      { label: 'Handcuffs', weight: 100, useable: true, description: 'Comes in handy when people misbehave. Maybe it can be used for something else?' },
        armor:          { label: 'Armor', weight: 5000, useable: true, description: 'Protection near your heart' },
        jerry_can:      { label: 'Jerry Can', weight: 3000, unique: true, useable: true, description: 'A can of gasoline' },
        casing:         { label: 'Casing', weight: 100, unique: true, description: 'A spent bullet casing' },
        blood_vial:     { label: 'Blood Vial', weight: 100, unique: true, description: 'A vial of blood' },
        usedfingerprinttape: { label: 'Used Fingerprint Tape', weight: 100, unique: true, description: 'An already used fingerprint tape' },
        cryptostick:    { label: 'Crypto Stick', weight: 200, unique: true, useable: true, description: 'Why would someone ever buy money that doesn\'t exist.. How many would it contain..?' },
    };

    function item(name, slot, amount, info, extra) {
        const base = ITEMS[name];
        return Object.assign({
            name, slot, amount: amount || 1,
            label: base.label, weight: base.weight, type: base.type || 'item',
            image: `${name}.png`, unique: !!base.unique, useable: !!base.useable,
            description: base.description || '',
            info: info || [], // an empty Lua table arrives as []
        }, extra || {});
    }

    // Keyed by slot, like a real Lua table with gaps.
    function keyed(list) {
        const out = {};
        list.forEach((it) => { out[it.slot] = it; });
        return out;
    }

    const player = () => ({
        id: 'player', type: 'player', label: 'Alex Reyes', sub: 'Citizen ID  ZE48271',
        maxWeight: 120000, slots: 41,
        money: { cash: 2480, bank: 36150 },
        items: keyed([
            item('weapon_pistol', 1, 1, { serie: 'ZE48271X', quality: 78 }, {
                attachments: [
                    { attachment: 'pistol_extendedclip', label: 'Extended Clip' },
                    { attachment: 'pistol_suppressor', label: 'Suppressor' },
                ],
            }),
            item('bandage', 2, 5),
            item('water_bottle', 3, 3),
            item('sandwich', 4, 2),
            item('phone', 5, 1, { phone_number: '555-0187' }),
            item('lockpick', 7, 2),
            item('radio', 8, 1, { _channel: 3 }),
            item('id_card', 9, 1, { citizenid: 'ZE48271', firstname: 'Alex', lastname: 'Reyes' }),
            item('driver_license', 10, 1, { type: 'Class C driver license' }),
            item('pistol_ammo', 12, 48),
            item('markedbills', 14, 1, { worth: 3200 }),
            item('firstaid', 15, 2),
            item('goldbar', 17, 3),
            item('repairkit', 20, 1, { quality: 41 }),
            item('laptop', 23, 1, { quality: 12 }),
            item('painkillers', 24, 6),
            item('casing', 25, 1, { ammoType: 'AMMO_PISTOL', serialNumber: 'ZE48271X' }),
            item('blood_vial', 26, 1, { DNA: 'TGCAATGCCGTA' }),
            item('blood_vial', 27, 1), // no DNA stored: no copy entry
            item('usedfingerprinttape', 28, 1, { fingerprint: 'Q7Z-41K-9XM' }),
            item('usedfingerprinttape', 29, 1, { fingerprint: ['Q7Z-41K-9XM', 'B2L-88T-0QD'] }),
        ]),
    });

    const stash = () => ({
        id: 'stash_mrpd_lockers', type: 'stash', label: 'Mission Row Lockers', sub: 'Stash · Police',
        maxWeight: 200000, slots: 30,
        items: keyed([
            item('handcuffs', 1, 4),
            item('armor', 2, 3),
            item('radio', 3, 1, { _channel: 1 }),
            item('pistol_ammo', 4, 120),
            item('binoculars', 6, 1),
            item('coffee', 7, 6),
            item('jerry_can', 9, 1, { quality: 90 }),
            item('beer', 10, 12),
        ]),
    });

    const shop = () => ({
        id: 'shop_247', type: 'shop', label: '24/7 Supermarket', sub: 'Shop · Strawberry',
        maxWeight: 0, slots: 15,
        items: keyed([
            item('water_bottle', 1, 99, null, { price: 4 }),
            item('sandwich', 2, 99, null, { price: 6 }),
            item('coffee', 3, 99, null, { price: 5 }),
            item('beer', 4, 99, null, { price: 9 }),
            item('bandage', 5, 99, null, { price: 25 }),
            item('painkillers', 6, 99, null, { price: 40 }),
            item('phone', 7, 5, null, { price: 850 }),
            item('lockpick', 8, 99, null, { price: 150 }),
            item('binoculars', 9, 99, null, { price: 120 }),
        ]),
    });

    const trunk = () => ({
        id: 'trunk_ABC123', type: 'trunk', label: 'Trunk', sub: 'Vehicle · ABC 123',
        maxWeight: 60000, slots: 20,
        items: keyed([item('jerry_can', 1, 1), item('repairkit', 2, 1), item('water_bottle', 3, 8)]),
    });

    const post = (data) => window.postMessage(data, '*');
    const config = { imagePath: IMAGE_PATH, currency: '$' };

    const open = (other) => post({ action: 'open', config, player: player(), other: other ? other() : undefined });

    // Flip this on (press X) to see a rejected action roll back with an error toast.
    let rejectNext = false;
    window.mockNui = (name, data) => {
        console.log(`%c[NUI → Lua] ${name}`, 'color:#5eead4;font-weight:600', data);
        if (name === 'close') return true;
        if (rejectNext && name !== 'ready') return { ok: false, message: 'Server said no (mock)' };
        return true;
    };

    // ---- Dev chrome ----
    const style = document.createElement('style');
    style.textContent = `
        body.dev {
            background:
                radial-gradient(60% 50% at 18% 72%, rgba(255, 170, 90, 0.35), transparent 70%),
                radial-gradient(50% 45% at 82% 30%, rgba(90, 140, 255, 0.28), transparent 70%),
                linear-gradient(160deg, #3a4768 0%, #1b2133 48%, #0d1017 100%);
        }
        .devbar {
            position: fixed; left: 14px; bottom: 12px; z-index: 5; display: flex; gap: 6px; flex-wrap: wrap;
            font: 600 11px/1 "Bahnschrift", "Segoe UI", sans-serif; color: rgba(255,255,255,.55); align-items: center;
        }
        .devbar b { color: rgba(255,255,255,.35); letter-spacing: .14em; margin-right: 4px; }
        .devbar button {
            padding: 6px 9px; border: 1px solid rgba(255,255,255,.16); border-radius: 8px;
            background: rgba(0,0,0,.3); color: #fff; font: inherit; cursor: pointer;
        }
        .devbar button:hover { border-color: #5eead4; color: #5eead4; }
        .devbar button.on { border-color: #fb7185; color: #fb7185; }
    `;
    document.head.appendChild(style);
    document.body.classList.add('dev');

    const bar = document.createElement('div');
    bar.className = 'devbar';
    bar.innerHTML = '<b>DEV</b>';
    const buttons = [
        ['O', 'Inventory + stash', () => open(stash)],
        ['P', 'Solo', () => open(null)],
        ['S', 'Shop', () => open(shop)],
        ['T', 'Trunk', () => open(trunk)],
        ['H', 'Quick slots', () => post({ action: 'hotbar', items: player().items, active: 2 })],
        ['N', 'Notice', () => {
            const kinds = ['add', 'remove', 'use'];
            const kind = kinds[Math.floor(Math.random() * 3)];
            post({ action: 'itemBox', kind, name: 'bandage', label: 'Bandage', amount: kind === 'use' ? 1 : 2, image: 'bandage.png' });
        }],
        ['R', 'Required items', () => {
            requiredOn = !requiredOn;
            post({ action: 'requiredItem', toggle: requiredOn, items: [
                { item: 'lockpick', label: 'Lockpick', image: 'lockpick.png' },
                { item: 'electronickit', label: 'Electronic Kit', image: 'electronickit.png' },
            ] });
        }],
        ['X', 'Reject moves', null],
    ];
    let requiredOn = false;
    buttons.forEach(([key, label, run]) => {
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.textContent = `${key} · ${label}`;
        btn.dataset.key = key.toLowerCase();
        btn.addEventListener('click', () => trigger(key.toLowerCase(), btn));
        bar.appendChild(btn);
    });
    document.body.appendChild(bar);

    function trigger(key, btn) {
        if (key === 'x') {
            rejectNext = !rejectNext;
            (btn || bar.querySelector('[data-key="x"]')).classList.toggle('on', rejectNext);
            return;
        }
        const entry = buttons.find((b) => b[0].toLowerCase() === key);
        if (entry && entry[2]) entry[2]();
    }

    window.addEventListener('keydown', (e) => {
        if (e.target && e.target.tagName === 'INPUT') return;
        if (e.ctrlKey || e.metaKey || e.altKey) return;
        // Only react when the inventory is closed; while open, the UI owns the keyboard.
        if (!document.getElementById('app').hidden && document.getElementById('app').classList.contains('open')) return;
        if (['o', 'p', 's', 't', 'h', 'n', 'r', 'x'].includes(e.key.toLowerCase())) trigger(e.key.toLowerCase());
    });

    setTimeout(() => open(stash), 150);
})();
