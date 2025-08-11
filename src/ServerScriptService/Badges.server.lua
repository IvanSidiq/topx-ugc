--!strict

local Players = game:GetService("Players")
local BadgeService = game:GetService("BadgeService")

-- Purchases-based milestones
local BADGE_MILESTONES: { { threshold: number, badgeId: number } } = {
	{ threshold = 1, badgeId = 2129060302556121 }, -- New Collector
	{ threshold = 5, badgeId = 139176286833309 }, -- Regular Customer
	{ threshold = 10, badgeId = 2822683770878813 }, -- True Fan
	{ threshold = 25, badgeId = 1553181686929842 }, -- Super Supporter
	{ threshold = 50, badgeId = 507465820821322 }, -- Legendary Patron
}

table.sort(BADGE_MILESTONES, function(a, b)
	return a.threshold < b.threshold
end)

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

local function onPurchasesChanged(player: Player, newValue: number)
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
	local function connectPurchases(container: Instance)
		local purchases = container:WaitForChild("Purchases", 10)
		if purchases and purchases:IsA("IntValue") then
			purchases.Changed:Connect(function()
				onPurchasesChanged(player, purchases.Value)
			end)
			-- initial check
			onPurchasesChanged(player, purchases.Value)
		end
	end

	if not leaderstats then
		player.ChildAdded:Connect(function(child)
			if child.Name == "leaderstats" then
				connectPurchases(child)
			end
		end)
		return
	end
	connectPurchases(leaderstats)
end

Players.PlayerAdded:Connect(hookPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	hookPlayer(player)
end 