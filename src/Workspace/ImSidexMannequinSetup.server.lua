--!strict
--[[
	ImSidex Mannequin Setup Script
	Place this script as a child of the ImSidex mannequin in Workspace
	
	SETUP INSTRUCTIONS:
	1. Make sure ImSidex has a Part child named "Base" for positioning
	2. This script will set up the animation attribute
	3. After running, manually add the "Mannequin" tag in Studio via CollectionService
]]

local CollectionService = game:GetService("CollectionService")

-- Get the mannequin (parent of this script)
local mannequin = script.Parent

-- Check for Base part 
local base = mannequin:FindFirstChild("Base")
if not base then
	warn(mannequin.Name, "is missing a 'Base' BasePart! Creating one...")
	base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(2, 0.2, 2)
	base.Anchored = true
	base.Transparency = 0.5
	base.BrickColor = BrickColor.new("Bright green")
	base.Parent = mannequin
	print("✓ Created Base part for", mannequin.Name)
end

-- Default Roblox R15 Animation IDs (these always work and are free)
local WAVE = "rbxassetid://507770239"          -- Friendly wave
local DANCE = "rbxassetid://507771019"         -- Dance animation
local DANCE2 = "rbxassetid://507776043"        -- Dance animation 2
local DANCE3 = "rbxassetid://507777268"        -- Dance animation 3
local LAUGH = "rbxassetid://507770818"         -- Laughing animation
local CHEER = "rbxassetid://507770677"         -- Cheering animation
local POINT = "rbxassetid://507770453"         -- Pointing animation

-- Set the animation (change this variable to use a different animation)
-- Wave is closest to a nodding/greeting motion
local chosenAnimation = WAVE

-- Set the animation attribute
mannequin:SetAttribute("poseAnimation", chosenAnimation)
print("✓ Set animation for", mannequin.Name, "to:", chosenAnimation)

print("")
print("═══════════════════════════════════════")
print("MANUAL SETUP REQUIRED:")
print("═══════════════════════════════════════")
print("1. Select the '" .. mannequin.Name .. "' mannequin in Workspace")
print("2. In Properties, add these String attributes:")
print("   • accessoryIds (leave empty or add IDs like: 1234567,8901234)")
print("   • bundleIds (leave empty or add IDs like: 5678901)")
print("3. Open View → CollectionService")
print("4. Add the tag: Mannequin")
print("5. The mannequin should appear with the wave animation!")
print("═══════════════════════════════════════")
print("")
print("To change animations, edit line 45 in this script")
print("Available: WAVE, DANCE, DANCE2, DANCE3, LAUGH, CHEER, POINT")

