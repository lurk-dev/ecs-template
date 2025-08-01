# Network System Usage Guide

A secure, middleware-based network system for Roblox ECS projects with focus on security and client-server relations.

## Overview

The network system consists of three main components:

- **Shared Network** (`src/shared/network.luau`) - Common utilities and types
- **Server Network** (`src/server/network.luau`) - Server-side request handling
- **Client Network** (`src/client/network.luau`) - Client-side request sending

### Dependencies

- **Promise Library** (`Packages/promise.lua`) - Standard Roblox Promise implementation for async operations
  - Provides enhanced features: `Promise.all()`, `Promise.race()`, `Promise.timeout()`, `Promise.delay()`
  - Better performance and reliability than custom implementations
  - Full cancellation support and error handling

## Security Features

✅ **Server-Authoritative** - All validation happens on server
✅ **Rate Limiting** - Prevents request spam
✅ **Timestamp Validation** - Prevents replay attacks  
✅ **Middleware Support** - Extensible validation pipeline
✅ **Request Validation** - Structured request format enforcement
✅ **Admin Authorization** - Built-in admin permission checks

## Quick Start

### Server Setup

```lua
-- In a server system (src/server/server-systems/my-network.luau)
local ServerNetwork = require(script.Parent.Parent.network)

-- Initialize the network system
ServerNetwork.init()

-- Register a simple handler
ServerNetwork.handle("ping", function(player: Player, data: any?)
    return true, {message = "Pong!", timestamp = tick()}, nil
end)

-- Register handler with validation
ServerNetwork.handle("updateSetting", function(player: Player, data: any?)
    if not data or type(data) ~= "table" then
        return false, nil, "Invalid data format"
    end

    -- Validate and process request
    local setting = data.setting
    local value = data.value

    -- Your business logic here

    return true, {updated = setting}, nil
end)
```

### Client Usage

```lua
-- In a client script (StarterPlayer/StarterPlayerScripts/NetworkClient.client.luau)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ClientNetwork = require(ReplicatedStorage.Shared.client.network)

-- Initialize client network
ClientNetwork.init()

-- Send a simple request
ClientNetwork.request("ping")
    :andThen(function(response)
        print("Server responded:", response.data.message)
    end)
    :catch(function(error)
        warn("Request failed:", error)
    end)

-- Send request with data
ClientNetwork.request("updateSetting", {
    setting = "displayName",
    value = "NewName"
})
    :andThen(function(response)
        print("Setting updated:", response.data.updated)
    end)
    :catch(function(error)
        warn("Update failed:", error)
    end)
```

## Middleware System

### Built-in Middleware

**Server Middleware:**

- `createValidationMiddleware()` - Validates request structure
- `createRateLimitMiddleware()` - Prevents request spam
- `createSecurityMiddleware()` - Timestamp and player validation
- `createAdminMiddleware()` - Admin permission checking
- `createLoggingMiddleware()` - Request/response logging

**Client Middleware:**

- `createThrottleMiddleware(interval)` - Minimum time between requests
- `createRetryMiddleware(maxRetries, delay)` - Automatic request retrying
- `createLoggingMiddleware()` - Request logging

### Custom Middleware

```lua
-- Server custom middleware
local function createCustomValidationMiddleware()
    return function(context, next)
        -- Check custom conditions
        if not someCondition(context.player, context.request) then
            context.cancel = true
            context.response = Network.createResponse(false, nil, "Custom validation failed", context.request.requestId)
            return
        end

        next() -- Continue to next middleware
    end
end

-- Register middleware globally
ServerNetwork.use(createCustomValidationMiddleware())

-- Or for specific actions
ServerNetwork.useForAction("sensitiveAction", createCustomValidationMiddleware())
```

## Advanced Usage

### Admin-Only Actions

```lua
-- Register admin middleware for sensitive actions
ServerNetwork.useForAction("adminCommand", ServerNetwork.createAdminMiddleware())

-- Handler will only run for admin users
ServerNetwork.handle("adminCommand", function(player: Player, data: any?)
    -- Only admins reach this point
    return true, {result = "Admin command executed"}, nil
end)
```

### Server Broadcasting

```lua
-- Send to all clients
ServerNetwork.broadcast("serverAlert", {
    message = "Server maintenance in 5 minutes",
    type = "warning"
})

-- Send to specific client
ServerNetwork.sendToClient(player, "personalMessage", {
    message = "Welcome back!",
    data = playerSpecificData
})
```

### Client Response Handlers

```lua
-- Handle server-initiated messages
ClientNetwork.onServerMessage("serverAlert", function(data)
    print("Server alert:", data.message)
    -- Update UI, show notification, etc.
end)

ClientNetwork.onServerMessage("personalMessage", function(data)
    print("Personal message:", data.message)
end)
```

## Enhanced Promise Features

The network system leverages the full power of the standard Promise library for advanced async patterns:

### Multiple Concurrent Requests

```lua
local Promise = require(ReplicatedStorage.Packages.promise)

-- Wait for multiple requests to complete
Promise.all({
    ClientNetwork.request("getPlayerData"),
    ClientNetwork.request("getServerStats"),
    ClientNetwork.request("getGameSettings")
})
    :andThen(function(results)
        local playerData, serverStats, settings = unpack(results)
        updateGameUI(playerData, serverStats, settings)
    end)
    :catch(function(error)
        warn("One or more requests failed:", error)
    end)
```

### Request Racing & Timeouts

```lua
-- First server to respond wins
Promise.race({
    ClientNetwork.request("getDataFromServer1"),
    ClientNetwork.request("getDataFromServer2")
})
    :andThen(function(fastestResult)
        print("Got data from fastest server:", fastestResult)
    end)

-- Built-in timeout support
ClientNetwork.request("slowOperation")
    :timeout(5) -- 5 second timeout
    :andThen(function(result)
        print("Operation completed in time:", result)
    end)
    :catch(function(error)
        if error == "timeout" then
            warn("Operation timed out")
        else
            warn("Operation failed:", error)
        end
    end)
```

### Promise Chaining & Data Processing

```lua
-- Chain operations with data transformation
ClientNetwork.request("getRawPlayerData")
    :andThen(function(rawData)
        -- Process data on client
        local processedData = processPlayerData(rawData.data)

        -- Make follow-up request if needed
        if processedData.needsUpdate then
            return ClientNetwork.request("updatePlayerStats", processedData)
        else
            return Promise.resolve(processedData)
        end
    end)
    :andThen(function(finalData)
        updatePlayerUI(finalData)
    end)
    :catch(function(error)
        showErrorMessage("Failed to load player data:", error)
    end)
```

### Delayed Operations

```lua
-- Use Promise.delay instead of wait()
Promise.delay(2) -- Wait 2 seconds
    :andThen(function()
        return ClientNetwork.request("periodicUpdate")
    end)
    :andThen(function(updateData)
        applyUpdate(updateData)
    end)
```

### Request Retry with Exponential Backoff

```lua
local function requestWithRetry(action, data, maxAttempts)
    local attempts = 0

    local function tryRequest()
        attempts += 1

        return ClientNetwork.request(action, data)
            :catch(function(error)
                if attempts < maxAttempts then
                    local delay = math.pow(2, attempts - 1) -- Exponential backoff
                    Debug.network(`Request failed (attempt ${attempts}), retrying in ${delay}s...`)

                    return Promise.delay(delay)
                        :andThen(tryRequest)
                else
                    return Promise.reject(`Request failed after ${maxAttempts} attempts: ${error}`)
                end
            end)
    end

    return tryRequest()
end

-- Usage
requestWithRetry("importantAction", {data = "critical"}, 3)
    :andThen(function(result)
        print("Request succeeded:", result)
    end)
    :catch(function(error)
        warn("Request failed permanently:", error)
    end)
```

## Configuration

Update `src/shared/shared-config.luau` to customize network settings:

```lua
Network = {
    maxRequestRate = 30,        -- Requests per second
    requestTimeout = 30,        -- Request timeout in seconds
    maxRequestAge = 30,         -- Max age for replay protection
    throttleInterval = 0.1,     -- Min time between client requests
    enableRateLimiting = true,  -- Enable/disable rate limiting
    enableRequestLogging = true, -- Enable/disable request logging
}
```

## Security Best Practices

### ✅ DO

- Always validate input on the server
- Use helper functions from server-config for sensitive data
- Return meaningful error messages
- Use middleware for common validation logic
- Check player permissions before sensitive operations
- Validate request structure and data types

### ❌ DON'T

- Trust any data from the client
- Send sensitive server data to clients
- Skip validation for "trusted" actions
- Use client-determined values for game logic
- Allow unlimited request rates
- Expose internal server errors to clients

## Error Handling

```lua
-- Server handler with proper error handling
ServerNetwork.handle("complexAction", function(player: Player, data: any?)
    -- Validate input
    if not data or type(data) ~= "table" then
        return false, nil, "Invalid data format"
    end

    -- Check permissions
    if not hasPermission(player, "complexAction") then
        return false, nil, "Insufficient permissions"
    end

    -- Perform action with error protection
    local success, result = pcall(function()
        return performComplexOperation(player, data)
    end)

    if not success then
        -- Log error internally but don't expose to client
        Debug.error(`Complex action failed for ${player.Name}: ${result}`)
        return false, nil, "Operation failed"
    end

    return true, result, nil
end)
```

## Integration with ECS

```lua
-- Using ECS components in network handlers
ServerNetwork.handle("getPlayerStats", function(player: Player, data: any?)
    -- Query ECS world for player data
    local playerQuery = world:query(components.Player, components.Stats)

    for playerEntity, userId, stats in playerQuery do
        if userId == player.UserId then
            return true, {
                level = stats.level,
                experience = stats.experience,
                -- Only send safe, non-sensitive data
            }, nil
        end
    end

    return false, nil, "Player stats not found"
end)
```

## Monitoring and Debugging

```lua
-- Get network statistics
local stats = ServerNetwork.getStats()
print("Handlers registered:", stats.handlersRegistered)
print("Middleware count:", stats.globalMiddlewareCount)

-- Enable/disable network debugging
Debug.enableCategory("network")
Debug.disableCategory("network")
```

## File Structure

```
src/
├── client/
│   └── network.luau           # Client network module
├── server/
│   ├── network.luau           # Server network module
│   └── server-systems/
│       └── network-handler.luau # Example server system
└── shared/
    ├── network.luau           # Shared utilities and types
    └── shared-config.luau     # Network configuration
```

This network system provides a secure, scalable foundation for all client-server communication in your Roblox ECS project.
