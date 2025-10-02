local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestMode = require(script.Parent.Utility.TestMode)
local TestStore = require(script.Parent.Utility.TestStore)

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
local FREE_ASSET_ID = 85890247763956 -- Set this to match your client
local CLAIM_COST = 500 -- Points required to claim

-- Bundle price mapping for third-party bundles that we can't get price info for
local KNOWN_BUNDLE_PRICES = {
	[6470] = 175, -- Chibi-Doll-Girl Bundle - 175 robux
	[7635] = 175, -- Chibi Doll Girl (V2) - 175 robux
	[1590409] = 58,
	[83] = 62,
	-- Add more bundle IDs and their prices here as needed
}

-- Security Configuration
local MAX_POINTS = 9999 -- Maximum allowed points per player
local MAX_SINGLE_PURCHASE_POINTS = 2000 -- Maximum points from a single purchase
local PURCHASE_COOLDOWN = 2 -- Seconds between purchases for same player
local SUSPICIOUS_POINTS_THRESHOLD = 5000 -- Alert threshold for rapid point gains

-- Anti-exploit tracking
local lastPurchaseTime = {} -- Track last purchase time per player
local recentPointGains = {} -- Track recent point gains for anomaly detection
local suspiciousPlayers = {} -- Track players with suspicious activity

-- Bulk purchase security tracking
local recentRobuxSpending = {} -- [player] = {totalSpent, timestamp, purchases = {}}
local bulkPurchaseHistory = {} -- [player] = {count, resetTime}

-- Security Functions
local function logSuspiciousActivity(player, reason, details)
	local message = string.format("[SECURITY ALERT] Player %s (%d): %s - %s", 
		player.Name, player.UserId, reason, details or "")
	warn(message)
	
	-- Mark player as suspicious
	suspiciousPlayers[player.UserId] = {
		reason = reason,
		details = details,
		timestamp = os.time()
	}
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
	local userId = player.UserId
	recentPointGains[userId] = recentPointGains[userId] or {}
	
	-- Add current gain with timestamp
	table.insert(recentPointGains[userId], {
		points = pointsGained,
		timestamp = os.clock()
	})
	
	-- Clean old entries (older than 5 minutes)
	local cutoff = os.clock() - 300
	local filteredEntries = {}
	for _, entry in ipairs(recentPointGains[userId]) do
		if entry.timestamp > cutoff then
			table.insert(filteredEntries, entry)
		end
	end
	recentPointGains[userId] = filteredEntries
	
	-- Check for suspicious rapid gains
	local totalRecentGains = 0
	for _, entry in ipairs(recentPointGains[userId]) do
		totalRecentGains += entry.points
	end
	
	if totalRecentGains > SUSPICIOUS_POINTS_THRESHOLD then
		logSuspiciousActivity(player, "Rapid point accumulation", 
			string.format("Gained %d points in last 5 minutes", totalRecentGains))
	end
end

-- Bulk Purchase Security Functions
local function trackRobuxSpending(player, robuxAmount, purchaseType)
	local userId = player.UserId
	local currentTime = os.clock()
	
	-- Initialize or get existing spending data
	if not recentRobuxSpending[player] then
		recentRobuxSpending[player] = {
			totalSpent = 0,
			timestamp = currentTime,
			purchases = {}
		}
	end
	
	local spendingData = recentRobuxSpending[player]
	
	-- Clean old purchases (older than 2 minutes)
	local cutoff = currentTime - 120
	local filteredPurchases = {}
	local totalRecent = 0
	
	for _, purchase in ipairs(spendingData.purchases) do
		if purchase.timestamp > cutoff then
			table.insert(filteredPurchases, purchase)
			totalRecent += purchase.amount
		end
	end
	
	-- Add new purchase
	table.insert(filteredPurchases, {
		amount = robuxAmount,
		timestamp = currentTime,
		type = purchaseType
	})
	totalRecent += robuxAmount
	
	-- Update spending data
	spendingData.purchases = filteredPurchases
	spendingData.totalSpent = totalRecent
	spendingData.timestamp = currentTime
	
	print(string.format("[ROBUX-TRACK] %s spent %d robux (%s), recent total: %d", 
		player.Name, robuxAmount, purchaseType, totalRecent))
end

local function canMakeBulkPurchase(player)
	local userId = player.UserId
	local currentTime = os.clock()
	
	-- Initialize history if needed
	if not bulkPurchaseHistory[player] then
		bulkPurchaseHistory[player] = {count = 0, resetTime = currentTime + 300}
	end
	
	local history = bulkPurchaseHistory[player]
	
	-- Reset counter if time window expired
	if currentTime > history.resetTime then
		history.count = 0
		history.resetTime = currentTime + 300 -- 5 minute window
	end
	
	-- Check if player has exceeded bulk purchase limit
	if history.count >= 5 then -- Max 5 bulk purchases per 5 minutes
		return false, "Too many bulk purchases in short time"
	end
	
	return true, nil
end

local function validateBulkPurchaseAmount(player, reportedRobux)
	local spendingData = recentRobuxSpending[player]
	
	-- Must have recent spending data
	if not spendingData or not spendingData.purchases then
		return false, "No recent purchase activity detected"
	end
	
	-- Check if we have recent spending within last 60 seconds
	local currentTime = os.clock()
	local recentSpending = 0
	local hasRecentActivity = false
	
	for _, purchase in ipairs(spendingData.purchases) do
		if (currentTime - purchase.timestamp) <= 60 then
			recentSpending += purchase.amount
			hasRecentActivity = true
		end
	end
	
	if not hasRecentActivity then
		return false, "No recent purchase activity (within 60 seconds)"
	end
	
	-- Allow some tolerance for timing and regional price differences
	local minExpected = math.floor(recentSpending * 0.7) -- 70% of tracked spending
	local maxExpected = math.ceil(recentSpending * 1.3)  -- 130% of tracked spending
	
	if reportedRobux < minExpected then
		return false, string.format("Reported robux (%d) too low vs tracked (%d)", reportedRobux, recentSpending)
	end
	
	if reportedRobux > maxExpected then
		return false, string.format("Reported robux (%d) too high vs tracked (%d)", reportedRobux, recentSpending)
	end
	
	return true, nil
end

-- Handle claim requests from clients
claimEvent.OnServerEvent:Connect(function(player, assetId)
	local success, err = pcall(function()
		-- Validate input
		if typeof(assetId) ~= "number" then
			claimResponseEvent:FireClient(player, false, "Invalid asset ID")
			return
		end
		
		-- Check if player is already claiming
		if playersCurrentlyClaiming[player] then
			claimResponseEvent:FireClient(player, false, "Already claiming an item")
			return
		end
		
		-- Validate it's the correct free asset
		if assetId ~= FREE_ASSET_ID then
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

-- Track expected individual purchases from Roblox events
local expectedPurchases = {} -- [player][assetId] = {timestamp = number}

reportEvent.OnServerEvent:Connect(function(player, assetId, clientPrice, infoTypeName)
	if typeof(assetId) ~= "number" or typeof(clientPrice) ~= "number" then
		return
	end
	if clientPrice < 0 then
		return
	end
	
	-- SECURITY: Only accept price reports if we have a recent purchase event for this asset
	local playerPurchases = expectedPurchases[player]
	if not playerPurchases or not playerPurchases[assetId] then
		logSuspiciousActivity(player, "Price report without purchase", 
			string.format("Asset %d price report without MarketplaceService event", assetId))
		return
	end
	
	-- Check if the purchase event is recent (within 30 seconds)
	local purchaseTime = playerPurchases[assetId].timestamp
	if (os.clock() - purchaseTime) > 30 then
		logSuspiciousActivity(player, "Stale price report", 
			string.format("Price report %.1f seconds after purchase", os.clock() - purchaseTime))
		expectedPurchases[player][assetId] = nil
		return
	end
	
	-- Enhanced validation: Check if price is reasonable
	if clientPrice > MAX_SINGLE_PURCHASE_POINTS then
		logSuspiciousActivity(player, "Suspicious client price report", 
			string.format("Reported price: %d for asset %d", clientPrice, assetId))
		return
	end
	
	-- Rate limit price reports
	local playerData = recentClientPricesByPlayer[player] or {}
	local lastReport = playerData.lastReportTime or 0
	if (os.clock() - lastReport) < 0.5 then -- 500ms cooldown between reports
		return
	end
	
	recentClientPricesByPlayer[player] = recentClientPricesByPlayer[player] or {}
	recentClientPricesByPlayer[player][assetId] = {
		price = math.floor(clientPrice),
		t = os.clock(),
		infoTypeName = infoTypeName,
	}
	recentClientPricesByPlayer[player].lastReportTime = os.clock()
	
	-- Clear the expected purchase since we've processed it
	if expectedPurchases[player] then
		expectedPurchases[player][assetId] = nil
	end
end)

-- Called when purchase is completed
local function grantPoints(player, robuxSpent)
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

	-- Security checks
	if isPlayerOnCooldown(player) then
		logSuspiciousActivity(player, "Purchase cooldown violation", 
			string.format("Attempted purchase while on cooldown"))
		return
	end
	
	-- Check if player is already flagged as suspicious
	if suspiciousPlayers[player.UserId] then
		warn(string.format("Blocking points for suspicious player %s (%d)", player.Name, player.UserId))
		return
	end

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
		-- Track this purchase for price report validation
		if isPurchased then
			expectedPurchases[player] = expectedPurchases[player] or {}
			expectedPurchases[player][assetId] = {
				timestamp = os.clock()
			}
			
			-- Clean up old expected purchases (older than 60 seconds)
			task.delay(60, function()
				if expectedPurchases[player] and expectedPurchases[player][assetId] then
					expectedPurchases[player][assetId] = nil
				end
			end)
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
			if clientEntry and (os.clock() - clientEntry.t) <= 15 then
				local reported = clientEntry.price
				if typeof(reported) == "number" and reported > 0 then
					if typeof(defaultPrice) == "number" and defaultPrice and defaultPrice > 0 then
						local minAllowed = math.floor(defaultPrice * 0.3)
						local maxAllowed = defaultPrice
						if reported >= minAllowed and reported <= maxAllowed then
							robuxSpent = reported
						end
					else
						-- SECURITY PATCH: Never trust client when we can't validate
						logSuspiciousActivity(player, "Client price rejected - no default price", 
							string.format("Reported: %d, Asset: %d", reported, assetId))
						robuxSpent = 0  -- Give 0 points when we can't validate
					end
				end
			end

			-- Clear cached entry after use
			if recentClientPricesByPlayer[player] then
				recentClientPricesByPlayer[player][assetId] = nil
			end

			-- Track this spending for bulk purchase validation
			trackRobuxSpending(player, robuxSpent, "Asset")
			
			grantPoints(player, robuxSpent)
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

-- Note: PromptBulkPurchaseFinished can only be used in LocalScripts (client-side)
-- The client handles bulk purchase detection and reports to server via bulkPurchaseReportEvent

-- Handle Bundle purchases
if MarketplaceService.PromptBundlePurchaseFinished then
	MarketplaceService.PromptBundlePurchaseFinished:Connect(function(player, bundleId, wasPurchased)
		if not wasPurchased then return end

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
		if clientEntry and (os.clock() - clientEntry.t) <= 15 then
			local reported = clientEntry.price
			if typeof(reported) == "number" and reported > 0 then
				if typeof(defaultPrice) == "number" and defaultPrice and defaultPrice > 0 then
					local minAllowed = math.floor(defaultPrice * 0.3)
					local maxAllowed = defaultPrice
					if reported >= minAllowed and reported <= maxAllowed then
						robuxSpent = reported
					end
				else
					-- SECURITY PATCH: Never trust client when we can't validate Bundle prices
					logSuspiciousActivity(player, "Bundle client price rejected - no default price", 
						string.format("Reported: %d, Bundle: %d", reported, bundleId))
					robuxSpent = 0  -- Give 0 points when we can't validate
				end
			end
		end

		if recentClientPricesByPlayer[player] then
			recentClientPricesByPlayer[player][bundleId] = nil
		end

		-- Track this spending for bulk purchase validation
		trackRobuxSpending(player, robuxSpent, "Bundle")

		grantPoints(player, robuxSpent)
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
		if not wasPurchased then return end

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
		if clientEntry and (os.clock() - clientEntry.t) <= 15 then
			local reported = clientEntry.price
			if typeof(reported) == "number" and reported > 0 then
				if typeof(defaultPrice) == "number" and defaultPrice and defaultPrice > 0 then
					local minAllowed = math.floor(defaultPrice * 0.3)
					local maxAllowed = defaultPrice
					if reported >= minAllowed and reported <= maxAllowed then
						robuxSpent = reported
					end
				else
					-- SECURITY PATCH: Never trust client when we can't validate GamePass prices
					logSuspiciousActivity(player, "GamePass client price rejected - no default price", 
						string.format("Reported: %d, GamePass: %d", reported, gamePassId))
					robuxSpent = 0  -- Give 0 points when we can't validate
				end
			end
		end

		if recentClientPricesByPlayer[player] then
			recentClientPricesByPlayer[player][gamePassId] = nil
		end

		-- Track this spending for bulk purchase validation
		trackRobuxSpending(player, robuxSpent, "GamePass")

		grantPoints(player, robuxSpent)
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

-- Create RemoteEvent for bulk purchase reporting
local bulkPurchaseReportEvent = ReplicatedStorage:FindFirstChild("UGC_ReportBulkPurchase")
if not bulkPurchaseReportEvent then
	bulkPurchaseReportEvent = Instance.new("RemoteEvent")
	bulkPurchaseReportEvent.Name = "UGC_ReportBulkPurchase"
	bulkPurchaseReportEvent.Parent = ReplicatedStorage
end

-- Note: expectedBulkPurchases removed since PromptBulkPurchaseFinished can only be used client-side

-- Handle bulk purchase reports from client
bulkPurchaseReportEvent.OnServerEvent:Connect(function(player, purchaseData)
	print("[BULK] Received bulk purchase report from", player.Name)
	
	-- Note: Since PromptBulkPurchaseFinished can only be used client-side,
	-- we rely on client-side MarketplaceService events which are legitimate Roblox events
	-- and implement basic server-side validation instead of cross-referencing with server events
	
	-- Basic security validation
	if not purchaseData or typeof(purchaseData) ~= "table" then
		logSuspiciousActivity(player, "Invalid bulk purchase data", 
			string.format("Type: %s", typeof(purchaseData)))
		return
	end
	
	-- Check if player is flagged as suspicious
	if suspiciousPlayers[player.UserId] then
		warn(string.format("Blocking bulk purchase for suspicious player %s (%d)", player.Name, player.UserId))
		return
	end
	
	-- Extract data from the purchase report
	local items = purchaseData.Items
	local totalRobuxSpent = purchaseData.RobuxSpent or 0
	local totalItems = 0
	
	if items and typeof(items) == "table" then
		totalItems = #items
	end
	
	-- Basic validation on the reported values
	if totalRobuxSpent < 0 or totalRobuxSpent > MAX_SINGLE_PURCHASE_POINTS then
		logSuspiciousActivity(player, "Suspicious bulk purchase robux amount", 
			string.format("Reported: %d robux", totalRobuxSpent))
		return
	end
	
	if totalItems <= 0 or totalItems > 50 then -- Reasonable limit on bulk items
		logSuspiciousActivity(player, "Suspicious bulk purchase item count", 
			string.format("Reported: %d items", totalItems))
		return
	end
	
	-- SECURITY: Check bulk purchase rate limiting
	local canPurchase, bulkError = canMakeBulkPurchase(player)
	if not canPurchase then
		logSuspiciousActivity(player, "Bulk purchase rate limit exceeded", bulkError)
		return
	end
	
	-- SECURITY: Validate against tracked Robux spending
	local isValidAmount, validationError = validateBulkPurchaseAmount(player, totalRobuxSpent)
	if not isValidAmount then
		logSuspiciousActivity(player, "Bulk purchase validation failed", validationError)
		return
	end
	
	-- Rate limiting - prevent rapid bulk purchase reports
	if isPlayerOnCooldown(player) then
		logSuspiciousActivity(player, "Bulk purchase cooldown violation", 
			"Attempted bulk purchase while on cooldown")
		return
	end
	
	-- Increment bulk purchase counter
	bulkPurchaseHistory[player].count += 1
	
	print("[BULK] Processing", totalItems, "items with robux:", totalRobuxSpent)
	
	if totalRobuxSpent > 0 then
		grantPoints(player, totalRobuxSpent)
		
		-- Update purchase count for bulk purchase
		local stats = player:FindFirstChild("leaderstats")
		if stats then
			local purchases = stats:FindFirstChild("Purchases")
			if purchases and purchases:IsA("IntValue") then
				if TestMode then
					purchases.Value += totalItems
				else
					local dataKey = "Purchases_" .. player.UserId
					local ok, newTotal = pcall(function()
						return PurchasesCountStore:IncrementAsync(dataKey, totalItems)
					end)
					if ok and typeof(newTotal) == "number" then
						purchases.Value = newTotal
					else
						purchases.Value += totalItems
					end
				end
			end
		end
		
		print("[BULK] Successfully processed bulk purchase for", player.Name, "- Robux:", totalRobuxSpent, "Items:", totalItems)
	else
		warn("[BULK] No robux spent reported for bulk purchase from", player.Name)
	end
end)

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

	local r = Instance.new("IntValue")
	r.Name = "RobuxSpent"
	r.Value = robuxSpent
	r.Parent = folder

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
	-- Clear purchase tracking
	expectedPurchases[player] = nil
	-- Clear bulk purchase security tracking
	recentRobuxSpending[player] = nil
	bulkPurchaseHistory[player] = nil
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
