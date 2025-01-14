-- Tarkistetaan kansion nimi
local folderName = GetCurrentResourceName()

-- Jos kansio ei ole "dextys_log", lopetetaan skripti
if folderName ~= "dextys_log" then
    print("Virhe: Tämä skripti vaatii, että se on nimeltään 'dextys_log'.")
    return
end

-- Lataa konfiguraatio
local Config = require('config')

-- Funktio Discord-viestin lähettämiseen
local function sendToDiscord(message, webhookURL)
    local embed = {
        {
            ["color"] = 16711680,  -- Punainen väri (voit muuttaa väriä)
            ["title"] = "Server Log",
            ["description"] = message,
            ["footer"] = {
                ["text"] = "QBcore - Server Log",
            },
        }
    }

    PerformHttpRequest(webhookURL, function(err, text, headers)
        -- Voit käsitellä virheitä täällä, mutta tällä hetkellä ei tehdä mitään
    end, 'POST', json.encode({username = "Server Log", embeds = embed}), { ['Content-Type'] = 'application/json' })
end

-- Kuolinsyy logiikka
AddEventHandler('qb-core:server:playerDied', function(playerId, cause, killerId)
    local playerName = GetPlayerName(playerId)
    local killerName = killerId and GetPlayerName(killerId) or nil
    local killMethod = cause
    local killerWeapon = nil

    -- Määritetään kuolinsyy ja ase
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
    local playerName = GetPlayerName(src)
    local playerId = GetPlayerServerId(src)
    local targetId = tonumber(args[1])  -- Vangittavan pelaajan ID
    local jailTime = tonumber(args[2])  -- Vankilassaoloaika

    if targetId and jailTime then
        local targetPlayer = GetPlayerName(targetId)
        
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
                playerName, playerId, targetPlayer, targetId, jailTime
            )
            sendToDiscord(jailMessage, Config.Webhooks.jailLogWebhook)
        end
    else
        print("Virheellinen komento! Käytä: /jail [pelaajan ID] [aika minuutteina]")
    end
end, false)

-- Laskujen lähettäminen logiikka
local billLog = {}

RegisterServerEvent('okokBilling:sendBill')
AddEventHandler('okokBilling:sendBill', function(billId, amount, reason, targetId)
    local src = source
    local senderName = GetPlayerName(src)
    local senderId = GetPlayerServerId(src)
    local targetName = GetPlayerName(targetId)

    -- Tallennetaan lasku logiin
    billLog[billId] = {
        senderId = senderId,
        senderName = senderName,
        targetId = targetId,
        targetName = targetName,
        amount = amount,
        reason = reason,
        sentTime = os.time(),
        paid = false  -- Aluksi lasku ei ole maksettu
    }

    -- Tallennetaan laskun lähettäminen aikaleimalla
    if not billLog[senderId] then
        billLog[senderId] = {}
    end

    -- Lisää uusi lasku lähettäjän logiin
    table.insert(billLog[senderId], {billId = billId, time = os.time()})

    -- Poistetaan vanhat laskut, jotka ovat yli 10 sekuntia vanhoja
    for i = #billLog[senderId], 1, -1 do
        if os.time() - billLog[senderId][i].time > 10 then
            table.remove(billLog[senderId], i)
        end
    end

    -- Tarkistetaan, onko pelaaja lähettänyt yli kaksi laskua 10 sekunnin sisällä
    if #billLog[senderId] > 2 then
        local billMessage = string.format(
            "HUOMIO! Pelaaja: %s (ID: %s) lähetti yli kaksi laskua 10 sekunnin sisällä!\n",
            senderName, senderId
        )

        -- Lisää kaikki laskujen saajat ja määrät
        billMessage = billMessage .. "Lähetetyt laskut ja vastaanottajat:\n"
        for _, v in ipairs(billLog[senderId]) do
            billMessage = billMessage .. string.format("Vastaanottaja: %s (ID: %s) Lasku: $%s, Syy: %s\n", 
            v.targetName, v.targetId, v.amount, v.reason)
        end

        -- Lähetetään huijausviesti Discordiin
        sendToDiscord(billMessage, Config.Webhooks.cheatLogWebhook)
    else
        -- Lähetetään tavallinen laskutuslogiviesti Discordiin
        local billMessage = string.format(
            "Lasku lähetetty:\nLähettäjä: %s (ID: %s)\nVastaanottaja: %s (ID: %s)\nSumma: $%s\nSyy: %s",
            senderName, senderId, targetName, targetId, amount, reason
        )
        sendToDiscord(billMessage, Config.Webhooks.billingLogWebhook)
    end
end)

-- Seuraa maksamattomia laskuja (7 päivän tarkistus)
Citizen.CreateThread(function()
    while true do
        Citizen.Wait(86400000)  -- Odotetaan 24 tuntia (24h = 86400 sekuntia)

        -- Tarkistetaan kaikki laskut
        for billId, bill in pairs(billLog) do
            if not bill.paid then
                local daysPassed = (os.time() - bill.sentTime) / (60 * 60 * 24)  -- Aika laskun lähettämisestä päivinä

                -- Jos lasku on ollut maksamatta 7 päivää
                if daysPassed >= 7 then
                    local overdueMessage = string.format(
                        "Maksamaton lasku:\nLähettäjä: %s (ID: %s)\nVastaanottaja: %s (ID: %s)\nSumma: $%s\nLasku lähetty: %d päivää sitten\nSyy: %s",
                        bill.senderName, bill.senderId, bill.targetName, bill.targetId, bill.amount, math.floor(daysPassed), bill.reason
                    )
                    sendToDiscord(overdueMessage, Config.Webhooks.cheatLogWebhook)
                end
            end
        end
    end
end)

-- Rahansiirrot logi
local lastCashTransaction = {}

AddEventHandler('qb-core:server:playerLoaded', function(playerData)
    local playerId = playerData.source
    lastCashTransaction[playerId] = {cash = playerData.money["cash"], bank = playerData.money["bank"]} 
end)

-- Seuraa rahansiirtoja yli 300 000$ tapahtumia
RegisterServerEvent('qb-core:server:moneyTransaction')
AddEventHandler('qb-core:server:moneyTransaction', function(playerId, amount, transactionType)
    if transactionType == "deposit" or transactionType == "withdraw" then
        if amount >= 300000 then
            local playerName = GetPlayerName(playerId)
            local transactionMessage = string.format("Pelaaja: %s (ID: %s) teki rahansiirron: %s, summa: $%s",
                playerName, playerId, transactionType, amount)

            sendToDiscord(transactionMessage, Config.Webhooks.transactionLogWebhook)
        end
    end
end)
