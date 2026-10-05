# ze-interiors: house manager menu

An admin menu for managing houses, in the same "Ember" theme as ze-inventory, ze-hud and ze-clothing. Open it with `/houses` (whoever may run the command may use the menu: QBCore's `admin` group, or anyone with the `command.houses` ACE such as `group.admin` in server.cfg; `PERMISSION` at the top of `server/menu.lua` picks the group, and every callback checks the ACE too).

## Setup

Import `ze_houses.sql`, and start `oxmysql` before this resource. Houses live in the `ze_houses` table: `Config.Houses` starts empty, the server fills it from the table (`server/houses.lua`) and syncs it to the clients, which build the qb-target door zones from it. Interiors stay in `shared/config.lua`. A house whose interior is missing from the config, or whose entrance count no longer matches the interior's exits, is skipped at load with a console warning (its row is left alone).

The menu has three tabs:

- **Houses**: searchable list with owner, lock state and entrance count, and a Sell and a Delete button on every row. Delete asks for confirmation.
- **Add house**: name, interior, and one entrance per exit of the chosen interior. The Create button stays disabled until every entrance has coordinates. "Use my position" fills an entrance from where you stand, and pasting a `vector4(...)` into any coordinate box fills all four.
- **Sell house**: pick a house and type the buyer's server id. The buyer's name is looked up while you type.

## Files

| File | What it does |
| --- | --- |
| `html/` | The menu UI. |
| `client/menu.lua` | Opens the NUI and relays each NUI callback to the server. |
| `client/client.lua` | qb-target zones. House doors are rebuilt when the server syncs a house. |
| `server/houses.lua` | Loads `ze_houses`, and the only place that writes to it: `Houses.Create / SetOwner / SetLocked / Delete`. Syncs every change to the clients. |
| `server/menu.lua` | The command, the permission check and the menu callbacks (validation, then a call into `Houses`). |
| `server/server.lua` | Enter, exit, stash and lock events. Locking is saved. |

What the actions do besides the table: **selling** sets the owner and clears the keyholders, and notifies the buyer. **Deleting** puts anyone still inside back on the first entrance, then empties the stash (`interiorStash<id>`) and removes it from the inventory. `ownerName` in `getData` is read from the `players` table, so it also works for offline owners.

## Contract

Server callbacks (all return nothing / `ok = false` without the permission):

| Callback | Receives | Replies |
| --- | --- | --- |
| `ze-interiors:menu:getData` | | `{ interiors = { {id, name, exits} }, houses = { {id, name, interiorName, entrances, owner, ownerName, locked} } }` |
| `ze-interiors:menu:lookupPlayer` | `{ id }` | `{ ok, name, citizenid }` or `{ ok = false, error }` |
| `ze-interiors:menu:createHouse` | `{ name, interior, entrances = { {x, y, z, w} } }` | `{ ok, error?, message? }` |
| `ze-interiors:menu:sellHouse` | `{ house, player }` | `{ ok, error?, message? }` |
| `ze-interiors:menu:deleteHouse` | `{ house }` | `{ ok, error?, message? }` |

`interior` and `house` are the ids from `getData`, `player` is a server id, `w` is the heading. The UI makes sure `#entrances` equals the interior's exit count, but re-check it in `createHouse`. After an `ok` reply the UI reloads the lists with `getData`, so the server has nothing else to push. `error` is shown to the admin as a red toast, `message` replaces the default green one.

NUI messages from the client: `open { interiors, houses, accent? }`, `data { interiors, houses }` (refreshes the lists while the menu is open) and `close`. NUI callbacks to the client: `close`, `getData`, `getPosition`, `lookupPlayer`, `createHouse`, `sellHouse`, `deleteHouse`.

## Previewing the UI without the game

`dev/` is not part of `files{}` and never reaches players. Run `dev/serve.ps1`, then open `http://localhost:8765/%5Bletr%5D/ze-interiors/dev/preview.html#open`. The page fakes the Lua side, with a toggle that makes every action fail so you can see the error toast. Add `?fit=1080` to see a true 1920x1080 frame.
