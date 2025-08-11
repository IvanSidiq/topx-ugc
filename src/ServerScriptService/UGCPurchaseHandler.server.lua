local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")

local PointsDataStore = DataStoreService:GetDataStore("UGCPlayerPoints")
local RobuxLeaderboard = DataStoreService:GetOrderedDataStore("RobuxSpentLeaderboard")

-- Called when purchase is completed
local function grantPoints(player, robuxSpent)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then return end

	-- Give points
	local points = stats:FindFirstChild("Points")
	if points then
		points.Value += math.floor(robuxSpent / 10)
	end

	-- Update robux spent
	local spent = stats:FindFirstChild("RobuxSpent")
	if spent then
		spent.Value += robuxSpent

		-- Save to OrderedDataStore
		local success, err = pcall(function()
			RobuxLeaderboard:SetAsync(player.UserId, spent.Value)
		end)
		if not success then
			warn("Failed to update leaderboard: " .. err)
		end
	end
end

-- Detect purchase
MarketplaceService.PromptPurchaseFinished:Connect(function(player, assetId, isPurchased)
	if isPurchased then
		local success, productInfo = pcall(function()
			return MarketplaceService:GetProductInfo(assetId)
		end)

		if success and productInfo and productInfo.IsForSale and productInfo.PriceInRobux then
			local robuxSpent = productInfo.PriceInRobux
			grantPoints(player, robuxSpent)
		end
	end
end)

-- Load leaderstats on join
game.Players.PlayerAdded:Connect(function(player)
	local dataKey = "Points_" .. player.UserId
	local robuxSpent = 0
	local points = 0

	local success, result = pcall(function()
		return PointsDataStore:GetAsync(dataKey)
	end)

	if success and result then
		points = result
	end

	-- Get robux leaderboard value
	local robuxSuccess, robuxValue = pcall(function()
		return RobuxLeaderboard:GetAsync(player.UserId)
	end)

	if robuxSuccess and robuxValue then
		robuxSpent = robuxValue
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
end)

-- Save points only (Robux is saved during purchases)
game.Players.PlayerRemoving:Connect(function(player)
	local points = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Points")
	if points then
		pcall(function()
			PointsDataStore:SetAsync("Points_" .. player.UserId, points.Value)
		end)
	end
end)
