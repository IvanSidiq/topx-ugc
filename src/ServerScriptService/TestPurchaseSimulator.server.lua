--!strict

local Players = game:GetService("Players")

local ServerScriptService = game:GetService("ServerScriptService")
local TestMode = require(ServerScriptService.Utility.TestMode)
local TestStore = require(ServerScriptService.Utility.TestStore)

-- Enable/disable the simulator
local ENABLED = false

local function randomRobuxAmount(): number
	local amounts = {25, 50, 75, 100, 200}
	return amounts[math.random(1, #amounts)]
end

local function simulatePurchaseFor(player: Player)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end
	local points = leaderstats:FindFirstChild("Points")
	local spent = leaderstats:FindFirstChild("RobuxSpent")
	if not points or not spent then return end

	local robux = randomRobuxAmount()
	points.Value += robux
	spent.Value += robux
	-- also update in-memory leaderboard so UI shows entries in Studio
	TestStore.addSpend(player.UserId, robux)
end

if ENABLED and TestMode then
	task.spawn(function()
		while true do
			local list = Players:GetPlayers()
			if #list > 0 then
				local target = list[math.random(1, #list)]
				simulatePurchaseFor(target)
			end
			task.wait(8)
		end
	end)
end 