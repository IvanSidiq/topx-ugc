--!strict

--[[
	validateString - Ensures that the passed argument is actually a string
--]]

local function validateString(str: string): boolean
	-- Make sure this is actually a string
	return typeof(str) == "string"
end

return validateString
