--!strict

--[[
	TryOn - This script handles the main try on functionality. When a player requests to try items on,
	their current appearance is loaded, modified with the items being tried on, and then re-applied
	to their character.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Settings = require(ReplicatedStorage.Settings)
local applyItemsToDescriptionAsync = require(ReplicatedStorage.Utility.applyItemsToDescriptionAsync)
local validateSimpleTable = require(ServerScriptService.Utility.TypeValidation.validateSimpleTable)
local validateNumber = require(ServerScriptService.Utility.TypeValidation.validateNumber)

local remotes = ReplicatedStorage.Remotes
local tryOnRemote = remotes.TryOn

local latestTryOn: { [Player]: { assets: { number }, bundles: { number } } } = {}

local function tryOnItems(player: Player, assets: { number }, bundles: { number })
	-- Make sure the player has a valid character
	if not player.Character then
		return
	end
	local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	-- Load the player's current outfit, equip the items being tried on, then apply back to their character
	local description = Players:GetHumanoidDescriptionFromUserId(player.CharacterAppearanceId)
	applyItemsToDescriptionAsync(description, assets, bundles, true)
	humanoid:ApplyDescription(description, Enum.AssetTypeVerification.Always)
end

local function onCharacterAddedAsync(character: Model)
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	if not player:HasAppearanceLoaded() then
		player.CharacterAppearanceLoaded:Wait()
	end

	local items = latestTryOn[player]
	if not items then
		return
	end

	tryOnItems(player, items.assets, items.bundles)
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(onCharacterAddedAsync)

	if player.Character then
		task.spawn(onCharacterAddedAsync, player.Character)
	end
end

local function onPlayerRemoving(player: Player)
	-- Make sure we're not leaking memory when players leave
	if latestTryOn[player] then
		latestTryOn[player] = nil
	end
end

local function onTryOnEvent(player: Player, assets: { number }, bundles: { number })
	-- Validate that the arrays of assets and bundles are formatted correctly
	if not validateSimpleTable(assets, "number", validateNumber) then
		return
	end
	if not validateSimpleTable(bundles, "number", validateNumber) then
		return
	end

	-- Make sure the player is not able to try on more than the maximum allowed items
	if #assets + #bundles > Settings.MAX_TRY_ON_ITEMS then
		return
	end

	-- Store these as the latest items the player has tried on
	latestTryOn[player] = {
		assets = assets,
		bundles = bundles,
	}

	tryOnItems(player, assets, bundles)
end

local function initialize()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	tryOnRemote.OnServerEvent:Connect(onTryOnEvent)
end

initialize()
