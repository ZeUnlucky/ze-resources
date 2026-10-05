/* Calculator. Buttons, and the keyboard while the app is open (digits, + - * / . Enter, Backspace, C or Delete to clear). */

(() => {
    'use strict';

    const { h } = ZP;

    ZP.registerApp({
        id: 'calculator', name: 'Calculator', icon: 'calculator', colors: ['#524c48', '#211e1c'],
        mount(ctx) {
            let shown = '0', acc = null, op = null, fresh = true, expr = '';

            const display = h('div.calc-out', '0');
            const exprEl = h('div.calc-expr', '');

            const format = (s) => {
                if (s === 'Error') return s;
                const neg = s.startsWith('-');
                const [int, dec] = (neg ? s.slice(1) : s).split('.');
                const grouped = int.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
                return (neg ? '-' : '') + grouped + (dec !== undefined ? '.' + dec : '');
            };
            const paint = () => {
                display.textContent = format(shown);
                display.style.fontSize = shown.length > 12 ? '2.2rem' : shown.length > 9 ? '3rem' : '4rem';
                exprEl.textContent = expr;
                const c = clearBtn.querySelector('span');
                if (c) c.textContent = (shown !== '0' || acc !== null) ? 'C' : 'AC';
            };
            const clean = (n) => {
                if (!Number.isFinite(n)) return 'Error';
                return String(parseFloat(n.toPrecision(12)));
            };
            const apply = (a, b, o) => {
                if (o === '+') return a + b;
                if (o === '-') return a - b;
                if (o === '*') return a * b;
                if (o === '/') return b === 0 ? NaN : a / b;
                return b;
            };

            const digit = (d) => {
                if (shown === 'Error') shown = '0';
                if (fresh) { shown = d === '.' ? '0.' : d; fresh = false; }
                else if (d === '.') { if (!shown.includes('.')) shown += '.'; }
                else if (shown.replace(/[-.]/g, '').length < 14) shown = shown === '0' ? d : shown + d;
                paint();
            };
            const operator = (o) => {
                const cur = parseFloat(shown);
                if (acc !== null && !fresh) { acc = apply(acc, cur, op); shown = clean(acc); } else acc = cur;
                op = o; fresh = true;
                expr = `${format(clean(acc))} ${{ '+': '+', '-': '−', '*': '×', '/': '÷' }[o]}`;
                paint();
            };
            const equals = () => {
                if (op === null) return;
                const cur = parseFloat(shown);
                const res = apply(acc, cur, op);
                expr = `${format(clean(acc))} ${{ '+': '+', '-': '−', '*': '×', '/': '÷' }[op]} ${format(clean(cur))} =`;
                shown = clean(res);
                acc = null; op = null; fresh = true;
                paint();
            };
            const clear = () => { if (shown !== '0' && !fresh) { shown = '0'; fresh = true; } else { shown = '0'; acc = null; op = null; expr = ''; fresh = true; } paint(); };
            const sign = () => { if (shown !== '0' && shown !== 'Error') shown = shown.startsWith('-') ? shown.slice(1) : '-' + shown; paint(); };
            const percent = () => { shown = clean(parseFloat(shown) / 100); fresh = true; paint(); };
            const back = () => { if (fresh || shown === 'Error') return; shown = shown.length > 1 && !(shown.length === 2 && shown.startsWith('-')) ? shown.slice(0, -1) : '0'; if (shown === '0') fresh = true; paint(); };

            const key = (label, cls, fn) => h(`button.ckey.${cls}`, { type: 'button', onclick: fn }, h('span', label));
            const clearBtn = key('AC', 'fn', clear);
            const pad = h('div.ckeys',
                clearBtn, key('±', 'fn', sign), key('%', 'fn', percent), key('÷', 'op', () => operator('/')),
                key('7', 'num', () => digit('7')), key('8', 'num', () => digit('8')), key('9', 'num', () => digit('9')), key('×', 'op', () => operator('*')),
                key('4', 'num', () => digit('4')), key('5', 'num', () => digit('5')), key('6', 'num', () => digit('6')), key('−', 'op', () => operator('-')),
                key('1', 'num', () => digit('1')), key('2', 'num', () => digit('2')), key('3', 'num', () => digit('3')), key('+', 'op', () => operator('+')),
                key('0', 'num.zero', () => digit('0')), key('.', 'num', () => digit('.')), key('=', 'eq', equals));

            const onKey = (e) => {
                if (!pad.isConnected || /^(INPUT|TEXTAREA)$/.test((document.activeElement || {}).tagName)) return;
                if (/^\d$/.test(e.key)) digit(e.key);
                else if (e.key === '.' || e.key === ',') digit('.');
                else if ('+-*/'.includes(e.key)) operator(e.key);
                else if (e.key === 'Enter' || e.key === '=') equals();
                else if (e.key === 'Backspace') back();
                else if (e.key === 'c' || e.key === 'C' || e.key === 'Delete') clear();
                else if (e.key === '%') percent();
            };
            document.addEventListener('keydown', onKey);
            ctx.offs.push(() => document.removeEventListener('keydown', onKey));

            ctx.push(ui_view());
            function ui_view() {
                const v = ZP.ui.view({ title: 'Calculator', root: true, className: 'flush calc', body: h('div.calc', h('div.calc-screen', exprEl, display), pad) });
                return v;
            }
            paint();
        },
    });
})();
