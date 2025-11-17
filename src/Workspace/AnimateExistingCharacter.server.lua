--!strict
--[[
	Animate Existing Character Script
	Use this for characters that already have a Humanoid
	Place this as a child of your existing character model
]]

local character = script.Parent
local humanoid = character:FindFirstChildOfClass("Humanoid")

if not humanoid then
	warn("No Humanoid found in", character.Name)
	return
end

-- Find or create Animator
local animator = humanoid:FindFirstChildOfClass("Animator")
if not animator then
	animator = Instance.new("Animator")
	animator.Parent = humanoid
end

-- Default Roblox R15 Animation IDs (these always work and are free)
local WAVE = "rbxassetid://507770239"
local DANCE = "rbxassetid://507771019"
local DANCE2 = "rbxassetid://507776043"
local DANCE3 = "rbxassetid://507777268"
local LAUGH = "rbxassetid://507770818"
local CHEER = "rbxassetid://507770677"
local POINT = "rbxassetid://507770453"
local FLYING = "rbxassetid://139058906415119"

-- Choose which animation to play
local chosenAnimation = WAVE

-- Create and play the animation
local animation = Instance.new("Animation")
animation.AnimationId = chosenAnimation
animation.Parent = character

local success, animTrack = pcall(function()
	return animator:LoadAnimation(animation)
end)

if success and animTrack then
	animTrack.Looped = true
	animTrack:Play()
	print("✓ Playing animation on", character.Name)
else
	warn("Failed to load animation on", character.Name)
end

-- Anchor the character so it doesn't fall
local rootPart = character:FindFirstChild("HumanoidRootPart")
if rootPart and rootPart:IsA("BasePart") then
	rootPart.Anchored = true
end

