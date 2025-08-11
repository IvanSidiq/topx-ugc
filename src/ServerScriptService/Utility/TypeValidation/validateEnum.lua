--!strict

--[[
	validateEnum - Ensures that the passed argument is the specified enum type
--]]

local function validateEnum(enum: EnumItem, enumType: Enum): boolean
	-- Make sure this is actually an enum
	if typeof(enum) ~= "EnumItem" then
		return false
	end

	return enum.EnumType == enumType
end

return validateEnum
