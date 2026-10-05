# ze-interiors: house manager menu

An admin menu for managing houses, in the same "Ember" theme as ze-inventory, ze-hud and ze-clothing. Open it with `/houses` (whoever may run the command may use the menu: QBCore's `admin` group, or anyone with the `command.houses` ACE such as `group.admin` in server.cfg; `PERMISSION` at the top of `server/menu.lua` picks the group, and every callback checks the ACE too).

## Setup

Import `ze_houses.sql`, then `ze_buildings.sql` and `ze_houses_apartments.sql` (apartments, see below), and start `oxmysql` before this resource. The houses query reads the `building` and `floor` columns, so the apartments SQL has to be imported before the resource starts. Houses live in the `ze_houses` table: `Shared.Houses` starts empty, the server fills it from the table (`server/houses.lua`) and syncs it to the clients, which build the qb-target door zones from it. Interiors stay in `shared/config.lua`. A house whose interior is missing from the config, or that has no entrance on exit 1, is skipped at load with a console warning (its row is left alone). An entrance that points at an exit the interior no longer has is ignored with a warning.

**Entrances and exits.** An interior can have any number of `exits` in `Config.Interiors`. A house always has an entrance on exit 1; entrances on the other exits are optional. The `entrances` column is a JSON list of `{ exit, x, y, z, w }`, and `Shared.Houses[id].entrances` is keyed by exit number and can have holes, so walk it with `pairs`. Rows saved before this (a plain list without `exit`) still load: the position in the list is the exit. Inside a house, the Exit / Lock / Unlock options at an exit only show when the house has an entrance on that exit.

**Buildings and apartments.** A building (`ze_buildings`: name, entrance, number of floors) is a door that a group of apartments share. An apartment is a normal `ze_houses` row with a `building` and a `floor` (1 to the building's floors); both are `NULL` for a house. An apartment has no entrances of its own: its only entrance (exit 1) is the building's door, so leaving an apartment puts you back there, and its owner, keys, lock, stash and sale work like a house's. The clients get the buildings from the server (`ze-interiors:SyncBuildings` / `SyncBuilding`, always before the houses). An apartment gets no door zone of its own: the building gets one qb-target zone at its entrance with an **Apartments** option, which fires the client event `ze-interiors:OpenBuilding` with the building id and opens the building menu (see below). Set waypoint on an apartment leads to the building's entrance, and an owner gets one map blip per building (named after it) however many apartments they own there. A building with apartments cannot be deleted. `server/buildings.lua` is the only writer of `ze_buildings`; buildings load before houses.

The menu has four tabs:

- **Houses**: searchable list with owner, lock state and entrance count ("2 of 3 entrances" when the interior has more exits than the house has entrances), and a Set waypoint, a Sell and a Delete button on every row. Set waypoint marks the first entrance on the map (the client already holds every house, so it needs no server call). Delete asks for confirmation.
- **Add house**: name, interior, and a card per exit of the chosen interior. Entrance 1 is required, the others are optional: leave a card empty (or press its X) and that exit simply does not exist for the house. The Create button stays disabled until entrance 1 is complete and no other card is half filled. "Use my position" fills an entrance from where you stand, and pasting a `vector4(...)` into any coordinate box fills all four.
- **Add house, apartment**: at the top of the form a House / Apartment switch. An apartment is a name, an interior, a building and a floor of that building (the floor list follows the building's number of floors); the entrance cards are replaced by those two selects. The Create button stays disabled until all four are set. Buildings must exist first (Buildings tab).
- **Buildings**: the list (floors, apartment count, a Delete button that is disabled while the building still has apartments) and a form to create one: name, number of floors (a whole number from 1 to 200) and the entrance (the same card as a house entrance: Use my position or typed coordinates).
- **Edit house**: the Edit button on a house row opens the Add house form filled in with that house (the tab turns into "Edit house"). You can change the name and the entrances; the interior is fixed (it is shown, locked), because people can be standing inside it, so use Delete and Add to switch interior. Below the entrances, the form has a **Lock, owner and keys** section that saves on its own: every change there (lock/unlock, set or remove the owner by player id, give a key by player id, take a key back with its X) is written to `ze_houses` the moment you make it, without Save changes. Setting or removing an owner clears the keys, like selling does. Keys can only be given while the house has an owner. The entrances you send replace the old ones, so emptying an optional card removes that entrance, and entrance 1 stays required. Save changes calls `updateHouse`; Cancel goes back to the list.
- **Sell house**: pick a house and type the buyer's server id. The buyer's name is looked up while you type.

## Files

| File | What it does |
| --- | --- |
| `html/` | The menu UI. |
| `client/menu.lua` | Opens the NUI and relays each NUI callback to the server. |
| `client/client.lua` | qb-target zones and the owner's map blips (green house icon on the first entrance, only on the owner's own map; one per building for apartments) and the building entrance zones. Doors and blips are rebuilt when the server syncs a house or a building, and the blips again when a character loads or logs out. |
| `server/houses.lua` | Loads `ze_houses`, and the only place that writes to it: `Houses.Create / Update / SetOwner / SetLocked / Delete`. Syncs every change to the clients. |
| `server/menu.lua` | The command, the permission check and the menu callbacks (validation, then a call into `Houses`). |
| `server/server.lua` | Enter, exit, stash and lock events. Locking is saved. |
| `server/keys.lua` | The `/givekeys` command (see below). Not connected to the menu. |
| `client/lobby.lua`, `server/lobby.lua` | The building menu (see below). |

## Building menu (floors and apartments)

The **Apartments** option at a building's entrance opens a menu with every floor of the building (floors without apartments are listed too, and show an empty state). A floor opens the list of its apartments; the arrow in the header or Escape goes back a step, Escape on the floors closes the menu. It is a separate overlay in the same NUI page (`#lobby`), not part of the house manager.

Each apartment shows whether it is locked and what it is to you: **Yours**, **Key** (you hold a key), **Vacant** (nobody owns it) or **Occupied**. Other tenants' names are never sent. The buttons depend on what you may do right now, and the server decides:

| Locked | Buttons |
| --- | --- |
| no | **Enter**, and **Lock** if you own it or hold a key |
| yes | **Unlock** if you own it or hold a key, **Breach** for the `police` job, **Lockpick** if you carry a `lockpick` |

Server callbacks (everyone may call them, every call is checked): `ze-interiors:lobby:getBuilding` `{ building }` replies `{ ok, building = { id, name, floors = { { floor, apartments = { { id, name, status, locked, actions } } } } }, error? }`, and `ze-interiors:lobby:act` `{ house, action }` (`enter`, `lock`, `unlock`, `breach`, `lockpick`) replies `{ ok, message?, error? }`. Both require you to stand within 6 m of the building's entrance, outside, and `act` refuses an action that is not in the apartment's `actions`. Entering uses the same `Houses.Enter` as the house doors, and leaving puts you back at the building's door. NUI messages: `openLobby { building }` / `closeLobby` from Lua, and `lobbyGet`, `lobbyAct`, `lobbyClose` back.

What the actions do besides the table: **selling** sets the owner and clears the keyholders, and notifies the buyer. **Deleting** puts anyone still inside back on the first entrance, then empties the stash (`interiorStash<id>`) and removes it from the inventory. `ownerName` in `getData` is read from the `players` table, so it also works for offline owners.

## Keys

The owner of a house gives a friend a key with `/givekeys [player id] [house id]`. The house id is optional: without it the house is the one the owner is inside, or the nearest entrance of theirs within 5 m, or their only house. Rules, all checked on the server: only the owner can give keys (a keyholder cannot pass them on), the friend has to be online, within 5 m and in the same routing bucket, and a player who already has a key is refused.

A key is the friend's citizenid in the `keyholders` JSON array of the house's row in `ze_houses`. `Houses.AddKeyholder(id, citizenid)` saves it first and only then changes `Shared.Houses` and syncs the clients, so a database failure leaves nothing half done. Selling the house still clears the keyholders.

`/takekeys [player id | all] [house id]` takes a key back, with the same house rules as `/givekeys`. A player id removes that friend's key (they have to be online but not nearby); `all` removes every key of the house, which is how a friend who is offline loses theirs. `Houses.RemoveKeyholders(id, citizenid)` does the database write the same way (citizenid `nil` = all keys). A keyholder sees Lock Doors / Unlock Doors on the front door like the owner does; the server sends `keyholders` to the clients for that.

## Contract

Server callbacks (all return nothing / `ok = false` without the permission):

| Callback | Receives | Replies |
| --- | --- | --- |
| `ze-interiors:menu:getData` | | `{ interiors = { {id, name, exits} }, buildings = { {id, name, floors, apartments, entrance = {x, y, z, w}} }, houses = { {id, name, building?, buildingName?, floor?, interior, interiorName, entrances, entranceList = { {exit, x, y, z, w} }, exits, owner, ownerName, locked, keyholders = { {citizenid, name} }} } }` (`entrances` = how many are set, `exits` = how many the interior has, `entranceList` fills the edit form) |
| `ze-interiors:menu:lookupPlayer` | `{ id }` | `{ ok, name, citizenid }` or `{ ok = false, error }` |
| `ze-interiors:menu:createHouse` | `{ name, interior, entrances = { {exit, x, y, z, w} } }`, or for an apartment `{ name, interior, apartment = true, building, floor }` | `{ ok, error?, message? }` |
| `ze-interiors:menu:updateHouse` | `{ house, name, entrances = { {exit, x, y, z, w} } }`, or for an apartment `{ house, name, building, floor }` | `{ ok, error?, message? }` |
| `ze-interiors:menu:createBuilding` | `{ name, floors, entrance = {x, y, z, w} }` | `{ ok, error?, message? }` |
| `ze-interiors:menu:deleteBuilding` | `{ building }` | `{ ok, error?, message? }` (refused while it has apartments) |
| `ze-interiors:menu:setLocked` | `{ house, locked }` | `{ ok, error?, message? }` |
| `ze-interiors:menu:setOwner` | `{ house, player }` | `{ ok, error?, message? }` (notifies the new owner) |
| `ze-interiors:menu:removeOwner` | `{ house }` | `{ ok, error?, message? }` |
| `ze-interiors:menu:addKey` | `{ house, player }` | `{ ok, error?, message? }` |
| `ze-interiors:menu:removeKey` | `{ house, citizenid }` | `{ ok, error?, message? }` |
| `ze-interiors:menu:sellHouse` | `{ house, player }` | `{ ok, error?, message? }` |
| `ze-interiors:menu:deleteHouse` | `{ house }` | `{ ok, error?, message? }` |

`interior` and `house` are the ids from `getData`, `player` is a server id, `w` is the heading. `exit` is the exit number of the interior (1 to its exit count). The UI always sends exit 1 and only the other exits that were filled in, but `createHouse` re-checks that: exit 1 present, no duplicates, no exit the interior does not have. After an `ok` reply the UI reloads the lists with `getData`, so the server has nothing else to push. `error` is shown to the admin as a red toast, `message` replaces the default green one.

NUI messages from the client: `open { interiors, houses, accent? }`, `data { interiors, houses }` (refreshes the lists while the menu is open) and `close`. NUI callbacks to the client: `close`, `getData`, `getPosition`, `setWaypoint` (`{ house }`, answered by the client itself with `{ ok, message?, error? }`), `lookupPlayer`, `createHouse`, `updateHouse`, `sellHouse`, `deleteHouse`.

## Previewing the UI without the game

`dev/` is not part of `files{}` and never reaches players. Run `dev/serve.ps1`, then open `http://localhost:8765/%5Bletr%5D/ze-interiors/dev/preview.html#open`. The page fakes the Lua side, with a toggle that makes every action fail so you can see the error toast. Add `?fit=1080` to see a true 1920x1080 frame.
