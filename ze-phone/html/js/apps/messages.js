/* Messages: chat list, conversations, photos and locations, read receipts. The server builds every message
   (server/messages.lua); the UI only says "send this to that number". Incoming messages arrive as the push 'message'. */

(() => {
    'use strict';

    const { h, icon } = ZP;
    const ui = ZP.ui;
    const state = ZP.state;

    const EMOJI = '😀 😁 😂 🤣 😊 😍 😘 😎 🤔 😅 😭 😡 🥳 😴 🙄 😬 👍 👎 👏 🙏 💪 🔥 ✨ 🎉 ❤️ 💔 💯 👀 🚗 🚓 🚑 💸 💰 🍻 🍕 🍔 🎮 🏁 📍 📞 🔫 😈 🤝 ✌️ 🤞 👌 😉 😏 🫡'.split(' ');

    const convos = {};        // [number] = { messages: [...], loaded: bool }
    const drafts = {};        // [number] = unsent text
    let openNumber = null;    // the chat that is on screen
    let openChatApi = null;   // { append(msg), markRead(ids) } of that chat

    const preview = (c) => {
        if (c.text === 'Photo') return [icon('image'), ' Photo'];
        if (c.text === 'Location') return [icon('pin'), ' Location'];
        return c.text;
    };

    function updateBadge() {
        ZP.setBadge('messages', state.chats.reduce((n, c) => n + (c.unread || 0), 0));
    }
    ZP.on('boot', updateBadge);

    // keeps the chat list in step: a message came in or went out
    function touchChat(number, msg, incoming) {
        let chat = state.chats.find(c => c.number === number);
        if (!chat) {
            chat = { number, text: '', mine: false, lastTs: 0, unread: 0, picture: null };
            state.chats.unshift(chat);
        }
        chat.text = msg.type === 'picture' ? 'Photo' : msg.type === 'location' ? 'Location' : msg.text;
        chat.mine = !incoming;
        chat.lastTs = ZP.fmt.toMs(msg.ts) || Date.now();
        if (incoming && openNumber !== number) chat.unread = (chat.unread || 0) + 1;
        state.chats.sort((a, b) => b.lastTs - a.lastTs);
        updateBadge();
        ZP.emit('chats', state.chats);
        return chat;
    }

    // ------------------------------------------------------------------ incoming

    ZP.onPush('message', (d, mute) => {
        const { number, message } = d;
        if (ZP.contacts.isBlocked(number)) return;
        const cv = convos[number];
        if (cv && cv.loaded && !cv.messages.some(m => m.id === message.id)) cv.messages.push(message);
        const watching = openNumber === number && ZP.state.open;
        touchChat(number, message, true);
        if (watching && openChatApi) {
            openChatApi.append(message);
            ZP.api('messages:read', { number });
            const chat = state.chats.find(c => c.number === number);
            if (chat) chat.unread = 0;
            updateBadge();
        } else if (!mute) {
            const chat = state.chats.find(c => c.number === number);
            ZP.notify({
                app: 'messages', title: ZP.contacts.nameOf(number),
                text: message.type === 'picture' ? 'Sent a photo' : message.type === 'location' ? 'Shared a location' : message.text,
                avatar: chat && chat.picture || null, icon: 'message',
                onTap: () => ZP.shell.openApp('messages', { chat: number }),
            });
        }
    });

    ZP.onPush('messagesRead', ({ number, ids }) => {
        const cv = convos[number];
        if (cv) cv.messages.forEach(m => { if (ids.includes(m.id)) m.read = true; });
        if (openNumber === number && openChatApi) openChatApi.refreshReceipts();
    });

    // ------------------------------------------------------------------ a conversation

    function chatView(ctx, number) {
        const name = () => ZP.contacts.nameOf(number);
        const picture = () => (state.chats.find(c => c.number === number) || {}).picture || null;
        const list = h('div.msgs');
        const loadingEl = ui.loading();
        list.appendChild(loadingEl);

        const input = ui.field({ placeholder: 'Message', multiline: true, rows: 1, max: state.ui.limits.message || 500, maxHeight: 96, onInput: () => paintSend() });
        input.el.classList.add('composer-field');
        input.input.value = drafts[number] || '';
        const sendBtn = h('button.sendbtn', { type: 'button', onclick: () => send(), title: 'Send' }, icon('send'));
        const emojiPanel = h('div.emojis', { hidden: true }, EMOJI.map(e => h('button', { type: 'button', onclick: () => { input.input.value += e; input.input.dispatchEvent(new Event('input')); input.input.focus(); } }, e)));

        const plus = ui.iconBtn('plus', () => ui.menu([
            { icon: 'image', label: 'Photo', onclick: async () => { const url = await ui.photoPicker({ title: 'Send a photo' }); if (url) send({ type: 'picture', url }); } },
            { icon: 'pin', label: 'Share my location', onclick: () => send({ type: 'location' }) },
        ]), { title: 'Attach', kind: 'fill' });
        const emojiBtn = ui.iconBtn('smile', () => { emojiPanel.hidden = !emojiPanel.hidden; }, { title: 'Emoji', kind: 'muted' });

        const composer = h('div.composer', h('div.crow', plus, input.el, emojiBtn, sendBtn), emojiPanel);

        const view = ui.view({
            title: '',
            actions: [
                ui.iconBtn('phone', () => ZP.calls.start(number), { title: 'Call' }),
                ui.iconBtn('more', () => ui.menu([
                    { icon: 'user', label: 'Contact', onclick: () => ZP.shell.openApp('phone', { contact: ZP.contacts.byNumber(number) || { number } }) },
                    { icon: 'trash', label: 'Delete conversation', danger: true, onclick: async () => {
                        if (!await ui.confirm({ title: 'Delete conversation?', text: 'This only removes it from your phone.', ok: 'Delete', danger: true })) return;
                        await ZP.api('messages:clear', { number });
                        state.chats = state.chats.filter(c => c.number !== number);
                        delete convos[number];
                        updateBadge();
                        ZP.emit('chats', state.chats);
                        ctx.pop();
                    } },
                ]), { title: 'More' }),
            ],
            body: list,
            footer: composer,
            className: 'chatview',
        });
        // the header shows who it is
        const head = h('div.chead-mini', { onclick: () => ZP.shell.openApp('phone', { contact: ZP.contacts.byNumber(number) || { number } }) }, ui.avatar({ name: name(), src: picture(), size: 'sm' }), h('div.cmini-name', name()));
        view.el.querySelector('.vtitle').replaceWith(head);

        let messages = [];
        let stick = true;
        list.addEventListener('scroll', () => { stick = list.scrollHeight - list.scrollTop - list.clientHeight < 60; });

        const paintSend = () => {
            const has = input.value().trim().length > 0;
            sendBtn.classList.toggle('ready', has);
        };

        // the whole list again: day separators, grouping, receipts
        const draw = () => {
            ZP.clear(list);
            if (!messages.length) {
                list.appendChild(ui.empty({ icon: 'message', title: name(), text: 'Say hello! Messages are delivered even when they are offline.' }));
                return;
            }
            let day = null, prev = null;
            const lastMine = [...messages].reverse().find(m => m.mine && !m.failed);
            messages.forEach((m, i) => {
                const label = ZP.fmt.day(m.day || m.ts);
                if (label !== day) { day = label; list.appendChild(h('div.dayline', h('span', label))); prev = null; }
                const next = messages[i + 1];
                const groupStart = !prev || prev.mine !== m.mine;
                const sameNext = next && next.mine === m.mine && ZP.fmt.day(next.day || next.ts) === label;
                list.appendChild(bubble(m, groupStart, !sameNext, m === lastMine));
                prev = m;
            });
            if (stick) list.scrollTop = list.scrollHeight;
        };

        const bubble = (m, first, last, showReceipt) => {
            let content;
            if (m.type === 'picture' && ZP.safeUrl(m.data.url)) {
                const img = h('img', { alt: 'Photo', draggable: 'false' });
                img.src = m.data.url;
                img.onload = () => { if (stick) list.scrollTop = list.scrollHeight; };
                content = h('button.mpic', { type: 'button', onclick: () => ui.viewer({ url: m.data.url, actions: [{ icon: 'copy', label: 'Copy link', onclick: () => ZP.copy(m.data.url) }] }) }, img);
            } else if (m.type === 'location') {
                content = h('button.mloc', { type: 'button', onclick: () => { ZP.post('waypoint', { x: m.data.x, y: m.data.y, label: 'Shared location' }); } },
                    h('span.mloc-ic', icon('pin')), h('span', h('b', 'Shared location'), h('small', 'Tap to set your GPS')));
            } else {
                content = h('span', m.text);
            }
            const el = h(`div.msg${m.mine ? '.mine' : '.theirs'}${first ? '.first' : ''}${last ? '.last' : ''}`,
                h(`div.bub${m.type !== 'message' ? '.media' : ''}${m.failed ? '.failed' : ''}${m.sending ? '.sending' : ''}`, {
                    oncontextmenu: (e) => { e.preventDefault(); bubbleMenu(m); },
                }, content),
                last ? h('div.mmeta', m.failed ? 'Not delivered' : (m.sending ? 'Sending' : ZP.fmt.hm(m.ts || Date.now())) + (m.mine && showReceipt && !m.sending ? (m.read ? ' · Read' : ' · Delivered') : '')) : null);
            return el;
        };

        const bubbleMenu = (m) => {
            if (m.sending || m.failed) return;
            ui.menu([
                m.type === 'message' ? { icon: 'copy', label: 'Copy', onclick: () => ZP.copy(m.text) } : null,
                m.type === 'location' ? { icon: 'navigation', label: 'Set GPS', onclick: () => ZP.post('waypoint', { x: m.data.x, y: m.data.y, label: 'Shared location' }) } : null,
                m.type === 'picture' ? { icon: 'copy', label: 'Copy link', onclick: () => ZP.copy(m.data.url) } : null,
                { icon: 'trash', label: 'Delete for me', danger: true, onclick: async () => {
                    const res = await ZP.api('messages:delete', { number, id: m.id });
                    if (res.error) return ui.toast(res.error, 'error');
                    messages = messages.filter(x => x.id !== m.id);
                    if (convos[number]) convos[number].messages = messages;
                    draw();
                } },
            ], { title: m.type === 'message' ? m.text.slice(0, 40) : 'Message' });
        };

        const send = async (extra) => {
            const kind = extra ? extra.type : 'message';
            const text = input.value().trim();
            if (kind === 'message' && !text) return;
            const temp = { id: 'tmp' + Date.now(), mine: true, type: kind, text: kind === 'message' ? text : (kind === 'picture' ? 'Photo' : 'Shared location'), data: extra && extra.url ? { url: extra.url } : {}, ts: Math.floor(Date.now() / 1000), day: null, read: false, sending: true };
            if (kind === 'message') { input.set(''); drafts[number] = ''; paintSend(); }
            messages.push(temp);
            stick = true;
            draw();
            const res = await ZP.api('messages:send', { number, type: kind, text, url: extra && extra.url });
            if (res.error || !res.message) {
                temp.sending = false;
                temp.failed = true;
                draw();
                ui.toast(res.error || 'The message was not delivered', 'error');
                setTimeout(() => { messages = messages.filter(m => m !== temp); draw(); }, 2600);
                return;
            }
            const at = messages.indexOf(temp);
            if (at >= 0) messages[at] = res.message;
            if (convos[number]) convos[number].messages = messages;
            touchChat(number, res.message, false);
            draw();
        };

        input.input.addEventListener('keydown', (e) => { if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(); } });
        input.input.addEventListener('input', () => { drafts[number] = input.value(); });

        const api = {
            append(m) { messages.push(m); stick = true; draw(); },
            refreshReceipts() { draw(); },
        };

        view.onShow = () => { openNumber = number; openChatApi = api; };
        view.onClose = () => {
            drafts[number] = input.value();
            if (openNumber === number) { openNumber = null; openChatApi = null; }
        };
        openNumber = number;
        openChatApi = api;

        ctx.push(view);
        paintSend();

        // load the conversation (and mark it read)
        ZP.api('messages:open', { number }).then((res) => {
            if (res.error) { ZP.clear(list); list.appendChild(ui.empty({ icon: 'alert', title: 'Could not open this chat', text: res.error })); return; }
            messages = res.messages || [];
            convos[number] = { messages, loaded: true };
            const chat = state.chats.find(c => c.number === number);
            if (chat) chat.unread = 0;
            updateBadge();
            stick = true;
            draw();
            ZP.emit('chats', state.chats);
        });
        return view;
    }

    // ------------------------------------------------------------------ new chat

    async function newChat(ctx) {
        const picked = await ui.contactPicker({ title: 'New message', allowNumber: true });
        if (picked) chatView(ctx, picked.number);
    }

    // ------------------------------------------------------------------ app

    ZP.registerApp({
        id: 'messages', name: 'Messages', icon: 'message', colors: ['#ffc14d', '#ff7a1a'],
        mount(ctx, params) {
            const holder = h('div.chatholder');
            const search = ui.search({ placeholder: 'Search', onInput: () => draw() });
            const body = h('div.chatlist', search.el, holder);

            const draw = () => {
                ZP.clear(holder);
                const needle = search.value().trim().toLowerCase();
                const items = state.chats.filter(c => !needle || ZP.contacts.nameOf(c.number).toLowerCase().includes(needle) || c.number.includes(needle) || (c.text || '').toLowerCase().includes(needle));
                if (!items.length) {
                    holder.appendChild(ui.empty({ icon: 'message', title: needle ? 'No matches' : 'No conversations', text: needle ? 'Try another name or number.' : 'Start a conversation with the pencil button.' }));
                    return;
                }
                const listEl = h('div.gcard');
                holder.appendChild(listEl);
                items.forEach((c) => {
                    const name = ZP.contacts.nameOf(c.number);
                    listEl.appendChild(h('div.row.tap.chatrow', {
                        onclick: () => chatView(ctx, c.number),
                        oncontextmenu: (e) => { e.preventDefault(); ui.menu([{ icon: 'trash', label: 'Delete conversation', danger: true, onclick: async () => {
                            await ZP.api('messages:clear', { number: c.number });
                            state.chats = state.chats.filter(x => x.number !== c.number);
                            delete convos[c.number];
                            updateBadge();
                            draw();
                        } }], { title: name }); },
                    },
                    ui.avatar({ name, src: c.picture, size: 'md' }),
                    h('div.rmain', h('div.rtitle' + (c.unread ? '.bold' : ''), name), h('div.rsub', c.mine ? 'You: ' : null, preview(c))),
                    h('div.rright.col', h('span' + (c.unread ? '.unread-time' : ''), ZP.fmt.short(c.lastTs)), c.unread ? h('span.upill', c.unread > 99 ? '99+' : c.unread) : null)));
                });
            };
            const root = ui.view({
                title: 'Messages', large: true, root: true,
                actions: [ui.iconBtn('edit', () => newChat(ctx), { title: 'New message' })],
                body,
            });
            ctx.push(root);
            ctx.on('chats', () => { if (!ctx.dead) draw(); });
            ctx.on('contacts', () => { if (!ctx.dead) draw(); });
            draw();

            // refresh the list from the server (read state, new chats)
            ZP.api('messages:list').then((res) => {
                if (res.chats && !ctx.dead) { state.chats = res.chats; updateBadge(); draw(); }
            });

            if (params.chat) chatView(ctx, params.chat);
            ctx.chatView = (n) => chatView(ctx, n);
        },
        onParams(ctx, params) {
            if (params.chat) ctx.chatView(params.chat);
        },
        unmount() { openNumber = null; openChatApi = null; },
    });
})();
