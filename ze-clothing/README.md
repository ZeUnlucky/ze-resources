# ze-clothing

A full replacement for `qb-clothing`: new NUI (vanilla HTML/CSS/JS, no jQuery, no Font Awesome, no CDNs), the same
events, exports, commands and database tables, same look as `ze-inventory` and `ze-hud` (the "Ember" theme: warm
charcoal glass panels, orange-to-amber accent gradient).

> **Status: never run in-game.** The Lua passed a block/bracket balance check and a cross-reference pass (every skin key,
> label, NUI callback and message matches on both sides), and was read through by hand. The UI was exercised in a
> browser with the Lua side faked (`dev/preview.html`). The first run in the game is the real test. See
> "First run checklist" below.

## What you get

| Piece | What it does |
| --- | --- |
| **Tabs** | Features, Hair & Face, Clothing, Accessories. Each shop opens only the tabs it needs (barber: Hair & Face, surgeon: Features, clothing store: Clothing + Accessories). |
| **Rows** | Every setting is a stepper, a slider and a number box. Holding a stepper repeats. Items and their variants (texture / colour / opacity) sit in the same card; the range follows the item. |
| **Camera** | Full body, head, torso, legs. `A` / `D` (or the round buttons, hold them) orbit the camera. |
| **Outfits** | *Presets* (job and gang locker rooms, by rank) and *My Outfits*. Wear, delete (two clicks) and save from the bookmark button. |
| **Esc / Cancel** | Puts back the skin from when the menu opened, including the model if the surgeon menu changed it. |

## Cutting over from qb-clothing

`qb-clothing` and `ze-clothing` answer the same events (`qb-clothing:client:loadOutfit`, `qb-clothes:loadSkin`, ...) and
use the same database tables, so only one may run. `ze-clothing` refuses to start if it finds the original running.

1. Move `resources/[qb]/qb-clothing` **out of `resources` entirely** (a backup folder next to `resources` is fine, renaming it inside `[qb]` is not enough because the resource name is what counts):

   ```powershell
   Move-Item -LiteralPath 'C:\path\to\resources\[qb]\qb-clothing' -Destination 'C:\path\to\backup\qb-clothing'
   ```

2. `ze-clothing` and the stand-in `qb-clothing` both live in `[letr]`, which `server.cfg` already ensures, so there is nothing to add.
3. Restart the server.

**Why there is a second folder called `qb-clothing` in `[letr]`:** `qb-houses` and `qb-apartments` list `'qb-clothing'`
in their `dependencies`, so a resource with that name has to exist or they will not start. The stand-in has no code, it
only depends on `ze-clothing`. (Alternative: rename this folder to `qb-clothing` and delete the stand-in. The code detects its own name.)

Existing characters keep their clothes and outfits: the `playerskins` and `player_outfits` tables are used as they are
(`ze-clothing.sql` is the same schema, only needed on a fresh database).

## Things that differ from qb-clothing

* **English only.** The four extra locale files are gone. Everything the menu says is in `locales/en.lua` (`ui.*`), and the menu has built-in English as a fallback.
* **Face features run from -10 to 10.** qb-clothing allowed 0 to 30 (which GTA reads as 0.0 to 3.0, but the game only defines -1.0 to 1.0). Old saves with values above 10 still load exactly as before and display with their own range.
* **Props: 0 means "none".** Hat, glasses, ear piece, watch and bracelet number 0 were shown while editing in qb-clothing but never loaded back (a saved 0 or -1 both counted as "no prop"). The menu now matches what loads, so the first real item is 1.
* **Moles / freckles** start at full opacity when you pick a type (qb-clothing started at 0, so nothing showed until you raised it). Ageing no longer has a colour row (it never did anything).
* **Colour ranges are the full palette** (0-63 for hair, eyebrows, beard, make-up, lipstick, blush; qb-clothing stopped at 45), and skin tone for the parents goes to 45 (it stopped at 15).
* **Item ranges are exact.** qb-clothing let you step one past the last item, which does nothing.
* **Outfits only change clothes.** Wearing an outfit no longer overwrites face, hair or make-up in the saved skin. Saved outfits still contain the full skin, so old ones work.
* **Outfit limit and checks.** `Config.MaxOutfits` (default 50) caps saved outfits per character, names are trimmed and limited to 40 characters, and what the client sends to the server is validated.
* **Fixes carried over from reading qb-clothing:** `cheek_2` and the neck thickness wrote into the wrong slot in the saved skin; glasses could not be cleared; Cancel did not divide face features by 10 (so face features jumped); `qb-clothes:loadSkin` waited forever for a new character's missing model; a model that does not exist (or an out-of-range model number) hung or errored; `A` / `D` rotated the camera while typing in a box; the language mechanism sent garbage keys to the menu; the store zones and targets were built again after every character switch (they are now built once).
* **New:** the menu follows the screen resolution, saves show a notification, clicking through models quickly only loads the last one, the skin is picked up again when the resource is restarted with a player in.
* The `/clothing` admin menu, `/refreshskin`, the E prompt (or `qb-target` when `UseTarget` is true) and the blips work as before.

## Config (`config.lua`)

* `Config.Accent`: UI accent colour (`#ff7a1a` matches `ze-inventory` and `ze-hud`). The gradient partner colour is derived from it.
* `Config.ModelSwitch`: show the "Player model" picker in the Features tab (plastic surgeon, first character, `/clothing`). It lets a player become any ped in the lists. qb-clothing always had it; turn it off if you do not want that.
* `Config.MaxOutfits`, `Config.CursorStart`.
* Everything else (`Stores`, `OutfitChangers`, `ClothingRooms`, `Outfits`, the model lists, `UseTarget`) is unchanged from qb-clothing.

## Events and exports other resources use

Unchanged from qb-clothing, and nothing else on this server needed editing:

| Name | Side | Use |
| --- | --- | --- |
| `qb-clothing:client:loadOutfit({ outfitData, outfitName })` | client | put an outfit on (prison, police tracker, parachute). Only clothing and accessory keys are applied. |
| `qb-clothing:client:loadPlayerClothing(skin, ped)` | client | dress a ped with a full skin (`qb-multicharacter` uses it for its preview ped) |
| `qb-clothing:client:openMenu` | client | full menu (`qb-adminmenu` `/clothing`) |
| `qb-clothing:client:openOutfitMenu` | client | saved outfits only (`qb-houses`, `qb-apartments`, `qb-management`) |
| `qb-clothes:client:CreateFirstCharacter` | client | new character (`qb-multicharacter`, `qb-interior`) |
| `qb-clothing:client:adjustfacewear(type)` | client | take a hat / glasses / ear piece / mask / top off or on with an animation |
| `qb-clothes:loadPlayerSkin` | server | load the saved skin and send it back (`qb-prison`, login) |
| `qb-clothing:saveSkin`, `qb-clothes:saveOutfit`, `qb-clothing:server:removeOutfit`, `qb-clothing:server:getOutfits` | server | the menu's own saves |
| `qb-clothing:client:onMenuClose` | client | fired when the menu closes |
| exports `reloadSkin`, `IsCreatingCharacter`, `getOutfits` | client | also answer as `exports['qb-clothing']` through the stand-in |

## NUI contract

Lua to NUI (`SendNUIMessage`):

* `open` `{ title, menus, values, hasTracker, modelSwitch, model, tr, accent }`. `menus` is a list of `{ menu, label, selected, outfits }` with `menu` one of `features`, `hair`, `clothing`, `accessories`, `presets`, `outfits`. `values` maps every skin key to `{ item, texture, minItem, maxItem, hasTexture, minTexture, maxTexture }` (`facemix` is `{ shapeMix, skinMix }`). `tr` replaces the built-in text.
* `values` `{ values, model }`: everything changed at once (an outfit was worn, the model was switched).
* `outfits` `{ outfits }`: the player's saved outfits changed.
* `close`: hide the menu without answering.

NUI to Lua (`RegisterNUICallback`): `updateSkin { clothingType, type, articleNumber }` (replies with that row's new state, because changing an item resets its texture and changes its range), `close { save }`, `selectOutfit`, `saveOutfit { outfitName }`, `removeOutfit { outfitName, outfitId }`, `setCurrentPed { ped }`, `setupCam { value }`, `rotateLeft`, `rotateRight`.

The skin engine (`client/skin.lua`) holds one definition per skin key and one function that applies it, so a new setting is one line there plus one row in `SCHEMA` in `html/script.js`.

## Previewing the UI without the game

`dev/preview.html` loads the real NUI in an iframe and fakes what the Lua answers (every shop type, locker room with presets, tracker lock, model switch on/off, outfits). It is not listed in `files{}`, so it is never sent to players.
Browsers do not load scripts and styles reliably from `file://`, so serve the `resources` folder over HTTP.
`dev/serve.ps1` does that with plain PowerShell (no Node or Python needed):

```powershell
powershell -ExecutionPolicy Bypass -File .\dev\serve.ps1
# then open http://localhost:8765/%5Bletr%5D/ze-clothing/dev/preview.html
# add ?fit=1080 to see it in a real 1920x1080 frame, and #room (or #full, #barber, ...) to open a scene at once
```

NUI notes: FiveM's embedded Chromium is older, so the CSS avoids `:has()`, `color-mix()`, nesting and `backdrop-filter`.

## First run checklist

1. Watch the server console and F8 for Lua errors at start. If `ze-clothing` prints that the original qb-clothing is running, finish the cutover above.
2. Log in: your clothes and face load as before (same database rows).
3. Walk to a clothing store (`E`, or the target eye with `UseTarget`): try a jacket and its variants, a hat, then Cancel (everything must go back) and open again and Confirm (it must stay after relogging).
4. Barber and plastic surgeon: change hair and colour, a few face sliders, the parent mix. Switch the player model if `ModelSwitch` is on and Cancel.
5. Save an outfit, wear it, delete it (two clicks). A police locker room should list its presets for your rank.
6. Cuff / tracker: with a tracker on, the neck accessory row is locked and the notification appears if you try it.
7. Create a new character (`qb-multicharacter`): the full menu opens on the freemode model of the chosen gender.
8. Tell me what is off (camera heights, ranges on a custom ped pack, anything that looks wrong at your resolution) and I will tune it.
