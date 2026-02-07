--[[
	═══════════════════════════════════════════════════════════════
	VISUAL ENGINE - USAGE EXAMPLES
	═══════════════════════════════════════════════════════════════
--]]

local VisualEngine = loadstring(game:HttpGet("https://raw.githubusercontent.com/vv7z/esp-Engine/refs/heads/main/src/engine.lua"))()

-- ═══════════════════════════════════════════════════════════════
-- INITIALIZATION
-- ═══════════════════════════════════════════════════════════════

-- MUST be called first - sets up protected container in CoreGui
VisualEngine.Initialize()

-- ═══════════════════════════════════════════════════════════════
-- EXAMPLE 1: Highlight Local Player
-- ═══════════════════════════════════════════════════════════════

local highlight1, id1 = VisualEngine.HighlightLocalPlayer({
	FillColor = Color3.fromRGB(0, 255, 0),
	FillTransparency = 0.3,
	OutlineColor = Color3.fromRGB(255, 255, 0)
})

print("Local player highlighted with ID:", id1)

-- ═══════════════════════════════════════════════════════════════
-- EXAMPLE 2: Highlight Another Player
-- ═══════════════════════════════════════════════════════════════

local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local highlight2, id2 = VisualEngine.HighlightPlayer(player, {
			FillColor = Color3.fromRGB(255, 0, 0),
			FillTransparency = 0.5
		})
		
		print(string.format("Highlighted player %s with ID: %s", player.Name, id2))
	end)
end)

-- ═══════════════════════════════════════════════════════════════
-- EXAMPLE 3: Highlight Workspace Instance
-- ═══════════════════════════════════════════════════════════════

local part = workspace:FindFirstChild("SomePart")
if part then
	local highlight3, id3 = VisualEngine.HighlightInstance(part, {
		FillColor = Color3.fromRGB(0, 0, 255),
		OutlineColor = Color3.fromRGB(255, 255, 255)
	})
	
	print("Part highlighted with ID:", id3)
end

-- ═══════════════════════════════════════════════════════════════
-- EXAMPLE 4: Color Tweening
-- ═══════════════════════════════════════════════════════════════

local TweenService = game:GetService("TweenService")

-- Change color with animation
if id1 then
	local tweenInfo = TweenInfo.new(
		2, -- Duration
		Enum.EasingStyle.Sine,
		Enum.EasingDirection.InOut,
		-1, -- Repeat infinitely
		true -- Reverse
	)
	
	VisualEngine.SetColor(
		id1,
		Color3.fromRGB(255, 0, 255), -- Fill color
		Color3.fromRGB(0, 255, 255), -- Outline color
		tweenInfo
	)
end

-- ═══════════════════════════════════════════════════════════════
-- EXAMPLE 5: Animation Hooks (Rainbow Effect)
-- ═══════════════════════════════════════════════════════════════

if id1 then
	local time = 0
	
	local hookId = VisualEngine.RegisterAnimationHook(id1, function(highlight, deltaTime)
		time = time + deltaTime
		
		-- Create rainbow effect
		local hue = (time * 0.5) % 1
		local color = Color3.fromHSV(hue, 1, 1)
		
		highlight.FillColor = color
		highlight.OutlineColor = Color3.fromHSV((hue + 0.5) % 1, 1, 1)
	end)
	
	-- Remove the hook after 10 seconds
	task.wait(10)
	VisualEngine.RemoveAnimationHook(id1, hookId)
end

-- ═══════════════════════════════════════════════════════════════
-- EXAMPLE 6: Pulsing Effect with Hook
-- ═══════════════════════════════════════════════════════════════

if id1 then
	local time = 0
	
	VisualEngine.RegisterAnimationHook(id1, function(highlight, deltaTime)
		time = time + deltaTime
		
		-- Pulsing transparency
		local pulse = (math.sin(time * 3) + 1) / 2 -- 0 to 1
		highlight.FillTransparency = 0.3 + (pulse * 0.4) -- 0.3 to 0.7
	end)
end

-- ═══════════════════════════════════════════════════════════════
-- EXAMPLE 7: Cleanup
-- ═══════════════════════════════════════════════════════════════

-- Remove a specific highlight
task.wait(5)
if id1 then
	VisualEngine.RemoveHighlight(id1)
	print("Removed highlight:", id1)
end

-- Clear all highlights
task.wait(10)
VisualEngine.ClearAll()
print("All highlights cleared")

-- ═══════════════════════════════════════════════════════════════
-- EXAMPLE 8: Advanced - Damage Indicator
-- ═══════════════════════════════════════════════════════════════

local function ShowDamageFlash(player)
	local highlight, id = VisualEngine.HighlightPlayer(player, {
		FillColor = Color3.fromRGB(255, 0, 0),
		FillTransparency = 0.2,
		OutlineTransparency = 1
	})
	
	if not highlight then return end
	
	-- Flash effect
	local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	VisualEngine.SetColor(id, Color3.fromRGB(255, 0, 0), nil, tweenInfo)
	
	-- Auto-remove after flash
	task.wait(0.5)
	VisualEngine.RemoveHighlight(id)
end

-- ═══════════════════════════════════════════════════════════════
-- EXAMPLE 9: Team-Based Coloring
-- ═══════════════════════════════════════════════════════════════

local TEAM_COLORS = {
	["Red"] = Color3.fromRGB(255, 0, 0),
	["Blue"] = Color3.fromRGB(0, 0, 255),
	["Green"] = Color3.fromRGB(0, 255, 0)
}

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local teamColor = TEAM_COLORS[player.Team and player.Team.Name or "Red"]
		
		VisualEngine.HighlightPlayer(player, {
			FillColor = teamColor,
			FillTransparency = 0.6,
			OutlineColor = teamColor
		})
	end)
end)
