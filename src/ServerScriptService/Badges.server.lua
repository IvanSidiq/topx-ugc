--!strict

local Players = game:GetService("Players")
local BadgeService = game:GetService("BadgeService")

-- Configure your milestones here: each entry needs a threshold and corresponding badgeId
-- Example:
-- local BADGE_MILESTONES = {
-- 	{ threshold = 100, badgeId = 123456 },
-- 	{ threshold = 1000, badgeId = 789012 },
-- }
local BADGE_MILESTONES: { { threshold: number, badgeId: number } } = {}

local function tryAwardBadge(player: Player, badgeId: number)
	local hasBadge = false
	local okCheck, errCheck = pcall(function()
		hasBadge = BadgeService:UserHasBadgeAsync(player.UserId, badgeId)
	end)
	if not okCheck then
		warn("Badge check failed:", errCheck)
		return
	end
	if hasBadge then
		return
	end
	pcall(function()
		BadgeService:AwardBadge(player.UserId, badgeId)
	end)
end

local function onPointsChanged(player: Player, newValue: number)
	if #BADGE_MILESTONES == 0 then
		return
	end
	for _, entry in ipairs(BADGE_MILESTONES) do
		if newValue >= entry.threshold then
			tryAwardBadge(player, entry.badgeId)
		end
	end
end

local function hookPlayer(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		player.ChildAdded:Connect(function(child)
			if child.Name == "leaderstats" then
				local points = child:WaitForChild("Points", 10)
				if points and points:IsA("IntValue") then
					points.Changed:Connect(function()
						onPointsChanged(player, points.Value)
					end)
					-- initial check
					onPointsChanged(player, points.Value)
				end
			end
		end)
		return
	end
	local points = leaderstats:FindFirstChild("Points")
	if points and points:IsA("IntValue") then
		points.Changed:Connect(function()
			onPointsChanged(player, points.Value)
		end)
		-- initial check
		onPointsChanged(player, points.Value)
	end
end

Players.PlayerAdded:Connect(hookPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	hookPlayer(player)
end 