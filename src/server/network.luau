--!strict
-- Server Network System - Secure Request Handling with Middleware
-- All network requests are validated and processed on the server for security

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Network = require(ReplicatedStorage.Shared.network)
local Debug = require(ReplicatedStorage.Shared.debug)
local serverConfig = require(script.Parent["server-config"])

export type NetworkHandler = Network.NetworkHandler
export type Middleware = Network.Middleware
export type MiddlewareContext = Network.MiddlewareContext

local ServerNetwork = {}

-- Registered handlers and middleware
local handlers: {[string]: NetworkHandler} = {}
local globalMiddleware: {Middleware} = {}
local actionMiddleware: {[string]: {Middleware}} = {}

-- RemoteEvents
local requestRemote: RemoteEvent
local responseRemote: RemoteEvent

-- Initialize server network system
function ServerNetwork.init()
    if not RunService:IsServer() then
        error("ServerNetwork can only be initialized on the server")
    end
    
    -- Create or get RemoteEvents
    requestRemote = ReplicatedStorage:FindFirstChild("NetworkRequest") or Instance.new("RemoteEvent")
    requestRemote.Name = "NetworkRequest"
    requestRemote.Parent = ReplicatedStorage
    
    responseRemote = ReplicatedStorage:FindFirstChild("NetworkResponse") or Instance.new("RemoteEvent")
    responseRemote.Name = "NetworkResponse"
    responseRemote.Parent = ReplicatedStorage
    
    -- Setup default middleware stack
    ServerNetwork.use(Network.createValidationMiddleware())
    ServerNetwork.use(Network.createRateLimitMiddleware())
    ServerNetwork.use(Network.createLoggingMiddleware("SERVER"))
    
    -- Connect request handler
    requestRemote.OnServerEvent:Connect(function(player: Player, request: any)
        ServerNetwork.handleRequest(player, request)
    end)
    
    -- Debug.system("Server network system initialized") -- Commented out to reduce noise
end

-- Register global middleware (runs for all requests)
function ServerNetwork.use(middleware: Middleware)
    table.insert(globalMiddleware, middleware)
    -- Removed verbose middleware registration logging
end

-- Register action-specific middleware
function ServerNetwork.useForAction(action: string, middleware: Middleware)
    if not actionMiddleware[action] then
        actionMiddleware[action] = {}
    end
    table.insert(actionMiddleware[action], middleware)
    -- Removed verbose action middleware registration logging
end

-- Register network action handler
function ServerNetwork.handle(action: string, handler: NetworkHandler)
    if handlers[action] then
        Debug.warn(`Overriding existing handler for action: ${action}`)
    end
    
    handlers[action] = handler
    -- Removed verbose handler registration logging
end

-- Built-in security middleware
function ServerNetwork.createSecurityMiddleware(): Middleware
    return function(context: MiddlewareContext, next: () -> ())
        local player = context.player
        local request = context.request
        
        if not player or not request then
            context.cancel = true
            context.response = Network.createResponse(false, nil, "Invalid request context", request and request.requestId or "unknown")
            return
        end
        
        -- Check if player is still in game
        if not Players:FindFirstChild(player.Name) then
            Debug.network(`Request from disconnected player: ${player.Name}`)
            context.cancel = true
            context.response = Network.createResponse(false, nil, "Player not connected", request.requestId)
            return
        end
        
        -- Timestamp validation (prevent replay attacks)
        local currentTime = tick()
        local requestAge = currentTime - request.timestamp
        local maxAge = 30 -- 30 seconds
        
        if requestAge > maxAge then
            Debug.network(`Stale request from ${player.Name}: ${requestAge}s old`)
            context.cancel = true
            context.response = Network.createResponse(false, nil, "Request too old", request.requestId)
            return
        end
        
        if requestAge < -5 then -- Allow small clock differences
            Debug.network(`Future request from ${player.Name}: ${requestAge}s in future`)
            context.cancel = true
            context.response = Network.createResponse(false, nil, "Invalid timestamp", request.requestId)
            return
        end
        
        next()
    end
end

-- Built-in admin check middleware
function ServerNetwork.createAdminMiddleware(): Middleware
    return function(context: MiddlewareContext, next: () -> ())
        local player = context.player
        
        if not player then
            context.cancel = true
            context.response = Network.createResponse(false, nil, "No player provided", "unknown")
            return
        end
        
        if not serverConfig.Helpers.isUserAdmin(player.UserId) then
            Debug.network(`Non-admin attempted admin action: ${player.Name}`)
            context.cancel = true
            context.response = Network.createResponse(false, nil, "Insufficient permissions", context.request and context.request.requestId or "unknown")
            return
        end
        
        next()
    end
end

-- Handle incoming network request
function ServerNetwork.handleRequest(player: Player, request: any)
    -- Create middleware context
    local context: MiddlewareContext = {
        player = player,
        request = request,
        response = nil,
        cancel = false,
        metadata = {},
    }
    
    -- Collect all middleware for this request
    local allMiddleware: {Middleware} = {}
    
    -- Add global middleware
    for _, middleware in globalMiddleware do
        table.insert(allMiddleware, middleware)
    end
    
    -- Add action-specific middleware
    if request and type(request) == "table" and request.action then
        local actionMw = actionMiddleware[request.action]
        if actionMw then
            for _, middleware in actionMw do
                table.insert(allMiddleware, middleware)
            end
        end
    end
    
    -- Add handler execution as final "middleware"
    table.insert(allMiddleware, function(ctx: MiddlewareContext, next: () -> ())
        if ctx.cancel or not ctx.request then
            return
        end
        
        local handler = handlers[ctx.request.action]
        if not handler then
            Debug.network(`No handler for action: ${ctx.request.action}`)
            ctx.response = Network.createResponse(false, nil, `Unknown action: ${ctx.request.action}`, ctx.request.requestId)
            return
        end
        
        -- Execute handler with error protection
        if not ctx.player then
            ctx.response = Network.createResponse(false, nil, "No player provided", ctx.request.requestId)
            return
        end
        
        local success, result, error = nil, nil, nil
        local handlerSuccess, handlerError = pcall(function()
            success, result, error = handler(ctx.player :: Player, ctx.request.data)
        end)
        
        if not handlerSuccess then
            Debug.error(`Handler error for ${ctx.request.action}: ${handlerError}`)
            ctx.response = Network.createResponse(false, nil, "Internal server error", ctx.request.requestId)
        else
            ctx.response = Network.createResponse(success, result, error, ctx.request.requestId)
        end
    end)
    
    -- Execute middleware chain
    Network.executeMiddleware(allMiddleware, context)
    
    -- Send response back to client
    if context.response then
        responseRemote:FireClient(player, context.response)
    else
        -- Fallback response if something went wrong
        local fallbackResponse = Network.createResponse(false, nil, "No response generated", 
            request and request.requestId or "unknown")
        responseRemote:FireClient(player, fallbackResponse)
    end
end

-- Broadcast message to all clients
function ServerNetwork.broadcast(action: string, data: any?)
    local response = Network.createResponse(true, {action = action, data = data}, nil, Network.generateRequestId())
    responseRemote:FireAllClients(response)
    Debug.network(`Broadcasted: ${action}`)
end

-- Send message to specific client
function ServerNetwork.sendToClient(player: Player, action: string, data: any?)
    local response = Network.createResponse(true, {action = action, data = data}, nil, Network.generateRequestId())
    responseRemote:FireClient(player, response)
    Debug.network(`Sent to ${player.Name}: ${action}`)
end

-- Get network statistics
function ServerNetwork.getStats(): {[string]: any}
    return {
        handlersRegistered = 0,
        globalMiddlewareCount = #globalMiddleware,
        actionMiddlewareCount = 0,
    }
end

-- Add default security middleware
ServerNetwork.use(ServerNetwork.createSecurityMiddleware())

-- Removed verbose module loading message

return ServerNetwork