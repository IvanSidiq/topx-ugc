-- ExampleGUI LocalScript
-- This is a template for how to structure your GUI LocalScripts

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Get services and references
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Import shared modules (adjust paths as needed)
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

-- Import GUI structure
local createGUIStructure = require(script.Parent.structure)

-- Variables
local screenGui = nil
local mainFrame = nil

-- Initialize GUI
local function initializeGUI()
    -- Create the GUI structure
    screenGui, mainFrame = createGUIStructure(playerGui)
    
    -- Add event connections here
    setupEventConnections()
    
    print("ExampleGUI initialized")
end

-- Setup event connections
local function setupEventConnections()
    -- Example: Button click events
    -- mainFrame.CloseButton.MouseButton1Click:Connect(closeGUI)
    
    -- Example: Input events
    -- UserInputService.InputBegan:Connect(onInputBegan)
end

-- Example functions
local function closeGUI()
    if screenGui then
        screenGui:Destroy()
        screenGui = nil
    end
end

-- Initialize when script runs
initializeGUI() 