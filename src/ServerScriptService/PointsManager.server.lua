local DataStoreService = game:GetService("DataStoreService")
local PointsDataStore = DataStoreService:GetDataStore("UGCPlayerPoints")

game.Players.PlayerAdded:Connect(function(player)
	local points = 0

	-- Load existing data
	local success, result = pcall(function()
		return PointsDataStore:GetAsync("Points_" .. player.UserId)
	end)

	if success and result then
		points = result
	end

	-- Store value in leaderstats
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"
	folder.Parent = player

	local pointsValue = Instance.new("IntValue")
	pointsValue.Name = "Points"
	pointsValue.Value = points
	pointsValue.Parent = folder
end)

game.Players.PlayerRemoving:Connect(function(player)
	local points = player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Points")
	if points then
		pcall(function()
			PointsDataStore:SetAsync("Points_" .. player.UserId, points.Value)
		end)
	end
end)
