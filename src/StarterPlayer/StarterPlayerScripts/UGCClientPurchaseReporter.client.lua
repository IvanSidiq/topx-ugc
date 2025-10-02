local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LOCAL_PLAYER = Players.LocalPlayer
local reportEvent = ReplicatedStorage:WaitForChild("UGC_ReportPurchasePrice", 10)
local bulkPurchaseReportEvent = ReplicatedStorage:WaitForChild("UGC_ReportBulkPurchase", 10)

local function getRegionalPriceForAsset(assetId: number, infoType: Enum.InfoType?): number?
	local product
	
	-- Try with specific InfoType if provided
	if infoType then
		local ok, _ = pcall(function()
			product = MarketplaceService:GetProductInfo(assetId, infoType)
		end)
	end
	
	-- If no product yet, try GamePass
	if not product then
		local ok, _ = pcall(function()
			product = MarketplaceService:GetProductInfo(assetId, Enum.InfoType.GamePass)
		end)
	end
	
	-- If still no product, fallback without explicit InfoType
	if not product then
		pcall(function()
			product = MarketplaceService:GetProductInfo(assetId)
		end)
	end
	
	if not product then return nil end
	return product.PriceInRobux or product.Price
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
		local price = getRegionalPriceForAsset(assetId, Enum.InfoType.Asset)
		if price and reportEvent then
			reportEvent:FireServer(assetId, price, "Asset")
		end
	end
end)

-- Also listen for game pass purchases explicitly
if MarketplaceService.PromptGamePassPurchaseFinished then
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(userId, gamePassId, wasPurchased)
		if wasPurchased and typeof(gamePassId) == "number" then
			local price = getRegionalPriceForAsset(gamePassId, Enum.InfoType.GamePass)
			if price and reportEvent then
				reportEvent:FireServer(gamePassId, price, "GamePass")
			end
		end
	end)
end

-- Listen for bundle purchases
if MarketplaceService.PromptBundlePurchaseFinished then
	MarketplaceService.PromptBundlePurchaseFinished:Connect(function(userId, bundleId, wasPurchased)
		if wasPurchased and typeof(bundleId) == "number" then
			-- Try to get bundle price using Bundle InfoType first
			local price = getRegionalPriceForAsset(bundleId, Enum.InfoType.Bundle)
			
			-- If that doesn't work, try without InfoType
			if not price then
				price = getRegionalPriceForAsset(bundleId)
			end
			

			
			if price and price > 0 and reportEvent then
				reportEvent:FireServer(bundleId, price, "Bundle")
			else
				-- If we can't get price, still report 0 so server knows a purchase happened
				if reportEvent then
					reportEvent:FireServer(bundleId, 0, "Bundle")
				end
			end
		end
	end)
end

-- Listen for bulk/cart purchases
if MarketplaceService.PromptBulkPurchaseFinished then
	MarketplaceService.PromptBulkPurchaseFinished:Connect(function(player, status, purchaseInfo)
		print("PromptBulkPurchaseFinished - Player:", player, "Status:", status, "Info:", purchaseInfo)
		
		-- Check if purchase was completed successfully
		if status == Enum.MarketplaceBulkPurchasePromptStatus.Completed and purchaseInfo then
			-- Try to get bulkPurchaseReportEvent again if it wasn't available initially
			local currentBulkEvent = bulkPurchaseReportEvent or ReplicatedStorage:FindFirstChild("UGC_ReportBulkPurchase")
			if currentBulkEvent then
				local items = purchaseInfo.Items
				local totalRobuxSpent = purchaseInfo.RobuxSpent
				
				if items and typeof(items) == "table" and next(items) then
					-- Count items manually since #items might not work with non-sequential tables
					local itemCount = 0
					for _ in pairs(items) do
						itemCount += 1
					end
					print("Reporting bulk purchase with", itemCount, "items, total robux:", totalRobuxSpent)
					
					-- Convert the items to the format expected by server
					local convertedItems = {}
					for _, item in ipairs(items) do
						-- Check if the item was purchased successfully
						-- The status appears to be an enum value, let's check for "Success" string or enum
						local isSuccess = (item.status == "Success") or 
										  (typeof(item.status) == "EnumItem" and tostring(item.status) == "Success") or
										  (item.status == Enum.MarketplaceItemPurchaseStatus.Success)
						
						if isSuccess then
							table.insert(convertedItems, {
								Id = tonumber(item.id) or item.id,
								Type = item.type,
								Status = item.status
							})
						end
					end
					
					-- Report the bulk purchase to server with total robux spent
					if #convertedItems > 0 then
						currentBulkEvent:FireServer({
							Items = convertedItems,
							RobuxSpent = totalRobuxSpent
						})
					end
					
					-- Also report individual item prices for future reference
					for _, item in ipairs(items) do
						-- Check if the item was purchased successfully (same logic as above)
						local isSuccess = (item.status == "Success") or 
										  (typeof(item.status) == "EnumItem" and tostring(item.status) == "Success") or
										  (item.status == Enum.MarketplaceItemPurchaseStatus.Success)
						
						if isSuccess then
							local itemId = tonumber(item.id) or item.id
							local itemType = item.type
							
							local price
							if itemType == Enum.MarketplaceProductType.AvatarBundle then
								price = getRegionalPriceForAsset(itemId, Enum.InfoType.Bundle)
							else
								price = getRegionalPriceForAsset(itemId, Enum.InfoType.Asset)
							end
							
							if price and price > 0 and reportEvent then
								local infoTypeName = "Asset"
								if itemType == Enum.MarketplaceProductType.AvatarBundle then
									infoTypeName = "Bundle"
								end
								reportEvent:FireServer(itemId, price, infoTypeName)
							else
								-- Report 0 so server knows the purchase happened
								if reportEvent then
									reportEvent:FireServer(itemId, 0, "BulkItem")
								end
							end
						end
					end
				end
			end
		else
			if status ~= Enum.MarketplaceBulkPurchasePromptStatus.Completed then
				print("Bulk purchase not completed - Status:", status)
			elseif not purchaseInfo then
				print("Bulk purchase completed but no purchase info provided")
			elseif not purchaseInfo.Items or typeof(purchaseInfo.Items) ~= "table" then
				print("Bulk purchase completed but items data is invalid:", typeof(purchaseInfo.Items))
			elseif not next(purchaseInfo.Items) then
				print("Bulk purchase completed but items table is empty")
			else
				local currentBulkEvent = bulkPurchaseReportEvent or ReplicatedStorage:FindFirstChild("UGC_ReportBulkPurchase")
				if not currentBulkEvent then
					print("Bulk purchase completed but bulkPurchaseReportEvent not available")
				else
					print("Bulk purchase completed but failed unknown validation")
				end
			end
		end
	end)
end

-- Optional helper; you can call this from any UI code if needed
local function promptGamePassPurchaseWithReporting(assetId: number)
	if typeof(assetId) ~= "number" then return end
	local price = getRegionalPriceForAsset(assetId, Enum.InfoType.GamePass)
	if reportEvent and price then
		reportEvent:FireServer(assetId, price, "GamePass")
	end
	MarketplaceService:PromptGamePassPurchase(LOCAL_PLAYER, assetId)
	-- Fire again after prompting to account for any dynamic updates
	task.defer(function()
		local postPrice = getRegionalPriceForAsset(assetId, Enum.InfoType.GamePass)
		if postPrice and reportEvent then
			reportEvent:FireServer(assetId, postPrice, "GamePass")
		end
	end)
end

_G.UGC_PromptGamePassPurchaseWithReporting = promptGamePassPurchaseWithReporting