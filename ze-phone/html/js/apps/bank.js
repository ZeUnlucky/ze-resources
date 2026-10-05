/* Bank: balance and recent activity, transfers by account number or from a contact, invoices (pay, decline, and create
   for jobs that may bill). The server checks every amount (server/bank.lua). */

(() => {
    'use strict';

    const { h, icon } = ZP;
    const ui = ZP.ui;
    const state = ZP.state;

    const store = { cash: 0, bank: 0, crypto: 0, account: '', history: [], invoices: [], loaded: false };
    const SOCIETY = { police: ['Police', '#4a8cff'], ambulance: ['Ambulance', '#ff5d7a'], mechanic: ['Mechanic', '#34d399'] };

    const syncMoney = () => {
        const m = state.player.money || {};
        store.cash = m.cash; store.bank = m.bank; store.crypto = m.crypto;
    };
    ZP.on('player', () => { syncMoney(); ZP.emit('bank', store); });
    ZP.on('boot', () => { syncMoney(); });

    const addHistory = (kind, amount, other, note) => {
        store.history.unshift({ kind, amount, other, note, ts: Date.now() });
        if (store.history.length > 40) store.history.length = 40;
    };

    ZP.onPush('bankIn', (d, mute) => {
        if (typeof d.bank === 'number') { store.bank = d.bank; state.player.money.bank = d.bank; }
        addHistory('in', d.amount, d.from, d.note);
        ZP.emit('bank', store);
        if (!mute) ZP.notify({ app: 'bank', title: 'Money received', text: `${ZP.fmt.money(d.amount)} from ${d.from}`, icon: 'bank' });
    });
    ZP.onPush('bankOut', (d, mute) => {
        if (!mute) ZP.notify({ app: 'bank', title: 'Bank', text: `${ZP.fmt.money(d.amount)} left your account`, icon: 'bank', sound: false });
    });
    ZP.onPush('invoice', (d, mute) => {
        if (!store.invoices.some(i => i.id === d.id)) store.invoices.unshift({ id: d.id, amount: d.amount, society: d.society, sender: d.sender, candecline: true, reason: d.reason || '' });
        ZP.setBadge('bank', store.invoices.length);
        ZP.emit('bank', store);
        if (!mute) ZP.notify({ app: 'bank', title: 'New invoice', text: `${ZP.fmt.money(d.amount)} from ${(SOCIETY[d.society] || [d.society])[0]}`, icon: 'bank' });
    });
    ZP.onPush('cryptoTx', () => {});

    // ------------------------------------------------------------------ panels

    function walletPanel(goto) {
        const el = h('div.panel');
        const draw = () => {
            ZP.clear(el);
            el.appendChild(h('div.bcard',
                h('div.bc-top', h('span.bc-brand', icon('bank'), 'Ze Bank'), h('span.bc-chip')),
                h('div.bc-label', 'Balance'),
                h('div.bc-amount', ZP.fmt.money(store.bank)),
                h('div.bc-bottom', h('div', h('div.bc-name', state.me.name), h('button.bc-acc', { type: 'button', onclick: () => store.account && ZP.copy(store.account), title: 'Copy' }, store.account || '-', icon('copy'))))));
            el.appendChild(h('div.btiles',
                h('div.btile', icon('wallet'), h('div', h('small', 'Cash'), h('b', ZP.fmt.money(store.cash)))),
                h('div.btile', icon('coins'), h('div', h('small', 'Crypto'), h('b', (Number(store.crypto) || 0).toFixed(2) + ' Qbit')))));
            el.appendChild(h('div.cactions',
                circle('arrow-up-right', 'Send', () => goto('transfer')),
                circle('arrow-down-left', 'Receive', () => ui.dialog({ title: 'Your account', text: store.account || '-', buttons: [{ label: 'Close', value: null }, { label: 'Copy', value: 'copy', kind: 'primary' }] }).then(v => { if (v === 'copy') ZP.copy(store.account); })),
                circle('file', 'Invoices', () => goto('invoices'))));
            el.appendChild(h('div.glabel', 'Recent activity'));
            if (!store.history.length) el.appendChild(h('div.gcard', h('div.pad-empty', 'No transfers yet')));
            else el.appendChild(h('div.gcard', store.history.map(t => ui.row({
                lead: h('div.rico', { style: { '--c': t.kind === 'in' ? '#1f9d72' : '#c43b56' } }, icon(t.kind === 'in' ? 'arrow-down-left' : 'arrow-up-right')),
                title: (SOCIETY[t.other] || [t.other])[0] || 'Transfer', sub: [t.note, ZP.fmt.short(t.ts)].filter(Boolean).join(' · '),
                right: h('b', { class: t.kind === 'in' ? 'plus' : 'minus' }, (t.kind === 'in' ? '+' : '-') + ZP.fmt.money(t.amount)),
            }))));
        };
        return { el, draw };
    }

    const circle = (ic, label, onclick) => h('button.caction', { type: 'button', onclick }, h('span.cico', icon(ic)), h('span', label));

    function transferPanel(ctx, pre) {
        const el = h('div.panel');
        const to = ui.field({ label: 'Recipient account', placeholder: 'Account number', max: 40, value: pre && pre.iban || '' });
        const amount = ui.field({ label: 'Amount', placeholder: '0', max: 9, inputmode: 'numeric', prefix: '$' });
        const note = ui.field({ label: 'Note (optional)', placeholder: 'What is it for?', max: 120 });
        const who = h('div.bwho', { hidden: true });
        const pick = ui.btn({ text: 'Choose from contacts', icon: 'users', kind: 'ghost', small: true, onclick: async () => {
            const c = await ui.contactPicker({ title: 'Send money to', filter: c => !!c.iban });
            if (!c) return;
            to.set(c.iban);
            who.hidden = false;
            who.textContent = c.name;
        } });
        const chips = h('div.qchips', [100, 500, 1000, 5000].map(n => h('button.qchip', { type: 'button', onclick: () => amount.set(String(n)) }, '$' + n.toLocaleString('en-US'))));
        const send = ui.btn({ text: 'Send money', icon: 'send', block: true, onclick: async () => {
            const n = Math.floor(Number(String(amount.value()).replace(/\D/g, '')));
            if (!to.value().trim()) return ui.toast('Enter the account number');
            if (!n || n < 1) return ui.toast('Enter an amount');
            if (n > store.bank) return ui.toast('You do not have enough money', 'error');
            const name = who.hidden ? to.value().trim() : who.textContent;
            if (!await ui.confirm({ title: `Send ${ZP.fmt.money(n)}?`, text: `To ${name}`, ok: 'Send' })) return;
            send.disabled = true;
            const res = await ZP.api('bank:transfer', { to: to.value(), amount: n, note: note.value() });
            send.disabled = false;
            if (res.error) return ui.toast(res.error, 'error');
            store.bank = res.bank;
            state.player.money.bank = res.bank;
            addHistory('out', n, res.to || name, note.value().trim());
            ZP.emit('bank', store);
            amount.set(''); note.set(''); to.set(''); who.hidden = true;
            ui.toast(`Sent ${ZP.fmt.money(n)} to ${res.to || name}`);
        } });
        to.input.addEventListener('input', () => { who.hidden = true; });
        el.appendChild(h('div.form', to.el, who, pick, amount.el, chips, note.el, send));
        if (pre && pre.name) { who.hidden = false; who.textContent = pre.name; }
        return { el };
    }

    function invoicesPanel(ctx) {
        const el = h('div.panel');
        const list = h('div.ilist');
        const draw = () => {
            ZP.clear(list);
            if (!store.invoices.length) { list.appendChild(ui.empty({ icon: 'file', title: 'No invoices', text: 'Fines and bills sent to you show up here.' })); return; }
            store.invoices.forEach((inv) => {
                const [label, color] = SOCIETY[inv.society] || [inv.society || 'Invoice', '#ff7a1a'];
                list.appendChild(h('div.inv',
                    h('div.inv-top', h('div.rico', { style: { '--c': color } }, icon('file')), h('div.inv-who', h('b', label), h('span', `From ${inv.sender || 'unknown'}`)), h('div.inv-amt', ZP.fmt.money(inv.amount))),
                    inv.reason ? h('div.inv-reason', inv.reason) : null,
                    h('div.inv-btns',
                        ui.btn({ text: 'Pay', icon: 'check', kind: 'primary', small: true, onclick: async (e) => {
                            e.currentTarget.disabled = true;
                            const res = await ZP.api('invoices:pay', { id: inv.id });
                            if (res.error) { ui.toast(res.error, 'error'); draw(); return; }
                            store.bank = res.bank; state.player.money.bank = res.bank;
                            store.invoices = store.invoices.filter(i => i.id !== inv.id);
                            addHistory('out', inv.amount, inv.society, 'Invoice');
                            ZP.setBadge('bank', store.invoices.length);
                            ZP.emit('bank', store);
                            ui.toast(`Paid ${ZP.fmt.money(inv.amount)}`);
                        } }),
                        inv.candecline ? ui.btn({ text: 'Decline', kind: 'danger', small: true, onclick: async () => {
                            if (!await ui.confirm({ title: 'Decline this invoice?', ok: 'Decline', danger: true })) return;
                            const res = await ZP.api('invoices:decline', { id: inv.id });
                            if (res.error) return ui.toast(res.error, 'error');
                            store.invoices = store.invoices.filter(i => i.id !== inv.id);
                            ZP.setBadge('bank', store.invoices.length);
                            ZP.emit('bank', store);
                        } }) : h('span.cant', 'Cannot be declined'))));
            });
        };
        el.appendChild(list);
        if (state.player.job && state.player.job.canBill) {
            el.appendChild(ui.btn({ text: 'Send an invoice', icon: 'plus', kind: 'ghost', block: true, onclick: async () => {
                const target = await ui.nearbyPicker({ title: 'Bill who?' });
                if (!target) return;
                const amount = ui.field({ label: 'Amount', prefix: '$', inputmode: 'numeric', max: 7, autofocus: true });
                const reason = ui.field({ label: 'Reason', max: 120, placeholder: 'What is it for?' });
                const sheet = ui.sheet({ title: `Invoice for ${target.name}`, build: (body) => {
                    body.appendChild(h('div.form', amount.el, reason.el, ui.btn({ text: 'Send invoice', icon: 'send', block: true, onclick: async () => {
                        const res = await ZP.api('invoices:create', { id: target.id, amount: Number(String(amount.value()).replace(/\D/g, '')), reason: reason.value() });
                        if (res.error) return ui.toast(res.error, 'error');
                        sheet.close();
                        ui.toast('Invoice sent');
                    } })));
                } });
            } }));
        }
        return { el, draw };
    }

    // ------------------------------------------------------------------ app

    ZP.registerApp({
        id: 'bank', name: 'Bank', icon: 'bank', colors: ['#b69cff', '#7a56f0'],
        mount(ctx, params) {
            syncMoney();
            const panes = {};
            const holder = h('div.panels');
            const goto = (id) => tabs.select(id);
            const wallet = walletPanel(goto), transfer = transferPanel(ctx, params.pay), invoices = invoicesPanel(ctx);
            panes.wallet = wallet.el; panes.transfer = transfer.el; panes.invoices = invoices.el;
            Object.keys(panes).forEach((k) => { const w = h('div.pwrap', { hidden: true }, panes[k]); holder.appendChild(w); panes[k] = w; });

            const tabs = ui.tabbar([
                { id: 'wallet', icon: 'wallet', label: 'Wallet' },
                { id: 'transfer', icon: 'send', label: 'Transfer' },
                { id: 'invoices', icon: 'file', label: 'Invoices' },
            ], 'wallet', (id) => show(id));
            const titles = { wallet: 'Bank', transfer: 'Transfer', invoices: 'Invoices' };
            const root = ui.view({ title: 'Bank', large: true, root: true, body: holder, footer: tabs.el, className: 'nopad' });
            const show = (id) => {
                Object.keys(panes).forEach(k => { panes[k].hidden = k !== id; });
                root.setTitle(titles[id]);
                root.body.scrollTop = 0;
            };
            ctx.push(root);

            const redraw = () => { wallet.draw(); invoices.draw(); tabs.badge('invoices', store.invoices.length); };
            ctx.on('bank', () => { if (!ctx.dead) redraw(); });
            redraw();
            show(params.pay ? 'transfer' : 'wallet');
            if (params.pay) tabs.select('transfer');

            ZP.api('bank:overview').then((res) => {
                if (ctx.dead || res.error) return;
                Object.assign(store, { cash: res.cash, bank: res.bank, crypto: res.crypto, account: res.account, history: res.history });
                state.player.money = { cash: res.cash, bank: res.bank, crypto: res.crypto };
                redraw();
            });
            ZP.api('invoices:list').then((res) => {
                if (ctx.dead || res.error) return;
                store.invoices = res.invoices || [];
                ZP.setBadge('bank', store.invoices.length);
                redraw();
            });
        },
    });
})();
