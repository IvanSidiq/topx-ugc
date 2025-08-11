--!strict

--[[
	validateSimpleTable - A utility function to validate that a table has the correct key types and values.
--]]

local function validateSimpleTable(tbl: { [any]: any }, keyType: string, validator: (any) -> boolean): boolean
	-- Make sure this is actually a table
	if typeof(tbl) ~= "table" then
		return false
	end

	-- Validate all keys and values
	for key, value in tbl do
		if typeof(key) ~= keyType then
			return false
		end

		if not validator(value) then
			return false
		end
	end

	return true
end

return validateSimpleTable
