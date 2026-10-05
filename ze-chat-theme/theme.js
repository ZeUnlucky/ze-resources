// Tints each message's accent bar with the colour the message was sent in.
(function () {
    var COLOR_RE = /rgba?\([^)]*\)|#[0-9a-f]{3,8}/i;

    function tint(msg) {
        if (msg.dataset.zeTinted) return;

        var colored = msg.querySelector('[style*="color"]');
        var found = colored && colored.getAttribute('style').match(COLOR_RE);

        if (found) {
            msg.style.setProperty('--msg-accent', found[0]);
        }

        msg.dataset.zeTinted = '1';
    }

    function scan(root) {
        var msgs = root.querySelectorAll ? root.querySelectorAll('.msg') : [];
        for (var i = 0; i < msgs.length; i++) tint(msgs[i]);
    }

    function start() {
        scan(document);

        new MutationObserver(function (records) {
            for (var i = 0; i < records.length; i++) {
                var added = records[i].addedNodes;
                for (var j = 0; j < added.length; j++) {
                    var node = added[j];
                    if (node.nodeType !== 1) continue;
                    if (node.classList.contains('msg')) {
                        // content is rendered after insertion; wait a frame
                        requestAnimationFrame(function (n) {
                            return function () { tint(n); };
                        }(node));
                    } else {
                        scan(node);
                    }
                }
            }
        }).observe(document.body, { childList: true, subtree: true });
    }

    if (document.body) start();
    else document.addEventListener('DOMContentLoaded', start);
})();
