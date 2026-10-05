/* Services: who is on duty right now (police, ambulance, mechanics, ...), one tap to call or message. */

(() => {
    'use strict';

    const { h, icon } = ZP;
    const ui = ZP.ui;

    ZP.registerApp({
        id: 'services', name: 'Services', icon: 'briefcase', colors: ['#4dd6ff', '#1b9ad6'],
        mount(ctx) {
            const holder = h('div.svc', ui.loading());
            const load = () => ZP.api('services:list').then((res) => {
                if (ctx.dead) return;
                ZP.clear(holder);
                if (res.error) { holder.appendChild(ui.empty({ icon: 'alert', title: 'Could not load', text: res.error })); return; }
                (res.groups || []).forEach((g) => {
                    const rows = g.members.length ? g.members.map(m => ui.row({
                        avatar: ui.avatar({ name: m.name, src: m.picture, size: 'sm' }), title: m.name, sub: ZP.fmt.number(m.number),
                        right: h('div.svc-btns', ui.iconBtn('message', () => ZP.shell.openApp('messages', { chat: m.number }), { title: 'Message', kind: 'fill' }), ui.iconBtn('phone', () => ZP.calls.start(m.number), { title: 'Call', kind: 'fill' })),
                    })) : h('div.pad-empty', 'Nobody on duty');
                    holder.appendChild(h('div.group',
                        h('div.sgroup', h('span.sg-ico', { style: { '--c': g.color } }, icon(g.icon || 'briefcase')), h('b', g.label), ui.chip(String(g.members.length), g.members.length ? 'ok' : null)),
                        h('div.gcard', rows)));
                });
            });
            ctx.push(ui.view({ title: 'Services', large: true, root: true, body: holder, actions: [ui.iconBtn('refresh', load, { title: 'Refresh' })] }));
            load();
        },
    });
})();
