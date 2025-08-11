local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local getLeaderboard = ReplicatedStorage:WaitForChild("GetLeaderboardData")

local boardPart = Workspace:WaitForChild("LeaderboardBoard")
local gui = boardPart:WaitForChild("LeaderboardDisplay")
local countdownLabel = gui:WaitForChild("CountdownLabel")

-- Clear text rows before updating
local function clearRows()
	for _, child in pairs(gui:GetChildren()) do
		if child:IsA("TextLabel") and child.Name ~= "TitleLabel" and child.Name ~= "CountdownLabel" then
			child:Destroy()
		end
	end
end

-- Create rows + image avatars
local function updateLeaderboard()
	clearRows()
	local topPlayers = getLeaderboard:InvokeServer()

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

		-- Avatar Image
		local avatar = Instance.new("ImageLabel")
		avatar.Name = "Avatar"
		avatar.Size = UDim2.new(0.08, 0, 0.07, 0)
		avatar.Position = UDim2.new(0.2, 0, label.Position.Y.Scale, 0)
		avatar.BackgroundTransparency = 1
		avatar.Image = string.format("https://www.roblox.com/headshot-thumbnail/image?userId=%s&width=100&height=100&format=png", data.userid or 1)
		avatar.Parent = gui
	end
end

-- Auto refresh every 60s
task.spawn(function()
	while true do
		updateLeaderboard()
		for i = 60, 1, -1 do
			countdownLabel.Text = "Refreshing in " .. i .. "s"
			task.wait(1)
		end
	end
end)


local ServerStorage = game:GetService("ServerStorage")
local pedestalCount = 5

-- Clear previous mannequins
for i = 1, pedestalCount do
	local old = Workspace:FindFirstChild("Mannequin_"..i)
	if old then old:Destroy() end
end

for i, data in ipairs(topPlayers) do
	if i > pedestalCount then break end

	local mannequin = ServerStorage:FindFirstChild("MannequinTemplate"):Clone()
	mannequin.Name = "Mannequin_"..i
	local pedestal = Workspace:FindFirstChild("Pedestal"..i)
	if pedestal then
		mannequin:SetPrimaryPartCFrame(pedestal.CFrame + Vector3.new(0, 3, 0))
		mannequin.Parent = Workspace
	end

	-- Add dance animation
	local animator = mannequin:FindFirstChildWhichIsA("Humanoid"):FindFirstChild("Animator")
	if animator then
		local danceAnim = Instance.new("Animation")
		danceAnim.AnimationId = "rbxassetid://507771019" -- Dance Animation
		local track = animator:LoadAnimation(danceAnim)
		track:Play()
	end
end
