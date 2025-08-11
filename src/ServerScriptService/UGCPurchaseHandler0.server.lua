local MarketplaceService = game:GetService("MarketplaceService")

local function grantPoints(player, robuxSpent)
	local pointsToAdd = math.floor(robuxSpent / 1)

	local stats = player:FindFirstChild("leaderstats")
	if stats and stats:FindFirstChild("Points") then
		stats.Points.Value += pointsToAdd
	end
end

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
