---------------------------------------------------------------------------
-- Diving HUD (right side of screen): EST. TIME / DEPTH / TANK.
--
-- Custom oxygen tank system, independent of GTA's native underwater breath
-- timer. Tank starts at 200 (= 30 minutes of underwater time). It drains
-- while submerged with the scuba vest on, and refills at the same rate
-- while surfaced with the vest still on. Nothing is persisted - it always
-- starts back at full (200) on resource restart/relog.
---------------------------------------------------------------------------

local TANK_MAX = 200
local TANK_SECONDS = 1800 -- 200 units == 30 minutes
local DRAIN_PER_SEC = TANK_MAX / TANK_SECONDS
local REFILL_PER_SEC = DRAIN_PER_SEC

local tankValue = TANK_MAX
local lastTick = nil
local visible = false
local wasHasGear = false

CoderaHud.hasScubaGear = false

local function isWearingScubaGear(ped)
    local gear = Config.ScubaGear
    if not gear then return false end

    if GetPedDrawableVariation(ped, gear.component) ~= gear.drawable then
        return false
    end

    if gear.texture ~= nil and GetPedTextureVariation(ped, gear.component) ~= gear.texture then
        return false
    end

    return true
end

CreateThread(function()
    while true do
        Wait(250)

        local ped = PlayerPedId()
        local hasGear = isWearingScubaGear(ped)
        CoderaHud.hasScubaGear = hasGear
        local underwater = IsPedSwimmingUnderWater(ped)

        if hasGear ~= wasHasGear then
            -- Wearing the tank makes drowning impossible outright, matching
            -- how a real scuba resource does it (SetPedDiesInWater), rather
            -- than fighting the native breath timer.
            SetPedDiesInWater(ped, not hasGear)
            wasHasGear = hasGear
        end

        local now = GetGameTimer()
        local dt = lastTick and ((now - lastTick) / 1000.0) or 0
        lastTick = now

        if hasGear then
            if underwater then
                tankValue = math.max(0, tankValue - (DRAIN_PER_SEC * dt))
            else
                tankValue = math.min(TANK_MAX, tankValue + (REFILL_PER_SEC * dt))
            end
        end

        local shouldShow = hasGear

        if shouldShow then
            local depth = 0.0
            if underwater then
                local coords = GetEntityCoords(ped)
                local waterOk, waterZ = GetWaterHeight(coords.x, coords.y, coords.z)
                depth = (waterOk and waterZ > coords.z) and (waterZ - coords.z) or 0.0
            end
            local estSeconds = math.floor((tankValue / TANK_MAX) * TANK_SECONDS)

            SendNUIMessage({
                action = 'diveHudUpdate',
                visible = true,
                depth = depth,
                estSeconds = estSeconds,
                tank = math.floor(tankValue + 0.5),
                tankMax = TANK_MAX,
                inVehicle = IsPedInAnyVehicle(ped, false)
            })
        elseif visible then
            SendNUIMessage({ action = 'diveHudUpdate', visible = false })
        end

        visible = shouldShow
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if wasHasGear then
        SetPedDiesInWater(PlayerPedId(), true)
    end
end)
