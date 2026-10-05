/* ze-phone call screen. Lua owns the state of a call (client/calls.lua) and sends it as { phase, number, anonymous, picture,
   elapsed } with phase idle | outgoing | incoming | active; when a call ends the same message carries `ended` and `log`.
   Here: the full screen call UI, the pill in the status bar while another app is in front, and the banner for a call that
   comes in while the phone is in the pocket (answer and decline with the keys). */

(() => {
    'use strict';

    const { h, icon } = ZP;
    const ui = ZP.ui;
    const $ = (id) => document.getElementById(id);

    const calls = ZP.calls = {};
    let minimized = false;
    let ticker = null;
    let started = 0;           // Date.now() when the call was answered
    let endedTimer = null;
    let banner = null;

    const who = (c) => (c.anonymous || !c.number) ? 'Unknown number' : ZP.contacts.nameOf(c.number);
    const sub = (c) => (c.anonymous || !c.number) ? 'Hidden number' : (ZP.contacts.byNumber(c.number) ? ZP.fmt.number(c.number) : 'Mobile');

    // ------------------------------------------------------------------ actions

    calls.start = async (number, opts = {}) => {
        number = String(number || '').replace(/\D/g, '');
        if (number.length < 3) { ui.toast('Enter a number'); return false; }
        if (ZP.state.call.phase !== 'idle') { ui.toast('You are already in a call'); return false; }
        if (ZP.state.settings.airplane) { ui.toast('Airplane mode is on'); return false; }
        const res = await ZP.post('call:start', { number, anonymous: opts.anonymous !== undefined ? !!opts.anonymous : !!ZP.state.settings.anonymous });
        if (res && res.error) { ui.toast(res.error, 'error'); return false; }
        return true;
    };
    calls.answer = () => ZP.post('call:answer');
    calls.hangup = () => ZP.post('call:hangup');
    calls.expand = () => { minimized = false; render(); };

    // ------------------------------------------------------------------ drawing

    function stopTicker() { clearInterval(ticker); ticker = null; }

    function tick() {
        const text = ZP.fmt.dur((Date.now() - started) / 1000);
        const t = $('cs-timer'); if (t) t.textContent = text;
        const p = $('sb-call-time'); if (p) p.textContent = text;
    }

    function render() {
        const view = $('callview');
        const c = ZP.state.call;
        const pill = $('sb-call');
        const open = ZP.state.open;

        if (c.phase === 'idle' && !view.dataset.ended) {
            view.hidden = true;
            view.classList.remove('on');
            ZP.clear(view);
            pill.hidden = true;
            hideBanner();
            return;
        }

        // phone in the pocket: a banner for an incoming call, nothing else
        if (!open) {
            view.hidden = true;
            if (c.phase === 'incoming') showBanner(c); else hideBanner();
            return;
        }
        hideBanner();

        pill.hidden = !(c.phase === 'active' && minimized);
        if (c.phase === 'active' && minimized) { view.hidden = true; view.classList.remove('on'); return; }

        const ended = view.dataset.ended;
        ZP.clear(view);
        const name = who(c);
        const label = ended ? ended : { outgoing: 'Calling', incoming: 'Incoming call', active: 'In call' }[c.phase] || '';
        const ringing = c.phase === 'incoming' || c.phase === 'outgoing';

        const actions = [];
        if (!ended) {
            if (c.phase === 'incoming') {
                actions.push(
                    h('div.cs-act', h('button.cs-btn.red', { onclick: calls.hangup, title: 'Decline' }, icon('phone', 'hang')), h('span', 'Decline')),
                    h('div.cs-act', h('button.cs-btn.green', { onclick: calls.answer, title: 'Answer' }, icon('phone')), h('span', 'Answer')));
            } else {
                if (c.phase === 'active') actions.push(h('div.cs-act', h('button.cs-btn.glass', { onclick: () => { minimized = true; render(); }, title: 'Minimise' }, icon('chevron-down')), h('span', 'Minimise')));
                actions.push(h('div.cs-act', h('button.cs-btn.red', { onclick: calls.hangup, title: 'Hang up' }, icon('phone', 'hang')), h('span', c.phase === 'outgoing' ? 'Cancel' : 'End')));
            }
        }

        view.appendChild(h('div.callscreen' + (ended ? '.over' : ''),
            h('div.cs-glow'),
            h('div.cs-top', label),
            h('div.cs-who',
                h('div.cs-ring' + (ringing && !ended ? '.pulse' : ''), ui.avatar({ name: c.anonymous ? '?' : name, src: c.picture, size: 'xl' })),
                h('div.cs-name', name),
                h('div.cs-sub', ended ? '' : (c.phase === 'active' ? '' : sub(c))),
                c.phase === 'active' && !ended ? h('div.cs-timer', { id: 'cs-timer' }, ZP.fmt.dur((Date.now() - started) / 1000)) : null),
            h('div.cs-actions', actions),
            c.phase === 'incoming' && ZP.state.ui.keys ? h('div.cs-hint', h('kbd', ZP.state.ui.keys.answer || 'Y'), ' answer  ', h('kbd', ZP.state.ui.keys.hangup || 'N'), ' decline') : null));
        view.hidden = false;
        frame(() => view.classList.add('on'));
    }

    const frame = (fn) => requestAnimationFrame(() => requestAnimationFrame(fn));

    // ------------------------------------------------------------------ the banner while the phone is away

    function showBanner(c) {
        if (banner) return;
        banner = h('div.banner.call.on',
            ui.avatar({ name: c.anonymous ? '?' : who(c), src: c.picture, size: 'sm' }),
            h('div.bmain', h('div.btitle', who(c)), h('div.btext', 'Incoming call')),
            h('div.bkeys', h('kbd', ZP.state.ui.keys.answer || 'Y'), h('span', 'answer'), h('kbd', ZP.state.ui.keys.hangup || 'N'), h('span', 'decline')));
        $('banners').appendChild(banner);
    }
    function hideBanner() {
        if (!banner) return;
        banner.remove();
        banner = null;
    }

    // ------------------------------------------------------------------ the call list

    calls.log = (entry) => {
        if (!entry) return;
        ZP.state.calls.unshift({
            id: -Date.now(),
            number: entry.number || null,
            direction: entry.direction,
            duration: entry.duration || 0,
            anonymous: !!entry.anonymous,
            seen: entry.direction !== 'missed',
            ts: entry.ts || Date.now(),
        });
        if (ZP.state.calls.length > 80) ZP.state.calls.length = 80;
        if (entry.direction === 'missed') {
            ZP.addBadge('phone', 1);
            const name = entry.anonymous || !entry.number ? 'Unknown number' : ZP.contacts.nameOf(entry.number);
            ZP.notify({ app: 'phone', title: 'Missed call', text: name, icon: 'phone', sound: false });
        }
        ZP.emit('calls', ZP.state.calls);
    };

    // ------------------------------------------------------------------ messages from Lua

    calls.onState = (s) => {
        const before = ZP.state.call.phase;
        const { ended, log } = s;
        ZP.state.call = { phase: s.phase, number: s.number, anonymous: s.anonymous, picture: s.picture, elapsed: s.elapsed || 0 };

        if (s.phase === 'active') {
            started = Date.now() - (s.elapsed || 0) * 1000;
            if (before !== 'active') minimized = false;
            if (!ticker) ticker = setInterval(tick, 1000);
        } else {
            stopTicker();
            minimized = false;
        }
        if (s.phase === 'incoming' || s.phase === 'outgoing') minimized = false;

        const view = $('callview');
        clearTimeout(endedTimer);
        delete view.dataset.ended;
        if (ended) {
            const text = { missed: 'No answer', declined: 'Call declined', cancelled: 'Call cancelled', dropped: 'Call dropped', hangup: ended.wasActive ? 'Call ended' : 'Call ended' }[ended.reason] || 'Call ended';
            view.dataset.ended = text;
            ZP.state.call.number = ZP.state.call.number || (log && log.number);
            endedTimer = setTimeout(() => { delete view.dataset.ended; render(); }, 1600);
            calls.log(log);
            // the screen shows who it was, from the log
            if (log) { ZP.state.call.number = log.number; ZP.state.call.anonymous = log.anonymous; }
        }
        render();
        ZP.emit('call', ZP.state.call);
    };

    ZP.on('open', () => render());
    ZP.on('close', () => render());
})();
