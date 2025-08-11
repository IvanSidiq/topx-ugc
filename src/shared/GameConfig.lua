-- Shared Game Configuration
local GameConfig = {}

-- Game Settings
GameConfig.GAME_NAME = "My Awesome Game"
GameConfig.VERSION = "1.0.0"

-- Player Settings
GameConfig.MAX_PLAYERS = 10
GameConfig.DEFAULT_WALKSPEED = 16
GameConfig.DEFAULT_JUMPPOWER = 50

-- GUI Settings
GameConfig.UI_COLORS = {
    PRIMARY = Color3.fromRGB(52, 152, 219),
    SECONDARY = Color3.fromRGB(46, 204, 113),
    DANGER = Color3.fromRGB(231, 76, 60),
    WARNING = Color3.fromRGB(241, 196, 15),
    DARK = Color3.fromRGB(52, 73, 94),
    LIGHT = Color3.fromRGB(236, 240, 241)
}

-- Game Mechanics
GameConfig.RESPAWN_TIME = 5
GameConfig.GAME_DURATION = 300 -- 5 minutes in seconds

-- Debug Settings
GameConfig.DEBUG_MODE = false

return GameConfig 