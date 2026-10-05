/* Dev only (not in files{}): fakes what Lua and the server answer, so the real NUI can be exercised in a browser.
   preview.html loads this and calls ZMock.attach(iframe). Every server request (ZP.api) lands in RPC below. */

window.ZMock = (() => {
    const BASE = location.origin + '/%5Bletr%5D/ze-phone/dev/img/';
    const IMG = [1, 2, 3, 4, 5, 6].map(i => BASE + i + '.svg');
    const T = Date.now();
    const MIN = 60000, HOUR = 3600000, DAY = 86400000;

    let nui = null;
    const log = [];
    const listeners = [];
    const send = (action, data) => nui && nui.contentWindow.postMessage({ action, data }, '*');
    const push = (name, data, mute) => nui && nui.contentWindow.postMessage({ action: 'push', name, data, mute: !!mute }, '*');
    const say = (text) => { log.unshift(text); log.length = Math.min(log.length, 9); listeners.forEach(f => f(log)); };
    const delay = (v, ms) => new Promise(r => setTimeout(() => r(v), ms === undefined ? 90 : ms));

    // ------------------------------------------------------------------ the fake world

    const me = { first: 'Jordan', last: 'Reyes', number: '5550142201', account: 'US03ZE5550142201', citizenid: 'ZE1234AB', serial: '48213907' };

    const world = {
        job: { name: 'unemployed', label: 'Civilian', type: 'none', onduty: false, canBill: false },
        mdt: false,
        hasPhone: true,
        money: { cash: 1840, bank: 52610, crypto: 3.4 },
    };

    const db = {
        settings: { background: 'ember', profilepicture: 'default', accent: false, ringtone: 'default', texttone: 'default', dnd: false, airplane: false, silent: false, anonymous: false, brightness: 100, favorites: ['5550188123'], order: [], muted: {} },
        contacts: [
            { id: 1, name: 'Ava Martinez', number: '5550188123', iban: 'US03ZE5550188123', online: true },
            { id: 2, name: 'Marcus Webb', number: '5550177456', iban: '', online: false },
            { id: 3, name: 'Bennys Motor Works', number: '5550165001', iban: '', online: true },
            { id: 4, name: 'Dr. Priya Nair', number: '5550133207', iban: 'US03ZE5550133207', online: false },
            { id: 5, name: 'Carlos "Tank" Mendez', number: '5550122908', iban: '', online: false },
            { id: 6, name: 'Elena Volkov', number: '5550111342', iban: 'US03ZE5550111342', online: true },
            { id: 7, name: 'Mum', number: '5550100777', iban: '', online: false },
            { id: 8, name: 'Zed', number: '5550199001', iban: '', online: false },
        ],
        blocked: ['5559990000'],
        calls: [
            { id: 1, number: '5550188123', direction: 'incoming', duration: 312, anonymous: false, seen: true, ts: T - 25 * MIN },
            { id: 2, number: '5550177456', direction: 'missed', duration: 0, anonymous: false, seen: false, ts: T - 2 * HOUR },
            { id: 3, number: null, direction: 'missed', duration: 0, anonymous: true, seen: false, ts: T - 3 * HOUR },
            { id: 4, number: '5550165001', direction: 'outgoing', duration: 64, anonymous: false, seen: true, ts: T - 7 * HOUR },
            { id: 5, number: '5550133207', direction: 'outgoing', duration: 0, anonymous: false, seen: true, ts: T - DAY },
            { id: 6, number: '5553140000', direction: 'incoming', duration: 45, anonymous: false, seen: true, ts: T - 2 * DAY },
        ],
        chats: [
            { number: '5550188123', mine: false, text: 'Where are you? I am at the pier', lastTs: T - 4 * MIN, unread: 2, picture: null, rowId: 3 },
            { number: '5550165001', mine: true, text: 'Photo', lastTs: T - 5 * HOUR, unread: 0, picture: null, rowId: 2 },
            { number: '5550100777', mine: false, text: 'Dinner on sunday?', lastTs: T - DAY, unread: 0, picture: null, rowId: 1 },
        ],
        convos: {},
        mails: [
            { mailid: 1001, sender: 'Township', subject: 'Welcome to Los Santos', message: 'Hello Jordan,<br><br>Your <b>driver license</b> application has been approved.<br>Pick it up at <strong>City Hall</strong>.<br><br>Kind regards,<br>Township Los Santos', read: false, hasButton: false, ts: T - 40 * MIN },
            { mailid: 1002, sender: 'Delivery Service', subject: 'Delivery location', message: 'We have a delivery for you. Pick it up in the marked location.', read: false, hasButton: true, ts: T - 3 * HOUR },
            { mailid: 1003, sender: 'Billing Department', subject: 'Invoice paid', message: 'Marcus Webb paid an invoice of $450.', read: true, hasButton: false, ts: T - DAY },
        ],
        tweets: [
            { tweetId: 'TWEET-11111111', firstName: 'Ava', lastName: 'Martinez', message: 'Sunset at the pier is unreal tonight #losSantos #vibes', url: IMG[0], picture: 'default', ts: T - 12 * MIN, likes: 14, liked: false, mine: false },
            { tweetId: 'TWEET-22222222', firstName: 'Marcus', lastName: 'Webb', message: 'Anyone selling a clean Sultan? DM me. @Jordan_Reyes you still got that one?', url: null, picture: 'default', ts: T - HOUR, likes: 3, liked: true, mine: false },
            { tweetId: 'TWEET-33333333', firstName: 'Jordan', lastName: 'Reyes', message: 'Testing the new phone. Looks great! #losSantos', url: null, picture: 'default', ts: T - 3 * HOUR, likes: 9, liked: false, mine: true },
            { tweetId: 'TWEET-44444444', firstName: 'Elena', lastName: 'Volkov', message: 'Race night at the docks, midnight. Bring your best. #racing #midnight', url: IMG[2], picture: 'default', ts: T - 5 * HOUR, likes: 31, liked: false, mine: false },
        ],
        adverts: [
            { id: 1, name: '@MarcusWebb', number: '5550177456', message: 'Selling: 2019 Sultan RS, low mileage. $48,000 or best offer.', url: IMG[1], ts: T - 10 * MIN },
            { id: 2, name: '@ElenaVolkov', number: '5550111342', message: 'Looking for a mechanic for a long term job. Good pay.', url: null, ts: T - 40 * MIN },
        ],
        gallery: IMG.map((url, i) => ({ url, ts: T - i * 3 * HOUR })),
        notes: [
            { id: 1, title: 'Shopping', body: 'Bandages x5\nRepair kit\nSnacks', color: '#ffb62e', pinned: true, updated: Math.floor((T - HOUR) / 1000) },
            { id: 2, title: 'Race night', body: 'Docks, midnight. Tune the Sultan first.', color: '#38bdf8', pinned: false, updated: Math.floor((T - 6 * HOUR) / 1000) },
        ],
        invoices: [
            { id: 1, amount: 450, society: 'mechanic', sender: 'Tony', candecline: true, reason: 'Engine repair' },
            { id: 2, amount: 1200, society: 'police', sender: 'Reyes', candecline: false, reason: 'Speeding' },
        ],
        history: [
            { kind: 'in', amount: 2500, other: 'Ava Martinez', note: 'Rent split', ts: T - 3 * HOUR },
            { kind: 'out', amount: 450, other: 'mechanic', note: 'Invoice', ts: T - DAY },
            { kind: 'out', amount: 120, other: 'Marcus Webb', note: 'Lunch', ts: T - 2 * DAY },
        ],
    };

    db.convos['5550188123'] = [
        { id: 1, mine: false, type: 'message', text: 'Hey! Are we still on for tonight?', data: {}, time: '19:02', ts: Math.floor((T - 2 * HOUR) / 1000), day: new Date(T - 2 * HOUR).toISOString().slice(0, 10), read: true },
        { id: 2, mine: true, type: 'message', text: 'Yes, leaving in ten', data: {}, time: '19:04', ts: Math.floor((T - 2 * HOUR + 120000) / 1000), day: new Date(T - 2 * HOUR).toISOString().slice(0, 10), read: true },
        { id: 3, mine: false, type: 'location', text: 'Shared location', data: { x: -1850.5, y: -1231.2 }, time: '19:30', ts: Math.floor((T - HOUR) / 1000), day: new Date(T - HOUR).toISOString().slice(0, 10), read: true },
        { id: 4, mine: false, type: 'message', text: 'Where are you? I am at the pier', data: {}, time: '20:41', ts: Math.floor((T - 4 * MIN) / 1000), day: new Date(T - 4 * MIN).toISOString().slice(0, 10), read: false },
    ];
    db.convos['5550165001'] = [
        { id: 11, mine: false, type: 'message', text: 'Your car is ready', data: {}, time: '09:10', ts: Math.floor((T - 7 * HOUR) / 1000), day: new Date(T - 7 * HOUR).toISOString().slice(0, 10), read: true },
        { id: 12, mine: true, type: 'picture', text: 'Photo', data: { url: IMG[3] }, time: '15:00', ts: Math.floor((T - 5 * HOUR) / 1000), day: new Date(T - 5 * HOUR).toISOString().slice(0, 10), read: true },
    ];

    let nextId = 100;

    // ------------------------------------------------------------------ server requests (ZP.api)

    const RPC = {
        boot: () => ({
            settings: db.settings, contacts: db.contacts, blocked: db.blocked, chats: db.chats, calls: db.calls, adverts: db.adverts,
            unread: { messages: db.chats.reduce((n, c) => n + c.unread, 0), mail: db.mails.filter(m => !m.read).length, phone: db.calls.filter(c => c.direction === 'missed' && !c.seen).length, bank: db.invoices.length },
            me: { name: me.first + ' ' + me.last, first: me.first, last: me.last, number: me.number, account: me.account, citizenid: me.citizenid, serial: me.serial, picture: 'default', mdt: world.mdt },
        }),
        'settings:save': (a) => { Object.assign(db.settings, a.patch || {}); return { settings: db.settings }; },

        'contacts:add': (a) => {
            if (!a.name || !/^\d{3,15}$/.test(String(a.number).replace(/\D/g, ''))) return { error: 'That is not a valid phone number' };
            const c = { id: ++nextId, name: a.name, number: String(a.number).replace(/\D/g, ''), iban: a.iban || '', online: false };
            db.contacts.push(c);
            return { contact: c };
        },
        'contacts:edit': (a) => { const c = db.contacts.find(x => x.id === a.id); if (!c) return { error: 'Contact not found' }; Object.assign(c, { name: a.name, number: String(a.number).replace(/\D/g, ''), iban: a.iban || '' }); return { contact: c }; },
        'contacts:delete': (a) => { db.contacts = db.contacts.filter(c => c.id !== a.id); return { ok: true }; },
        'contacts:block': (a) => { db.blocked = db.blocked.filter(n => n !== a.number); if (a.on) db.blocked.push(a.number); return { ok: true }; },
        'contacts:share': () => ({ ok: true }),
        'players:nearby': () => ({ players: [{ id: 12, name: 'Ava Martinez', distance: 2.4 }, { id: 31, name: 'Tony Ricci', distance: 6.1 }] }),

        'calls:seen': () => { db.calls.forEach(c => { c.seen = true; }); return { ok: true }; },
        'calls:clear': () => { db.calls = []; return { ok: true }; },
        'calls:list': () => ({ calls: db.calls }),

        'messages:list': () => ({ chats: db.chats }),
        'messages:open': (a) => {
            const chat = db.chats.find(c => c.number === a.number);
            if (chat) chat.unread = 0;
            (db.convos[a.number] || []).forEach(m => { if (!m.mine) m.read = true; });
            return { messages: db.convos[a.number] || [], exists: true };
        },
        'messages:read': () => ({ ok: true }),
        'messages:send': (a) => {
            if (a.number === '5550000000') return { error: 'This number does not exist' };
            const ts = Math.floor(Date.now() / 1000);
            const m = { id: ++nextId, mine: true, type: a.type || 'message', text: a.type === 'picture' ? 'Photo' : a.type === 'location' ? 'Shared location' : a.text, data: a.type === 'picture' ? { url: a.url } : a.type === 'location' ? { x: -1100.2, y: -820.4 } : {}, time: '20:50', ts, day: new Date().toISOString().slice(0, 10), read: false };
            (db.convos[a.number] = db.convos[a.number] || []).push(m);
            let chat = db.chats.find(c => c.number === a.number);
            if (!chat) { chat = { number: a.number, unread: 0, picture: null, rowId: ++nextId }; db.chats.unshift(chat); }
            Object.assign(chat, { mine: true, text: m.type === 'message' ? m.text : (m.type === 'picture' ? 'Photo' : 'Location'), lastTs: Date.now() });
            setTimeout(() => { m.read = true; push('messagesRead', { number: a.number, ids: [m.id] }); }, 1800);
            return { message: m };
        },
        'messages:delete': (a) => { const l = db.convos[a.number] || []; db.convos[a.number] = l.filter(m => m.id !== a.id); return { ok: true }; },
        'messages:clear': (a) => { delete db.convos[a.number]; db.chats = db.chats.filter(c => c.number !== a.number); return { ok: true }; },

        'mail:list': () => ({ mails: db.mails }),
        'mail:read': (a) => { const m = db.mails.find(x => x.mailid === a.mailid); if (m) m.read = true; return { ok: true }; },
        'mail:readAll': () => { db.mails.forEach(m => { m.read = true; }); return { ok: true }; },
        'mail:delete': (a) => { db.mails = db.mails.filter(m => m.mailid !== a.mailid); return { ok: true }; },

        'tweets:list': () => ({ tweets: db.tweets }),
        'tweets:post': (a) => {
            if (!a.message && !a.url) return { error: 'Write something first' };
            const t = { tweetId: 'TWEET-' + (++nextId), firstName: me.first, lastName: me.last, message: a.message, url: a.url || null, picture: 'default', ts: Date.now(), likes: 0, liked: false, mine: true };
            db.tweets.unshift(t);
            return { tweet: t };
        },
        'tweets:delete': (a) => { db.tweets = db.tweets.filter(t => t.tweetId !== a.tweetId); return { ok: true }; },
        'tweets:like': (a) => { const t = db.tweets.find(x => x.tweetId === a.tweetId); if (!t) return { error: 'Tweet not found' }; t.liked = !t.liked; t.likes += t.liked ? 1 : -1; return { liked: t.liked, likes: t.likes }; },

        'ads:list': () => ({ adverts: db.adverts }),
        'ads:post': (a) => {
            if (!a.message || !a.message.trim()) return { error: 'You cannot post an empty advert' };
            db.adverts = db.adverts.filter(x => x.number !== me.number);
            db.adverts.unshift({ id: ++nextId, name: '@' + me.first + me.last, number: me.number, message: a.message, url: a.url || null, ts: Date.now() });
            return { ok: true };
        },
        'ads:delete': () => { db.adverts = db.adverts.filter(x => x.number !== me.number); return { ok: true }; },

        'bank:overview': () => ({ cash: world.money.cash, bank: world.money.bank, crypto: world.money.crypto, account: me.account, history: db.history }),
        'bank:transfer': (a) => {
            if (!a.to) return { error: 'This account number does not exist' };
            if (a.to === me.account) return { error: 'You cannot transfer to yourself' };
            if (a.amount > world.money.bank) return { error: 'You do not have enough money in your bank' };
            world.money.bank -= a.amount;
            db.history.unshift({ kind: 'out', amount: a.amount, other: 'Ava Martinez', note: a.note || '', ts: Date.now() });
            return { ok: true, bank: world.money.bank, to: 'Ava Martinez' };
        },
        'invoices:list': () => ({ invoices: db.invoices }),
        'invoices:pay': (a) => { const i = db.invoices.find(x => x.id === a.id); if (!i) return { error: 'Invoice not found' }; if (i.amount > world.money.bank) return { error: 'You do not have enough money in your bank' }; world.money.bank -= i.amount; db.invoices = db.invoices.filter(x => x.id !== a.id); return { ok: true, bank: world.money.bank }; },
        'invoices:decline': (a) => { db.invoices = db.invoices.filter(x => x.id !== a.id); return { ok: true }; },
        'invoices:create': () => ({ ok: true }),
        'crypto:transactions': () => ({ transactions: db.cryptoTx || [{ title: 'Credit', message: 'You have 1 Qbit(s) purchased!', ts: T - 5 * HOUR }, { title: 'Debit', message: 'You have sold 2 Qbit(s)!', ts: T - DAY }] }),

        'notes:list': () => ({ notes: db.notes }),
        'notes:save': (a) => {
            if (!a.title && !a.body) return { error: 'The note is empty' };
            let n = db.notes.find(x => x.id === a.id);
            if (!n) { n = { id: ++nextId }; db.notes.push(n); }
            Object.assign(n, { title: a.title, body: a.body, color: a.color, pinned: !!a.pinned, updated: Math.floor(Date.now() / 1000) });
            return { id: n.id };
        },
        'notes:delete': (a) => { db.notes = db.notes.filter(n => n.id !== a.id); return { ok: true }; },

        'services:list': () => ({
            groups: [
                { job: 'police', label: 'Police', icon: 'shield', color: '#4a8cff', members: [{ name: 'Nora Nowak', number: '5550145001' }, { name: 'Sam Keller', number: '5550145002' }] },
                { job: 'ambulance', label: 'Ambulance', icon: 'cross', color: '#ff5d7a', members: [{ name: 'Dr. Priya Nair', number: '5550133207' }] },
                { job: 'mechanic', label: 'Mechanics', icon: 'wrench', color: '#34d399', members: [] },
                { job: 'taxi', label: 'Taxi', icon: 'car', color: '#ffc14d', members: [{ name: 'Leo Fischer', number: '5550167003' }] },
                { job: 'lawyer', label: 'Lawyers', icon: 'scale', color: '#4dc3ff', members: [] },
            ],
        }),

        'mdt:people': (a) => {
            if (!world.mdt) return { error: 'You do not have access to this' };
            const all = [
                { citizenid: 'ZE1234AB', firstname: 'Jordan', lastname: 'Reyes', birthdate: '1994-03-02', phone: '5550142201', nationality: 'American', gender: 0, driver: true, weapon: false, business: false, record: false, fingerprint: 'KJ12L388', apartment: { label: 'South Los Santos 14', type: 'apartment1' } },
                { citizenid: 'ZE9981XY', firstname: 'Marcus', lastname: 'Webb', birthdate: '1989-11-19', phone: '5550177456', nationality: 'American', gender: 0, driver: false, weapon: true, business: false, record: true, fingerprint: 'PQ99A102' },
                { citizenid: 'ZE5512QQ', firstname: 'Elena', lastname: 'Volkov', birthdate: '1997-07-08', phone: '5550111342', nationality: 'Russian', gender: 1, driver: true, weapon: false, business: true, record: false, fingerprint: 'RT44B771' },
            ];
            const q = (a.q || '').toLowerCase();
            return { people: all.filter(p => (p.firstname + ' ' + p.lastname + p.citizenid + p.phone).toLowerCase().includes(q)) };
        },
        'mdt:person': () => ({ vehicles: [{ plate: '48KJ2910', label: 'Karin Sultan RS' }, { plate: 'ZE 7712', label: 'Declasse Vigero' }] }),

        'gallery:list': () => ({ photos: db.gallery }),
        'gallery:add': (a) => { db.gallery.unshift({ url: a.url, ts: Date.now() }); return { url: a.url }; },
        'gallery:delete': (a) => { db.gallery = db.gallery.filter(p => p.url !== a.url); return { ok: true }; },
    };

    // ------------------------------------------------------------------ client side callbacks (ZP.post)

    let call = null;
    const callState = (extra) => send('call', Object.assign({ phase: 'idle' }, call || {}, extra || {}));

    const POST = {
        rpc: (d) => {
            const fn = RPC[d.name];
            say('rpc ' + d.name);
            if (!fn) return delay({ error: 'mock: ' + d.name + ' is not faked yet' });
            return delay(fn(d.args || {}));
        },
        typing: () => 'ok',
        sound: (d) => { say('sound ' + d.kind + (d.id ? ' ' + d.id : '')); return 'ok'; },
        waypoint: (d) => { say('waypoint ' + d.x + ',' + d.y); return 'ok'; },
        waypointClear: () => { say('waypoint cleared'); return 'ok'; },
        location: () => ({ x: 215.4, y: -810.2, street: 'Strawberry Ave', cross: 'Alta St', zone: 'Strawberry', heading: 182 }),
        close: () => { say('close'); setTimeout(() => send('close', { force: false }), 40); return 'ok'; },
        ready: () => 'ok',
        'call:start': (d) => {
            if (d.number === '5559990001') return delay({ error: 'This number is not available' });
            if (d.number === '5559990002') return delay({ error: 'This person is busy' });
            call = { phase: 'outgoing', number: d.number, anonymous: d.anonymous };
            callState();
            setTimeout(() => { if (call && call.phase === 'outgoing') { call.phase = 'active'; callState({ elapsed: 0 }); } }, 2600);
            return delay({ ok: true });
        },
        'call:answer': () => { if (call && call.phase === 'incoming') { call.phase = 'active'; callState({ elapsed: 0 }); } return 'ok'; },
        'call:hangup': () => {
            if (!call) return 'ok';
            const was = call.phase === 'active';
            const n = call.number;
            const missed = call.phase === 'incoming';
            call = null;
            send('call', { phase: 'idle', number: n, ended: { reason: missed ? 'declined' : 'hangup', by: 'you', duration: was ? 12 : 0, wasActive: was }, log: { number: n, direction: missed ? 'missed' : (was ? 'outgoing' : 'outgoing'), duration: was ? 12 : 0, anonymous: false, ts: Date.now() } });
            return 'ok';
        },
        'mail:button': (d) => { const m = db.mails.find(x => x.mailid === d.mailid); if (m) m.hasButton = false; say('mail button event'); return delay({ ok: true }); },

        'crypto:data': () => delay({ history: [{ PreviousWorth: 1000, NewWorth: 1040 }, { PreviousWorth: 1040, NewWorth: 990 }, { PreviousWorth: 990, NewWorth: 1075 }, { PreviousWorth: 1075, NewWorth: 1120 }, { PreviousWorth: 1120, NewWorth: 1085 }, { PreviousWorth: 1085, NewWorth: 1160 }, { PreviousWorth: 1160, NewWorth: 1205 }, { PreviousWorth: 1205, NewWorth: 1180 }], worth: 1180, portfolio: world.money.crypto, walletId: 'QB-48213907' }),
        'crypto:buy': (d) => { const cost = Math.floor(d.coins * 1180); if (cost > world.money.bank) return delay({ error: 'You do not have enough money' }); world.money.bank -= cost; world.money.crypto += d.coins; push('cryptoTx', { title: 'Credit', message: `You have ${d.coins} Qbit('s) purchased!` }); return delay({ ok: true, history: [{ PreviousWorth: 1205, NewWorth: 1180 }], worth: 1180, portfolio: world.money.crypto, walletId: 'QB-48213907' }); },
        'crypto:sell': (d) => { if (d.coins > world.money.crypto) return delay({ error: 'You do not have enough Qbits' }); world.money.crypto -= d.coins; world.money.bank += Math.floor(d.coins * 1180); push('cryptoTx', { title: 'Debit', message: `You have sold ${d.coins} Qbit('s)!` }); return delay({ ok: true, history: [{ PreviousWorth: 1205, NewWorth: 1180 }], worth: 1180, portfolio: world.money.crypto, walletId: 'QB-48213907' }); },
        'crypto:transfer': (d) => { if (d.coins > world.money.crypto) return delay({ error: 'You do not have enough Qbits' }); if (d.walletId === 'bad') return delay({ error: 'This wallet ID does not exist' }); world.money.crypto -= d.coins; return delay({ ok: true, history: [{ PreviousWorth: 1205, NewWorth: 1180 }], worth: 1180, portfolio: world.money.crypto, walletId: 'QB-48213907' }); },

        'vehicles:list': () => delay({ vehicles: [
            { fullname: 'Karin Sultan RS', brand: 'Karin', model: 'Sultan RS', plate: '48KJ2910', garage: 'Legion Square Garage', state: 'Garaged', fuel: 82, engine: 940, body: 880 },
            { fullname: 'Declasse Vigero', brand: 'Declasse', model: 'Vigero', plate: 'ZE 7712', garage: 'Out', state: 'Out', fuel: 22, engine: 410, body: 300 },
            { fullname: 'Albany Alpha', brand: 'Albany', model: 'Alpha', plate: '33LL0912', garage: 'Impound Lot', state: 'Impound', fuel: 55, engine: 1000, body: 990 },
        ] }),
        'vehicles:track': () => delay({ ok: Math.random() > 0.3 }),

        'houses:list': () => delay({
            houses: [{ name: 'house_1', label: '2044 Grove Street', tier: 2, price: 120000, garage: { x: 1, y: 2, z: 3 }, keyholders: [{ citizenid: 'ZE1234AB', charinfo: { firstname: 'Jordan', lastname: 'Reyes' } }, { citizenid: 'ZE9981XY', charinfo: { firstname: 'Marcus', lastname: 'Webb' } }] }, { name: 'house_2', label: '12 Mirror Park Blvd', tier: 4, price: 350000, garage: [], keyholders: [] }],
            keys: [{ HouseData: { adress: '2044 Grove Street', coords: { enter: { x: 126.2, y: -1929.5 } } } }, { HouseData: { adress: '12 Mirror Park Blvd', coords: { enter: { x: 1060.1, y: -724.2 } } } }, { HouseData: { adress: '8 Vinewood Hills', coords: { enter: { x: 300.4, y: 520.8 } } } }],
        }),
        'houses:removeKey': () => delay({ ok: true }),
        'houses:transfer': (d) => delay(d.citizenid === 'bad' ? { error: 'This is not a valid citizen ID' } : { ok: true }),

        'racing:list': () => delay({ races: [
            { RaceId: 'LR-1111', Laps: 3, SetupCitizenId: 'ZE5512QQ', RaceData: { RaceName: 'Docks Sprint', Started: false, Distance: 4120, Racers: { ZE5512QQ: {}, ZE9981XY: {} } } },
            { RaceId: 'LR-2222', Laps: 0, SetupCitizenId: 'ZE9981XY', RaceData: { RaceName: 'Vinewood Loop', Started: true, Distance: 6800, Racers: { ZE9981XY: {}, ZE1000AA: {}, ZE1001AA: {} } } },
            { RaceId: 'LR-3333', Laps: 2, SetupCitizenId: 'ZE1234AB', RaceData: { RaceName: 'My Track', Started: false, Distance: 2500, Racers: { ZE1234AB: {} } } },
        ] }),
        'racing:join': () => delay({ ok: true }),
        'racing:leave': () => delay({ ok: true }),
        'racing:start': () => delay({ ok: true }),
        'racing:tracks': () => delay({ tracks: [{ RaceId: 'LR-1111', RaceName: 'Docks Sprint' }, { RaceId: 'LR-4444', RaceName: 'Airport Run' }, { RaceId: 'LR-5555', RaceName: 'Mount Chiliad' }] }),
        'racing:track': () => delay({ distance: 4120, creator: 'E. Volkov', record: { time: 312, holder: 'M. Webb' } }),
        'racing:setup': () => delay({ ok: true }),
        'racing:create': (d) => delay(d.name === 'taken' ? { error: 'This name is not available..' } : { ok: true }),
        'racing:leaderboards': () => delay({ races: [{ name: 'Docks Sprint', results: [{ BestLap: 301, Holder: ['Elena', 'Volkov'] }, { BestLap: 322, Holder: ['Marcus', 'Webb'] }, { BestLap: 'DNF', Holder: ['Tony', 'Ricci'] }] }] }),

        'mdt:vehicles': (d) => delay(world.mdt ? { vehicles: [{ plate: '48KJ2910', label: 'Karin Sultan RS', owner: 'Jordan Reyes', flagged: false }, { plate: '99XT1200', label: 'Pegassi Zentorno', owner: 'Marcus Webb', flagged: true }, { plate: (d.q || '').toUpperCase().slice(0, 8), label: 'Unknown vehicle', owner: 'Bailey Sykes', npc: true }] } : { error: 'You do not have access to this' }),
        'mdt:scan': () => delay({ vehicle: { plate: '77PL5521', label: 'Vapid Dominator', owner: 'Kurt Bain', npc: true, flagged: false } }),
        'mdt:houses': () => delay({ houses: [{ label: '2044 Grove Street', tier: 2, charinfo: { firstname: 'Jordan', lastname: 'Reyes' }, coords: { x: 126.2, y: -1929.5 } }] }),
        'mdt:apartment': () => delay({ ok: true }),

        'camera:open': () => {
            say('camera open');
            send('close', {});
            send('camera', { on: true });
            setTimeout(() => {
                send('camera', { on: false });
                const url = IMG[Math.floor(Math.random() * IMG.length)];
                db.gallery.unshift({ url, ts: Date.now() });
                send('open', { player: playerSummary(), time: timeNow() });
                push('photoTaken', { url });
            }, 1800);
            return { ok: true };
        },
    };

    // ------------------------------------------------------------------ pieces of the world that Lua sends

    const timeNow = () => { const d = new Date(); return { h: d.getHours(), m: d.getMinutes(), day: d.getDate(), month: d.getMonth(), year: d.getFullYear(), weekday: d.getDay() }; };
    const playerSummary = () => ({ id: 7, money: world.money, job: world.job, mdt: world.mdt });

    const uiConfig = () => ({
        accent: '#ff7a1a',
        apps: [
            { id: 'phone', dock: true }, { id: 'messages', dock: true }, { id: 'camera', dock: true }, { id: 'settings', dock: true },
            { id: 'twitter' }, { id: 'mail' }, { id: 'bank' }, { id: 'crypto' }, { id: 'vehicles' }, { id: 'houses' }, { id: 'racing' },
            { id: 'services' }, { id: 'ads' }, { id: 'gallery' }, { id: 'maps' }, { id: 'notes' }, { id: 'clock' }, { id: 'calculator' }, { id: 'mdt', mdt: true },
        ],
        wallpapers: [
            { id: 'ember', label: 'Ember', css: 'radial-gradient(120% 70% at 85% 0%, rgba(255,122,26,.62), transparent 60%), radial-gradient(90% 60% at 0% 100%, rgba(255,182,46,.30), transparent 65%), linear-gradient(165deg, #2a1c14, #0d0a09 70%)' },
            { id: 'dusk', label: 'Dusk', css: 'radial-gradient(110% 70% at 15% 0%, rgba(167,139,250,.55), transparent 62%), radial-gradient(100% 70% at 100% 100%, rgba(255,122,26,.40), transparent 60%), linear-gradient(170deg, #1d1530, #0b0912 75%)' },
            { id: 'midnight', label: 'Midnight', css: 'radial-gradient(110% 70% at 80% 0%, rgba(56,189,248,.45), transparent 60%), radial-gradient(90% 60% at 0% 100%, rgba(99,102,241,.35), transparent 65%), linear-gradient(170deg, #0f1a2e, #070a12 75%)' },
            { id: 'forest', label: 'Forest', css: 'radial-gradient(110% 70% at 20% 0%, rgba(52,211,153,.42), transparent 60%), radial-gradient(90% 60% at 100% 100%, rgba(163,230,53,.25), transparent 65%), linear-gradient(170deg, #0e1f1a, #070d0b 75%)' },
            { id: 'rose', label: 'Rose', css: 'radial-gradient(110% 70% at 85% 0%, rgba(244,114,182,.50), transparent 60%), radial-gradient(90% 60% at 0% 100%, rgba(255,93,122,.32), transparent 65%), linear-gradient(170deg, #2a1420, #0e080b 75%)' },
            { id: 'sunrise', label: 'Sunrise', css: 'linear-gradient(180deg, rgba(255,182,46,.65) 0%, rgba(255,93,122,.55) 38%, rgba(72,34,76,.85) 70%, #120a14 100%)' },
        ],
        accents: ['#ff7a1a', '#ffb62e', '#ff5d7a', '#f472b6', '#a78bfa', '#38bdf8', '#2dd4bf', '#34d399', '#a3e635'],
        ringtones: [{ id: 'default', label: 'Classic' }, { id: 'michael', label: 'Michael' }, { id: 'franklin', label: 'Franklin' }, { id: 'trevor', label: 'Trevor' }],
        texttones: [{ id: 'default', label: 'Classic' }, { id: 'michael', label: 'Michael' }, { id: 'franklin', label: 'Franklin' }, { id: 'trevor', label: 'Trevor' }],
        places: [
            { label: 'Legion Square', category: 'City', x: 195.2, y: -933.8 }, { label: 'City Hall', category: 'City', x: -544.8, y: -204.4 },
            { label: 'Del Perro Pier', category: 'Leisure', x: -1850, y: -1231 }, { label: 'Vinewood Sign', category: 'Leisure', x: 711, y: 1198 },
            { label: 'Mission Row Police Station', category: 'Services', x: 441.8, y: -981.9 }, { label: 'Pillbox Medical Center', category: 'Services', x: 311, y: -592 },
            { label: 'Premium Deluxe Motorsport', category: 'Shops', x: -56, y: -1097 }, { label: 'Los Santos International', category: 'Travel', x: -1037, y: -2737 },
        ],
        keys: { open: 'M', answer: 'Y', hangup: 'N' },
        limits: { message: 500, tweet: 280, advert: 300, advertPrice: 150, transfer: 1000000, billing: 100000 },
        walk: true,
    });

    const init = () => send('init', { ui: uiConfig(), boot: RPC.boot(), player: playerSummary(), time: timeNow() });

    // ------------------------------------------------------------------ what the control panel can trigger

    const actions = {
        open: () => { send('open', { player: playerSummary(), time: timeNow(), call: call ? Object.assign({}, call) : null }); },
        close: () => send('close', {}),
        init,
        reinit: init,
        toggle: () => { const open = nui.contentWindow.ZP.state.open; if (open) POST.close(); else actions.open(); },
        incoming: () => { call = { phase: 'incoming', number: '5550188123', anonymous: false }; callState(); },
        anon: () => { call = { phase: 'incoming', number: null, anonymous: true }; callState(); },
        missed: () => { send('call', { phase: 'idle', ended: { reason: 'missed', by: 'nobody', duration: 0, wasActive: false }, log: { number: '5550177456', direction: 'missed', duration: 0, anonymous: false, ts: Date.now() } }); },
        message: () => {
            const ts = Math.floor(Date.now() / 1000);
            const m = { id: ++nextId, mine: false, type: 'message', text: 'Heads up, I just saw your car outside 👀', data: {}, time: '20:55', ts, day: new Date().toISOString().slice(0, 10), read: false };
            (db.convos['5550188123'] = db.convos['5550188123'] || []).push(m);
            const chat = db.chats.find(c => c.number === '5550188123');
            Object.assign(chat, { mine: false, text: m.text, lastTs: Date.now(), unread: chat.unread + 1 });
            push('message', { number: '5550188123', message: m });
        },
        mail: () => { const mail = { mailid: ++nextId, sender: 'qb-drugs', subject: 'New job', message: 'A new job is waiting for you.', read: false, hasButton: true, ts: Date.now() }; db.mails.unshift(mail); push('mail', mail); },
        tweet: () => { const t = { tweetId: 'TWEET-' + (++nextId), firstName: 'Tony', lastName: 'Ricci', message: 'New in town. Hello Los Santos! #newhere', url: null, picture: 'default', ts: Date.now(), likes: 0, liked: false, mine: false }; db.tweets.unshift(t); push('tweet', t); },
        mention: () => { const t = { tweetId: 'TWEET-' + (++nextId), firstName: 'Tony', lastName: 'Ricci', message: '@Jordan_Reyes where did you get that jacket?', url: null, picture: 'default', ts: Date.now(), likes: 0, liked: false, mine: false }; db.tweets.unshift(t); push('mention', t); push('tweet', t); },
        police: () => push('policeAlert', { title: '10-33 | Shop Robbery', description: 'Someone is trying to rob a store at Grove Street. Camera 2.', coords: { x: -47.2, y: -1757.5, z: 29.4 } }),
        sos: () => push('policeAlert', { title: 'Assistance colleague', description: 'Officer Nowak needs assistance at Vinewood Blvd.', coords: { x: 300.2, y: 200.5, z: 104.4 } }),
        bank: () => { world.money.bank += 2500; push('bankIn', { amount: 2500, from: 'Elena Volkov', note: 'Race winnings', bank: world.money.bank }); send('player', playerSummary()); },
        invoice: () => { const inv = { id: ++nextId, amount: 275, society: 'mechanic', sender: 'Tony', candecline: true, reason: 'Tyre change' }; db.invoices.unshift(inv); push('invoice', inv); },
        notify: () => push('notify', { title: 'Racing', text: 'Elena joined the race', icon: 'fas fa-flag-checkered', app: 'racing' }),
        shared: () => push('contactShared', { name: 'Tony Ricci', number: '5550123456', iban: 'US03ZE5550123456' }),
        advert: () => { const ad = { id: ++nextId, name: '@TonyRicci', number: '5550123456', message: 'Tow service available 24/7', url: null, ts: Date.now() }; db.adverts.unshift(ad); push('advert', ad); },
        cop: () => { world.job = { name: 'police', label: 'Police', type: 'leo', onduty: true, canBill: true, grade: 'Sergeant' }; world.mdt = true; send('player', playerSummary()); },
        civ: () => { world.job = { name: 'unemployed', label: 'Civilian', type: 'none', onduty: false, canBill: false }; world.mdt = false; send('player', playerSummary()); },
        nophone: () => { world.hasPhone = !world.hasPhone; return world.hasPhone; },
    };

    return {
        attach(iframe) {
            nui = iframe;
            iframe.addEventListener('load', () => {
                iframe.contentWindow.ZE_POST = (name, data) => {
                    const fn = POST[name];
                    if (!fn) { say('post ' + name); return delay('ok'); }
                    return fn(data || {});
                };
                setTimeout(init, 120);
            });
        },
        actions, send, push, db, world, RPC, POST,
        onLog: (f) => listeners.push(f),
        log,
    };
})();
