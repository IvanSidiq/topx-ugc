--!strict
--[[
	PurchaseTracking Module
	
	Shared module for tracking server-initiated purchases to prevent exploit spoofing.
	This protects against exploiters using Signal* functions to fake purchases.
	
	Security: Only purchases that the SERVER prompted will be in these tables.
	Purchase handlers must validate against these tables before granting points.
]]

local MarketplaceService = game:GetService("MarketplaceService")

local PurchaseTracking = {}

-- Helper function to verify actual ownership (Layer 2 security)
function PurchaseTracking.verifyOwnership(player: Player, itemId: number, itemType: string): boolean
	local success, owns = pcall(function()
		if itemType == "asset" then
			return MarketplaceService:PlayerOwnsAsset(player, itemId)
		elseif itemType == "gamepass" then
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, itemId)
		elseif itemType == "bundle" then
			-- For bundles, we can't directly check ownership
			-- But we can check if the player owns bundle items
			local bundleInfo = MarketplaceService:GetProductInfo(itemId, Enum.InfoType.Bundle)
			if bundleInfo and bundleInfo.Items then
				-- Check if player owns at least one item from the bundle
				for _, item in ipairs(bundleInfo.Items) do
					if item.Type == "Asset" then
						local ownsItem = MarketplaceService:PlayerOwnsAsset(player, item.Id)
						if ownsItem then
							return true
						end
					end
				end
			end
			-- If we can't verify bundle ownership, we'll rely on Layer 1 only
			return true
		end
		return false
	end)
	
	if not success then
		warn(string.format("[OWNERSHIP-CHECK] Failed to verify ownership for player %s, item %d, type %s", 
			player.Name, itemId, itemType))
		return false
	end
	
	return owns
end

-- Track expected purchases by type
PurchaseTracking.expectedPurchases = {} -- [player][assetId] = {timestamp = number, purchaseType = string}
PurchaseTracking.expectedBundlePurchases = {} -- [player][bundleId] = {timestamp = number}
PurchaseTracking.expectedGamePassPurchases = {} -- [player][gamePassId] = {timestamp = number}

-- Register an expected asset purchase
function PurchaseTracking.registerAssetPurchase(player: Player, assetId: number, purchaseType: string?)
	print(string.format("[PurchaseTracking] Registering asset purchase: player=%s (UserId=%d), assetId=%d, purchaseType=%s", player.Name, player.UserId, assetId, tostring(purchaseType or "asset")))

	PurchaseTracking.expectedPurchases[player] = PurchaseTracking.expectedPurchases[player] or {}
	PurchaseTracking.expectedPurchases[player][assetId] = {
		timestamp = os.clock(),
		purchaseType = purchaseType or "asset"
	}

	print(string.format("[PurchaseTracking] expectedPurchases for %s after register: %s", player.Name, PurchaseTracking.expectedPurchases[player] and tostring(PurchaseTracking.expectedPurchases[player][assetId]) or "nil"))
	
	-- Auto-cleanup after 2 minutes
	task.delay(120, function()
		if PurchaseTracking.expectedPurchases[player] and PurchaseTracking.expectedPurchases[player][assetId] then
			print(string.format("[PurchaseTracking] Auto-cleaning expected purchase: player=%s, assetId=%d", player.Name, assetId))
			PurchaseTracking.expectedPurchases[player][assetId] = nil
		end
	end)
end

-- Register an expected bundle purchase
function PurchaseTracking.registerBundlePurchase(player: Player, bundleId: number)
	PurchaseTracking.expectedBundlePurchases[player] = PurchaseTracking.expectedBundlePurchases[player] or {}
	PurchaseTracking.expectedBundlePurchases[player][bundleId] = {
		timestamp = os.clock()
	}
	
	-- Auto-cleanup after 2 minutes
	task.delay(120, function()
		if PurchaseTracking.expectedBundlePurchases[player] and PurchaseTracking.expectedBundlePurchases[player][bundleId] then
			PurchaseTracking.expectedBundlePurchases[player][bundleId] = nil
		end
	end)
end

-- Register an expected gamepass purchase
function PurchaseTracking.registerGamePassPurchase(player: Player, gamePassId: number)
	PurchaseTracking.expectedGamePassPurchases[player] = PurchaseTracking.expectedGamePassPurchases[player] or {}
	PurchaseTracking.expectedGamePassPurchases[player][gamePassId] = {
		timestamp = os.clock()
	}
	
	-- Auto-cleanup after 2 minutes
	task.delay(120, function()
		if PurchaseTracking.expectedGamePassPurchases[player] and PurchaseTracking.expectedGamePassPurchases[player][gamePassId] then
			PurchaseTracking.expectedGamePassPurchases[player][gamePassId] = nil
		end
	end)
end

-- Clean up all tracking for a player (call on PlayerRemoving)
function PurchaseTracking.cleanupPlayer(player: Player)
	PurchaseTracking.expectedPurchases[player] = nil
	PurchaseTracking.expectedBundlePurchases[player] = nil
	PurchaseTracking.expectedGamePassPurchases[player] = nil
end

return PurchaseTracking


