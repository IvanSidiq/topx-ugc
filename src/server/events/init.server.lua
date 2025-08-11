-- Server Events Initialization
-- This script sets up all RemoteEvent and RemoteFunction handlers

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import event handlers
local PlayerEvents = require(script.Parent.PlayerEvents)
local GameEvents = require(script.Parent.GameEvents)

-- Create RemoteEvents and RemoteFunctions folders if they don't exist
local function createRemoteObjects()
    local remotesFolder = ReplicatedStorage:FindFirstChild("RemoteEvents")
    if not remotesFolder then
        remotesFolder = Instance.new("Folder")
        remotesFolder.Name = "RemoteEvents"
        remotesFolder.Parent = ReplicatedStorage
    end
    
    local functionsFolder = ReplicatedStorage:FindFirstChild("RemoteFunctions")
    if not functionsFolder then
        functionsFolder = Instance.new("Folder")
        functionsFolder.Name = "RemoteFunctions"
        functionsFolder.Parent = ReplicatedStorage
    end
    
    return remotesFolder, functionsFolder
end

-- Initialize all event handlers
local function initializeEvents()
    local remotesFolder, functionsFolder = createRemoteObjects()
    
    -- Initialize player events
    PlayerEvents.init(remotesFolder, functionsFolder)
    
    -- Initialize game events
    GameEvents.init(remotesFolder, functionsFolder)
    
    print("All server events initialized")
end

-- Start initialization
initializeEvents() 