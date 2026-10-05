/* Adverts: one board for the whole server. Every player has at most one advert; it expires after a while (config). */

(() => {
    'use strict';

    const { h, icon } = ZP;
    const ui = ZP.ui;
    const state = ZP.state;

    ZP.onPush('advert', (ad, mute) => {
        if (!ad) return;
        state.adverts = state.adverts.filter(a => a.id !== ad.id && a.number !== ad.number);
        state.adverts.unshift(ad);
        ZP.emit('adverts', state.adverts);
        if (!mute && ad.number !== state.me.number) {
            ZP.notify({ app: 'ads', title: 'New advert', text: `${ad.name}: ${ad.message}`, icon: 'megaphone', sound: false });
        }
    });
    ZP.onPush('advertRemoved', ({ id }) => {
        state.adverts = state.adverts.filter(a => a.id !== id);
        ZP.emit('adverts', state.adverts);
    });

    function compose() {
        let photo = null;
        const price = state.ui.limits.advertPrice || 0;
        const field = ui.field({ placeholder: 'What do you want to tell the city?', multiline: true, rows: 4, max: state.ui.limits.advert || 300, autofocus: true, maxHeight: 180 });
        const preview = h('div.cphoto', { hidden: true });
        const paint = () => {
            ZP.clear(preview);
            preview.hidden = !photo;
            if (!photo) return;
            const img = h('img', { alt: '', draggable: 'false' });
            img.src = photo;
            preview.appendChild(img);
            preview.appendChild(ui.iconBtn('x', () => { photo = null; paint(); }, { kind: 'fill' }));
        };
        const post = ui.btn({ text: price ? `Post for ${ZP.fmt.money(price)}` : 'Post', icon: 'send', block: true, onclick: async () => {
            if (!field.value().trim()) return ui.toast('You cannot post an empty advert');
            post.disabled = true;
            const res = await ZP.api('ads:post', { message: field.value(), url: photo });
            post.disabled = false;
            if (res.error) return ui.toast(res.error, 'error');
            sheet.close();
            ui.toast('Advert posted');
        } });
        const sheet = ui.sheet({
            title: 'New advert',
            build: (body) => {
                body.appendChild(field.el);
                body.appendChild(preview);
                if (price) body.appendChild(h('div.hint', `An advert costs ${ZP.fmt.money(price)} from your bank account and replaces your current one.`));
                body.appendChild(h('div.crow2', ui.btn({ text: 'Photo', icon: 'image', kind: 'ghost', onclick: async () => { const url = await ui.photoPicker({ title: 'Advert photo' }); if (url) { photo = url; paint(); } } }), post));
            },
        });
    }

    ZP.registerApp({
        id: 'ads', name: 'Adverts', icon: 'megaphone', colors: ['#ffc14d', '#ff8a1f'],
        mount(ctx) {
            const holder = h('div.adlist');
            const draw = () => {
                ZP.clear(holder);
                if (!state.adverts.length) { holder.appendChild(ui.empty({ icon: 'megaphone', title: 'No adverts', text: 'Be the first to put something on the board.' })); return; }
                state.adverts.forEach((ad) => {
                    const mine = ad.number === state.me.number;
                    const img = ZP.safeUrl(ad.url) ? h('button.tmedia', { type: 'button', onclick: () => ui.viewer({ url: ad.url }) }, (() => { const i = h('img', { alt: '', draggable: 'false' }); i.src = ad.url; return i; })()) : null;
                    holder.appendChild(h('article.ad',
                        { onclick: () => {
                            if (mine) return;
                            ui.menu([
                                { icon: 'phone', label: `Call ${ZP.fmt.number(ad.number)}`, onclick: () => ZP.calls.start(ad.number) },
                                { icon: 'message', label: 'Send a message', onclick: () => ZP.shell.openApp('messages', { chat: ad.number }) },
                                ZP.contacts.byNumber(ad.number) ? null : { icon: 'user-plus', label: 'Add to contacts', onclick: () => ZP.shell.openApp('phone', { contact: { number: ad.number } }) },
                            ], { title: ad.name });
                        } },
                        h('div.adhead', ui.avatar({ name: ad.name.replace('@', ''), size: 'sm' }), h('div.adwho', h('b', ad.name), h('span', ZP.fmt.number(ad.number))), h('span.ttime', ZP.fmt.ago(ad.ts))),
                        h('div.adtext', ad.message),
                        img,
                        mine ? ui.btn({ text: 'Delete my advert', icon: 'trash', kind: 'danger', small: true, onclick: async (e) => {
                            e.stopPropagation();
                            const res = await ZP.api('ads:delete');
                            if (res.error) return ui.toast(res.error, 'error');
                            state.adverts = state.adverts.filter(a => a.number !== state.me.number);
                            draw();
                        } }) : null));
                });
            };
            ctx.push(ui.view({ title: 'Adverts', large: true, root: true, body: holder, actions: [ui.iconBtn('edit', compose, { title: 'New advert' })] }));
            ctx.on('adverts', () => { if (!ctx.dead) draw(); });
            draw();
            ZP.api('ads:list').then((res) => { if (res.adverts && !ctx.dead) { state.adverts = res.adverts; draw(); } });
        },
    });
})();
