-- ExampleGUI Structure
-- This module creates the GUI elements and returns references to them

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.GameConfig)

local function createGUIStructure(parent)
    -- Create ScreenGui
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "ExampleGUI"
    screenGui.Parent = parent
    
    -- Create main frame
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 400, 0, 300)
    mainFrame.Position = UDim2.new(0.5, -200, 0.5, -150)
    mainFrame.BackgroundColor3 = GameConfig.UI_COLORS.DARK
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    -- Add corner radius
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = mainFrame
    
    -- Create title label
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(1, 0, 0, 50)
    titleLabel.Position = UDim2.new(0, 0, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "Example GUI"
    titleLabel.TextColor3 = GameConfig.UI_COLORS.LIGHT
    titleLabel.TextScaled = true
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.Parent = mainFrame
    
    -- Create close button
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, 30, 0, 30)
    closeButton.Position = UDim2.new(1, -35, 0, 5)
    closeButton.BackgroundColor3 = GameConfig.UI_COLORS.DANGER
    closeButton.BorderSizePixel = 0
    closeButton.Text = "X"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextScaled = true
    closeButton.Font = Enum.Font.GothamBold
    closeButton.Parent = mainFrame
    
    -- Add corner radius to close button
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 4)
    closeCorner.Parent = closeButton
    
    -- Return references for the LocalScript to use
    return screenGui, mainFrame
end

return createGUIStructure 