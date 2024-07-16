addEvent("newmodels_reborn:receiveCustomModels", true)

loadedModels = {}

local currFreeIdDelay = 9500 -- ms
local FREE_ID_DELAY_STEP = 500 -- ms

local function applyElementCustomModel(element)
    local customModel = tonumber(getElementData(element, getCustomModelDataKey(element)))
    if not customModel then return end
    local loadedModel = loadedModels[customModel]
    if not loadedModel then return end

    if _getElementModel(element) == loadedModel.id then return end
    
    
    local upgrades, handling, paintjob
    if getElementType(element) == "vehicle" then
        upgrades = getVehicleUpgrades(element)
        handling = getVehicleHandling(element)
        paintjob = getVehiclePaintjob(element)
        
    end

    _setElementModel(element, loadedModel.id)

    
    if upgrades then
        for _, v in pairs(upgrades) do
            addVehicleUpgrade(element, v)
        end
    end
    if handling then
        for k, v in pairs(handling) do
            setVehicleHandling(element, k, v)
        end
    end
    if paintjob then
        setVehiclePaintjob(element, paintjob)
    end
end

local function loadCustomModel(customModel, elementToApply)
    if not tonumber(customModel) then return end

    local customInfo = customModels[customModel]
    if not customInfo then
        outputDebugString("Trying to load custom model " .. customModel .. " that does not exist", 2)
        return
    end

    if loadedModels[customModel] then
        outputDebugString("Trying to load custom model " .. customModel .. " that is already loaded", 1)
        return
    end

    local allocatedModel = engineRequestModel(customInfo.type, customInfo.baseModel)
    if not allocatedModel then
        outputDebugString("Failed to load custom model " .. customModel .. " due to model allocation failure", 1)
        return
    end
    
    local colPath, txdPath, dffPath = customInfo.col, customInfo.txd, customInfo.dff

    local col, txd, dff
    if colPath then
        col = engineLoadCOL(colPath)
    end
    if txdPath then
        txd = engineLoadTXD(txdPath)
    end
    if dffPath then
        dff = engineLoadDFF(dffPath)
    end

    if (colPath and not col)
        or (txdPath and not txd)
        or (dffPath and not dff) then
        if col and isElement(col) then destroyElement(col) end
        if txd and isElement(txd) then destroyElement(txd) end
        if dff and isElement(dff) then destroyElement(dff) end
        engineFreeModel(allocatedModel)
        outputDebugString("Failed to load custom model " .. customModel .. " due to col/txd/dff loading failure", 1)
        return
    end

    if (col and not engineReplaceCOL(col, allocatedModel))
        or (txd and not engineImportTXD(txd, allocatedModel))
        or (dff and not engineReplaceModel(dff, allocatedModel)) then
        if col and isElement(col) then destroyElement(col) end
        if txd and isElement(txd) then destroyElement(txd) end
        if dff and isElement(dff) then destroyElement(dff) end
        engineRestoreCOL(allocatedModel)
        engineRestoreModel(allocatedModel)
        engineFreeModel(allocatedModel)
        outputDebugString("Failed to load custom model " .. customModel .. " due to col/txd/dff replacing failure", 1)
        return
    end

    local elementTypes = { "vehicle" }
    if customInfo.type == "ped" then
        elementTypes = { "ped", "player" }
    elseif customInfo.type == "object" then
        elementTypes = { "object", "pickup" }
    end

    -- Set loadedModel info
    loadedModels[customModel] = {
        id = allocatedModel,
        baseModel = customInfo.baseModel,
        elementTypes = elementTypes,
        freeAllocatedTimer = nil,
        elements = { txd = txd, dff = dff, col = col }
    }

    if isElement(elementToApply) then
        applyElementCustomModel(elementToApply)
    end
end

local function countStreamedElementsWithCustomModel(elementTypes, customModel)
    local count = 0
    for _, elementType in pairs(elementTypes) do
        for _, v in pairs(getElementsByType(elementType, root, true)) do
            if getElementData(v, getCustomModelDataKey(elementType)) == customModel then
                count = count + 1
            end
        end
    end
    return count
end

local function freeAllocatedModelNow(customModel)
    local loadedModel = loadedModels[customModel]
    if not loadedModel then return end

    if isTimer(loadedModel.freeAllocatedTimer) then
        killTimer(loadedModel.freeAllocatedTimer)
    end
    engineFreeModel(loadedModel.id)
    if isElement(loadedModel.elements.col) then destroyElement(loadedModel.elements.col) end
    if isElement(loadedModel.elements.txd) then destroyElement(loadedModel.elements.txd) end
    if isElement(loadedModel.elements.dff) then destroyElement(loadedModel.elements.dff) end

    -- Unset loadedModel info
    loadedModels[customModel] = nil
end

local function freeAllocatedModel(customModel, loadedModel)
    if isTimer(loadedModel.freeAllocatedTimer) then
        killTimer(loadedModel.freeAllocatedTimer)
    end
    -- Do not free all models at once, delay each model by a bit
    currFreeIdDelay = currFreeIdDelay + FREE_ID_DELAY_STEP
    loadedModel.freeAllocatedTimer = setTimer(function()
        freeAllocatedModelNow(customModel)
        currFreeIdDelay = currFreeIdDelay - FREE_ID_DELAY_STEP
    end, currFreeIdDelay, 1)
end

local function freeAllocatedModelIfUnused(customModel)
    local loadedModel = loadedModels[customModel]
    if not loadedModel then return end
    if countStreamedElementsWithCustomModel(loadedModel.elementTypes, customModel) == 0 then
        freeAllocatedModel(customModel, loadedModel)
    end
end

local function setElementCustomModel(element)
    local customModel = getElementData(element, getCustomModelDataKey(element))
    if not customModel then return end
    if not loadedModels[customModel] then
        loadCustomModel(customModel, element)
    else
        applyElementCustomModel(element)
    end
end

addEventHandler("onClientElementDataChange", root, function(key, prevCustomModel, newCustomModel)
    if not isValidElement(source) then return end
    if key ~= getCustomModelDataKey(source) then return end
    prevCustomModel = tonumber(prevCustomModel)

    -- Get the base model of the previous custom model the element has
    local prevLoadedModelBaseModel
    if prevCustomModel then
        local prevLoadedModel = loadedModels[prevCustomModel]
        if prevLoadedModel then
            prevLoadedModelBaseModel = prevLoadedModel.baseModel
        end
    end

    if not newCustomModel then
        -- If resetting the custom model, free the allocated model if it's not used by any other element
        local loadedModel = loadedModels[newCustomModel]
        if loadedModel then
            freeAllocatedModel(newCustomModel, loadedModel)
        end
    else
        setElementCustomModel(source)
    end
    if prevCustomModel then
        -- Force-set the base model of the previous custom model if resetting the custom model
        if (not newCustomModel) and prevLoadedModelBaseModel then
            _setElementModel(source, prevLoadedModelBaseModel)
        end

        -- Free the previous custom model if it's not used by any other element
        freeAllocatedModelIfUnused(prevCustomModel)
    end
end)

addEventHandler("onClientElementStreamIn", root, function()
    if not isValidElement(source) then return end
    setElementCustomModel(source)
    
end)

addEventHandler("onClientElementStreamOut", root, function()
    if not isValidElement(source) then return end
    local customModel = getElementData(source, getCustomModelDataKey(source))
    if not customModel then return end
    freeAllocatedModelIfUnused(customModel)
end)

addEventHandler("onClientElementDestroy", root, function()
    if not isValidElement(source) then return end
    local customModel = getElementData(source, getCustomModelDataKey(source))
    if not customModel then return end
    freeAllocatedModelIfUnused(customModel)
end)

local function restoreElementBaseModels()
    -- Restore the base models of all elements with custom models
    for _, elementType in pairs(ELEMENT_TYPES) do
        for _, element in pairs(getElementsByType(elementType, root, true)) do
            local model = _getElementModel(element)
            for _, loadedModel in pairs(loadedModels) do
                if loadedModel.id == model then
                    _setElementModel(element, loadedModel.baseModel)
                    break
                end
            end
        end
    end
end


local sX,sY = guiGetScreenSize()
local centerX, centerY = sX/2, sY/2

function control()
    local theVeh = getPedOccupiedVehicle(localPlayer)
    if not theVeh then return end
    if not hasElementData(theVeh,"gData") then return end
    if (theVeh and getVehicleController(theVeh) == localPlayer) then
        local cx, cy, cz, wx, wy, wz, roll = getCameraMatrix()
        local target = Vector3(getWorldFromScreenPosition(centerX,centerY,15))
        local x,y,z = getVehicleComponentPosition(theVeh, "misc_a","world")
        local pos = Vector3(x,y,z)
        local dir = target - pos
        dir:normalize()
        local rot = getPedCameraRotation(localPlayer)
        --local newRX,newRY,newRZ = math.deg(dir.z) + 170, math.deg(dir.y), math.deg(dir.z)
        local newr = -rot + 180
        setVehicleComponentRotation(theVeh, "misc_a", math.deg(-dir.z) + 150 ,0, newr, "world")
    end
end

local gTimer = false

function gFunc()
    local lx,ly,lz = getElementPosition(localPlayer)

    local vehs = getElementsWithinRange(lx,ly,lz,200,"vehicle")
    for _, theVeh in pairs(vehs) do
        local gData = getElementData(theVeh,"gData")
        if gData and getVehicleController(theVeh) ~= false then
            if gData.waterCannon then
                local ghost = gData.ghost
                local ghostPed = gData.ghostPed
                if ghost then 
                    
                    local x,y,z = getVehicleComponentPosition(theVeh, "misc_a","world")
                    setVehicleComponentPosition(ghost, "misc_a",x,y,z,"world")
                    local rx,ry,rz = getVehicleComponentRotation(theVeh,"misc_a","parent")
                    local gx,gy,gz = getVehicleComponentRotation(ghost,"misc_a","parent")
                    --setVehicleComponentRotation(ghost,"misc_a",rx,ry,rz,"parent")
                    
                    if not gx or not rx then
                        setPedControlState(ghostPed, "special_control_left", false)
                        setPedControlState(ghostPed, "special_control_right", false)    
                        setPedControlState(ghostPed, "special_control_up", false)
                        setPedControlState(ghostPed, "special_control_down", false)
                        break 
                    end
                    local difz = rz - gz
                    if difz < -180 then difz = difz + 360 end
                    if difz > 180 then difz = difz - 360 end
                    if difz == 0 then 
                        setPedControlState(ghostPed, "special_control_left", false)
                        setPedControlState(ghostPed, "special_control_right", false) 
                        return end
                    if difz > 0 then 
                    setPedControlState(ghostPed, "special_control_right", false) 
                    setPedAnalogControlState(ghostPed, "special_control_left",1)
                    
                    elseif difz < 0 then 
                        setPedControlState(ghostPed, "special_control_left", false)
                        setPedAnalogControlState(ghostPed, "special_control_right",1)
                    else
                        setPedControlState(ghostPed, "special_control_left", false)
                        setPedControlState(ghostPed, "special_control_right", false)
                    end
                    --if gx < 180 then gx = gx + 180 end
                    --if gx > 180 then gx = gx - 180 end
                    local difx = rx - gx
                    
                    if difx < 180 then difx = difx + 360 end
                    if difx > 180 then difx = difx - 360 end
                    --difx = difx - 180
                    --outputChatBox(string.format("d %.1f r %.1f g %.1f",difx,rx,gx))
                    if difx == 0 then 
                        setPedControlState(ghostPed, "special_control_up", false)
                        setPedControlState(ghostPed, "special_control_down", false) 
                        return end
                    if difx < 0 then 
                    setPedControlState(ghostPed, "special_control_down", false) 
                    setPedControlState(ghostPed, "special_control_up",true)
                    
                    elseif difx > 0 then 
                        setPedControlState(ghostPed, "special_control_up", false)
                        setPedControlState(ghostPed, "special_control_down",true)
                    else
                        setPedControlState(ghostPed, "special_control_up", false)
                        setPedControlState(ghostPed, "special_control_down", false)
                    end
                end
            end
        end
    end
    
end

addEventHandler("newmodels_reborn:receiveCustomModels", resourceRoot, function(customModelsFromServer)
    restoreElementBaseModels()

    -- Unload all loaded models
    for customModel, _ in pairs(loadedModels) do
        freeAllocatedModelNow(customModel)
    end

    customModels = customModelsFromServer

    for _, elementType in pairs(ELEMENT_TYPES) do
        for _, element in pairs(getElementsByType(elementType, root, true)) do
            setElementCustomModel(element)
        end
    end
    if isTimer(gTimer) then killTimer(gTimer) end
    gTimer = setTimer(gFunc,200,0)
end, false)

addEventHandler("onClientResourceStop", resourceRoot, function()
    restoreElementBaseModels()
    if isTimer(gTimer) then killTimer(gTimer) end
    removeEventHandler("onClientRender", root, control)
end, false)


addEventHandler("onClientVehicleEnter", getRootElement(),
    function(thePlayer, seat)
        if seat == 0 then
            addEventHandler("onClientRender", root, control)
        end
    end
)

addEventHandler("onClientVehicleExit", getRootElement(),
    function(thePlayer, seat)
        if seat == 0 then
            removeEventHandler("onClientRender", root, control)
        end
    end
)

local showComponents = false
bindKey("F5", "down", function() showComponents = not showComponents end)

addEventHandler("onClientRender", root, function()
    if not showComponents then return end

    for _, veh in pairs(getElementsByType("vehicle", root, true)) do
        for compname in pairs(getVehicleComponents(veh)) do
            local x, y = getScreenFromWorldPosition(getVehicleComponentPosition(veh, compname, "world"))

            if x then
                dxDrawText(compname, x, y, 0, 0)
            end
        end 
    end
end)



addEvent("pedVehicleFire",true)
addEventHandler("pedVehicleFire",localPlayer,function(ped,state)
    if isElement(ped) then
        if isElementStreamedIn(ped) then
            setPedControlState(ped,"vehicle_fire", state=="down")
        end
    end
    
end)