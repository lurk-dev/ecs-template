--!strict
-- Shared Network System - Types, Utilities, and Common Middleware
-- Provides secure networking foundation with middleware support

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Debug = require(ReplicatedStorage.Shared.debug)
local sharedConfig = require(ReplicatedStorage.Shared["shared-config"])

-- Network Types
export type NetworkRequest = {
    action: string,
    data: any?,
    timestamp: number,
    requestId: string,
}

export type NetworkResponse = {
    success: boolean,
    data: any?,
    error: string?,
    requestId: string,
}

export type MiddlewareContext = {
    player: Player?,
    request: NetworkRequest?,
    response: NetworkResponse?,
    cancel: boolean,
    metadata: {[string]: any},
}

export type Middleware = (context: MiddlewareContext, next: () -> ()) -> ()

export type NetworkHandler = (player: Player, data: any?) -> (boolean, any?, string?)

local Network = {}

-- Generate unique request ID
function Network.generateRequestId(): string
    return `{tick()}_{math.random(1000, 9999)}`
end

-- Validate request structure
function Network.validateRequest(request: any): boolean
    if type(request) ~= "table" then
        return false
    end
    
    if type(request.action) ~= "string" or #request.action == 0 then
        return false
    end
    
    if type(request.timestamp) ~= "number" then
        return false
    end
    
    if type(request.requestId) ~= "string" or #request.requestId == 0 then
        return false
    end
    
    return true
end

-- Create standardized network request
function Network.createRequest(action: string, data: any?): NetworkRequest
    return {
        action = action,
        data = data,
        timestamp = tick(),
        requestId = Network.generateRequestId(),
    }
end

-- Create standardized network response
function Network.createResponse(success: boolean, data: any?, error: string?, requestId: string): NetworkResponse
    return {
        success = success,
        data = data,
        error = error,
        requestId = requestId,
    }
end

-- Built-in Middleware: Request Logging
function Network.createLoggingMiddleware(category: string): Middleware
    return function(context: MiddlewareContext, next: () -> ())
        if context.request then
            Debug.network(`${category}: ${context.request.action} from ${context.player and context.player.Name or "Unknown"}`)
        end
        
        next()
        
        if context.response then
            local status = context.response.success and "SUCCESS" or "FAILED"
            Debug.network(`${category}: ${context.request and context.request.action or "Unknown"} -> ${status}`)
        end
    end
end

-- Built-in Middleware: Request Validation
function Network.createValidationMiddleware(): Middleware
    return function(context: MiddlewareContext, next: () -> ())
        if context.request and not Network.validateRequest(context.request) then
            Debug.network("Invalid request structure")
            context.cancel = true
            context.response = Network.createResponse(false, nil, "Invalid request format", context.request.requestId or "unknown")
            return
        end
        
        next()
    end
end

-- Built-in Middleware: Rate Limiting
function Network.createRateLimitMiddleware(): Middleware
    local playerRequestTimes: {[Player]: {number}} = {}
    local maxRequestRate = sharedConfig.Config.Network.maxRequestRate or 30
    
    return function(context: MiddlewareContext, next: () -> ())
        if not context.player then
            next()
            return
        end
        
        local player = context.player
        local currentTime = tick()
        
        -- Initialize player request history
        if not playerRequestTimes[player] then
            playerRequestTimes[player] = {}
        end
        
        local requestHistory = playerRequestTimes[player]
        
        -- Remove old requests (older than 1 second)
        for i = #requestHistory, 1, -1 do
            if currentTime - requestHistory[i] > 1 then
                table.remove(requestHistory, i)
            end
        end
        
        -- Check rate limit
        if #requestHistory >= maxRequestRate then
            Debug.network(`Rate limit exceeded for player: ${player.Name}`)
            context.cancel = true
            context.response = Network.createResponse(false, nil, "Rate limit exceeded", context.request and context.request.requestId or "unknown")
            return
        end
        
        -- Add current request to history
        table.insert(requestHistory, currentTime)
        
        next()
        
        -- Clean up on player leaving
        if not Players:FindFirstChild(player.Name) then
            playerRequestTimes[player] = nil
        end
    end
end

-- Middleware chain executor
function Network.executeMiddleware(middlewares: {Middleware}, context: MiddlewareContext): ()
    local currentIndex = 1
    
    local function next()
        if currentIndex <= #middlewares and not context.cancel then
            local middleware = middlewares[currentIndex]
            currentIndex += 1
            middleware(context, next)
        end
    end
    
    next()
end

-- Common network event names from config
function Network.getEventName(eventType: string): string
    local events = sharedConfig.Config.Network.events
    for _, event in events do
        if event:lower():find(eventType:lower()) then
            return event
        end
    end
    return eventType -- Fallback to provided name
end

-- Context helpers
function Network.isServer(): boolean
    return RunService:IsServer()
end

function Network.isClient(): boolean
    return RunService:IsClient()
end

print("🌐 Shared network system loaded")

return Network