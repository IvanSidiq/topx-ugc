local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local TestMode = require(script.Parent.Utility.TestMode)
local TestStore = require(script.Parent.Utility.TestStore)

local PointsDataStore = DataStoreService:GetDataStore("UGCPlayerPoints")
local RobuxLeaderboard = DataStoreService:GetOrderedDataStore("RobuxSpentLeaderboard")

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
		local success, productInfo = pcall(function()
			return MarketplaceService:GetProductInfo(assetId)
		end)

		if success and productInfo and productInfo.IsForSale and productInfo.PriceInRobux then
			local robuxSpent = productInfo.PriceInRobux
			grantPoints(player, robuxSpent)
			-- count purchase for badge milestones
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

-- Save points only (Robux is saved during purchases)
game.Players.PlayerRemoving:Connect(function(player)
	if TestMode then return end
	local points = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Points")
	if points then
		pcall(function()
			PointsDataStore:SetAsync("Points_" .. player.UserId, points.Value)
		end)
	end
end)
