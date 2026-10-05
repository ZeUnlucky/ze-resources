/* Maps: where you are (street, area, coordinates, updated while the app is open), places that can be set as GPS, your own
   coordinates, clearing the waypoint. Places come from Config.Places. */

(() => {
    'use strict';

    const { h, icon } = ZP;
    const ui = ZP.ui;

    ZP.registerApp({
        id: 'maps', name: 'Maps', icon: 'pin', colors: ['#5ee09a', '#14a66b'],
        mount(ctx) {
            const here = h('div.here', ui.loading());
            const holder = h('div.places');
            const search = ui.search({ placeholder: 'Search places', onInput: () => draw() });
            let loc = null;

            const drawHere = () => {
                ZP.clear(here);
                if (!loc) { here.appendChild(ui.loading()); return; }
                here.appendChild(h('div.hcard',
                    h('div.h-ico', icon('locate')),
                    h('div.h-main', h('div.h-street', loc.street || 'Unknown road'), h('div.h-sub', [loc.cross, loc.zone].filter(Boolean).join(' · ') || 'Los Santos'), h('div.h-coords', `${loc.x}, ${loc.y}`)),
                    h('div.h-btns', ui.iconBtn('copy', () => ZP.copy(`${loc.x}, ${loc.y}`), { title: 'Copy coordinates', kind: 'fill' }))));
            };

            const draw = () => {
                ZP.clear(holder);
                const needle = search.value().trim().toLowerCase();
                const places = ZP.state.ui.places.filter(p => !needle || p.label.toLowerCase().includes(needle) || p.category.toLowerCase().includes(needle));
                if (!places.length) { holder.appendChild(h('div.pad-empty', 'No places found')); return; }
                const groups = {};
                places.forEach(p => { (groups[p.category] = groups[p.category] || []).push(p); });
                Object.keys(groups).forEach((cat) => {
                    holder.appendChild(h('div.group', h('div.glabel', cat), h('div.gcard', groups[cat].map(p => ui.row({
                        lead: h('div.rico', { style: { '--c': '#14a66b' } }, icon('pin')), title: p.label,
                        right: ui.btn({ text: 'GPS', icon: 'navigation', kind: 'soft', small: true, onclick: (e) => { e.stopPropagation(); ZP.post('waypoint', { x: p.x, y: p.y, label: p.label }); } }),
                        onclick: () => ZP.post('waypoint', { x: p.x, y: p.y, label: p.label }),
                    })))));
                });
            };

            const custom = ui.row({
                icon: 'locate', color: '#4a8cff', title: 'Go to coordinates', sub: 'Type an X and Y', chevron: true,
                onclick: async () => {
                    const text = await ui.prompt({ title: 'Coordinates', text: 'X, Y (for example 215.4, -810.2)', placeholder: '215.4, -810.2', max: 40, ok: 'Set GPS' });
                    if (!text) return;
                    const m = /^\s*(-?\d+(?:\.\d+)?)\s*[, ]\s*(-?\d+(?:\.\d+)?)\s*$/.exec(text);
                    if (!m) return ui.toast('Use two numbers, like 215.4, -810.2', 'error');
                    ZP.post('waypoint', { x: Number(m[1]), y: Number(m[2]), label: 'Custom location' });
                },
            });
            const clear = ui.row({ icon: 'x', color: '#e0314f', title: 'Clear GPS', onclick: () => { ZP.post('waypointClear'); ui.toast('GPS cleared'); } });

            const body = h('div.mapbody', here, h('div.gcard', custom, clear), search.el, holder);
            ctx.push(ui.view({ title: 'Maps', large: true, root: true, body }));
            draw();

            const poll = () => ZP.post('location').then((res) => { if (!ctx.dead && res) { loc = res; drawHere(); } });
            poll();
            const timer = setInterval(poll, 2000);
            ctx.offs.push(() => clearInterval(timer));
        },
    });
})();
