
local RING_LEFT = 0.845
local RING_TOP = 0.10
local RING_DIAMETER = 0.105 -- matches .compass__ring { width: 10.5vw } in web/css/minimap.css

local KVP_KEY = 'codera_hud:minimap2'
local Tune = { x = 0.0, y = 0.0, scale = 1.0, stretch = 1.0 }

local function loadTune()
    local raw = GetResourceKvpString(KVP_KEY)
    if not raw or raw == '' then return end
    local ok, data = pcall(json.decode, raw)
    if ok and type(data) == 'table' then
        Tune.x = tonumber(data.x) or 0.0
        Tune.y = tonumber(data.y) or 0.0
        Tune.scale = tonumber(data.scale) or 1.0
        Tune.stretch = tonumber(data.stretch) or 1.0
    end
end

local function saveTune()
    SetResourceKvp(KVP_KEY, json.encode(Tune))
end

loadTune()

-- Standard circle-map map height (HUD units) and the circle size inside the mask texture
local BASE_ASPECT = 16 / 9
local STD_CIRCLE_H = 0.183
local CIRCLE_W_FRAC = 389 / 512
local CIRCLE_H_FRAC = 389 / 396
local BLUR_WIDTH = 1.0 -- width of the soft grey halo (1.0 = original, try 0.9 if it sticks out at the sides)

local TXD = 'circlemap_codera'

local METERS_PER_MILE = 1609.344

---------------------------------------------------------------------------
-- Circle minimap texture
---------------------------------------------------------------------------
local lastResX, lastResY, lastSafezone = 0, 0, 0.0
local textureReady = false

CreateThread(function()
    RequestStreamedTextureDict(TXD, false)
    while not HasStreamedTextureDictLoaded(TXD) do Wait(0) end

    AddReplaceTexture('platform:/textures/graphics', 'radarmasksm', TXD, 'radarmasksm')
    AddReplaceTexture('platform:/textures/graphics', 'radarmasklg', TXD, 'radarmasklg')
    textureReady = true
    lastResX = 0 -- force the minimap to be re-applied with the circle mask
end)


local function getAlignment(resX, resY)
    local ok, x0, y0, x1, y1 = pcall(function()
        SetScriptGfxAlign(76, 66)
        SetScriptGfxAlignParams(0.0, 0.0, 0.0, 0.0)
        local ax0, ay0 = GetScriptGfxAlignPosition(0.0, 0.0)
        local ax1, ay1 = GetScriptGfxAlignPosition(1.0, 1.0)
        return ax0, ay0, ax1, ay1
    end)
    ResetScriptGfxAlign()

    if ok and x0 and y0 and x1 and y1 and (x1 - x0) > 0.01 and (y1 - y0) > 0.01 then
        return x0, y0, x1 - x0, y1 - y0
    end

    local aspect = resX / resY
    local region = aspect > BASE_ASPECT and (BASE_ASPECT / aspect) or 1.0
    local margin = (1.0 - GetSafeZoneSize()) / 2.0
    return ((1.0 - region) / 2.0) + (margin * region), 1.0 - margin, region, 1.0
end

local STD = {
    minimap = { x = 0.000, y = -0.047, w = 0.1638, h = 0.183 },
    mask    = { x = 0.000, y = 0.000,  w = 0.128,  h = 0.200 },
    blur    = { x = -0.010, y = 0.025, w = 0.262,  h = 0.300 }
}

local function applyMinimap()
    local resX, resY = GetActiveScreenResolution()
    if resX <= 0 or resY <= 0 then return end

    local ax, ay, bx, by = getAlignment(resX, resY)
    local aspect = resX / resY

 
    local layout = CoderaHud.GetMapLayout and CoderaHud.GetMapLayout() or nil
    local layoutX = layout and layout.x or 0.0
    local layoutY = layout and layout.y or 0.0
    local layoutScale = layout and layout.scale or 1.0

    local diameterPx = RING_DIAMETER * resX * Tune.scale * layoutScale
    local centerX = RING_LEFT + layoutX + ((RING_DIAMETER / 2.0) * layoutScale) + Tune.x
    local centerY = RING_TOP + layoutY + (((RING_DIAMETER * aspect) / 2.0) * layoutScale) + Tune.y

    local hudCX = (centerX - ax) / bx
    local hudCY = (centerY - ay) / by

    local maskW = ((diameterPx / CIRCLE_W_FRAC) / (resX * bx)) * Tune.stretch
    local maskH = (diameterPx / CIRCLE_H_FRAC) / (resY * by)

    local s = diameterPx / (STD_CIRCLE_H * resY * by)

    local stdMaskCX = STD.mask.x + (STD.mask.w / 2.0)
    local stdMaskCY = STD.mask.y - (STD.mask.h / 2.0)

    local function place(name, comp)
        local wMul = (name == 'minimap_blur') and BLUR_WIDTH or 1.0
        local w, h = comp.w * s * Tune.stretch * wMul, comp.h * s
        local cx = hudCX + ((comp.x + (comp.w / 2.0) - stdMaskCX) * s * Tune.stretch)
        local cy = hudCY + (((comp.y - (comp.h / 2.0)) - stdMaskCY) * s)
        SetMinimapComponentPosition(name, 'L', 'B', cx - (w / 2.0), cy + (h / 2.0), w, h)
    end

    SetMinimapClipType(1)
    place('minimap', STD.minimap)

    place('minimap_blur', STD.blur)
    SetMinimapComponentPosition('minimap_mask', 'L', 'B', hudCX - (maskW / 2.0), hudCY + (maskH / 2.0), maskW, maskH)

    SetBlipAlpha(GetNorthRadarBlip(), 0)
    SetRadarBigmapEnabled(true, false)
    Wait(0)
    SetRadarBigmapEnabled(false, false)
end

-- Re-places the map (used by /hudsettings when the compass layout changes).
local applying = false
function CoderaHud.RefreshMinimap()
    if not textureReady or applying then
        lastResX = 0 -- the loop below re-applies it within a second
        return
    end

    applying = true
    CreateThread(function()
        applyMinimap()
        applying = false
    end)
end

CreateThread(function()
    local safezoneShown = false
    local wasLoaded = false

    while true do
        Wait(Config.Intervals.minimap)

        local resX, resY = GetActiveScreenResolution()
        local safezone = GetSafeZoneSize()

        if not wasLoaded and CoderaHud.loaded then
            wasLoaded = true
            lastResX = 0 -- force a re-apply once the character is loaded
        elseif wasLoaded and not CoderaHud.loaded then
            wasLoaded = false
        end

        if textureReady and (resX ~= lastResX or resY ~= lastResY or safezone ~= lastSafezone) then
            lastResX, lastResY, lastSafezone = resX, resY, safezone
            applyMinimap()
        end

        local shouldWarn = Config.ShowSafezoneWarning
            and CoderaHud.loaded
            and not IsPauseMenuActive()
            and safezone < Config.RequiredSafezone

        if shouldWarn ~= safezoneShown then
            safezoneShown = shouldWarn
            SendNUIMessage({ action = shouldWarn and 'showSafezoneWarning' or 'hideSafezoneWarning' })
        end
    end
end)

---------------------------------------------------------------------------
-- Compass heading (browser-side interpolation smooths the motion)
---------------------------------------------------------------------------
-- GTA camera rotation is counter-clockwise; the compass uses clockwise degrees.
local function getCompassHeading()
    return (-GetGameplayCamRot(2).z) % 360.0
end

CreateThread(function()
    local lastHeading = nil
    local hiddenSent = false

    while true do
        Wait(Config.Intervals.compassHeading)

        if CoderaHud.IsVisible() then
            hiddenSent = false
            local heading = getCompassHeading()

            if not lastHeading or math.abs(heading - lastHeading) >= 0.05 then
                lastHeading = heading
                SendNUIMessage({ action = 'updateCompassHeading', heading = heading })
            end
        elseif not hiddenSent then
            hiddenSent = true
            lastHeading = nil
            SendNUIMessage({ action = 'hideCompass' })
        end
    end
end)

---------------------------------------------------------------------------
-- Street / zone / custom waypoint
---------------------------------------------------------------------------
local function getWaypointDirection(playerCoords, waypoint)
    local dx = waypoint.x - playerCoords.x
    local dy = waypoint.y - playerCoords.y

    local bearing = math.deg(math.atan(dx, dy)) % 360.0   -- clockwise from north
    local relative = ((bearing - getCompassHeading() + 540.0) % 360.0) - 180.0

    if math.abs(relative) <= 45.0 then return 'straight' end
    if relative > 45.0 and relative <= 135.0 then return 'right' end
    if relative < -45.0 and relative >= -135.0 then return 'left' end
    return 'back'
end

CreateThread(function()
    local lastStreet, lastZone = nil, nil
    local lastWaypointKey = nil
    local hiddenSent = false

    while true do
        Wait(Config.Intervals.compassDetails)

        if CoderaHud.IsVisible() then
            hiddenSent = false

            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)

            -- Street and zone
            local streetHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
            local street = GetStreetNameFromHashKey(streetHash) or ''
            local zone = GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
            if zone == 'NULL' then zone = '' end

            street, zone = string.upper(street), string.upper(zone)

            if street ~= lastStreet or zone ~= lastZone then
                lastStreet, lastZone = street, zone
                SendNUIMessage({ action = 'updateCompassDetails', street = street, zone = zone })
            end

            -- Waypoint
            local blip = GetFirstBlipInfoId(8)
            if DoesBlipExist(blip) then
                local waypoint = GetBlipInfoIdCoord(blip)
                local dx, dy = waypoint.x - coords.x, waypoint.y - coords.y
                local meters = math.sqrt((dx * dx) + (dy * dy))

                local distance = string.format('%.2f mi', meters / METERS_PER_MILE)
                local direction = getWaypointDirection(coords, waypoint)
                local key = distance .. direction

                if key ~= lastWaypointKey then
                    lastWaypointKey = key
                    SendNUIMessage({ action = 'updateWaypoint', distance = distance, direction = direction })
                end
            elseif lastWaypointKey then
                lastWaypointKey = nil
                SendNUIMessage({ action = 'hideWaypoint' })
            end
        elseif not hiddenSent then
            hiddenSent = true
            lastStreet, lastZone, lastWaypointKey = nil, nil, nil
            SendNUIMessage({ action = 'hideWaypoint' })
        end
    end
end)

---------------------------------------------------------------------------
-- In-game calibration:  /vhudmap
--   Arrow keys      move the map   (Shift = big steps, Ctrl = tiny steps)
--   PageUp/PageDown resize the map
--   Enter           save           Backspace  cancel
--   /vhudmap reset  restore defaults
---------------------------------------------------------------------------
local calibrating = false

local function showHelp(text)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

local function calibrate()
    if calibrating then return end
    calibrating = true

    local backup = { x = Tune.x, y = Tune.y, scale = Tune.scale, stretch = Tune.stretch }
    local dirty = false

    while calibrating do
        Wait(0)

        local step = 0.0005
        if IsControlPressed(0, 21) then step = 0.004 end   -- Shift
        if IsControlPressed(0, 36) then step = 0.0001 end  -- Ctrl

        local moved = false
        if IsControlPressed(0, 174) then Tune.x = Tune.x - step; moved = true end
        if IsControlPressed(0, 175) then Tune.x = Tune.x + step; moved = true end
        if IsControlPressed(0, 172) then Tune.y = Tune.y - step; moved = true end
        if IsControlPressed(0, 173) then Tune.y = Tune.y + step; moved = true end
        if IsControlPressed(0, 10) then Tune.scale = Tune.scale + (step * 2); moved = true end
        if IsControlPressed(0, 11) then Tune.scale = math.max(0.2, Tune.scale - (step * 2)); moved = true end
        if IsControlPressed(0, 38) then Tune.stretch = Tune.stretch + (step * 2); moved = true end   -- E: wider
        if IsControlPressed(0, 44) then Tune.stretch = math.max(0.2, Tune.stretch - (step * 2)); moved = true end -- Q: narrower

        if moved then dirty = true end

        -- Re-apply only when something changed, and not every single frame
        if dirty and not moved then
            dirty = false
            applyMinimap()
        end

        local resX, resY = GetActiveScreenResolution()
        showHelp(('~b~Minimap calibration~s~~n~Arrows: move  |  PgUp/PgDn: size  |  Q/E: narrower/wider~n~Enter: save  |  Backspace: cancel~n~'
            .. 'x=%.4f  y=%.4f  scale=%.3f  stretch=%.3f~n~%dx%d  safezone=%.2f'):format(Tune.x, Tune.y, Tune.scale, Tune.stretch, resX, resY, GetSafeZoneSize()))

        if IsControlJustPressed(0, 191) then -- Enter
            saveTune()
            print(('[codera-hud] minimap saved: x=%.4f y=%.4f scale=%.3f stretch=%.3f (%dx%d)'):format(Tune.x, Tune.y, Tune.scale, Tune.stretch, resX, resY))
            calibrating = false
        elseif IsControlJustPressed(0, 177) then -- Backspace
            Tune.x, Tune.y, Tune.scale, Tune.stretch = backup.x, backup.y, backup.scale, backup.stretch
            applyMinimap()
            calibrating = false
        end
    end
end

RegisterCommand('vhudmap', function(_, args)
    if args[1] == 'debug' then
        CreateThread(function()
            local resX, resY = GetActiveScreenResolution()
            local ax, ay, bx, by = getAlignment(resX, resY)
            local text = ('res=%dx%d  aspect=%.4f  nativeAspect=%.4f~n~safezone=%.3f~n~align ax=%.4f ay=%.4f bx=%.4f by=%.4f~n~tune x=%.4f y=%.4f scale=%.3f stretch=%.3f')
                :format(resX, resY, resX / resY, GetAspectRatio(false), GetSafeZoneSize(), ax, ay, bx, by, Tune.x, Tune.y, Tune.scale, Tune.stretch)
            print('[codera-hud] ' .. text:gsub('~n~', ' | '))
            local untilTime = GetGameTimer() + 20000
            while GetGameTimer() < untilTime do
                Wait(0)
                showHelp('~b~vhudmap debug~s~~n~' .. text)
            end
        end)
        return
    end

    if args[1] == 'reset' then
        Tune.x, Tune.y, Tune.scale, Tune.stretch = 0.0, 0.0, 1.0, 1.0
        DeleteResourceKvp(KVP_KEY)
        applyMinimap()
        return
    end
    CreateThread(calibrate)
end, false)
