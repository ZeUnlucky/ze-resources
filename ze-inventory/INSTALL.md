# Replacing qb-inventory with ze-inventory

**This has not been run in-game.** The Lua was checked for structure and cross-references and the UI was tested in a
browser, but nobody has started a server with it. Do the first run on a copy of the server or a quiet moment, with a
database backup, and read the console.

## Why there are two folders

`qb-core` only loads, saves and uses inventories while a resource named **`qb-inventory`** exists
(`GetResourceState('qb-inventory') ~= 'missing'`). Without it, `Player.PlayerData.items` is never loaded,
`QBCore.Functions.HasItem` silently returns `nil`, and nothing is saved.

So there are two resources in `[letr]`:

- `ze-inventory` — the real thing. It answers every `exports['qb-inventory']:...` call (the 14 used on this server, plus
  the rest of qb-inventory's API) and the `qb-inventory:client:ItemBox` / `requiredItems` style events.
- `qb-inventory` — an empty stand-in (manifest only) whose only job is to exist. Do not put code in it.

If you would rather have a single folder: rename `ze-inventory` to `qb-inventory`, delete the stand-in, and everything works
natively. The code detects its own name.

## Cutover

1. **Back up the database** (the `players` and `inventories` tables). Nothing is migrated; ze-inventory reads and writes
   the same `players.inventory` column and `inventories` table qb-inventory uses.
2. Stop the server.
3. **Move `resources/[qb]/qb-inventory` out of the resources folder entirely** (somewhere outside `resources`). Renaming it
   inside `[qb]` is not enough: `ensure [qb]` would still start it, and two inventories would fight over the same events.
4. Optional but recommended, in `server.cfg`, start the inventory right after `qb-core` so nothing asks for it before it exists:
   ```
   ensure qb-core
   ensure ze-inventory
   ensure qb-inventory
   ensure [qb]
   ```
   `ensure [letr]` later is then harmless (already started). It works without this too, since players only connect later.
5. Start the server. In the console you should see `N inventories loaded` and **no** red `[ze-inventory]` lines. Ten seconds
   after start it checks that the stand-in exists and that the original qb-inventory is not running, and says so if not.

To roll back: stop the server, move `qb-inventory` back into `[qb]`, remove `ze-inventory` and the stand-in.

## Things that behave differently from the original

These are deliberate fixes. Callers should not notice, except where they relied on a bug.

- **The server decides what a player may touch.** The UI names inventories by id, but the server only accepts the player's
  own inventory and the one it opened for them. Stock qb-inventory trusted whatever name the client sent.
- **Moves are atomic.** Everything is checked first, then applied. Stock removed from one inventory and then added to the
  other, so a failed add lost the item.
- **`AddItem` never overwrites a slot.** If the requested slot holds a different item, the first free slot is used. Stock
  overwrote it (or added to the wrong item).
- **`RemoveItem` without a slot** takes from the first stack that can cover the amount, otherwise from several stacks,
  lowest slot first. Stock only looked at one stack and failed if it was too small. With a slot it behaves exactly as before.
- **"First slot with an item" is always the lowest slot** (stock depended on table iteration order).
- Loaded items get `info = {}` when they had none (stock used an empty string).
- Stashes are saved when closed, every 5 minutes if changed, on resource stop and on txAdmin shutdown (stock: only on
  close, or on shutdown if open). Old rows load fine; new rows are stored as a list.
- Vehicle classes with no storage (`0` slots) say "This vehicle has no storage" instead of opening an enormous stash.
  The `default` entry in `Config.VehicleStorage` actually works now.
- `inventory:client:ItemBox` (without the `qb-`) is accepted too; `ze-evidence` uses that name.
- A shop item that has a stock number is removed from the shop once its stock reaches 0. Buying checks your cash, your
  room and the stock first, and refunds you if adding the item fails.

## Not carried over

- `qb-inventory:server:RobPlayer`: in stock it is a client event nobody on this server triggers.
- The old UI's weapon "attachments" side panel became "Remove <attachment>" entries in a weapon's right-click menu.

## Config

Everything lives in `config.lua`, using the same names as qb-inventory (`MaxWeight`, `MaxSlots`, `StashSize`, `DropSize`,
`Keybinds`, `VendingItems`, `VehicleStorage`, ...) plus `Config.UI` for the look (accent colour, currency).
