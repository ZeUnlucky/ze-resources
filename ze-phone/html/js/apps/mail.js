/* Mail: inbox, reading (a little HTML is allowed, nothing else), the action button some mails carry, delete.
   New mail arrives as the push 'mail' (server/mail.lua). Unread counts persist: they come from the `read` column. */

(() => {
    'use strict';

    const { h, icon } = ZP;
    const ui = ZP.ui;

    const store = { mails: [], loaded: false };

    ZP.onPush('mail', (m, mute) => {
        if (!m || store.mails.some(x => x.mailid === m.mailid)) return;
        store.mails.unshift(m);
        ZP.addBadge('mail', 1);
        ZP.emit('mails', store.mails);
        if (!mute) ZP.notify({ app: 'mail', title: m.sender, text: m.subject || ZP.stripHtml(m.message), icon: 'mail' });
    });

    const unreadCount = () => store.mails.filter(m => !m.read).length;

    function mailView(ctx, m) {
        const body = h('div.mailbody');
        const buttonRow = h('div.mailact');
        const view = ui.view({
            title: '',
            actions: [ui.iconBtn('trash', async () => {
                if (!await ui.confirm({ title: 'Delete this mail?', ok: 'Delete', danger: true })) return;
                await ZP.api('mail:delete', { mailid: m.mailid });
                store.mails = store.mails.filter(x => x.mailid !== m.mailid);
                ZP.setBadge('mail', unreadCount());
                ZP.emit('mails', store.mails);
                ctx.pop();
            }, { title: 'Delete', kind: 'danger' })],
            body: h('div.cardbody',
                h('div.mhead', ui.avatar({ name: m.sender, size: 'md' }), h('div.mwho', h('b', m.sender), h('span', new Date(ZP.fmt.toMs(m.ts)).toLocaleString([], { dateStyle: 'medium', timeStyle: 'short' })))),
                m.subject ? h('h2.msubject', m.subject) : null,
                body, buttonRow),
        });
        body.appendChild(ZP.richText(m.message));

        const drawButton = () => {
            ZP.clear(buttonRow);
            if (!m.hasButton) return;
            buttonRow.appendChild(ui.btn({ text: 'Accept', icon: 'check', block: true, onclick: async (e) => {
                e.currentTarget.disabled = true;
                const res = await ZP.post('mail:button', { mailid: m.mailid });
                if (res && res.error) { ui.toast(res.error, 'error'); drawButton(); return; }
                m.hasButton = false;
                drawButton();
                ui.toast('Done');
            } }));
        };
        drawButton();
        ctx.push(view);

        if (!m.read) {
            m.read = true;
            ZP.api('mail:read', { mailid: m.mailid });
            ZP.setBadge('mail', unreadCount());
            ZP.emit('mails', store.mails);
        }
    }

    ZP.registerApp({
        id: 'mail', name: 'Mail', icon: 'mail', colors: ['#ff7a8a', '#e0314f'],
        mount(ctx) {
            const holder = h('div.maillist');
            const draw = () => {
                ZP.clear(holder);
                if (!store.loaded && !store.mails.length) { holder.appendChild(ui.loading()); return; }
                if (!store.mails.length) { holder.appendChild(ui.empty({ icon: 'mail', title: 'Inbox zero', text: 'Mail from the city, jobs and other people shows up here.' })); return; }
                holder.appendChild(h('div.gcard', store.mails.map(m => h('div.row.tap.mailrow' + (m.read ? '' : '.unread'), {
                    onclick: () => mailView(ctx, m),
                    oncontextmenu: (e) => { e.preventDefault(); ui.menu([{ icon: 'trash', label: 'Delete', danger: true, onclick: async () => {
                        await ZP.api('mail:delete', { mailid: m.mailid });
                        store.mails = store.mails.filter(x => x.mailid !== m.mailid);
                        ZP.setBadge('mail', unreadCount());
                        draw();
                    } }], { title: m.sender }); },
                },
                h('i.udot'),
                ui.avatar({ name: m.sender, size: 'sm' }),
                h('div.rmain', h('div.rtitle', m.sender), h('div.msub', m.subject || '(no subject)'), h('div.rsub', ZP.stripHtml(m.message))),
                h('div.rright.col', h('span', ZP.fmt.short(m.ts)), m.hasButton ? icon('check-circle', 'accent') : null)))));
            };

            const readAll = ui.iconBtn('check', async () => {
                if (!unreadCount()) return ui.toast('Everything is read');
                await ZP.api('mail:readAll');
                store.mails.forEach(m => { m.read = true; });
                ZP.setBadge('mail', 0);
                draw();
            }, { title: 'Mark all as read' });

            ctx.push(ui.view({ title: 'Mail', large: true, root: true, body: holder, actions: [readAll] }));
            ctx.on('mails', () => { if (!ctx.dead && ctx.depth === 1) draw(); });
            draw();

            ZP.api('mail:list').then((res) => {
                if (ctx.dead) return;
                store.loaded = true;
                if (res.mails) { store.mails = res.mails; ZP.setBadge('mail', unreadCount()); }
                draw();
            });
        },
    });
})();
