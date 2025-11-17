-- Script in ServerScriptService
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local event = ReplicatedStorage:WaitForChild("TryOnAccessoryEvent")

local function isExternalReference(obj, container)
	return obj and not obj:IsDescendantOf(container)
end

local function cleanExternalConstraints(accessory)
	for _, obj in ipairs(accessory:GetDescendants()) do
		if obj:IsA("Weld") then
			if isExternalReference(obj.Part0, accessory) or isExternalReference(obj.Part1, accessory) then
				obj:Destroy()
			end
		elseif obj:IsA("WeldConstraint") then
			if isExternalReference(obj.Part0, accessory) or isExternalReference(obj.Part1, accessory) then
				obj:Destroy()
			end
		elseif obj:IsA("Motor6D") then
			if isExternalReference(obj.Part0, accessory) or isExternalReference(obj.Part1, accessory) then
				obj:Destroy()
			end
		elseif obj:IsA("Glue") then
			if isExternalReference(obj.Part0, accessory) or isExternalReference(obj.Part1, accessory) then
				obj:Destroy()
			end
		end
	end
end

event.OnServerEvent:Connect(function(player, dummyName)
	if typeof(dummyName) ~= "string" then return end
	local char = player.Character or player.CharacterAdded:Wait()
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local dummy = workspace:FindFirstChild(dummyName)
	if not dummy then
		warn("TryOnAccessory: dummy not found", dummyName)
		return
	end

	-- You can choose to clone all Accessory children or a single one.
	for _, acc in ipairs(dummy:GetChildren()) do
		if acc:IsA("Accessory") then
			local clone = acc:Clone()
			-- remove welds/constraints that point to parts **outside** the accessory
			cleanExternalConstraints(clone)

			-- AddAccessory properly parents + welds accessory to the character
			-- (Humanoid:AddAccessory is server-side and creates correct attachments/welds)
			local success, err = pcall(function()
				humanoid:AddAccessory(clone)
			end)
			if not success then
				warn("TryOnAccessory: AddAccessory failed:", err)
				-- fallback: parent directly (less ideal)
				clone.Parent = char
			end
		end
	end
end)
