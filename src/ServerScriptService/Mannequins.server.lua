--!strict

--[[
	Mannequins - This script handles loading in mannequin appearances. Mannequins have a list of accessory and bundle IDs
	set as attributes, which are used to customize the mannequin appearance.

	To create a mannequin rig, a new HumanoidDescription is created, the bundles and accessories are applied, and then
	Players:CreateHumanoidModelFromDescription() is used for the final creation.
--]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Constants = require(ReplicatedStorage.Constants)
local applyItemsToDescriptionAsync = require(ReplicatedStorage.Utility.applyItemsToDescriptionAsync)
local setDescriptionSkinColor = require(ReplicatedStorage.Utility.setDescriptionSkinColor)
local stringOfNumbersToArray = require(ReplicatedStorage.Utility.stringOfNumbersToArray)

type MannequinRig = Model & {
	Humanoid: Humanoid & {
		BodyDepthScale: NumberValue,
		BodyHeightScale: NumberValue,
		BodyProportionScale: NumberValue,
		BodyTypeScale: NumberValue,
		BodyWidthScale: NumberValue,
		HeadScale: NumberValue,
		Animator: Animator,
	},
	HumanoidRootPart: BasePart,
}

local function setupMannequinAsync(mannequin: Instance)
	local base = mannequin:FindFirstChild("Base")
	assert(base and base:IsA("BasePart"), `{mannequin:GetFullName()} is missing a Base`)

	-- Get the list of accessories, bundles, and skin color to apply to the mannequin
	local accessoryIdsString = mannequin:GetAttribute(Constants.ACCESSORY_IDS_ATTRIBUTE)
	local bundleIdsString = mannequin:GetAttribute(Constants.BUNDLE_IDS_ATTRIBUTE)
	local skinColor = mannequin:GetAttribute(Constants.SKIN_COLOR_ATTRIBUTE)

	-- Convert the accessory and bundle ID strings into arrays
	local accessoryIds = stringOfNumbersToArray(accessoryIdsString)
	local bundleIds = stringOfNumbersToArray(bundleIdsString)

	-- Create a new HumanoidDescription and apply the skin color, accessories, and bundles to it
	local description = Instance.new("HumanoidDescription")
	setDescriptionSkinColor(description, skinColor)
	applyItemsToDescriptionAsync(description, accessoryIds, bundleIds, true)

	-- Create a new rig from the HumanoidDescription we just created
	local rig = Players:CreateHumanoidModelFromDescription(
		description,
		Enum.HumanoidRigType.R15,
		Enum.AssetTypeVerification.Always
	) :: MannequinRig

	-- This rig includes an animation script by default, which we need to remove
	for _, descendant in rig:GetDescendants() do
		if descendant:IsA("Script") then
			descendant:Destroy()
		end
	end

	-- Disable name/health display for the rig and anchor its root part so it doesn't move around
	rig.Name = "Rig"
	rig.Humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	rig.Humanoid.BodyTypeScale.Value = mannequin:GetAttribute(Constants.BODY_TYPE_SCALE_ATTRIBUTE) or 1
	rig.Humanoid.BodyDepthScale.Value = mannequin:GetAttribute(Constants.BODY_DEPTH_SCALE_ATTRIBUTE) or 1
	rig.Humanoid.BodyHeightScale.Value = mannequin:GetAttribute(Constants.BODY_HEIGHT_SCALE_ATTRIBUTE) or 1
	rig.Humanoid.BodyWidthScale.Value = mannequin:GetAttribute(Constants.BODY_WIDTH_SCALE_ATTRIBUTE) or 1
	rig.Humanoid.BodyProportionScale.Value = mannequin:GetAttribute(Constants.BODY_PROPORTION_SCALE_ATTRIBUTE) or 1
	rig.Humanoid.HeadScale.Value = mannequin:GetAttribute(Constants.HEAD_SCALE_ATTRIBUTE) or 1
	rig.HumanoidRootPart.Anchored = true
	rig.Parent = mannequin

	-- Calculate the hip height and move the rig into place
	local height = rig.Humanoid.HipHeight + rig.HumanoidRootPart.Size.Y * 0.5
	rig:PivotTo(base.CFrame * CFrame.new(0, height, 0))

	-- Play the pose animation if one is set
	local poseAnimationId = mannequin:GetAttribute(Constants.POSE_ANIMATION_ATTRIBUTE)
	if poseAnimationId then
		local animation = Instance.new("Animation")
		animation.Name = "PoseAnimation"
		animation.AnimationId = poseAnimationId
		animation.Parent = rig

		local animationTrack = rig.Humanoid.Animator:LoadAnimation(animation)
		animationTrack:Play()
	end

	-- Remove the placeholder mannequin if there is one
	local placeholder = mannequin:FindFirstChild("Placeholder")
	if placeholder then
		placeholder:Destroy()
	end
end

local function initialize()
	CollectionService:GetInstanceAddedSignal(Constants.MANNEQUIN_TAG):Connect(setupMannequinAsync)

	for _, mannequin in CollectionService:GetTagged(Constants.MANNEQUIN_TAG) do
		setupMannequinAsync(mannequin)
	end
end

initialize()
