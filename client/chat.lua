---------------------------------------------------------------------------
-- Codera HUD chat
--
-- Replaces the stock 'chat' resource (remove/stop it in server.cfg - only
-- one resource should own the chat key and NUI focus). The wire protocol
-- below is kept identical to the default resource so every script that
-- already sends chat messages/suggestions keeps working with zero changes:
--
--   TriggerClientEvent('chatMessage', target, author, color, message)     -- legacy 3-arg
--   TriggerClientEvent('chat:addMessage', target, { color, args, ... })   -- modern
--   TriggerEvent/TriggerClientEvent('chat:addSuggestion', '/cmd', 'help', params)
--   TriggerEvent/TriggerClientEvent('chat:removeSuggestion', '/cmd')
--   TriggerEvent/TriggerClientEvent('chat:clear')
---------------------------------------------------------------------------

local commandName = (Config.Commands and Config.Commands.chat) or 'coderahud_chat'
local chatOpen = false
local currentColor = { 255, 255, 255 }

---------------------------------------------------------------------------
-- FiveM's client has a built-in text-chat overlay baked into the game
-- itself (bound to the INPUT_MP_TEXT_CHAT_ALL / INPUT_MP_TEXT_CHAT_TEAM
-- native controls, T/U by default) - completely separate from any resource.
-- It has to be disabled every frame or it pops up alongside our own chat.
-- Our RegisterKeyMapping below is a different, custom input, so disabling
-- these native controls does not stop our own chat from opening.
---------------------------------------------------------------------------
CreateThread(function()
    while true do
        DisableControlAction(0, 245, true) -- INPUT_MP_TEXT_CHAT_ALL
        DisableControlAction(0, 246, true) -- INPUT_MP_TEXT_CHAT_TEAM
        Wait(0)
    end
end)

local function openChat()
    if chatOpen then return end
    if not CoderaHud.IsVisible() then return end
    if CoderaHud.IsSettingsOpen and CoderaHud.IsSettingsOpen() then return end

    chatOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'chatOpen' })
end

local function closeChat()
    if not chatOpen then return end
    chatOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'chatClose' })
end

RegisterCommand(commandName, openChat, false)
RegisterKeyMapping(commandName, 'Open chat', 'keyboard', Config.ChatKey or 't')

RegisterNUICallback('chatResult', function(data, cb)
    local message = tostring(data and data.message or '')

    if message ~= '' then
        if message:sub(1, 1) == '/' then
            ExecuteCommand(message:sub(2))
        else
            TriggerServerEvent('_chat:messageEntered', GetPlayerName(PlayerId()), currentColor, message)
        end
    end

    closeChat()
    cb('ok')
end)

RegisterNUICallback('chatEscape', function(_, cb)
    closeChat()
    cb('ok')
end)

---------------------------------------------------------------------------
-- Incoming messages / suggestions - same events the stock chat listens for,
-- so qb-core/esx/admin scripts/etc. need no changes.
---------------------------------------------------------------------------
RegisterNetEvent('chatMessage')
AddEventHandler('chatMessage', function(author, color, message)
    SendNUIMessage({
        action = 'chatAddMessage',
        message = { author = author, color = color, args = { author, message } }
    })
end)

RegisterNetEvent('chat:addMessage')
AddEventHandler('chat:addMessage', function(message)
    SendNUIMessage({ action = 'chatAddMessage', message = message or {} })
end)

RegisterNetEvent('chat:addSuggestion')
AddEventHandler('chat:addSuggestion', function(name, help, params, generic)
    SendNUIMessage({ action = 'chatAddSuggestion', name = name, help = help, params = params, generic = generic })
end)

-- QBCore's own command system (QBCore.Commands.Add/Refresh) broadcasts its
-- real help/params in bulk through this plural event, not the singular one
-- above - see qb-core/server/commands.lua's QBCore.Commands.Refresh().
RegisterNetEvent('chat:addSuggestions')
AddEventHandler('chat:addSuggestions', function(suggestions)
    if type(suggestions) ~= 'table' then return end

    for _, suggestion in ipairs(suggestions) do
        SendNUIMessage({
            action = 'chatAddSuggestion',
            name = suggestion.name,
            help = suggestion.help,
            params = suggestion.params or suggestion.arguments
        })
    end
end)

RegisterNetEvent('chat:removeSuggestion')
AddEventHandler('chat:removeSuggestion', function(name)
    SendNUIMessage({ action = 'chatRemoveSuggestion', name = name })
end)

RegisterNetEvent('chat:clear')
AddEventHandler('chat:clear', function()
    SendNUIMessage({ action = 'chatClear' })
end)

-- codera-hud's own commands, so they show up in the suggestion box too.
CreateThread(function()
    Wait(500)

    local own = {
        { (Config.Commands and Config.Commands.hudsettings) or 'hudsettings', 'Open the Codera HUD personal settings menu' },
        { 'vhudmap', 'Calibrate the minimap position (args: reset, debug)' },
        { 'vhudzoom', 'Change minimap zoom (args: in, out, reset, <300-1400>)' }
    }

    for _, entry in ipairs(own) do
        SendNUIMessage({ action = 'chatAddSuggestion', name = '/' .. entry[1], help = entry[2] })
    end
end)

---------------------------------------------------------------------------
-- Client-registered commands (emotes, other client-side scripts) never
-- reach the server's GetRegisteredCommands() sweep, so they get their own
-- local sweep here. Marked "generic" for the same reason as the server
-- sweep - see web/js/chat.js.
---------------------------------------------------------------------------
local EXCLUDED_CLIENT_COMMANDS = {
    [commandName] = true,
    [(Config.Commands and Config.Commands.hudsettings) or 'hudsettings'] = true,
    vhudmap = true,
    vhudzoom = true,
    vhudzoomin = true,
    vhudzoomout = true
}

CreateThread(function()
    Wait(3000)

    while true do
        for _, entry in ipairs(GetRegisteredCommands()) do
            local name = entry.name
            -- "internal" is FiveM's own engine/profile/console commands
            -- (profile_fps*, etc.) - not resource commands, never any help.
            if name and name ~= '' and entry.resource ~= 'internal' and not EXCLUDED_CLIENT_COMMANDS[name] then
                -- No real help text is available for these - FiveM only
                -- exposes name/resource via GetRegisteredCommands(), never
                -- a description or params, so we can't fabricate one.
                SendNUIMessage({
                    action = 'chatAddSuggestion',
                    name = '/' .. name,
                    help = '',
                    generic = true
                })
            end
        end

        Wait(5000)
    end
end)
