/* MDT (police): live alerts with GPS, people, vehicles (and a plate scan of the closest car) and houses. The server checks the
   job on every search; this app is only on the home screen for the jobs in Config.MDT. */

(() => {
    'use strict';

    const { h, icon } = ZP;
    const ui = ZP.ui;
    const state = ZP.state;

    const alerts = [];
    const EMERGENCY = /assist|panic|officer down|10-13|shots fired|officer needs/i;

    ZP.onPush('policeAlert', (a, mute) => {
        const entry = { id: ZP.uid(), title: a.title, description: a.description, coords: a.coords, ts: Date.now(), emergency: EMERGENCY.test(a.title || '') };
        alerts.unshift(entry);
        if (alerts.length > 40) alerts.length = 40;
        ZP.addBadge('mdt', 1);
        ZP.emit('alerts', alerts);
        if (!mute) ZP.notify({ app: 'mdt', title: a.title, text: a.description, icon: 'shield', sound: entry.emergency ? 'alert' : 'text', force: entry.emergency });
    });

    const plate = (p) => h('span.plate.small', h('span', p));

    // ------------------------------------------------------------------ people

    function personView(ctx, p) {
        const name = `${p.firstname} ${p.lastname}`;
        const vehicles = h('div.gcard', ui.loading());
        const body = h('div.cardbody',
            h('div.chead', ui.avatar({ name, size: 'lg' }), h('div.cname', name), h('div.csub', p.citizenid),
                h('div.cchips', p.record ? ui.chip('Criminal record', 'bad', 'warning') : ui.chip('No record', 'ok', 'check'))),
            h('div.gcard',
                ui.row({ title: 'Date of birth', right: p.birthdate || '-' }),
                ui.row({ title: 'Gender', right: p.gender === 1 ? 'Female' : 'Male' }),
                ui.row({ title: 'Nationality', right: p.nationality || '-' }),
                ui.row({ title: 'Phone', right: p.phone ? ZP.fmt.number(p.phone) : '-', onclick: p.phone ? () => ZP.calls.start(p.phone) : null }),
                ui.row({ title: 'Fingerprint', right: p.fingerprint || '-' })),
            h('div.glabel', 'Licences'),
            h('div.cchips.wrap', ui.chip('Driver', p.driver ? 'ok' : 'bad', p.driver ? 'check' : 'x'), ui.chip('Weapon', p.weapon ? 'ok' : null, p.weapon ? 'check' : 'x'), ui.chip('Business', p.business ? 'ok' : null, p.business ? 'check' : 'x')),
            p.apartment ? h('div.gcard', ui.row({ icon: 'building', color: '#4a8cff', title: p.apartment.label || 'Apartment', sub: 'Tap to set GPS', chevron: true, onclick: () => ZP.post('mdt:apartment', { type: p.apartment.type }) })) : null,
            h('div.glabel', 'Vehicles'),
            vehicles);
        ctx.push(ui.view({ title: name, body }));
        ZP.api('mdt:person', { citizenid: p.citizenid }).then((res) => {
            ZP.clear(vehicles);
            if (res.error) { vehicles.appendChild(h('div.pad-empty', res.error)); return; }
            if (!res.vehicles.length) { vehicles.appendChild(h('div.pad-empty', 'No registered vehicles')); return; }
            res.vehicles.forEach(v => vehicles.appendChild(ui.row({ lead: h('div.rico', { style: { '--c': '#5457e6' } }, icon('car')), title: v.label, right: plate(v.plate) })));
        });
    }

    // ------------------------------------------------------------------ panels

    function searchBox(placeholder, onSearch, extra) {
        const field = ui.search({ placeholder });
        field.input.addEventListener('keydown', (e) => { if (e.key === 'Enter') onSearch(field.value().trim()); });
        const go = ui.btn({ text: 'Search', icon: 'search', small: true, onclick: () => onSearch(field.value().trim()) });
        return h('div.msearch', field.el, go, extra || null);
    }

    function peoplePanel(ctx) {
        const results = h('div.mres');
        const run = async (q) => {
            if (q.length < 2) return ui.toast('Type at least two characters');
            ZP.clear(results);
            results.appendChild(ui.loading('Searching'));
            const res = await ZP.api('mdt:people', { q });
            ZP.clear(results);
            if (res.error) { results.appendChild(ui.empty({ icon: 'alert', title: 'Search failed', text: res.error })); return; }
            if (!res.people.length) { results.appendChild(ui.empty({ icon: 'users', title: 'Nobody found', text: 'Try a name, a phone number or a citizen ID.' })); return; }
            results.appendChild(h('div.gcard', res.people.map(p => ui.row({
                avatar: ui.avatar({ name: `${p.firstname} ${p.lastname}`, size: 'sm' }), title: `${p.firstname} ${p.lastname}`, sub: p.citizenid,
                right: [p.record ? icon('warning', 'miss') : null, !p.driver ? ui.chip('No licence', 'warn') : null], chevron: true,
                onclick: () => personView(ctx, p),
            }))));
        };
        return { el: h('div.panel', searchBox('Name, phone or citizen ID', run), results), run };
    }

    function vehiclesPanel() {
        const results = h('div.mres');
        const show = (list) => {
            ZP.clear(results);
            if (!list.length) { results.appendChild(ui.empty({ icon: 'car', title: 'No vehicles found', text: 'Search a plate or a citizen ID.' })); return; }
            results.appendChild(h('div.vres', list.map(v => h('div.vcard' + (v.flagged ? '.flagged' : ''),
                h('div.vc-top', plate(v.plate), v.flagged ? ui.chip('Flagged', 'bad', 'warning') : null, v.npc ? ui.chip('Unregistered', 'warn') : null),
                h('div.vc-label', v.label),
                h('div.vc-owner', icon('user'), v.owner || 'Unknown owner')))));
        };
        const run = async (q) => {
            if (q.length < 2) return ui.toast('Type at least two characters');
            ZP.clear(results);
            results.appendChild(ui.loading('Searching'));
            const res = await ZP.post('mdt:vehicles', { q });
            if (res && res.error) { ZP.clear(results); results.appendChild(ui.empty({ icon: 'alert', title: 'Search failed', text: res.error })); return; }
            show((res && res.vehicles) || []);
        };
        const scan = ui.btn({ text: 'Scan closest car', icon: 'locate', kind: 'soft', small: true, onclick: async () => {
            ZP.clear(results);
            results.appendChild(ui.loading('Scanning'));
            const res = await ZP.post('mdt:scan');
            if (res && res.error) { ZP.clear(results); results.appendChild(ui.empty({ icon: 'car', title: 'No vehicle', text: res.error })); return; }
            show(res && res.vehicle ? [res.vehicle] : []);
        } });
        return { el: h('div.panel', searchBox('Plate or citizen ID', run), h('div.mscan', scan), results) };
    }

    function housesPanel() {
        const results = h('div.mres');
        const run = async (q) => {
            if (q.length < 2) return ui.toast('Type at least two characters');
            ZP.clear(results);
            results.appendChild(ui.loading('Searching'));
            const res = await ZP.post('mdt:houses', { q });
            ZP.clear(results);
            const houses = (res && res.houses) || [];
            if (!houses.length) { results.appendChild(ui.empty({ icon: 'home', title: 'No houses found', text: 'Search the owner by name or citizen ID.' })); return; }
            results.appendChild(h('div.gcard', houses.map(hs => ui.row({
                lead: h('div.rico', { style: { '--c': '#2aa84a' } }, icon('home')),
                title: hs.label, sub: `${hs.charinfo ? hs.charinfo.firstname + ' ' + hs.charinfo.lastname : 'Owner'} · Tier ${hs.tier}`,
                right: ui.btn({ text: 'GPS', icon: 'navigation', kind: 'soft', small: true, onclick: (e) => { e.stopPropagation(); if (hs.coords) ZP.post('waypoint', { x: hs.coords.x, y: hs.coords.y, label: hs.label }); } }),
            }))));
        };
        return { el: h('div.panel', searchBox('Owner name or citizen ID', run), results) };
    }

    function alertsPanel(ctx) {
        const el = h('div.panel');
        const draw = () => {
            ZP.clear(el);
            if (!alerts.length) { el.appendChild(ui.empty({ icon: 'shield', title: 'No alerts', text: 'Dispatch calls show up here as they come in.' })); return; }
            alerts.forEach((a) => {
                el.appendChild(h('div.alert' + (a.emergency ? '.sos' : ''),
                    h('div.al-top', h('b', a.title), h('span.ttime', ZP.fmt.ago(a.ts))),
                    h('div.al-text', a.description),
                    h('div.al-btns',
                        a.coords ? ui.btn({ text: 'GPS', icon: 'navigation', small: true, onclick: () => ZP.post('waypoint', { x: a.coords.x, y: a.coords.y, label: a.title }) }) : h('span.cant', 'No location'),
                        ui.btn({ text: 'Dismiss', kind: 'ghost', small: true, onclick: () => { alerts.splice(alerts.indexOf(a), 1); draw(); } }))));
            });
        };
        ctx.on('alerts', () => { if (!ctx.dead) draw(); });
        draw();
        return { el, clear: () => { alerts.length = 0; draw(); } };
    }

    ZP.registerApp({
        id: 'mdt', name: 'MDT', icon: 'shield', colors: ['#4a8cff', '#1e4fd6'],
        mount(ctx) {
            const al = alertsPanel(ctx), people = peoplePanel(ctx), veh = vehiclesPanel(), houses = housesPanel();
            const panes = { alerts: al.el, people: people.el, vehicles: veh.el, houses: houses.el };
            const holder = h('div.panels');
            Object.keys(panes).forEach((k) => { const w = h('div.pwrap', { hidden: true }, panes[k]); holder.appendChild(w); panes[k] = w; });
            const tabs = ui.tabbar([
                { id: 'alerts', icon: 'bell', label: 'Alerts' },
                { id: 'people', icon: 'users', label: 'People' },
                { id: 'vehicles', icon: 'car', label: 'Vehicles' },
                { id: 'houses', icon: 'home', label: 'Houses' },
            ], 'alerts', (id) => show(id));
            const titles = { alerts: 'Dispatch', people: 'People', vehicles: 'Vehicles', houses: 'Houses' };
            const clearBtn = ui.iconBtn('trash', () => al.clear(), { title: 'Clear alerts' });
            const root = ui.view({ title: 'Dispatch', large: true, root: true, body: holder, footer: tabs.el, className: 'nopad' });
            const show = (id) => {
                Object.keys(panes).forEach(k => { panes[k].hidden = k !== id; });
                root.setTitle(titles[id]);
                root.setActions(id === 'alerts' ? [clearBtn] : []);
                root.body.scrollTop = 0;
                if (id === 'alerts') ZP.setBadge('mdt', 0);
            };
            ctx.push(root);
            show('alerts');
            ctx.on('alerts', () => { if (!ctx.dead && !panes.alerts.hidden) ZP.setBadge('mdt', 0); });
            ctx.guardMdt = state.player.mdt;
        },
    });
})();
