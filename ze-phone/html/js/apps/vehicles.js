/* Vehicles (qb-garages): your cars with fuel, engine and body, where they are kept, and a GPS mark for one that is out. */

(() => {
    'use strict';

    const { h, icon } = ZP;
    const ui = ZP.ui;

    const bar = (label, ic, value, color) => {
        const pct = Math.max(0, Math.min(100, Math.round(value)));
        const tone = pct < 25 ? 'var(--danger)' : pct < 55 ? 'var(--warn)' : (color || 'var(--ok)');
        return h('div.vbar2', h('div.vb-top', h('span', icon(ic), label), h('b', pct + '%')), h('div.vb-track', h('i', { style: { width: pct + '%', background: tone } })));
    };

    const stateChip = (s) => {
        const t = String(s || '').toLowerCase();
        if (t.includes('garage')) return ui.chip(s, 'ok', 'home');
        if (t.includes('impound') || t.includes('depot')) return ui.chip(s, 'bad', 'warning');
        if (t.includes('out')) return ui.chip(s, 'warn', 'navigation');
        return ui.chip(s || 'Unknown');
    };

    function detail(ctx, v) {
        const out = String(v.state || '').toLowerCase().includes('out');
        const view = ui.view({
            title: v.fullname || v.model || 'Vehicle',
            body: h('div.cardbody',
                h('div.plate', h('span', v.plate || '--------')),
                h('div.cchips', stateChip(v.state), v.garage ? ui.chip(v.garage, null, 'pin') : null),
                h('div.gcard.pad.bars', bar('Fuel', 'fuel', v.fuel), bar('Engine', 'gauge', v.engine / 10), bar('Body', 'car', v.body / 10)),
                h('div.gcard',
                    ui.row({ title: 'Brand', right: v.brand || '-' }),
                    ui.row({ title: 'Model', right: v.model || '-' }),
                    ui.row({ title: 'Plate', right: v.plate, onclick: () => ZP.copy(v.plate) })),
                ui.btn({ text: out ? 'Locate on the map' : 'Try to locate', icon: 'locate', block: true, kind: out ? 'primary' : 'ghost', onclick: async () => {
                    const res = await ZP.post('vehicles:track', { plate: v.plate });
                    if (res && res.ok) ui.toast('Vehicle marked on your GPS'); else ui.toast('This vehicle cannot be located', 'error');
                } })),
        });
        ctx.push(view);
    }

    ZP.registerApp({
        id: 'vehicles', name: 'Vehicles', icon: 'car', colors: ['#8b8cff', '#5457e6'],
        mount(ctx) {
            const holder = h('div.vlist', ui.loading());
            ctx.push(ui.view({ title: 'Vehicles', large: true, root: true, body: holder }));
            ZP.post('vehicles:list').then((res) => {
                if (ctx.dead) return;
                ZP.clear(holder);
                const list = (res && res.vehicles) || [];
                if (!list.length) { holder.appendChild(ui.empty({ icon: 'car', title: 'No vehicles', text: 'Cars you own appear here.' })); return; }
                holder.appendChild(h('div.gcard', list.map(v => ui.row({
                    lead: h('div.vlet', (v.brand || v.fullname || '?').charAt(0).toUpperCase()),
                    title: v.fullname || v.model, sub: [v.plate, v.garage].filter(Boolean).join(' · '),
                    right: stateChip(v.state), chevron: true, onclick: () => detail(ctx, v),
                }))));
            });
        },
    });
})();
