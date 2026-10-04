# ze-inventory UI

The message contract between the Lua side (`client/main.lua`) and the NUI (`html/`). You only need this if you change the
UI or want to drive it from another resource.

The UI never decides what is allowed. It shows what it is sent, predicts moves locally so dragging feels instant, then
**rolls back if Lua answers no**. The server is the authority; every reply carries fresh snapshots so the UI always ends up
showing what the server really has.

Files: `html/index.html`, `html/style.css`, `html/script.js`, `html/images/*.png` (shipped) and `html/dev/mock.js`
(browser preview only, not in the manifest).

## Lua → UI (`SendNUIMessage`)

| `action` | Payload | What it does |
|---|---|---|
| `open` | `config?`, `player`, `other?` | Opens the inventory. Omit `other` for a solo view. |
| `update` | `config?`, `player?`, `other?` | Replaces whichever inventories are included. `other = false` removes the second panel. |
| `close` | – | Closes the UI (does **not** fire the `close` callback). |
| `hotbar` | `items`, `active?`, `persist?`, `show?` | Quick-slot bar while the inventory is closed. `active` highlights a slot. `persist = true` keeps it up until `show = false`; otherwise it fades after `hotbarMs`. |
| `itemBox` | `name`, `label`, `image?`, `amount?`, `kind` | Small notice above the bar. `kind` is `add`, `remove` or `use`. |
| `requiredItem` | `items = { { item, label, image } }`, `toggle` | The "Required" card some resources show near doors and terminals. |
| `notify` | `message`, `type?` | Toast inside the inventory. `type` is `ok` or `err` (default). |

### Inventory object (`player` / `other`)

```lua
{
    id        = 'stash_mrpd',        -- sent back in callbacks. 'player' is always the player's own inventory
    type      = 'stash',             -- player | stash | trunk | glovebox | drop | shop | otherplayer  (picks the icon)
    label     = 'Mission Row Lockers',
    sub       = 'Stash',             -- optional small text under the title (defaults to the type name)
    maxWeight = 200000,              -- grams. 0 or nil = no limit
    slots     = 30,
    readonly  = false,               -- true = items can be taken out but not put in (shops always are)
    money     = { cash = 500, bank = 5000 },  -- optional, shown in the header
    items     = { ... },
}
```

### Item object

```lua
{
    name = 'bandage', label = 'Bandage', slot = 2, amount = 5,
    weight = 100,                    -- grams, PER UNIT
    type = 'item',                   -- 'weapon' gets a red tint and tag
    image = 'bandage.png',           -- appended to config.imagePath
    unique = false, useable = true,
    description = 'A simple bandage...',
    info = { quality = 87, serie = 'AB123' },   -- quality (0-100) draws a bar; other keys show in the tooltip
    price = 25,                      -- shops only
    attachments = { { attachment = 'pistol_suppressor', label = 'Suppressor' } },  -- weapons only
}
```

`items` can be an array or a table keyed by slot. Always include `slot`. An empty Lua table reaches JS as `[]`; the UI
handles that. Keys in `info` starting with `_` are hidden from the tooltip.

### `config` (all optional, on `open` or `update`)

```lua
config = {
    imagePath   = 'nui://ze-inventory/html/images/',  -- default, the images shipped in this resource
    currency    = '$',
    hotbarSlots = 5,                 -- player slots 1..N are the quick slots
    hotbarMs    = 3500,
    closeKeys   = { 'Escape', 'Tab' },
    accent      = '#5eead4',         -- one colour re-themes the whole UI
}
```

`Config.UI` in `config.lua` feeds these.

## UI → Lua (`RegisterNUICallback`)

Every callback must call `cb(...)`. `cb(false)` or `cb({ ok = false, message = '...' })` rejects an action: the UI undoes its
prediction and shows `message`. Anything else accepts it. If an `update` arrives before the reply, the UI keeps that data
and skips the rollback.

| Callback | Data | Fired when |
|---|---|---|
| `ready` | `{}` | UI finished loading. |
| `close` | `{}` | The player pressed a close key or the ✕. |
| `moveItem` | `{ from = {id, type, slot}, to = {id, type, slot}, amount, name }` | Drag, shift-click or context menu. `to.slot` is already resolved. Buying from a shop is a `moveItem` whose source is a `shop` inventory. |
| `useItem` | `{ slot, name }` | Double-click, context menu, or dropped on the Use zone. |
| `giveItem` | `{ slot, amount, name }` | Dropped on the Give zone or context menu. |
| `dropItem` | `{ slot, amount, name }` | Dropped on the Drop zone or context menu. |
| `removeAttachment` | `{ slot, name, attachment }` | "Remove <attachment>" in a weapon's menu. |

The `Amount` box sets `amount` (empty means the whole stack).

The context menu also has client-side "Copy ..." entries (no callback; they copy to the clipboard) driven by `COPYABLE` in
`script.js`: weapons copy `info.serie`, `casing` copies `info.serialNumber`, `usedfingerprinttape` copies `info.fingerprint`
(an array is joined with `, `) and `blood_vial` copies `info.DNA`. An item without that value gets no entry.

## Where the Lua lives

| File | Role |
|---|---|
| `client/main.lua` | NUI bridge, key mappings, quick-slot bar, notices, attachments |
| `client/drops.lua`, `client/vehicles.lua` | Ground bags, trunk and glovebox |
| `server/moves.lua` | Containers, what the UI is sent, the move/drop/give/purchase engine |
| `server/functions.lua` | The inventory API (`AddItem`, `RemoveItem`, `HasItem`, ...) |
| `server/compat.lua` | Registers the API as `exports['ze-inventory']` and `exports['qb-inventory']` |

See `INSTALL.md` for setup.

## Previewing without the game

Serve the `resources` folder (or just open `html/index.html`) in a normal browser. `html/dev/mock.js` loads automatically,
fills the UI with qb-core items and adds a DEV bar: stash / solo / shop / trunk, quick-slot bar, notices, the required-items
card, and a switch that makes every action fail so you can see the rollback. Every callback is logged to the console as
`[NUI → Lua]`.

## Notes

- Weights are grams everywhere (QBCore's convention); the UI shows kilograms.
- FiveM's NUI browser is an older Chromium, so the CSS avoids `:has()`, `color-mix()`, nesting and `backdrop-filter`.
- Item text is always inserted with `textContent`, never HTML, so names and `info` values can't inject markup.
