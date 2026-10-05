/* ze-phone NUI entry point: receives what Lua sends and hands it to the shell and the apps.
   init   { ui, boot, player, time }   the first thing after login (and after qb-phone:RefreshPhone)
   open   { player, time, call }       the phone comes up        close { force }
   time   { h, m, day, month, year, weekday }
   player { id, money, job, mdt }      money or job changed
   call   { phase, number, ... }       see calls.js
   camera { on }                       the hint while the game camera is up
   push   { name, data, mute }         everything else (message, mail, tweet, ...): apps listen with ZP.onPush(name, fn)
   reset                               the character logged out */

(() => {
    'use strict';

    const $ = (id) => document.getElementById(id);
    const state = ZP.state;
    let built = false;

    function applyBoot(boot) {
        state.settings = Object.assign({}, ZP.DEFAULT_SETTINGS, boot.settings || {});
        state.me = boot.me || state.me;
        state.blocked = boot.blocked || [];
        state.chats = boot.chats || [];
        state.calls = boot.calls || [];
        state.adverts = boot.adverts || [];
        ZP.contacts.set(boot.contacts || []);
        const u = boot.unread || {};
        ZP.badges = {};
        ['messages', 'mail', 'phone', 'bank'].forEach(k => { if (u[k]) ZP.badges[k] = u[k]; });
        ZP.emit('badges', ZP.badges);
        ZP.emit('boot', boot);
    }

    const handlers = {
        init(d) {
            state.ui = Object.assign({}, state.ui, d.ui || {});
            state.player = d.player || state.player;
            if (d.time) state.time = d.time;
            applyBoot(d.boot || {});
            if (!built) { built = true; ZP.shell.build(); }
            state.ready = true;
            ZP.applySettings();
            ZP.shell.paintStatus();
            ZP.shell.refreshHome();
            ZP.emit('time', state.time);
        },

        reset() {
            state.ready = false;
            ZP.shell.closeApp(true);
            ZP.shell.hide();
        },

        open(d) {
            if (d.player) { state.player = d.player; ZP.shell.refreshHome(); }
            if (d.time) { state.time = d.time; ZP.emit('time', state.time); }
            if (d.call) ZP.calls.onState(d.call);
            ZP.shell.show();
        },

        close() {
            ZP.shell.closeShade();
            ZP.shell.hide();
        },

        time(d) {
            state.time = d;
            ZP.emit('time', d);
        },

        player(d) {
            state.player = d;
            ZP.emit('player', d);
            if (state.ready) ZP.shell.refreshHome();
        },

        call(d) { ZP.calls.onState(d); },

        camera(d) {
            const hint = $('camhint');
            hint.hidden = !(d && d.on);
        },

        push(msg) {
            ZP.emit('push:' + msg.name, msg.data, msg.mute === true);
        },
    };

    window.addEventListener('message', (e) => {
        const m = e.data;
        if (!m || typeof m.action !== 'string') return;
        const fn = handlers[m.action];
        if (!fn) return;
        // push carries name/data/mute next to action, the others carry data
        try { fn(m.action === 'push' ? m : (m.data || {})); } catch (err) { console.error('[ze-phone]', m.action, err); }
    });

    // generic notification from another resource (qb-phone:client:CustomNotification, race news, ...)
    ZP.onPush('notify', (d, mute) => {
        if (mute) return;
        ZP.notify({
            app: d.app, title: d.title || 'Phone', text: d.text,
            icon: d.icon ? ZP.iconFromFa(d.icon) : undefined, color: d.color, timeout: d.timeout,
        });
    });

    // contacts someone shared with us, kept until they are added or dismissed
    ZP.onPush('contactShared', (d, mute) => {
        state.suggestions.unshift(d);
        ZP.emit('suggestions', state.suggestions);
        if (!mute) ZP.notify({ app: 'phone', title: 'New suggested contact', text: d.name, icon: 'user-plus' });
        ZP.addBadge('phone', 1);
    });

    document.addEventListener('contextmenu', (e) => { if (!/^(INPUT|TEXTAREA)$/.test(e.target.tagName)) e.preventDefault(); });

    // tell Lua the page is ready so it can send init
    window.addEventListener('DOMContentLoaded', () => {
        ZP.post('ready');
    });
})();
