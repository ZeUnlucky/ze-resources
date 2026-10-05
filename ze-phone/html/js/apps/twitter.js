/* Twitter: the feed of the last hours, trending hashtags, mentions, likes and photos. A new tweet arrives as the push
   'tweet' (one tweet, not the whole feed); you are told about mentions only, a banner per tweet would be noise. */

(() => {
    'use strict';

    const { h, icon } = ZP;
    const ui = ZP.ui;
    const state = ZP.state;

    const store = { tweets: [], loaded: false, mentions: 0 };

    const handleOf = (t) => `${t.firstName}_${t.lastName}`.toLowerCase().replace(/\s+/g, '_');
    const myHandle = () => `${state.me.first || ''}_${state.me.last || ''}`.toLowerCase().replace(/\s+/g, '_');
    const mentionsMe = (t) => !t.mine && (t.message || '').toLowerCase().includes('@' + myHandle());

    function upsert(t) {
        const i = store.tweets.findIndex(x => x.tweetId === t.tweetId);
        if (i >= 0) { store.tweets[i] = Object.assign({}, store.tweets[i], t, { mine: store.tweets[i].mine || t.mine }); return; }
        store.tweets.unshift(t);
        if (store.tweets.length > 120) store.tweets.length = 120;
    }

    ZP.onPush('tweet', (t) => {
        if (!t || !t.tweetId) return;
        upsert(t);
        ZP.emit('tweets', store.tweets);
    });
    ZP.onPush('mention', (t, mute) => {
        if (!t || !t.tweetId) return;
        upsert(t);
        store.mentions++;
        ZP.addBadge('twitter', 1);
        ZP.emit('tweets', store.tweets);
        if (!mute) ZP.notify({ app: 'twitter', title: `${t.firstName} ${t.lastName} mentioned you`, text: t.message, avatar: ZP.safeUrl(t.picture) ? t.picture : null, icon: 'bird' });
    });
    ZP.onPush('tweetDeleted', ({ tweetId }) => {
        store.tweets = store.tweets.filter(t => t.tweetId !== tweetId);
        ZP.emit('tweets', store.tweets);
    });
    ZP.onPush('tweetLikes', ({ tweetId, likes }) => {
        const t = store.tweets.find(x => x.tweetId === tweetId);
        if (t) { t.likes = likes; ZP.emit('tweets', store.tweets); }
    });

    // ------------------------------------------------------------------ a tweet

    function tweetCard(ctx, t) {
        const name = `${t.firstName} ${t.lastName}`;
        const like = h('button.tact' + (t.liked ? '.liked' : ''), { type: 'button', onclick: async (e) => {
            e.stopPropagation();
            like.classList.toggle('liked');
            const res = await ZP.api('tweets:like', { tweetId: t.tweetId });
            if (res.error) { like.classList.toggle('liked'); return ui.toast(res.error, 'error'); }
            t.liked = res.liked; t.likes = res.likes;
            ZP.emit('tweets', store.tweets);
        } }, icon(t.liked ? 'heart-fill' : 'heart'), h('span', t.likes ? String(t.likes) : ''));

        const actions = h('div.tacts', like,
            h('button.tact', { type: 'button', onclick: () => compose(ctx, `@${handleOf(t)} `), title: 'Reply' }, icon('at')),
            t.mine ? h('button.tact.del', { type: 'button', title: 'Delete', onclick: async () => {
                if (!await ui.confirm({ title: 'Delete this tweet?', ok: 'Delete', danger: true })) return;
                const res = await ZP.api('tweets:delete', { tweetId: t.tweetId });
                if (res.error) return ui.toast(res.error, 'error');
                store.tweets = store.tweets.filter(x => x.tweetId !== t.tweetId);
                ZP.emit('tweets', store.tweets);
            } }, icon('trash')) : null);

        const media = ZP.safeUrl(t.url) ? h('button.tmedia', { type: 'button', onclick: () => ui.viewer({ url: t.url, actions: [{ icon: 'copy', label: 'Copy link', onclick: () => ZP.copy(t.url) }] }) }, (() => { const i = h('img', { alt: '', draggable: 'false' }); i.src = t.url; return i; })()) : null;

        return h('article.tweet' + (t.mine ? '.mine' : ''),
            ui.avatar({ name, src: t.picture, size: 'md' }),
            h('div.tbody',
                h('div.thead', h('b', name), h('span.thandle', '@' + handleOf(t)), h('span.ttime', ZP.fmt.ago(t.ts))),
                t.message ? h('div.ttext', ui.richPlain(t.message, (tag) => tagView(ctx, '#' + tag), (who) => { /* mentions are plain */ })) : null,
                media,
                actions));
    }

    function feedList(ctx, tweets, emptyOpts) {
        const box = h('div.tlist');
        if (!tweets.length) { box.appendChild(ui.empty(emptyOpts)); return box; }
        tweets.forEach(t => box.appendChild(tweetCard(ctx, t)));
        return box;
    }

    // ------------------------------------------------------------------ hashtag screen

    function tagView(ctx, tag) {
        const body = h('div.tfeed');
        const view = ui.view({ title: tag, body, className: 'nopad' });
        const draw = () => {
            ZP.clear(body);
            const needle = tag.toLowerCase();
            const list = store.tweets.filter(t => (t.message || '').toLowerCase().split(/[^\w#]+/).includes(needle));
            body.appendChild(feedList(ctx, list, { icon: 'hash', title: 'No tweets', text: `Nobody used ${tag} in the last hours.` }));
        };
        ctx.on('tweets', () => { if (!view.el.isConnected) return; draw(); });
        draw();
        ctx.push(view);
    }

    // ------------------------------------------------------------------ compose

    function compose(ctx, prefill, firstPhoto) {
        let photo = firstPhoto || null;
        const field = ui.field({ placeholder: "What's happening?", multiline: true, rows: 4, max: state.ui.limits.tweet || 280, value: prefill || '', autofocus: true, maxHeight: 180 });
        const preview = h('div.cphoto', { hidden: true });
        const post = ui.btn({ text: 'Post', icon: 'send', block: true, onclick: async () => {
            const message = field.value().trim();
            if (!message && !photo) return ui.toast('Write something first');
            post.disabled = true;
            const res = await ZP.api('tweets:post', { message, url: photo });
            post.disabled = false;
            if (res.error) return ui.toast(res.error, 'error');
            upsert(res.tweet);
            ZP.emit('tweets', store.tweets);
            sheet.close();
            ui.toast('Tweet posted');
        } });
        const paintPhoto = () => {
            ZP.clear(preview);
            preview.hidden = !photo;
            if (!photo) return;
            const img = h('img', { alt: '', draggable: 'false' });
            img.src = photo;
            preview.appendChild(img);
            preview.appendChild(ui.iconBtn('x', () => { photo = null; paintPhoto(); }, { kind: 'fill', title: 'Remove' }));
        };
        const sheet = ui.sheet({
            title: 'New tweet',
            build: (body) => {
                body.appendChild(field.el);
                body.appendChild(preview);
                body.appendChild(h('div.crow2',
                    ui.btn({ text: 'Photo', icon: 'image', kind: 'ghost', onclick: async () => { const url = await ui.photoPicker({ title: 'Tweet photo' }); if (url) { photo = url; paintPhoto(); } } }),
                    post));
                paintPhoto();
            },
        });
    }

    // ------------------------------------------------------------------ app

    ZP.registerApp({
        id: 'twitter', name: 'Twitter', icon: 'bird', colors: ['#4cc3ff', '#1d8cf8'],
        mount(ctx, params) {
            const panes = {};
            const holder = h('div.tfeedwrap');
            const draw = () => {
                const t = store.tweets;
                ZP.clear(panes.feed);
                panes.feed.appendChild(feedList(ctx, t, { icon: 'bird', title: 'Quiet here', text: 'Nobody tweeted in the last hours. Be the first!' }));

                // trending: hashtags of the loaded tweets, most used first
                ZP.clear(panes.trending);
                const counts = {};
                t.forEach(tw => (tw.message || '').match(/#\w+/g)?.forEach(tag => { const k = tag.toLowerCase(); counts[k] = (counts[k] || 0) + 1; }));
                const top = Object.keys(counts).sort((a, b) => counts[b] - counts[a]).slice(0, 15);
                if (!top.length) panes.trending.appendChild(ui.empty({ icon: 'hash', title: 'Nothing is trending', text: 'Use a #hashtag in your tweet to start something.' }));
                else panes.trending.appendChild(h('div.gcard', top.map((tag, i) => ui.row({
                    lead: h('div.rank', String(i + 1)), title: tag, sub: `${counts[tag]} tweet${counts[tag] === 1 ? '' : 's'}`, chevron: true,
                    onclick: () => tagView(ctx, tag),
                }))));

                ZP.clear(panes.mentions);
                panes.mentions.appendChild(feedList(ctx, t.filter(mentionsMe), { icon: 'at', title: 'No mentions', text: `People can mention you with @${myHandle()}.` }));
            };

            ['feed', 'trending', 'mentions'].forEach((k) => { panes[k] = h('div.tpane', { hidden: true }); holder.appendChild(panes[k]); });
            const tabs = ui.tabbar([
                { id: 'feed', icon: 'home', label: 'Feed' },
                { id: 'trending', icon: 'hash', label: 'Trending' },
                { id: 'mentions', icon: 'at', label: 'Mentions' },
            ], 'feed', (id) => show(id));

            const titles = { feed: 'Twitter', trending: 'Trending', mentions: 'Mentions' };
            const root = ui.view({ title: 'Twitter', large: true, root: true, body: holder, footer: tabs.el, className: 'nopad', actions: [ui.iconBtn('edit', () => compose(ctx), { title: 'New tweet' })] });
            const show = (id) => {
                Object.keys(panes).forEach(k => { panes[k].hidden = k !== id; });
                root.setTitle(titles[id]);
                root.body.scrollTop = 0;
                if (id === 'mentions' && store.mentions) { store.mentions = 0; ZP.setBadge('twitter', 0); }
            };

            ctx.push(root);
            ctx.on('tweets', () => { if (!ctx.dead) { draw(); tabs.badge('mentions', 0); } });
            draw();
            show('feed');
            ZP.setBadge('twitter', 0);
            store.mentions = 0;
            if (params.compose) compose(ctx, params.compose.text, params.compose.photo);

            ZP.api('tweets:list').then((res) => {
                if (ctx.dead) return;
                if (res.error) { ui.toast(res.error, 'error'); return; }
                // keep what arrived live while this loaded
                const have = new Map(store.tweets.map(x => [x.tweetId, x]));
                store.tweets = (res.tweets || []).map(x => Object.assign({}, x, { mine: x.mine || (have.get(x.tweetId) || {}).mine }));
                store.loaded = true;
                draw();
            });
        },
    });
})();
