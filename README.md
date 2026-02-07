# Visual Engine v1.0

A highly configurable, optimized visual effects system for Roblox with built-in animation support and clean API design.

## Features

- ✨ **Highlight Management** - Full control over Roblox Highlight instances
- 🎨 **Color Animation** - Built-in tweening support for smooth color transitions
- 🪝 **Animation Hooks** - Custom per-frame callbacks for advanced effects
- 🛡️ **Protected** - Runs in CoreGui for security
- ⚡ **Optimized** - Minimal overhead, automatic cleanup
- 🔧 **Configurable** - Extensive configuration options
- 📦 **Expandable** - Designed for future visual effect types

## Quick Start

```lua
local VisualEngine = require(path.to.VisualEngine)

-- Initialize (required first step)
VisualEngine.Initialize()

-- Highlight local player
local highlight, id = VisualEngine.HighlightLocalPlayer({
    FillColor = Color3.fromRGB(0, 255, 0),
    FillTransparency = 0.5
})
```

## API Reference

### Core Functions

#### `VisualEngine.Initialize()`
Initializes the engine and creates protected container in CoreGui.
**Must be called before any other functions.**

---

#### `VisualEngine.HighlightLocalPlayer(properties)`
Creates a highlight on the local player's character.

**Parameters:**
- `properties` (table, optional) - Highlight properties to override defaults

**Returns:**
- `highlight` - The Highlight instance
- `id` - Unique identifier string

**Example:**
```lua
local highlight, id = VisualEngine.HighlightLocalPlayer({
    FillColor = Color3.fromRGB(255, 0, 0),
    FillTransparency = 0.3,
    OutlineColor = Color3.fromRGB(255, 255, 0)
})
```

---

#### `VisualEngine.HighlightPlayer(player, properties)`
Creates a highlight on another player's character.

**Parameters:**
- `player` (Player) - The player to highlight
- `properties` (table, optional) - Highlight properties

**Returns:**
- `highlight` - The Highlight instance
- `id` - Unique identifier string

**Example:**
```lua
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        VisualEngine.HighlightPlayer(player, {
            FillColor = Color3.fromRGB(0, 0, 255)
        })
    end)
end)
```

---

#### `VisualEngine.HighlightInstance(instance, properties)`
Creates a highlight on any instance.

**Parameters:**
- `instance` (Instance) - Any Roblox instance to highlight
- `properties` (table, optional) - Highlight properties

**Returns:**
- `highlight` - The Highlight instance
- `id` - Unique identifier string

**Example:**
```lua
local part = workspace.SomePart
local highlight, id = VisualEngine.HighlightInstance(part, {
    FillColor = Color3.fromRGB(255, 255, 0),
    OutlineTransparency = 0
})
```

---

### Color & Animation

#### `VisualEngine.SetColor(id, fillColor, outlineColor, tweenInfo)`
Changes highlight colors with optional animation.

**Parameters:**
- `id` (string) - Highlight identifier
- `fillColor` (Color3, optional) - New fill color
- `outlineColor` (Color3, optional) - New outline color
- `tweenInfo` (TweenInfo, optional) - Animation settings

**Returns:**
- `tween` - Created tween (if tweenInfo provided)

**Examples:**
```lua
-- Immediate color change
VisualEngine.SetColor(id, Color3.fromRGB(255, 0, 0))

-- Animated color change
local tweenInfo = TweenInfo.new(2, Enum.EasingStyle.Sine)
VisualEngine.SetColor(
    id,
    Color3.fromRGB(0, 255, 0),
    Color3.fromRGB(255, 255, 0),
    tweenInfo
)
```

---

#### `VisualEngine.RegisterAnimationHook(id, callback)`
Registers a custom function to be called every frame for advanced animations.

**Parameters:**
- `id` (string) - Highlight identifier
- `callback` (function) - Function called each frame: `callback(highlight, deltaTime)`

**Returns:**
- `hookId` - Hook identifier (for removal)

**Example:**
```lua
-- Rainbow effect
local time = 0
local hookId = VisualEngine.RegisterAnimationHook(id, function(highlight, deltaTime)
    time = time + deltaTime
    local hue = (time * 0.5) % 1
    highlight.FillColor = Color3.fromHSV(hue, 1, 1)
end)
```

---

#### `VisualEngine.RemoveAnimationHook(id, hookId)`
Removes a previously registered animation hook.

**Parameters:**
- `id` (string) - Highlight identifier
- `hookId` (string) - Hook identifier from RegisterAnimationHook

---

### Management

#### `VisualEngine.RemoveHighlight(id)`
Removes a highlight and cleans up all associated resources.

**Parameters:**
- `id` (string) - Highlight identifier

---

#### `VisualEngine.ClearAll()`
Removes all active highlights.

---

#### `VisualEngine.GetHighlight(id)`
Gets highlight data for inspection.

**Parameters:**
- `id` (string) - Highlight identifier

**Returns:**
- `data` (table) - Highlight data containing:
  - `highlight` - The Highlight instance
  - `adornee` - The parent instance
  - `tweens` - Active tweens
  - `hooks` - Animation hooks

---

## Configuration

Default settings can be modified in the CONFIG table:

```lua
local CONFIG = {
    Highlight = {
        FillColor = Color3.fromRGB(255, 255, 255),
        FillTransparency = 0.5,
        OutlineColor = Color3.fromRGB(255, 255, 255),
        OutlineTransparency = 0,
        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
        Enabled = true
    },
    
    Performance = {
        MaxHighlights = 100,  -- Safety limit
        UpdateRate = 0.016,   -- ~60 FPS
    }
}
```

## Advanced Examples

### Pulsing Effect
```lua
local time = 0
VisualEngine.RegisterAnimationHook(id, function(highlight, deltaTime)
    time = time + deltaTime
    local pulse = (math.sin(time * 3) + 1) / 2
    highlight.FillTransparency = 0.3 + (pulse * 0.4)
end)
```

### Damage Flash
```lua
local function ShowDamageFlash(player)
    local highlight, id = VisualEngine.HighlightPlayer(player, {
        FillColor = Color3.fromRGB(255, 0, 0),
        FillTransparency = 0.2
    })
    
    task.wait(0.5)
    VisualEngine.RemoveHighlight(id)
end
```

### Team Colors
```lua
local TEAM_COLORS = {
    ["Red"] = Color3.fromRGB(255, 0, 0),
    ["Blue"] = Color3.fromRGB(0, 0, 255)
}

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        local color = TEAM_COLORS[player.Team.Name]
        VisualEngine.HighlightPlayer(player, {
            FillColor = color,
            OutlineColor = color
        })
    end)
end)
```

## Performance Notes

- Maximum 100 highlights by default (configurable)
- Automatic cleanup of destroyed instances
- Efficient per-frame hook system
- Tween management with automatic disposal
- Protected in CoreGui (cannot be tampered with)

## Future Roadmap

- 🔴 Beam effects
- ⚡ Particle systems
- 🌟 Trail effects
- 📊 Layer management
- 🎭 Effect presets
- 🔊 Sound visualization integration

## Best Practices

1. **Always initialize first**: Call `Initialize()` before using any functions
2. **Store IDs**: Keep track of highlight IDs for later manipulation
3. **Clean up**: Remove highlights when no longer needed to free resources
4. **Use hooks sparingly**: Animation hooks run every frame - keep them efficient
5. **Check returns**: Functions return `nil` on failure - always validate

## License

Free to use and modify for your Roblox projects!
