/* Houses (qb-houses): your houses with their key holders, the keys you hold, GPS, and handing a house to someone else. */

(() => {
    'use strict';

    const { h, icon } = ZP;
    const ui = ZP.ui;
    const state = ZP.state;

    const hasGarage = (g) => !!g && (Array.isArray(g) ? g.length > 0 : Object.keys(g).length > 0);
    const enterOf = (key) => key && key.HouseData && key.HouseData.coords && key.HouseData.coords.enter;

    function houseView(ctx, house, keys, reload) {
        const holders = (house.keyholders || []).filter(Boolean);
        const gps = (keys || []).find(k => k.HouseData && k.HouseData.adress === house.label);
        const body = h('div.cardbody');
        const view = ui.view({ title: house.label, body });
        const draw = () => {
            ZP.clear(body);
            body.appendChild(h('div.chead', h('div.hico', icon('home')), h('div.cname', house.label), h('div.cchips', ui.chip(`Tier ${house.tier}`, 'accent'), ui.chip(hasGarage(house.garage) ? 'Garage' : 'No garage', hasGarage(house.garage) ? 'ok' : null, 'car'))));
            const e = enterOf(gps);
            body.appendChild(ui.btn({ text: 'Set GPS', icon: 'navigation', block: true, onclick: () => { if (e) ZP.post('waypoint', { x: e.x, y: e.y, label: house.label }); else ui.toast('No location for this house'); } }));

            body.appendChild(h('div.glabel', `Key holders (${holders.length})`));
            body.appendChild(h('div.gcard', holders.length ? holders.map((k) => {
                const me = k.citizenid === state.me.citizenid;
                const name = `${k.charinfo.firstname} ${k.charinfo.lastname}`;
                return ui.row({
                    avatar: ui.avatar({ name, size: 'sm' }), title: name + (me ? ' (you)' : ''),
                    right: me ? null : ui.iconBtn('trash', async () => {
                        if (!await ui.confirm({ title: 'Take the key back?', text: name, ok: 'Remove', danger: true })) return;
                        await ZP.post('houses:removeKey', { house: house.name, holder: { citizenid: k.citizenid, firstname: k.charinfo.firstname, lastname: k.charinfo.lastname } });
                        house.keyholders = holders.filter(x => x.citizenid !== k.citizenid);
                        view.el.querySelector('.cardbody') && ctx.pop();
                        ui.toast('Key removed');
                        reload();
                    }, { kind: 'danger', size: 'sm' }),
                });
            }) : h('div.pad-empty', 'Only you have a key')));

            body.appendChild(h('div.gcard', ui.row({
                icon: 'key', color: '#c63fb0', title: 'Transfer ownership', sub: 'Give this house to another citizen', chevron: true,
                onclick: async () => {
                    const cid = await ui.prompt({ title: 'Transfer house', text: 'Enter the citizen ID of the new owner.', placeholder: 'ABC12345', max: 20, ok: 'Continue' });
                    if (!cid || !cid.trim()) return;
                    if (!await ui.confirm({ title: 'Give away this house?', text: `${house.label} goes to ${cid.trim().toUpperCase()}. You cannot undo this.`, ok: 'Transfer', danger: true })) return;
                    const res = await ZP.post('houses:transfer', { citizenid: cid.trim(), house: house.name });
                    if (res && res.error) return ui.toast(res.error, 'error');
                    ui.toast('House transferred');
                    ctx.pop();
                    reload();
                },
            })));
        };
        draw();
        ctx.push(view);
    }

    ZP.registerApp({
        id: 'houses', name: 'Houses', icon: 'home', colors: ['#6ee06e', '#2aa84a'],
        mount(ctx) {
            const panes = { houses: h('div.panel', { hidden: true }), keys: h('div.panel', { hidden: true }) };
            const holder = h('div.panels', Object.values(panes).map(p => h('div.pwrap', p)));
            const tabs = ui.tabbar([{ id: 'houses', icon: 'home', label: 'My houses' }, { id: 'keys', icon: 'key', label: 'Keys' }], 'houses', (id) => show(id));
            const root = ui.view({ title: 'Houses', large: true, root: true, body: holder, footer: tabs.el, className: 'nopad' });
            const show = (id) => { Object.keys(panes).forEach(k => { panes[k].hidden = k !== id; }); root.setTitle(id === 'houses' ? 'Houses' : 'Keys'); };
            ctx.push(root);

            let data = { houses: [], keys: [] };
            const draw = () => {
                ZP.clear(panes.houses);
                ZP.clear(panes.keys);
                if (!data.houses.length) panes.houses.appendChild(ui.empty({ icon: 'home', title: 'No houses', text: 'Houses you own show up here.' }));
                else panes.houses.appendChild(h('div.gcard', data.houses.map(hs => ui.row({
                    lead: h('div.rico', { style: { '--c': '#2aa84a' } }, icon('home')), title: hs.label, sub: `Tier ${hs.tier} · ${(hs.keyholders || []).length} key${(hs.keyholders || []).length === 1 ? '' : 's'}`,
                    right: hasGarage(hs.garage) ? icon('car') : null, chevron: true, onclick: () => houseView(ctx, hs, data.keys, load),
                }))));
                if (!data.keys.length) panes.keys.appendChild(ui.empty({ icon: 'key', title: 'No keys', text: 'Keys to houses are listed here.' }));
                else panes.keys.appendChild(h('div.gcard', data.keys.map(k => ui.row({
                    lead: h('div.rico', { style: { '--c': '#c63fb0' } }, icon('key')), title: k.HouseData.adress, sub: 'Tap to set your GPS',
                    onclick: () => { const e = enterOf(k); if (e) ZP.post('waypoint', { x: e.x, y: e.y, label: k.HouseData.adress }); },
                }))));
            };
            const load = () => {
                ZP.post('houses:list').then((res) => {
                    if (ctx.dead) return;
                    data = { houses: (res && res.houses) || [], keys: (res && res.keys) || [] };
                    draw();
                });
            };
            panes.houses.appendChild(ui.loading());
            show('houses');
            load();
        },
    });
})();
