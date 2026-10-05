/* ze-phone shell: the phone itself. Status bar, home screen (pages, dock, drag to reorder), the app host with its screen
   stack, the notification shade with quick settings, banners, and the Esc / home-bar behaviour. */

(() => {
    'use strict';

    const { h, icon } = ZP;
    const ui = ZP.ui;
    const $ = (id) => document.getElementById(id);
    const frame = (fn) => requestAnimationFrame(() => requestAnimationFrame(fn));

    ZP.apps = {};
    ZP.registerApp = (def) => { ZP.apps[def.id] = def; };

    const shell = ZP.shell = {};
    let current = null;          // the open app (AppCtx)
    let shadeOpen = false;
    let editing = false;

    // ------------------------------------------------------------------ an open app

    class AppCtx {
        constructor(def, el, params) {
            this.def = def;
            this.el = el;
            this.params = params || {};
            this.stack = [];
            this.offs = [];
            this.dead = false;
        }
        push(view) {
            view.ctx = this;
            const prev = this.stack[this.stack.length - 1];
            this.stack.push(view);
            this.el.appendChild(view.el);
            if (prev) {
                view.el.classList.add('enter');
                prev.el.classList.add('behind');
                frame(() => view.el.classList.remove('enter'));
            }
            if (view.onShow) view.onShow();
            return view;
        }
        pop() {
            if (this.stack.length <= 1) return false;
            const view = this.stack.pop();
            const prev = this.stack[this.stack.length - 1];
            view.el.classList.add('leave');
            prev.el.classList.remove('behind');
            if (prev.onShow) prev.onShow();
            setTimeout(() => { view.el.remove(); if (view.onClose) view.onClose(); }, 270);
            return true;
        }
        // goes back to the first screen
        popToRoot() { while (this.pop()); }
        // the screen on top changes without an animation (a list that is replaced by its filtered version, ...)
        replaceTop(view) {
            const old = this.stack.pop();
            view.ctx = this;
            this.stack.push(view);
            this.el.appendChild(view.el);
            if (old) old.el.remove();
            return view;
        }
        get depth() { return this.stack.length; }
        get top() { return this.stack[this.stack.length - 1]; }
        // bus subscriptions that end with the app
        on(event, fn) { this.offs.push(ZP.on(event, fn)); }
        onPush(name, fn) { this.offs.push(ZP.onPush(name, fn)); }
        // runs fn only while this app is open
        guard(fn) { return (...a) => (this.dead ? undefined : fn(...a)); }
        destroy() {
            this.dead = true;
            this.offs.forEach(off => off());
            this.offs = [];
            if (this.def.unmount) { try { this.def.unmount(this); } catch (e) { console.error(e); } }
        }
    }

    shell.currentApp = () => current;

    shell.openApp = (id, params, fromEl) => {
        const def = ZP.apps[id];
        if (!def) return;
        closeShade();
        if (current && current.def.id === id) {
            if (def.onParams) def.onParams(current, params || {});
            return;
        }
        if (current) shell.closeApp(true);
        const win = h('div.appwin', { dataset: { app: id }, style: { '--a1': def.colors[0], '--a2': def.colors[1] } });
        $('apps').appendChild(win);

        if (fromEl) {
            const s = $('screen').getBoundingClientRect(), r = fromEl.getBoundingClientRect();
            const k = parseFloat(getComputedStyle(document.documentElement).fontSize) || 13;
            win.style.transformOrigin = `${(r.left + r.width / 2 - s.left) / k}rem ${(r.top + r.height / 2 - s.top) / k}rem`;
        }

        const ctx = new AppCtx(def, win, params);
        current = ctx;
        try { def.mount(ctx, params || {}); } catch (err) { console.error('[ze-phone] app', id, err); ui.toast('This app crashed'); }
        frame(() => { win.classList.add('on'); $('screen').classList.add('app-open'); });
        ZP.emit('app:open', id);
    };

    shell.closeApp = (fast) => {
        if (!current) return;
        const ctx = current;
        current = null;
        ctx.el.classList.remove('on');
        $('screen').classList.remove('app-open');
        ctx.destroy();
        setTimeout(() => ctx.el.remove(), fast ? 0 : 300);
        ZP.emit('app:close', ctx.def.id);
    };

    // ------------------------------------------------------------------ phone on / off the screen

    shell.show = () => {
        $('phone').dataset.state = 'open';
        document.body.classList.add('phone-open');
        ZP.state.open = true;
        ZP.emit('open');
    };

    shell.hide = () => {
        $('phone').dataset.state = 'hidden';
        document.body.classList.remove('phone-open');
        ZP.state.open = false;
        if (document.activeElement && document.activeElement.blur) document.activeElement.blur();
        ZP.emit('close');
    };

    shell.requestClose = () => { ZP.post('close'); };

    // one step back: modal, shade, edit mode, app screen, app, then the phone itself
    shell.back = () => {
        if (ZP.modals.length) { ZP.modals[ZP.modals.length - 1].close(); return; }
        if (shadeOpen) { closeShade(); return; }
        if (editing) { setEditing(false); return; }
        if (searchOpen()) { closeSearch(); return; }
        if (current) {
            if (current.def.onBack && current.def.onBack(current)) return;
            if (!current.pop()) shell.closeApp();
            return;
        }
        shell.requestClose();
    };

    // the home bar: leave the app, or close the phone from the home screen
    shell.home = () => {
        if (ZP.modals.length) { ZP.modals[ZP.modals.length - 1].close(); return; }
        if (shadeOpen) { closeShade(); return; }
        if (editing) { setEditing(false); return; }
        if (searchOpen()) { closeSearch(); return; }
        if (current) { shell.closeApp(); return; }
        shell.requestClose();
    };

    document.addEventListener('keydown', (e) => {
        if (e.key !== 'Escape' || !ZP.state.open) return;
        const a = document.activeElement;
        if (a && /^(INPUT|TEXTAREA)$/.test(a.tagName) && a.value && ZP.modals.length === 0 && !a.closest('.search')) { a.blur(); return; }
        if (a && /^(INPUT|TEXTAREA)$/.test(a.tagName)) a.blur();
        e.preventDefault();
        shell.back();
    });

    // ------------------------------------------------------------------ typing: the game must not walk while a field has focus

    let typing = false, typingTimer = null;
    const isField = (el) => el && (/^(INPUT|TEXTAREA)$/.test(el.tagName) && !['range', 'checkbox', 'button'].includes(el.type));
    document.addEventListener('focusin', (e) => {
        if (!isField(e.target)) return;
        clearTimeout(typingTimer);
        if (!typing) { typing = true; ZP.post('typing', { on: true }); }
    });
    document.addEventListener('focusout', () => {
        clearTimeout(typingTimer);
        typingTimer = setTimeout(() => {
            if (typing && !isField(document.activeElement)) { typing = false; ZP.post('typing', { on: false }); }
        }, 60);
    });

    // ------------------------------------------------------------------ status bar

    function buildStatusBar() {
        const bar = $('statusbar');
        const time = h('span.sb-time', { id: 'sb-time' }, '12:00');
        const pill = h('button.sb-call', { id: 'sb-call', hidden: true, onclick: (e) => { e.stopPropagation(); ZP.calls && ZP.calls.expand(); } }, icon('phone'), h('span', { id: 'sb-call-time' }, '0:00'));
        const left = h('div.sb-left', { onclick: toggleShade }, time, pill);
        const right = h('div.sb-right', { onclick: toggleShade },
            h('span.sb-ico', { id: 'sb-dnd', hidden: true }, icon('moon')),
            h('span.sb-ico', { id: 'sb-silent', hidden: true }, icon('volume-off')),
            h('span.sb-ico', { id: 'sb-air', hidden: true }, icon('plane')),
            h('span.sb-signal', { id: 'sb-signal' }, h('i'), h('i'), h('i'), h('i')),
            h('span.sb-batt', h('i')));
        bar.appendChild(left);
        bar.appendChild(h('div.sb-hole'));
        bar.appendChild(right);
    }

    function paintStatus() {
        const s = ZP.state.settings;
        $('sb-time').textContent = ZP.fmt.gameClock();
        $('sb-dnd').hidden = !s.dnd;
        $('sb-silent').hidden = !s.silent;
        $('sb-air').hidden = !s.airplane;
        $('sb-signal').hidden = !!s.airplane;
    }

    // ------------------------------------------------------------------ home screen

    const PAGE1 = 16, PAGE_N = 20;
    let page = 0, pageCount = 1;
    let dockApps = [], gridApps = [];

    function visibleApps() {
        const p = ZP.state.player;
        return ZP.state.ui.apps.filter(a => ZP.apps[a.id]
            && (!a.mdt || p.mdt)
            && (!a.jobs || a.jobs.includes((p.job || {}).name)));
    }

    function orderedGrid(list) {
        const order = ZP.state.settings.order || [];
        const rank = (id) => { const i = order.indexOf(id); return i < 0 ? 1e6 : i; };
        return list.map((a, i) => ({ a, i })).sort((x, y) => (rank(x.a.id) - rank(y.a.id)) || (x.i - y.i)).map(x => x.a);
    }

    function tile(a, inDock) {
        const def = ZP.apps[a.id];
        const badge = h('span.badge', { hidden: true });
        const t = h('div.tile', { dataset: { app: a.id } },
            h('div.tile-ico', { style: { '--a1': def.colors[0], '--a2': def.colors[1] } }, icon(def.icon), badge),
            inDock ? null : h('div.tile-label', def.name));
        t._badge = badge;
        attachTile(t, a);
        return t;
    }

    // tap opens, long press starts the edit mode, in the edit mode a drag moves the icon
    function attachTile(t, a) {
        let timer = null, startX = 0, startY = 0, dragging = false, ghost = null, offX = 0, offY = 0, moved = false;

        t.addEventListener('pointerdown', (e) => {
            if (e.button !== 0) return;
            startX = e.clientX; startY = e.clientY; moved = false;
            if (editing && t.parentNode.classList.contains('grid')) {
                beginDrag(e);
            } else {
                clearTimeout(timer);
                timer = setTimeout(() => { timer = null; setEditing(true); }, 520);
            }
        });
        t.addEventListener('pointermove', (e) => {
            if (Math.hypot(e.clientX - startX, e.clientY - startY) > 6) { moved = true; clearTimeout(timer); timer = null; }
            if (dragging) moveDrag(e);
        });
        const up = (e) => {
            const wasTimer = timer !== null;
            clearTimeout(timer);
            timer = null;
            if (dragging) { endDrag(e); return; }
            if (wasTimer && !moved && !editing) shell.openApp(a.id, {}, t.querySelector('.tile-ico'));
        };
        t.addEventListener('pointerup', up);
        t.addEventListener('pointercancel', () => { clearTimeout(timer); timer = null; if (dragging) endDrag(); });

        function beginDrag(e) {
            dragging = true;
            t.setPointerCapture(e.pointerId);
            const r = t.getBoundingClientRect();
            const home = $('home').getBoundingClientRect();
            const k = scale();
            offX = (e.clientX - r.left) / k; offY = (e.clientY - r.top) / k;
            ghost = t.cloneNode(true);
            ghost.classList.add('ghost');
            ghost.style.left = ((r.left - home.left) / k) + 'rem';
            ghost.style.top = ((r.top - home.top) / k) + 'rem';
            $('home').appendChild(ghost);
            t.classList.add('lifted');
        }
        function moveDrag(e) {
            const home = $('home').getBoundingClientRect();
            const k = scale();
            ghost.style.left = ((e.clientX - home.left) / k - offX) + 'rem';
            ghost.style.top = ((e.clientY - home.top) / k - offY) + 'rem';
            // the tile under the pointer takes the lifted one's place
            const siblings = [...t.parentNode.children].filter(c => c !== t && c.classList.contains('tile'));
            const hit = siblings.find((c) => {
                const r = c.getBoundingClientRect();
                return e.clientX >= r.left && e.clientX <= r.right && e.clientY >= r.top && e.clientY <= r.bottom;
            });
            if (hit) {
                const all = [...t.parentNode.children];
                if (all.indexOf(hit) > all.indexOf(t)) hit.after(t); else hit.before(t);
            }
        }
        function endDrag() {
            dragging = false;
            if (ghost) ghost.remove();
            ghost = null;
            t.classList.remove('lifted');
            // the new order of the grid, kept in the settings
            const ids = [...document.querySelectorAll('#home .grid .tile')].map(x => x.dataset.app);
            ZP.saveSettings({ order: ids });
        }
    }

    const scale = () => parseFloat(getComputedStyle(document.documentElement).fontSize) || 13;

    function setEditing(on) {
        editing = on;
        $('home').classList.toggle('editing', on);
        $('home-search').hidden = on;
        $('home-done').hidden = !on;
    }

    function renderHome() {
        const home = $('home');
        const track = $('pages');
        ZP.clear(track);

        const list = visibleApps();
        dockApps = list.filter(a => a.dock);
        gridApps = orderedGrid(list.filter(a => !a.dock));

        const pages = [];
        pages.push(gridApps.slice(0, PAGE1));
        for (let i = PAGE1; i < gridApps.length; i += PAGE_N) pages.push(gridApps.slice(i, i + PAGE_N));
        pageCount = pages.length;
        if (page >= pageCount) page = pageCount - 1;

        pages.forEach((apps, index) => {
            const grid = h('div.grid', apps.map(a => tile(a, false)));
            track.appendChild(h('div.page', index === 0 ? widget() : null, grid));
        });

        const dock = $('dock');
        ZP.clear(dock);
        dockApps.forEach(a => dock.appendChild(tile(a, true)));

        paintDots();
        setPage(page, false);
        paintBadges();
        home.dataset.pages = pageCount;
    }

    // the clock widget on the first page
    function widget() {
        const t = ZP.state.time;
        const unread = h('div.glance', { id: 'glance' });
        const w = h('div.widget',
            h('div.w-time', { id: 'w-time' }, ZP.fmt.gameClock()),
            h('div.w-date', { id: 'w-date' }, dateLine(t)),
            unread);
        return w;
    }

    const dateLine = (t) => `${ZP.fmt.days[t.weekday % 7]}, ${t.day} ${ZP.fmt.months[t.month % 12]}`;

    function paintGlance() {
        const g = $('glance');
        if (!g) return;
        ZP.clear(g);
        const chips = [['messages', 'message', 'message'], ['phone', 'phone', 'missed call'], ['mail', 'mail', 'mail']];
        chips.forEach(([app, ic, label]) => {
            const n = ZP.badges[app] || 0;
            if (!n) return;
            g.appendChild(h('button.gchip', { onclick: () => shell.openApp(app) }, icon(ic), `${n} ${label}${n === 1 || app === 'mail' ? '' : 's'}`));
        });
    }

    function paintBadges() {
        document.querySelectorAll('#home .tile').forEach((t) => {
            const n = ZP.badges[t.dataset.app] || 0;
            if (t._badge) { t._badge.hidden = !n; t._badge.textContent = n > 99 ? '99+' : n; }
        });
        paintGlance();
    }

    function paintDots() {
        const dots = $('dots');
        ZP.clear(dots);
        if (pageCount < 2) return;
        for (let i = 0; i < pageCount; i++) dots.appendChild(h('button.dot' + (i === page ? '.on' : ''), { onclick: () => setPage(i, true) }));
    }

    function setPage(i, animate) {
        page = Math.max(0, Math.min(pageCount - 1, i));
        const track = $('pages');
        track.style.transition = animate ? '' : 'none';
        track.style.transform = `translateX(${-page * 100}%)`;
        [...$('dots').children].forEach((d, n) => d.classList.toggle('on', n === page));
        if (!animate) frame(() => { track.style.transition = ''; });
    }

    function buildHome() {
        const home = $('home');
        home.appendChild(h('div.pages-clip', { id: 'pages-clip' }, h('div.pages', { id: 'pages' })));
        const search = h('button.home-search', { id: 'home-search', onclick: openSearch }, icon('search'), h('span', 'Search'));
        const done = h('button.home-done', { id: 'home-done', hidden: true, onclick: () => setEditing(false) }, 'Done');
        home.appendChild(h('div.home-foot', search, done, h('div.dots', { id: 'dots' })));
        home.appendChild(h('div.dockwrap', h('div.dock', { id: 'dock' })));

        // swipe between pages
        const clip = $('pages-clip');
        let down = false, sx = 0, sy = 0, dx = 0, axis = null;
        clip.addEventListener('pointerdown', (e) => {
            if (editing || e.target.closest('.tile')) return;
            down = true; sx = e.clientX; sy = e.clientY; dx = 0; axis = null;
        });
        window.addEventListener('pointermove', (e) => {
            if (!down) return;
            dx = e.clientX - sx;
            if (!axis && Math.hypot(dx, e.clientY - sy) > 8) axis = Math.abs(dx) > Math.abs(e.clientY - sy) ? 'x' : 'y';
            if (axis === 'x' && pageCount > 1) {
                const track = $('pages');
                track.style.transition = 'none';
                const w = clip.getBoundingClientRect().width;
                track.style.transform = `translateX(${(-page * w + dx)}px)`;
            }
        });
        window.addEventListener('pointerup', () => {
            if (!down) return;
            down = false;
            if (axis === 'x') {
                const w = clip.getBoundingClientRect().width;
                if (dx < -w * 0.18) page++; else if (dx > w * 0.18) page--;
                setPage(page, true);
            }
        });
        clip.addEventListener('wheel', (e) => {
            if (pageCount < 2 || Math.abs(e.deltaY) < 8) return;
            setPage(page + (e.deltaY > 0 ? 1 : -1), true);
        }, { passive: true });
    }

    // ------------------------------------------------------------------ app search

    let searchEl = null;
    const searchOpen = () => !!searchEl;
    function closeSearch() {
        if (!searchEl) return;
        const el = searchEl;
        searchEl = null;
        el.classList.remove('on');
        setTimeout(() => el.remove(), 220);
    }
    function openSearch() {
        if (searchEl) return;
        const list = h('div.gcard.flush');
        const paint = (q) => {
            ZP.clear(list);
            const needle = (q || '').trim().toLowerCase();
            const apps = visibleApps().filter(a => !needle || ZP.apps[a.id].name.toLowerCase().includes(needle));
            apps.forEach(a => {
                const def = ZP.apps[a.id];
                list.appendChild(ui.row({
                    lead: h('div.mini-ico', { style: { '--a1': def.colors[0], '--a2': def.colors[1] } }, icon(def.icon)),
                    title: def.name, chevron: true,
                    onclick: () => { closeSearch(); shell.openApp(a.id); },
                }));
            });
            if (!apps.length) list.appendChild(h('div.pad-empty', 'No apps found'));
        };
        const s = ui.search({
            placeholder: 'Search apps', onInput: paint,
        });
        s.input.addEventListener('keydown', (e) => {
            if (e.key === 'Enter') { const first = list.querySelector('.row'); if (first) first.click(); }
        });
        searchEl = h('div.appsearch', h('div.as-bar', s.el, h('button.as-cancel', { onclick: closeSearch }, 'Cancel')), list);
        $('overlay').appendChild(searchEl);
        paint('');
        frame(() => { searchEl.classList.add('on'); s.input.focus(); });
    }

    // ------------------------------------------------------------------ notification shade and quick settings

    function buildShade() {
        const shade = $('shade');
        const quick = h('div.quick', { id: 'quick' });
        const list = h('div.nlist', { id: 'nlist' });
        shade.appendChild(h('div.shade-sheet',
            h('div.shade-head',
                h('div', h('div.sh-time', { id: 'sh-time' }), h('div.sh-date', { id: 'sh-date' })),
                h('button.ibtn', { onclick: () => { closeShade(); shell.openApp('settings'); }, title: 'Settings' }, icon('settings'))),
            quick,
            h('div.nhead', h('span', 'Notifications'), h('button.nclear', { onclick: () => { ZP.state.notifications.length = 0; ZP.emit('notifications', []); } }, 'Clear all')),
            list,
            h('button.shade-grab', { onclick: closeShade }, h('i'))));
        shade.addEventListener('click', (e) => { if (e.target === shade) closeShade(); });
        paintQuick();
        paintNotifications();
    }

    function paintQuick() {
        const q = $('quick');
        if (!q) return;
        ZP.clear(q);
        const s = ZP.state.settings;
        const tile = (ic, label, on, key, extra) => h('button.qtile' + (on ? '.on' : ''), {
            onclick: () => { ZP.saveSettings({ [key]: !s[key] }); paintQuick(); },
        }, icon(ic), h('span', label));
        q.appendChild(h('div.qgrid',
            tile('plane', 'Airplane', s.airplane, 'airplane'),
            tile('moon', 'Do not disturb', s.dnd, 'dnd'),
            tile('volume-off', 'Silent', s.silent, 'silent'),
            tile('eye-off', 'Hide my number', s.anonymous, 'anonymous')));
        const slider = ui.slider({ min: 30, max: 100, value: s.brightness || 100, icons: ['sun', 'sun'], onInput: (v) => ZP.saveSettings({ brightness: v }) });
        q.appendChild(h('div.qslider', slider.el));
    }

    function paintNotifications() {
        const list = $('nlist');
        if (!list) return;
        ZP.clear(list);
        const items = ZP.state.notifications;
        if (!items.length) { list.appendChild(h('div.pad-empty', 'No notifications')); return; }
        items.slice(0, 30).forEach((n) => {
            const def = n.app && ZP.apps[n.app];
            const lead = n.avatar
                ? ui.avatar({ name: n.title, src: n.avatar, size: 'sm' })
                : h('div.mini-ico', { style: def ? { '--a1': def.colors[0], '--a2': def.colors[1] } : { '--a1': n.color || '#6f6963', '--a2': n.color || '#4a4540' } }, icon(n.icon || (def ? def.icon : 'bell')));
            list.appendChild(h('div.notif', {
                onclick: () => { ZP.state.notifications = ZP.state.notifications.filter(x => x !== n); ZP.emit('notifications', ZP.state.notifications); closeShade(); if (n.onTap) n.onTap(); else if (n.app) shell.openApp(n.app); },
            }, lead, h('div.nmain', h('div.ntitle', n.title), n.text ? h('div.ntext', n.text) : null), h('div.ntime', ZP.fmt.ago(n.ts))));
        });
    }

    function openShade() {
        if (shadeOpen) return;
        shadeOpen = true;
        const t = ZP.state.time;
        $('sh-time').textContent = ZP.fmt.gameClock();
        $('sh-date').textContent = dateLine(t);
        paintQuick();
        paintNotifications();
        $('shade').classList.add('on');
    }
    function closeShade() {
        if (!shadeOpen) return;
        shadeOpen = false;
        $('shade').classList.remove('on');
    }
    function toggleShade() { if (shadeOpen) closeShade(); else openShade(); }
    shell.closeShade = closeShade;

    // ------------------------------------------------------------------ banners (above the phone, also while it is put away)

    shell.banner = (n) => {
        const box = $('banners');
        const def = n.app && ZP.apps[n.app];
        const lead = n.avatar
            ? ui.avatar({ name: n.title, src: n.avatar, size: 'sm' })
            : h('div.mini-ico', { style: def ? { '--a1': def.colors[0], '--a2': def.colors[1] } : { '--a1': n.color || '#ff7a1a', '--a2': n.color || '#ffb62e' } }, icon(n.icon || (def ? def.icon : 'bell')));
        const el = h('div.banner', {
            onclick: () => {
                remove();
                if (!ZP.state.open) return;
                if (n.onTap) n.onTap(); else if (n.app) shell.openApp(n.app);
            },
        }, lead, h('div.bmain', h('div.btitle', n.title), n.text ? h('div.btext', n.text) : null));
        box.appendChild(el);
        frame(() => el.classList.add('on'));
        while (box.children.length > 3) box.firstChild.remove();
        let timer = setTimeout(remove, n.timeout || 4200);
        function remove() {
            clearTimeout(timer);
            el.classList.remove('on');
            setTimeout(() => el.remove(), 260);
        }
        return { remove };
    };

    // ------------------------------------------------------------------ wiring

    ZP.on('time', () => {
        if (!$('sb-time')) return;
        $('sb-time').textContent = ZP.fmt.gameClock();
        const wt = $('w-time'); if (wt) wt.textContent = ZP.fmt.gameClock();
        const wd = $('w-date'); if (wd) wd.textContent = dateLine(ZP.state.time);
        if (shadeOpen) { $('sh-time').textContent = ZP.fmt.gameClock(); $('sh-date').textContent = dateLine(ZP.state.time); }
    });
    ZP.on('settings', () => { paintStatus(); if (shadeOpen) paintQuick(); });
    ZP.on('badges', paintBadges);
    ZP.on('notifications', () => { if (shadeOpen) paintNotifications(); });

    // the home screen only has to be drawn again when the set of apps changes (job, duty), not when the money does
    let lastKey = '';
    shell.refreshHome = () => {
        const key = visibleApps().map(a => a.id).join(',');
        if (key !== lastKey) { lastKey = key; renderHome(); }
    };

    shell.build = () => {
        buildStatusBar();
        buildHome();
        buildShade();
        $('homebar').addEventListener('click', shell.home);
    };

    shell.renderHome = renderHome;
    shell.paintStatus = paintStatus;
})();
