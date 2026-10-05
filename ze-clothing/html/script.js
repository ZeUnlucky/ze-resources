/* ze-clothing NUI. Vanilla JS, no build step, no CDNs, no jQuery.
   Lua sends: open, values, outfits, close.
   The UI sends back: updateSkin, setupCam, rotateLeft, rotateRight, setCurrentPed, selectOutfit, saveOutfit,
   removeOutfit, close {save}. (See README.md.) */

(() => {
    'use strict';

    const $ = (selector, parent = document) => parent.querySelector(selector);

    // Outside the game (dev/preview.html) there is no resource name; ZE_POST lets the preview intercept calls.
    const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'ze-clothing';

    function post(name, data) {
        if (window.ZE_POST) return Promise.resolve(window.ZE_POST(name, data || {}));
        return fetch(`https://${RESOURCE}/${name}`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data || {}),
        }).then((r) => r.json()).catch(() => null);
    }

    // ------------------------------------------------------------------ text

    // English fallbacks. Lua sends its own `tr` (locales/en.lua) with the same keys, which wins.
    const EN = {
        confirm: 'Confirm', cancel: 'Cancel', save_outfit: 'Save outfit', outfit_name: 'Outfit name',
        outfit_name_hint: 'Give this outfit a name', wear: 'Wear', delete: 'Delete', sure: 'Sure?',
        no_outfits: 'You have no saved outfits yet.', no_presets: 'No outfits are set up for your rank.',
        cam_full: 'Full body', cam_head: 'Head', cam_torso: 'Torso', cam_legs: 'Legs', rotate: 'Rotate',
        locked: 'Locked', none: 'None', style: 'Style', texture: 'Variant', color: 'Color', opacity: 'Opacity',
        model: 'Model', player_model: 'Player model', wardrobe: 'Wardrobe',
        grp_model: 'Model', grp_parents: 'Parents', grp_nose: 'Nose', grp_brows: 'Brows', grp_cheeks: 'Cheeks',
        grp_eyes: 'Eyes', grp_lips: 'Lips', grp_jaw: 'Jaw', grp_chin: 'Chin', grp_neck: 'Neck', grp_hair: 'Hair',
        grp_face: 'Face', grp_makeup: 'Makeup', grp_tops: 'Tops', grp_bottoms: 'Bottoms & shoes',
        grp_extras: 'Extras', grp_head: 'Head', grp_body: 'Wrists & ears',
        face: 'Mother', face2: 'Father', facemix: 'Parent mix', shape: 'Shape', skin: 'Skin tone',
        shape_mix: 'Shape mix', skin_mix: 'Skin mix', mother: 'Mother', father: 'Father',
        nose_0: 'Nose width', nose_1: 'Nose peak height', nose_2: 'Nose peak length', nose_3: 'Nose bone height',
        nose_4: 'Nose peak lowering', nose_5: 'Nose bone twist', eyebrown_high: 'Brow height',
        eyebrown_forward: 'Brow depth', cheek_1: 'Cheekbone height', cheek_2: 'Cheekbone width',
        cheek_3: 'Cheek width', eye_opening: 'Eye opening', lips_thickness: 'Lip thickness',
        jaw_bone_width: 'Jaw width', jaw_bone_back_lenght: 'Jaw length', chimp_bone_lowering: 'Chin height',
        chimp_bone_lenght: 'Chin length', chimp_bone_width: 'Chin width', chimp_hole: 'Chin hole',
        neck_thikness: 'Neck thickness',
        hair: 'Hair', eyebrows: 'Eyebrows', beard: 'Facial hair', eye_color: 'Eye color', moles: 'Moles / freckles',
        ageing: 'Ageing', lipstick: 'Lipstick', blush: 'Blush', makeup: 'Makeup',
        arms: 'Arms', 't-shirt': 'Undershirt / belts', torso2: 'Jackets / tops', vest: 'Vests', decals: 'Decals',
        accessory: 'Neck accessories', bag: 'Bags', pants: 'Pants', shoes: 'Shoes',
        mask: 'Masks', hat: 'Hats', glass: 'Glasses', ear: 'Ear accessories', watch: 'Watches', bracelet: 'Bracelets',
    };

    let tr = {};
    const T = (id) => (tr[id] !== undefined ? tr[id] : (EN[id] !== undefined ? EN[id] : id));

    // ------------------------------------------------------------------ accent (same code as ze-hud)

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

    const toList = (x) => (Array.isArray(x) ? x : (x && typeof x === 'object' ? Object.values(x) : []));

    // ------------------------------------------------------------------ what the tabs hold

    const feat = (...keys) => keys.map((k) => ({ k, compact: true }));

    // Rows are { k: skin key, item: caption id, tex: caption id }. Whether a row has a texture control comes from Lua.
    const SCHEMA = {
        features: [
            { title: 'grp_model', model: true },
            { title: 'grp_parents', rows: [{ k: 'face', item: 'shape', tex: 'skin' }, { k: 'face2', item: 'shape', tex: 'skin' }, { k: 'facemix', mix: true }] },
            { title: 'grp_nose', rows: feat('nose_0', 'nose_1', 'nose_2', 'nose_3', 'nose_4', 'nose_5') },
            { title: 'grp_brows', rows: feat('eyebrown_high', 'eyebrown_forward') },
            { title: 'grp_cheeks', rows: feat('cheek_1', 'cheek_2', 'cheek_3') },
            { title: 'grp_eyes', rows: feat('eye_opening') },
            { title: 'grp_lips', rows: feat('lips_thickness') },
            { title: 'grp_jaw', rows: feat('jaw_bone_width', 'jaw_bone_back_lenght') },
            { title: 'grp_chin', rows: feat('chimp_bone_lowering', 'chimp_bone_lenght', 'chimp_bone_width', 'chimp_hole') },
            { title: 'grp_neck', rows: feat('neck_thikness') },
        ],
        hair: [
            { title: 'grp_hair', rows: [{ k: 'hair', tex: 'color' }, { k: 'eyebrows', tex: 'color' }, { k: 'beard', tex: 'color' }] },
            { title: 'grp_face', rows: [{ k: 'eye_color', item: 'color' }, { k: 'moles', tex: 'opacity' }, { k: 'ageing' }] },
            { title: 'grp_makeup', rows: [{ k: 'lipstick', tex: 'color' }, { k: 'blush', tex: 'color' }, { k: 'makeup', tex: 'color' }] },
        ],
        clothing: [
            { title: 'grp_tops', rows: [{ k: 'torso2' }, { k: 't-shirt' }, { k: 'vest' }, { k: 'arms' }, { k: 'decals' }] },
            { title: 'grp_bottoms', rows: [{ k: 'pants' }, { k: 'shoes' }] },
            { title: 'grp_extras', rows: [{ k: 'accessory' }, { k: 'bag' }] },
        ],
        accessories: [
            { title: 'grp_head', rows: [{ k: 'hat' }, { k: 'glass' }, { k: 'mask' }, { k: 'ear' }] },
            { title: 'grp_body', rows: [{ k: 'watch' }, { k: 'bracelet' }] },
        ],
    };

    const TAB_ICONS = { features: 'user', hair: 'scissors', clothing: 'shirt', accessories: 'glasses', presets: 'list', outfits: 'bookmark' };
    const PROPS = new Set(['hat', 'glass', 'ear', 'watch', 'bracelet']); // item 0 means "none" for these

    // ------------------------------------------------------------------ state

    const S = {
        open: false,
        rows: {},          // skin key -> row api
        panes: {},         // tab id -> element
        tabBtns: {},
        active: null,
        hasTracker: false,
        outfits: { presets: [], outfits: [] },
        model: null,
        modelApi: null,
    };

    // ------------------------------------------------------------------ talking to Lua

    // Slider drags fire many events. Only the latest value per control matters, and one request at a time is
    // in flight, so the game is never flooded and the order of changes is kept.
    const queue = new Map();
    let inflight = false;

    function queueChange(key, type, value) {
        queue.set(`${key}:${type}`, { key, type, value });
        pump();
    }

    function pump() {
        if (inflight || !queue.size) return;
        const [id, job] = queue.entries().next().value;
        queue.delete(id);
        inflight = true;
        post('updateSkin', { clothingType: job.key, type: job.type, articleNumber: job.value })
            .then((res) => {
                const row = S.rows[job.key];
                if (row && res && typeof res === 'object') row.apply(res);
            })
            .then(() => { inflight = false; pump(); }, () => { inflight = false; pump(); });
    }

    // ------------------------------------------------------------------ controls

    function holdRepeat(btn, step) {
        let wait = null, timer = null;
        const stop = () => { clearTimeout(wait); clearInterval(timer); wait = timer = null; };
        btn.addEventListener('pointerdown', (e) => {
            if (btn.disabled) return;
            e.preventDefault();
            step();
            wait = setTimeout(() => { timer = setInterval(step, 70); }, 380);
        });
        ['pointerup', 'pointerleave', 'pointercancel'].forEach((ev) => btn.addEventListener(ev, stop));
    }

    function stepButton(dir) {
        const b = el('button', 'step');
        b.type = 'button';
        b.appendChild(icon(dir));
        return b;
    }

    // A whole-number control: step back, slider, step forward, number box.
    function control(api, type, caption) {
        const c = { type, min: 0, max: 0, value: 0, busy: false };
        c.el = el('div', caption ? 'ctl' : 'ctl nocap');
        if (caption) c.el.appendChild(el('span', 'ctl-cap', caption));

        const dec = stepButton('left');
        const inc = stepButton('right');
        const rng = el('input', 'rng');
        rng.type = 'range';
        rng.step = '1';
        const num = el('input', 'num');
        num.type = 'number';
        num.step = '1';
        c.el.append(dec, rng, inc, num);

        c.render = () => {
            rng.min = c.min;
            rng.max = Math.max(c.max, c.min);
            rng.value = c.value;
            num.value = c.value;
            const span = (c.max - c.min) || 1;
            rng.style.setProperty('--fill', `${Math.max(0, Math.min(100, ((c.value - c.min) / span) * 100))}%`);
            dec.disabled = c.value <= c.min;
            inc.disabled = c.value >= c.max;
        };

        // from Lua: a value being dragged or typed is not overwritten by an older reply
        c.set = (value, min, max) => {
            if (min !== undefined) c.min = min;
            if (max !== undefined) c.max = max;
            if (!c.busy && value !== undefined) c.value = value;
            // an old save can hold a value outside today's range: keep it visible
            if (c.value < c.min) c.min = c.value;
            if (c.value > c.max) c.max = c.value;
            c.render();
        };

        c.commit = (raw) => {
            let v = Math.round(Number(raw));
            if (!Number.isFinite(v)) { c.render(); return; }
            v = Math.min(c.max, Math.max(c.min, v));
            c.value = v;
            c.render();
            api.badge();
            queueChange(api.k, type, v);
        };

        holdRepeat(dec, () => c.commit(c.value - 1));
        holdRepeat(inc, () => c.commit(c.value + 1));
        rng.addEventListener('pointerdown', () => { c.busy = true; });
        rng.addEventListener('input', () => c.commit(rng.value));
        ['pointerup', 'pointercancel', 'change', 'blur'].forEach((ev) => rng.addEventListener(ev, () => { c.busy = false; }));
        num.addEventListener('focus', () => { c.busy = true; num.select(); });
        num.addEventListener('blur', () => { c.busy = false; c.render(); });
        num.addEventListener('change', () => c.commit(num.value));
        num.addEventListener('keydown', (e) => { if (e.key === 'Enter') num.blur(); });
        return c;
    }

    // Mother / father mix: two 0..100 sliders (sent to Lua as 0..1).
    function mixControl(api, type, title) {
        const c = { type, value: 50, busy: false };
        c.el = el('div', 'mix');
        c.el.appendChild(el('div', 'mix-head', title));
        const rng = el('input', 'rng');
        rng.type = 'range';
        rng.min = '0';
        rng.max = '100';
        rng.step = '1';
        const ends = el('div', 'mix-ends');
        ends.append(el('span', null, T('mother')), el('span', null, T('father')));
        c.el.append(rng, ends);

        c.render = () => {
            rng.value = c.value;
            rng.style.setProperty('--fill', `${c.value}%`);
        };
        c.set = (fraction) => {
            if (c.busy || typeof fraction !== 'number') return;
            c.value = Math.round(fraction * 100);
            c.render();
        };
        rng.addEventListener('pointerdown', () => { c.busy = true; });
        rng.addEventListener('input', () => {
            c.value = Number(rng.value);
            c.render();
            queueChange(api.k, type, c.value / 100);
        });
        ['pointerup', 'pointercancel', 'change', 'blur'].forEach((ev) => rng.addEventListener(ev, () => { c.busy = false; }));
        return c;
    }

    // ------------------------------------------------------------------ rows

    function formatItem(key, item, compact) {
        if (compact) return item > 0 ? `+${item}` : String(item);
        if (item < 0 || (PROPS.has(key) && item === 0)) return T('none');
        return String(item);
    }

    function buildRow(def) {
        const key = def.k;
        const api = { k: key, def };
        api.el = el('div', 'row');
        const head = el('div', 'row-head');
        const label = el('span', 'row-label');
        label.appendChild(el('span', null, T(key)));
        if (key === 'accessory' && S.hasTracker) {
            label.appendChild(icon('lock'));
            api.el.classList.add('locked');
            api.el.title = T('locked');
        }
        api.val = el('span', 'row-val');
        head.append(label, api.val);
        api.el.appendChild(head);

        if (def.mix) {
            api.mix = {
                shapeMix: mixControl(api, 'shapeMix', T('shape_mix')),
                skinMix: mixControl(api, 'skinMix', T('skin_mix')),
            };
            api.el.append(api.mix.shapeMix.el, api.mix.skinMix.el);
            api.badge = () => {};
            api.apply = (v) => {
                api.mix.shapeMix.set(v.shapeMix);
                api.mix.skinMix.set(v.skinMix);
            };
            return api;
        }

        api.item = control(api, 'item', def.compact ? null : T(def.item || 'style'));
        api.tex = control(api, 'texture', T(def.tex || 'texture'));
        api.tex.el.hidden = true;
        api.el.append(api.item.el, api.tex.el);

        api.badge = () => {
            api.val.textContent = formatItem(key, api.item.value, def.compact);
            if (!def.compact && api.item.max > 0) {
                const small = el('small', null, ` / ${api.item.max}`);
                api.val.appendChild(small);
            }
        };
        api.apply = (v) => {
            if (v.item === undefined) return;
            api.item.set(v.item, v.minItem, v.maxItem);
            api.tex.el.hidden = !v.hasTexture;
            if (v.hasTexture) api.tex.set(v.texture, v.minTexture, v.maxTexture);
            api.badge();
        };
        return api;
    }

    // ------------------------------------------------------------------ player model

    function buildModel() {
        const wrap = el('div', 'row');
        const head = el('div', 'row-head');
        head.appendChild(el('span', 'row-label', T('player_model')));
        const val = el('span', 'row-val');
        head.appendChild(val);
        const line = el('div', 'model');
        const dec = stepButton('left');
        const inc = stepButton('right');
        const name = el('div', 'model-name');
        const nameText = el('b');
        const sub = el('small');
        name.append(nameText, sub);
        line.append(dec, name, inc);
        wrap.append(head, line);

        const api = { el: wrap };
        api.set = (m) => {
            if (!m) return;
            S.model = m;
            nameText.textContent = m.name || '';
            sub.textContent = `${m.index} / ${m.count}`;
            dec.disabled = m.index <= 1;
            inc.disabled = m.index >= m.count;
        };
        const go = (delta) => {
            if (!S.model) return;
            const next = Math.min(S.model.count, Math.max(1, S.model.index + delta));
            if (next === S.model.index) return;
            post('setCurrentPed', { ped: next }).then((m) => { if (m && m.name) api.set(m); });
        };
        dec.addEventListener('click', () => go(-1));
        inc.addEventListener('click', () => go(1));
        api.set(S.model);
        return api;
    }

    // ------------------------------------------------------------------ outfits

    function fillOutfits(kind) {
        const pane = S.panes[kind];
        if (!pane) return;
        pane.textContent = '';
        const list = toList(S.outfits[kind]);
        if (!list.length) {
            pane.appendChild(el('div', 'empty', T(kind === 'presets' ? 'no_presets' : 'no_outfits')));
            return;
        }

        list.forEach((o) => {
            const mine = kind === 'outfits';
            const name = mine ? o.outfitname : o.outfitLabel;
            const card = el('div', 'outfit');
            card.appendChild(el('span', 'outfit-name', name || ''));

            const wear = el('button', 'btn-sm');
            wear.type = 'button';
            wear.append(icon('check'), el('span', null, T('wear')));
            wear.addEventListener('click', () => {
                pane.querySelectorAll('.outfit.worn').forEach((n) => n.classList.remove('worn'));
                card.classList.add('worn');
                post('selectOutfit', mine
                    ? { outfitData: o.skin, outfitName: o.outfitname, outfitId: o.outfitId }
                    : { outfitData: o.outfitData, outfitName: o.outfitLabel });
            });
            card.appendChild(wear);

            if (mine) {
                const del = el('button', 'btn-sm danger');
                del.type = 'button';
                del.title = T('delete');
                del.appendChild(icon('trash'));
                let armed = null;
                del.addEventListener('click', () => {
                    if (!armed) {
                        // the first click only arms it
                        del.classList.add('armed');
                        del.replaceChildren(el('span', null, T('sure')));
                        armed = setTimeout(() => {
                            armed = null;
                            del.classList.remove('armed');
                            del.replaceChildren(icon('trash'));
                        }, 2500);
                        return;
                    }
                    clearTimeout(armed);
                    post('removeOutfit', { outfitName: o.outfitname, outfitId: o.outfitId });
                });
                card.appendChild(del);
            }
            pane.appendChild(card);
        });
    }

    // ------------------------------------------------------------------ building the menu

    function buildSchemaPane(tab) {
        const pane = el('div');
        (SCHEMA[tab] || []).forEach((group) => {
            if (group.model && !S.modelSwitch) return;
            pane.appendChild(el('div', 'group-title', T(group.title)));
            if (group.model) {
                S.modelApi = buildModel();
                pane.appendChild(S.modelApi.el);
                return;
            }
            group.rows.forEach((def) => {
                const row = buildRow(def);
                S.rows[def.k] = row;
                pane.appendChild(row.el);
            });
        });
        return pane;
    }

    function selectTab(id) {
        S.active = id;
        Object.keys(S.panes).forEach((k) => {
            S.panes[k].hidden = k !== id;
            S.tabBtns[k].classList.toggle('on', k === id);
        });
        $('#subtitle').textContent = S.tabBtns[id] ? S.tabBtns[id].dataset.label : '';
        $('#body').scrollTop = 0;
    }

    function applyValues(values) {
        if (!values) return;
        Object.keys(values).forEach((k) => {
            if (S.rows[k]) S.rows[k].apply(values[k]);
        });
    }

    function translateStatic() {
        document.querySelectorAll('[data-t]').forEach((n) => { n.textContent = T(n.dataset.t); });
        document.querySelectorAll('[data-tt]').forEach((n) => { n.title = T(n.dataset.tt); });
    }

    function resetCameraButtons() {
        document.querySelectorAll('#cams .seg-btn').forEach((b) => b.classList.toggle('on', b.dataset.cam === '0'));
    }

    function open(msg) {
        tr = msg.tr || {};
        if (msg.accent) setAccent(msg.accent);
        S.hasTracker = !!msg.hasTracker;
        S.modelSwitch = !!msg.modelSwitch;
        S.model = msg.model || null;
        S.rows = {};
        S.panes = {};
        S.tabBtns = {};
        S.modelApi = null;
        S.outfits.presets = [];
        S.outfits.outfits = [];

        translateStatic();
        $('#title').textContent = msg.title || T('wardrobe');

        const tabs = $('#tabs');
        const body = $('#body');
        tabs.textContent = '';
        body.textContent = '';

        const menus = toList(msg.menus).filter((m) => m && (SCHEMA[m.menu] || m.menu === 'presets' || m.menu === 'outfits'));
        menus.forEach((m) => {
            const btn = el('button', 'tab');
            btn.type = 'button';
            btn.dataset.label = m.label || m.menu;
            btn.append(icon(TAB_ICONS[m.menu] || 'list'), el('span', null, m.label || m.menu));
            btn.addEventListener('click', () => selectTab(m.menu));
            tabs.appendChild(btn);
            S.tabBtns[m.menu] = btn;

            let pane;
            if (m.menu === 'presets' || m.menu === 'outfits') {
                pane = el('div');
                S.panes[m.menu] = pane;
                S.outfits[m.menu] = m.outfits;
                fillOutfits(m.menu);
            } else {
                pane = buildSchemaPane(m.menu);
                S.panes[m.menu] = pane;
            }
            pane.hidden = true;
            body.appendChild(pane);
        });
        tabs.classList.toggle('single', menus.length <= 1);

        applyValues(msg.values);
        const first = menus.find((m) => m.selected) || menus[0];
        if (first) selectTab(first.menu);
        resetCameraButtons();

        const app = $('#app');
        clearTimeout(S.hideTimer);
        app.hidden = false;
        S.open = true;
        requestAnimationFrame(() => requestAnimationFrame(() => app.classList.add('open')));
    }

    function hide() {
        const app = $('#app');
        S.open = false;
        $('#modal').hidden = true;
        app.classList.remove('open');
        clearTimeout(S.hideTimer);
        S.hideTimer = setTimeout(() => { app.hidden = true; }, 220);
    }

    function finish(save) {
        if (!S.open) return;
        hide();
        post('close', { save });
    }

    // ------------------------------------------------------------------ camera, keys, dialog

    document.querySelectorAll('#cams .seg-btn').forEach((b) => {
        b.addEventListener('click', () => {
            document.querySelectorAll('#cams .seg-btn').forEach((n) => n.classList.toggle('on', n === b));
            post('setupCam', { value: Number(b.dataset.cam) });
        });
    });

    function holdOrbit(btn, action) {
        let timer = null;
        const stop = () => { clearInterval(timer); timer = null; };
        btn.addEventListener('pointerdown', (e) => {
            e.preventDefault();
            post(action);
            timer = setInterval(() => post(action), 40);
        });
        ['pointerup', 'pointerleave', 'pointercancel'].forEach((ev) => btn.addEventListener(ev, stop));
        window.addEventListener('blur', stop);
    }
    holdOrbit($('#orbit-left'), 'rotateLeft');
    holdOrbit($('#orbit-right'), 'rotateRight');

    $('#confirm').addEventListener('click', () => finish(true));
    $('#cancel').addEventListener('click', () => finish(false));

    function openDialog() {
        const input = $('#outfit-name');
        input.value = '';
        input.placeholder = T('outfit_name_hint');
        $('#modal').hidden = false;
        input.focus();
    }
    function closeDialog() { $('#modal').hidden = true; }
    function saveDialog() {
        const name = $('#outfit-name').value.trim();
        if (!name) { $('#outfit-name').focus(); return; }
        post('saveOutfit', { outfitName: name });
        closeDialog();
    }

    $('#save-outfit').addEventListener('click', openDialog);
    $('#outfit-ok').addEventListener('click', saveDialog);
    $('#outfit-cancel').addEventListener('click', closeDialog);

    document.addEventListener('keydown', (e) => {
        if (!S.open) return;
        if (e.key === 'Escape') {
            if (!$('#modal').hidden) closeDialog(); else finish(false);
            return;
        }
        if (e.key === 'Enter' && !$('#modal').hidden) {
            saveDialog();
            return;
        }
        // A and D turn the camera, unless the player is typing
        if (e.target instanceof HTMLInputElement && e.target.type !== 'range') return;
        if (e.code === 'KeyA') post('rotateLeft');
        else if (e.code === 'KeyD') post('rotateRight');
    });

    // ------------------------------------------------------------------ messages from Lua

    window.addEventListener('message', (event) => {
        const msg = event.data;
        if (!msg || !msg.action) return;
        switch (msg.action) {
            case 'open':
                open(msg);
                break;
            case 'values':
                applyValues(msg.values);
                if (S.modelApi) S.modelApi.set(msg.model || S.model);
                break;
            case 'outfits':
                S.outfits.outfits = msg.outfits;
                fillOutfits('outfits');
                break;
            case 'close':
                hide();
                break;
        }
    });
})();
