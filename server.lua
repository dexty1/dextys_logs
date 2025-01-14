-- Tämä tiedosto sisältää pelaajan tiedot ja niiden käsittelylogiikan

local Config = require('config')

-- Funktio, joka palauttaa pelaajan nimen ja ID:n
function GetPlayerDetails(playerId)
    local playerName = GetPlayerName(playerId)
    return playerName, playerId
end

-- Pelaajan rahansiirtojen käsittely
RegisterServerEvent('qb-core:server:moneyTransaction')
AddEventHandler('qb-core:server:moneyTransaction', function(playerId, amount, transactionType)
    local playerName, playerID = GetPlayerDetails(playerId)
    if transactionType == "deposit" or transactionType == "withdraw" then
        if amount >= 300000 then
            local transactionMessage = string.format(
                "Pelaaja: %s (ID: %s) teki rahansiirron: %s, summa: $%s",
                playerName, playerId, transactionType, amount
            )
            sendToDiscord(transactionMessage, Config.Webhooks.transactionLogWebhook)
        end
    end
end)

-- Kuolinsyy ja tappajan tietojen lähetys
AddEventHandler('qb-core:server:playerDied', function(playerId, cause, killerId)
    local playerName, playerID = GetPlayerDetails(playerId)
    local killerName = killerId and GetPlayerName(killerId) or nil
    local killMethod = cause
    local killerWeapon = nil

    -- Määritellään kuolinsyy ja ase
    if cause == 1 then  -- Auto
        killMethod = "Auto-onnettomuus"
    elseif cause == 2 then  -- Räjähdys
        killMethod = "Räjähdys"
    elseif cause == 3 then  -- Drowning (hukkuminen)
        killMethod = "Hukkuminen"
    elseif cause == 4 then  -- Onnettomuus / tiputus
        killMethod = "Tiputus"
    elseif cause == 5 then  -- Muut syyt, kuten aseet
        killMethod = "Aseella"
        -- Käytetään tapauskohtaisesti tappajan ase tai muu tapa
        if killerId then
            killerWeapon = GetPlayerWeapon(killerId)
        end
    elseif cause == 6 then  -- Itsemurha (kill-komento)
        killMethod = "Itsemurha"
    else
        killMethod = "Tuntematon kuolinsyy"
    end

    -- Viesti Discordiin pelaajan kuolemasta
    local deathMessage = string.format(
        "Pelaaja: %s (ID: %s) kuoli syystä: %s.",
        playerName, playerId, killMethod
    )

    -- Jos tappaja on olemassa
    if killerId then
        local killerWeaponMessage = killerWeapon and string.format("Tappaja käytti asetta: %s", killerWeapon) or "Tappaja käytti tuntematonta asetta."
        deathMessage = deathMessage .. string.format("\nTappaja: %s (ID: %s)\n%s", killerName, killerId, killerWeaponMessage)
    end

    -- Lähetetään kuolinsyyviesti Discordiin
    sendToDiscord(deathMessage, Config.Webhooks.deathLogWebhook)
end)

-- Vankilaan laittaminen logiikka
local jailLog = {}

RegisterCommand('jail', function(source, args, rawCommand)
    local src = source
    local playerName, playerId = GetPlayerDetails(src)
    local targetId = tonumber(args[1])  -- Vangittavan pelaajan ID
    local jailTime = tonumber(args[2])  -- Vankilassaoloaika

    if targetId and jailTime then
        local targetPlayerName = GetPlayerName(targetId)
        
        -- Tallennetaan vankilaan laittaminen logiin
        if not jailLog[playerId] then
            jailLog[playerId] = {}
        end

        -- Lisää uusi vankilaan laittaminen logiin
        table.insert(jailLog[playerId], {targetId = targetId, time = os.time()})

        -- Poistetaan vanhat merkinnät, jotka ovat yli 10 sekuntia vanhoja
        for i = #jailLog[playerId], 1, -1 do
            if os.time() - jailLog[playerId][i].time > 10 then
                table.remove(jailLog[playerId], i)
            end
        end

        -- Tarkistetaan, onko pelaaja laittanut yli kaksi pelaajaa vankilaan 10 sekunnin sisällä
        if #jailLog[playerId] > 2 then
            local jailMessage = string.format(
                "HUOMIO! Pelaaja: %s (ID: %s) laittoi yli kaksi pelaajaa vankilaan 10 sekunnin sisällä!\n",
                playerName, playerId
            )

            -- Lisää kaikki pelaajat, jotka on laitettu vankilaan
            jailMessage = jailMessage .. "Laitettu vankilaan olevat pelaajat:\n"
            for _, v in ipairs(jailLog[playerId]) do
                local targetPlayerName = GetPlayerName(v.targetId)
                jailMessage = jailMessage .. string.format("Pelaaja: %s (ID: %s)\n", targetPlayerName, v.targetId)
            end

            -- Lähetetään huijausviesti Discordiin
            sendToDiscord(jailMessage, Config.Webhooks.cheatLogWebhook)
        else
            -- Lähetetään tavallinen vankilalogiviesti Discordiin
            local jailMessage = string.format(
                "Pelaaja: %s (ID: %s) laittoi pelaajan %s (ID: %s) vankilaan ajaksi: %s minuuttia.",
                playerName, playerId, targetPlayerName, targetId, jailTime
            )
            sendToDiscord(jailMessage, Config.Webhooks.jailLogWebhook)
        end
    else
        print("Virheellinen komento! Käytä: /jail [pelaajan ID] [aika minuutteina]")
    end
end, false)
