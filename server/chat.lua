---------------------------------------------------------------------------
-- Codera HUD chat - server relay
--
-- Mirrors the stock 'chat' resource's server-side behaviour so anything
-- listening for the 'chatMessage' event (profanity filters, logging, admin
-- mutes) still works: it can call CancelEvent() inside its handler to stop
-- the message from ever reaching other players.
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Stop the stock 'chat' resource if it's running. codera-hud draws and
-- handles its own chat now - having both running at once means the T key
-- opens two chats at the same time.
-- The clean, permanent fix is removing/commenting "ensure chat" out of your
-- server.cfg; this is just a safety net for setups that still auto-start it.
---------------------------------------------------------------------------
local STOCK_CHAT_RESOURCE = 'chat'

local function disableStockChat()
    local state = GetResourceState(STOCK_CHAT_RESOURCE)
    if state == 'started' or state == 'starting' then
        StopResource(STOCK_CHAT_RESOURCE)
        print(('[codera-hud] stopped the stock "%s" resource - codera-hud provides its own chat now. '
            .. 'Remove/comment "ensure %s" from server.cfg to avoid this message.'):format(STOCK_CHAT_RESOURCE, STOCK_CHAT_RESOURCE))
    end
end

CreateThread(function()
    Wait(1000)
    disableStockChat()
end)

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == STOCK_CHAT_RESOURCE then
        disableStockChat()
    end
end)

---------------------------------------------------------------------------
-- Character name (not the Steam/Rockstar display name) for chat authors.
---------------------------------------------------------------------------
local Framework = Config.Framework
local FrameworkResource = Config.FrameworkResources[Framework]
local Core = nil

CreateThread(function()
    if not FrameworkResource then return end
    while GetResourceState(FrameworkResource) ~= 'started' do Wait(500) end

    if Framework == 'qbcore' then
        local ok, core = pcall(function() return exports[FrameworkResource]:GetCoreObject() end)
        if ok then Core = core end
    elseif Framework == 'esx' then
        local ok, core = pcall(function() return exports[FrameworkResource]:getSharedObject() end)
        if ok then Core = core end
    end
    -- qbox (qbx_core) exposes GetPlayer(src) directly, no Core object needed.
end)

local function getCharacterName(src)
    local fallback = GetPlayerName(src) or ('Player ' .. tostring(src))

    if Framework == 'qbcore' and Core then
        local ok, player = pcall(function() return Core.Functions.GetPlayer(src) end)
        if ok and player and player.PlayerData and player.PlayerData.charinfo then
            local info = player.PlayerData.charinfo
            local name = (tostring(info.firstname or '') .. ' ' .. tostring(info.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
            if name ~= '' then return name end
        end
    elseif Framework == 'qbox' then
        local ok, player = pcall(function() return exports[FrameworkResource]:GetPlayer(src) end)
        if ok and player and player.PlayerData and player.PlayerData.charinfo then
            local info = player.PlayerData.charinfo
            local name = (tostring(info.firstname or '') .. ' ' .. tostring(info.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
            if name ~= '' then return name end
        end
    elseif Framework == 'esx' and Core then
        local ok, player = pcall(function() return Core.GetPlayerFromId(src) end)
        if ok and player then
            local okName, name = pcall(function() return player.getName() end)
            if okName and name and name ~= '' then return name end
        end
    end

    return fallback
end

RegisterNetEvent('_chat:messageEntered')
AddEventHandler('_chat:messageEntered', function(author, color, message)
    local src = source
    local name = getCharacterName(src)

    CancelEvent()
    TriggerEvent('chatMessage', src, name, message)

    if not WasEventCanceled() then
        TriggerClientEvent('chatMessage', -1, name, color, message)
    end
end)

---------------------------------------------------------------------------
-- Broadcast every command registered anywhere on the server (client or
-- server side) as a chat suggestion, so the dropdown lists everything
-- available, not just the commands a resource explicitly announces via
-- chat:addSuggestion. Marked "generic" so a resource's own, more detailed
-- chat:addSuggestion call (name + help + params) is never overwritten by
-- this generic sweep - see the "generic" handling in web/js/chat.js.
---------------------------------------------------------------------------
local EXCLUDED_COMMANDS = {
    [(Config.Commands and Config.Commands.chat) or 'coderahud_chat'] = true,
    [(Config.Commands and Config.Commands.hudsettings) or 'hudsettings'] = true,
    vhudmap = true,
    vhudzoom = true,
    vhudzoomin = true,
    vhudzoomout = true
}

local function broadcastServerCommands()
    for _, entry in ipairs(GetRegisteredCommands()) do
        local name = entry.name
        -- "internal" is FiveM's own engine/console commands, not resource
        -- commands - never has any help, just clutters the suggestion list.
        if name and name ~= '' and entry.resource ~= 'internal' and not EXCLUDED_COMMANDS[name] then
            -- No real help text is available for these - FiveM only exposes
            -- name/resource via GetRegisteredCommands(), never a description
            -- or params, so we can't fabricate one.
            TriggerClientEvent('chat:addSuggestion', -1, '/' .. name, '', nil, true)
        end
    end
end

CreateThread(function()
    Wait(3000)
    while true do
        broadcastServerCommands()
        Wait(5000)
    end
end)
