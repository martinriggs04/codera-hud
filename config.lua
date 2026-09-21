Config = {}

-- Supported values: 'qbcore', 'esx', 'qbox'
Config.Framework = 'qbcore'

Config.FrameworkResources = {
    qbcore = 'qb-core',
    esx = 'es_extended',
    qbox = 'qbx_core'
}

-- Seatbelt is optional outside QBCore. Statebag-based seatbelt scripts work
-- automatically; set a resource name here only when it exposes
-- HasSeatbeltOn()/HasHarness() like qb-smallresources.
Config.SeatbeltResources = {
    qbcore = 'qb-smallresources',
    esx = false,
    qbox = false
}

-- Scuba/diving gear detection (drives the diving HUD panel on the right and
-- swaps the bottom-center display between oxygen and stamina). Checked via
-- GetPedDrawableVariation(ped, component) == drawable. Set texture to a
-- number to also require GetPedTextureVariation(ped, component) == texture,
-- or leave it nil to match on the drawable alone.
Config.ScubaGear = {
    component = 9,
    drawable = 288,
    texture = nil
}

Config.NeedsRefreshInterval = 5000

-- Voice resource used for the mic/proximity/radio indicator on the player HUD.
-- Supported values: 'pma-voice', 'qb-voice' or 'auto' (detects whichever of the
-- two is started; pma-voice takes priority if both happen to be running).
Config.VoiceResource = 'auto'

-- Commands registered by codera-hud.
Config.Commands = {
    cinematic = 'cinematic',
    hudsettings = 'hudsettings', -- opens the personal HUD settings menu
    chat = 'coderahud_chat' -- internal, opens the built-in chat (see client/chat.lua)
}

-- Key that opens the chat. codera-hud now provides its own chat (it replaces
-- the stock 'chat' resource - stop/remove 'chat' from your server.cfg).
Config.ChatKey = 't'

-- Name shown in the footer of the /hudsettings menu ("<name> / PERSONAL SETTINGS").
Config.SettingsBrand = 'CODERA HUD'

-- Client update intervals in milliseconds.
-- These values are read directly by the runtime loops. Lower values update more
-- frequently but use more client CPU time. The defaults below are tuned to keep
-- the HUD responsive without sending unnecessary NUI messages.
Config.Intervals = {
    player = 200,          -- Health, armour, needs, voice, stamina and weapon data.
    vehicle = 50,          -- Vehicle data while the player is inside a vehicle.
    vehicleIdle = 250,     -- Vehicle presence check while outside a vehicle.
    compassHeading = 25,   -- Camera heading target; NUI interpolation keeps it smooth.
    compassDetails = 250,  -- Street, zone and custom waypoint distance/direction.
    minimap = 1000         -- Resolution, safezone and minimap position checks.
}

-- Vehicle speed display. The default multiplier converts GTA metres/second to MPH.
-- Use 3.6 and 'KM/H' if you want metric speed instead.
Config.SpeedMultiplier = 2.236936
Config.SpeedUnit = 'MPH'
Config.MaxSpeed = 160 -- Speed at which the outer speed arc reaches 100%.

-- Warn players when their GTA safezone is too small for the HUD layout.
Config.ShowSafezoneWarning = true
Config.RequiredSafezone = 0.99

-- Display the custom aiming crosshair handled by the player HUD.
Config.UseCustomCrosshair = true

-- Minimap zoom. 0 = game default. Bigger number = zoomed out, smaller = zoomed in.
-- Players can also change it in game: /vhudzoom in | out | <number> | reset
-- (default keys: "=" zoom in, "-" zoom out). A player's own choice is saved and overrides this value.
Config.MapZoom = 0
Config.MapZoomStep = 100
Config.MapZoomMin = 300
Config.MapZoomMax = 1400
