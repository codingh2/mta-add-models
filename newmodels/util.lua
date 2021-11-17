--[[
	Author: Fernando

	shared.lua

	/!\ UNLESS YOU KNOW WHAT YOU ARE DOING, NO NEED TO CHANGE THIS FILE /!\
]]

dataNames = {
	ped = "skinID",
	player = "skinID",
	object = "objectID",
	-- vehicle = "vehicleID", -- not yet implemented
}

function getDataTypeFromName(dataName)
	for elementType, name in pairs(dataNames) do
		if dataName == name then
			return elementType
		end
	end
end

function getDataNameFromType(elementType) -- [Exported]
	if not elementType then return end
	return dataNames[elementType]
end

normalSkins = {1, 2, 7, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 32, 33, 34, 35, 36, 37, 43, 44, 45, 46, 47, 48, 49, 50, 51, 52, 57, 58, 59, 60, 61, 62, 66, 67, 68, 70, 71, 72, 73, 78, 79, 80, 81, 82, 83, 84, 94, 95, 96, 97, 98, 99, 100, 101, 102, 103, 104, 105, 106, 107, 108, 109, 110, 111, 112, 113, 114, 115, 116, 117, 118, 120, 121, 122, 123, 124, 125, 126, 127, 128, 132, 133, 134, 135, 136, 137, 142, 143, 144, 146, 147, 153, 154, 155, 156, 158, 159, 160, 161, 162, 163, 164, 165, 166, 167, 168, 170, 171, 173, 174, 175, 176, 177, 179, 180, 181, 182, 183, 184, 185, 186, 187, 188, 189, 200, 202, 203, 204, 206, 209, 210, 212, 213, 217, 220, 221, 222, 223, 227, 228, 229, 230, 234, 235, 236, 239, 240, 241, 242, 247, 248, 249, 250, 252, 253, 254, 255, 258, 259, 260, 261, 262, 264, 265, 266, 267, 268, 269, 270, 271, 272, 274, 275, 276, 277, 278, 279, 280, 281, 282, 283, 284, 285, 286, 287, 288, 290, 291, 292, 293, 294, 295, 296, 297, 299, 300, 301, 302, 303, 305, 306, 307, 308, 309, 310, 311, 312, 9, 10, 11, 12, 13, 31, 38, 39, 40, 41, 53, 54, 55, 56, 63, 64, 69, 75, 76, 77, 85, 87, 88, 89, 90, 91, 92, 93, 129, 130, 131, 138, 139, 140, 141, 145, 148, 150, 151, 152, 157, 169, 172, 178, 190, 191, 192, 193, 194, 195, 196, 197, 198, 199, 201, 205, 207, 211, 214, 215, 216, 218, 219, 224, 225, 226, 231, 232, 233, 237, 238, 243, 244, 245, 246, 251, 256, 257, 263, 298, 304}

function isDefaultID(elementType, id) -- [Exported]
	id = tonumber(id)
	if not id then return end

	if elementType == "ped" or elementType == "player" then
		for k,id2 in pairs(normalSkins) do
			if id2 == id then
				return true
			end
		end
	
	elseif elementType == "object" then
		return ((id >= 321 and id <= 18630) and (id <= 11681 or id >= 12800))
    	-- 			   min 			  max 	   exclude 11682    to    12799 SAMP ID Range
	end
	return false
end

function getActualModPaths(elementType, folder, id)
	local path = folder

	local lastchar = string.sub(folder, -1)
	if lastchar ~= "/" then
		path = folder.."/" -- / is missing but I'm nice
	end

	path = path..id

	local paths = {
		txd = path..".txd",
		dff = path..".dff",
		col = path..".col",
	}
	return paths
end

function isCustomModID(elementType, id) -- [Exported]

	local name = getModNameFromID(elementType, id)
	if not name then
		return false
	end
	return true
end


function isElementTypeSupported(et)
	local found
	for type,_ in pairs(dataNames) do
		if et == type then
			found = true
			break
		end
	end

	if not found then
		return false, "added "..et.." mods are not yet supported"
	end
	return true
end

function verifySetModelArguments(element, elementType, id)
	if not isElement(element) then
		return false, "Invalid element passed"
	end

	local et = getElementType(element)

	local sup,reason = isElementTypeSupported(et)
	if not sup then
		return false, reason
	end

	local dataName = dataNames[et]
	if not dataName then
		return false, et.." mods yet supported"
	end

	if not tonumber(id) then
		return false, "Non-number ID passed"
	end
	id = tonumber(id)

	return true
end

function table.size ( tab )
    local length = 0
    
    for _ in pairs ( tab ) do
        length = length + 1
    end
    
    return length
end