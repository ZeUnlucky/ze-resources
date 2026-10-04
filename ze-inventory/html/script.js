(() => {
    'use strict';

    // The page also runs in a normal browser for previewing (see html/dev/mock.js).
    const IN_GAME = typeof GetParentResourceName === 'function';
    const RESOURCE = IN_GAME ? GetParentResourceName() : 'ze-inventory';

    const TEXT = {
        noSpace: 'No room for that item',
        tooHeavy: 'Too heavy to carry',
        readonly: 'You cannot put items here',
        occupied: 'That slot is taken by another item',
        denied: 'That did not work',
        use: 'Use',
        give: 'Give',
        drop: 'Drop',
        take: 'Take',
        buy: 'Buy',
        transfer: 'Transfer',
    };

    // Icon + fallback title for each inventory type the server can send in `type`.
    const INV_TYPES = {
        player: { icon: '#i-user', name: 'Inventory' },
        stash: { icon: '#i-box', name: 'Stash' },
        trunk: { icon: '#i-car', name: 'Trunk' },
        glovebox: { icon: '#i-glove', name: 'Glovebox' },
        drop: { icon: '#i-ground', name: 'Ground' },
        shop: { icon: '#i-shop', name: 'Shop' },
        otherplayer: { icon: '#i-users', name: 'Player' },
    };

    // Evidence values that get a "Copy ..." entry in the item menu. `match` picks the items,
    // `key` is the field in item.info that holds the value (an array is joined with ", ").
    const COPYABLE = [
        { match: (i) => i.type === 'weapon', key: 'serie', text: 'Copy serial', done: 'Serial copied' },
        { match: (i) => i.name === 'casing', key: 'serialNumber', text: 'Copy serial', done: 'Serial copied' },
        { match: (i) => i.name === 'usedfingerprinttape', key: 'fingerprint', text: 'Copy fingerprint', done: 'Fingerprint copied' },
        { match: (i) => i.name === 'blood_vial', key: 'DNA', text: 'Copy DNA', done: 'DNA copied' },
    ];

    // Everything here can be overridden from Lua through `config` on open/update.
    const cfg = {
        imagePath: `nui://${RESOURCE}/html/images/`,
        currency: '$',
        hotbarSlots: 5,
        hotbarMs: 3500,
        closeKeys: ['Escape', 'Tab'],
    };

    const inv = { player: null, other: null };
    const ui = {
        open: false,
        busy: false,
        rev: 0,
        amount: 0, // 0 = whole stack
        search: { player: '', other: '' },
        hoverNode: null,
    };

    // ---------- Helpers ----------

    const $ = (selector, root = document) => root.querySelector(selector);
    const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));
    const ref = (root, name) => root.querySelector(`[data-ref="${name}"]`);
    const num = (value, fallback = 0) => {
        const n = Number(value);
        return Number.isFinite(n) ? n : fallback;
    };
    const clamp = (n, lo, hi) => Math.min(hi, Math.max(lo, n));

    function el(tag, className, text) {
        const node = document.createElement(tag);
        if (className) node.className = className;
        if (text != null) node.textContent = text;
        return node;
    }

    const SVG_NS = 'http://www.w3.org/2000/svg';
    function svgIcon(id) {
        const svg = document.createElementNS(SVG_NS, 'svg');
        svg.setAttribute('class', 'icon');
        const use = document.createElementNS(SVG_NS, 'use');
        use.setAttribute('href', id);
        svg.appendChild(use);
        return svg;
    }

    const kgShort = (grams) => {
        const kg = grams / 1000;
        if (kg >= 100) return kg.toFixed(0);
        if (kg >= 10) return kg.toFixed(1);
        return String(Math.round(kg * 100) / 100);
    };
    const kgFixed = (grams) => (grams / 1000).toFixed(1);
    const money = (n) => cfg.currency + Math.round(n).toLocaleString('en-US');
    const prettyKey = (key) => key.replace(/[_-]+/g, ' ').replace(/^./, (c) => c.toUpperCase());

    async function post(name, data = {}) {
        if (!IN_GAME) {
            return typeof window.mockNui === 'function' ? window.mockNui(name, data) : true;
        }
        try {
            const res = await fetch(`https://${RESOURCE}/${name}`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify(data),
            });
            const text = await res.text();
            try { return JSON.parse(text); } catch (_) { return true; }
        } catch (err) {
            // A callback that is not registered yet should not roll the UI back while you are building the Lua side.
            console.warn(`[ze-inventory] NUI callback "${name}" failed`, err);
            return true;
        }
    }

    // `cb(false)` or `cb({ ok = false, message = '...' })` rejects an action; anything else accepts it.
    const accepted = (res) => !(res === false || (res && res.ok === false));

    // ---------- Config ----------

    function applyConfig(c) {
        if (!c || typeof c !== 'object') return;
        if (typeof c.imagePath === 'string' && c.imagePath) cfg.imagePath = c.imagePath.replace(/\/*$/, '/');
        if (typeof c.currency === 'string') cfg.currency = c.currency.slice(0, 3);
        if (Number.isInteger(c.hotbarSlots)) cfg.hotbarSlots = clamp(c.hotbarSlots, 1, 9);
        if (Number.isFinite(c.hotbarMs)) cfg.hotbarMs = clamp(c.hotbarMs, 500, 20000);
        if (Array.isArray(c.closeKeys) && c.closeKeys.length) cfg.closeKeys = c.closeKeys.map(String);
        if (typeof c.accent === 'string') setAccent(c.accent);
    }

    function setAccent(hex) {
        let h = hex.trim().replace('#', '');
        if (/^[0-9a-f]{3}$/i.test(h)) h = h.replace(/./g, '$&$&');
        if (!/^[0-9a-f]{6}$/i.test(h)) return;
        const r = parseInt(h.slice(0, 2), 16);
        const g = parseInt(h.slice(2, 4), 16);
        const b = parseInt(h.slice(4, 6), 16);
        const luma = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
        const root = document.documentElement.style;
        root.setProperty('--accent', `#${h}`);
        root.setProperty('--accent-rgb', `${r}, ${g}, ${b}`);
        root.setProperty('--accent-ink', luma > 0.6 ? '#05080c' : '#ffffff');
    }

    // ---------- Data normalisation ----------

    function normalizeItem(raw, slot) {
        if (!raw || typeof raw !== 'object') return null;
        const name = String(raw.name || '');
        if (!name) return null;
        const unique = !!raw.unique;
        // Lua encodes an empty table as [], so only accept real objects for info.
        const info = raw.info && typeof raw.info === 'object' && !Array.isArray(raw.info) ? raw.info : {};
        return {
            name,
            label: String(raw.label || name),
            slot,
            amount: unique ? 1 : Math.max(1, Math.floor(num(raw.amount, 1))),
            weight: Math.max(0, num(raw.weight)),
            type: String(raw.type || 'item'),
            image: raw.image ? String(raw.image) : `${name}.png`,
            unique,
            useable: raw.useable !== false,
            description: raw.description ? String(raw.description) : '',
            info,
            price: raw.price != null ? num(raw.price) : null,
            // Weapons only: [{ attachment = 'item_name', label = 'Extended Clip' }]
            attachments: Array.isArray(raw.attachments)
                ? raw.attachments.filter((a) => a && a.attachment).map((a) => ({ attachment: String(a.attachment), label: String(a.label || a.attachment) }))
                : [],
        };
    }

    // Accepts a Lua array, or a table keyed by slot (which JSON turns into an object).
    function normalizeInventory(raw, fallbackType) {
        if (!raw || typeof raw !== 'object') return null;
        const slots = Math.max(1, Math.floor(num(raw.slots, 40)));
        const type = String(raw.type || fallbackType);
        const data = {
            id: raw.id != null ? String(raw.id) : type,
            type,
            label: String(raw.label || (INV_TYPES[type] || INV_TYPES.stash).name),
            sub: raw.sub ? String(raw.sub) : '',
            maxWeight: Math.max(0, num(raw.maxWeight)),
            slots,
            readonly: !!raw.readonly || type === 'shop',
            money: raw.money && typeof raw.money === 'object' ? { ...raw.money } : null,
            items: new Array(slots).fill(null),
        };

        const isArray = Array.isArray(raw.items);
        const entries = Object.entries(raw.items || {});
        const loose = [];
        for (const [key, value] of entries) {
            const hinted = Math.floor(num(value && value.slot, isArray ? Number(key) + 1 : Number(key)));
            const item = normalizeItem(value, hinted);
            if (!item) continue;
            if (hinted >= 1 && hinted <= slots && !data.items[hinted - 1]) data.items[hinted - 1] = item;
            else loose.push(item);
        }
        for (const item of loose) {
            const free = data.items.indexOf(null);
            if (free === -1) break;
            item.slot = free + 1;
            data.items[free] = item;
        }
        return data;
    }

    const cloneItem = (item) => ({ ...item, info: { ...item.info } });
    const cloneInv = (data) => data && {
        ...data,
        money: data.money && { ...data.money },
        items: data.items.map((item) => item && cloneItem(item)),
    };
    const snapshot = () => ({ player: cloneInv(inv.player), other: cloneInv(inv.other) });
    const restore = (snap) => { inv.player = snap.player; inv.other = snap.other; };

    const weightOf = (data) => data.items.reduce((sum, item) => sum + (item ? item.weight * item.amount : 0), 0);
    const itemAt = (node) => {
        const data = node && inv[node.dataset.side];
        return data ? data.items[Number(node.dataset.slot) - 1] : null;
    };

    // ---------- Rendering ----------

    const appEl = $('#app');
    const tipEl = $('#tip');
    const ctxEl = $('#ctx');
    const toastEl = $('#toast');
    const hotbarEl = $('#hotbar');
    const boxesEl = $('#itemboxes');
    const requiredEl = $('#required');
    const amountInput = $('#amount');
    const tplPanel = $('#tpl-panel');
    const panels = {};

    function buildPanel(side) {
        const root = $(`#panel-${side}`);
        root.appendChild(tplPanel.content.cloneNode(true));
        const panel = { root, side };
        ['icon', 'title', 'sub', 'extra', 'meter', 'meterFill', 'weight', 'count', 'search', 'grid'].forEach((name) => {
            panel[name] = ref(root, name);
        });
        panel.search.addEventListener('input', () => {
            ui.search[side] = panel.search.value.trim().toLowerCase();
            renderGrid(side);
        });
        return panel;
    }

    function imageUrl(file) {
        return /^(nui:|https?:|data:|\/|\.)/i.test(file) ? file : cfg.imagePath + encodeURI(file);
    }

    function glyph(item) {
        const letters = item.label.replace(/[^a-z0-9 ]/gi, '').split(' ').filter(Boolean);
        const text = letters.length > 1 ? letters[0][0] + letters[1][0] : (letters[0] || '?').slice(0, 2);
        return el('span', 'slot-glyph', text.toUpperCase());
    }

    function buildArt(item) {
        const art = el('div', 'slot-art');
        if (!item.image) {
            art.appendChild(glyph(item));
            return art;
        }
        const img = new Image();
        img.className = 'slot-img';
        img.alt = '';
        img.draggable = false;
        img.addEventListener('error', () => art.replaceChildren(glyph(item)), { once: true });
        img.src = imageUrl(item.image);
        art.appendChild(img);
        return art;
    }

    function qualityColor(q) {
        return q > 60 ? 'var(--ok)' : q > 30 ? 'var(--warn)' : 'var(--danger)';
    }

    function buildSlot(side, data, index) {
        const item = data.items[index];
        const slotNo = index + 1;
        const node = el('div', 'slot');
        node.dataset.side = side;
        node.dataset.slot = String(slotNo);
        node.style.setProperty('--i', String(Math.min(index, 40)));

        if (side === 'hud' || (side === 'player' && slotNo <= cfg.hotbarSlots)) {
            node.classList.add('hot');
            node.appendChild(el('span', 'slot-key', String(slotNo)));
        }
        if (!item) return node;

        node.classList.add('filled');
        node.dataset.type = item.type;
        node.appendChild(buildArt(item));
        if (item.amount > 1) node.appendChild(el('span', 'slot-amount', `×${item.amount}`));
        if (data.type === 'shop' && item.price != null) node.appendChild(el('span', 'slot-price', money(item.price)));
        node.appendChild(el('span', 'slot-label', item.label));

        const quality = num(item.info.quality, -1);
        if (quality >= 0) {
            node.classList.add('has-q');
            const bar = el('span', 'slot-q');
            bar.style.setProperty('--q', `${clamp(quality, 0, 100)}%`);
            bar.style.setProperty('--qc', qualityColor(quality));
            node.appendChild(bar);
        }

        const query = ui.search[side];
        if (query && !item.label.toLowerCase().includes(query) && !item.name.toLowerCase().includes(query)) {
            node.classList.add('dim');
        }
        if (drag && drag.side === side && drag.slot === slotNo) node.classList.add('dragging');
        return node;
    }

    function renderGrid(side) {
        const data = inv[side];
        if (!data) return;
        const frag = document.createDocumentFragment();
        for (let i = 0; i < data.slots; i++) frag.appendChild(buildSlot(side, data, i));
        panels[side].grid.replaceChildren(frag);
    }

    function renderPanel(side) {
        const data = inv[side];
        const panel = panels[side];
        panel.root.hidden = !data;
        if (!data) return;

        const meta = INV_TYPES[data.type] || INV_TYPES.stash;
        panel.icon.setAttribute('href', meta.icon);
        panel.title.textContent = data.label;
        panel.sub.textContent = data.sub || meta.name;

        panel.extra.replaceChildren();
        if (data.money) {
            for (const kind of ['cash', 'bank']) {
                if (data.money[kind] == null) continue;
                const chip = el('div', 'money');
                chip.dataset.kind = kind;
                chip.append(svgIcon(kind === 'cash' ? '#i-coin' : '#i-bank'), document.createTextNode(money(num(data.money[kind]))));
                panel.extra.appendChild(chip);
            }
        }

        const weight = weightOf(data);
        const ratio = data.maxWeight > 0 ? clamp(weight / data.maxWeight, 0, 1) : 0;
        panel.meterFill.style.width = `${(ratio * 100).toFixed(1)}%`;
        panel.meter.dataset.level = ratio >= 0.97 ? 'full' : ratio >= 0.75 ? 'warn' : 'ok';
        panel.weight.textContent = data.maxWeight > 0
            ? `${kgFixed(weight)} / ${kgFixed(data.maxWeight)} kg`
            : `${kgFixed(weight)} kg`;
        const used = data.items.reduce((n, item) => n + (item ? 1 : 0), 0);
        panel.count.textContent = `${used} / ${data.slots} slots`;

        renderGrid(side);
    }

    function renderAll() {
        renderPanel('player');
        renderPanel('other');
        hideTip();
    }

    function syncAmount() {
        amountInput.value = ui.amount > 0 ? String(ui.amount) : '';
        $$('#chips button').forEach((btn) => btn.classList.toggle('on', Number(btn.dataset.amt) === ui.amount));
    }

    // ---------- Toast, item boxes, quick-slot HUD ----------

    let toastTimer = null;
    function toast(message, kind = 'err') {
        toastEl.textContent = message;
        toastEl.className = `toast ${kind}`;
        toastEl.hidden = false;
        // Restart the entrance animation when a toast replaces another.
        toastEl.style.animation = 'none';
        void toastEl.offsetWidth;
        toastEl.style.animation = '';
        clearTimeout(toastTimer);
        toastTimer = setTimeout(() => { toastEl.hidden = true; }, 2400);
    }

    function itemBox(msg) {
        const item = normalizeItem(msg, 0) || normalizeItem({ name: 'item', label: msg && msg.label }, 0);
        const kind = ['add', 'remove', 'use'].includes(msg.kind) ? msg.kind : 'add';
        const amount = Math.max(1, Math.floor(num(msg.amount, 1)));

        const box = el('div', `ibox ${kind}`);
        const art = el('div', 'ibox-art');
        art.appendChild(buildArt(item));
        const text = el('div', 'ibox-text');
        text.appendChild(el('b', null, item.label));
        text.appendChild(el('span', null, kind === 'use' ? 'Used' : `${kind === 'add' ? '+' : '−'}${amount}`));
        box.append(art, text);

        while (boxesEl.children.length >= 5) boxesEl.firstElementChild.remove();
        boxesEl.appendChild(box);
        requestAnimationFrame(() => box.classList.add('in'));
        setTimeout(() => {
            box.classList.remove('in');
            box.classList.add('out');
            setTimeout(() => box.remove(), 320);
        }, 3000);
    }

    let hotbarTimer = null;
    function hideHotbar() {
        clearTimeout(hotbarTimer);
        hotbarEl.classList.remove('show');
        setTimeout(() => { if (!hotbarEl.classList.contains('show')) hotbarEl.hidden = true; }, 300);
    }

    // `persist` keeps the bar up until it is told `show = false` (the quick-slot toggle key); otherwise it fades.
    function showHotbar(msg) {
        if (ui.open) return;
        if (msg.show === false) return hideHotbar();
        const holder = normalizeInventory({ id: 'hud', type: 'player', slots: cfg.hotbarSlots, items: msg.items }, 'player');
        const frag = document.createDocumentFragment();
        for (let i = 0; i < cfg.hotbarSlots; i++) {
            const node = buildSlot('hud', holder, i);
            if (Number(msg.active) === i + 1) node.classList.add('active');
            frag.appendChild(node);
        }
        hotbarEl.replaceChildren(frag);
        hotbarEl.hidden = false;
        requestAnimationFrame(() => hotbarEl.classList.add('show'));
        clearTimeout(hotbarTimer);
        if (!msg.persist) hotbarTimer = setTimeout(hideHotbar, cfg.hotbarMs);
    }

    // The "you need these items" card some resources show near doors, terminals and so on.
    let requiredTimer = null;
    function showRequired(msg) {
        clearTimeout(requiredTimer);
        const list = Array.isArray(msg.items) ? msg.items : [];
        if (!msg.toggle || list.length === 0) {
            requiredEl.classList.remove('show');
            requiredTimer = setTimeout(() => { requiredEl.hidden = true; }, 260);
            return;
        }
        const frag = document.createDocumentFragment();
        frag.appendChild(el('div', 'req-title', 'Required'));
        for (const entry of list) {
            const item = normalizeItem({ name: entry.item, label: entry.label, image: entry.image }, 0);
            if (!item) continue;
            const row = el('div', 'req-item');
            const art = el('div', 'req-art');
            art.appendChild(buildArt(item));
            row.append(art, el('span', 'req-label', item.label));
            frag.appendChild(row);
        }
        requiredEl.replaceChildren(frag);
        requiredEl.hidden = false;
        requestAnimationFrame(() => requiredEl.classList.add('show'));
    }

    // ---------- Moving things around ----------

    const stackable = (a, b) => !a.unique && !b.unique && a.name === b.name;

    function firstSlotFor(target, item) {
        let empty = 0;
        for (let i = 0; i < target.slots; i++) {
            const existing = target.items[i];
            if (existing && stackable(existing, item)) return i + 1;
            if (!existing && !empty) empty = i + 1;
        }
        return empty;
    }

    // Dry-run of a move. Mirrors what the server is expected to do; the server stays the authority.
    function planMove(fromSide, fromSlot, toSide, toSlot, want) {
        const fail = (message, silent) => ({ ok: false, message, silent });
        const A = inv[fromSide];
        const B = inv[toSide];
        if (!A || !B) return fail(null, true);
        const src = A.items[fromSlot - 1];
        if (!src) return fail(null, true);

        const cross = A !== B;
        const infinite = A.type === 'shop'; // shops never run out and never take items back
        if (B.readonly) return fail(TEXT.readonly);

        let amt = want > 0 ? Math.min(want, src.amount) : src.amount;
        if (src.unique) amt = src.amount;

        if (toSlot == null) {
            toSlot = firstSlotFor(B, src);
            if (!toSlot) return fail(TEXT.noSpace);
        }
        if (!cross && toSlot === fromSlot) return fail(null, true);

        let dst = B.items[toSlot - 1] || null;
        if (dst && infinite && !stackable(src, dst)) {
            toSlot = firstSlotFor(B, src);
            if (!toSlot) return fail(TEXT.noSpace);
            dst = B.items[toSlot - 1] || null;
        }

        const stack = !!dst && stackable(src, dst);
        const swap = !!dst && !stack;
        if (swap && amt !== src.amount) return fail(TEXT.occupied);
        if (swap && cross && A.readonly) return fail(TEXT.readonly);

        if (cross) {
            const going = src.weight * amt;
            const coming = swap ? dst.weight * dst.amount : 0;
            const bDelta = going - coming;
            const aDelta = coming - (infinite ? 0 : going);
            if (B.maxWeight > 0 && bDelta > 0 && weightOf(B) + bDelta > B.maxWeight) return fail(TEXT.tooHeavy);
            if (A.maxWeight > 0 && aDelta > 0 && weightOf(A) + aDelta > A.maxWeight) return fail(TEXT.tooHeavy);
        }

        return { ok: true, A, B, src, dst, fromSlot, toSlot, amt, stack, swap, infinite };
    }

    function takeFrom(data, slot, amount, infinite) {
        if (infinite) return;
        const item = data.items[slot - 1];
        item.amount -= amount;
        if (item.amount <= 0) data.items[slot - 1] = null;
    }

    function applyMove(plan) {
        const { A, B, src, dst, fromSlot, toSlot, amt, stack, swap, infinite } = plan;
        if (stack) {
            dst.amount += amt;
            takeFrom(A, fromSlot, amt, infinite);
        } else if (swap) {
            A.items[fromSlot - 1] = { ...cloneItem(dst), slot: fromSlot };
            B.items[toSlot - 1] = { ...cloneItem(src), slot: toSlot };
        } else if (amt === src.amount && !infinite) {
            A.items[fromSlot - 1] = null;
            B.items[toSlot - 1] = { ...cloneItem(src), slot: toSlot };
        } else {
            B.items[toSlot - 1] = { ...cloneItem(src), amount: amt, slot: toSlot };
            takeFrom(A, fromSlot, amt, infinite);
        }
    }

    // Apply a change locally, tell the server, and roll back if it says no.
    function transact(event, payload, mutate) {
        if (ui.busy) return;
        const snap = snapshot();
        const rev = ui.rev;
        if (mutate) mutate();
        renderAll();

        ui.busy = true;
        const timer = setTimeout(() => { ui.busy = false; }, 1500);
        post(event, payload).then((res) => {
            clearTimeout(timer);
            ui.busy = false;
            if (accepted(res)) return;
            // If the server already pushed fresh data in the meantime, that is the truth; do not overwrite it.
            if (ui.rev === rev) {
                restore(snap);
                renderAll();
            }
            toast((res && res.message) || TEXT.denied, 'err');
        });
    }

    function commitMove(fromSide, fromSlot, toSide, toSlot, want) {
        if (ui.busy) return;
        const plan = planMove(fromSide, fromSlot, toSide, toSlot, want);
        if (!plan.ok) {
            if (plan.message) toast(plan.message, 'err');
            return;
        }
        const { A, B, src } = plan;
        transact('moveItem', {
            from: { id: A.id, type: A.type, slot: plan.fromSlot },
            to: { id: B.id, type: B.type, slot: plan.toSlot },
            amount: plan.amt,
            name: src.name,
        }, () => applyMove(plan));
    }

    function quickMove(side, slot) {
        if (!inv.other) return;
        commitMove(side, slot, side === 'player' ? 'other' : 'player', null, ui.amount);
    }

    function doUse(slot) {
        const item = inv.player && inv.player.items[slot - 1];
        if (!item || !item.useable) return;
        post('useItem', { slot, name: item.name });
    }

    function removeFromPlayer(event, slot) {
        const item = inv.player && inv.player.items[slot - 1];
        if (!item) return;
        const amount = ui.amount > 0 ? Math.min(ui.amount, item.amount) : item.amount;
        transact(event, { slot, amount, name: item.name }, () => takeFrom(inv.player, slot, amount, false));
    }

    function runZone(zone, slot) {
        if (zone === 'use') doUse(slot);
        else if (zone === 'give') removeFromPlayer('giveItem', slot);
        else if (zone === 'drop') removeFromPlayer('dropItem', slot);
    }

    // ---------- Drag and drop ----------

    let pending = null; // pointer is down on a slot but has not moved far enough to be a drag
    let drag = null;

    function resolveTarget(x, y) {
        const hit = document.elementFromPoint(x, y);
        if (!hit) return null;
        const zone = hit.closest('.zone');
        if (zone) return { kind: 'zone', name: zone.dataset.zone, node: zone };
        const slot = hit.closest('.slot');
        if (slot && (slot.dataset.side === 'player' || slot.dataset.side === 'other')) {
            return { kind: 'slot', side: slot.dataset.side, slot: Number(slot.dataset.slot), node: slot };
        }
        const panel = hit.closest('.panel');
        if (panel) return { kind: 'panel', side: panel.dataset.side, node: panel };
        return null;
    }

    function clearOver() {
        $$('.over, .over-ok, .over-bad').forEach((n) => n.classList.remove('over', 'over-ok', 'over-bad'));
    }

    function markTarget(target) {
        clearOver();
        if (!target) return;
        if (target.kind === 'zone') {
            if (drag.side === 'player') target.node.classList.add('over');
        } else if (target.kind === 'panel') {
            if (target.side !== drag.side && planMove(drag.side, drag.slot, target.side, null, ui.amount).ok) {
                target.node.classList.add('over');
            }
        } else {
            const plan = planMove(drag.side, drag.slot, target.side, target.slot, ui.amount);
            if (plan.ok) target.node.classList.add('over-ok');
            else if (!plan.silent) target.node.classList.add('over-bad');
        }
    }

    function startDrag(e) {
        const item = inv[pending.side] && inv[pending.side].items[pending.slot - 1];
        if (!item) return;
        const moving = ui.amount > 0 ? Math.min(ui.amount, item.amount) : item.amount;

        const ghost = el('div', 'ghost');
        ghost.appendChild(buildArt(item));
        if (moving > 1) ghost.appendChild(el('span', 'slot-amount', `×${moving}`));
        document.body.appendChild(ghost);

        drag = { side: pending.side, slot: pending.slot, ghost, half: ghost.offsetWidth / 2, key: '' };
        document.body.classList.add('is-dragging');
        appEl.classList.add(`dragging-${drag.side}`);
        const source = $(`.slot[data-side="${drag.side}"][data-slot="${drag.slot}"]`);
        if (source) source.classList.add('dragging');
        hideTip();
        hideCtx();
        moveDrag(e);
    }

    function moveDrag(e) {
        drag.ghost.style.transform = `translate(${e.clientX - drag.half}px, ${e.clientY - drag.half}px)`;
        const target = resolveTarget(e.clientX, e.clientY);
        const key = target ? `${target.kind}:${target.side || target.name}:${target.slot || ''}` : '';
        if (key === drag.key) return;
        drag.key = key;
        markTarget(target);
    }

    function endDrag() {
        if (!drag) return;
        drag.ghost.remove();
        document.body.classList.remove('is-dragging');
        appEl.classList.remove('dragging-player', 'dragging-other');
        clearOver();
        $$('.slot.dragging').forEach((n) => n.classList.remove('dragging'));
        drag = null;
    }

    function stopTracking() {
        pending = null;
        window.removeEventListener('pointermove', onPointerMove);
        window.removeEventListener('pointerup', onPointerUp);
        window.removeEventListener('pointercancel', onPointerCancel);
    }

    function onPointerDown(e) {
        if (!ui.open) return;
        if (!e.target.closest('.ctx')) hideCtx();
        if (e.button !== 0 || ui.busy) return;
        const node = e.target.closest('.slot.filled');
        if (!node || (node.dataset.side !== 'player' && node.dataset.side !== 'other')) return;
        pending = {
            side: node.dataset.side,
            slot: Number(node.dataset.slot),
            x: e.clientX,
            y: e.clientY,
            shift: e.shiftKey,
        };
        window.addEventListener('pointermove', onPointerMove);
        window.addEventListener('pointerup', onPointerUp);
        window.addEventListener('pointercancel', onPointerCancel);
    }

    function onPointerMove(e) {
        if (!drag && pending && Math.hypot(e.clientX - pending.x, e.clientY - pending.y) > 5) startDrag(e);
        else if (drag) moveDrag(e);
    }

    function onPointerUp(e) {
        const from = pending;
        const dragging = drag;
        const target = dragging ? resolveTarget(e.clientX, e.clientY) : null;
        endDrag();
        stopTracking();

        if (dragging) {
            if (!target) return;
            if (target.kind === 'zone') {
                if (dragging.side === 'player') runZone(target.name, dragging.slot);
            } else if (target.kind === 'slot') {
                commitMove(dragging.side, dragging.slot, target.side, target.slot, ui.amount);
            } else if (target.kind === 'panel' && target.side !== dragging.side) {
                commitMove(dragging.side, dragging.slot, target.side, null, ui.amount);
            }
        } else if (from && from.shift) {
            quickMove(from.side, from.slot);
        }
    }

    function onPointerCancel() {
        endDrag();
        stopTracking();
    }

    // ---------- Tooltip ----------

    function showTip(node) {
        const item = itemAt(node);
        if (!item) return hideTip();
        const data = inv[node.dataset.side];

        tipEl.replaceChildren();
        tipEl.appendChild(el('div', 'tip-title', item.label));

        const tags = el('div', 'tip-tags');
        tags.appendChild(el('span', item.type === 'weapon' ? 'tag weapon' : 'tag', item.type));
        if (item.unique) tags.appendChild(el('span', 'tag', 'Unique'));
        if (item.useable) tags.appendChild(el('span', 'tag use', 'Useable'));
        tipEl.appendChild(tags);

        if (item.description) tipEl.appendChild(el('p', 'tip-desc', item.description));
        if (item.attachments.length) {
            const attached = el('div', 'tip-tags');
            for (const a of item.attachments) attached.appendChild(el('span', 'tag use', a.label));
            tipEl.appendChild(attached);
        }

        const rows = [];
        if (data.type === 'shop' && item.price != null) rows.push(['Price', money(item.price)]);
        rows.push(['Weight', `${kgShort(item.weight)} kg`]);
        if (item.amount > 1) rows.push([`Stack ×${item.amount}`, `${kgShort(item.weight * item.amount)} kg`]);
        const quality = num(item.info.quality, -1);
        if (quality >= 0) rows.push(['Quality', `${Math.round(quality)}%`]);
        for (const [key, value] of Object.entries(item.info)) {
            if (key === 'quality' || key.startsWith('_') || rows.length >= 8) continue;
            if (value === null || typeof value === 'object') continue;
            rows.push([prettyKey(key), String(value)]);
        }
        const list = el('div', 'tip-rows');
        for (const [label, value] of rows) {
            const row = el('div', 'tip-row');
            row.append(el('span', null, label), el('span', null, value));
            list.appendChild(row);
        }
        tipEl.appendChild(list);

        if (node.dataset.side === 'player') tipEl.appendChild(el('p', 'tip-hint', 'Press 1–5 to bind to a quick slot'));
        tipEl.hidden = false;
    }

    function placeTip(x, y) {
        const pad = 18;
        const w = tipEl.offsetWidth;
        const h = tipEl.offsetHeight;
        let left = x + pad;
        let top = y + pad;
        if (left + w > window.innerWidth - 8) left = x - w - pad;
        if (top + h > window.innerHeight - 8) top = window.innerHeight - h - 8;
        tipEl.style.transform = `translate(${Math.max(8, left)}px, ${Math.max(8, top)}px)`;
    }

    function hideTip() {
        ui.hoverNode = null;
        tipEl.hidden = true;
    }

    function onPointerHover(e) {
        if (!ui.open || drag) return;
        const node = e.target.closest ? e.target.closest('.slot.filled') : null;
        const live = node && (node.dataset.side === 'player' || node.dataset.side === 'other') ? node : null;
        if (live !== ui.hoverNode) {
            ui.hoverNode = live;
            if (live) showTip(live);
            else tipEl.hidden = true;
        }
        if (live) placeTip(e.clientX, e.clientY);
    }

    // ---------- Context menu ----------

    function hideCtx() { ctxEl.hidden = true; }

    function copyValue(item) {
        const entry = COPYABLE.find((c) => c.match(item));
        if (!entry) return null;
        const raw = item.info[entry.key];
        const parts = (Array.isArray(raw) ? raw : [raw])
            .filter((v) => v != null && typeof v !== 'object')
            .map((v) => String(v).trim())
            .filter(Boolean);
        return parts.length ? { entry, value: parts.join(', ') } : null;
    }

    // NUI is not always a secure context, so navigator.clipboard may be missing; execCommand works in CEF.
    function copyText(text) {
        const box = document.createElement('textarea');
        box.value = text;
        box.setAttribute('readonly', '');
        box.style.cssText = 'position:fixed;left:-9999px;top:0;opacity:0';
        document.body.appendChild(box);
        box.select();
        let ok = false;
        try { ok = document.execCommand('copy'); } catch (_) { /* fall through */ }
        box.remove();
        if (ok) return Promise.resolve(true);
        if (navigator.clipboard && navigator.clipboard.writeText) {
            return navigator.clipboard.writeText(text).then(() => true, () => false);
        }
        return Promise.resolve(false);
    }

    function runCopy(copy) {
        copyText(copy.value).then((ok) => toast(ok ? copy.entry.done : 'Could not copy', ok ? 'ok' : 'err'));
    }

    function showCtx(node, e) {
        const item = itemAt(node);
        if (!item) return;
        const side = node.dataset.side;
        const slot = Number(node.dataset.slot);
        const other = inv.other;
        const copy = copyValue(item);

        const actions = [];
        if (side === 'player') {
            actions.push({ icon: '#i-bolt', text: TEXT.use, off: !item.useable, run: () => doUse(slot) });
            if (other && !other.readonly) actions.push({ icon: '#i-swap', text: TEXT.transfer, run: () => quickMove('player', slot) });
            if (copy) actions.push({ icon: '#i-copy', text: copy.entry.text, run: () => runCopy(copy) });
            // The server pushes the updated weapon back once the attachment is off, so no local prediction here.
            for (const a of item.attachments) {
                actions.push({ icon: '#i-close', text: `Remove ${a.label}`, run: () => post('removeAttachment', { slot, name: item.name, attachment: a.attachment }) });
            }
            actions.push({ icon: '#i-gift', text: TEXT.give, run: () => removeFromPlayer('giveItem', slot) });
            actions.push({ icon: '#i-ground', text: TEXT.drop, run: () => removeFromPlayer('dropItem', slot) });
        } else {
            const shop = other && other.type === 'shop';
            actions.push({ icon: shop ? '#i-cart' : '#i-swap', text: shop ? TEXT.buy : TEXT.take, run: () => quickMove('other', slot) });
            if (copy) actions.push({ icon: '#i-copy', text: copy.entry.text, run: () => runCopy(copy) });
        }

        ctxEl.replaceChildren();
        const head = el('li', 'ctx-head');
        head.append(el('b', null, item.label), el('span', null, item.amount > 1 ? `×${item.amount}` : ''));
        ctxEl.appendChild(head);
        for (const action of actions) {
            const li = el('li');
            const btn = el('button');
            btn.type = 'button';
            btn.disabled = !!action.off;
            btn.append(svgIcon(action.icon), document.createTextNode(action.text));
            btn.addEventListener('click', () => { hideCtx(); action.run(); });
            li.appendChild(btn);
            ctxEl.appendChild(li);
        }

        hideTip();
        ctxEl.hidden = false;
        const w = ctxEl.offsetWidth;
        const h = ctxEl.offsetHeight;
        const left = Math.min(e.clientX + 4, window.innerWidth - w - 8);
        const top = Math.min(e.clientY + 4, window.innerHeight - h - 8);
        ctxEl.style.transform = `translate(${Math.max(8, left)}px, ${Math.max(8, top)}px)`;
    }

    // ---------- Open / close / messages ----------

    let closeTimer = null;

    function openUI(msg) {
        applyConfig(msg.config);
        const wasOpen = ui.open;
        inv.player = normalizeInventory(msg.player, 'player');
        inv.other = msg.other ? normalizeInventory(msg.other, 'stash') : null;
        ui.rev++;
        ui.open = true;
        ui.busy = false;
        if (!wasOpen) {
            ui.search = { player: '', other: '' };
            panels.player.search.value = '';
            panels.other.search.value = '';
        }
        hotbarEl.classList.remove('show');
        hotbarEl.hidden = true;
        renderAll();

        clearTimeout(closeTimer);
        appEl.hidden = false;
        if (!wasOpen) {
            appEl.classList.add('entering');
            void appEl.offsetWidth;
            appEl.classList.add('open');
            setTimeout(() => appEl.classList.remove('entering'), 800);
        }
    }

    function closeUI(tellLua) {
        if (!ui.open) return;
        ui.open = false;
        onPointerCancel();
        hideTip();
        hideCtx();
        appEl.classList.remove('open');
        clearTimeout(closeTimer);
        closeTimer = setTimeout(() => { if (!ui.open) appEl.hidden = true; }, 200);
        if (tellLua) post('close');
    }

    function updateUI(msg) {
        applyConfig(msg.config);
        if (msg.player) inv.player = normalizeInventory(msg.player, 'player');
        if ('other' in msg) inv.other = msg.other ? normalizeInventory(msg.other, 'stash') : null;
        ui.rev++;
        if (ui.open) renderAll();
    }

    window.addEventListener('message', (event) => {
        const msg = event.data;
        if (!msg || typeof msg.action !== 'string') return;
        switch (msg.action) {
            case 'open': return openUI(msg);
            case 'close': return closeUI(false);
            case 'update': return updateUI(msg);
            case 'hotbar': return showHotbar(msg);
            case 'itemBox': return itemBox(msg);
            case 'requiredItem': return showRequired(msg);
            case 'notify': return toast(String(msg.message || ''), msg.type === 'ok' ? 'ok' : 'err');
            default:
        }
    });

    // ---------- Input wiring ----------

    function onKeyDown(e) {
        if (!ui.open) return;
        const typing = e.target && e.target.tagName === 'INPUT';
        const key = e.key;

        const closing = cfg.closeKeys.some((k) => k.toLowerCase() === key.toLowerCase());
        if (closing && (!typing || key.length > 1)) {
            e.preventDefault();
            if (!ctxEl.hidden) hideCtx();
            else if (drag) onPointerCancel();
            else closeUI(true);
            return;
        }
        if (key === 'Enter' && typing) {
            e.target.blur();
            return;
        }

        if (!typing && /^[1-9]$/.test(key)) {
            const slot = Number(key);
            const node = ui.hoverNode;
            if (slot > cfg.hotbarSlots || !node || !node.isConnected || drag) return;
            commitMove(node.dataset.side, Number(node.dataset.slot), 'player', slot, 0);
        }
    }

    function init() {
        panels.player = buildPanel('player');
        panels.other = buildPanel('other');

        window.addEventListener('keydown', onKeyDown);
        appEl.addEventListener('pointerdown', onPointerDown);
        appEl.addEventListener('pointermove', onPointerHover);
        appEl.addEventListener('pointerleave', () => { if (!drag) hideTip(); });
        appEl.addEventListener('dblclick', (e) => {
            const node = e.target.closest('.slot.filled');
            if (node && node.dataset.side === 'player') doUse(Number(node.dataset.slot));
        });
        window.addEventListener('contextmenu', (e) => {
            e.preventDefault();
            if (!ui.open || drag) return;
            const node = e.target.closest('.slot.filled');
            if (node && (node.dataset.side === 'player' || node.dataset.side === 'other')) showCtx(node, e);
            else hideCtx();
        });
        window.addEventListener('dragstart', (e) => e.preventDefault());

        $('#btn-close').addEventListener('click', () => closeUI(true));

        amountInput.addEventListener('input', () => {
            const digits = amountInput.value.replace(/\D/g, '').slice(0, 4);
            ui.amount = digits ? parseInt(digits, 10) : 0;
            syncAmount();
        });
        $('#chips').addEventListener('click', (e) => {
            const btn = e.target.closest('button');
            if (!btn) return;
            ui.amount = Number(btn.dataset.amt);
            syncAmount();
        });
        $$('.stepper button').forEach((btn) => btn.addEventListener('click', () => {
            ui.amount = clamp(ui.amount + Number(btn.dataset.step), 0, 9999);
            syncAmount();
        }));
        syncAmount();

        post('ready');

        if (!IN_GAME) {
            const script = document.createElement('script');
            script.src = 'dev/mock.js';
            document.body.appendChild(script);
        }
    }

    init();
})();
