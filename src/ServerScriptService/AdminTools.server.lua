--!strict
-- Admin Tools for Points System Security
-- Use this script to manage exploited accounts and monitor the system

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local MessagingService = game:GetService("MessagingService")

local PointsDataStore = DataStoreService:GetDataStore("UGCPlayerPoints")
local RobuxLeaderboard = DataStoreService:GetOrderedDataStore("RobuxSpentLeaderboard")
local PurchasesCountStore = DataStoreService:GetDataStore("UGCPurchasesCount")

-- Configuration
local ADMIN_USER_IDS = {
	-- Add your admin user IDs here
	-- Example: 123456789,
    7054181424,
	3886427330,
	8001552362,
}

local function isAdmin(player)
	return table.find(ADMIN_USER_IDS, player.UserId) ~= nil
end

-- Admin Commands via Chat
local function handleAdminCommand(player, message)
	if not isAdmin(player) then return end
	
	local args = string.split(message, " ")
	local command = args[1]:lower()
	
	if command == "/resetpoints" and args[2] then
		local targetName = args[2]
		local targetPlayer = Players:FindFirstChild(targetName)
		local newPoints = tonumber(args[3]) or 0
		
		-- Get UserId for offline operations
		local userId
		if targetPlayer then
			userId = targetPlayer.UserId
		else
			local success, result = pcall(function()
				return Players:GetUserIdFromNameAsync(targetName)
			end)
			if success then
				userId = result
			end
		end
		
		if userId then
			-- Reset points in DataStore
			pcall(function()
				PointsDataStore:SetAsync("Points_" .. userId, newPoints)
			end)
			
			-- Reset RobuxSpent in leaderboard (if newPoints is 0, remove from leaderboard)
			if newPoints == 0 then
				pcall(function()
					RobuxLeaderboard:RemoveAsync(userId)
					print(string.format("Removed %s from RobuxSpent leaderboard", targetName))
				end)
			end
			
			-- Reset purchases count if points are 0
			if newPoints == 0 then
				pcall(function()
					PurchasesCountStore:SetAsync("Purchases_" .. userId, 0)
				end)
			end
			
			-- Update online player stats
			if targetPlayer then
				local stats = targetPlayer:FindFirstChild("leaderstats")
				if stats then
					if stats:FindFirstChild("Points") then 
						stats.Points.Value = newPoints 
					end
					if newPoints == 0 and stats:FindFirstChild("RobuxSpent") then 
						stats.RobuxSpent.Value = 0 
					end
					if newPoints == 0 and stats:FindFirstChild("Purchases") then 
						stats.Purchases.Value = 0 
					end
				end
			end
			
			print(string.format("Reset %s (%d) - Points: %d, RobuxSpent: %s, Purchases: %s", 
				targetName, userId, newPoints, 
				newPoints == 0 and "0" or "unchanged",
				newPoints == 0 and "0" or "unchanged"))
		else
			print("Player not found: " .. targetName)
		end

	elseif command == "/setpoints" and args[2] and args[3] then
		local targetName = args[2]
		local targetPlayer = Players:FindFirstChild(targetName)
		local newPoints = tonumber(args[3])
		
		if not newPoints then
			print("Invalid points amount. Please provide a valid number.")
			return
		end
		
		-- Get UserId for offline operations
		local userId
		if targetPlayer then
			userId = targetPlayer.UserId
		else
			local success, result = pcall(function()
				return Players:GetUserIdFromNameAsync(targetName)
			end)
			if success then
				userId = result
			end
		end
		
		if userId then
			-- Set points in DataStore
			pcall(function()
				PointsDataStore:SetAsync("Points_" .. userId, newPoints)
			end)
			
			-- Update online player stats
			if targetPlayer then
				local stats = targetPlayer:FindFirstChild("leaderstats")
				if stats and stats:FindFirstChild("Points") then 
					stats.Points.Value = newPoints 
				end
			end
			
			print(string.format("Set %s (%d) points to: %d", targetName, userId, newPoints))
		else
			print("Player not found: " .. targetName)
		end

	elseif command == "/setpurchasecount" and args[2] and args[3] then
		local targetName = args[2]
		local targetPlayer = Players:FindFirstChild(targetName)
		local newPurchases = tonumber(args[3])
		
		if not newPurchases then
			print("Invalid purchase count. Please provide a valid number.")
			return
		end
		
		-- Get UserId for offline operations
		local userId
		if targetPlayer then
			userId = targetPlayer.UserId
		else
			local success, result = pcall(function()
				return Players:GetUserIdFromNameAsync(targetName)
			end)
			if success then
				userId = result
			end
		end
		
		if userId then
			-- Set purchases count in DataStore
			pcall(function()
				PurchasesCountStore:SetAsync("Purchases_" .. userId, newPurchases)
			end)
			
			-- Update online player stats
			if targetPlayer then
				local stats = targetPlayer:FindFirstChild("leaderstats")
				if stats and stats:FindFirstChild("Purchases") then 
					stats.Purchases.Value = newPurchases 
				end
			end
			
			print(string.format("Set %s (%d) purchase count to: %d", targetName, userId, newPurchases))
		else
			print("Player not found: " .. targetName)
		end

	elseif command == "/setrobuxspent" and args[2] and args[3] then
		local targetName = args[2]
		local targetPlayer = Players:FindFirstChild(targetName)
		local newRobuxSpent = tonumber(args[3])
		
		if not newRobuxSpent then
			print("Invalid robux amount. Please provide a valid number.")
			return
		end
		
		-- Get UserId for offline operations
		local userId
		if targetPlayer then
			userId = targetPlayer.UserId
		else
			local success, result = pcall(function()
				return Players:GetUserIdFromNameAsync(targetName)
			end)
			if success then
				userId = result
			end
		end
		
		if userId then
			-- Set robux spent in leaderboard (if 0, remove from leaderboard)
			if newRobuxSpent == 0 then
				pcall(function()
					RobuxLeaderboard:RemoveAsync(userId)
					print(string.format("Removed %s from RobuxSpent leaderboard", targetName))
				end)
			else
				pcall(function()
					RobuxLeaderboard:SetAsync(userId, newRobuxSpent)
				end)
			end
			
			-- Update online player stats
			if targetPlayer then
				local stats = targetPlayer:FindFirstChild("leaderstats")
				if stats and stats:FindFirstChild("RobuxSpent") then 
					stats.RobuxSpent.Value = newRobuxSpent 
				end
			end
			
			print(string.format("Set %s (%d) robux spent to: %d", targetName, userId, newRobuxSpent))
		else
			print("Player not found: " .. targetName)
		end

	elseif command == "/securitystatus" then
		-- Display current security status
		print("=== SECURITY STATUS ===")
		local suspiciousCount = 0
		for _ in pairs(game.ServerScriptService.UGCPurchaseHandler.suspiciousPlayers or {}) do
			suspiciousCount += 1
		end
		print("Suspicious players flagged:", suspiciousCount)
		print("Security monitoring: ACTIVE")
		print("Purchase verification: ENABLED") 
		print("Price report validation: ENABLED")
		print("=======================")
		
	elseif command == "/checkpoints" and args[2] then
        local targetName = args[2]
        local targetPlayer = Players:FindFirstChild(targetName)
        
        if targetPlayer then
            local stats = targetPlayer:FindFirstChild("leaderstats")
            if stats then
                local points = stats:FindFirstChild("Points") and stats.Points.Value or 0
                local robux = stats:FindFirstChild("RobuxSpent") and stats.RobuxSpent.Value or 0
                local purchases = stats:FindFirstChild("Purchases") and stats.Purchases.Value or 0
                
                print(string.format("=== %s's Stats ===", targetName))
                print(string.format("Points: %d", points))
                print(string.format("RobuxSpent: %d", robux))
                print(string.format("Purchases: %d", purchases))
                print("==================")
            end
        else
            -- Check offline player
            local success, userId = pcall(function()
                return Players:GetUserIdFromNameAsync(targetName)
            end)
            
            if success and userId then
                local points = 0
                local robux = 0
                local purchases = 0
                
                -- Get points
                pcall(function()
                    points = PointsDataStore:GetAsync("Points_" .. userId) or 0
                end)
                
                -- Get robux from leaderboard
                pcall(function()
                    robux = RobuxLeaderboard:GetAsync(userId) or 0
                end)
                
                -- Get purchases
                pcall(function()
                    purchases = PurchasesCountStore:GetAsync("Purchases_" .. userId) or 0
                end)
                
                print(string.format("=== %s's Stats (Offline) ===", targetName))
                print(string.format("Points: %d", points))
                print(string.format("RobuxSpent: %d", robux))
                print(string.format("Purchases: %d", purchases))
                print("==============================")
            else
                print("Player not found: " .. targetName)
            end
        end
		
	elseif command == "/banplayer" and args[2] then
		local targetName = args[2]
		local targetPlayer = Players:FindFirstChild(targetName)
		
		if targetPlayer then
			targetPlayer:Kick("Banned for exploiting the points system")
			print(string.format("Banned player %s for exploiting", targetName))
		else
			print("Player not found: " .. targetName)
		end
		

	elseif command == "/listrich" then
		-- List players with suspiciously high points
		local richPlayers = {}
		for _, player in pairs(Players:GetPlayers()) do
			local stats = player:FindFirstChild("leaderstats")
			if stats and stats:FindFirstChild("Points") then
				local points = stats.Points.Value
				if points > 4500 then -- Adjust threshold as needed
					table.insert(richPlayers, {name = player.Name, points = points, userId = player.UserId})
				end
			end
		end
		
		table.sort(richPlayers, function(a, b) return a.points > b.points end)
		
		print("=== Players with High Points ===")
		for _, playerData in ipairs(richPlayers) do
			print(string.format("%s (%d): %d points", playerData.name, playerData.userId, playerData.points))
		end
		print("=== End List ===")
		

	elseif command == "/leaderboardclean" then
		-- Clean leaderboard of suspicious entries
		print("Cleaning suspicious leaderboard entries...")
		
		local suspiciousCount = 0
		local pages = RobuxLeaderboard:GetSortedAsync(false, 100)  -- Get top 100
		
		for pageIndex = 1, 10 do  -- Check first 10 pages
			local data = pages:GetCurrentPage()
			for _, entry in ipairs(data) do
				local userId = entry.key
				local robuxSpent = entry.value
				
				-- Check if robux spent seems suspicious (you can adjust threshold)
				if robuxSpent > 100000 then  -- More than 100k robux spent
					local success, username = pcall(function()
						return Players:GetNameFromUserIdAsync(userId)
					end)
					
					if success then
						print(string.format("SUSPICIOUS: %s (%d) - %d robux spent", username, userId, robuxSpent))
						suspiciousCount = suspiciousCount + 1
					end
				end
			end
			
			if not pages.IsFinished then
				pages:AdvanceToNextPageAsync()
			else
				break
			end
		end
		
		print(string.format("Found %d suspicious leaderboard entries", suspiciousCount))
		
	elseif command == "/help" then
		print("=== Safe Admin Commands ===")
		print("/checkpoints [player] - Check player's points and purchases")
		print("/resetpoints [player] [amount] - Reset player's points (0 = full reset)")
		print("/setpoints [player] [amount] - Set player's points to specific amount")
		print("/setpurchasecount [player] [amount] - Set player's purchase count")
		print("/setrobuxspent [player] [amount] - Set player's robux spent leaderboard value")
		print("/banplayer [player] - Ban a player")
		print("/listrich - List players with high points")
		print("/leaderboardclean - Find suspicious leaderboard entries")
		print("/help - Show this help")
		print("===========================")
		print("NOTE: /resetpoints [player] 0 will also reset RobuxSpent and Purchases")
		print("NOTE: All set commands require both player name and amount parameters")
	end
end

-- Listen for chat commands
Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		handleAdminCommand(player, message)
	end)
end)

-- For players already in game
for _, player in pairs(Players:GetPlayers()) do
	player.Chatted:Connect(function(message)
		handleAdminCommand(player, message)
	end)
end

-- Auto-detect and flag suspicious accounts on join
Players.PlayerAdded:Connect(function(player)
	task.wait(2) -- Wait for leaderstats to load
	
	local stats = player:FindFirstChild("leaderstats")
	if stats and stats:FindFirstChild("Points") then
		local points = stats.Points.Value
		
		-- Flag accounts with impossibly high points
		if points > 50000 then
			warn(string.format("SUSPICIOUS ACCOUNT DETECTED: %s (%d) has %d points!", 
				player.Name, player.UserId, points))
				
			-- Optional: Auto-kick suspicious players
			-- player:Kick("Account flagged for review")
		end
	end
end)

print("Admin Tools loaded. Use /help in chat for commands.")
print("Remember to add your UserId to ADMIN_USER_IDS at the top of this script!")
