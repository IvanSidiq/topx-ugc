-- Setup Verification Script
-- Run this in Roblox Studio Command Bar to verify the Rojo setup is working

print("🔍 Verifying Rojo Project Setup...")

-- Check if required services exist
local services = {
    "ReplicatedStorage",
    "ServerScriptService", 
    "StarterGui",
    "StarterPlayer"
}

for _, serviceName in ipairs(services) do
    local service = game:GetService(serviceName)
    if service then
        print("✅ " .. serviceName .. " - OK")
    else
        print("❌ " .. serviceName .. " - MISSING")
    end
end

-- Check ReplicatedStorage structure
local repStorage = game:GetService("ReplicatedStorage")
local shared = repStorage:FindFirstChild("Shared")
if shared then
    print("✅ ReplicatedStorage.Shared - OK")
    
    local gameConfig = shared:FindFirstChild("GameConfig")
    if gameConfig then
        print("✅ GameConfig module - OK")
    else
        print("❌ GameConfig module - MISSING")
    end
else
    print("❌ ReplicatedStorage.Shared - MISSING")
end

-- Check ServerScriptService structure
local serverScripts = game:GetService("ServerScriptService")
local serverInit = serverScripts:FindFirstChild("init")
if serverInit then
    print("✅ ServerScriptService.init - OK")
else
    print("❌ ServerScriptService.init - MISSING")
end

-- Check StarterPlayer structure
local starterPlayer = game:GetService("StarterPlayer")
local starterPlayerScripts = starterPlayer:FindFirstChild("StarterPlayerScripts")
if starterPlayerScripts then
    print("✅ StarterPlayerScripts - OK")
    
    local clientInit = starterPlayerScripts:FindFirstChild("init")
    if clientInit then
        print("✅ Client init script - OK")
    else
        print("❌ Client init script - MISSING")
    end
else
    print("❌ StarterPlayerScripts - MISSING")
end

-- Check StarterGui structure
local starterGui = game:GetService("StarterGui")
print("✅ StarterGui ready for content")

print("\n🎯 Setup Verification Complete!")
print("If you see any ❌ items, make sure Rojo is connected and syncing.") 