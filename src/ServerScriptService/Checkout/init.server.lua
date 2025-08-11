--!strict

--[[
	Checkout - This script handles the main checkout functionality. Since bulk purchases are only able
	to be prompted on the server, the client fires a RemoteEvent to let the server know when they want
	to make a purchase.

	We do some simple validation on the parameters passed from the client to ensure we are sending a
	proper prompt request.
--]]

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Types = require(ReplicatedStorage.Utility.Types)
local RestrictedItems = require(ReplicatedStorage.Libraries.RestrictedItems)
local validateSimpleTable = require(ServerScriptService.Utility.TypeValidation.validateSimpleTable)
local validateNumber = require(ServerScriptService.Utility.TypeValidation.validateNumber)
local validateEnum = require(ServerScriptService.Utility.TypeValidation.validateEnum)
local validateBulkItem = require(script.validateBulkItem)

local remotes = ReplicatedStorage.Remotes
local bulkPurchaseRemote = remotes.BulkPurchase
local purchaseRemote = remotes.Purchase

local function onPurchaseEvent(player: Player, itemId: number, itemType: Enum.MarketplaceProductType)
	if not validateNumber(itemId) then
		return
	end

	if not validateEnum(itemType, Enum.MarketplaceProductType) then
		return
	end

	-- Make sure this item is not in the restricted items list. This list should be used to
	-- disable purchasing items using these remotes, e.g. in the case of giving out free
	-- UGC through a separate game mechanic.
	if RestrictedItems.isRestricted(itemId, itemType) then
		return
	end

	if itemType == Enum.MarketplaceProductType.AvatarBundle then
		MarketplaceService:PromptBundlePurchase(player, itemId)
	else
		MarketplaceService:PromptPurchase(player, itemId)
	end
end

local function onBulkPurchaseEvent(player: Player, bulkPurchaseItems: { Types.BulkItem })
	if not validateSimpleTable(bulkPurchaseItems, "number", validateBulkItem) then
		return
	end

	-- Make sure no items are in the restricted items list. This list should be used to
	-- disable purchasing items using these remotes, e.g. in the case of giving out free
	-- UGC through a separate game mechanic.
	for _, item in bulkPurchaseItems do
		if RestrictedItems.isRestricted(tonumber(item.Id) :: number, item.Type) then
			return
		end
	end

	local options = {}
	MarketplaceService:PromptBulkPurchase(player, bulkPurchaseItems, options)
end

purchaseRemote.OnServerEvent:Connect(onPurchaseEvent)
bulkPurchaseRemote.OnServerEvent:Connect(onBulkPurchaseEvent) 