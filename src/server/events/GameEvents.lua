-- Game Events Handler
-- Handles all RemoteEvents and RemoteFunctions related to game mechanics

local GameEvents = {}

-- Initialize game events
function GameEvents.init(remotesFolder, functionsFolder)
    -- Create game-related RemoteEvents
    local gameStateChanged = Instance.new("RemoteEvent")
    gameStateChanged.Name = "GameStateChanged"
    gameStateChanged.Parent = remotesFolder
    
    local requestGameInfo = Instance.new("RemoteFunction")
    requestGameInfo.Name = "RequestGameInfo"
    requestGameInfo.Parent = functionsFolder
    
    -- Set up event handlers
    GameEvents.setupEventHandlers(gameStateChanged, requestGameInfo)
    
    print("GameEvents initialized")
end

-- Setup all event handlers
function GameEvents.setupEventHandlers(gameStateChanged, requestGameInfo)
    -- Handle game info requests
    requestGameInfo.OnServerInvoke = function(player)
        return GameEvents.getGameInfoForClient(player)
    end
    
    -- Add more game-related event handlers here
end

-- Get game info formatted for client
function GameEvents.getGameInfoForClient(player)
    return {
        gameMode = "Adventure",
        currentLevel = "Level1",
        playersOnline = #game:GetService("Players"):GetPlayers(),
        serverUptime = tick()
    }
end

-- Fire game state changed event to all clients
function GameEvents.fireGameStateChanged(newState)
    local gameStateChanged = game:GetService("ReplicatedStorage").RemoteEvents.GameStateChanged
    gameStateChanged:FireAllClients(newState)
end

return GameEvents 