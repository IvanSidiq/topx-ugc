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
local DataStoreService = game:GetService("DataStoreService")

local Types = require(ReplicatedStorage.Utility.Types)
local RestrictedItems = require(ReplicatedStorage.Libraries.RestrictedItems)
local validateSimpleTable = require(ServerScriptService.Utility.TypeValidation.validateSimpleTable)
local validateNumber = require(ServerScriptService.Utility.TypeValidation.validateNumber)
local validateEnum = require(ServerScriptService.Utility.TypeValidation.validateEnum)
local validateBulkItem = require(script.validateBulkItem)

local TestMode = require(ServerScriptService.Utility.TestMode)
local TestStore = require(ServerScriptService.Utility.TestStore)

local remotes = ReplicatedStorage.Remotes
local bulkPurchaseRemote = remotes.BulkPurchase
local purchaseRemote = remotes.Purchase

local RobuxLeaderboard = DataStoreService:GetOrderedDataStore("RobuxSpentLeaderboard")

local function simulateGrant(player: Player, robuxSpent: number)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then return end

	local points = stats:FindFirstChild("Points")
	if points then
		points.Value += math.floor(robuxSpent / 1)
	end

	local spent = stats:FindFirstChild("RobuxSpent")
	if spent then
		spent.Value += robuxSpent
		if TestMode then
			TestStore.addSpend(player.UserId, spent.Value)
		else
			pcall(function()
				RobuxLeaderboard:SetAsync(player.UserId, spent.Value)
			end)
		end
	end

	local purchases = stats:FindFirstChild("Purchases")
	if purchases then
		purchases.Value += 1
	end
end

local function onPurchaseEvent(player: Player, itemId: number, itemType: Enum.MarketplaceProductType)
	if not validateNumber(itemId) then
		return
	end

	if not validateEnum(itemType, Enum.MarketplaceProductType) then
		return
	end

	if RestrictedItems.isRestricted(itemId, itemType) then
		return
	end

	if TestMode then
		local robuxSpent = 50
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(itemId)
		end)
		if ok and info and info.PriceInRobux then
			robuxSpent = info.PriceInRobux
		end
		simulateGrant(player, robuxSpent)
		return
	end

	if itemType == Enum.MarketplaceProductType.AvatarBundle then
		MarketplaceService:PromptBundlePurchase(player, itemId)
	else
		MarketplaceService:PromptPurchase(player, itemId)
	end

	-- On live prompt, we increment purchases in the finished signal in UGCPurchaseHandler.
end

local function onBulkPurchaseEvent(player: Player, bulkPurchaseItems: { Types.BulkItem })
	if not validateSimpleTable(bulkPurchaseItems, "number", validateBulkItem) then
		return
	end

	for _, item in bulkPurchaseItems do
		if RestrictedItems.isRestricted(tonumber(item.Id) :: number, item.Type) then
			return
		end
	end

	if TestMode then
		local total = 0
		for _, item in bulkPurchaseItems do
			local idNum = tonumber(item.Id) or 0
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(idNum)
			end)
			if ok and info and info.PriceInRobux then
				total += info.PriceInRobux
			else
				total += 50
			end
		end
		simulateGrant(player, total)
		return
	end

	local options = {}
	MarketplaceService:PromptBulkPurchase(player, bulkPurchaseItems, options)
end

purchaseRemote.OnServerEvent:Connect(onPurchaseEvent)
bulkPurchaseRemote.OnServerEvent:Connect(onBulkPurchaseEvent) 