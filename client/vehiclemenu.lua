---------------------------------------------------------------------------
-- Vehicle control menu (F6 by default) - seats, doors, windows, engine,
-- lights, hood/trunk, extras. First pass: only opens for the driver.
---------------------------------------------------------------------------

local commandName = (Config.Commands and Config.Commands.vehicleMenu) or 'coderahud_vehiclemenu'
local SIDE_DOORS = { 0, 1, 2, 3 }
local HOOD_DOOR = 4
local TRUNK_DOOR = 5
local MAX_EXTRAS = 12

local menuOpen = false
local currentVehicle = nil

-- No reliable native to read current window position or hazard-light
-- state, so both are tracked ourselves per vehicle (keyed by network id,
-- since handles can be reused). Same for TCS/ESC/manual/launch - GTA has no
-- real simulation for any of these. TCS maps loosely onto
-- SetVehicleReduceGrip; the other three are cosmetic-only toggles with no
-- native effect (manual transmission and launch control aren't a thing in
-- vanilla GTA physics).
local windowState = {}
local hazardState = {}
local tcsState = {}
local escState = {}
local manualState = {}
local launchState = {}
local lightsState = {}
local fullbeamState = {}
local interiorLightState = {}

local function vehicleKey(vehicle)
    return NetworkGetNetworkIdFromEntity(vehicle)
end

local function getWindowsDown(vehicle)
    local key = vehicleKey(vehicle)
    windowState[key] = windowState[key] or { false, false, false, false }
    return windowState[key]
end

local function buildState(vehicle)
    local maxPassengers = GetVehicleMaxNumberOfPassengers(vehicle)
    local seats = {}
    for seat = -1, maxPassengers - 1 do
        table.insert(seats, {
            index = seat,
            occupied = not IsVehicleSeatFree(vehicle, seat),
            current = GetPedInVehicleSeat(vehicle, seat) == PlayerPedId()
        })
    end

    local doors = {}
    for _, index in ipairs(SIDE_DOORS) do
        doors[tostring(index)] = GetVehicleDoorAngleRatio(vehicle, index) > 0.05
    end

    local windowsDown = getWindowsDown(vehicle)
    local windows = {}
    for i, down in ipairs(windowsDown) do
        windows[tostring(i - 1)] = down
    end

    local extras = {}
    for i = 1, MAX_EXTRAS do
        if DoesExtraExist(vehicle, i) then
            extras[tostring(i)] = IsVehicleExtraTurnedOn(vehicle, i)
        end
    end

    local key = vehicleKey(vehicle)

    return {
        seats = seats,
        doors = doors,
        hoodOpen = GetVehicleDoorAngleRatio(vehicle, HOOD_DOOR) > 0.05,
        trunkOpen = GetVehicleDoorAngleRatio(vehicle, TRUNK_DOOR) > 0.05,
        windows = windows,
        engineOn = GetIsVehicleEngineRunning(vehicle),
        lightsOn = lightsState[key] == true,
        fullbeamOn = fullbeamState[key] == true,
        interiorLightOn = interiorLightState[key] == true,
        hazardOn = hazardState[key] == true,
        alarmOn = IsVehicleAlarmActivated(vehicle),
        tcs = tcsState[key] ~= false,
        esc = escState[key] ~= false,
        manual = manualState[key] == true,
        launch = launchState[key] == true,
        extras = extras
    }
end

local function pushState()
    if not menuOpen or not currentVehicle or not DoesEntityExist(currentVehicle) then return end
    SendNUIMessage({ action = 'vehicleMenuState', state = buildState(currentVehicle) })
end

local function closeMenu()
    if not menuOpen then return end
    menuOpen = false
    currentVehicle = nil
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'vehicleMenuClose' })
end

local function openMenu()
    if menuOpen then closeMenu() return end
    if not CoderaHud.IsVisible() then return end

    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if GetPedInVehicleSeat(vehicle, -1) ~= ped then return end

    menuOpen = true
    currentVehicle = vehicle
    SetNuiFocus(true, true)
    -- Keeps the game receiving camera/look input even with the cursor up,
    -- so holding right mouse still orbits the camera around the car while
    -- the menu is open, same as the normal in-vehicle look-around.
    SetNuiFocusKeepInput(true)
    SendNUIMessage({ action = 'vehicleMenuOpen', state = buildState(vehicle) })
end

RegisterCommand(commandName, openMenu, false)
RegisterKeyMapping(commandName, 'Open the vehicle control menu (driver only)', 'keyboard', Config.VehicleMenuKey or 'F6')

-- SetNuiFocusKeepInput(true) lets the game keep reading camera-look input
-- while the cursor is up, but that also means the mouse would spin the
-- camera just from moving it to click a button. Only let the look axis
-- (INPUT_LOOK_LR/UD, controls 1/2) through while the right mouse button is
-- actually held, exactly like the normal in-vehicle look-around.
--
-- Right-click while driving unarmed is INPUT_VEH_AIM (68), NOT the on-foot
-- INPUT_AIM (25) - using 25 here never touched the vehicle control, which
-- is why the flip-off gesture kept firing. INPUT_VEH_ATTACK2 (70) is also
-- bound to right mouse in a vehicle, so it's disabled too just in case.
-- All three are disabled every frame (blocking their default vanilla
-- action on the ped), and IsDisabledControlPressed still reports whether
-- they're held even while disabled, so that's reused for our own camera
-- gating instead.
CreateThread(function()
    while true do
        if menuOpen then
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 68, true)
            DisableControlAction(0, 70, true)

            local rmbHeld = IsDisabledControlPressed(0, 68)
                or IsDisabledControlPressed(0, 25)
                or IsDisabledControlPressed(0, 70)

            if not rmbHeld then
                DisableControlAction(0, 1, true)
                DisableControlAction(0, 2, true)
            end
            Wait(0)
        else
            Wait(200)
        end
    end
end)

-- SetVehicleLights()/SetVehicleFullbeam() are "this frame" overrides, not a
-- persistent setting - a single call can get silently reset by the game
-- (most noticeably during the day), so a forced-on state has to be
-- reapplied every frame for as long as it's toggled on. Runs independently
-- of the menu being open, so lights stay on after you close it.
CreateThread(function()
    while true do
        Wait(0)
        local vehicle = GetVehiclePedIsIn(PlayerPedId(), false)
        if vehicle ~= 0 then
            local key = vehicleKey(vehicle)
            if lightsState[key] then
                SetVehicleLights(vehicle, 2)
                if fullbeamState[key] then
                    SetVehicleFullbeam(vehicle, true)
                end
            end
        end
    end
end)

CreateThread(function()
    while true do
        Wait(500)
        local ped = PlayerPedId()
        if menuOpen and (
            not currentVehicle
            or not DoesEntityExist(currentVehicle)
            or IsPedDeadOrDying(ped, true)
            or GetVehiclePedIsIn(ped, false) ~= currentVehicle
        ) then
            closeMenu()
        end
    end
end)

local function withVehicle(cb)
    return function(data, resultCb)
        if menuOpen and currentVehicle and DoesEntityExist(currentVehicle) then
            cb(currentVehicle, data or {})
            pushState()
        end
        resultCb('ok')
    end
end

RegisterNUICallback('vehiclemenu_close', function(_, cb)
    closeMenu()
    cb('ok')
end)

RegisterNUICallback('vehiclemenu_seat', withVehicle(function(vehicle, data)
    local seat = tonumber(data.seat)
    if seat == nil then return end
    if IsVehicleSeatFree(vehicle, seat) then
        TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, seat)
        if seat ~= -1 then closeMenu() end
    end
end))

RegisterNUICallback('vehiclemenu_engine', withVehicle(function(vehicle)
    SetVehicleEngineOn(vehicle, not GetIsVehicleEngineRunning(vehicle), false, true)
end))

RegisterNUICallback('vehiclemenu_lights', withVehicle(function(vehicle)
    local key = vehicleKey(vehicle)
    local on = not (lightsState[key] == true)
    lightsState[key] = on
    SetVehicleLights(vehicle, on and 2 or 1) -- 2 = force on, 1 = force off

    if not on and fullbeamState[key] then
        fullbeamState[key] = false -- no high beam without low beam
        SetVehicleFullbeam(vehicle, false)
    end
end))

RegisterNUICallback('vehiclemenu_highbeam', withVehicle(function(vehicle)
    local key = vehicleKey(vehicle)
    if not (lightsState[key] == true) then return end -- low beam has to be on first

    local on = not (fullbeamState[key] == true)
    fullbeamState[key] = on
    SetVehicleFullbeam(vehicle, on)
end))

RegisterNUICallback('vehiclemenu_interior', withVehicle(function(vehicle)
    local key = vehicleKey(vehicle)
    local on = not (interiorLightState[key] == true)
    interiorLightState[key] = on
    SetVehicleInteriorlight(vehicle, on)
end))

RegisterNUICallback('vehiclemenu_door', withVehicle(function(vehicle, data)
    local index = tonumber(data.index)
    if index == nil then return end
    if GetVehicleDoorAngleRatio(vehicle, index) > 0.05 then
        SetVehicleDoorShut(vehicle, index, false)
    else
        SetVehicleDoorOpen(vehicle, index, false, false)
    end
end))

RegisterNUICallback('vehiclemenu_hood', withVehicle(function(vehicle)
    if GetVehicleDoorAngleRatio(vehicle, HOOD_DOOR) > 0.05 then
        SetVehicleDoorShut(vehicle, HOOD_DOOR, false)
    else
        SetVehicleDoorOpen(vehicle, HOOD_DOOR, false, false)
    end
end))

RegisterNUICallback('vehiclemenu_trunk', withVehicle(function(vehicle)
    if GetVehicleDoorAngleRatio(vehicle, TRUNK_DOOR) > 0.05 then
        SetVehicleDoorShut(vehicle, TRUNK_DOOR, false)
    else
        SetVehicleDoorOpen(vehicle, TRUNK_DOOR, false, false)
    end
end))

RegisterNUICallback('vehiclemenu_window', withVehicle(function(vehicle, data)
    local index = tonumber(data.index)
    if index == nil then return end

    local windowsDown = getWindowsDown(vehicle)
    if windowsDown[index + 1] then
        RollUpWindow(vehicle, index)
        windowsDown[index + 1] = false
    else
        RollDownWindow(vehicle, index)
        windowsDown[index + 1] = true
    end
end))

RegisterNUICallback('vehiclemenu_hazard', withVehicle(function(vehicle)
    local key = vehicleKey(vehicle)
    local on = not (hazardState[key] == true)
    hazardState[key] = on
    SetVehicleIndicatorLights(vehicle, 0, on)
    SetVehicleIndicatorLights(vehicle, 1, on)
end))

RegisterNUICallback('vehiclemenu_alarm', withVehicle(function(vehicle)
    local on = IsVehicleAlarmActivated(vehicle)
    SetVehicleAlarm(vehicle, not on)
    if not on then StartVehicleAlarm(vehicle) end
end))

RegisterNUICallback('vehiclemenu_tcs', withVehicle(function(vehicle)
    local key = vehicleKey(vehicle)
    local newState = not (tcsState[key] ~= false)
    tcsState[key] = newState
    SetVehicleReduceGrip(vehicle, not newState)
end))

RegisterNUICallback('vehiclemenu_esc', withVehicle(function(vehicle)
    local key = vehicleKey(vehicle)
    escState[key] = not (escState[key] ~= false)
end))

RegisterNUICallback('vehiclemenu_manual', withVehicle(function(vehicle)
    local key = vehicleKey(vehicle)
    manualState[key] = not (manualState[key] == true)
end))

RegisterNUICallback('vehiclemenu_launch', withVehicle(function(vehicle)
    local key = vehicleKey(vehicle)
    launchState[key] = not (launchState[key] == true)
end))

RegisterNUICallback('vehiclemenu_extra', withVehicle(function(vehicle, data)
    local id = tonumber(data.id)
    if id == nil or not DoesExtraExist(vehicle, id) then return end
    SetVehicleExtra(vehicle, id, IsVehicleExtraTurnedOn(vehicle, id) and 1 or 0)
end))
