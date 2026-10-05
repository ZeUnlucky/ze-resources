/* Crypto (qb-crypto): the Qbit price with a chart, buy, sell and transfer, your wallet and its transactions. */

(() => {
    'use strict';

    const { h, icon } = ZP;
    const ui = ZP.ui;
    const state = ZP.state;

    const store = { history: [], worth: 0, portfolio: 0, walletId: '', txs: [], loaded: false };

    ZP.onPush('cryptoTx', (d, mute) => {
        if (!d || !d.message) return;
        store.txs.unshift({ title: d.title, message: d.message, ts: Date.now() });
        ZP.emit('crypto', store);
        if (!mute) ZP.notify({ app: 'crypto', title: 'Crypto', text: d.message, icon: 'coins', sound: false });
    });

    const apply = (res) => {
        store.history = res.history || [];
        store.worth = res.worth;
        store.portfolio = res.portfolio;
        store.walletId = res.walletId;
        store.loaded = true;
        ZP.emit('crypto', store);
    };

    const series = () => {
        const hst = store.history;
        if (!hst.length) return [store.worth, store.worth];
        return [hst[0].PreviousWorth, ...hst.map(x => x.NewWorth)].map(Number);
    };
    const change = () => {
        const last = store.history[store.history.length - 1];
        if (!last || !last.PreviousWorth) return 0;
        return (last.NewWorth - last.PreviousWorth) / last.PreviousWorth * 100;
    };

    // buy / sell / transfer
    function tradeSheet(kind) {
        const coins = ui.field({ label: kind === 'transfer' ? 'Amount (Qbit)' : 'Amount of Qbit', placeholder: '0.0', max: 10, inputmode: 'decimal', autofocus: true });
        const wallet = ui.field({ label: 'Wallet ID', placeholder: 'QB-12345678', max: 20 });
        const info = h('div.tradeinfo');
        const value = () => Math.max(0, parseFloat(String(coins.value()).replace(',', '.')) || 0);
        const paint = () => {
            const c = value();
            if (kind === 'buy') info.textContent = c ? `Costs ${ZP.fmt.money(Math.floor(c * store.worth))} (you have ${ZP.fmt.money(state.player.money.bank)})` : `1 Qbit = ${ZP.fmt.money(store.worth)}`;
            else if (kind === 'sell') info.textContent = c ? `You get ${ZP.fmt.money(Math.floor(c * store.worth))}` : `You own ${Number(store.portfolio).toFixed(4)} Qbit`;
            else info.textContent = `You own ${Number(store.portfolio).toFixed(4)} Qbit`;
        };
        coins.input.addEventListener('input', paint);
        const titles = { buy: 'Buy Qbit', sell: 'Sell Qbit', transfer: 'Transfer Qbit' };
        const go = ui.btn({ text: titles[kind], block: true, onclick: async () => {
            const c = value();
            if (!c) return ui.toast('Enter an amount');
            go.disabled = true;
            const res = await ZP.post('crypto:' + kind, { coins: c, walletId: wallet.value() });
            go.disabled = false;
            if (res && res.error) return ui.toast(res.error, 'error');
            apply(res);
            sheet.close();
            ui.toast(kind === 'buy' ? 'Order filled' : kind === 'sell' ? 'Sold' : 'Transferred');
        } });
        const sheet = ui.sheet({ title: titles[kind], build: (body) => {
            const rows = [coins.el];
            if (kind === 'transfer') rows.unshift(wallet.el);
            if (kind === 'sell') rows.push(ui.btn({ text: 'Sell everything', kind: 'ghost', small: true, onclick: () => { coins.set(String(store.portfolio)); paint(); } }));
            body.appendChild(h('div.form', rows, info, go));
            paint();
        } });
    }

    function marketPanel() {
        const el = h('div.panel');
        const draw = () => {
            ZP.clear(el);
            const ch = change();
            const up = ch >= 0;
            el.appendChild(h('div.cprice',
                h('div.cp-top', h('span.cp-coin', h('i', 'Q'), 'Qbit'), h('span.cp-change' + (up ? '.up' : '.down'), icon(up ? 'trending-up' : 'trending-down'), `${up ? '+' : ''}${ch.toFixed(1)}%`)),
                h('div.cp-worth', ZP.fmt.money(store.worth)),
                h('div.cp-chart', ui.sparkline(series(), { color: up ? 'var(--ok)' : 'var(--danger)' }))));
            el.appendChild(h('div.btiles',
                h('div.btile', icon('coins'), h('div', h('small', 'You own'), h('b', Number(store.portfolio).toFixed(4) + ' Qbit'))),
                h('div.btile', icon('wallet'), h('div', h('small', 'Worth'), h('b', ZP.fmt.money(Math.floor(store.portfolio * store.worth)))))));
            el.appendChild(h('div.trade', ui.btn({ text: 'Buy', icon: 'plus', onclick: () => tradeSheet('buy') }), ui.btn({ text: 'Sell', icon: 'minus', kind: 'ghost', onclick: () => tradeSheet('sell') }), ui.btn({ text: 'Send', icon: 'send', kind: 'ghost', onclick: () => tradeSheet('transfer') })));

            el.appendChild(h('div.glabel', 'Price history'));
            const rows = store.history.slice(-12).reverse().map((x) => {
                const pc = (x.NewWorth - x.PreviousWorth) / (x.PreviousWorth || 1) * 100;
                return ui.row({
                    lead: h('div.rico', { style: { '--c': pc >= 0 ? '#1f9d72' : '#c43b56' } }, icon(pc >= 0 ? 'trending-up' : 'trending-down')),
                    title: `${ZP.fmt.money(x.PreviousWorth)} to ${ZP.fmt.money(x.NewWorth)}`,
                    right: h('b', { class: pc >= 0 ? 'plus' : 'minus' }, `${pc >= 0 ? '+' : ''}${pc.toFixed(1)}%`),
                });
            });
            el.appendChild(h('div.gcard', rows.length ? rows : h('div.pad-empty', 'No price changes yet')));
        };
        return { el, draw };
    }

    function walletPanel() {
        const el = h('div.panel');
        const draw = () => {
            ZP.clear(el);
            el.appendChild(h('div.cwallet',
                h('div.cw-label', 'Wallet ID'),
                h('button.cw-id', { type: 'button', onclick: () => store.walletId && ZP.copy(store.walletId) }, store.walletId || '-', icon('copy')),
                h('div.cw-bal', Number(store.portfolio).toFixed(6), h('small', ' Qbit'))));
            el.appendChild(h('div.glabel', 'Transactions'));
            if (!store.txs.length) { el.appendChild(h('div.gcard', h('div.pad-empty', 'No transactions yet'))); return; }
            el.appendChild(h('div.gcard', store.txs.map((t) => {
                const out = /sold|debit|transferred/i.test(t.title);
                return ui.row({ lead: h('div.rico', { style: { '--c': out ? '#c43b56' : '#1f9d72' } }, icon(out ? 'arrow-up-right' : 'arrow-down-left')), title: t.title, sub: t.message });
            })));
        };
        return { el, draw };
    }

    ZP.registerApp({
        id: 'crypto', name: 'Crypto', icon: 'coins', colors: ['#3fe0d0', '#0f9d8e'],
        mount(ctx) {
            const market = marketPanel(), wallet = walletPanel();
            const holder = h('div.panels');
            const panes = { market: h('div.pwrap', { hidden: true }, market.el), wallet: h('div.pwrap', { hidden: true }, wallet.el) };
            Object.values(panes).forEach(p => holder.appendChild(p));
            const tabs = ui.tabbar([{ id: 'market', icon: 'trending-up', label: 'Market' }, { id: 'wallet', icon: 'wallet', label: 'Wallet' }], 'market', (id) => show(id));
            const root = ui.view({ title: 'Crypto', large: true, root: true, body: holder, footer: tabs.el, className: 'nopad' });
            const show = (id) => { Object.keys(panes).forEach(k => { panes[k].hidden = k !== id; }); root.setTitle(id === 'market' ? 'Crypto' : 'Wallet'); root.body.scrollTop = 0; };
            ctx.push(root);
            const draw = () => { market.draw(); wallet.draw(); };
            ctx.on('crypto', () => { if (!ctx.dead) draw(); });
            ctx.on('player', () => { if (!ctx.dead) market.draw(); });
            draw();
            show('market');

            ZP.post('crypto:data').then((res) => {
                if (ctx.dead) return;
                if (res && res.error) { ui.toast(res.error, 'error'); return; }
                apply(res);
            });
            ZP.api('crypto:transactions').then((res) => {
                if (ctx.dead || !res.transactions) return;
                const live = store.txs.filter(t => t.ts > Date.now() - 5000);
                store.txs = live.concat(res.transactions);
                wallet.draw();
            });
        },
    });
})();
