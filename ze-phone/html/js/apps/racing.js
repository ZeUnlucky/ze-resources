/* Racing (qb-lapraces): open races (join, quit, start), setting up a race from a track, creating a track, last results.
   The checks before joining or setting up (distance to the start, editor busy, ...) run on the game side (client/apps.lua). */

(() => {
    'use strict';

    const { h, icon } = ZP;
    const ui = ZP.ui;
    const state = ZP.state;

    const count = (racers) => (racers && typeof racers === 'object') ? Object.keys(racers).length : 0;
    const hasRacer = (racers, cid) => !!racers && !Array.isArray(racers) && Object.prototype.hasOwnProperty.call(racers, cid);
    const lapLabel = (n) => (n === 0 ? 'Sprint' : n === 1 ? '1 lap' : `${n} laps`);
    const clock = (s) => {
        s = Math.floor(Number(s) || 0);
        const hh = Math.floor(s / 3600), mm = Math.floor((s % 3600) / 60), ss = s % 60;
        return `${hh}:${String(mm).padStart(2, '0')}:${String(ss).padStart(2, '0')}`;
    };

    ZP.onPush('racesChanged', () => ZP.emit('races'));

    function racesPanel(ctx) {
        const el = h('div.panel');
        let races = null;
        const load = () => ZP.post('racing:list').then((res) => { races = (res && res.races) || []; draw(); });
        const act = async (name, race) => {
            const res = await ZP.post('racing:' + name, { race });
            if (res && res.error) ui.toast(res.error, 'error');
            setTimeout(load, 350);
        };
        const draw = () => {
            ZP.clear(el);
            if (races === null) { el.appendChild(ui.loading()); return; }
            if (!races.length) { el.appendChild(ui.empty({ icon: 'flag', title: 'No races right now', text: 'Set one up in the Setup tab.' })); return; }
            races.slice().reverse().forEach((r) => {
                const data = r.RaceData || {};
                const started = !!data.Started;
                const mine = hasRacer(data.Racers, state.me.citizenid);
                const creator = r.SetupCitizenId === state.me.citizenid;
                const buttons = [];
                if (!mine && !started) buttons.push(ui.btn({ text: 'Join', icon: 'log-in', small: true, onclick: () => act('join', r) }));
                if (mine && creator && !started) buttons.push(ui.btn({ text: 'Start', icon: 'flag', small: true, kind: 'ok', onclick: () => act('start', r) }));
                if (mine) buttons.push(ui.btn({ text: 'Quit', icon: 'log-out', small: true, kind: 'danger', onclick: () => act('leave', r) }));
                if (started && !mine) buttons.push(ui.chip('Already started', 'bad', 'lock'));
                el.appendChild(h('div.race' + (started ? '.live' : ''),
                    h('div.race-top', h('b', data.RaceName || 'Race'), ui.chip(started ? 'Started' : 'Open', started ? 'bad' : 'ok')),
                    h('div.race-info', ui.chip(lapLabel(r.Laps), null, 'flag'), ui.chip(`${data.Distance || 0} m`, null, 'navigation'), ui.chip(String(count(data.Racers)), null, 'users')),
                    buttons.length ? h('div.race-btns', buttons) : null));
            });
        };
        ctx.on('races', () => { if (!ctx.dead) load(); });
        draw();
        load();
        return { el, reload: load };
    }

    function setupPanel(ctx) {
        const el = h('div.panel');
        let selected = null;
        const info = h('div.trackinfo');
        const laps = ui.field({ label: 'Laps (0 for a sprint)', value: '3', max: 2, inputmode: 'numeric' });
        const list = h('div.gcard', ui.loading());
        const go = ui.btn({ text: 'Set up this race', icon: 'flag', block: true, onclick: async () => {
            if (!selected) return ui.toast('Pick a track first');
            const res = await ZP.post('racing:setup', { raceId: selected, laps: laps.value() });
            if (res && res.error) return ui.toast(res.error, 'error');
            ui.toast('Race set up. People can join now.');
            ZP.emit('races');
        } });
        const draw = (tracks) => {
            ZP.clear(list);
            if (!tracks.length) { list.appendChild(h('div.pad-empty', 'No tracks are free')); return; }
            tracks.forEach(t => list.appendChild(ui.row({
                lead: h('div.rico', { style: { '--c': selected === t.RaceId ? 'var(--accent)' : '#4a4540' } }, icon(selected === t.RaceId ? 'check' : 'flag')),
                title: t.RaceName,
                onclick: async () => {
                    selected = t.RaceId;
                    draw(tracks);
                    ZP.clear(info);
                    info.appendChild(ui.loading());
                    const res = await ZP.post('racing:track', { raceId: t.RaceId });
                    ZP.clear(info);
                    if (res && res.error) return info.appendChild(h('div.pad-empty', res.error));
                    info.appendChild(h('div.gcard', ui.row({ title: 'Distance', right: `${res.distance} m` }), ui.row({ title: 'Creator', right: res.creator }), ui.row({ title: 'Record', right: res.record ? `${clock(res.record.time)} (${res.record.holder})` : 'N/A' })));
                },
            })));
        };
        el.appendChild(h('div.glabel', 'Track'));
        el.appendChild(list);
        el.appendChild(info);
        el.appendChild(h('div.form', laps.el, go));
        ZP.post('racing:tracks').then((res) => { if (!ctx.dead) draw((res && res.tracks) || []); });
        return { el };
    }

    function createPanel() {
        const name = ui.field({ label: 'Track name', placeholder: 'Midnight loop', max: 40 });
        const go = ui.btn({ text: 'Start the track editor', icon: 'plus', block: true, onclick: async () => {
            if (!name.value().trim()) return ui.toast('You have to enter a track name..');
            const res = await ZP.post('racing:create', { name: name.value() });
            if (res && res.error) return ui.toast(res.error, 'error');
            name.set('');
            ZP.shell.requestClose();
        } });
        return { el: h('div.panel', h('div.hint', 'The editor opens in the game. Only authorised players can make tracks.'), h('div.form', name.el, go)) };
    }

    function boardPanel(ctx) {
        const el = h('div.panel', ui.loading());
        ZP.post('racing:leaderboards').then((res) => {
            if (ctx.dead) return;
            ZP.clear(el);
            const races = (res && res.races) || [];
            if (!races.length) { el.appendChild(ui.empty({ icon: 'trophy', title: 'No results yet', text: 'Finished races show their results here.' })); return; }
            races.forEach((r) => {
                el.appendChild(h('div.group', h('div.glabel', r.name), h('div.gcard', (r.results || []).map((x, i) => {
                    const dnf = x.BestLap === 'DNF';
                    const holder = x.Holder || [];
                    return ui.row({
                        lead: h('div.rank' + (i === 0 && !dnf ? '.gold' : ''), dnf ? '-' : String(i + 1)),
                        title: `${String(holder[0] || '?').charAt(0).toUpperCase()}. ${holder[1] || ''}`, right: dnf ? 'DNF' : clock(x.BestLap),
                    });
                }))));
            });
        });
        return { el };
    }

    ZP.registerApp({
        id: 'racing', name: 'Racing', icon: 'flag', colors: ['#ff6b81', '#c71f45'],
        mount(ctx) {
            const races = racesPanel(ctx), setup = setupPanel(ctx), create = createPanel(), board = boardPanel(ctx);
            const panes = { races: races.el, setup: setup.el, create: create.el, board: board.el };
            const holder = h('div.panels');
            Object.keys(panes).forEach((k) => { const w = h('div.pwrap', { hidden: true }, panes[k]); holder.appendChild(w); panes[k] = w; });
            const tabs = ui.tabbar([
                { id: 'races', icon: 'flag', label: 'Races' },
                { id: 'setup', icon: 'plus-circle', label: 'Setup' },
                { id: 'create', icon: 'edit', label: 'Create' },
                { id: 'board', icon: 'trophy', label: 'Results' },
            ], 'races', (id) => show(id));
            const titles = { races: 'Racing', setup: 'Set up a race', create: 'New track', board: 'Results' };
            const root = ui.view({ title: 'Racing', large: true, root: true, body: holder, footer: tabs.el, className: 'nopad' });
            const show = (id) => { Object.keys(panes).forEach(k => { panes[k].hidden = k !== id; }); root.setTitle(titles[id]); root.body.scrollTop = 0; };
            ctx.push(root);
            show('races');
        },
    });
})();
