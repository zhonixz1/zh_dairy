-- client.lua
Config = Config or {}

local spawnedCows       = {}     -- [index] = handle
local PromptGroup       = GetRandomIntInRange(0, 0xffffff)
local MilkPrompt        = nil
local playerHasTool     = true
local isMilking         = false
local milkingCowIndex   = nil

local VORPprogress      = exports.vorp_progressbar:initiate()

-- ───────────────────────────────────────────────────────────────────────────────
-- Loaders
-- ───────────────────────────────────────────────────────────────────────────────
local function LoadAnim(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do Wait(10) end
end

local function LoadModel(model)
    if not IsModelValid(model) then return false end
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end
    return true
end

local function HoldCompleted(prompt)
    return Citizen.InvokeNative(0xC92AC953F0A982AE, prompt)
end

-- ───────────────────────────────────────────────────────────────────────────────
-- Prompt
-- ───────────────────────────────────────────────────────────────────────────────
local function CreateMilkPrompt()
    local str = CreateVarString(10, "LITERAL_STRING", Config.Language.MilkPrompt)
    MilkPrompt = PromptRegisterBegin()
    PromptSetControlAction(MilkPrompt, 0x760A9C6F) -- G (change if needed)
    PromptSetText(MilkPrompt, str)
    PromptSetHoldMode(MilkPrompt, true)
    PromptSetEnabled(MilkPrompt, true)
    PromptSetVisible(MilkPrompt, true)
    PromptSetGroup(MilkPrompt, PromptGroup)
    PromptRegisterEnd(MilkPrompt)
end



-- ───────────────────────────────────────────────────────────────────────────────
-- Cow AI Modes
-- ───────────────────────────────────────────────────────────────────────────────

local function StopCowSmooth(cowPed)
    -- stop AI movement gently, then lock
    ClearPedTasks(cowPed)              -- cancels wander task
    TaskStandStill(cowPed, 1000)       -- “settle” 1s (looks natural)
    Wait(300)
end


local function StartCowRoam(cowPed, cow)
    if not cowPed or cowPed == 0 or not DoesEntityExist(cowPed) then return end

    ClearPedTasks(cowPed)
    FreezeEntityPosition(cowPed, true)
    SetBlockingOfNonTemporaryEvents(cowPed, true)

   
end

local function LockCowForMilking(cowPed)
    if not cowPed or cowPed == 0 or not DoesEntityExist(cowPed) then return end

    LoadAnim("mini_games@story@mar5@milk_cow")
    ClearPedTasks(cowPed)
    FreezeEntityPosition(cowPed, true)
    SetBlockingOfNonTemporaryEvents(cowPed, true)
    SetEntityCanBeDamaged(cowPed, false)
    SetEntityInvincible(cowPed, true)

    TaskPlayAnim(cowPed, "mini_games@story@mar5@milk_cow", "cow_idle", 1.0, 1.0, -1, 1, 0, false, false, false)
end

local function UnlockCowAfterMilking(cowPed, cow)
    if not cowPed or cowPed == 0 or not DoesEntityExist(cowPed) then return end

    FreezeEntityPosition(cowPed, false)
    SetBlockingOfNonTemporaryEvents(cowPed, false)
    StartCowRoam(cowPed, cow)
end

-- ───────────────────────────────────────────────────────────────────────────────
-- Spawn / Despawn Thread
-- ───────────────────────────────────────────────────────────────────────────────
CreateThread(function()
    CreateMilkPrompt()

    while true do
        local sleep = 4500
        local ped = PlayerPedId()
        local pCoords = GetEntityCoords(ped)

        for i, cow in ipairs(Config.Cows) do
            local dist = #(pCoords - cow.coords.xyz)

            if dist < (cow.radius + 30.0) then
                sleep = 250

                if not spawnedCows[i] then
                    if not LoadModel(cow.model) then goto continue end

                    local handle = CreatePed(cow.model, cow.coords.x, cow.coords.y, cow.coords.z, cow.coords.w, false, false, false, false)
                    while not DoesEntityExist(handle) do Wait(0) end
                    Citizen.InvokeNative(0x283978A15512B2FE, handle, true)
                    SetEntityAsMissionEntity(handle, true, true)
                    SetEntityCanBeDamaged(handle, false)
                    SetEntityInvincible(handle, true)
                    PlaceEntityOnGroundProperly(handle)
                    TaskStartScenarioInPlace(handle, joaat("WORLD_ANIMAL_COW_GRAZING"), -1, true)
                    spawnedCows[i] = handle

                    StartCowRoam(handle, cow)
                end
            elseif spawnedCows[i] then
                if not isMilking or milkingCowIndex ~= i then
                    if DoesEntityExist(spawnedCows[i]) then DeleteEntity(spawnedCows[i]) end
                    spawnedCows[i] = nil
                end
            end
            ::continue::
        end

        Wait(sleep)
    end
end)


-- ───────────────────────────────────────────────────────────────────────────────
-- Interaction Loop
-- ───────────────────────────────────────────────────────────────────────────────
CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local pCoords = GetEntityCoords(ped)

        if playerHasTool and not isMilking then
            for i, cow in ipairs(Config.Cows) do
                local h = spawnedCows[i]
                if h and DoesEntityExist(h) then
                    local dist = #(pCoords - GetEntityCoords(h))

                    if dist < 2.0 then
                        sleep = 0
                        PromptSetActiveGroupThisFrame(
                            PromptGroup,
                            CreateVarString(10, "LITERAL_STRING", Config.Language.PromptLabel)
                        )

                        if PromptHasHoldModeCompleted(MilkPrompt) then
                                milkingCowIndex = i
                                if spawnedCows[i] and DoesEntityExist(spawnedCows[i]) then
                                    ClearPedTasks(spawnedCows[i])
                                end
                                TriggerServerEvent("qq_milking:tryMilkCow", i)
                                Wait(800)
                        end
                    end
                end
            end
        end

        Wait(sleep)
    end
end)

-- ───────────────────────────────────────────────────────────────────────────────
-- Start Milking (server approved)
-- ───────────────────────────────────────────────────────────────────────────────
RegisterNetEvent("qq_milking:startMilkingClient")
AddEventHandler("qq_milking:startMilkingClient", function(cowIndex)
    isMilking = true
    cowIndex = tonumber(cowIndex)
    local cowHandle = spawnedCows[cowIndex]
    if not cowHandle or not DoesEntityExist(cowHandle) then
        isMilking = false
        milkingCowIndex = nil
        TriggerServerEvent("qq_milking:cancelMilking", cowIndex)
        return
    end

    local player = PlayerPedId()

    -- Load anims early
    LoadAnim("mini_games@story@mar5@milk_cow")
    LoadAnim("mech_milking")
    SetBlockingOfNonTemporaryEvents(cowHandle, true) -- stop new ambient tasks
    StopCowSmooth(cowHandle)

    -- 2) Now freeze + cow idle anim (locked)
    FreezeEntityPosition(cowHandle, true)
    SetEntityCanBeDamaged(cowHandle, false)
    SetEntityInvincible(cowHandle, true)
    TaskPlayAnim(cowHandle, "mini_games@story@mar5@milk_cow", "cow_idle", 1.0, 1.0, -1, 1, 0, false, false, false)

    local boneIndex = GetEntityBoneIndexByName(cowHandle, "skel_l_BackFlap00")

    if boneIndex ~= -1 then
        local boneCoords = GetWorldPositionOfEntityBone(cowHandle, boneIndex)
        TaskTurnPedToFaceCoord(player, boneCoords.x, boneCoords.y, boneCoords.z, -1)
    else
        -- fallback if bone not found
        TaskTurnPedToFaceEntity(player, cowHandle, -1)
    end
    Wait(850)

    ClearPedTasks(player)
    TaskPlayAnim(player, "mech_milking", "milking_loop_player", 3.0, 3.0, -1, 1, 0, false, false, false)
    FreezeEntityPosition(player, true)

    -- Sound
    Citizen.InvokeNative(0x706D57B0F50DA710, "MAR5_MILKING")

    local milkTime = tonumber(Config.Cows[cowIndex].milkTime) or 5000

    local finished = false
    local function Finish()
        if finished then return end
        finished = true

        Citizen.InvokeNative(0x706D57B0F50DA710, "MC_MUSIC_STOP")

        FreezeEntityPosition(player, false)
        ClearPedTasks(player)

        -- unlock cow + resume roam
        FreezeEntityPosition(cowHandle, false)
        SetBlockingOfNonTemporaryEvents(cowHandle, false)
        StartCowRoam(cowHandle, Config.Cows[cowIndex])

        TriggerServerEvent("qq_milking:finishMilking", cowIndex)

        isMilking = false
        milkingCowIndex = nil
    end

    -- Progressbar + fallback
    if Config.Progressbar and Config.Progressbar.useVorp then
        VORPprogress.start(Config.Language.Milking, milkTime, Finish)
    end

    CreateThread(function()
        Wait(milkTime + 750)
        Finish()
    end)
end)


-- ───────────────────────────────────────────────────────────────────────────────
-- Cleanup
-- ───────────────────────────────────────────────────────────────────────────────
AddEventHandler("onResourceStop", function(resource)
    if resource ~= GetCurrentResourceName() then return end

    for _, handle in pairs(spawnedCows) do
        if handle and DoesEntityExist(handle) then
            DeleteEntity(handle)
        end
    end
    spawnedCows = {}

    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    ClearPedTasksImmediately(ped)
end)
