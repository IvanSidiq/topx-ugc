--!strict

--[[
	validateBulkItem - A utility function for validating that entries being passed to
	MarketplaceService:PromptBulkPurchase() are correctly formatted.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Types = require(ReplicatedStorage.Utility.Types)
local validateString = require(ServerScriptService.Utility.TypeValidation.validateString)
local validateEnum = require(ServerScriptService.Utility.TypeValidation.validateEnum)

local function validateBulkItem(item: Types.BulkItem): boolean
	if typeof(item) ~= "table" then
		return false
	end

	if not validateString(item.Id) then
		return false
	end

	if not tonumber(item.Id) then
		return false
	end

	if not validateEnum(item.Type, Enum.MarketplaceProductType) then
		return false
	end

	return true
end

return validateBulkItem
