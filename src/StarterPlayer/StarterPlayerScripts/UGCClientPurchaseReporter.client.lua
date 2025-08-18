local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LOCAL_PLAYER = Players.LocalPlayer
local reportEvent = ReplicatedStorage:WaitForChild("UGC_ReportPurchasePrice", 5)

local function getRegionalPriceForAsset(assetId: number): number?
	local product
	local ok, _ = pcall(function()
		product = MarketplaceService:GetProductInfo(assetId, Enum.InfoType.GamePass)
	end)
	if not ok or not product then
		-- Fallback without explicit InfoType
		pcall(function()
			product = MarketplaceService:GetProductInfo(assetId)
		end)
	end
	if not product then return nil end
	return product.PriceInRobux
end

-- Auto-report when any purchase finishes on client
MarketplaceService.PromptPurchaseFinished:Connect(function(...)
	local args = { ... }
	-- Possible signatures: (assetId, isPurchased) or (userId, assetId, isPurchased)
	local assetId, isPurchased
	if typeof(args[1]) == "number" and typeof(args[2]) == "boolean" then
		assetId, isPurchased = args[1], args[2]
	elseif typeof(args[2]) == "number" and typeof(args[3]) == "boolean" then
		assetId, isPurchased = args[2], args[3]
	end
	if isPurchased and typeof(assetId) == "number" then
		local price = getRegionalPriceForAsset(assetId)
		if price and reportEvent then
			reportEvent:FireServer(assetId, price, "Asset")
		end
	end
end)

-- Also listen for game pass purchases explicitly
if MarketplaceService.PromptGamePassPurchaseFinished then
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(userId, gamePassId, wasPurchased)
		if wasPurchased and typeof(gamePassId) == "number" then
			local price = getRegionalPriceForAsset(gamePassId)
			if price and reportEvent then
				reportEvent:FireServer(gamePassId, price, "GamePass")
			end
		end
	end)
end

-- Optional helper; you can call this from any UI code if needed
local function promptGamePassPurchaseWithReporting(assetId: number)
	if typeof(assetId) ~= "number" then return end
	local price = getRegionalPriceForAsset(assetId)
	if reportEvent and price then
		reportEvent:FireServer(assetId, price, "GamePass")
	end
	MarketplaceService:PromptGamePassPurchase(LOCAL_PLAYER, assetId)
	-- Fire again after prompting to account for any dynamic updates
	task.defer(function()
		local postPrice = getRegionalPriceForAsset(assetId)
		if postPrice and reportEvent then
			reportEvent:FireServer(assetId, postPrice, "GamePass")
		end
	end)
end

_G.UGC_PromptGamePassPurchaseWithReporting = promptGamePassPurchaseWithReporting 