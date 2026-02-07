--[[
	═══════════════════════════════════════════════════════════════
	VISUAL ENGINE v1.0
	A highly configurable, optimized visual effects system
	═══════════════════════════════════════════════════════════════
	
	FEATURES:
	- Highlight management for players and instances
	- Color animation hooks
	- Tween integration support
	- Clean API with minimal overhead
	- Protected CoreGui implementation
	
	ROADMAP:
	- More visual effect types (Beams, Particles, etc.)
	- Advanced animation presets
	- Layer management system
	
	═══════════════════════════════════════════════════════════════
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- ═══════════════════════════════════════════════════════════════
-- CONFIGURATION
-- ═══════════════════════════════════════════════════════════════

local CONFIG = {
	-- Default highlight properties
	Highlight = {
		FillColor = Color3.fromRGB(255, 255, 255),
		FillTransparency = 0.5,
		OutlineColor = Color3.fromRGB(255, 255, 255),
		OutlineTransparency = 0,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		Enabled = true
	},
	
	-- Default box ESP properties
	BoxESP = {
		Color = Color3.fromRGB(255, 255, 255),
		Thickness = 2,
		Transparency = 0,
		Filled = false,
		FillTransparency = 0.5,
		ShowHealthBar = true,
		ShowName = true,
		ShowDistance = true,
		TextSize = 14,
		TextColor = Color3.fromRGB(255, 255, 255)
	},
	
	-- Performance settings
	Performance = {
		MaxHighlights = 100, -- Safety limit
		MaxBoxes = 100, -- Max box ESP instances
		UpdateRate = 0.016, -- ~60 FPS for animations
	},
	
	-- Container settings
	Container = {
		Name = "VisualEngineContainer",
		Parent = nil -- Set at runtime to CoreGui
	}
}

-- ═══════════════════════════════════════════════════════════════
-- CORE ENGINE
-- ═══════════════════════════════════════════════════════════════

local VisualEngine = {}
VisualEngine.__index = VisualEngine

-- Internal storage
local _highlights = {} -- Tracks all active highlights
local _boxes = {} -- Tracks all active box ESPs
local _animationHooks = {} -- Stores animation callbacks
local _container = nil -- Protected container reference
local _screenGui = nil -- ScreenGui for 2D elements

--[[
	Initialize the engine
	Sets up protected container in CoreGui
--]]
function VisualEngine.Initialize()
	-- Protect against multiple initializations
	if _container then
		warn("[VisualEngine] Already initialized")
		return
	end
	
	-- Create protected container in CoreGui
	local CoreGui = game:GetService("CoreGui")
	_container = Instance.new("Folder")
	_container.Name = CONFIG.Container.Name
	_container.Parent = CoreGui
	
	-- Create ScreenGui for 2D elements (box ESP)
	_screenGui = Instance.new("ScreenGui")
	_screenGui.Name = "VisualEngineScreenGui"
	_screenGui.ResetOnSpawn = false
	_screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	_screenGui.Parent = CoreGui
	
	print("[VisualEngine] Initialized successfully")
end

-- ═══════════════════════════════════════════════════════════════
-- HIGHLIGHT SYSTEM
-- ═══════════════════════════════════════════════════════════════

--[[
	Create a highlight with custom properties
	
	@param parent - Instance to attach highlight to
	@param properties - Table of highlight properties (optional)
	@return highlight - The created Highlight instance
	@return id - Unique identifier for this highlight
--]]
local function CreateHighlight(parent, properties)
	assert(parent, "[VisualEngine] Parent instance required")
	assert(_container, "[VisualEngine] Engine not initialized. Call Initialize() first")
	
	-- Check highlight limit
	local count = 0
	for _ in pairs(_highlights) do count = count + 1 end
	if count >= CONFIG.Performance.MaxHighlights then
		warn("[VisualEngine] Max highlights reached")
		return nil, nil
	end
	
	-- Create highlight instance
	local highlight = Instance.new("Highlight")
	
	-- Apply default properties
	for property, value in pairs(CONFIG.Highlight) do
		highlight[property] = value
	end
	
	-- Apply custom properties if provided
	if properties then
		for property, value in pairs(properties) do
			if highlight[property] ~= nil then
				highlight[property] = value
			else
				warn(string.format("[VisualEngine] Invalid property: %s", property))
			end
		end
	end
	
	-- Set parent and protect in container
	highlight.Adornee = parent
	highlight.Parent = _container
	
	-- Generate unique ID and store reference
	local id = tostring(parent) .. "_" .. tostring(tick())
	_highlights[id] = {
		highlight = highlight,
		adornee = parent,
		tweens = {}, -- Active tweens for this highlight
		hooks = {} -- Animation hooks for this highlight
	}
	
	return highlight, id
end

--[[
	Create highlight for local player's character
	
	@param properties - Table of highlight properties (optional)
	@return highlight - The created Highlight instance
	@return id - Unique identifier
--]]
function VisualEngine.HighlightLocalPlayer(properties)
	local player = Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()
	
	return CreateHighlight(character, properties)
end

--[[
	Create highlight for another player's character
	
	@param player - Player instance to highlight
	@param properties - Table of highlight properties (optional)
	@return highlight - The created Highlight instance
	@return id - Unique identifier
--]]
function VisualEngine.HighlightPlayer(player, properties)
	assert(player and player:IsA("Player"), "[VisualEngine] Valid Player instance required")
	
	local character = player.Character
	if not character then
		warn(string.format("[VisualEngine] Player %s has no character", player.Name))
		return nil, nil
	end
	
	return CreateHighlight(character, properties)
end

--[[
	Create highlight for any instance
	
	@param instance - Any instance to highlight
	@param properties - Table of highlight properties (optional)
	@return highlight - The created Highlight instance
	@return id - Unique identifier
--]]
function VisualEngine.HighlightInstance(instance, properties)
	assert(instance and typeof(instance) == "Instance", "[VisualEngine] Valid Instance required")
	
	return CreateHighlight(instance, properties)
end

-- ═══════════════════════════════════════════════════════════════
-- BOX ESP SYSTEM
-- ═══════════════════════════════════════════════════════════════

--[[
	Create a box ESP with all visual elements
	
	@param adornee - Instance to draw box around
	@param properties - Table of box properties (optional)
	@return boxData - Table containing all box elements
	@return id - Unique identifier
--]]
local function CreateBoxESP(adornee, properties)
	assert(adornee, "[VisualEngine] Adornee instance required")
	assert(_screenGui, "[VisualEngine] Engine not initialized. Call Initialize() first")
	
	-- Check box limit
	local count = 0
	for _ in pairs(_boxes) do count = count + 1 end
	if count >= CONFIG.Performance.MaxBoxes then
		warn("[VisualEngine] Max boxes reached")
		return nil, nil
	end
	
	-- Create container for this box
	local container = Instance.new("Frame")
	container.Name = "BoxESP"
	container.BackgroundTransparency = 1
	container.Size = UDim2.new(0, 0, 0, 0)
	container.Parent = _screenGui
	
	-- Apply default properties
	local props = {}
	for property, value in pairs(CONFIG.BoxESP) do
		props[property] = value
	end
	
	-- Override with custom properties
	if properties then
		for property, value in pairs(properties) do
			props[property] = value
		end
	end
	
	-- Create box outline (4 lines)
	local lines = {}
	for i = 1, 4 do
		local line = Instance.new("Frame")
		line.Name = "Line" .. i
		line.BorderSizePixel = 0
		line.BackgroundColor3 = props.Color
		line.BackgroundTransparency = props.Transparency
		line.ZIndex = 2
		line.Parent = container
		lines[i] = line
	end
	
	-- Create fill (optional)
	local fill = nil
	if props.Filled then
		fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.BorderSizePixel = 0
		fill.BackgroundColor3 = props.Color
		fill.BackgroundTransparency = props.FillTransparency
		fill.ZIndex = 1
		fill.Parent = container
	end
	
	-- Create health bar (optional)
	local healthBar = nil
	local healthBarBg = nil
	if props.ShowHealthBar then
		healthBarBg = Instance.new("Frame")
		healthBarBg.Name = "HealthBarBg"
		healthBarBg.BorderSizePixel = 0
		healthBarBg.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
		healthBarBg.ZIndex = 2
		healthBarBg.Parent = container
		
		healthBar = Instance.new("Frame")
		healthBar.Name = "HealthBar"
		healthBar.BorderSizePixel = 0
		healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
		healthBar.ZIndex = 3
		healthBar.Parent = healthBarBg
	end
	
	-- Create name label (optional)
	local nameLabel = nil
	if props.ShowName then
		nameLabel = Instance.new("TextLabel")
		nameLabel.Name = "NameLabel"
		nameLabel.BackgroundTransparency = 1
		nameLabel.TextColor3 = props.TextColor
		nameLabel.TextSize = props.TextSize
		nameLabel.Font = Enum.Font.GothamBold
		nameLabel.TextStrokeTransparency = 0.5
		nameLabel.ZIndex = 4
		nameLabel.Parent = container
	end
	
	-- Create distance label (optional)
	local distanceLabel = nil
	if props.ShowDistance then
		distanceLabel = Instance.new("TextLabel")
		distanceLabel.Name = "DistanceLabel"
		distanceLabel.BackgroundTransparency = 1
		distanceLabel.TextColor3 = props.TextColor
		distanceLabel.TextSize = props.TextSize - 2
		distanceLabel.Font = Enum.Font.Gotham
		distanceLabel.TextStrokeTransparency = 0.5
		distanceLabel.ZIndex = 4
		distanceLabel.Parent = container
	end
	
	-- Generate unique ID
	local id = tostring(adornee) .. "_box_" .. tostring(tick())
	
	-- Store box data
	_boxes[id] = {
		container = container,
		lines = lines,
		fill = fill,
		healthBar = healthBar,
		healthBarBg = healthBarBg,
		nameLabel = nameLabel,
		distanceLabel = distanceLabel,
		adornee = adornee,
		properties = props,
		tweens = {},
		hooks = {}
	}
	
	return _boxes[id], id
end

--[[
	Create box ESP for local player
	
	@param properties - Table of box properties (optional)
	@return boxData - Box data table
	@return id - Unique identifier
--]]
function VisualEngine.BoxESPLocalPlayer(properties)
	local player = Players.LocalPlayer
	local character = player.Character or player.CharacterAdded:Wait()
	
	return CreateBoxESP(character, properties)
end

--[[
	Create box ESP for another player
	
	@param player - Player instance
	@param properties - Table of box properties (optional)
	@return boxData - Box data table
	@return id - Unique identifier
--]]
function VisualEngine.BoxESPPlayer(player, properties)
	assert(player and player:IsA("Player"), "[VisualEngine] Valid Player instance required")
	
	local character = player.Character
	if not character then
		warn(string.format("[VisualEngine] Player %s has no character", player.Name))
		return nil, nil
	end
	
	return CreateBoxESP(character, properties)
end

--[[
	Create box ESP for any instance
	
	@param instance - Any instance
	@param properties - Table of box properties (optional)
	@return boxData - Box data table
	@return id - Unique identifier
--]]
function VisualEngine.BoxESPInstance(instance, properties)
	assert(instance and typeof(instance) == "Instance", "[VisualEngine] Valid Instance required")
	
	return CreateBoxESP(instance, properties)
end

--[[
	Update box ESP visual properties
	
	@param id - Box identifier
	@param properties - Table of properties to update
	@param tweenInfo - TweenInfo for animation (optional)
--]]
function VisualEngine.UpdateBoxProperties(id, properties, tweenInfo)
	local data = _boxes[id]
	if not data then
		warn("[VisualEngine] Box not found: " .. tostring(id))
		return
	end
	
	-- Update stored properties
	for property, value in pairs(properties) do
		data.properties[property] = value
	end
	
	-- Apply visual updates
	if properties.Color then
		for _, line in ipairs(data.lines) do
			if tweenInfo then
				local tween = TweenService:Create(line, tweenInfo, {BackgroundColor3 = properties.Color})
				tween:Play()
			else
				line.BackgroundColor3 = properties.Color
			end
		end
		if data.fill then
			if tweenInfo then
				local tween = TweenService:Create(data.fill, tweenInfo, {BackgroundColor3 = properties.Color})
				tween:Play()
			else
				data.fill.BackgroundColor3 = properties.Color
			end
		end
	end
	
	if properties.Transparency then
		for _, line in ipairs(data.lines) do
			if tweenInfo then
				local tween = TweenService:Create(line, tweenInfo, {BackgroundTransparency = properties.Transparency})
				tween:Play()
			else
				line.BackgroundTransparency = properties.Transparency
			end
		end
	end
	
	if properties.Thickness then
		-- Will be applied in the render loop
	end
end

--[[
	Remove a box ESP
	
	@param id - Box identifier
--]]
function VisualEngine.RemoveBox(id)
	local data = _boxes[id]
	if not data then return end
	
	-- Cancel active tweens
	for _, tween in ipairs(data.tweens) do
		tween:Cancel()
	end
	
	-- Destroy container (destroys all children)
	if data.container then
		data.container:Destroy()
	end
	
	-- Remove from tracking
	_boxes[id] = nil
end

-- ═══════════════════════════════════════════════════════════════
-- COLOR & ANIMATION SYSTEM
-- ═══════════════════════════════════════════════════════════════

--[[
	Update any highlight property with optional tweening
	
	@param id - Highlight identifier
	@param properties - Table of properties to update
	@param tweenInfo - TweenInfo for animation (optional)
	@return tween - Created tween if tweenInfo provided
--]]
function VisualEngine.UpdateProperties(id, properties, tweenInfo)
	local data = _highlights[id]
	if not data then
		warn("[VisualEngine] Highlight not found: " .. tostring(id))
		return
	end
	
	local highlight = data.highlight
	
	-- Immediate property change
	if not tweenInfo then
		for property, value in pairs(properties) do
			if highlight[property] ~= nil then
				highlight[property] = value
			else
				warn(string.format("[VisualEngine] Invalid property: %s", property))
			end
		end
		return
	end
	
	-- Animated property change
	local tween = TweenService:Create(highlight, tweenInfo, properties)
	
	-- Store tween reference
	table.insert(data.tweens, tween)
	
	-- Cleanup on completion
	tween.Completed:Connect(function()
		local index = table.find(data.tweens, tween)
		if index then
			table.remove(data.tweens, index)
		end
	end)
	
	tween:Play()
	return tween
end

--[[
	Change highlight color with optional tweening
	
	@param id - Highlight identifier
	@param fillColor - New fill color (optional)
	@param outlineColor - New outline color (optional)
	@param tweenInfo - TweenInfo for animation (optional)
	@return tween - Created tween if tweenInfo provided
--]]
function VisualEngine.SetColor(id, fillColor, outlineColor, tweenInfo)
	local properties = {}
	if fillColor then properties.FillColor = fillColor end
	if outlineColor then properties.OutlineColor = outlineColor end
	
	return VisualEngine.UpdateProperties(id, properties, tweenInfo)
end

--[[
	Change fill color only
	
	@param id - Highlight identifier
	@param color - New fill color
	@param tweenInfo - TweenInfo for animation (optional)
	@return tween - Created tween if tweenInfo provided
--]]
function VisualEngine.SetFillColor(id, color, tweenInfo)
	return VisualEngine.UpdateProperties(id, {FillColor = color}, tweenInfo)
end

--[[
	Change outline color only
	
	@param id - Highlight identifier
	@param color - New outline color
	@param tweenInfo - TweenInfo for animation (optional)
	@return tween - Created tween if tweenInfo provided
--]]
function VisualEngine.SetOutlineColor(id, color, tweenInfo)
	return VisualEngine.UpdateProperties(id, {OutlineColor = color}, tweenInfo)
end

--[[
	Change fill transparency
	
	@param id - Highlight identifier
	@param transparency - New transparency (0-1)
	@param tweenInfo - TweenInfo for animation (optional)
	@return tween - Created tween if tweenInfo provided
--]]
function VisualEngine.SetFillTransparency(id, transparency, tweenInfo)
	return VisualEngine.UpdateProperties(id, {FillTransparency = transparency}, tweenInfo)
end

--[[
	Change outline transparency
	
	@param id - Highlight identifier
	@param transparency - New transparency (0-1)
	@param tweenInfo - TweenInfo for animation (optional)
	@return tween - Created tween if tweenInfo provided
--]]
function VisualEngine.SetOutlineTransparency(id, transparency, tweenInfo)
	return VisualEngine.UpdateProperties(id, {OutlineTransparency = transparency}, tweenInfo)
end

--[[
	Set both fill and outline transparency
	
	@param id - Highlight identifier
	@param fillTransparency - Fill transparency (0-1)
	@param outlineTransparency - Outline transparency (0-1)
	@param tweenInfo - TweenInfo for animation (optional)
	@return tween - Created tween if tweenInfo provided
--]]
function VisualEngine.SetTransparency(id, fillTransparency, outlineTransparency, tweenInfo)
	local properties = {}
	if fillTransparency then properties.FillTransparency = fillTransparency end
	if outlineTransparency then properties.OutlineTransparency = outlineTransparency end
	
	return VisualEngine.UpdateProperties(id, properties, tweenInfo)
end

--[[
	Change depth mode
	
	@param id - Highlight identifier
	@param depthMode - Enum.HighlightDepthMode (AlwaysOnTop, Occluded)
--]]
function VisualEngine.SetDepthMode(id, depthMode)
	return VisualEngine.UpdateProperties(id, {DepthMode = depthMode})
end

--[[
	Enable or disable a highlight
	
	@param id - Highlight identifier
	@param enabled - Boolean
--]]
function VisualEngine.SetEnabled(id, enabled)
	return VisualEngine.UpdateProperties(id, {Enabled = enabled})
end

--[[
	Register an animation hook for custom updates
	Hooks are called every frame with (highlight, deltaTime)
	
	@param id - Highlight identifier
	@param callback - Function(highlight, deltaTime) to call each frame
	@return hookId - Identifier for this hook (to remove later)
--]]
function VisualEngine.RegisterAnimationHook(id, callback)
	assert(type(callback) == "function", "[VisualEngine] Callback must be a function")
	
	local data = _highlights[id]
	if not data then
		warn("[VisualEngine] Highlight not found: " .. tostring(id))
		return nil
	end
	
	local hookId = tostring(tick())
	data.hooks[hookId] = callback
	
	return hookId
end

--[[
	Remove an animation hook
	
	@param id - Highlight identifier
	@param hookId - Hook identifier from RegisterAnimationHook
--]]
function VisualEngine.RemoveAnimationHook(id, hookId)
	local data = _highlights[id]
	if data and data.hooks[hookId] then
		data.hooks[hookId] = nil
	end
end

-- ═══════════════════════════════════════════════════════════════
-- CLEANUP & MANAGEMENT
-- ═══════════════════════════════════════════════════════════════

--[[
	Remove a highlight and clean up resources
	
	@param id - Highlight identifier
--]]
function VisualEngine.RemoveHighlight(id)
	local data = _highlights[id]
	if not data then return end
	
	-- Cancel active tweens
	for _, tween in ipairs(data.tweens) do
		tween:Cancel()
	end
	
	-- Destroy highlight
	if data.highlight then
		data.highlight:Destroy()
	end
	
	-- Remove from tracking
	_highlights[id] = nil
end

--[[
	Remove all highlights
--]]
function VisualEngine.ClearAll()
	for id in pairs(_highlights) do
		VisualEngine.RemoveHighlight(id)
	end
	for id in pairs(_boxes) do
		VisualEngine.RemoveBox(id)
	end
end

--[[
	Remove all highlights only
--]]
function VisualEngine.ClearHighlights()
	for id in pairs(_highlights) do
		VisualEngine.RemoveHighlight(id)
	end
end

--[[
	Remove all boxes only
--]]
function VisualEngine.ClearBoxes()
	for id in pairs(_boxes) do
		VisualEngine.RemoveBox(id)
	end
end

--[[
	Get highlight data by ID
	
	@param id - Highlight identifier
	@return data - Highlight data table (read-only access recommended)
--]]
function VisualEngine.GetHighlight(id)
	return _highlights[id]
end

-- ═══════════════════════════════════════════════════════════════
-- ANIMATION LOOP
-- ═══════════════════════════════════════════════════════════════

-- Helper function to calculate 2D bounding box
local function GetBoundingBox(object, camera)
	local parts = {}
	
	-- Collect all parts to calculate bounds from
	if object:IsA("Model") then
		-- For characters, use HumanoidRootPart as primary reference
		local hrp = object:FindFirstChild("HumanoidRootPart")
		if hrp then
			-- For character models, get visible parts only (exclude root part from visual bounds)
			for _, part in ipairs(object:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					table.insert(parts, part)
				end
			end
			-- If no other parts found, use the root part
			if #parts == 0 then
				table.insert(parts, hrp)
			end
		else
			-- For non-character models, get all parts
			for _, part in ipairs(object:GetDescendants()) do
				if part:IsA("BasePart") then
					table.insert(parts, part)
				end
			end
		end
	elseif object:IsA("BasePart") then
		table.insert(parts, object)
	else
		return nil
	end
	
	if #parts == 0 then return nil end
	
	-- Project all part corners to screen space
	local minX, minY = math.huge, math.huge
	local maxX, maxY = -math.huge, -math.huge
	local allInFront = true
	
	for _, part in ipairs(parts) do
		local cf, size = part.CFrame, part.Size
		
		-- Calculate 8 corners of each part
		local corners = {
			cf * CFrame.new(size.X/2, size.Y/2, size.Z/2),
			cf * CFrame.new(-size.X/2, size.Y/2, size.Z/2),
			cf * CFrame.new(size.X/2, -size.Y/2, size.Z/2),
			cf * CFrame.new(-size.X/2, -size.Y/2, size.Z/2),
			cf * CFrame.new(size.X/2, size.Y/2, -size.Z/2),
			cf * CFrame.new(-size.X/2, size.Y/2, -size.Z/2),
			cf * CFrame.new(size.X/2, -size.Y/2, -size.Z/2),
			cf * CFrame.new(-size.X/2, -size.Y/2, -size.Z/2)
		}
		
		for _, corner in ipairs(corners) do
			local screenPos, onScreen = camera:WorldToViewportPoint(corner.Position)
			
			if screenPos.Z > 0 then
				minX = math.min(minX, screenPos.X)
				minY = math.min(minY, screenPos.Y)
				maxX = math.max(maxX, screenPos.X)
				maxY = math.max(maxY, screenPos.Y)
			else
				allInFront = false
			end
		end
	end
	
	if minX == math.huge then
		return nil
	end
	
	return {
		position = Vector2.new(minX, minY),
		size = Vector2.new(maxX - minX, maxY - minY),
		center = Vector2.new((minX + maxX) / 2, (minY + maxY) / 2)
	}
end

-- Run animation hooks for highlights
RunService.Heartbeat:Connect(function(deltaTime)
	for id, data in pairs(_highlights) do
		-- Validate highlight still exists
		if not data.highlight or not data.highlight.Parent then
			VisualEngine.RemoveHighlight(id)
			continue
		end
		
		-- Execute animation hooks
		for hookId, callback in pairs(data.hooks) do
			local success, err = pcall(callback, data.highlight, deltaTime)
			if not success then
				warn(string.format("[VisualEngine] Hook error: %s", err))
				data.hooks[hookId] = nil -- Remove broken hook
			end
		end
	end
end)

-- Render box ESPs every frame
RunService.RenderStepped:Connect(function()
	local camera = workspace.CurrentCamera
	if not camera then return end
	
	local localPlayer = Players.LocalPlayer
	if not localPlayer then return end
	
	local localCharacter = localPlayer.Character
	local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
	
	for id, data in pairs(_boxes) do
		-- Validate adornee still exists
		if not data.adornee or not data.adornee.Parent then
			VisualEngine.RemoveBox(id)
			continue
		end
		
		-- Get bounding box
		local box = GetBoundingBox(data.adornee, camera)
		
		if box then
			-- Update container position and size
			data.container.Position = UDim2.new(0, box.position.X, 0, box.position.Y)
			data.container.Size = UDim2.new(0, box.size.X, 0, box.size.Y)
			data.container.Visible = true
			
			local thickness = data.properties.Thickness
			
			-- Update lines to form box outline
			-- Top line
			data.lines[1].Position = UDim2.new(0, 0, 0, 0)
			data.lines[1].Size = UDim2.new(1, 0, 0, thickness)
			
			-- Bottom line
			data.lines[2].Position = UDim2.new(0, 0, 1, -thickness)
			data.lines[2].Size = UDim2.new(1, 0, 0, thickness)
			
			-- Left line
			data.lines[3].Position = UDim2.new(0, 0, 0, 0)
			data.lines[3].Size = UDim2.new(0, thickness, 1, 0)
			
			-- Right line
			data.lines[4].Position = UDim2.new(1, -thickness, 0, 0)
			data.lines[4].Size = UDim2.new(0, thickness, 1, 0)
			
			-- Update fill if exists
			if data.fill then
				data.fill.Position = UDim2.new(0, 0, 0, 0)
				data.fill.Size = UDim2.new(1, 0, 1, 0)
			end
			
			-- Update health bar if exists
			if data.healthBar and data.healthBarBg then
				local humanoid = data.adornee:FindFirstChildOfClass("Humanoid")
				if humanoid then
					local healthPercent = humanoid.Health / humanoid.MaxHealth
					
					-- Position health bar to the left of box
					data.healthBarBg.Position = UDim2.new(0, -7, 0, 0)
					data.healthBarBg.Size = UDim2.new(0, 3, 1, 0)
					
					-- Update health bar fill
					data.healthBar.Size = UDim2.new(1, 0, healthPercent, 0)
					data.healthBar.Position = UDim2.new(0, 0, 1 - healthPercent, 0)
					
					-- Color based on health
					if healthPercent > 0.5 then
						data.healthBar.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
					elseif healthPercent > 0.25 then
						data.healthBar.BackgroundColor3 = Color3.fromRGB(255, 255, 0)
					else
						data.healthBar.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
					end
				end
			end
			
			-- Update name label if exists
			if data.nameLabel then
				local displayName = ""
				
				if data.adornee:IsA("Model") then
					displayName = data.adornee.Name
				elseif data.adornee.Parent and data.adornee.Parent:IsA("Model") then
					displayName = data.adornee.Parent.Name
				end
				
				data.nameLabel.Text = displayName
				data.nameLabel.Position = UDim2.new(0.5, 0, 0, -(data.properties.TextSize + 5))
				data.nameLabel.Size = UDim2.new(2, 0, 0, data.properties.TextSize)
				data.nameLabel.AnchorPoint = Vector2.new(0.5, 1)
				data.nameLabel.TextSize = data.properties.TextSize
			end
			
			-- Update distance label if exists
			if data.distanceLabel and localRoot then
				local targetPos
				
				if data.adornee:IsA("Model") then
					targetPos = data.adornee:GetPivot().Position
				elseif data.adornee:IsA("BasePart") then
					targetPos = data.adornee.Position
				end
				
				if targetPos then
					local distance = (localRoot.Position - targetPos).Magnitude
					data.distanceLabel.Text = string.format("%.0f studs", distance)
					data.distanceLabel.Position = UDim2.new(0.5, 0, 1, 5)
					data.distanceLabel.Size = UDim2.new(2, 0, 0, data.properties.TextSize - 2)
					data.distanceLabel.AnchorPoint = Vector2.new(0.5, 0)
					data.distanceLabel.TextSize = data.properties.TextSize - 2
				end
			end
		else
			-- Hide if not visible
			data.container.Visible = false
		end
		
		-- Execute animation hooks for boxes
		for hookId, callback in pairs(data.hooks) do
			local success, err = pcall(callback, data, 0)
			if not success then
				warn(string.format("[VisualEngine] Box hook error: %s", err))
				data.hooks[hookId] = nil
			end
		end
	end
end)

-- ═══════════════════════════════════════════════════════════════
-- EXPORT
-- ═══════════════════════════════════════════════════════════════

return VisualEngine
