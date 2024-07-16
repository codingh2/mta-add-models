local function loadModels()
    if not pathIsDirectory("models") then
        return false, "models directory not found"
    end
    local filesAndFolders = pathListDir("models")
    if not filesAndFolders then
        return false, "failed to list models directory"
    end
    for _, modelType in pairs({"vehicle", "object", "ped"}) do
        local modelTypePath = "models/" .. modelType
        -- Directory is optional, user might not have any custom models for this type
        if pathIsDirectory(modelTypePath) then
            local filesAndFoldersHere = pathListDir(modelTypePath)
            if not filesAndFoldersHere then
                return false, "failed to list " .. modelTypePath .. " directory"
            end
            for _, fileOrFolder in pairs(filesAndFoldersHere) do
                local fullPath = modelTypePath .. "/" .. fileOrFolder
                if pathIsDirectory(fullPath) then
                    local baseModel = tonumber(fileOrFolder)
                    if baseModel then
                        if not isDefaultID(modelType, baseModel) then
                            return false, "invalid " .. modelType .. " base model: " .. baseModel
                        end
                        local filesAndFoldersInside = pathListDir(fullPath)
                        if not filesAndFoldersInside then
                            return false, "failed to list " .. fullPath .. " directory"
                        end
                        local filesForCustomModel = {}
                        for _, fileInside in pairs(filesAndFoldersInside) do
                            local fullPathInside = fullPath .. "/" .. fileInside
                            local customModel = false
                            if pathIsFile(fullPathInside) then
                                local fileType = string.sub(fileInside, -3)
                                if not (fileType == "dff" or fileType == "txd" or fileType == "col") then
                                    return false, "invalid " .. modelType .. " file type: " .. fileType
                                end
                                customModel = tonumber(string.sub(fileInside, 1, -5))
                                if not filesForCustomModel[customModel] then
                                    filesForCustomModel[customModel] = {}
                                end
                                filesForCustomModel[customModel][fileType] = fullPathInside
                            else
                                customModel = tonumber(fileInside)
                                if not filesForCustomModel[customModel] then
                                    filesForCustomModel[customModel] = {}
                                end
                                local data = getData(modelType)
                                if not data then
                                    return false, "no data found for " .. modelType
                                end
                                
                                if data[baseModel].dff then filesForCustomModel[customModel]["dff"] = string.format("%s/%s.%s",fullPathInside,data[baseModel].dff,"dff") end
                                if data[baseModel].txd then filesForCustomModel[customModel]["txd"] = string.format("%s/%s.%s",fullPathInside,data[baseModel].txd,"txd") end
                                if data[baseModel].col then filesForCustomModel[customModel]["col"] = string.format("%s/%s.%s",fullPathInside,data[baseModel].col,"col") end
                                
                            end
                            if not customModel then
                                return false, "invalid " .. modelType .. " custom model: " .. fileInside
                            end
                            if isDefaultID(modelType, customModel) then
                                return false, "custom " .. modelType .. " model is a default ID: " .. customModel
                            end
                            if customModels[customModel] then
                                return false, "duplicate " .. modelType .. " custom model: " .. customModel
                            end
                            
                        end
                        for customModel, files in pairs(filesForCustomModel) do
                            
                            customModels[customModel] = {
                                type = modelType,
                                baseModel = baseModel,
                                dff = fileExists(files.dff) and files.dff or nil,
                                txd = fileExists(files.txd) and files.txd or nil,
                                col = files.col 
                            }
                        end
                    end
                end
            end
        end
    end
    return true
end


local result, failReason = loadModels()
if not result then
    outputServerLog("[loadModels] " .. failReason)
    outputDebugString("Failed to load models. See server log for details.", 1)
    return
end

addEventHandler("onPlayerResourceStart", root, function(res)
    if res == resource then
        triggerClientEvent(source, "newmodels_reborn:receiveCustomModels", resourceRoot, customModels)
    end
    
    bindKey(source,"vehicle_fire","both",function(player,key,state)
        local theVeh = getPedOccupiedVehicle(player)
        if theVeh then
            local gData = getElementData(theVeh,"gData")
            if (gData and getVehicleController(theVeh) == player) then
                local x,y,z = getElementPosition(player)
                local others = getElementsWithinRange(x,y,z,200,"player")
                
                for _,p in pairs(others) do
                    triggerClientEvent(p,"pedVehicleFire",player,gData.ghostPed, state)
                end
                
                
            end
        end
    end)
end)

addEventHandler("onElementDestroy", getRootElement(), function ()
    if getElementType(source) == "vehicle" then
        local gData = getElementData(theVeh,"gData")
        if gData then destroyElement(gData.ghost) destroyElement(gData.ghostPed) end
    end
  end)


