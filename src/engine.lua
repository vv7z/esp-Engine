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
	
	-- Performance settings
	Performance = {
		MaxHighlights = 100, -- Safety limit
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
local _animationHooks = {} -- Stores animation callbacks
local _container = nil -- Protected container reference

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
-- COLOR & ANIMATION SYSTEM
-- ═══════════════════════════════════════════════════════════════

--[[
	Change highlight color with optional tweening
	
	@param id - Highlight identifier
	@param fillColor - New fill color (optional)
	@param outlineColor - New outline color (optional)
	@param tweenInfo - TweenInfo for animation (optional)
	@return tween - Created tween if tweenInfo provided
--]]
function VisualEngine.SetColor(id, fillColor, outlineColor, tweenInfo)
	local data = _highlights[id]
	if not data then
		warn("[VisualEngine] Highlight not found: " .. tostring(id))
		return
	end
	
	local highlight = data.highlight
	
	-- Immediate color change
	if not tweenInfo then
		if fillColor then highlight.FillColor = fillColor end
		if outlineColor then highlight.OutlineColor = outlineColor end
		return
	end
	
	-- Animated color change
	local goals = {}
	if fillColor then goals.FillColor = fillColor end
	if outlineColor then goals.OutlineColor = outlineColor end
	
	local tween = TweenService:Create(highlight, tweenInfo, goals)
	
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

-- Run animation hooks every frame
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

-- ═══════════════════════════════════════════════════════════════
-- EXPORT
-- ═══════════════════════════════════════════════════════════════

return VisualEngine
