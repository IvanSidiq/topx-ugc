--!strict

--[[
	Checkout - This script handles the main checkout functionality. The client fires a RemoteEvent 
	to let the server know when they want to make a purchase.

	We do some simple validation on the parameters passed from the client to ensure we are sending a
	proper prompt request.
--]]

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")

local Types = require(ReplicatedStorage.Utility.Types)
local RestrictedItems = require(ReplicatedStorage.Libraries.RestrictedItems)
local validateNumber = require(ServerScriptService.Utility.TypeValidation.validateNumber)
local validateEnum = require(ServerScriptService.Utility.TypeValidation.validateEnum)

local TestMode = require(ServerScriptService.Utility.TestMode)
local TestStore = require(ServerScriptService.Utility.TestStore)

local remotes = ReplicatedStorage.Remotes
local purchaseRemote = remotes.Purchase

-- Create RemoteEvent for purchase notifications
local purchaseNotificationEvent = ReplicatedStorage:FindFirstChild("UGC_PurchaseNotification")
if not purchaseNotificationEvent then
	purchaseNotificationEvent = Instance.new("RemoteEvent")
	purchaseNotificationEvent.Name = "UGC_PurchaseNotification"
	purchaseNotificationEvent.Parent = ReplicatedStorage
	print("[CHECKOUT] Created UGC_PurchaseNotification RemoteEvent")
else
	print("[CHECKOUT] Found existing UGC_PurchaseNotification RemoteEvent")
end

local RobuxLeaderboard = DataStoreService:GetOrderedDataStore("RobuxSpentLeaderboard")

-- SECURITY: Removed simulateGrant function - points should only be awarded 
-- through legitimate MarketplaceService purchase events, never simulated

-- SECURITY: Import shared purchase tracking module
local PurchaseTracking = require(ServerScriptService.PurchaseTracking)

-- SECURITY: Rate limiting for purchase requests (Balanced for UX)
local lastPurchaseRequest = {}
local PURCHASE_REQUEST_COOLDOWN = 0.5 -- 500ms between purchase requests (allows faster browsing)

local function onPurchaseEvent(player: Player, itemId: number, itemType: any)
	-- SECURITY: Rate limit purchase requests
	local userId = player.UserId
	if lastPurchaseRequest[userId] and (os.clock() - lastPurchaseRequest[userId]) < PURCHASE_REQUEST_COOLDOWN then
		warn(string.format("[SECURITY] %s is spamming purchase requests", player.Name))
		return
	end
	lastPurchaseRequest[userId] = os.clock()
	
	if not validateNumber(itemId) then
		warn(string.format("[SECURITY] Invalid itemId from %s: %s", player.Name, tostring(itemId)))
		return
	end
	
	-- SECURITY: Validate itemId is within reasonable range
	if itemId <= 0 or itemId > 999999999999999 then
		warn(string.format("[SECURITY] Suspicious itemId from %s: %d", player.Name, itemId))
		return
	end

	-- SECURITY: Validate itemType - accept both enum values and strings
	-- Convert enum to string for easier handling
	local itemTypeStr = ""
	if typeof(itemType) == "EnumItem" then
		-- Handle Enum.MarketplaceProductType values
		if itemType == Enum.MarketplaceProductType.AvatarAsset then
			itemTypeStr = "Asset"
		elseif itemType == Enum.MarketplaceProductType.Product then
			itemTypeStr = "Product"
		else
			warn(string.format("[SECURITY] Unknown enum itemType from %s: %s", player.Name, tostring(itemType)))
			return
		end
	elseif typeof(itemType) == "string" then
		-- Handle string values (GamePass, Bundle, etc.)
		local validTypes = {"Asset", "Bundle", "GamePass", "Product"}
		if table.find(validTypes, itemType) then
			itemTypeStr = itemType
		else
			warn(string.format("[SECURITY] Invalid string itemType from %s: %s", player.Name, tostring(itemType)))
			return
		end
	else
		warn(string.format("[SECURITY] Invalid itemType type from %s: %s (%s)", player.Name, tostring(itemType), typeof(itemType)))
		return
	end

	if RestrictedItems.isRestricted(itemId, itemType) then
		warn(string.format("[SECURITY] %s attempted to purchase restricted item: %d", player.Name, itemId))
		-- Notify the player this item is restricted
		purchaseNotificationEvent:FireClient(player, "purchase_blocked", "This item is not available for purchase.")
		return
	end

	if TestMode then
		-- SECURITY: TestMode should only prompt purchases, never grant points directly
		-- Points should only be awarded through legitimate MarketplaceService events
		print(string.format("[TEST-MODE] Would purchase item %d for player %s (no points awarded)", itemId, player.Name))
		return
	end

	-- SECURITY: Check if player already owns the item BEFORE prompting purchase
	local ownershipType = ""
	if itemTypeStr == "Bundle" then
		ownershipType = "bundle"
	elseif itemTypeStr == "GamePass" then
		ownershipType = "gamepass"
	else
		ownershipType = "asset"
	end
	
	local alreadyOwns = PurchaseTracking.verifyOwnership(player, itemId, ownershipType)
	if alreadyOwns then
		warn(string.format("[PURCHASE-BLOCKED] Player %s already owns %s %d - purchase cancelled", 
			player.Name, itemTypeStr, itemId))
		-- Notify the player they already own this item
		print(string.format("[NOTIFICATION-SEND] Sending 'already_owned' notification to %s", player.Name))
		purchaseNotificationEvent:FireClient(player, "already_owned", "You already own this item!")
		print("[NOTIFICATION-SEND] Notification sent")
		return
	end
	
	print(string.format("[PURCHASE-CHECK] Player %s does not own %s %d - proceeding with purchase", 
		player.Name, itemTypeStr, itemId))

	-- SECURITY: Register this purchase as expected before prompting
	if itemTypeStr == "Bundle" then
		print(string.format("[PURCHASE-REGISTER] Registering bundle purchase for %s, bundleId=%d", player.Name, itemId))
		PurchaseTracking.registerBundlePurchase(player, itemId)
		print(string.format("[PURCHASE-PROMPT] Calling PromptBundlePurchase for %s, bundleId=%d", player.Name, itemId))
		MarketplaceService:PromptBundlePurchase(player, itemId)
	elseif itemTypeStr == "GamePass" then
		print(string.format("[PURCHASE-REGISTER] Registering gamepass purchase for %s, gamePassId=%d", player.Name, itemId))
		PurchaseTracking.registerGamePassPurchase(player, itemId)
		print(string.format("[PURCHASE-PROMPT] Calling PromptGamePassPurchase for %s, gamePassId=%d", player.Name, itemId))
		MarketplaceService:PromptGamePassPurchase(player, itemId)
	else
		-- Regular asset purchase (includes AvatarAsset and Product)
		print(string.format("[PURCHASE-REGISTER] Registering asset purchase for %s, assetId=%d", player.Name, itemId))
		PurchaseTracking.registerAssetPurchase(player, itemId, "purchase")
		print(string.format("[PURCHASE-PROMPT] Calling PromptPurchase for %s, assetId=%d", player.Name, itemId))
		MarketplaceService:PromptPurchase(player, itemId)
	end

	-- On live prompt, we increment purchases in the finished signal in UGCPurchaseHandler.
end

-- Cleanup purchase request rate limiting on player leave
game.Players.PlayerRemoving:Connect(function(player)
	lastPurchaseRequest[player.UserId] = nil
	-- Note: PurchaseTracking.cleanupPlayer is called in UGCPurchaseHandler
end)

purchaseRemote.OnServerEvent:Connect(onPurchaseEvent) 