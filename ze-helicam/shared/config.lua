Config = {}

Config.Command = 'helicam'  -- command behind the keybind (also usable from the console)
Config.DefaultKey = 'H'     -- default key, players can rebind it in Settings > Key Bindings > FiveM

Config.Models = { 'polmav' } -- helicopters that carry the helicam
Config.MinHeight = 1.5       -- the heli must be at least this high above the ground

Config.RestrictToLEO = false -- true: only on-duty police (job.type == 'leo') can use it

Config.Fov = { max = 80.0, min = 10.0, speed = 2.0 } -- scroll zoom limits (smaller fov = more zoom) and step
Config.PanSpeed = 3.0                                 -- free-look sensitivity

Config.LockRange = 400.0 -- how far the camera can pick a vehicle
Config.LockAssist = 4.0  -- extra tolerance (in metres) around the crosshair, so moving cars are easy to hit
Config.LosGrace = 1000   -- ms the target can stay hidden (tree, bridge, other car) before the lock drops
