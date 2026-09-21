
local KVP_KEY = 'codera_hud:zoom'

local STEP = Config.MapZoomStep or 100
local MIN = Config.MapZoomMin or 300
local MAX = Config.MapZoomMax or 1400
local START = 1100 -- value used as the starting point when zoom is still "game default"

-- 0 = leave the game's own automatic zoom alone
local zoom = tonumber(Config.MapZoom) or 0

local saved = GetResourceKvpString(KVP_KEY)
if saved and tonumber(saved) then zoom = tonumber(saved) end

local function clamp(value)
    return math.floor(math.max(MIN, math.min(MAX, value)) + 0.5)
end

local function notify(text)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandThefeedPostTicker(false, false)
end

local function setZoom(value, silent)
    if value <= 0 then
        zoom = 0
        DeleteResourceKvp(KVP_KEY)
        SetRadarZoom(0)
        if not silent then notify('Minimap zoom: default') end
        return
    end

    zoom = clamp(value)
    SetResourceKvp(KVP_KEY, tostring(zoom))
    SetRadarZoom(zoom)
    if not silent then notify(('Minimap zoom: %d'):format(zoom)) end
end

local function zoomBy(delta)
    local base = zoom > 0 and zoom or START
    setZoom(base + delta)
end

-- Used by the /hudsettings menu (client/settings.lua)
function CoderaHud.GetMapZoom() return zoom end
function CoderaHud.SetMapZoom(value) setZoom(tonumber(value) or 0, true) end

RegisterCommand('vhudzoom', function(_, args)
    local arg = args[1]

    if arg == 'in' then
        zoomBy(-STEP)
    elseif arg == 'out' then
        zoomBy(STEP)
    elseif arg == 'reset' or arg == 'default' then
        setZoom(0)
    elseif tonumber(arg) then
        setZoom(tonumber(arg))
    else
        notify(('Usage: /vhudzoom in | out | <%d-%d> | reset  (now: %s)'):format(MIN, MAX, zoom > 0 and zoom or 'default'))
    end
end, false)

RegisterCommand('vhudzoomin', function() zoomBy(-STEP) end, false)
RegisterCommand('vhudzoomout', function() zoomBy(STEP) end, false)
RegisterKeyMapping('vhudzoomin', 'Minimap: zoom in', 'keyboard', 'EQUALS')
RegisterKeyMapping('vhudzoomout', 'Minimap: zoom out', 'keyboard', 'MINUS')

-- The game keeps adjusting the radar zoom by itself every frame (for example it zooms
-- out with vehicle speed). Re-applying our value only now and then makes the map "pulse"
-- between the two values, so it has to be set every frame while a custom zoom is active.
CreateThread(function()
    while true do
        if zoom > 0 then
            SetRadarZoom(zoom)
            Wait(0)
        else
            Wait(500)
        end
    end
end)
