-- Discord Webhookit
local deathWebhookUrl = "https://discord.com/api/webhooks/XXXXXX/XXXXXXXXXXXX" -- Kuoleman logi
local chatWebhookUrl = "https://discord.com/api/webhooks/YYYYYY/YYYYYYYYYY" -- Chat logi
local adminCommandWebhookUrl = "https://discord.com/api/webhooks/ZZZZZ/ZZZZZZZZZZ" -- Admin-komentojen logi

if GetCurrentResourceName() ~= "dextys_logs" then
    print("Virhe: Tämä skripti toimii vain 'dextys_logs' kansion nimellä!")
    return
end

local QBCore = exports['qb-core']:GetCoreObject()

function sendToDiscord(url, message)
    local jsonMessage = json.encode({content = message})
    PerformHttpRequest(url, function(err, text, headers) end, 'POST', jsonMessage, {['Content-Type'] = 'application/json'})
end

function isPlayerAdmin(playerId)
    local player = QBCore.Functions.GetPlayer(playerId)
    if player and player.PlayerData and player.PlayerData.job and player.PlayerData.job.name == 'admin' then
        return true
    else
        return false
    end
end

-- Kuoleman logi
AddEventHandler('baseevents:onPlayerDied', function(playerId, reason)
    local playerName = GetPlayerName(playerId)
    local message = "**Pelaaja kuoli!**\n**Nimi:** " .. playerName .. "\n**Kuolinsyy:** " .. reason
    sendToDiscord(deathWebhookUrl, message)
end)

-- Chat logi
AddEventHandler('chatMessage', function(source, name, message)
    local playerName = GetPlayerName(source)
    local formattedMessage = "**" .. playerName .. "**: " .. message
    sendToDiscord(chatWebhookUrl, formattedMessage)
end)

AddEventHandler('playerCommand', function(source, command, args)
    if isPlayerAdmin(source) then
        local playerName = GetPlayerName(source)

        if command == "giveitem" then
            local itemName = args[1] or "Tuntematon"
            local amount = args[2] or "1"
            local message = "**Admin Komento Käytetty!**\n**Admin:** " .. playerName .. "\n**Komento:** /giveitem " .. itemName .. " " .. amount
            sendToDiscord(adminCommandWebhookUrl, message)

        elseif command == "car" then
            local vehicleModel = args[1] or "Tuntematon"
            local message = "**Admin Komento Käytetty!**\n**Admin:** " .. playerName .. "\n**Komento:** /car " .. vehicleModel
            sendToDiscord(adminCommandWebhookUrl, message)

        elseif command == "tp" then
            local targetPlayerId = args[1] or "Tuntematon"
            local message = "**Admin Komento Käytetty!**\n**Admin:** " .. playerName .. "\n**Komento:** /tp " .. targetPlayerId
            sendToDiscord(adminCommandWebhookUrl, message)
        end
    end
end)


print("[Dextys Logs] Ladattu onnistuneesti!")
