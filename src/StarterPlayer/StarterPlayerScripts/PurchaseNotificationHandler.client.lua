--[[
	PurchaseNotificationHandler - Client-side script to handle purchase notifications
	Displays notifications when:
	- Player tries to buy an item they already own
	- Other purchase-related events
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

-- Wait for the notification event to be created
local notificationEvent = ReplicatedStorage:WaitForChild("UGC_PurchaseNotification", 10)
if not notificationEvent then
	warn("[PURCHASE-NOTIFICATION] Could not find UGC_PurchaseNotification event")
	return
end

-- Function to display notification to player
local function displayNotification(title: string, message: string, duration: number?, iconType: string?)
	duration = duration or 5
	iconType = iconType or "info"
	
	-- Select appropriate icon based on notification type
	local icon = "rbxasset://textures/ui/ErrorIcon.png" -- default error icon
	if iconType == "info" then
		icon = "rbxasset://textures/ui/InformationIcon.png"
	elseif iconType == "success" then
		icon = "rbxasset://textures/ui/InformationIcon.png" -- Roblox doesn't have a success icon, use info
	elseif iconType == "warning" then
		icon = "rbxasset://textures/ui/ErrorIcon.png"
	end
	
	-- Try to use the built-in notification system
	local success = pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = title,
			Text = message,
			Duration = duration,
			Icon = icon
		})
	end)
	
	if not success then
		-- Fallback: print to output if notifications aren't available
		warn(string.format("[NOTIFICATION] %s: %s", title, message))
	end
end

-- Listen for purchase notifications from server
notificationEvent.OnClientEvent:Connect(function(notificationType: string, message: string)
	print(string.format("[PURCHASE-NOTIFICATION] Received: %s - %s", notificationType, message))
	
	if notificationType == "already_owned" then
		displayNotification("Already Owned", message, 4, "info")
	elseif notificationType == "purchase_blocked" then
		displayNotification("Purchase Blocked", message, 4, "warning")
	elseif notificationType == "error" then
		displayNotification("Error", message, 5, "error")
	elseif notificationType == "success" then
		displayNotification("Success", message, 3, "success")
	else
		-- Generic notification
		displayNotification("Notice", message, 4, "info")
	end
end)

print("[PURCHASE-NOTIFICATION] Handler initialized")

