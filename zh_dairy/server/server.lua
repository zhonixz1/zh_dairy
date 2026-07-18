local VORPcore = exports.vorp_core:GetCore()
local VORPinv  = exports.vorp_inventory:vorp_inventoryApi()

RegisterServerEvent("qq_milking:tryMilkCow")
AddEventHandler("qq_milking:tryMilkCow", function(cowIndex)
    local src = source
    if Config.RequiredItem then
        local count = VORPinv.getItemCount(src, Config.RequiredItem)
        if count < 1 then
            TriggerClientEvent("qq-notify:Alert", src, "Hata", Config.Language.NoTool, 4000, "error")
            return
        end
    end
    TriggerClientEvent("qq_milking:startMilkingClient", src, cowIndex)
end)


RegisterServerEvent("qq_milking:finishMilking")
AddEventHandler("qq_milking:finishMilking", function(cowIndex)
    local src = source

    local Character = VORPcore.getUser(src).getUsedCharacter
    if Config.Cows[cowIndex].rewardItem then
        local count = 1

        TriggerEvent("vorpCore:canCarryItems", tonumber(src), count, function(canCarry)
            TriggerEvent("vorpCore:canCarryItem", tonumber(src), Config.Cows[cowIndex].rewardItem, count, function(canCarry2)
                if canCarry and canCarry2 then
                   VORPinv.subItem(src, Config.RequiredItem, 1)
                    VORPinv.addItem(src, Config.Cows[cowIndex].rewardItem, 1)
                    TriggerClientEvent("qq-notify:Alert", src, "Süt", "Bir şişe süt doldurdun", 5000, "success")
                else
                    TriggerClientEvent("qq-notify:Alert", src, 'Süt', "Daha fazla süt şişesi taşıyamazsın!", 3000, 'error')
                end
            end)
        end)
    end
end)

local playerTimers = {}
local playerBusy   = {} 

local function GetPlayerKey(src)
    -- Try VORP character id first
    local ok, user = pcall(function() return VORPcore.getUser(src) end)
    if ok and user then
        local ch = user.getUsedCharacter
        -- Some VORP builds expose fields differently; try common ones:
        if type(ch) == "table" then
            if ch.charIdentifier then return "char:" .. tostring(ch.charIdentifier) end
            if ch.identifier then return "char:" .. tostring(ch.identifier) end
        end
        -- Sometimes getUsedCharacter is a function
        if type(user.getUsedCharacter) == "function" then
            local c = user.getUsedCharacter()
            if c and c.charIdentifier then return "char:" .. tostring(c.charIdentifier) end
            if c and c.identifier then return "char:" .. tostring(c.identifier) end
        end
    end

    -- Fallback: license
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:find("license:") == 1 then
            return id
        end
    end

    -- Worst fallback
    return "src:" .. tostring(src)
end

local function EnsurePlace(placeIndex)
    placeIndex = tonumber(placeIndex)
    if not placeIndex or not Config.Chickens[placeIndex] or not Config.Chickens[placeIndex].Chickens then
        return nil
    end
    return placeIndex
end

local function GetReadyAt(playerKey, placeIndex)
    if not playerTimers[playerKey] then return 0 end
    return tonumber(playerTimers[playerKey][placeIndex] or 0) or 0
end

local function SetReadyAt(playerKey, placeIndex, readyAt)
    playerTimers[playerKey] = playerTimers[playerKey] or {}
    playerTimers[playerKey][placeIndex] = tonumber(readyAt) or 0
end

-- Client asks current timer so UI can show remaining time after rejoin
RegisterServerEvent("qq_chickens:getMyChickenTimers")
AddEventHandler("qq_chickens:getMyChickenTimers", function()
    local src = source
    local key = GetPlayerKey(src)
    TriggerClientEvent("qq_chickens:setMyChickenTimers", src, playerTimers[key] or {})
end)

-- FEED
RegisterServerEvent("qq_chickens:tryFeed")
AddEventHandler("qq_chickens:tryFeed", function(placeIndex)
    local src = source
    if playerBusy[src] then return end
    playerBusy[src] = true

    placeIndex = EnsurePlace(placeIndex)
    if not placeIndex then playerBusy[src] = nil return end

    local key = GetPlayerKey(src)
    local place = Config.Chickens[placeIndex].Chickens
    local now = os.time()

    local readyAt = GetReadyAt(key, placeIndex)
    if readyAt > now then
        TriggerClientEvent("qq-notify:Alert", src, "Hayvancılık", "Tavuklar zaten beslenmiş!", 3000, "error")
        playerBusy[src] = nil
        return
    end

    if Config.FeedRequiredItem then
        local count = VORPinv.getItemCount(src, Config.FeedRequiredItem)
        if count < 1 then
            TriggerClientEvent("qq-notify:Alert", src, "Hayvancılık", "Tavukları beslemek için yeme ihtiyacın var!", 4000, "error")
            playerBusy[src] = nil
            return
        end
    end

    -- Let client play anim/progress then call finish
    TriggerClientEvent("qq_chickens:startFeedingClient", src, placeIndex)
    playerBusy[src] = nil
end)

RegisterServerEvent("qq_chickens:finishFeed")
AddEventHandler("qq_chickens:finishFeed", function(placeIndex)
    local src = source
    placeIndex = EnsurePlace(placeIndex)
    if not placeIndex then return end

    local key = GetPlayerKey(src)
    local place = Config.Chickens[placeIndex].Chickens
    local now = os.time()

    -- re-check items on finish (server authority)
    if Config.FeedRequiredItem then
        local count = VORPinv.getItemCount(src, Config.FeedRequiredItem)
        if count < 1 then
            TriggerClientEvent("qq-notify:Alert", src, "Hayvancılık", "Tavukları beslemek için yeme ihtiyacın var!", 4000, "error")
            return
        end
        VORPinv.subItem(src, Config.FeedRequiredItem, 1)
    end

    local waitSeconds = math.floor((tonumber(place.waittime) or 60000) / 1000)
    local newReadyAt = now + waitSeconds
    SetReadyAt(key, placeIndex, newReadyAt)

    -- push updated timers only to this player
    TriggerClientEvent("qq_chickens:setMyChickenTimers", src, playerTimers[key] or {})

    TriggerClientEvent("qq-notify:Alert", src, "Hayvancılık", "Tavukları besledin. Yumurtalar hazırlanıyor...", 3500, "success")
end)

RegisterServerEvent("qq_chickens:tryCollect")
AddEventHandler("qq_chickens:tryCollect", function(placeIndex)
    local src = source
    if playerBusy[src] then return end
    playerBusy[src] = true
    placeIndex = EnsurePlace(placeIndex)
    if not placeIndex then playerBusy[src] = nil return end
    local key = GetPlayerKey(src)
    local place = Config.Chickens[placeIndex].Chickens
    local now = os.time()
    
    local readyAt = GetReadyAt(key, placeIndex)
    if readyAt == 0 then
        TriggerClientEvent("qq-notify:Alert", src, "Hayvancılık", "Önce tavukları beslemelisin!", 3500, "error")
        playerBusy[src] = nil
        return
    end

    if now < readyAt then
        TriggerClientEvent("qq-notify:Alert", src, "Hayvancılık", "Yumurtalar henüz hazır değil!", 3000, "error")
        playerBusy[src] = nil
        return
    end

    if Config.CollectRequiredItem then
        local count = VORPinv.getItemCount(src, Config.CollectRequiredItem)
        if count < 1 then
            TriggerClientEvent("qq-notify:Alert", src,  "Hayvancılık", "Yumurta sepetin yok!", 4000, "error")
            playerBusy[src] = nil
            return
        end
    end

    TriggerClientEvent("qq_chickens:startCollectingClient", src, placeIndex)
    playerBusy[src] = nil
end)

RegisterServerEvent("qq_chickens:finishCollect")
AddEventHandler("qq_chickens:finishCollect", function(placeIndex)
    local src = source
    placeIndex = EnsurePlace(placeIndex)
    if not placeIndex then return end

    local key = GetPlayerKey(src)
    local place = Config.Chickens[placeIndex].Chickens
    local now = os.time()

    local readyAt = GetReadyAt(key, placeIndex)
    if readyAt == 0 or now < readyAt then
        TriggerClientEvent("qq-notify:Alert", src, "Hayvancılık", "Yumurtalar hazır değil!", 3000, "error")
        return
    end

    local rewardItem = place.rewardItem or "egg"
    local count = 1
    TriggerEvent("vorpCore:canCarryItems", tonumber(src), count, function(canCarry)
        TriggerEvent("vorpCore:canCarryItem", tonumber(src), rewardItem, count, function(canCarry2)
            if not canCarry or not canCarry2 then
                TriggerClientEvent("qq-notify:Alert", src, "Hayvancılık", "Daha fazla yumurta taşıyamazsın!", 3000, "error")
                return
            end

            if Config.CollectRequiredItem then
                local have = VORPinv.getItemCount(src, Config.CollectRequiredItem)
                if have < 1 then
                    TriggerClientEvent("qq-notify:Alert", src, "Hayvancılık", "Yumurta sepetin yok!", 4000, "error")
                    return
                end
                VORPinv.subItem(src, Config.CollectRequiredItem, 1)
            end

            VORPinv.addItem(src, rewardItem, count)

            SetReadyAt(key, placeIndex, 0)
            TriggerClientEvent("qq_chickens:setMyChickenTimers", src, playerTimers[key] or {})

            TriggerClientEvent("qq-notify:Alert", src, "Yumurta", "Bir sepet yumurta topladın!", 5000, "success")
        end)
    end)
end)

AddEventHandler("playerDropped", function()
    playerBusy[source] = nil
end)