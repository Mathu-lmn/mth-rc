local rc_entity = nil
local rc_camera = nil
local isCameraActive = false
local index_vision = 0
local rc_model = `rcbandito`
local controller = `prop_controller_01`
local tablet = nil
local distanceCheck = nil
-- scaleforms
local scaleform = nil
local limit = nil
local blip = nil
local outOfRange = false
local driver = nil

if Config.UseCommand then
    RegisterCommand('rc', function()
        ToggleRcCar()
    end)
end

if Config.Recall then
    RegisterCommand("recall", function()
        local playerCoords = GetEntityCoords(PlayerPedId())  -- PlayerPedId() returns the player's ped ID.
        local carCoords = GetEntityCoords(rc_entity)         -- Get the car's coords.
        -- Check if there is a driver in the car, if not, create one.
        if GetPedInVehicleSeat(rc_entity, -1) == 0 then
            local player = `cs_brad`
            RequestModel(player)
            while not HasModelLoaded(player) do
                Citizen.Wait(0)
            end
            driver = CreatePed(1, player, carCoords.x, carCoords.y, carCoords.z, 0.0, false, true)
            SetPedIntoVehicle(driver, rc_entity, -1)
            SetBlockingOfNonTemporaryEvents(driver, true)
            -- can't talk
            SetModelAsNoLongerNeeded(player)
        end

        local temp = GetPedInVehicleSeat(rc_entity, -1)
        TaskVehicleDriveToCoord(temp, rc_entity, playerCoords.x, playerCoords.y, playerCoords.z, 20.0, 0,
            GetEntityModel(rc_entity), 786603, 2.0, true)
    end)
end
RegisterNetEvent('mth-rc:client:SpawnRcCar')
AddEventHandler('mth-rc:client:SpawnRcCar', function()
    ToggleRcCar()
end)

function ToggleRcCar()
    if rc_entity ~= nil then
        if distanceCheck < 5.0 and not Config.DespawnOnCommand then
            PlayAnim()
            DeleteRc()
        elseif Config.DespawnOnCommand then
            ClearPedTasks(PlayerPedId())
            DeleteRc()
        else
            ShowNotification("You are too far from the car!")
        end
    else
        SpawnRcCar()
    end
end

function SpawnRcCar()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)

    RequestModel(rc_model)
    local time = GetGameTimer()
    while not HasModelLoaded(rc_model) do
        Citizen.Wait(0)
        if GetGameTimer() - time > 5000 then
            print("Failed to load model " .. rc_model)
            return
        end
    end

    PlayAnim()
    Wait(700)
    local front_coords = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 1.0, 0.0)
    rc_entity = CreateVehicle(rc_model, front_coords, GetEntityHeading(playerPed), true, false)
    SetModelAsNoLongerNeeded(rc_model)
    SetVehicleOnGroundProperly(rc_entity)
    SetVehicleEngineOn(rc_entity, true, true, false)
    SetVehicleModKit(rc_entity, 0)
    SetVehicleMod(rc_entity, 48, math.random(0, GetNumVehicleMods(rc_entity, 48)), false)
    SetEntityAsMissionEntity(rc_entity, true, true)
    SetVehicleHasBeenOwnedByPlayer(rc_entity, true)
    SetVehicleDoorsLocked(rc_entity, 2)
    if Config.DisableCollision then
        -- disable collision with the car but not with the world (don't want to fall through the ground)
        SetEntityNoCollisionEntity(rc_entity, playerPed, false)
        Citizen.CreateThread(function()
            while DoesEntityExist(rc_entity) do
                Citizen.Wait(5000)
                -- get all players
                local players = GetActivePlayers()
                -- get player coords
                playerCoords = GetEntityCoords(playerPed)
                -- loop through all players
                for _, player in pairs(players) do
                    local playerPed = GetPlayerPed(player)
                    SetEntityNoCollisionEntity(rc_entity, playerPed, false)
                end
            end
        end)
    end
    if Config.Blip then
        blip = AddBlipForEntity(rc_entity)
        SetBlipSprite(blip, 647)
        SetBlipColour(blip, 5)
        SetBlipScale(blip, 0.5)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString("RC Car")
        EndTextCommandSetBlipName(blip)
    end
    Wait(800)
    rc_camera = CreateCam("DEFAULT_SCRIPTED_CAMERA", true)
    AttachCamToEntity(rc_camera, rc_entity, 0.0, 0.0, 0.4, true)

    CreateAnimLoop()
    CreateRCLoop(rc_entity, rc_camera)
end

function CreateAnimLoop()
    -- play animation on the ped (he is on the phone and controlling the car until the car is destroyed)
    local playerCoords = GetEntityCoords(playerPed)
    local playerHeading = GetEntityHeading(playerPed)
    local animDict = "stand_controller@dad"
    local animName = "stand_controller_clip"

    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do
        Citizen.Wait(0)
    end

    RequestModel(controller)
    while not HasModelLoaded(controller) do
        Citizen.Wait(0)
    end

    tablet = CreateObject(controller, playerCoords, true, true, false)
    AttachEntityToEntity(tablet, PlayerPedId(), GetPedBoneIndex(PlayerPedId(), 18905), 0.15, 0.02, 0.09, -136.30, -54.8,
        5.4, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(controller)

    TaskPlayAnim(PlayerPedId(), animDict, animName, 3.0, -8, -1, 63, 0, 0, 0, 0)

    Citizen.CreateThread(function()
        while not outOfRange and DoesEntityExist(rc_entity) do
            if not IsEntityPlayingAnim(PlayerPedId(), animDict, animName, 3) then
                TaskPlayAnim(PlayerPedId(), animDict, animName, 3.0, -8, -1, 63, 0, 0, 0, 0)
            end
            SetCamRot(rc_camera, GetEntityRotation(rc_entity))
            Citizen.Wait(5)
        end
    end)
end

function CreateRCLoop(entity, cam)
    -- temp thread to allow destroying car with 'E' key before entering the camera mode
    Citizen.CreateThread(function()
        if Config.BlowUpEnabled then
            while DoesEntityExist(rc_entity) and not outOfRange do
                Citizen.Wait(0)
                if IsControlJustPressed(0, 38) then
                    BlowUp()
                end
            end
        end
    end)


    Citizen.CreateThread(function()
        while DoesEntityExist(rc_entity) do
            distanceCheck = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(rc_entity))
            if distanceCheck > Config.LoseConnectionDistance - 15.0 then
                ShowNotification("You are going too far !")
            end
            if NetworkHasControlOfEntity(rc_entity) == false then
                NetworkRequestControlOfEntity(rc_entity)
            end
            Citizen.Wait(1500)
        end
    end)
    Citizen.CreateThread(function()
        while DoesEntityExist(rc_entity) do
            Citizen.Wait(0)

            -- Toggle camera view with 'G' key
            if IsControlJustPressed(0, 47) and rc_entity ~= nil and not outOfRange then
                if isCameraActive then
                    RenderScriptCams(false, false, 0, true, true)
                    isCameraActive = false
                    SetSeethrough(false)
                    SetNightvision(false)
                    index_vision = 0
                    isHeatVisionEnabled = false
                else
                    RenderScriptCams(true, false, 0, true, true)
                    isCameraActive = true
                    Citizen.CreateThread(function()
                        while isCameraActive and DoesEntityExist(rc_entity) do
                            Citizen.Wait(0)
                            if distanceCheck > Config.LoseConnectionDistance then
                                DrawLimitScaleform()
                            else
                                DrawScaleform()
                            end

                            if IsControlJustPressed(0, 19) then
                                if index_vision == 0 then
                                    SetSeethrough(true)
                                    SetNightvision(false)
                                    index_vision = 1
                                elseif index_vision == 1 then
                                    SetNightvision(true)
                                    SetSeethrough(false)
                                    index_vision = 2
                                elseif index_vision == 2 then
                                    SetSeethrough(false)
                                    SetNightvision(false)
                                    index_vision = 0
                                end
                            end
                        end
                    end)
                end
            end

            DrawDriveInstructions()

            if distanceCheck < Config.LoseConnectionDistance then
                if outOfRange == true then
                    outOfRange = false
                    ShowNotification("You are back in range !")
                    CreateAnimLoop()
                    Citizen.CreateThread(function()
                        if Config.BlowUpEnabled then
                            while DoesEntityExist(rc_entity) and not outOfRange do
                                Citizen.Wait(0)
                                if IsControlJustPressed(0, 38) then
                                    BlowUp()
                                end
                            end
                        end
                    end)
                end
                -- FRONT / BACK
                if IsControlPressed(0, 172) then
                    TaskVehicleTempAction(PlayerPedId(), rc_entity, 9, 1)
                end
                if IsControlPressed(0, 173) then
                    TaskVehicleTempAction(PlayerPedId(), rc_entity, 22, 1)
                end
                if IsControlJustReleased(0, 172) or IsControlJustReleased(0, 173) then
                    TaskVehicleTempAction(PlayerPedId(), rc_entity, 6, 1500)
                end
                -- LEFT / RIGHT + FRONT
                if IsControlPressed(0, 174) and IsControlPressed(0, 173) then
                    TaskVehicleTempAction(PlayerPedId(), rc_entity, 13, 1)
                end
                if IsControlPressed(0, 175) and IsControlPressed(0, 173) then
                    TaskVehicleTempAction(PlayerPedId(), rc_entity, 14, 1)
                end
                -- LEFT / RIGHT + BACK
                if IsControlPressed(0, 174) and IsControlPressed(0, 172) then
                    TaskVehicleTempAction(PlayerPedId(), rc_entity, 7, 1)
                end
                if IsControlPressed(0, 175) and IsControlPressed(0, 172) then
                    TaskVehicleTempAction(PlayerPedId(), rc_entity, 8, 1)
                end
                -- LEFT / RIGHT ONLY
                if IsControlPressed(0, 174) and not IsControlPressed(0, 172) and not IsControlPressed(0, 173) then
                    TaskVehicleTempAction(PlayerPedId(), rc_entity, 4, 1)
                end
                if IsControlPressed(0, 175) and not IsControlPressed(0, 172) and not IsControlPressed(0, 173) then
                    TaskVehicleTempAction(PlayerPedId(), rc_entity, 5, 1)
                end
            else
                if not outOfRange then
                    TaskVehicleTempAction(PlayerPedId(), rc_entity, 6, 1500)
                    -- reset camera to ped
                    SetTimeout(300, function()
                        RenderScriptCams(false, false, 0, true, true)
                        isCameraActive = false
                        SetSeethrough(false)
                        SetNightvision(false)
                        index_vision = 0
                        isHeatVisionEnabled = false
                        -- clear ped tasks
                        ClearPedTasks(PlayerPedId())
                        DeleteEntity(tablet)
                    end)
                    outOfRange = true
                end
            end
            if IsEntityDead(PlayerPedId()) then
                DeleteRc()
            end
            if GetEntitySubmergedLevel(rc_entity) > 0.5 then
                ShowNotification("Your RC has short circuited !")
                -- make it spark electric
                SetVehicleEngineHealth(rc_entity, 0)
                CreateThread(function()
                    RequestNamedPtfxAsset("core")
                    -- Wait until it's done loading.
                    while not HasNamedPtfxAssetLoaded("core") do
                        Wait(0)
                    end

                    local particleTbl = {}

                    for i = 0, 25 do
                        UseParticleFxAsset("core")
                        local partiResult = StartNetworkedParticleFxLoopedOnEntity("ent_dst_elec_fire_sp", rc_entity, 0.0,
                            0.0, 0.0, 0.0, 0.0, 0.0, 1.5, false, false, false)
                        particleTbl[#particleTbl + 1] = partiResult
                        Wait(0)
                    end

                    Wait(1000)
                    for _, particle in ipairs(particleTbl) do
                        StopParticleFxLooped(particle, true)
                    end
                end)
                Wait(1000)
                ClearPedTasks(PlayerPedId())
                if driver then
                    DeleteEntity(driver)
                end
                RenderScriptCams(false, false, 0, true, true)
                DestroyCam(rc_camera)
                DeleteEntity(tablet)
                if DoesBlipExist(blip) then
                    RemoveBlip(blip)
                end
                SetSeethrough(false)
                SetNightvision(false)
                -- Reset variables
                blip = nil
                rc_entity = nil
                rc_camera = nil
                tablet = nil
                isCameraActive = false
                index_vision = 0
                isHeatVisionEnabled = false
            end
        end
    end)
end

function PlayAnim()
    -- play pickup animation
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local playerHeading = GetEntityHeading(playerPed)
    local animDict = "pickup_object"
    local animName = "pickup_low"

    RequestAnimDict(animDict)

    while not HasAnimDictLoaded(animDict) do
        Citizen.Wait(0)
    end

    TaskPlayAnim(playerPed, animDict, animName, 8.0, 8.0, -1, 50, 0, false, false, false)
    SetTimeout(700, function()
        ClearPedTasks(playerPed)
    end)
    RemoveAnimDict(animDict)
end

function ShowNotification(text)
    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandThefeedPostTicker(false, false)
end

local steeringButtons = {
    {
        ["label"] = "Right",
        ["button"] = "~INPUT_CELLPHONE_RIGHT~"
    },
    {
        ["label"] = "Forward",
        ["button"] = "~INPUT_CELLPHONE_UP~"
    },
    {
        ["label"] = "Reverse",
        ["button"] = "~INPUT_CELLPHONE_DOWN~"
    },
    {
        ["label"] = "Left",
        ["button"] = "~INPUT_CELLPHONE_LEFT~"
    },
}

local buttonsToDraw = {}

local inCameraButtons = {
    {
        ["label"] = "Change Vision Mode",
        ["button"] = GetControlInstructionalButton(0, 19, 1)
    }
}

local blowUpButton = {
    {
        ["label"] = "Self Destruct",
        ["button"] = "~INPUT_PICKUP~"
    }
}

function DrawDriveInstructions()
    buttonsToDraw = {}
    if distanceCheck <= Config.LoseConnectionDistance then
        for buttonIndex = 1, #steeringButtons do
            local steeringButton = steeringButtons[buttonIndex]

            table.insert(buttonsToDraw, steeringButton)
        end
        table.insert(buttonsToDraw, {
            ["label"] = "Toggle Camera",
            ["button"] = "~INPUT_DETONATE~"
        })
        if Config.BlowUpEnabled then
            for buttonIndex = 1, #blowUpButton do
                local blowUpButton = blowUpButton[buttonIndex]

                table.insert(buttonsToDraw, blowUpButton)
            end
        end
    end

    if isCameraActive then
        for buttonIndex = 1, #inCameraButtons do
            local inCameraButton = inCameraButtons[buttonIndex]

            table.insert(buttonsToDraw, inCameraButton)
        end
    end

    Citizen.CreateThread(function()
        local instructionScaleform = RequestScaleformMovie("instructional_buttons")

        while not HasScaleformMovieLoaded(instructionScaleform) do
            Wait(0)
        end

        PushScaleformMovieFunction(instructionScaleform, "CLEAR_ALL")
        PushScaleformMovieFunction(instructionScaleform, "TOGGLE_MOUSE_BUTTONS")
        PushScaleformMovieFunctionParameterBool(0)
        PopScaleformMovieFunctionVoid()

        for buttonIndex, buttonValues in ipairs(buttonsToDraw) do
            PushScaleformMovieFunction(instructionScaleform, "SET_DATA_SLOT")
            PushScaleformMovieFunctionParameterInt(buttonIndex - 1)

            PushScaleformMovieMethodParameterButtonName(buttonValues["button"])
            PushScaleformMovieFunctionParameterString(buttonValues["label"])
            PopScaleformMovieFunctionVoid()
        end

        PushScaleformMovieFunction(instructionScaleform, "DRAW_INSTRUCTIONAL_BUTTONS")
        PushScaleformMovieFunctionParameterInt(-1)
        PopScaleformMovieFunctionVoid()
        DrawScaleformMovieFullscreen(instructionScaleform, 255, 255, 255, 255)
    end)
end

function BlowUp()
    if not Config.BlowUpEnabled then
        return
    end
    AddExplosion(GetEntityCoords(rc_entity), 69, 0.5, true, false, 1.0)
    for i = 0, 7 do
        BreakOffVehicleWheel(rc_entity, i, true, false, true, false)
    end
    Wait(1000)
    if driver then
        DeleteEntity(driver)
    end
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(rc_camera)
    DeleteEntity(tablet)
    if DoesBlipExist(blip) then
        RemoveBlip(blip)
    end
    -- Reset variables
    blip = nil
    rc_entity = nil
    rc_camera = nil
    tablet = nil
    isCameraActive = false
    index_vision = 0
    isHeatVisionEnabled = false
    SetSeethrough(false)
    SetNightvision(false)
    ClearPedTasks(PlayerPedId())
end

function DeleteRc()
    DeleteEntity(rc_entity)
    if driver then
        DeleteEntity(driver)
    end
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(rc_camera)
    DeleteEntity(tablet)
    if DoesBlipExist(blip) then
        RemoveBlip(blip)
    end
    -- Reset variables
    blip = nil
    rc_entity = nil
    rc_camera = nil
    tablet = nil
    isCameraActive = false
    index_vision = 0
    SetSeethrough(false)
    SetNightvision(false)
    isHeatVisionEnabled = false
end

function DrawScaleform()
    -- scaleform that shows distorted image when RC car is too far away
    if not HasScaleformMovieLoaded(scaleform) then
        scaleform = RequestScaleformMovie("security_cam")
        while not HasScaleformMovieLoaded(scaleform) do
            Wait(0)
        end
    end

    local plyPos = GetEntityCoords(PlayerPedId(), true)
    local s1, s2 = GetStreetNameAtCoord(plyPos.x, plyPos.y, plyPos.z)
    local street1 = GetStreetNameFromHashKey(s1)
    local street2 = GetStreetNameFromHashKey(s2)
    local zone = GetNameOfZone(plyPos.x, plyPos.y, plyPos.z)
    local playerZoneName = GetLabelText(zone)
    local currentTime = { GetClockHours(), GetClockMinutes() }

    PushScaleformMovieFunction(scaleform, "SET_LOCATION")
    PushScaleformMovieFunctionParameterString(playerZoneName)
    PopScaleformMovieFunctionVoid()
    PushScaleformMovieFunction(scaleform, "SET_DETAILS")
    PushScaleformMovieFunctionParameterString(street1 .. " / " .. street2)
    PopScaleformMovieFunctionVoid()
    PushScaleformMovieFunction(scaleform, "SET_TIME")
    PushScaleformMovieFunctionParameterString(currentTime[1])
    PushScaleformMovieFunctionParameterString(currentTime[2])
    PopScaleformMovieFunctionVoid()

    DrawScaleformMovieFullscreen(scaleform, 255, 255, 255, 255)
end

function DrawLimitScaleform()
    if not HasScaleformMovieLoaded(limit) then
        limit = RequestScaleformMovie("security_camera")
        while not HasScaleformMovieLoaded(limit) do
            Wait(0)
        end

        PushScaleformMovieFunction(limit, "SHOW_STATIC")
        PushScaleformMovieFunctionParameterBool(true)
        PopScaleformMovieFunctionVoid()
    end

    DrawScaleformMovieFullscreen(limit, 0, 0, 0, 100)
end

AddEventHandler("onResourceStop", function(resource)
    if resource == GetCurrentResourceName() then
        if rc_entity ~= nil then
            ClearPedTasksImmediately(PlayerPedId())
            DeleteRc()
        end
    end
end)
