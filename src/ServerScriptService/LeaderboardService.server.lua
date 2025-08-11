local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RobuxLeaderboard = DataStoreService:GetOrderedDataStore("RobuxSpentLeaderboard")

local getLeaderboard = ReplicatedStorage:WaitForChild("GetLeaderboardData")

getLeaderboard.OnServerInvoke = function()
	local success, pages = pcall(function()
		return RobuxLeaderboard:GetSortedAsync(false, 10)
	end)

	if not success or not pages then
		return {}
	end

	local topPlayers = pages:GetCurrentPage()
	local result = {}

	for i, entry in ipairs(topPlayers) do
		local userId = entry.key
		local robux = entry.value
		local username = "[Unknown]"

		-- Try to get username
		local successName, name = pcall(function()
			return game.Players:GetNameFromUserIdAsync(userId)
		end)

		if successName then
			username = name
		end

		table.insert(result, { rank = i, name = username, value = robux, userid = userId })
	end

	return result
end
