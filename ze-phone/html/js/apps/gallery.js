/* Gallery and Camera. ZP.gallery is shared (photo picker in Messages, Twitter, adverts, profile). ZP.camera.open(cb) hides the
   phone, the game camera comes up (client/camera.lua), and the result comes back as the push 'photoTaken' { url | null }. */

(() => {
    'use strict';

    const { h, icon } = ZP;
    const ui = ZP.ui;
    const state = ZP.state;

    // ------------------------------------------------------------------ shared gallery

    let photos = null;
    let loadedAt = 0;
    let pending = null;

    ZP.gallery = {
        list(force) {
            if (photos && !force && Date.now() - loadedAt < 60000) return Promise.resolve(photos);
            if (pending) return pending;
            pending = ZP.api('gallery:list').then((res) => {
                pending = null;
                if (res.photos) { photos = res.photos; loadedAt = Date.now(); }
                return photos || [];
            });
            return pending;
        },
        add(photo) {
            if (!photos) return;
            photos = photos.filter(p => p.url !== photo.url);
            photos.unshift(photo);
        },
        remove(url) {
            if (photos) photos = photos.filter(p => p.url !== url);
        },
        // a link typed or pasted by the player
        async addLink(url) {
            if (!ZP.safeUrl(url)) { ui.toast('That is not a usable link'); return null; }
            const res = await ZP.api('gallery:add', { url });
            if (res.error) { ui.toast(res.error, 'error'); return null; }
            ZP.gallery.add({ url: res.url, ts: Date.now() });
            return res.url;
        },
    };

    ZP.camera = {
        open(cb) {
            ZP.pendingPhoto = cb || null;
            return ZP.post('camera:open').then((res) => {
                if (res && res.error) {
                    ui.toast(res.error, 'error');
                    const f = ZP.pendingPhoto;
                    ZP.pendingPhoto = null;
                    if (f) f(null);
                    return false;
                }
                return true;
            });
        },
    };

    ZP.onPush('photoTaken', ({ url }) => {
        const cb = ZP.pendingPhoto;
        ZP.pendingPhoto = null;
        if (url) ZP.gallery.add({ url, ts: Date.now() });
        if (cb) { cb(url || null); return; }
        if (url) ZP.shell.openApp('gallery', { view: url });
    });

    // ------------------------------------------------------------------ gallery app

    function viewPhoto(ctx, photo, redraw) {
        const url = photo.url;
        ui.viewer({
            url,
            actions: [
                { icon: 'send', label: 'Send', onclick: async () => {
                    const c = await ui.contactPicker({ title: 'Send photo to', allowNumber: true });
                    if (!c) return;
                    const res = await ZP.api('messages:send', { number: c.number, type: 'picture', url });
                    ui.toast(res.error || `Sent to ${c.name}`, res.error ? 'error' : undefined);
                } },
                { icon: 'bird', label: 'Tweet', onclick: () => ZP.shell.openApp('twitter', { compose: { photo: url } }) },
                { icon: 'image', label: 'Wallpaper', onclick: () => { ZP.saveSettings({ background: url }); ui.toast('Wallpaper set'); } },
                { icon: 'user', label: 'Profile', onclick: () => { ZP.saveSettings({ profilepicture: url }); ui.toast('Profile photo set'); } },
                { icon: 'copy', label: 'Link', keep: true, onclick: () => ZP.copy(url) },
                { icon: 'trash', label: 'Delete', danger: true, onclick: async () => {
                    if (!await ui.confirm({ title: 'Delete this photo?', ok: 'Delete', danger: true })) return;
                    const res = await ZP.api('gallery:delete', { url });
                    if (res.error) return ui.toast(res.error, 'error');
                    ZP.gallery.remove(url);
                    redraw();
                } },
            ],
        });
    }

    ZP.registerApp({
        id: 'gallery', name: 'Gallery', icon: 'image', colors: ['#ff7ad9', '#b43fa3'],
        mount(ctx, params) {
            const holder = h('div.gal', ui.loading());
            const draw = () => {
                ZP.clear(holder);
                const list = photos || [];
                if (!list.length) { holder.appendChild(ui.empty({ icon: 'image', title: 'No photos', text: 'Take a photo with the camera, or add one from a link.', action: ui.btn({ text: 'Open the camera', icon: 'camera', onclick: () => ZP.camera.open() }) })); return; }
                holder.appendChild(h('div.photo-grid.big', list.map((p) => {
                    const cell = h('button.photo', { type: 'button', onclick: () => viewPhoto(ctx, p, draw) });
                    ZP.setBg(cell, p.url);
                    return cell;
                })));
                holder.appendChild(h('div.hint', `${list.length} photo${list.length === 1 ? '' : 's'}`));
            };
            const actions = [
                ui.iconBtn('link', async () => {
                    const link = await ui.prompt({ title: 'Add from a link', placeholder: 'https://...', type: 'url', max: 500, ok: 'Add' });
                    if (link && await ZP.gallery.addLink(link.trim())) draw();
                }, { title: 'Add from a link' }),
                ui.iconBtn('camera', () => ZP.camera.open(), { title: 'Camera' }),
            ];
            ctx.push(ui.view({ title: 'Gallery', large: true, root: true, body: holder, actions }));
            ZP.gallery.list(true).then(() => {
                if (ctx.dead) return;
                draw();
                if (params.view) { const p = (photos || []).find(x => x.url === params.view); if (p) viewPhoto(ctx, p, draw); }
            });
        },
        onParams(ctx, params) {
            if (params.view) ZP.gallery.list().then((list) => { const p = list.find(x => x.url === params.view); if (p) viewPhoto(ctx, p, () => {}); });
        },
    });

    // ------------------------------------------------------------------ camera app: it only starts the camera

    ZP.registerApp({
        id: 'camera', name: 'Camera', icon: 'camera', colors: ['#b5afa8', '#4d4844'],
        mount(ctx) {
            const body = h('div.camsplash', h('div.cs-lens', icon('camera')), h('div.cs-text', 'Opening the camera'), ui.spinner());
            ctx.push(ui.view({ title: 'Camera', root: true, body, className: 'flush' }));
            const start = () => {
                ZP.clear(body);
                body.appendChild(h('div.cs-lens', icon('camera')));
                body.appendChild(h('div.cs-text', 'Opening the camera'));
                body.appendChild(ui.spinner());
                ZP.camera.open((url) => {
                    if (url) ZP.shell.openApp('gallery', { view: url });
                    else if (!ctx.dead) ZP.shell.closeApp();
                }).then((ok) => {
                    if (ok || ctx.dead) return;
                    ZP.clear(body);
                    body.appendChild(ui.empty({ icon: 'camera', title: 'Camera not available', text: 'The camera is not set up on this server, or you cannot use it right now.', action: ui.btn({ text: 'Try again', onclick: start }) }));
                });
            };
            start();
        },
    });
})();
