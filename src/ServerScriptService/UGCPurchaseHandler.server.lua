local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TestMode = require(script.Parent.Utility.TestMode)
local TestStore = require(script.Parent.Utility.TestStore)

local PointsDataStore = DataStoreService:GetDataStore("UGCPlayerPoints")
local RobuxLeaderboard = DataStoreService:GetOrderedDataStore("RobuxSpentLeaderboard")

-- Prefer client-reported regional prices via RemoteEvent
local reportEvent = ReplicatedStorage:FindFirstChild("UGC_ReportPurchasePrice")
if not reportEvent then
	reportEvent = Instance.new("RemoteEvent")
	reportEvent.Name = "UGC_ReportPurchasePrice"
	reportEvent.Parent = ReplicatedStorage
end

local recentClientPricesByPlayer = {}

reportEvent.OnServerEvent:Connect(function(player, assetId, clientPrice, infoTypeName)
	if typeof(assetId) ~= "number" or typeof(clientPrice) ~= "number" then
		return
	end
	if clientPrice < 0 then
		return
	end
	recentClientPricesByPlayer[player] = recentClientPricesByPlayer[player] or {}
	recentClientPricesByPlayer[player][assetId] = {
		price = math.floor(clientPrice),
		t = os.clock(),
		infoTypeName = infoTypeName,
	}
end)

-- Called when purchase is completed
local function grantPoints(player, robuxSpent)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then return end

	-- Give points
	local points = stats:FindFirstChild("Points")
	if points then
		points.Value += math.floor(robuxSpent / 1)
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
						robuxSpent = reported
					end
				end
			end

			-- Clear cached entry after use
			if recentClientPricesByPlayer[player] then
				recentClientPricesByPlayer[player][assetId] = nil
			end

			grantPoints(player, robuxSpent)
			-- count purchase for badge milestones (session-only)
			local stats = player:FindFirstChild("leaderstats")
			if stats then
				local purchases = stats:FindFirstChild("Purchases")
				if purchases and purchases:IsA("IntValue") then
					purchases.Value += 1
				end
			end
		end
	end
end)

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
					robuxSpent = reported
				end
			end
		end

		if recentClientPricesByPlayer[player] then
			recentClientPricesByPlayer[player][gamePassId] = nil
		end

		grantPoints(player, robuxSpent)
		local stats = player:FindFirstChild("leaderstats")
		if stats then
			local purchases = stats:FindFirstChild("Purchases")
			if purchases and purchases:IsA("IntValue") then
				purchases.Value += 1
			end
		end
	end)
end

-- Load leaderstats on join
game.Players.PlayerAdded:Connect(function(player)
	local dataKey = "Points_" .. player.UserId
	local robuxSpent = 0
	local points = 0

	if not TestMode then
		local success, result = pcall(function()
			return PointsDataStore:GetAsync(dataKey)
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
	c.Value = 0
	c.Parent = folder
end)

-- Save points and purchases on leave (Robux is saved during purchases)
game.Players.PlayerRemoving:Connect(function(player)
	-- Clear cached client price entries
	recentClientPricesByPlayer[player] = nil
	if TestMode then return end
	local points = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Points")
	if points then
		pcall(function()
			PointsDataStore:SetAsync("Points_" .. player.UserId, points.Value)
		end)
	end
end)
