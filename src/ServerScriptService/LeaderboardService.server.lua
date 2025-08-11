local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local RobuxLeaderboard = DataStoreService:GetOrderedDataStore("RobuxSpentLeaderboard")

-- Ensure RemoteFunction exists
local getLeaderboard = ReplicatedStorage:FindFirstChild("GetLeaderboardData")
if not getLeaderboard then
	getLeaderboard = Instance.new("RemoteFunction")
	getLeaderboard.Name = "GetLeaderboardData"
	getLeaderboard.Parent = ReplicatedStorage
end

-- Simple username cache
local userIdToNameCache: {[number]: string} = {}

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
		local username = userIdToNameCache[userId]

		if not username then
			local successName, name = pcall(function()
				return game.Players:GetNameFromUserIdAsync(userId)
			end)
			if successName and name then
				username = name
				userIdToNameCache[userId] = name
			else
				username = "[Unknown]"
			end
		end

		table.insert(result, { rank = i, name = username, value = robux, userid = userId })
	end

	return result
end
