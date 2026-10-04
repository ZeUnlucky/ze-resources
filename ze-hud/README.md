# ze-hud

A full replacement for `qb-hud`: new NUI (vanilla HTML/CSS/JS, no CDNs, no Vue/Quasar/Font Awesome), the same
events and commands, same look as `ze-inventory` (dark glass panels, teal accent).

> **Status: never run in-game.** The Lua passed a block/bracket balance check and was read through by hand, and
> the UI was exercised in a browser with simulated data (`dev/preview.html`). The first run in the game is the
> real test. See "First run checklist" below.

## What you get

| Piece | What it does |
| --- | --- |
| **Vitals dock** | Voice (3 range pips, talking glow, radio channel), health, armor, hunger, thirst, stress, stamina / oxygen. Tiles fill from the bottom, turn rose and pulse when low, health becomes a skull when dead. Tiles can auto-hide while there is nothing to report. |
| **Chips** | `Armed`, `Chute`, `Dev` above the dock. |
| **Minimap frame** | Corner brackets (square) or arcs (circle) around the minimap, with an inner vignette. |
| **Compass** | Scrolling heading tape with N/E/S/W marks, degrees, street, cross street and area name. |
| **Money** | Cash and bank pills that slide in on change with a floating `+$250` / `-$40` and a count-up, or on `/cash` and `/bank`. |
| **Vehicle card** | Speed arc with leading zeros dimmed, RPM arc, gear (`R`/`N`/`1-6`), fuel, engine health, nitrous, altitude for aircraft, seatbelt / harness / cruise chips. |
| **Settings menu** | `I` (or `/hudmenu`). Five tabs, toggles, square/circle switch, cinematic mode, restart, reset. |

## Cutting over from qb-hud

`qb-hud` and `ze-hud` listen to the same events, ship the same minimap files and fight over the radar, so only one may run.

1. Move `resources/[qb]/qb-hud` **out of `resources` entirely** (a backup folder next to `resources` is fine):

   ```powershell
   Move-Item -LiteralPath 'C:\path\to\resources\[qb]\qb-hud' -Destination 'C:\path\to\backup\qb-hud'
   ```

2. `ze-hud` lives in `[letr]`, which `server.cfg` already ensures (after `[qb]`), so there is nothing to add.
3. Restart the server (or `ensure ze-hud` after stopping `qb-hud`).

Nothing else on this server references the `qb-hud` resource name; only `qb-adminmenu` mentions it in a label.

## Things that differ from qb-hud

* **Command and key:** `/menu` is now `/hudmenu` (default key is still `I`, set in `Config.OpenMenu`). `/resethud`, `/cash`, `/bank` and `/dev` are unchanged.
* **Settings are not carried over.** They are stored in resource KVP under the resource name, so everyone starts from `Config.Defaults`.
* **Sounds are GTA frontend sounds,** so `interact-sound` is no longer needed by the HUD. (The sounds themselves are different.)
* **English only.** The 19 locale files are gone; there are only 10 strings.
* **Removed events** (nothing here uses them): `hud:client:ToggleAirHud`, `ToggleShowSeatbelt`, `ToggleHealth`, `LoadMap`, `resetStorage`, the `play*Sounds` events and the `hud:server:getMenu` callback.
* **Hunger / thirst / stress** are also read from the player's metadata on load, so they are right before the first `UpdateNeeds`.
* **Fixes carried over from reading qb-hud:** the armed chip no longer sticks after switching to a whitelisted weapon; the bicycle check used an entity where a model was expected; `hud:server:GainStress` indexed the player before checking it existed; stress amounts sent by clients are now capped (gain 20, relief 100) and must be numbers.
* **New:** gear and RPM, zone name under the street, oxygen vs stamina icon, fuel / nitrous / engine bars, count-up money.

## Config (`config.lua`)

* `Config.UseMPH`, `Config.SpeedMax`: unit and the speed that fills the arc.
* `Config.Accent`: UI accent colour (`#5eead4` matches `ze-inventory`).
* `Config.Currency`: locale and currency code for the money display.
* `Config.FuelResource`: any resource exporting `GetFuel(vehicle)` (`qb-fuel` provides `LegacyFuel`). If it errors, the fuel bar simply hides.
* `Config.VoiceRanges`: pma-voice ranges, shortest first.
* `Config.Tick`: refresh rates for the "Optimized" and "Synced" modes.
* `Config.Defaults`: the starting value of every player setting (what "Reset to defaults" restores).
* Stress block: the same keys as qb-hud (`StressChance`, `MinimumStress`, `WhitelistedJobs`, `VehClassStress`, ...).

### If the minimap frame does not line up

The frame is a NUI box laid over the game's minimap, so it depends on screen shape. `Config.MapFrame` holds its
position and size in vh for each shape (the defaults are what `qb-hud` used at 1920x1080). Nudge `left`,
`bottom`, `width` and `height` until the brackets sit on the map edge, and make sure the GTA safezone is on its default
(Settings > Display > Restore Defaults). Ultrawide screens get the same horizontal correction `qb-hud` applied to the map itself.

## Events other resources can use

Unchanged from qb-hud:

| Event | Side | Use |
| --- | --- | --- |
| `hud:client:UpdateNeeds(hunger, thirst)` | client | set hunger / thirst |
| `hud:client:UpdateStress(stress)` | client | set stress (server sends it) |
| `hud:client:UpdateNitrous(level, hasNitro)` | client | nitrous bar |
| `hud:client:UpdateHarness(hp)` | client | accepted, harness chip comes from the `harness` item |
| `hud:client:ShowAccounts(type, amount)` | client | show a money pill |
| `hud:client:OnMoneyChange(type, amount, isMinus)` | client | qb-core triggers this |
| `hud:server:GainStress(amount)` / `hud:server:RelieveStress(amount)` | server | change stress |
| `seatbelt:client:ToggleSeatbelt`, `seatbelt:client:ToggleCruise` | client | qb-smallresources |
| `qb-admin:client:ToggleDevmode` | client | the Dev chip |

## NUI contract

Lua to NUI (`SendNUIMessage`): `init` (accent, currency, units, voice levels, map frame, settings), `settings`
(the full settings table), `tick` (vitals plus `veh`, sent only when something changed), `compass`, `money`
(`mode` is `change` or `show`), `menu` (`open` true or false), `restart`.

NUI to Lua (`RegisterNUICallback`): `ready`, `close`, `set {key, value}` (validated against `Config.Defaults`),
`action {name = 'restart' | 'reset'}`.

## Previewing the UI without the game

`dev/preview.html` loads the real NUI in an iframe and fakes everything the Lua sends (on foot, car, aircraft,
bike, hurt, dead, underwater, radio, money, circle map, menu). It is not listed in `files{}`, so it is never sent to players.
Browsers do not load scripts and styles reliably from `file://`, so serve the `resources` folder over HTTP.
`dev/serve.ps1` does that with plain PowerShell (no Node or Python needed):

```powershell
powershell -ExecutionPolicy Bypass -File .\dev\serve.ps1
# then open http://localhost:8765/%5Bletr%5D/ze-hud/dev/preview.html
```

NUI notes: FiveM's embedded Chromium is older, so the CSS avoids `:has()`, `color-mix()`, nesting and `backdrop-filter`.

## First run checklist

1. Watch the server console and F8 for Lua errors at start.
2. Minimap: appears in a vehicle, frame lines up (see above), square/circle switch works from the menu.
3. Spawn, drink / eat (stat changes), take damage, get hurt to see the low state.
4. Drive: speed, gear, fuel (needs `qb-fuel`), seatbelt chip toggles with your seatbelt key, `Cruise` chip.
5. `/cash`, then give yourself money to see the pill and delta.
6. Open the menu with `I`: toggle things, Esc closes, "Restart HUD" and "Reset to defaults" work.
7. Ultrawide / 4K if you use them: tell me what is off and I will tune `Config.MapFrame`.
