--!strict

-- TestMode: return true to use in-memory stores and bypass live prompts.
-- Set to false to use real DataStores and purchase prompts.
-- Tip: when testing DataStores in Studio, enable Game Settings > Security > Enable Studio Access to API Services.

local ENABLED = false
local RunService = game:GetService("RunService")

if RunService:IsStudio() then
	ENABLED = true
else
	ENABLED = false
end

return ENABLED 