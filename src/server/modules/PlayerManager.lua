-- PlayerManager Module
-- Handles player data, joining/leaving events, and player-related functionality

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import shared modules
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local PlayerManager = {}

-- Player data storage
local playerData = {}

-- Initialize the PlayerManager
function PlayerManager.init()
    print("PlayerManager initialized")
    
    -- Connect player events
    Players.PlayerAdded:Connect(PlayerManager.onPlayerAdded)
    Players.PlayerRemoving:Connect(PlayerManager.onPlayerRemoving)
end

-- Handle player joining
function PlayerManager.onPlayerAdded(player)
    print(player.Name .. " joined the game!")
    
    -- Initialize player data
    playerData[player] = {
        joinTime = tick(),
        stats = {
            level = 1,
            experience = 0,
            coins = 100
        }
    }
    
    -- Setup player character
    PlayerManager.setupPlayerCharacter(player)
    
    -- Load player data (if you have a data store)
    -- PlayerManager.loadPlayerData(player)
end

-- Handle player leaving
function PlayerManager.onPlayerRemoving(player)
    print(player.Name .. " left the game!")
    
    -- Save player data (if you have a data store)
    -- PlayerManager.savePlayerData(player)
    
    -- Clean up player data
    if playerData[player] then
        playerData[player] = nil
    end
end

-- Setup player character when they spawn
function PlayerManager.setupPlayerCharacter(player)
    local function onCharacterAdded(character)
        local humanoid = character:WaitForChild("Humanoid")
        
        -- Set player properties from config
        humanoid.WalkSpeed = GameConfig.DEFAULT_WALKSPEED
        humanoid.JumpPower = GameConfig.DEFAULT_JUMPPOWER
        
        print(player.Name .. " character spawned")
    end
    
    -- Connect to current and future characters
    if player.Character then
        onCharacterAdded(player.Character)
    end
    player.CharacterAdded:Connect(onCharacterAdded)
end

-- Get player data
function PlayerManager.getPlayerData(player)
    return playerData[player]
end

-- Update player stats
function PlayerManager.updatePlayerStats(player, statName, value)
    if playerData[player] and playerData[player].stats[statName] then
        playerData[player].stats[statName] = value
        return true
    end
    return false
end

-- Get all online players' data
function PlayerManager.getAllPlayerData()
    return playerData
end

return PlayerManager 