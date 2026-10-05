/* Phone: favorites, recent calls, contacts, keypad, contact card. Calls themselves are in calls.js. */

(() => {
    'use strict';

    const { h, icon } = ZP;
    const ui = ZP.ui;
    const state = ZP.state;

    const LETTERS = { 2: 'ABC', 3: 'DEF', 4: 'GHI', 5: 'JKL', 6: 'MNO', 7: 'PQRS', 8: 'TUV', 9: 'WXYZ', 0: '+' };

    // the red number on the phone icon: missed calls nobody has looked at, and contacts that were shared with you
    function updateBadge() {
        const missed = state.calls.filter(c => c.direction === 'missed' && !c.seen).length;
        ZP.setBadge('phone', missed + state.suggestions.length);
    }
    ZP.on('calls', updateBadge);
    ZP.on('suggestions', updateBadge);
    ZP.on('boot', updateBadge);

    // ------------------------------------------------------------------ contact edit

    function editContact(ctx, contact, prefill) {
        const isNew = !contact;
        const name = ui.field({ label: 'Name', value: contact ? contact.name : (prefill && prefill.name) || '', max: 50, placeholder: 'Name', autofocus: true });
        const number = ui.field({ label: 'Phone number', value: contact ? contact.number : (prefill && prefill.number) || '', max: 15, inputmode: 'numeric', placeholder: '5551234567' });
        const iban = ui.field({ label: 'Bank account (optional)', value: contact ? contact.iban : (prefill && prefill.iban) || '', max: 50, placeholder: 'Account number', hint: 'Lets you send money from the Bank app' });
        const save = ui.btn({
            text: isNew ? 'Add contact' : 'Save', block: true,
            onclick: async () => {
                save.disabled = true;
                const res = await ZP.api(isNew ? 'contacts:add' : 'contacts:edit', { id: contact && contact.id, name: name.value(), number: number.value(), iban: iban.value() });
                save.disabled = false;
                if (res.error) return ui.toast(res.error, 'error');
                const list = state.contacts.filter(c => !contact || c.id !== contact.id);
                list.push(res.contact);
                ZP.contacts.set(list);
                ui.toast(isNew ? 'Contact added' : 'Saved');
                ctx.pop();
                if (!isNew) { ctx.pop(); contactView(ctx, res.contact); }
            },
        });
        const view = ui.view({
            title: isNew ? 'New contact' : 'Edit contact',
            body: h('div.form', name.el, number.el, iban.el, save),
        });
        ctx.push(view);
    }

    // ------------------------------------------------------------------ contact card

    function circleAction(ic, label, onclick, kind) {
        return h(`button.caction${kind ? '.' + kind : ''}`, { type: 'button', onclick }, h('span.cico', icon(ic)), h('span', label));
    }

    function contactView(ctx, contact) {
        const known = contact && contact.id !== undefined;
        const number = contact.number;
        const name = known ? contact.name : ZP.fmt.number(number);
        const favorite = () => ZP.contacts.isFavorite(number);
        const blocked = () => ZP.contacts.isBlocked(number);

        const body = h('div.cardbody');
        const view = ui.view({
            title: '',
            actions: known ? [ui.iconBtn('edit', () => editContact(ctx, contact), { title: 'Edit' })] : [],
            body,
        });

        const draw = () => {
            ZP.clear(body);
            const picture = (state.chats.find(c => c.number === number) || {}).picture;
            body.appendChild(h('div.chead',
                ui.avatar({ name, src: picture, size: 'xl' }),
                h('div.cname', name),
                known ? h('div.csub', ZP.fmt.number(number)) : h('div.csub', 'Unknown number'),
                h('div.cchips', blocked() ? ui.chip('Blocked', 'bad', 'ban') : null, known && contact.online ? ui.chip('Online', 'ok') : null)));

            const actions = [
                circleAction('message', 'Message', () => ZP.shell.openApp('messages', { chat: number })),
                circleAction('phone', 'Call', () => ZP.calls.start(number)),
            ];
            if (known && contact.iban) actions.push(circleAction('bank', 'Pay', () => ZP.shell.openApp('bank', { pay: contact })));
            actions.push(circleAction('share', 'Share', async () => {
                const target = await ui.nearbyPicker({ title: 'Share your contact card with' });
                if (!target) return;
                const res = await ZP.api('contacts:share', { id: target.id });
                ui.toast(res.error || `Shared with ${target.name}`, res.error ? 'error' : undefined);
            }));
            body.appendChild(h('div.cactions', actions));

            const rows = [
                ui.row({ icon: 'phone', color: '#17a673', title: ZP.fmt.number(number), sub: 'Phone number', right: icon('copy'), onclick: () => ZP.copy(number) }),
            ];
            if (known && contact.iban) rows.push(ui.row({ icon: 'bank', color: '#7a56f0', title: contact.iban, sub: 'Bank account', right: icon('copy'), onclick: () => ZP.copy(contact.iban) }));
            body.appendChild(h('div.gcard', rows));

            const fav = ui.toggle(favorite(), (on) => {
                const list = (state.settings.favorites || []).filter(n => n !== number);
                if (on) list.push(number);
                ZP.saveSettings({ favorites: list });
            });
            const rows2 = [];
            if (known) rows2.push(ui.row({ icon: 'star', color: '#ffb62e', title: 'Favorite', right: fav.el, onclick: () => fav.el.click() }));
            const block = ui.toggle(blocked(), async (on) => {
                const res = await ZP.api('contacts:block', { number, on });
                if (res.error) { block.set(!on); return ui.toast(res.error, 'error'); }
                state.blocked = on ? state.blocked.concat(number) : state.blocked.filter(n => n !== number);
                ui.toast(on ? 'Number blocked' : 'Number unblocked');
                draw();
            });
            rows2.push(ui.row({ icon: 'ban', color: '#e0314f', title: 'Block this caller', sub: 'No calls or messages from this number', right: block.el, onclick: () => block.el.click() }));
            body.appendChild(h('div.gcard', rows2));

            if (known) {
                body.appendChild(h('div.gcard', ui.row({
                    icon: 'trash', color: '#e0314f', title: 'Delete contact', danger: true,
                    onclick: async () => {
                        if (!await ui.confirm({ title: 'Delete contact?', text: contact.name, ok: 'Delete', danger: true })) return;
                        const res = await ZP.api('contacts:delete', { id: contact.id });
                        if (res.error) return ui.toast(res.error, 'error');
                        ZP.contacts.set(state.contacts.filter(c => c.id !== contact.id));
                        ctx.pop();
                    },
                })));
            } else {
                body.appendChild(ui.btn({ text: 'Add to contacts', icon: 'user-plus', block: true, onclick: () => editContact(ctx, null, { number }) }));
            }
        };
        draw();
        ctx.push(view);
    }

    // ------------------------------------------------------------------ the tabs

    function favoritesPanel(ctx) {
        const el = h('div.panel');
        const draw = () => {
            ZP.clear(el);
            const favs = (state.settings.favorites || []).map(n => ZP.contacts.byNumber(n)).filter(Boolean);
            if (!favs.length) {
                el.appendChild(ui.empty({ icon: 'star', title: 'No favorites yet', text: 'Open a contact and turn on Favorite to keep them one tap away.' }));
                return;
            }
            el.appendChild(h('div.favgrid', favs.map(c => h('button.fav', { type: 'button', onclick: () => ZP.calls.start(c.number), oncontextmenu: (e) => { e.preventDefault(); contactView(ctx, c); } },
                ui.avatar({ name: c.name, size: 'lg' }), h('span', c.name)))));
            el.appendChild(h('div.hint', 'Tap to call. Right click for the contact card.'));
        };
        ctx.on('settings', draw);
        ctx.on('contacts', draw);
        draw();
        return { el, draw };
    }

    function recentsPanel(ctx) {
        const el = h('div.panel');
        let mode = 'all';
        const seg = ui.segmented([{ id: 'all', label: 'All' }, { id: 'missed', label: 'Missed' }], 'all', (m) => { mode = m; draw(); });
        const list = h('div.gcard');
        const clear = ui.btn({ text: 'Clear call history', kind: 'danger', block: true, small: true, onclick: async () => {
            if (!await ui.confirm({ title: 'Clear call history?', ok: 'Clear', danger: true })) return;
            await ZP.api('calls:clear');
            state.calls = [];
            ZP.emit('calls', state.calls);
        } });
        el.appendChild(seg.el);
        el.appendChild(list);

        const draw = () => {
            ZP.clear(list);
            const items = state.calls.filter(c => mode === 'all' || c.direction === 'missed');
            if (!items.length) {
                ZP.clear(el);
                el.appendChild(seg.el);
                el.appendChild(ui.empty({ icon: 'clock', title: mode === 'missed' ? 'No missed calls' : 'No recent calls', text: 'Calls you make and receive show up here.' }));
                return;
            }
            if (!list.parentNode) { ZP.clear(el); el.appendChild(seg.el); el.appendChild(list); }
            items.forEach((c) => {
                const hidden = c.anonymous || !c.number;
                const name = hidden ? 'Unknown number' : ZP.contacts.nameOf(c.number);
                const ic = c.direction === 'missed' ? 'arrow-down-left' : c.direction === 'incoming' ? 'arrow-down-left' : 'arrow-up-right';
                const sub = c.direction === 'missed' ? 'Missed call' : (c.direction === 'incoming' ? 'Incoming' : 'Outgoing') + (c.duration ? ' · ' + ZP.fmt.dur(c.duration) : '');
                list.appendChild(ui.row({
                    avatar: ui.avatar({ name: hidden ? '?' : name, size: 'sm' }),
                    title: h('span', { class: c.direction === 'missed' ? 'missed' : '' }, name),
                    sub: h('span.csubline', icon(ic, c.direction === 'missed' ? 'miss' : ''), sub),
                    right: [h('span', ZP.fmt.short(c.ts)), hidden ? null : ui.iconBtn('info', (e) => { e.stopPropagation(); contactView(ctx, ZP.contacts.byNumber(c.number) || { number: c.number }); }, { size: 'sm', title: 'Details' })],
                    onclick: () => { if (!hidden) ZP.calls.start(c.number); else ui.toast('This caller hid their number'); },
                }));
            });
            list.parentNode.appendChild(clear);
        };
        ctx.on('calls', draw);
        ctx.on('contacts', draw);
        draw();
        return { el, draw, seen: () => {
            if (state.calls.some(c => c.direction === 'missed' && !c.seen)) {
                state.calls.forEach(c => { c.seen = true; });
                ZP.api('calls:seen');
                updateBadge();
            }
        } };
    }

    function contactsPanel(ctx) {
        const el = h('div.panel');
        const suggestBox = h('div.suggest');
        const list = h('div.alpha');
        const search = ui.search({ placeholder: 'Search contacts', onInput: () => draw() });
        el.appendChild(search.el);
        el.appendChild(suggestBox);
        el.appendChild(list);

        const drawSuggestions = () => {
            ZP.clear(suggestBox);
            if (!state.suggestions.length) return;
            suggestBox.appendChild(h('div.glabel', 'Suggested contacts'));
            const rows = state.suggestions.map((s, i) => ui.row({
                avatar: ui.avatar({ name: s.name, size: 'sm' }), title: s.name, sub: ZP.fmt.number(s.number),
                right: [
                    ui.btn({ text: 'Add', kind: 'soft', small: true, onclick: () => { state.suggestions.splice(i, 1); ZP.emit('suggestions', state.suggestions); editContact(ctx, null, s); } }),
                    ui.iconBtn('x', () => { state.suggestions.splice(i, 1); ZP.emit('suggestions', state.suggestions); }, { size: 'sm', kind: 'muted' }),
                ],
            }));
            suggestBox.appendChild(h('div.gcard', rows));
        };

        const draw = () => {
            drawSuggestions();
            ZP.clear(list);
            const needle = search.value().trim().toLowerCase();
            const items = state.contacts.filter(c => !needle || c.name.toLowerCase().includes(needle) || c.number.includes(needle));
            if (!items.length) {
                list.appendChild(ui.empty({ icon: 'users', title: needle ? 'No matches' : 'No contacts', text: needle ? 'Try another name or number.' : 'Tap + to add your first contact.' }));
                return;
            }
            let letter = null, card = null;
            items.forEach((c) => {
                const first = (c.name.match(/[\p{L}]/u) || ['#'])[0].toUpperCase();
                if (first !== letter) {
                    letter = first;
                    list.appendChild(h('div.letter', letter));
                    card = h('div.gcard');
                    list.appendChild(card);
                }
                card.appendChild(ui.row({
                    avatar: ui.avatar({ name: c.name, size: 'sm' }), title: c.name, sub: ZP.fmt.number(c.number),
                    right: [ZP.contacts.isFavorite(c.number) ? icon('star-fill', 'fav-on') : null, c.online ? h('i.online') : null, ZP.contacts.isBlocked(c.number) ? icon('ban', 'miss') : null],
                    onclick: () => contactView(ctx, c),
                }));
            });
        };
        ctx.on('contacts', draw);
        ctx.on('suggestions', draw);
        ctx.on('settings', draw);
        draw();
        return { el, draw };
    }

    function keypadPanel(ctx) {
        let digits = '';
        let hide = !!state.settings.anonymous;
        const display = h('div.kdisplay');
        const match = h('div.kmatch');
        const paint = () => {
            display.textContent = digits ? ZP.fmt.number(digits) : '';
            display.classList.toggle('empty', !digits);
            const c = digits ? ZP.contacts.byNumber(digits) : null;
            match.textContent = c ? c.name : '';
            addBtn.hidden = !(digits.length >= 3 && !c);
            delBtn.style.visibility = digits ? 'visible' : 'hidden';
        };
        const press = (d) => { if (digits.length < 15) digits += d; paint(); };
        const keys = '123456789*0#'.split('').map((k) => h('button.key', { type: 'button', onclick: () => { if (/\d/.test(k)) press(k); } },
            h('span.knum', k), h('span.kletters', /\d/.test(k) ? (LETTERS[k] || '') : '')));
        const delBtn = h('button.kdel', { type: 'button', onclick: () => { digits = digits.slice(0, -1); paint(); }, oncontextmenu: (e) => { e.preventDefault(); digits = ''; paint(); } }, icon('backspace'));
        const addBtn = h('button.kadd', { type: 'button', onclick: () => editContact(ctx, null, { number: digits }) }, icon('user-plus'), h('span', 'Add'));
        const callBtn = h('button.kcall', { type: 'button', onclick: () => { if (digits) ZP.calls.start(digits, { anonymous: hide }); } }, icon('phone'));
        const hideChip = h('button.khide' + (hide ? '.on' : ''), { type: 'button', onclick: () => { hide = !hide; hideChip.classList.toggle('on', hide); } }, icon('eye-off'), h('span', 'Hide my number'));

        const el = h('div.panel.keypad', display, match, h('div.kgrid', keys), h('div.krow', addBtn, callBtn, delBtn), hideChip);

        // typing digits on the keyboard works too, while this tab is on screen
        const onKey = (e) => {
            if (!el.isConnected || el.parentNode.hidden || /^(INPUT|TEXTAREA)$/.test((document.activeElement || {}).tagName)) return;
            if (/^\d$/.test(e.key)) press(e.key);
            else if (e.key === 'Backspace') { digits = digits.slice(0, -1); paint(); }
            else if (e.key === 'Enter' && digits) ZP.calls.start(digits, { anonymous: hide });
        };
        document.addEventListener('keydown', onKey);
        ctx.offs.push(() => document.removeEventListener('keydown', onKey));
        ctx.on('contacts', paint);
        paint();
        return { el, setNumber: (n) => { digits = String(n || '').replace(/\D/g, ''); paint(); } };
    }

    // ------------------------------------------------------------------ app

    ZP.registerApp({
        id: 'phone', name: 'Phone', icon: 'phone', colors: ['#3ddc97', '#17a673'],
        mount(ctx, params) {
            const favs = favoritesPanel(ctx), recents = recentsPanel(ctx), contacts = contactsPanel(ctx), keypad = keypadPanel(ctx);
            const panels = { favorites: favs.el, recents: recents.el, contacts: contacts.el, keypad: keypad.el };
            const titles = { favorites: 'Favorites', recents: 'Recents', contacts: 'Contacts', keypad: 'Keypad' };
            const holder = h('div.panels');
            Object.keys(panels).forEach(k => { const w = h('div.pwrap', { hidden: true }, panels[k]); holder.appendChild(w); panels[k] = w; });

            const tabs = ui.tabbar([
                { id: 'favorites', icon: 'star', label: 'Favorites' },
                { id: 'recents', icon: 'clock', label: 'Recents' },
                { id: 'contacts', icon: 'users', label: 'Contacts' },
                { id: 'keypad', icon: 'keypad', label: 'Keypad' },
            ], 'recents', (id) => show(id));

            const addBtn = ui.iconBtn('plus', () => editContact(ctx, null), { title: 'New contact' });
            const view = ui.view({ title: 'Recents', large: true, root: true, actions: [], body: holder, footer: tabs.el, className: 'nopad' });

            const show = (id) => {
                Object.keys(panels).forEach(k => { panels[k].hidden = k !== id; });
                view.setTitle(titles[id]);
                view.setActions(id === 'contacts' ? [addBtn] : []);
                if (id === 'recents') recents.seen();
                view.body.scrollTop = 0;
            };

            ctx.on('calls', () => tabs.badge('recents', state.calls.filter(c => c.direction === 'missed' && !c.seen).length));
            ctx.on('suggestions', () => tabs.badge('contacts', state.suggestions.length));
            tabs.badge('contacts', state.suggestions.length);

            ctx.push(view);
            const start = params.tab || (state.suggestions.length && !params.number ? 'contacts' : (params.number ? 'keypad' : 'recents'));
            tabs.select(start);
            if (params.number) keypad.setNumber(params.number);
            ctx.contactView = (c) => contactView(ctx, c);
            tabs.badge('recents', state.calls.filter(c => c.direction === 'missed' && !c.seen).length);
            if (params.contact) contactView(ctx, params.contact);
        },
        onParams(ctx, params) {
            if (params.contact) ctx.contactView(params.contact);
        },
    });
})();
