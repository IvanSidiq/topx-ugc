local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestMode = require(script.Parent.Utility.TestMode)
local TestStore = require(script.Parent.Utility.TestStore)
local PurchaseTracking = require(script.Parent.PurchaseTracking)

local PointsDataStore = DataStoreService:GetDataStore("UGCPlayerPoints")
local RobuxLeaderboard = DataStoreService:GetOrderedDataStore("RobuxSpentLeaderboard")
local PurchasesCountStore = DataStoreService:GetDataStore("UGCPurchasesCount")

-- Prefer client-reported regional prices via RemoteEvent
local reportEvent = ReplicatedStorage:FindFirstChild("UGC_ReportPurchasePrice")
if not reportEvent then
	reportEvent = Instance.new("RemoteEvent")
	reportEvent.Name = "UGC_ReportPurchasePrice"
	reportEvent.Parent = ReplicatedStorage
end

-- Create RemoteEvent for claim functionality
local claimEvent = ReplicatedStorage:FindFirstChild("UGC_ClaimItem")
if not claimEvent then
	claimEvent = Instance.new("RemoteEvent")
	claimEvent.Name = "UGC_ClaimItem"
	claimEvent.Parent = ReplicatedStorage
end

-- Create RemoteEvent for claim responses
local claimResponseEvent = ReplicatedStorage:FindFirstChild("UGC_ClaimResponse")
if not claimResponseEvent then
	claimResponseEvent = Instance.new("RemoteEvent")
	claimResponseEvent.Name = "UGC_ClaimResponse"
	claimResponseEvent.Parent = ReplicatedStorage
end

local recentClientPricesByPlayer = {}

-- Track players currently claiming items to prevent exploits
local playersCurrentlyClaiming = {}
local claimAttempts = {} -- Track claim attempts per player for rate limiting
local lastClaimTime = {} -- Track last claim time per player

-- Helper function to safely get leaderstats without infinite yield
local function getLeaderstats(player, timeoutSeconds)
	timeoutSeconds = timeoutSeconds or 5
	local maxRetries = timeoutSeconds * 10 -- 10 checks per second
	local retryCount = 0
	
	local stats = player:FindFirstChild("leaderstats")
	while not stats and retryCount < maxRetries do
		task.wait(0.1)
		stats = player:FindFirstChild("leaderstats")
		retryCount += 1
	end
	
	return stats
end

-- Configuration for free item claims
local FREE_ASSET_IDS = {
	85890247763956, -- Original reward asset
	75903645746351, -- Additional reward asset
}
local CLAIM_COST = 500 -- Points required to claim

-- Helper function to check if asset ID is a valid free reward
local function isValidFreeAsset(assetId)
	for _, validId in ipairs(FREE_ASSET_IDS) do
		if assetId == validId then
			return true
		end
	end
	return false
end

-- Bundle price mapping for third-party bundles that we can't get price info for
local KNOWN_BUNDLE_PRICES = {
	[6470] = 175, -- Chibi-Doll-Girl Bundle - 175 robux
	[7635] = 175, -- Chibi Doll Girl (V2) - 175 robux
	[1590409] = 58,
	[83] = 62,
	-- Add more bundle IDs and their prices here as needed
}

-- Security Configuration (Balanced for UX + Security)
local MAX_POINTS = 9999 -- Maximum allowed points per player
local MAX_SINGLE_PURCHASE_POINTS = 2000 -- Maximum points from a single purchase
local PURCHASE_COOLDOWN = 0 -- DISABLED - Removed to allow rapid legitimate purchases
local CLAIM_COOLDOWN = 3 -- Seconds between claim attempts (reduced for better UX)
local SUSPICIOUS_POINTS_THRESHOLD = 5000 -- Alert threshold for rapid point gains
local MAX_CLAIMS_PER_HOUR = 20 -- Maximum claim attempts per hour (increased for better UX)

-- Anti-exploit tracking
local lastPurchaseTime = {} -- Track last purchase time per player
local recentPointGains = {} -- Track recent point gains for anomaly detection
-- Removed suspiciousPlayers - too aggressive for legitimate users

-- Security Functions
local function logSuspiciousActivity(player, reason, details)
	local message = string.format("[SECURITY ALERT] Player %s (%d): %s - %s", 
		player.Name, player.UserId, reason, details or "")
	warn(message)
	
	-- Don't mark players as suspicious for legitimate activity
	-- Only log for monitoring purposes
end

local function validatePointsAmount(currentPoints, newPoints, source)
	-- Check for impossibly high values
	if newPoints > MAX_POINTS then
		return false, "Points exceed maximum allowed"
	end
	
	-- Check for impossible negative values
	if newPoints < 0 then
		return false, "Negative points detected"
	end
	
	-- Check for suspiciously large gains
	local pointGain = newPoints - currentPoints
	if pointGain > MAX_SINGLE_PURCHASE_POINTS then
		return false, string.format("Single gain of %d points exceeds limit (%d)", pointGain, MAX_SINGLE_PURCHASE_POINTS)
	end
	
	return true, nil
end

local function isPlayerOnCooldown(player)
	local lastTime = lastPurchaseTime[player.UserId]
	if lastTime and (os.clock() - lastTime) < PURCHASE_COOLDOWN then
		return true
	end
	return false
end

local function trackPointGain(player, pointsGained)
	-- Simplified tracking - just for monitoring, no blocking
	print(string.format("[POINTS-TRACK] %s gained %d points", player.Name, pointsGained))
end

-- Rate limiting function for claims
local function canPlayerClaim(player)
	local userId = player.UserId
	local currentTime = os.clock()
	
	-- Check claim cooldown
	if lastClaimTime[userId] and (currentTime - lastClaimTime[userId]) < CLAIM_COOLDOWN then
		return false, string.format("Please wait %.0f seconds before claiming again", CLAIM_COOLDOWN - (currentTime - lastClaimTime[userId]))
	end
	
	-- Initialize or reset hourly tracking
	if not claimAttempts[userId] then
		claimAttempts[userId] = {count = 0, resetTime = currentTime + 3600}
	elseif currentTime > claimAttempts[userId].resetTime then
		claimAttempts[userId] = {count = 0, resetTime = currentTime + 3600}
	end
	
	-- Check hourly limit
	if claimAttempts[userId].count >= MAX_CLAIMS_PER_HOUR then
		return false, "Too many claim attempts. Please try again later."
	end
	
	return true, nil
end

-- Handle claim requests from clients
claimEvent.OnServerEvent:Connect(function(player, assetId)
	local success, err = pcall(function()
		-- SECURITY: Rate limiting check
		local canClaim, limitError = canPlayerClaim(player)
		if not canClaim then
			claimResponseEvent:FireClient(player, false, limitError)
			logSuspiciousActivity(player, "Claim rate limit exceeded", limitError)
			return
		end
		
		-- Increment claim attempts
		claimAttempts[player.UserId].count += 1
		lastClaimTime[player.UserId] = os.clock()
		
		-- Validate input
		if typeof(assetId) ~= "number" then
			claimResponseEvent:FireClient(player, false, "Invalid asset ID")
			logSuspiciousActivity(player, "Invalid claim asset ID", string.format("Asset: %s", tostring(assetId)))
			return
		end
		
		-- SECURITY: Validate asset ID is within reasonable range
		if assetId <= 0 or assetId > 999999999999999 then
			claimResponseEvent:FireClient(player, false, "Invalid asset ID")
			logSuspiciousActivity(player, "Suspicious claim asset ID", string.format("Asset: %d", assetId))
			return
		end
		
		-- Check if player is already claiming
		if playersCurrentlyClaiming[player] then
			claimResponseEvent:FireClient(player, false, "Already claiming an item")
			return
		end
		
		-- Validate it's a valid free asset
		if not isValidFreeAsset(assetId) then
			claimResponseEvent:FireClient(player, false, "Invalid item for claiming")
			return
		end
		
		-- Check player's points
		local stats = player:FindFirstChild("leaderstats")
		if not stats then
			claimResponseEvent:FireClient(player, false, "Stats not found")
			return
		end
		
		local points = stats:FindFirstChild("Points")
		if not points then
			claimResponseEvent:FireClient(player, false, "Points not found")
			return
		end
		
		if points.Value < CLAIM_COST then
			claimResponseEvent:FireClient(player, false, "Not enough points!")
			return
		end
		
		-- Get asset info to validate it's free and available
		local assetInfo
		local infoSuccess, infoResult = pcall(function()
			return MarketplaceService:GetProductInfo(assetId, Enum.InfoType.Asset)
		end)
		
		if not infoSuccess then
			claimResponseEvent:FireClient(player, false, "Unable to fetch item info")
			return
		end
		
		assetInfo = infoResult
		if not assetInfo.IsForSale or (assetInfo.PriceInRobux or 0) ~= 0 then
			claimResponseEvent:FireClient(player, false, "Item not free/on sale")
			return
		end
		
		-- Mark player as claiming and prompt purchase
		playersCurrentlyClaiming[player] = {
			assetId = assetId,
			startTime = os.clock()
		}
		
		-- SECURITY: Track this as an expected purchase using module
		PurchaseTracking.registerAssetPurchase(player, assetId, "claim")
		
		-- Prompt the purchase
		MarketplaceService:PromptPurchase(player, assetId)
		claimResponseEvent:FireClient(player, true, "Purchase prompted")
	end)
	
	if not success then
		warn("Claim request error for player " .. player.Name .. ":", err)
		playersCurrentlyClaiming[player] = nil
		claimResponseEvent:FireClient(player, false, "Server error occurred")
	end
end)

-- SECURITY: Use shared purchase tracking to prevent exploit spoofing
-- Reference the tables from PurchaseTracking module
local expectedPurchases = PurchaseTracking.expectedPurchases
local expectedBundlePurchases = PurchaseTracking.expectedBundlePurchases
local expectedGamePassPurchases = PurchaseTracking.expectedGamePassPurchases

reportEvent.OnServerEvent:Connect(function(player, assetId, clientPrice, infoTypeName)
	print(string.format("[PRICE-REPORT-DEBUG] Received report from %s: asset %d, price %d, type %s", 
		player.Name, assetId, clientPrice, infoTypeName or "unknown"))
	
	-- SECURITY: Comprehensive input validation
	if typeof(assetId) ~= "number" or typeof(clientPrice) ~= "number" then
		print("[PRICE-REPORT-DEBUG] Invalid types - rejecting")
		logSuspiciousActivity(player, "Invalid price report types", 
			string.format("AssetID: %s, Price: %s", typeof(assetId), typeof(clientPrice)))
		return
	end
	
	-- SECURITY: Validate reasonable ranges
	if assetId <= 0 or assetId > 999999999999999 then
		logSuspiciousActivity(player, "Suspicious asset ID in price report", string.format("Asset: %d", assetId))
		return
	end
	
	if clientPrice < 0 then
		print("[PRICE-REPORT-DEBUG] Negative price - rejecting")
		logSuspiciousActivity(player, "Negative price reported", string.format("Price: %d", clientPrice))
		return
	end
	
	-- SECURITY: Validate price is within reasonable limits (max 10k Robux per item)
	if clientPrice > 10000 then
		logSuspiciousActivity(player, "Excessive price reported", string.format("Price: %d for asset: %d", clientPrice, assetId))
		return
	end
	
	-- SECURITY: Only accept price reports if we have a recent purchase event for this asset
	local playerPurchases = expectedPurchases[player]
	if not playerPurchases or not playerPurchases[assetId] then
		-- Log but don't block - might be timing issue
		print(string.format("[PRICE-REPORT] No expected purchase for asset %d from %s (type: %s)", assetId, player.Name, infoTypeName or "unknown"))
		if playerPurchases then
			print("[PRICE-REPORT] Available expected purchases:")
			for expectedAssetId, data in pairs(playerPurchases) do
				print(string.format("  - Asset %d (age: %.1fs)", expectedAssetId, os.clock() - data.timestamp))
			end
		end
		return
	end
	
	-- Check if the purchase event is recent (within 60 seconds - more lenient)
	local purchaseTime = playerPurchases[assetId].timestamp
	if (os.clock() - purchaseTime) > 60 then
		print(string.format("[PRICE-REPORT] Stale price report from %s (%.1f seconds old)", player.Name, os.clock() - purchaseTime))
		expectedPurchases[player][assetId] = nil
		return
	end
	
	-- Enhanced validation: Check if price is reasonable
	if clientPrice > MAX_SINGLE_PURCHASE_POINTS then
		logSuspiciousActivity(player, "Suspicious client price report", 
			string.format("Reported price: %d for asset %d", clientPrice, assetId))
		return
	end
	
	-- REMOVED: Price report rate limiting - was rejecting legitimate rapid purchases
	
	recentClientPricesByPlayer[player] = recentClientPricesByPlayer[player] or {}
	recentClientPricesByPlayer[player][assetId] = {
		price = math.floor(clientPrice),
		t = os.clock(),
		infoTypeName = infoTypeName,
	}
	
	print(string.format("[PRICE-REPORT-DEBUG] Accepted price report for asset %d", assetId))
	
	-- DON'T clear expected purchase here - let PromptPurchaseFinished handler do it
	-- This fixes race condition where purchase event fires but expected purchase is already cleared
end)

-- Called when purchase is completed - SECURITY: Only called from legitimate MarketplaceService events
local function grantPoints(player, robuxSpent, purchaseSource)
	-- SECURITY: Log all point grants with source for audit trail
	print(string.format("[SECURITY-AUDIT] Point grant request: Player=%s, Robux=%d, Source=%s", 
		player.Name, robuxSpent or 0, purchaseSource or "unknown"))
	
	-- Safely get leaderstats without infinite yield
	local stats = getLeaderstats(player, 5)
	if not stats then 
		warn("Leaderstats not found for points grant - player " .. player.Name)
		return 
	end

	-- Validate robuxSpent parameter
	if not robuxSpent or typeof(robuxSpent) ~= "number" or robuxSpent < 0 then
		warn(string.format("Invalid robuxSpent value for player %s: %s", player.Name, tostring(robuxSpent)))
		return
	end

	-- SECURITY: Validate purchase source is legitimate
	local validSources = {"PromptPurchaseFinished", "PromptBundlePurchaseFinished", "PromptGamePassPurchaseFinished"}
	if not purchaseSource or not table.find(validSources, purchaseSource) then
		logSuspiciousActivity(player, "Invalid purchase source for point grant", 
			string.format("Source: %s, Robux: %d", tostring(purchaseSource), robuxSpent))
		return
	end

	-- REMOVED: Purchase cooldown check - was blocking legitimate rapid purchases

	-- Give points with validation
	local points = stats:FindFirstChild("Points")
	if points then
		local currentPoints = points.Value
		local pointsToGrant = math.floor(robuxSpent / 1)
		local newPoints = currentPoints + pointsToGrant
		
		-- Validate the new points amount
		local isValid, errorMsg = validatePointsAmount(currentPoints, newPoints, "purchase")
		if not isValid then
			logSuspiciousActivity(player, "Invalid points calculation", errorMsg)
			return
		end
		
		-- Cap points at maximum
		if newPoints > MAX_POINTS then
			newPoints = MAX_POINTS
			pointsToGrant = newPoints - currentPoints
			logSuspiciousActivity(player, "Points capped at maximum", 
				string.format("Would have gained %d, capped at %d", math.floor(robuxSpent / 1), pointsToGrant))
		end
		
		points.Value = newPoints
		
		-- Track the point gain for anomaly detection
		trackPointGain(player, pointsToGrant)
		
		-- Update purchase timestamp
		lastPurchaseTime[player.UserId] = os.clock()
		
		print(string.format("[POINTS] %s gained %d points (robux: %d, total: %d)", 
			player.Name, pointsToGrant, robuxSpent, newPoints))
	end

	-- Update robux spent
	local spent = stats:FindFirstChild("RobuxSpent")
	if spent then
		spent.Value += robuxSpent
		print(spent.Value)
		print(robuxSpent)

		if TestMode then
			TestStore.addSpend(player.UserId, robuxSpent)
		else
			-- Save to OrderedDataStore
			local success, err = pcall(function()
				RobuxLeaderboard:SetAsync(player.UserId, spent.Value)
			end)
			if not success then
				warn("Failed to update leaderboard: " .. err)
			end
		end
	end
end

-- Detect purchase
MarketplaceService.PromptPurchaseFinished:Connect(function(player, assetId, isPurchased)
	local success, err = pcall(function()
		-- SECURITY FIX: Validate this purchase was server-initiated to prevent exploit spoofing
		-- This protects against exploiters using SignalPromptPurchaseFinished
		if isPurchased then
			-- LAYER 1: Validate server-initiated purchase
			local playerExpected = expectedPurchases[player]
			if not playerExpected or not playerExpected[assetId] then
				logSuspiciousActivity(player, "EXPLOIT ATTEMPT: Unsolicited purchase event", 
					string.format("Asset %d was not prompted by server", assetId))
				return -- REJECT spoofed purchase
			end
			
			-- Validate purchase is recent (within 120 seconds of prompt)
			local purchaseAge = os.clock() - playerExpected[assetId].timestamp
			if purchaseAge > 120 then
				logSuspiciousActivity(player, "EXPLOIT ATTEMPT: Stale purchase event", 
					string.format("Asset %d purchase is %.1f seconds old", assetId, purchaseAge))
				expectedPurchases[player][assetId] = nil
				return -- REJECT stale purchase
			end
			
			-- LAYER 2: Verify actual ownership (defense-in-depth)
			local ownsAsset = PurchaseTracking.verifyOwnership(player, assetId, "asset")
			if not ownsAsset then
				logSuspiciousActivity(player, "EXPLOIT ATTEMPT: Purchase event fired but player doesn't own asset", 
					string.format("Asset %d ownership verification failed", assetId))
				expectedPurchases[player][assetId] = nil
				return -- REJECT - player doesn't actually own the item
			end
			
			print(string.format("[SECURITY-VERIFIED] Player %s successfully purchased and owns asset %d", player.Name, assetId))
			
			-- Valid purchase - will be cleaned up at the end of processing
		else
			-- Purchase cancelled/failed - clean up expected entry
			if expectedPurchases[player] then
				expectedPurchases[player][assetId] = nil
			end
			return
		end
		
		-- Check if this is a claim purchase
		local claimData = playersCurrentlyClaiming[player]
		if claimData and claimData.assetId == assetId then
			-- Clear the claiming status
			playersCurrentlyClaiming[player] = nil
			
			if isPurchased then
				-- Deduct points for successful claim
				local stats = player:FindFirstChild("leaderstats")
				if stats then
					local points = stats:FindFirstChild("Points")
					if points and points.Value >= CLAIM_COST then
						points.Value -= CLAIM_COST
						claimResponseEvent:FireClient(player, true, "Free UGC claimed!", "success")
						print("Player " .. player.Name .. " successfully claimed free UGC for " .. CLAIM_COST .. " points")
					else
						claimResponseEvent:FireClient(player, false, "Insufficient points after purchase")
					end
				else
					claimResponseEvent:FireClient(player, false, "Stats not found after purchase")
				end
			else
				claimResponseEvent:FireClient(player, false, "Purchase cancelled")
			end
			return -- Exit early for claim purchases
		end
		
		-- Regular purchase handling (existing logic)
		if isPurchased then
		-- Wait briefly for the client to report the regional price if not present yet
		local clientEntry = recentClientPricesByPlayer[player] and recentClientPricesByPlayer[player][assetId]
		if not clientEntry then
			local deadline = os.clock() + 2
			while os.clock() < deadline do
				clientEntry = recentClientPricesByPlayer[player] and recentClientPricesByPlayer[player][assetId]
				if clientEntry then break end
				task.wait(0.1)
			end
		end

		-- Fetch default (non-regional) price for validation/fallback
		local defaultInfoType = Enum.InfoType.Asset
		local success, productInfo = pcall(function()
			return MarketplaceService:GetProductInfo(assetId, defaultInfoType)
		end)
		if not success or not productInfo or not productInfo.PriceInRobux then
			success, productInfo = pcall(function()
				return MarketplaceService:GetProductInfo(assetId)
			end)
		end

		if success and productInfo and productInfo.IsForSale then
			local defaultPrice = productInfo.PriceInRobux
			local robuxSpent = defaultPrice

		-- Prefer client-reported regionalized price if available and sane (within 30%-100% default)
		clientEntry = recentClientPricesByPlayer[player] and recentClientPricesByPlayer[player][assetId]
		if clientEntry and (os.clock() - clientEntry.t) <= 30 then -- Increased time window to 30 seconds
			local reported = clientEntry.price
			if typeof(reported) == "number" and reported > 0 then
				if typeof(defaultPrice) == "number" and defaultPrice and defaultPrice > 0 then
					local minAllowed = math.floor(defaultPrice * 0.3)
					local maxAllowed = defaultPrice
					if reported >= minAllowed and reported <= maxAllowed then
						robuxSpent = reported
					else
						-- Use default price if client price is outside range (don't reject, just use default)
						print(string.format("[PRICE] Client price %d outside range [%d-%d], using default %d", 
							reported, minAllowed, maxAllowed, defaultPrice))
					end
				else
					-- If no default price, trust client (regional pricing or limited item)
					robuxSpent = reported
					print(string.format("[PRICE] No default price for asset %d, using client-reported: %d", assetId, reported))
				end
			end
		end

		-- Clear cached entry after use
		if recentClientPricesByPlayer[player] then
			recentClientPricesByPlayer[player][assetId] = nil
		end
		
		-- SECURITY: Clear expected purchase after processing
		if expectedPurchases[player] then
			expectedPurchases[player][assetId] = nil
		end

		grantPoints(player, robuxSpent, "PromptPurchaseFinished")
			-- count purchase for badge milestones (persisted)
			local stats = player:FindFirstChild("leaderstats")
			if stats then
				local purchases = stats:FindFirstChild("Purchases")
				if purchases and purchases:IsA("IntValue") then
					if TestMode then
						purchases.Value += 1
					else
						local dataKey = "Purchases_" .. player.UserId
						local ok, newTotal = pcall(function()
							return PurchasesCountStore:IncrementAsync(dataKey, 1)
						end)
						if ok and typeof(newTotal) == "number" then
							purchases.Value = newTotal
						else
							purchases.Value += 1
						end
					end
				end
			end
		end
		end
	end)
	
	if not success then
		warn("PromptPurchaseFinished error for player " .. player.Name .. ":", err)
		-- Clear claiming status on error
		if playersCurrentlyClaiming[player] then
			playersCurrentlyClaiming[player] = nil
			claimResponseEvent:FireClient(player, false, "Purchase error occurred")
		end
	end
end)

-- Handle Bundle purchases
if MarketplaceService.PromptBundlePurchaseFinished then
	MarketplaceService.PromptBundlePurchaseFinished:Connect(function(player, bundleId, wasPurchased)
		-- LAYER 1: Validate this bundle purchase was server-initiated
		local playerExpected = expectedBundlePurchases[player]
		if not playerExpected or not playerExpected[bundleId] then
			if wasPurchased then
				logSuspiciousActivity(player, "EXPLOIT ATTEMPT: Unsolicited bundle purchase", 
					string.format("Bundle %d was not prompted by server", bundleId))
			end
			return -- REJECT spoofed purchase
		end
		
		-- Validate purchase is recent (within 120 seconds)
		local purchaseAge = os.clock() - playerExpected[bundleId].timestamp
		if purchaseAge > 120 then
			logSuspiciousActivity(player, "EXPLOIT ATTEMPT: Stale bundle purchase", 
				string.format("Bundle %d purchase is %.1f seconds old", bundleId, purchaseAge))
			expectedBundlePurchases[player][bundleId] = nil
			return -- REJECT stale purchase
		end
		
		-- Clear expected purchase
		expectedBundlePurchases[player][bundleId] = nil
		
		if not wasPurchased then return end
		
		-- LAYER 2: Verify actual ownership (defense-in-depth)
		local ownsBundle = PurchaseTracking.verifyOwnership(player, bundleId, "bundle")
		if not ownsBundle then
			logSuspiciousActivity(player, "EXPLOIT ATTEMPT: Bundle purchase event fired but player doesn't own bundle items", 
				string.format("Bundle %d ownership verification failed", bundleId))
			return -- REJECT - player doesn't actually own bundle items
		end
		
		print(string.format("[SECURITY-VERIFIED] Player %s successfully purchased and owns bundle %d", player.Name, bundleId))

		-- Wait briefly for the client to report
		local clientEntry = recentClientPricesByPlayer[player] and recentClientPricesByPlayer[player][bundleId]
		if not clientEntry then
			local deadline = os.clock() + 2
			while os.clock() < deadline do
				clientEntry = recentClientPricesByPlayer[player] and recentClientPricesByPlayer[player][bundleId]
				if clientEntry then break end
				task.wait(0.1)
			end
		end

		-- Get default price for validation
		local success, productInfo = pcall(function()
			return MarketplaceService:GetProductInfo(bundleId, Enum.InfoType.Bundle)
		end)
		if not success or not productInfo then
			success, productInfo = pcall(function()
				return MarketplaceService:GetProductInfo(bundleId)
			end)
		end
		if not success or not productInfo then 
			warn("Failed to get product info for bundle " .. bundleId)
			return 
		end

		-- For bundles, try to get price from different possible fields
		local defaultPrice = productInfo.PriceInRobux or productInfo.Price
		
		-- If bundle doesn't have direct price info, check our known bundle prices first
		if not defaultPrice then
			defaultPrice = KNOWN_BUNDLE_PRICES[bundleId]
			if defaultPrice then
				print("Using known price for bundle " .. bundleId .. ": " .. defaultPrice)
			end
		end
		
		-- If still no price, try to get it from MarketplaceService
		if not defaultPrice then
			local bundlePriceSuccess, bundleInfo = pcall(function()
				return MarketplaceService:GetProductInfo(bundleId, Enum.InfoType.Asset)
			end)
			if bundlePriceSuccess and bundleInfo and bundleInfo.PriceInRobux then
				defaultPrice = bundleInfo.PriceInRobux
			end
		end
		
		-- If we still don't have a price, check if client reported one
		if not defaultPrice then
			local clientEntry = recentClientPricesByPlayer[player] and recentClientPricesByPlayer[player][bundleId]
			if clientEntry and (os.clock() - clientEntry.t) <= 15 then
				local reported = clientEntry.price
				if typeof(reported) == "number" and reported > 0 then
					defaultPrice = reported
					print("Using client-reported price for bundle " .. bundleId .. ": " .. reported)
				end
			end
		end
		
		if not defaultPrice or defaultPrice <= 0 then
			-- For bundles without price info, we'll grant a minimal amount (5 robux equivalent)
			-- This ensures players still get some points for bundle purchases
			defaultPrice = 5
			warn("Bundle " .. bundleId .. " has no price info, granting minimal points (5 robux equivalent)")
		end
		
	local robuxSpent = defaultPrice
	-- Re-check client entry for final price validation
	clientEntry = recentClientPricesByPlayer[player] and recentClientPricesByPlayer[player][bundleId]
	if clientEntry and (os.clock() - clientEntry.t) <= 30 then -- Increased time window to 30 seconds
		local reported = clientEntry.price
		if typeof(reported) == "number" and reported > 0 then
			if typeof(defaultPrice) == "number" and defaultPrice and defaultPrice > 0 then
				local minAllowed = math.floor(defaultPrice * 0.3)
				local maxAllowed = defaultPrice
				if reported >= minAllowed and reported <= maxAllowed then
					robuxSpent = reported
				else
					-- Use default price if client price is outside range (don't reject, just use default)
					print(string.format("[PRICE] Bundle client price %d outside range [%d-%d], using default %d", 
						reported, minAllowed, maxAllowed, defaultPrice))
				end
			else
				-- If no default price, trust client (regional pricing)
				robuxSpent = reported
				print(string.format("[PRICE] No default price for bundle %d, using client-reported: %d", bundleId, reported))
			end
		end
	end

		if recentClientPricesByPlayer[player] then
			recentClientPricesByPlayer[player][bundleId] = nil
		end

		grantPoints(player, robuxSpent, "PromptBundlePurchaseFinished")
		local stats = player:FindFirstChild("leaderstats")
		if stats then
			local purchases = stats:FindFirstChild("Purchases")
			if purchases and purchases:IsA("IntValue") then
				if TestMode then
					purchases.Value += 1
				else
					local dataKey = "Purchases_" .. player.UserId
					local ok, newTotal = pcall(function()
						return PurchasesCountStore:IncrementAsync(dataKey, 1)
					end)
					if ok and typeof(newTotal) == "number" then
						purchases.Value = newTotal
					else
						purchases.Value += 1
					end
				end
			end
		end
	end)
end

-- Mirror logic for Game Pass purchases
if MarketplaceService.PromptGamePassPurchaseFinished then
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, gamePassId, wasPurchased)
		-- LAYER 1: Validate this gamepass purchase was server-initiated
		local playerExpected = expectedGamePassPurchases[player]
		if not playerExpected or not playerExpected[gamePassId] then
			if wasPurchased then
				logSuspiciousActivity(player, "EXPLOIT ATTEMPT: Unsolicited gamepass purchase", 
					string.format("GamePass %d was not prompted by server", gamePassId))
			end
			return -- REJECT spoofed purchase
		end
		
		-- Validate purchase is recent (within 120 seconds)
		local purchaseAge = os.clock() - playerExpected[gamePassId].timestamp
		if purchaseAge > 120 then
			logSuspiciousActivity(player, "EXPLOIT ATTEMPT: Stale gamepass purchase", 
				string.format("GamePass %d purchase is %.1f seconds old", gamePassId, purchaseAge))
			expectedGamePassPurchases[player][gamePassId] = nil
			return -- REJECT stale purchase
		end
		
		-- Clear expected purchase
		expectedGamePassPurchases[player][gamePassId] = nil
		
		if not wasPurchased then return end
		
		-- LAYER 2: Verify actual ownership (defense-in-depth)
		local ownsGamePass = PurchaseTracking.verifyOwnership(player, gamePassId, "gamepass")
		if not ownsGamePass then
			logSuspiciousActivity(player, "EXPLOIT ATTEMPT: GamePass purchase event fired but player doesn't own gamepass", 
				string.format("GamePass %d ownership verification failed", gamePassId))
			return -- REJECT - player doesn't actually own the gamepass
		end
		
		print(string.format("[SECURITY-VERIFIED] Player %s successfully purchased and owns gamepass %d", player.Name, gamePassId))

		-- Wait briefly for the client to report
		local clientEntry = recentClientPricesByPlayer[player] and recentClientPricesByPlayer[player][gamePassId]
		if not clientEntry then
			local deadline = os.clock() + 2
			while os.clock() < deadline do
				clientEntry = recentClientPricesByPlayer[player] and recentClientPricesByPlayer[player][gamePassId]
				if clientEntry then break end
				task.wait(0.1)
			end
		end

		-- Get default price for validation
		local success, productInfo = pcall(function()
			return MarketplaceService:GetProductInfo(gamePassId, Enum.InfoType.GamePass)
		end)
		if not success or not productInfo then
			success, productInfo = pcall(function()
				return MarketplaceService:GetProductInfo(gamePassId)
			end)
		end
		if not success or not productInfo then return end

	local defaultPrice = productInfo.PriceInRobux
	local robuxSpent = defaultPrice
	clientEntry = recentClientPricesByPlayer[player] and recentClientPricesByPlayer[player][gamePassId]
	if clientEntry and (os.clock() - clientEntry.t) <= 30 then -- Increased time window to 30 seconds
		local reported = clientEntry.price
		if typeof(reported) == "number" and reported > 0 then
			if typeof(defaultPrice) == "number" and defaultPrice and defaultPrice > 0 then
				local minAllowed = math.floor(defaultPrice * 0.3)
				local maxAllowed = defaultPrice
				if reported >= minAllowed and reported <= maxAllowed then
					robuxSpent = reported
				else
					-- Use default price if client price is outside range (don't reject, just use default)
					print(string.format("[PRICE] GamePass client price %d outside range [%d-%d], using default %d", 
						reported, minAllowed, maxAllowed, defaultPrice))
				end
			else
				-- If no default price, trust client (regional pricing)
				robuxSpent = reported
				print(string.format("[PRICE] No default price for gamepass %d, using client-reported: %d", gamePassId, reported))
			end
		end
	end

		if recentClientPricesByPlayer[player] then
			recentClientPricesByPlayer[player][gamePassId] = nil
		end

		grantPoints(player, robuxSpent, "PromptGamePassPurchaseFinished")
		local stats = player:FindFirstChild("leaderstats")
		if stats then
			local purchases = stats:FindFirstChild("Purchases")
			if purchases and purchases:IsA("IntValue") then
				if TestMode then
					purchases.Value += 1
				else
					local dataKey = "Purchases_" .. player.UserId
					local ok, newTotal = pcall(function()
						return PurchasesCountStore:IncrementAsync(dataKey, 1)
					end)
					if ok and typeof(newTotal) == "number" then
						purchases.Value = newTotal
					else
						purchases.Value += 1
					end
				end
			end
		end
	end)
end

-- Load leaderstats on join
game.Players.PlayerAdded:Connect(function(player)
	
	local pointsKey = "Points_" .. player.UserId
	local purchasesKey = "Purchases_" .. player.UserId
	local robuxSpent = 0
	local points = 0
	local purchasesCount = 0

	if not TestMode then
		local success, result = pcall(function()
			return PointsDataStore:GetAsync(pointsKey)
		end)
		if success and result then
			points = result
		end
	else
		points = 0
	end

	-- Get robux leaderboard value
	if not TestMode then
		local robuxSuccess, robuxValue = pcall(function()
			return RobuxLeaderboard:GetAsync(player.UserId)
		end)
		if robuxSuccess and robuxValue then
			robuxSpent = robuxValue
		end
	else
		robuxSpent = TestStore.getRobuxSpent(player.UserId)
	end

	-- Load persisted purchases count
	if not TestMode then
		local purchasesSuccess, storedPurchases = pcall(function()
			return PurchasesCountStore:GetAsync(purchasesKey)
		end)
		if purchasesSuccess and typeof(storedPurchases) == "number" then
			purchasesCount = storedPurchases
		else
			purchasesCount = 0
		end
	else
		purchasesCount = 0
	end

	-- Validate and sanitize points on load
	if points > MAX_POINTS then
		logSuspiciousActivity(player, "Excessive points on join", 
			string.format("Had %d points, reset to %d", points, MAX_POINTS))
		points = MAX_POINTS
	end
	
	if points < 0 then
		logSuspiciousActivity(player, "Negative points on join", 
			string.format("Had %d points, reset to 0", points))
		points = 0
	end

	-- Setup leaderstats
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	folder.Parent = player

	local p = Instance.new("IntValue")
	p.Name = "Points"
	p.Value = points
	p.Parent = folder
	
	-- SECURITY: Monitor for external point manipulation
	p.Changed:Connect(function(newValue)
		-- Only allow points to change through our grantPoints function
		-- by checking if the change is within expected parameters
		if newValue > MAX_POINTS then
			p.Value = MAX_POINTS
			logSuspiciousActivity(player, "Points exceeded maximum", 
				string.format("Attempted to set points to %d", newValue))
		elseif newValue < 0 then
			p.Value = 0
			logSuspiciousActivity(player, "Negative points detected", 
				string.format("Attempted to set points to %d", newValue))
		end
	end)

	local r = Instance.new("IntValue")
	r.Name = "RobuxSpent"
	r.Value = robuxSpent
	r.Parent = folder
	
	-- SECURITY: Monitor RobuxSpent for manipulation
	r.Changed:Connect(function(newValue)
		if newValue < robuxSpent then
			r.Value = robuxSpent
			logSuspiciousActivity(player, "RobuxSpent decreased", 
				string.format("Attempted to decrease RobuxSpent from %d to %d", robuxSpent, newValue))
		end
	end)

	local c = Instance.new("IntValue")
	c.Name = "Purchases"
	c.Value = purchasesCount
	c.Parent = folder

end)

-- Save points and purchases on leave (Robux is saved during purchases)
game.Players.PlayerRemoving:Connect(function(player)
	-- Clear cached client price entries
	recentClientPricesByPlayer[player] = nil
	-- Clear claiming status
	playersCurrentlyClaiming[player] = nil
	-- Clear anti-exploit tracking
	lastPurchaseTime[player.UserId] = nil
	recentPointGains[player.UserId] = nil
	-- SECURITY: Clear purchase tracking using module
	PurchaseTracking.cleanupPlayer(player)
	-- Clear claim tracking (SECURITY)
	claimAttempts[player.UserId] = nil
	lastClaimTime[player.UserId] = nil
	if TestMode then return end

	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		local points = leaderstats:FindFirstChild("Points")
		if points then
			pcall(function()
				PointsDataStore:SetAsync("Points_" .. player.UserId, points.Value)
			end)
		end
		-- Save purchases count defensively
		local purchases = leaderstats:FindFirstChild("Purchases")
		if purchases then
			pcall(function()
				PurchasesCountStore:SetAsync("Purchases_" .. player.UserId, purchases.Value)
			end)
		end
	end
end)
