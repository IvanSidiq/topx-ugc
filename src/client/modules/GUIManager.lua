-- GUIManager Module
-- Manages all client-side GUI interactions and state

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

-- Get player references
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Import shared modules
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local GUIManager = {}

-- GUI state tracking
local activeGUIs = {}
local guiStates = {}

-- Initialize the GUI Manager
function GUIManager.init()
    print("GUIManager initialized")
    
    -- Setup input handling
    GUIManager.setupInputHandling()
    
    -- Connect to server events
    GUIManager.connectServerEvents()
end

-- Setup input handling for GUI shortcuts
function GUIManager.setupInputHandling()
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        -- Example: ESC key to close all GUIs
        if input.KeyCode == Enum.KeyCode.Escape then
            GUIManager.closeAllGUIs()
        end
        
        -- Add more input shortcuts here
    end)
end

-- Connect to server events for GUI updates
function GUIManager.connectServerEvents()
    -- Wait for RemoteEvents to be created
    local function waitForRemoteEvents()
        local remotesFolder = ReplicatedStorage:WaitForChild("RemoteEvents", 10)
        if remotesFolder then
            -- Connect to player data changes
            local playerDataChanged = remotesFolder:WaitForChild("PlayerDataChanged", 5)
            if playerDataChanged then
                playerDataChanged.OnClientEvent:Connect(GUIManager.onPlayerDataChanged)
            end
        end
    end
    
    -- Wait for server to set up remotes
    spawn(waitForRemoteEvents)
end

-- Handle player data changes from server
function GUIManager.onPlayerDataChanged(newData)
    print("Player data updated:", newData)
    
    -- Update all GUIs that display player data
    GUIManager.updatePlayerDataDisplays(newData)
end

-- Update all GUIs that show player data
function GUIManager.updatePlayerDataDisplays(playerData)
    -- Update HUD, inventory, stats, etc.
    for guiName, gui in pairs(activeGUIs) do
        if gui.updatePlayerData then
            gui:updatePlayerData(playerData)
        end
    end
end

-- Register a GUI with the manager
function GUIManager.registerGUI(name, guiObject)
    activeGUIs[name] = guiObject
    guiStates[name] = {
        isVisible = true,
        lastUpdate = tick()
    }
    
    print("Registered GUI:", name)
end

-- Unregister a GUI
function GUIManager.unregisterGUI(name)
    if activeGUIs[name] then
        activeGUIs[name] = nil
        guiStates[name] = nil
        print("Unregistered GUI:", name)
    end
end

-- Toggle GUI visibility
function GUIManager.toggleGUI(name)
    if activeGUIs[name] and activeGUIs[name].Enabled ~= nil then
        local isVisible = activeGUIs[name].Enabled
        activeGUIs[name].Enabled = not isVisible
        guiStates[name].isVisible = not isVisible
        
        print("Toggled GUI:", name, "Visible:", not isVisible)
    end
end

-- Close all GUIs
function GUIManager.closeAllGUIs()
    for name, gui in pairs(activeGUIs) do
        if gui.Enabled ~= nil then
            gui.Enabled = false
            guiStates[name].isVisible = false
        end
    end
    
    print("Closed all GUIs")
end

-- Get GUI state
function GUIManager.getGUIState(name)
    return guiStates[name]
end

-- Check if any GUI is currently open
function GUIManager.isAnyGUIOpen()
    for name, state in pairs(guiStates) do
        if state.isVisible then
            return true
        end
    end
    return false
end

return GUIManager 