# ze-phone

Replacement for `qb-phone`: new vanilla NUI (Ember theme, no jQuery or CDNs), server-authoritative calls and messages,
same events, exports and tables.

> **Status: unfinished and never run in-game.** Written but not yet checked: Lua syntax/cross-reference pass, a full
> click-through of every app in `dev/preview.html`, and the NUI contract docs. Only the home screen, Phone (Recents) and
> Messages were looked at in the browser preview. Expect bugs.

## Cutover
1. Move `resources/[qb]/qb-phone` out of `resources` entirely (a rename inside `[qb]` is not enough).
2. `ze-phone` and the stand-in `qb-phone` live in `[letr]`, which `server.cfg` already ensures.
3. Restart. Tables are created at start (`IF NOT EXISTS`); three columns are added to `phone_messages`, and `phone_gallery.image` is widened to 500.
4. Camera: set a provider in `config.server.lua` (default `none`). Discord CDN links expire; prefer fivemerr/custom.

## Apps
Phone, Messages, Camera, Settings, Twitter, Mail, Bank, Crypto, Vehicles, Houses, Racing, Services, Adverts, Gallery,
Maps, Notes, Clock, Calculator, MDT (jobs in `Config.MDT`). Edit `Config.Apps` to remove or gate any.

## Changes from qb-phone
Server owns calls (unique channel per call, cleaned on disconnect), messages (no client-written histories), invoices
(amount from the database), MDT (job checked per request, no SQL string building). Mail buttons run from the stored row.
Per-conversation unread counts persist. Trucker and Store apps are dropped (they never worked).

## Dev
`dev/serve.ps1`, then `http://localhost:8765/%5Bletr%5D/ze-phone/dev/preview.html?fit=520&z=1.15#open`.

## First run checklist
Watch the server console and F8; open the phone (M); call, message, pay an invoice; check each app against its resource.
