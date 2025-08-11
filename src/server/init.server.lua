-- Main Server Script
print("Server starting up...")

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import modules
local PlayerManager = require(script.modules.PlayerManager)

-- Initialize server modules
local function initializeServer()
    -- Initialize player management
    PlayerManager.init()
    
    -- Initialize events (this will be handled by events/init.server.lua)
    -- The events init script will run automatically due to Rojo structure
    
    print("Server modules initialized")
end

-- Legacy player events (keep for backward compatibility)
local function onPlayerAdded(player)
    print(player.Name .. " joined the game!")
    -- Additional legacy logic can go here
end

local function onPlayerRemoving(player)
    print(player.Name .. " left the game!")
    -- Additional legacy logic can go here
end

-- Start server initialization
initializeServer()

-- Connect legacy events (these can be removed once PlayerManager is fully integrated)
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

print("Server setup complete!") 