(() => {
    'use strict';

    const RESOURCE = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'ze-evidence';

    // Everything that differs between casings and DNA. The keys match the evidence types
    // understood by server/lab.lua.
    const TYPES = {
        casing: {
            title: 'Shell casings',
            records: 'Casing Records',
            icon: '#i-casing',
            unit: ['casing', 'casings'],
            blurb: 'Spent casings collected at scenes, logged against the serial of the weapon that fired them.',
            labelPlaceholder: 'e.g. Vinewood Blvd shooting',
            lookupBlurb: 'Find a submitted casing by its record ID, or pull every casing matched to a gun serial.',
            modes: [
                { id: 'id', label: 'Record ID', placeholder: 'Enter casing ID', numeric: true },
                { id: 'value', label: 'Gun serial', placeholder: 'Enter gun serial number', numeric: false },
            ],
            idleText: 'Search by record ID or gun serial to see matching casings.',
        },
        dna: {
            title: 'DNA samples',
            records: 'DNA Records',
            icon: '#i-droplet',
            unit: ['sample', 'samples'],
            blurb: 'Blood vials taken from scenes or suspects, logged against their DNA string.',
            labelPlaceholder: 'e.g. Blood trail behind the bar',
            lookupBlurb: 'Find a submitted sample by its record ID, or pull every sample matching a DNA string.',
            modes: [
                { id: 'id', label: 'Record ID', placeholder: 'Enter DNA ID', numeric: true },
                { id: 'value', label: 'DNA string', placeholder: 'Enter DNA string', numeric: false },
            ],
            idleText: 'Search by record ID or DNA string to see matching samples.',
        },
    };

    const $ = (selector, root = document) => root.querySelector(selector);
    const $$ = (selector, root = document) => Array.from(root.querySelectorAll(selector));
    const ref = (root, name) => root.querySelector(`[data-ref="${name}"]`);

    const app = $('#app');
    const toastEl = $('#toast');
    const cards = {};
    const lookups = {};
    let maxLabel = 255;
    let toastTimer = null;

    // ---------- Helpers ----------

    async function request(action, payload) {
        try {
            const response = await fetch(`https://${RESOURCE}/request`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json; charset=UTF-8' },
                body: JSON.stringify({ action, payload }),
            });
            return await response.json();
        } catch (err) {
            return { ok: false, error: 'Could not reach the laboratory.' };
        }
    }

    function plural(count, [one, many]) {
        return count === 1 ? one : many;
    }

    // [12, 13, 14, 17] -> "#12–#14, #17"
    function formatIds(ids) {
        const sorted = [...ids].sort((a, b) => a - b);
        const parts = [];
        let start = sorted[0];
        let prev = start;
        for (let i = 1; i <= sorted.length; i++) {
            if (sorted[i] === prev + 1) {
                prev = sorted[i];
                continue;
            }
            parts.push(start === prev ? `#${start}` : `#${start}–#${prev}`);
            start = prev = sorted[i];
        }
        return parts.join(', ');
    }

    function icon(href, className) {
        const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
        svg.setAttribute('class', className || 'icon');
        const use = document.createElementNS('http://www.w3.org/2000/svg', 'use');
        use.setAttribute('href', href);
        svg.appendChild(use);
        return svg;
    }

    function showToast(message, kind = 'error') {
        clearTimeout(toastTimer);
        toastEl.replaceChildren(icon(kind === 'error' ? '#i-alert' : '#i-check'), document.createTextNode(message));
        toastEl.dataset.kind = kind;
        toastEl.hidden = false;
        toastTimer = setTimeout(() => { toastEl.hidden = true; }, 4500);
    }

    // ---------- Submit cards ----------

    function buildCard(type) {
        const config = TYPES[type];
        const root = $('#tpl-card').content.firstElementChild.cloneNode(true);
        root.dataset.type = type;
        ref(root, 'icon').setAttribute('href', config.icon);
        ref(root, 'title').textContent = config.title;
        ref(root, 'blurb').textContent = config.blurb;
        ref(root, 'label').placeholder = config.labelPlaceholder;

        const card = {
            type,
            root,
            ready: 0,
            busy: false,
            count: ref(root, 'count'),
            note: ref(root, 'note'),
            label: ref(root, 'label'),
            submit: ref(root, 'submit'),
            result: ref(root, 'result'),
        };

        card.label.addEventListener('input', () => refreshCard(card));
        card.label.addEventListener('keydown', (event) => {
            if (event.key === 'Enter') submitEvidence(card);
        });
        card.submit.addEventListener('click', () => submitEvidence(card));

        $('#cards').appendChild(root);
        cards[type] = card;
    }

    function refreshCard(card) {
        const config = TYPES[card.type];
        card.count.textContent = card.ready;
        card.label.maxLength = maxLabel;
        card.label.readOnly = card.busy;

        if (card.busy) {
            card.submit.textContent = 'Submitting…';
        } else if (card.ready > 0) {
            card.submit.textContent = `Submit ${card.ready} ${plural(card.ready, config.unit)}`;
        } else {
            card.submit.textContent = 'Nothing to submit';
        }
        card.submit.disabled = card.busy || card.ready === 0 || card.label.value.trim() === '';
    }

    function applySummary(summary) {
        $('#officer').textContent = summary.officer ? `Signed in as ${summary.officer}` : '';
        maxLabel = summary.maxLabel || maxLabel;

        for (const type of Object.keys(TYPES)) {
            const card = cards[type];
            const info = summary[type] || { ready: 0, unusable: 0 };
            card.ready = info.ready;
            if (info.unusable > 0) {
                const unit = plural(info.unusable, TYPES[type].unit);
                card.note.textContent = `${info.unusable} ${unit} in your inventory can't be logged because they carry no identifying data.`;
                card.note.hidden = false;
            } else {
                card.note.hidden = true;
            }
            refreshCard(card);
        }
    }

    function showSubmitResult(card, data) {
        const config = TYPES[card.type];
        const strong = document.createElement('strong');
        strong.textContent = `Logged ${data.submitted} ${plural(data.submitted, config.unit)}`;
        const ids = document.createElement('span');
        ids.className = 'mono';
        ids.textContent = formatIds(data.ids);

        const text = document.createElement('div');
        text.append(strong, document.createTextNode(' · record IDs '), ids);
        if (data.failed > 0) {
            const warn = document.createElement('div');
            warn.className = 'muted';
            warn.textContent = `${data.failed} could not be logged and were returned to your inventory.`;
            text.appendChild(warn);
        }

        card.result.replaceChildren(icon('#i-check'), text);
        card.result.hidden = false;
    }

    async function submitEvidence(card) {
        if (card.busy || card.submit.disabled) return;
        card.busy = true;
        card.result.hidden = true;
        refreshCard(card);

        const response = await request('submit', { type: card.type, label: card.label.value });

        card.busy = false;
        if (response && response.ok) {
            card.label.value = '';
            applySummary(response.data.summary);
            showSubmitResult(card, response.data);
        } else {
            refreshCard(card);
            showToast((response && response.error) || 'Something went wrong.');
        }
    }

    // ---------- Record lookups ----------

    function buildLookup(type) {
        const config = TYPES[type];
        const root = $('#tpl-lookup').content.firstElementChild.cloneNode(true);
        root.dataset.type = type;
        ref(root, 'title').textContent = config.records;
        ref(root, 'blurb').textContent = config.lookupBlurb;
        ref(root, 'emptyIcon').setAttribute('href', config.icon);

        const lookup = {
            type,
            root,
            mode: config.modes[0],
            buttons: new Map(),
            busy: false,
            form: ref(root, 'form'),
            modes: ref(root, 'modes'),
            query: ref(root, 'query'),
            go: ref(root, 'go'),
            summary: ref(root, 'summary'),
            list: ref(root, 'list'),
            empty: ref(root, 'empty'),
            emptyText: ref(root, 'emptyText'),
        };

        for (const mode of config.modes) {
            const button = document.createElement('button');
            button.type = 'button';
            button.setAttribute('role', 'radio');
            button.textContent = mode.label;
            button.addEventListener('click', () => setMode(lookup, mode));
            lookup.modes.appendChild(button);
            lookup.buttons.set(mode, button);
        }

        lookup.form.addEventListener('submit', (event) => {
            event.preventDefault();
            searchRecords(lookup);
        });

        setMode(lookup, lookup.mode);
        resetLookup(lookup);

        $(`#panel-${type}`).appendChild(root);
        lookups[type] = lookup;
    }

    function setMode(lookup, mode) {
        lookup.mode = mode;
        for (const [candidate, button] of lookup.buttons) {
            button.setAttribute('aria-checked', String(candidate === mode));
        }
        lookup.query.placeholder = mode.placeholder;
        lookup.query.inputMode = mode.numeric ? 'numeric' : 'text';
        lookup.query.maxLength = mode.numeric ? 10 : 55;
        lookup.query.value = '';
        lookup.query.focus();
    }

    function resetLookup(lookup) {
        lookup.list.replaceChildren();
        lookup.summary.hidden = true;
        lookup.emptyText.textContent = TYPES[lookup.type].idleText;
        lookup.empty.hidden = false;
    }

    function renderRecords(lookup, data) {
        const rows = Array.isArray(data.results) ? data.results : [];
        lookup.list.replaceChildren();

        if (rows.length === 0) {
            lookup.summary.hidden = true;
            lookup.emptyText.textContent = 'No records match that search.';
            lookup.empty.hidden = false;
            return;
        }

        for (const row of rows) {
            const item = document.createElement('li');
            item.className = 'record';

            const id = document.createElement('span');
            id.className = 'record-id';
            id.textContent = `#${row.id}`;

            const body = document.createElement('div');
            const value = document.createElement('div');
            value.className = 'record-value';
            value.textContent = row.value;
            const label = document.createElement('div');
            label.className = 'record-label';
            label.textContent = row.label;
            body.append(value, label);

            const by = document.createElement('div');
            by.className = 'record-by';
            const name = document.createElement('strong');
            name.textContent = row.submittedBy;
            by.append('Submitted by', name);

            item.append(id, body, by);
            lookup.list.appendChild(item);
        }

        const capped = rows.length >= data.limit;
        lookup.summary.textContent = capped
            ? `Showing the latest ${rows.length} records`
            : `${rows.length} ${rows.length === 1 ? 'record' : 'records'} found`;
        lookup.summary.hidden = false;
        lookup.empty.hidden = true;
    }

    async function searchRecords(lookup) {
        if (lookup.busy) return;
        const query = lookup.query.value.trim();
        if (query === '') {
            lookup.query.focus();
            return;
        }
        if (lookup.mode.numeric && !/^\d+$/.test(query)) {
            showToast('Record IDs are whole numbers.');
            return;
        }

        lookup.busy = true;
        lookup.go.disabled = true;
        const response = await request('search', { type: lookup.type, mode: lookup.mode.id, query });
        lookup.busy = false;
        lookup.go.disabled = false;

        if (response && response.ok) {
            renderRecords(lookup, response.data);
        } else {
            showToast((response && response.error) || 'Something went wrong.');
        }
    }

    // ---------- Tabs & lifecycle ----------

    function selectTab(tab) {
        for (const button of $$('.nav-btn')) {
            button.setAttribute('aria-selected', String(button.dataset.tab === tab));
        }
        for (const panel of $$('.panel')) {
            panel.hidden = panel.id !== `panel-${tab}`;
        }
        if (lookups[tab]) lookups[tab].query.focus();
    }

    function openLab(summary) {
        for (const card of Object.values(cards)) {
            card.label.value = '';
            card.result.hidden = true;
        }
        for (const lookup of Object.values(lookups)) {
            lookup.query.value = '';
            resetLookup(lookup);
        }
        applySummary(summary);
        toastEl.hidden = true;
        selectTab('submit');
        app.hidden = false;
    }

    function hideLab() {
        app.hidden = true;
    }

    function closeLab() {
        hideLab();
        fetch(`https://${RESOURCE}/close`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: '{}',
        }).catch(() => {});
    }

    for (const type of Object.keys(TYPES)) {
        buildCard(type);
        buildLookup(type);
    }

    for (const button of $$('.nav-btn')) {
        button.addEventListener('click', () => selectTab(button.dataset.tab));
    }
    $('#close').addEventListener('click', closeLab);

    document.addEventListener('keydown', (event) => {
        if (event.key === 'Escape' && !app.hidden) {
            event.preventDefault();
            closeLab();
        }
    });

    window.addEventListener('message', (event) => {
        const message = event.data;
        if (!message || typeof message !== 'object') return;
        if (message.action === 'open') openLab(message.summary || {});
        else if (message.action === 'close') hideLab();
    });
})();
