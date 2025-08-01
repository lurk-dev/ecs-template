# Generic ECS Project - Development Guide

A comprehensive development guide for JECS ECS and Planck scheduler projects with modern security architecture.

## Quick Reference

This document covers the essential patterns and APIs for developing with JECS ECS and Planck scheduler.

### Key Sections

- **[JECS API](#jecs-ecs-library-api-reference)** - Entity/component operations, queries, relationships
- **[System Patterns](#planck-system-patterns)** - Planck phases, initialization, performance
- **[Component Reference](#component-reference)** - Common component patterns
- **[Client-Server Architecture](#client-server-architecture)** - ECS replication, RemoteEvents, authority patterns
- **[Configuration Security](#configuration-security-architecture)** - Three-config system for multiplayer games
- **[Network System](#network-system)** - Secure networking with middleware support
- **[Debugging](#debugging-support)** - Configurable debug system with categories
- **[Troubleshooting](#troubleshooting-guide)** - Common issues and solutions

## JECS ECS Library API Reference

### Entity Management

- `mk.mkEntity(world, name)` - Creates new entities with Jecs.Name for debugging (NOT `world:entity()`)
- `mk.mkComponent(world, name)` - Creates components with Jecs.Name for debugging (NOT `world:component()`)
- `mk.mkTag(world, name)` - Creates tags with Jecs.Name for debugging (NOT `world:tag()`)
- `world:delete(entity)` - Removes entities (NOT `world:despawn()`)
- `world:set(entity, component, data)` - Adds component with data (NOT `world:insert()`)
- `world:get(entity, component, ...)` - Retrieves component data (up to 4 components)
- `world:has(entity, component)` - Checks if entity has component (NOT `world:contains()`)
- `world:remove(entity, component)` - Removes component from entity
- `world:clear(entity)` - Removes all components from entity

### Query Patterns

- Always cache queries for systems that run every frame: `local query = world:query(Component1, Component2):cached()`
- Initialize cached queries at module level when possible, not inside the system function
- Use `for entity, data1, data2 in query do` to iterate over results
- Use `world:query(Component):without(OtherComponent)` to exclude entities with certain components
- Use `world:query(Component):with(Tag)` to include entities with tags but not retrieve tag data
- Alternative iteration: `for entity in query:iter() do` (entities only, no component data)
- Get archetype info: `query:archetypes()` returns table of matching archetypes

### Pair Relationships & world:target()

- Use `jecs.pair(Relationship, Target)` to create typed relationships between entities
- Use `world:target(entity, relationship)` to get the target of a relationship generically
- Use `jecs.Wildcard` in queries to match any target: `world:query(jecs.pair(Eats, jecs.Wildcard))`
- Prefer relationships over hardcoded component checks for scalable type systems
- Store type data on type entities, not on individual items (data normalization)

## Planck System Patterns

### System Return Formats

Systems can be returned in two ways:

1. **Simple function**: `return systemFunction`
2. **System table**: `return { system = systemFunction, phase = Phase.Startup }`

### Phase Usage

- `Phase.Startup` - One-time initialization systems
- `Phase.PreUpdate` - Before main update loop
- `Phase.Update` - Main update loop (default when no phase specified)
- `Phase.PostUpdate` - After main update loop
- `Phase.PreRender` - Before rendering
- `Phase.PostRender` - After rendering
- Use phases to solve "off-by-a-frame" issues when systems depend on each other

### Run Conditions

Systems can have conditional execution:

```lua
return {
    system = mySystem,
    runConditions = {
        function() return game.Workspace.CurrentCamera ~= nil end,
        function() return #game.Players:GetPlayers() > 0 end
    }
}
```

### System Design Principles

- **Single Responsibility**: Each system should do one thing
- **Self-Contained**: Systems shouldn't depend on other systems, isolated behavior
- **Reusable**: Aim for generic, reusable systems
- **Singleton World**: Use module-level world import, no need to pass as parameter since there's only one world
- **Module Dependencies**: Access external dependencies at module level, not inside system functions
- **Testable**: Systems should be easily testable with the singleton world
- **Small Systems**: Split large systems into smaller, focused systems when possible
- **No Yielding**: Systems must never yield the Planck scheduler - use task.spawn() for waiting operations
- **Initialization Guards**: Use systemInitialized flags to prevent multiple system setup

### Scheduler & Plugins

The project uses Planck scheduler with plugins:

```lua
local scheduler = Scheduler.new(world)
    :addPlugin(jabbyPlugin)      -- Jabby debugger integration
    :addPlugin(runServicePlugin)  -- RunService event binding
scheduler:addSystems(systems)     -- Add all systems
```

### System Names & Debugging

Systems can have optional names for debugging:

```lua
return {
    system = mySystem,
    phase = Phase.Update,
    name = "MySystemName"  -- Required: helps with debugging
}
```

## Configuration Security Architecture

### Three-Config System (Need-to-Know Basis)

**🛡️ `src/server/server-config.luau`** - Server-authoritative data:

- ✅ **Game balance** (damage, health, ranges, economy values)
- ✅ **Server settings** (spawn rates, AI behavior, drop rates)
- ✅ **Admin settings** (whitelisted users, command permissions)
- ✅ **Security-sensitive data** (costs, rewards, validation rules)
- ❌ **Clients cannot access** - prevents exploits and cheating

**🖥️ `src/shared/client-config.luau`** - Client-specific settings:

- ✅ **UI layouts** (positioning, sizing, visual preferences)
- ✅ **Input bindings** (keybinds, mouse controls, camera settings)
- ✅ **Visual preferences** (particle counts, effect quality, distances)
- ✅ **Performance settings** (frame caps, render distances)
- ❌ **NO sensitive balance data** - only presentation settings

**🤝 `src/shared/shared-config.luau`** - Coordination data:

- ✅ **Display information** (names, descriptions, colors)
- ✅ **Basic limits** (max slots, stack sizes - for UI sizing)
- ✅ **Network constants** (RemoteEvent names, rate limits)
- ✅ **Error messages** (user-facing text that both sides show)
- ✅ **Debug categories** (shared debug configuration)
- ❌ **NO sensitive balance data** - only safe coordination info

### Security Benefits

```lua
-- ❌ BEFORE (Vulnerable): Client could access sensitive data
local sensitiveValue = gameConfig.Balance.criticalValue  -- Exposed to client!

-- ✅ AFTER (Secure): Proper separation of concerns
-- CLIENT: Only sees display info
local displayName = sharedConfig.Helpers.getDisplayName("ItemType")

-- SERVER: Handles all sensitive calculations
local balanceValue = serverConfig.Helpers.getBalanceValue("criticalValue")  -- Server-only
```

### Configuration Import Patterns

```lua
-- SERVER SYSTEMS: Access server config for balance data
local serverConfig = require(script.Parent.Parent["server-config"])
local balanceValue = serverConfig.Helpers.getBalanceValue("someValue")

-- CLIENT SYSTEMS: Access client config for UI/input settings
local clientConfig = require(ReplicatedStorage.Shared["client-config"])
local uiSettings = clientConfig.Helpers.getUISettings()

-- SHARED SYSTEMS: Access shared config for display data
local sharedConfig = require(ReplicatedStorage.Shared["shared-config"])
local displayName = sharedConfig.Helpers.getDisplayName("SomeType")
```

## Network System

### 🌐 Overview

The project includes a comprehensive, secure network system with middleware support using the standard Roblox Promise library for async operations. For detailed information, see **[NETWORK_USAGE.md](./NETWORK_USAGE.md)**.

### Key Features

- **Server-Authoritative**: All validation happens on server
- **Middleware Pipeline**: Extensible request/response processing
- **Rate Limiting**: Prevents request spam and DoS attacks
- **Admin Protection**: Built-in permission checking
- **Type Safety**: Strict typing throughout the system
- **Promise Integration**: Standard Roblox Promise library for advanced async patterns
- **Enhanced Async**: Promise.all(), Promise.race(), timeouts, and chaining support

### Quick Integration

```lua
-- Server system
local ServerNetwork = require(script.Parent.Parent.network)
ServerNetwork.init()
ServerNetwork.handle("gameAction", function(player, data)
    -- Your secure game logic here
    return true, {result = "success"}, nil
end)

-- Client usage with Promise features
local Promise = require(ReplicatedStorage.Packages.promise)
local ClientNetwork = require(ReplicatedStorage.Shared.client.network)
ClientNetwork.init()

-- Simple request
ClientNetwork.request("gameAction", {param = "value"})
    :andThen(function(response)
        print("Action completed:", response.data.result)
    end)

-- Advanced: Multiple concurrent requests
Promise.all({
    ClientNetwork.request("getPlayerData"),
    ClientNetwork.request("getGameSettings")
})
    :andThen(function(results)
        local playerData, settings = unpack(results)
        initializeGame(playerData, settings)
    end)
    :catch(function(error)
        showErrorMessage("Failed to load game data:", error)
    end)
```

**📖 See [NETWORK_USAGE.md](./NETWORK_USAGE.md) for complete documentation, examples, and security best practices.**

## Project Structure Patterns

### Components

- All components defined in `src/shared/components.luau`
- Created with `mk.mkComponent(world, "ComponentName")`
- Organized as a dictionary export

### Systems Organization

- `shared-systems/` - Run on both client and server
- `client-systems/` - Client only
- `server-systems/` - Server only
- Systems automatically loaded by folder scanning in setup files

### Coding Style Preferences

- **Always use `game:GetService()`** - Never access services directly via `game.ServiceName`
- **Define service variables** at the top of files for clarity and performance
- **Use `ipairs` for arrays**, `pairs` for dictionaries
- **Avoid magic numbers** - use constants/config
- **Separate modules and services** with one whitespace

### Service Access Pattern (REQUIRED)

```lua
-- ✅ CORRECT: Always use game:GetService()
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local require_path = require(ReplicatedStorage.Shared.module)

-- ❌ INCORRECT: Never access services directly
local require_path = require(game.ReplicatedStorage.Shared.module)
local script_path = game.ServerScriptService.Scripts.myScript
```

### Modern Code Organization Patterns

- **Import organization**: Group services first, then packages, then local modules
- **Type annotations**: Add parameter types (`function myFunc(param: Type)`)
- **Debug consistency**: Use `Debug.category()` instead of raw `print()` statements
- **System naming**: Always include `name = "SystemName"` in system exports
- **Error handling**: Include defensive checks and meaningful error messages
- **Module structure**: Services → Packages → Local modules with whitespace separation

### Modern Import Structure Example

```lua
-- SERVICES (group together, always use game:GetService())
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- PACKAGES (separate with whitespace)
local jecs = require(ReplicatedStorage.Packages.jecs)
local Planck = require(ReplicatedStorage.Packages.Planck)

-- LOCAL MODULES (group by type)
local components = require(ReplicatedStorage.Shared.components)
local world = require(ReplicatedStorage.Shared.world)
local mk = require(ReplicatedStorage.Shared.mk)
-- SERVER: Use server config for sensitive data
local serverConfig = require(script.Parent.Parent["server-config"])

-- CLIENT: Use client config for UI/input settings
local clientConfig = require(ReplicatedStorage.Shared["client-config"])

-- SHARED: Use shared config for display data
local sharedConfig = require(ReplicatedStorage.Shared["shared-config"])
local Debug = require(ReplicatedStorage.Shared.debug)
```

### System Export Pattern

```lua
-- STANDARD: Include system name for debugging
return {
    system = mySystemFunction,
    phase = Planck.Phase.Update,    -- Optional: specify phase
    name = "MySystemName"           -- Required: for debugging
}

-- STARTUP SYSTEMS: Use Startup phase for one-time setup
return {
    system = initializationSystem,
    phase = Planck.Phase.Startup,
    name = "SystemInitializer"
}
```

## Component Reference

### Core Components

- `Player` - Stores player UserId
- `PlayerData` - Stores player info (name, etc.)
- `Possesses` - Creates relationships (player possesses character)
- `Position` - Entity positions
- `Health` / `MaxHealth` - Current and maximum health values
- `Name` - Readable names for entities (required for Jabby debugger)

### Common System Components

- `TypeComponent` - Generic type relationship component
- `StoredIn` - Generic storage relationship
- `Model` - Links ECS entities to Roblox models/parts
- `Target` - Current target entity
- `Owner` - Ownership relationship

## Resource Management

- Use world resources instead of global state for shared data
- Connect event listeners BEFORE processing existing state to avoid race conditions
- Extract duplicate logic into reusable functions (DRY principle)

## Memory Management & Cleanup

- Always clean up entities when players leave: `world:delete(playerEntity)`
- Remove component relationships before deleting entities: `world:remove(entity, Possesses)`
- Clear mappings in resource entities when entities are removed
- Use weak references in lookup tables when possible
- Disconnect event connections when systems shut down
- Clean up cached queries if systems are dynamically removed (rare)

## File Naming Conventions

- Omit suffixes like ".server", ".luau", ".client" when referencing scripts
- Use kebab-case for system files (e.g., `player-name-printer.luau`)

## Client-Server Architecture

### Multiplayer Security Architecture

#### Core Security Principles

- **Never Trust Clients**: All game logic must be server-authoritative
- **Server Validation**: Validate all client requests (range, cooldowns, existence, permissions)
- **Client Presentation Only**: Clients handle UI, effects, input collection - never game logic
- **ECS Authority**: Server owns all authoritative ECS state, clients receive updates
- **Network Security**: Use the secure network system for all communication (see [NETWORK_USAGE.md](./NETWORK_USAGE.md))

#### Server-Authoritative Pattern

```lua
-- CLIENT: Only sends requests (no sensitive data)
ClientNetwork.request("playerAction")  -- No calculations, no damage amounts

-- SERVER: Performs all validation and calculations
ServerNetwork.handle("playerAction", function(player: Player, data: any?)
    -- 1. Validate action is allowed
    if not isActionAllowed(player.UserId) then return false, nil, "Action not allowed" end

    -- 2. Server-side calculations
    local result = performServerCalculation(player)
    if not result then return false, nil, "Calculation failed" end

    -- 3. Apply changes and send confirmation to all clients
    world:set(entity, Component, newValue)
    ServerNetwork.broadcast("actionConfirmed", {player = player.UserId, result = result})

    return true, result, nil
end)
```

#### Security Validation Patterns

```lua
-- RANGE VALIDATION: Server checks proximity
local distance = (playerPosition - targetPosition).Magnitude
if distance > MAX_RANGE then
    Debug.debug("Action blocked: out of range")
    return false, nil, "Target out of range"
end

-- COOLDOWN VALIDATION: Server enforces cooldowns
local lastTime = lastActionTime[player.UserId]
if lastTime and currentTime - lastTime < ACTION_COOLDOWN then
    Debug.debug("Action blocked: cooldown active")
    return false, nil, "Action on cooldown"
end

-- EXISTENCE VALIDATION: Server verifies entity exists
local targetEntity = tonumber(targetEntityId)
if not targetEntity or not world:has(targetEntity, RequiredComponent) then
    Debug.error("Invalid target entity:", targetEntityId)
    return false, nil, "Invalid target"
end
```

#### Network Security Patterns

```lua
-- SECURE: Client sends minimal request data
ClientNetwork.request("playerAction")                    -- No exploitable data
ClientNetwork.request("useItem", {slotIndex = 1})        -- Only slot, server determines effect
ClientNetwork.request("interactWith", {entityId = 123})  -- Only entity ID for validation

-- INSECURE: Never send these from client
-- ClientNetwork.request("damageEntity", {entityId = 123, damage = 999999})   -- Exploitable amount
-- ClientNetwork.request("setPosition", {position = anyPosition})            -- Exploitable positioning
-- ClientNetwork.request("giveReward", {amount = 999999})                   -- Exploitable rewards
```

#### Physical Model Linking (Secure)

- **Server**: Creates ECS entities and links via attributes
- **Client**: Reads attributes to identify entities, sends requests for validation
- **Pattern**: `model:SetAttribute("EntityId", tostring(entity))`

## ECS Design Patterns

### Component Design Guidelines

- **Data Only**: Components should only hold data, never behavior (functions)
- **Small & Focused**: Each component represents one concept (Position, Health, etc.)
- **Flat Structure**: Avoid deep nesting in component data
- **Immutable When Possible**: Prefer replacing component data over mutating it
- **Meaningful Names**: Use clear, descriptive names that indicate purpose

### Scalable Type Systems (Key Pattern)

- **Types as Entities**: Make TypeA, TypeB entities instead of components
- **Relationships Over Components**: Use `jecs.pair(TypeComponent, TypeA)` instead of `TypeA` component
- **Data Normalization**: Store type data once on type entity, not duplicated per item
- **Generic Queries**: Use `world:target()` to avoid hardcoded type checking
- **Zero-Code Scaling**: Adding new types requires no system code changes

### Entity Relationships

- Use **Possesses** component to create parent-child relationships
- Store entity IDs in components to reference other entities
- Clean up relationships when entities are deleted
- Use resource entities to hold shared data (like PlayerEntityMap)

### Error Handling Patterns

- **Always check `world:has(entity, component)` before `world:get()`**
- **Use defensive programming** - check if entities exist before operations
- **Clean up properly** in removal/disconnection events
- **Handle edge cases** like character spawning before player entity creation
- **Validate inputs** with nil checks and meaningful error messages
- **Provide fallbacks** for critical operations (e.g., character position defaults)
- **Use Debug.error()** for error reporting instead of raw error throwing

### Essential Defensive Patterns

```lua
-- PARAMETER VALIDATION: Always check critical inputs
local function initCharacter(player, playerEntity, character)
    if not character then
        Debug.error("Character is nil for player:", player.Name)
        return
    end

    -- Provide safe fallbacks
    local position = Vector3.new(0, 10, 0)  -- Default spawn height
    if character.PrimaryPart then
        position = character.PrimaryPart.Position
    elseif character:FindFirstChild("HumanoidRootPart") then
        position = character.HumanoidRootPart.Position
    end
end

-- COMPONENT ACCESS: Always check before getting
if world:has(entity, Component) then
    local data = world:get(entity, Component)
    -- Use data safely
end

-- ENTITY QUERIES: Verify entities still exist
for playerEntity, userId in playerQuery do
    if world:has(playerEntity, Player) then  -- Entity still valid
        -- Process entity
    end
end
```

### Performance Considerations

- **Cache queries that run frequently**: `local query = world:query(Component):cached()` at module level
- **Use `:without()` and `:with()`** to filter queries efficiently
- **Minimize component data size** - store only what's needed
- **Batch operations** when possible to reduce world state changes
- **Optimize monitoring frequencies** - don't scan workspace every frame (use 2+ second intervals)
- **Scan efficiently** - only check relevant objects (BaseParts vs all workspace children)
- **Use defensive queries** - always check `world:has()` before `world:get()`

## Debugging Support

### Jabby Debugger Integration

- Always use `mk.mkEntity()`, `mk.mkComponent()`, `mk.mkTag()` instead of raw JECS methods
- These helpers automatically add `Jecs.Name` for Jabby debugger visualization
- Entity names: descriptive + player name when applicable (e.g., "Player_John", "Character_Jane")
- Component names: match the component purpose (e.g., "PlayerData", "Health")
- Resource entities: descriptive purpose (e.g., "PlayerEntityMapResource")

### Debug Helper System

Create a shared debug utility (`src/shared/debug.luau`) for consistent logging:

```lua
local Debug = require(ReplicatedStorage.Shared.debug)

Debug.target("Target detected by player:", player.Name)    -- 🎯 [CLIENT]: Target detected...
Debug.success("Action completed successfully")             -- ✅ [SERVER]: Action completed...
Debug.error("Failed to find player entity")               -- ❌ [CLIENT]: Failed to find...
Debug.network("Sending data update")                      -- 📡 [SERVER]: Sending data...
```

### Context-Aware Logging with Categories

- **Automatic Detection**: Debug helper detects CLIENT vs SERVER context
- **Categorized Messages**: Different emojis for different message types
- **Configurable Categories**: Enable/disable debug output by category
- **Consistent Format**: All debug messages follow `[CONTEXT]: message` pattern
- **Easy Debugging**: Clear visual separation makes tracing client-server flow easy

### Debug Categories System

The debug system supports configurable categories to reduce noise:

**Core Categories (keep enabled):**

- `system` - System initialization (⚙️)
- `config` - Configuration loading (🔧)
- `error` - Error messages (❌)

**Gameplay Categories (toggle as needed):**

- `gameplay` - Core game mechanics (🎮)
- `movement` - Movement and positioning (🏃)
- `interaction` - Player interactions (🤝)

**Visual Categories (usually disable):**

- `visual` - Visual effects, UI updates (🎨)
- `network` - RemoteEvent communication (📡)
- `ui` - UI updates and changes (🖥️)

**Development Categories (enable when debugging specific issues):**

- `target` - Targeting and interaction detection (🎯)
- `search` - Search operations (🔍)
- `link` - Entity linking and references (🔗)
- `debug` - General debug information (🐛)
- `info` - Informational messages (🔵)
- `success` - Success confirmations (✅)

### Debug Configuration (shared-config.luau)

```lua
Debug = {
    enableDebugPrints = true,   -- Master toggle
    categories = {
        system = true,          -- System messages
        gameplay = true,        -- Gameplay messages
        movement = false,       -- Movement messages (disabled)
        visual = false,         -- Visual effects (disabled)
        -- ... etc
    }
}
```

### Debug Helper Functions

```lua
-- Enable/disable categories (via shared config)
sharedConfig.Helpers.enableDebugCategory("gameplay")
sharedConfig.Helpers.disableDebugCategory("movement")
sharedConfig.Helpers.listDebugCategories()

-- Quick presets (via shared config)
sharedConfig.Helpers.debugOnlyCore()      -- Only core + critical
sharedConfig.Helpers.debugQuiet()         -- Only core systems
sharedConfig.Helpers.debugVerbose()       -- All categories

-- Direct debug helper
Debug.enableCategory("visual")
Debug.disableCategory("network")
Debug.listCategories()
Debug.enableOnlyCategory("gameplay")
```

## Essential Patterns

### Scalable Type System (Core Pattern)

```lua
-- BAD: Hardcoded type checking (doesn't scale)
if world:has(entity, TypeA) then
    local dataA = world:get(entity, TypeA)
elseif world:has(entity, TypeB) then
    local dataB = world:get(entity, TypeB)
end

-- GOOD: Types as entities with relationships (infinitely scalable)
world:set(TypeA, Name, "Type A")                           -- Type data on type entity
world:set(entity, jecs.pair(TypeComponent, TypeA), true)   -- Entity → Type relationship

-- Generic lookup works for ANY type automatically
local typeEntity = world:target(entity, TypeComponent)
local typeName = world:get(typeEntity, Name)               -- "Type A"
```

### Client-Server Architecture Pattern

```lua
-- SERVER: Authoritative state in ECS
world:set(entity, jecs.pair(StoredIn, containerEntity), true)
world:set(entity, Component, data)

-- CLIENT: Receives updates via network system
ClientNetwork.onServerMessage("dataUpdate", function(updateData)
    -- Update UI with received data (no local ECS queries)
end)

-- PHYSICAL LINKING: Connect Roblox models to ECS entities
model:SetAttribute("EntityId", tostring(entity))
```

### System Initialization Pattern

```lua
local systemInitialized = false

local function mySystem()
    if not RunService:IsServer() or systemInitialized then return end
    systemInitialized = true

    Debug.system("My system initializing...")

    -- Initialization code here (never yields)
    task.spawn(function()
        task.wait(1)  -- Safe inside task.spawn
        doDelayedSetup()
    end)

    Debug.config("My system initialized")
end
```

### Network Integration Pattern

```lua
-- SERVER: Handle secure requests
ServerNetwork.handle("gameAction", function(player: Player, data: any?)
    -- Validate, process with ECS, return secure result
    if not validateAction(player, data) then
        return false, nil, "Invalid action"
    end

    -- Update ECS state
    updateGameState(player, data)

    -- Notify other players if needed
    ServerNetwork.broadcast("stateChange", {
        type = "playerAction",
        playerId = player.UserId
    })

    return true, {success = true}, nil
end)

-- CLIENT: Send requests with Promise features
local Promise = require(ReplicatedStorage.Packages.promise)

-- Simple request
ClientNetwork.request("gameAction", {actionType = "move", direction = "forward"})
    :andThen(function(response)
        Debug.success("Action completed")
    end)
    :catch(function(error)
        Debug.error("Action failed:", error)
    end)

-- Advanced: Load game state with multiple requests and timeout
Promise.all({
    ClientNetwork.request("getPlayerState"),
    ClientNetwork.request("getWorldState"),
    ClientNetwork.request("getGameRules")
})
    :timeout(10) -- 10 second timeout for all requests
    :andThen(function(results)
        local playerState, worldState, gameRules = unpack(results)
        initializeGameClient(playerState, worldState, gameRules)
        Debug.success("Game state loaded successfully")
    end)
    :catch(function(error)
        if error == "timeout" then
            Debug.error("Game state loading timed out")
        else
            Debug.error("Failed to load game state:", error)
        end
        showLoadingError()
    end)
```

## Troubleshooting Guide

### JECS API Errors

- **Missing method 'spawn'**: Use `mk.mkEntity(world, "name")` not `world:spawn()`
- **Missing method 'insert'**: Use `world:set(entity, component, data)` not `world:insert()`
- **Numbers in Jabby debugger**: Always use `mk.mkEntity()`, `mk.mkComponent()`, `mk.mkTag()` helpers

### System Issues

- **Systems not running**: Return `{ system = mySystem, name = "SystemName" }` or just `mySystem`
- **System yielding errors**: Use `task.spawn()` for any `task.wait()` operations
- **Race conditions**: Connect event listeners FIRST, then process existing state
- **Performance issues**: Cache queries at module level with `:cached()`

### Client-Server Sync Problems

- **Empty data despite updates**: Add proper ownership relationships with `jecs.pair(StoredIn, containerEntity)`
- **Client can't read server data**: Use network system - server is authoritative, client receives updates
- **Config lookup errors**: Ensure server sends config key names that match client expectations

### Network Issues

- **Requests failing**: Check network system initialization on both client and server
- **Rate limiting errors**: Adjust `maxRequestRate` in shared-config or add delays between requests
- **Permission denied**: Verify admin middleware setup and user permissions
- **Timeout errors**: Check server responsiveness and increase `requestTimeout` if needed
- **Promise cancellation**: Handle Promise cancellation properly in cleanup/disconnection events
- **Promise.all() failures**: Remember that if any request in Promise.all() fails, the entire batch fails
- **Unhandled rejections**: Always include `:catch()` handlers to prevent Promise rejection warnings

**📖 For detailed network troubleshooting, see [NETWORK_USAGE.md](./NETWORK_USAGE.md)**

### Security Vulnerabilities

- **Client-side validation**: Move all validation to server, clients send requests only
- **Client-determined values**: All calculations must be server-side
- **Client target selection**: Server determines targets via character facing direction or other server logic
- **Exploitable network requests**: Never send sensitive amounts, positions, or validation data from client
- **Range exploits**: Server validates all distances and line-of-sight

### Architecture Violations

- **Hardcoded type checking**: Use `world:target()` and scalable type relationships instead of hardcoded if statements
- **World parameter confusion**: Access module-level world directly, don't pass as parameter
- **Variable naming inconsistency**: Match parameter names to actual entity types being passed

### Performance Optimizations

- **Workspace scanning lag**: Reduce frequency (2+ seconds) and scan only relevant objects
- **Query creation overhead**: Move queries to module level with `:cached()`
- **Debug message spam**: Use `Debug.category()` instead of `print()` for configurable output
- **Network overhead**: Use middleware to optimize request patterns and batch operations

### Common Defensive Patterns

```lua
-- Always check existence before accessing
if world:has(entity, Component) then
    local data = world:get(entity, Component)
end

-- Validate critical parameters
if not character then
    Debug.error("Character is nil for player:", player.Name)
    return
end

-- Provide fallbacks for positions
local position = Vector3.new(0, 10, 0)  -- Safe default
if character.PrimaryPart then
    position = character.PrimaryPart.Position
end
```

## Related Documentation

- **[NETWORK_USAGE.md](./NETWORK_USAGE.md)** - Complete network system documentation with security best practices and examples
