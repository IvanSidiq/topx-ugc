-- Main Client Script
print("Client starting up...")

-- Services
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Get local player
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Import modules
local GUIManager = require(script.modules.GUIManager)

print("Welcome " .. player.Name .. "!")

-- Initialize client modules
local function initializeClient()
    -- Initialize GUI management
    GUIManager.init()
    
    print("Client modules initialized")
end

-- Legacy input handling (can be moved to GUIManager)
local function onInputBegan(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.Space then
        print("Space key pressed!")
        -- Add your space key logic here
    end
end

-- Legacy GUI creation (this will be replaced by StarterGui)
local function createWelcomeGui()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "WelcomeGui"
    screenGui.Parent = playerGui
    
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 300, 0, 100)
    frame.Position = UDim2.new(0.5, -150, 0, 50)
    frame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    frame.BorderSizePixel = 0
    frame.Parent = screenGui
    
    local textLabel = Instance.new("TextLabel")
    textLabel.Size = UDim2.new(1, 0, 1, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = "Welcome to the game, " .. player.Name .. "!"
    textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    textLabel.TextScaled = true
    textLabel.Font = Enum.Font.Gotham
    textLabel.Parent = frame
    
    -- Register with GUI manager
    GUIManager.registerGUI("WelcomeGui", screenGui)
    
    -- Auto-remove after 5 seconds
    game:GetService("Debris"):AddItem(screenGui, 5)
    spawn(function()
        wait(5)
        GUIManager.unregisterGUI("WelcomeGui")
    end)
end

-- Start client initialization
initializeClient()

-- Connect legacy input events
UserInputService.InputBegan:Connect(onInputBegan)

-- Create welcome GUI (this will eventually be handled by StarterGui)
createWelcomeGui()

print("Client setup complete!") 