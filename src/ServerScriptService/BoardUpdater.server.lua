local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local TestMode = require(script.Parent.Utility.TestMode)
local TestStore = require(script.Parent.Utility.TestStore)

local RobuxLeaderboard = DataStoreService:GetOrderedDataStore("RobuxSpentLeaderboard")

local boardPart = Workspace:FindFirstChild("LeaderboardBoard")
if not boardPart then
	warn("LeaderboardBoard not found in Workspace")
	return
end

local gui = boardPart:FindFirstChild("LeaderboardDisplay")
if not gui then
	warn("LeaderboardDisplay not found under LeaderboardBoard")
	return
end

local countdownLabel = gui:FindFirstChild("CountdownLabel")

local function clearRows()
	for _, child in pairs(gui:GetChildren()) do
		if child:IsA("TextLabel") and child.Name ~= "TitleLabel" and child.Name ~= "CountdownLabel" then
			child:Destroy()
		end
		if child:IsA("ImageLabel") and child.Name == "Avatar" then
			child:Destroy()
		end
	end
end

local function resolvePedestalCFrame(index: number): CFrame?
	local inst = Workspace:FindFirstChild("Pedestal"..index)
	if not inst then return nil end
	if inst:IsA("BasePart") then
		return inst.CFrame
	end
	if inst:IsA("Model") then
		local base = inst.PrimaryPart or inst:FindFirstChildWhichIsA("BasePart")
		if base then
			return base.CFrame
		end
	end
	return nil
end

local function fetchTopPlayers(maxCount: number)
	if TestMode then
		local entries = TestStore.getTopSpenders(maxCount)
		local results = {}
		for i, e in ipairs(entries) do
			local name = "[Unknown]"
			local ok, gotName = pcall(function()
				return Players:GetNameFromUserIdAsync(e.userId)
			end)
			if ok and gotName then name = gotName end
			results[i] = { rank = i, name = name, value = e.spent, userid = e.userId }
		end
		return results
	end

	local success, pages = pcall(function()
		return RobuxLeaderboard:GetSortedAsync(false, maxCount)
	end)
	if not success or not pages then
		return {}
	end

	local current = pages:GetCurrentPage()
	local results = {}
	for i, entry in ipairs(current) do
		local userId = entry.key
		local value = entry.value
		local name = "[Unknown]"
		local ok, gotName = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		if ok and gotName then
			name = gotName
		end
		results[i] = { rank = i, name = name, value = value, userid = userId }
	end
	return results
end

local function destroyOldRigs()
	for i = 1, 3 do
		local old = Workspace:FindFirstChild("TopSpenderRig_"..i)
		if old and old:IsA("Model") then
			old:Destroy()
		end
	end
end

local function createRigForUser(userId: number): Model?
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromUserId(userId)
	end)
	if not ok or not rig then
		return nil
	end
	for _, d in ipairs(rig:GetDescendants()) do
		if d:IsA("Script") then
			d:Destroy()
		end
	end
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	return rig
end

local function updateTopMannequins(topPlayers)
	destroyOldRigs()
	for i = 1, math.min(3, #topPlayers) do
		local data = topPlayers[i]
		local baseCFrame = resolvePedestalCFrame(i)
		if baseCFrame then
			local rig = createRigForUser(tonumber(data.userid) or 0)
			if rig then
				rig.Name = "TopSpenderRig_"..i
				rig.Parent = Workspace
				local hrp = rig:FindFirstChild("HumanoidRootPart")
				if rig.PrimaryPart == nil and hrp and hrp:IsA("BasePart") then
					rig.PrimaryPart = hrp
				end
				if rig.PrimaryPart then
					rig:PivotTo(baseCFrame * CFrame.new(0, 4, 0))
					-- anchor so the rig stays on the pedestal
					local part = rig.PrimaryPart
					if part then
						part.Anchored = true
					end
				end
				local animator = rig:FindFirstChildOfClass("Animator")
				if not animator then
					local hum = rig:FindFirstChildOfClass("Humanoid")
					if hum then
						animator = hum:FindFirstChildOfClass("Animator")
					end
				end
				if animator then
					local danceAnim = Instance.new("Animation")
					danceAnim.AnimationId = "rbxassetid://507771019"
					local track = animator:LoadAnimation(danceAnim)
					track:Play()
				end
			end
		end
	end
end

local function updateLeaderboard()
	clearRows()
	local topPlayers = fetchTopPlayers(10)

	for i, data in ipairs(topPlayers) do
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(0.7, 0, 0.07, 0)
		label.Position = UDim2.new(0.3, 0, 0.1 + (i - 1) * 0.08, 0)
		label.BackgroundTransparency = 1
		label.TextScaled = true
		label.TextColor3 = Color3.new(1, 1, 1)
		label.Font = Enum.Font.Gotham
		label.Text = string.format("%d. %s - %d R$", data.rank, data.name, data.value)
		label.Parent = gui

		local avatar = Instance.new("ImageLabel")
		avatar.Name = "Avatar"
		avatar.Size = UDim2.new(0.08, 0, 0.07, 0)
		avatar.Position = UDim2.new(0.2, 0, label.Position.Y.Scale, 0)
		avatar.BackgroundTransparency = 1
		avatar.Image = string.format("https://www.roblox.com/headshot-thumbnail/image?userId=%s&width=100&height=100&format=png", data.userid or 1)
		avatar.Parent = gui
	end

	updateTopMannequins(topPlayers)
end

coroutine.wrap(function()
	while true do
		updateLeaderboard()
		for i = 60, 1, -1 do
			if countdownLabel and countdownLabel:IsA("TextLabel") then
				countdownLabel.Text = "Refreshing in " .. i .. "s"
			end
			task.wait(1)
		end
	end
end)()
