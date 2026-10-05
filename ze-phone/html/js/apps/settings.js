/* Settings: profile, connectivity (airplane, do not disturb, silent, hidden number), wallpaper and accent, sounds,
   notifications per app, blocked numbers, key bindings, about. Everything is saved through ZP.saveSettings. */

(() => {
    'use strict';

    const { h, icon } = ZP;
    const ui = ZP.ui;
    const state = ZP.state;

    const swatch = (css, label, on, onclick, extra) => h('button.wp' + (on ? '.on' : ''), { type: 'button', onclick },
        h('span.wp-img', { style: { backgroundImage: css } }, on ? h('span.wp-check', icon('check')) : null), h('span.wp-label', label), extra);

    // ------------------------------------------------------------------ screens

    function profileView(ctx) {
        const body = h('div.cardbody');
        const view = ui.view({ title: 'Profile', body });
        const draw = () => {
            ZP.clear(body);
            const me = state.me;
            const pic = state.settings.profilepicture;
            body.appendChild(h('div.chead',
                ui.avatar({ name: me.name, src: pic === 'default' ? null : pic, size: 'xl' }),
                h('div.cname', me.name),
                h('div.csub', ZP.fmt.number(me.number))));
            body.appendChild(h('div.gcard',
                ui.row({
                    icon: 'camera', color: '#ff7a1a', title: 'Change photo', chevron: true,
                    onclick: async () => {
                        const url = await ui.photoPicker({ title: 'Profile photo' });
                        if (url) { ZP.saveSettings({ profilepicture: url }); draw(); }
                    },
                }),
                pic !== 'default' ? ui.row({ icon: 'user', color: '#6f6963', title: 'Use the default photo', onclick: () => { ZP.saveSettings({ profilepicture: 'default' }); draw(); } }) : null));
            body.appendChild(h('div.gcard',
                ui.row({ icon: 'phone', color: '#17a673', title: ZP.fmt.number(me.number), sub: 'Phone number', right: icon('copy'), onclick: () => ZP.copy(me.number) }),
                ui.row({ icon: 'bank', color: '#7a56f0', title: me.account || '-', sub: 'Bank account', right: icon('copy'), onclick: () => me.account && ZP.copy(me.account) })));
        };
        draw();
        ctx.push(view);
    }

    function displayView(ctx) {
        const body = h('div.cardbody');
        const view = ui.view({ title: 'Wallpaper & style', body });
        const draw = () => {
            ZP.clear(body);
            const s = state.settings;
            const custom = !state.ui.wallpapers.some(w => w.id === s.background);
            body.appendChild(h('div.glabel', 'Wallpaper'));
            body.appendChild(h('div.wpgrid',
                state.ui.wallpapers.map(w => swatch(w.css, w.label, s.background === w.id, () => { ZP.saveSettings({ background: w.id }); draw(); })),
                custom && ZP.safeUrl(s.background) ? swatch(`url("${s.background}")`, 'Yours', true, () => {}) : null));
            body.appendChild(h('div.gcard',
                ui.row({
                    icon: 'image', color: '#c63fb0', title: 'Use a photo', chevron: true,
                    onclick: async () => {
                        const url = await ui.photoPicker({ title: 'Wallpaper', allowCamera: false });
                        if (url) { ZP.saveSettings({ background: url }); draw(); }
                    },
                })));

            body.appendChild(h('div.glabel', 'Accent colour'));
            body.appendChild(h('div.accents', [
                ...state.ui.accents.map(c => h('button.acc' + ((s.accent || state.ui.accent) === c ? '.on' : ''), { type: 'button', style: { '--c': c }, onclick: () => { ZP.saveSettings({ accent: c === state.ui.accent ? false : c }); draw(); } }, (s.accent || state.ui.accent) === c ? icon('check') : null)),
            ]));

            body.appendChild(h('div.glabel', 'Brightness'));
            const slider = ui.slider({ min: 30, max: 100, value: s.brightness || 100, icons: ['sun', 'sun'], onInput: (v) => ZP.saveSettings({ brightness: v }) });
            body.appendChild(h('div.gcard.pad', slider.el));
        };
        draw();
        ctx.push(view);
    }

    function soundsView(ctx) {
        const body = h('div.cardbody');
        const view = ui.view({ title: 'Sounds', body });
        const draw = () => {
            ZP.clear(body);
            const s = state.settings;
            const silent = ui.toggle(s.silent, (on) => { ZP.saveSettings({ silent: on }); });
            body.appendChild(h('div.gcard', ui.row({ icon: 'volume-off', color: '#6f6963', title: 'Silent', sub: 'No ringtone and no message tones', right: silent.el, onclick: () => silent.el.click() })));

            body.appendChild(h('div.glabel', 'Ringtone'));
            body.appendChild(h('div.gcard', state.ui.ringtones.map(t => ui.row({
                title: t.label, right: s.ringtone === t.id ? icon('check', 'accent') : null,
                onclick: () => { ZP.saveSettings({ ringtone: t.id }); ZP.sound('previewRing', t.id); draw(); },
            }))));

            body.appendChild(h('div.glabel', 'Message tone'));
            body.appendChild(h('div.gcard', state.ui.texttones.map(t => ui.row({
                title: t.label, right: s.texttone === t.id ? icon('check', 'accent') : null,
                onclick: () => { ZP.saveSettings({ texttone: t.id }); ZP.sound('previewText', t.id); draw(); },
            }))));
        };
        draw();
        ctx.push(view);
    }

    const NOTIFYING = ['phone', 'messages', 'mail', 'twitter', 'bank', 'crypto', 'ads', 'racing', 'mdt'];

    function notificationsView(ctx) {
        const body = h('div.cardbody');
        const view = ui.view({ title: 'Notifications', body });
        const draw = () => {
            ZP.clear(body);
            const s = state.settings;
            const dnd = ui.toggle(s.dnd, (on) => ZP.saveSettings({ dnd: on }));
            body.appendChild(h('div.gcard', ui.row({ icon: 'moon', color: '#7a56f0', title: 'Do not disturb', sub: 'No banners or sounds. Calls come as missed calls.', right: dnd.el, onclick: () => dnd.el.click() })));
            body.appendChild(h('div.glabel', 'Allow notifications from'));
            const rows = state.ui.apps.filter(a => NOTIFYING.includes(a.id) && ZP.apps[a.id]).map((a) => {
                const def = ZP.apps[a.id];
                const sw = ui.toggle(!(s.muted && s.muted[a.id]), (on) => {
                    const muted = Object.assign({}, state.settings.muted);
                    if (on) delete muted[a.id]; else muted[a.id] = true;
                    ZP.saveSettings({ muted });
                });
                return ui.row({ lead: h('div.mini-ico.small', { style: { '--a1': def.colors[0], '--a2': def.colors[1] } }, icon(def.icon)), title: def.name, right: sw.el, onclick: () => sw.el.click() });
            });
            body.appendChild(h('div.gcard', rows));
        };
        draw();
        ctx.push(view);
    }

    function blockedView(ctx) {
        const body = h('div.cardbody');
        const view = ui.view({ title: 'Blocked numbers', body });
        const draw = () => {
            ZP.clear(body);
            if (!state.blocked.length) {
                body.appendChild(ui.empty({ icon: 'ban', title: 'Nobody is blocked', text: 'Block a number from its contact card or from Recents.' }));
                return;
            }
            body.appendChild(h('div.gcard', state.blocked.map(n => ui.row({
                avatar: ui.avatar({ name: ZP.contacts.nameOf(n), size: 'sm' }), title: ZP.contacts.nameOf(n), sub: ZP.fmt.number(n),
                right: ui.btn({ text: 'Unblock', kind: 'soft', small: true, onclick: async () => {
                    const res = await ZP.api('contacts:block', { number: n, on: false });
                    if (res.error) return ui.toast(res.error, 'error');
                    state.blocked = state.blocked.filter(x => x !== n);
                    draw();
                } }),
            }))));
        };
        draw();
        ctx.push(view);
    }

    function keysView(ctx) {
        const k = state.ui.keys || {};
        const body = h('div.cardbody',
            h('div.gcard',
                ui.row({ icon: 'phone', color: '#17a673', title: 'Open the phone', right: h('kbd', k.open || 'M') }),
                ui.row({ icon: 'phone', color: '#17a673', title: 'Answer a call', sub: 'While the phone is in your pocket', right: h('kbd', k.answer || 'Y') }),
                ui.row({ icon: 'phone', color: '#e0314f', title: 'Hang up or decline', right: h('kbd', k.hangup || 'N') })),
            h('div.hint', 'Change these in the game: Settings, Key Bindings, FiveM.'));
        ctx.push(ui.view({ title: 'Key bindings', body }));
    }

    function aboutView(ctx) {
        const me = state.me;
        const body = h('div.cardbody',
            h('div.chead', h('div.logo', icon('phone')), h('div.cname', 'Ze Phone'), h('div.csub', 'Version 1.0')),
            h('div.gcard',
                ui.row({ title: 'Name', right: me.name }),
                ui.row({ title: 'Phone number', right: ZP.fmt.number(me.number), onclick: () => ZP.copy(me.number) }),
                ui.row({ title: 'Serial number', right: me.serial ? 'ZE-' + me.serial : '-', onclick: () => me.serial && ZP.copy('ZE-' + me.serial) }),
                ui.row({ title: 'Bank account', right: me.account || '-', onclick: () => me.account && ZP.copy(me.account) }),
                ui.row({ title: 'Citizen ID', right: me.citizenid || '-', onclick: () => me.citizenid && ZP.copy(me.citizenid) })));
        ctx.push(ui.view({ title: 'About', body }));
    }

    // ------------------------------------------------------------------ app

    ZP.registerApp({
        id: 'settings', name: 'Settings', icon: 'settings', colors: ['#9a948e', '#4e4945'],
        mount(ctx) {
            const body = h('div.settings');
            const draw = () => {
                ZP.clear(body);
                const s = state.settings, me = state.me;

                body.appendChild(h('div.gcard', ui.row({
                    avatar: ui.avatar({ name: me.name, src: s.profilepicture === 'default' ? null : s.profilepicture, size: 'md' }),
                    title: me.name, sub: ZP.fmt.number(me.number), chevron: true, onclick: () => profileView(ctx),
                })));

                const sw = (key) => ui.toggle(s[key], (on) => { ZP.saveSettings({ [key]: on }); });
                const air = sw('airplane'), dnd = sw('dnd'), anon = sw('anonymous');
                body.appendChild(h('div.gcard',
                    ui.row({ icon: 'plane', color: '#f59e0b', title: 'Airplane mode', right: air.el, onclick: () => air.el.click() }),
                    ui.row({ icon: 'moon', color: '#7a56f0', title: 'Do not disturb', right: dnd.el, onclick: () => dnd.el.click() }),
                    ui.row({ icon: 'eye-off', color: '#6f6963', title: 'Hide my number', sub: 'On calls you start', right: anon.el, onclick: () => anon.el.click() })));

                body.appendChild(h('div.gcard',
                    ui.row({ icon: 'palette', color: '#c63fb0', title: 'Wallpaper & style', chevron: true, onclick: () => displayView(ctx) }),
                    ui.row({ icon: 'volume', color: '#e0314f', title: 'Sounds', chevron: true, onclick: () => soundsView(ctx) }),
                    ui.row({ icon: 'bell', color: '#ff7a1a', title: 'Notifications', chevron: true, onclick: () => notificationsView(ctx) }),
                    ui.row({ icon: 'grid', color: '#4a8cff', title: 'Reset the home screen', chevron: true, onclick: async () => {
                        if (!await ui.confirm({ title: 'Reset the home screen?', text: 'Apps go back to their original order.', ok: 'Reset' })) return;
                        ZP.saveSettings({ order: [] });
                        ZP.shell.renderHome();
                        ui.toast('Home screen reset');
                    } })));

                body.appendChild(h('div.gcard',
                    ui.row({ icon: 'ban', color: '#e0314f', title: 'Blocked numbers', right: state.blocked.length ? String(state.blocked.length) : null, chevron: true, onclick: () => blockedView(ctx) }),
                    ui.row({ icon: 'key', color: '#6f6963', title: 'Key bindings', chevron: true, onclick: () => keysView(ctx) }),
                    ui.row({ icon: 'info', color: '#38bdf8', title: 'About', chevron: true, onclick: () => aboutView(ctx) })));
            };
            ctx.on('settings', () => { if (ctx.depth === 1) draw(); });
            draw();
            const root = ui.view({ title: 'Settings', large: true, root: true, body });
            root.onShow = draw;
            ctx.push(root);
        },
    });
})();
