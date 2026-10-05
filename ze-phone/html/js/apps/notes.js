/* Notes: saved on the server per character. The editor saves by itself a moment after you stop typing. */

(() => {
    'use strict';

    const { h, icon } = ZP;
    const ui = ZP.ui;

    const COLORS = ['#ffb62e', '#ff7a1a', '#ff5d7a', '#f472b6', '#a78bfa', '#38bdf8', '#34d399', '#a3e635'];
    let notes = null;

    const sortNotes = () => notes.sort((a, b) => (b.pinned - a.pinned) || (b.updated - a.updated));

    function editor(ctx, note, redraw) {
        const isNew = !note;
        note = note || { id: null, title: '', body: '', color: COLORS[0], pinned: false, updated: Math.floor(Date.now() / 1000) };
        let dirty = false, saving = false, timer = null;

        const title = h('input.ntitle-in', { type: 'text', placeholder: 'Title', maxlength: 80, value: note.title, spellcheck: 'false' });
        const body = h('textarea.nbody-in', { placeholder: 'Start typing...', maxlength: 4000, spellcheck: 'false' });
        body.value = note.body;
        const dots = h('div.ncolors', COLORS.map(c => h('button.ndot' + (note.color === c ? '.on' : ''), { type: 'button', style: { '--c': c }, onclick: () => { note.color = c; dots.querySelectorAll('.ndot').forEach(d => d.classList.toggle('on', d.style.getPropertyValue('--c') === c)); touch(); } })));
        const status = h('span.nstatus', '');

        const save = async () => {
            if (saving || !dirty) return;
            if (!title.value.trim() && !body.value.trim()) return;
            saving = true;
            dirty = false;
            status.textContent = 'Saving';
            const res = await ZP.api('notes:save', { id: note.id, title: title.value, body: body.value, color: note.color, pinned: note.pinned });
            saving = false;
            if (res.error) { status.textContent = res.error; dirty = true; return; }
            if (!note.id) { note.id = res.id; if (notes) notes.unshift(note); }
            note.title = title.value; note.body = body.value;
            note.updated = Math.floor(Date.now() / 1000);
            if (notes) sortNotes();
            status.textContent = 'Saved';
            if (dirty) save();
        };
        const touch = () => { dirty = true; status.textContent = ''; clearTimeout(timer); timer = setTimeout(save, 700); };
        title.addEventListener('input', touch);
        body.addEventListener('input', touch);

        const pin = ui.iconBtn(note.pinned ? 'star-fill' : 'star', () => {
            note.pinned = !note.pinned;
            pin.replaceChildren(icon(note.pinned ? 'star-fill' : 'star'));
            touch();
        }, { title: 'Pin' });
        const del = ui.iconBtn('trash', async () => {
            if (!await ui.confirm({ title: 'Delete this note?', ok: 'Delete', danger: true })) return;
            dirty = false;
            if (note.id) await ZP.api('notes:delete', { id: note.id });
            if (notes) notes = notes.filter(n => n.id !== note.id);
            ctx.pop();
            redraw();
        }, { title: 'Delete', kind: 'danger' });

        const view = ui.view({
            title: '',
            actions: [pin, del],
            body: h('div.neditor', title, body, h('div.nfoot', dots, status)),
        });
        view.onClose = () => { clearTimeout(timer); save().then(redraw); };
        // leaving the app while the editor is open must not lose the last words
        ctx.offs.push(() => { clearTimeout(timer); save(); });
        ctx.push(view);
        if (isNew) setTimeout(() => title.focus(), 330);
    }

    ZP.registerApp({
        id: 'notes', name: 'Notes', icon: 'note', colors: ['#ffe066', '#f2b705'],
        mount(ctx) {
            const holder = h('div.nlistwrap', ui.loading());
            const draw = () => {
                ZP.clear(holder);
                if (notes === null) { holder.appendChild(ui.loading()); return; }
                if (!notes.length) { holder.appendChild(ui.empty({ icon: 'note', title: 'No notes', text: 'Keep shopping lists, plans and phone numbers here.' })); return; }
                holder.appendChild(h('div.gcard', notes.map(n => ui.row({
                    lead: h('i.ncolor', { style: { background: n.color || COLORS[0] } }),
                    title: n.title || (n.body || '').split('\n')[0] || 'Untitled',
                    sub: (n.title ? (n.body || '').split('\n')[0] : (n.body || '').split('\n')[1] || '') || 'No text',
                    right: [n.pinned ? icon('star-fill', 'fav-on') : null, h('span', ZP.fmt.short(n.updated))],
                    onclick: () => editor(ctx, n, draw),
                    chevron: true,
                }))));
            };
            ctx.push(ui.view({ title: 'Notes', large: true, root: true, body: holder, actions: [ui.iconBtn('plus', () => editor(ctx, null, draw), { title: 'New note' })] }));
            draw();
            ZP.api('notes:list').then((res) => {
                if (ctx.dead) return;
                if (res.error) { ZP.clear(holder); holder.appendChild(ui.empty({ icon: 'alert', title: 'Could not load', text: res.error })); return; }
                notes = res.notes || [];
                sortNotes();
                draw();
            });
        },
    });
})();
