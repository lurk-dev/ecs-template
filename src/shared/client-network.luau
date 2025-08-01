--!strict
-- Client Network System - Secure Request Sending
-- Handles all client-to-server communication with middleware support

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Promise = require(ReplicatedStorage.Packages.promise)
local Network = require(ReplicatedStorage.Shared.network)
local Debug = require(ReplicatedStorage.Shared.debug)
local _clientConfig = require(ReplicatedStorage.Shared["client-config"])

export type NetworkResponse = Network.NetworkResponse
export type Middleware = Network.Middleware
export type MiddlewareContext = Network.MiddlewareContext

local ClientNetwork = {}

-- Client state
local isInitialized = false
local pendingRequests: {[string]: {resolve: (NetworkResponse) -> (), reject: (string) -> (), timeout: number}} = {}
local globalMiddleware: {Middleware} = {}
local responseHandlers: {[string]: (any?) -> ()} = {}

-- RemoteEvents
local requestRemote: RemoteEvent
local responseRemote: RemoteEvent

-- Initialize client network system
function ClientNetwork.init()
    if not RunService:IsClient() then
        error("ClientNetwork can only be initialized on the client")
    end
    
    if isInitialized then
        Debug.warn("ClientNetwork already initialized")
        return
    end
    
    -- Wait for RemoteEvents
    requestRemote = ReplicatedStorage:WaitForChild("NetworkRequest", 10) :: RemoteEvent
    responseRemote = ReplicatedStorage:WaitForChild("NetworkResponse", 10) :: RemoteEvent
    
    if not requestRemote or not responseRemote then
        error("Failed to find network RemoteEvents")
    end
    
    -- Setup default middleware
    ClientNetwork.use(Network.createLoggingMiddleware("CLIENT"))
    
    -- Connect response handler
    responseRemote.OnClientEvent:Connect(function(response: any)
        ClientNetwork.handleResponse(response)
    end)
    
    -- Cleanup old pending requests
    task.spawn(function()
        while isInitialized do
            local currentTime = tick()
            for requestId, pendingRequest in pendingRequests do
                if currentTime > pendingRequest.timeout then
                    pendingRequest.reject("Request timeout")
                    pendingRequests[requestId] = nil
                    Debug.network(`Request timeout: ${requestId}`)
                end
            end
            task.wait(5) -- Check every 5 seconds
        end
    end)
    
    isInitialized = true
    Debug.system("Client network system initialized")
end

-- Register global middleware (runs for all requests)
function ClientNetwork.use(middleware: Middleware)
    table.insert(globalMiddleware, middleware)
    Debug.system(`Registered client middleware: ${tostring(middleware)}`)
end

-- Register response handler for server-initiated messages
function ClientNetwork.onServerMessage(action: string, handler: (data: any?) -> ())
    responseHandlers[action] = handler
    Debug.system(`Registered response handler for: ${action}`)
    
    -- Return a connection-like object that can be used to disconnect
    return {
        Disconnect = function()
            responseHandlers[action] = nil
            Debug.system(`Unregistered response handler for: ${action}`)
        end
    }
end

-- Send request to server with Promise interface
function ClientNetwork.request(action: string, data: any?, timeout: number?)
    if not isInitialized then
        error("ClientNetwork not initialized. Call ClientNetwork.init() first")
    end
    
    local actualTimeout = timeout or 30 -- Default 30 second timeout
    local request = Network.createRequest(action, data)
    
    return Promise.new(function(resolve, reject)
        -- Create middleware context
        local context: MiddlewareContext = {
            player = nil, -- Not applicable on client
            request = request,
            response = nil,
            cancel = false,
            metadata = {},
        }
        
        -- Add request validation as final middleware
        local allMiddleware = {}
        for _, middleware in globalMiddleware do
            table.insert(allMiddleware, middleware)
        end
        
        -- Add request sending as final "middleware"
        table.insert(allMiddleware, function(ctx: MiddlewareContext, next: () -> ())
            if ctx.cancel then
                return
            end
            
            -- Store pending request for response handling
            pendingRequests[request.requestId] = {
                resolve = resolve,
                reject = reject,
                timeout = tick() + actualTimeout,
            }
            
            -- Send request to server
            local success, error = pcall(function()
                requestRemote:FireServer(request)
            end)
            
            if not success then
                pendingRequests[request.requestId] = nil
                reject(`Failed to send request: ${error}`)
                return
            end
            
            Debug.network(`Sent request: ${request.action} (${request.requestId})`)
        end)
        
        -- Execute middleware chain
        Network.executeMiddleware(allMiddleware, context)
        
        -- If cancelled by middleware, reject immediately
        if context.cancel then
            reject("Request cancelled by middleware")
        end
    end)
end

-- Handle response from server
function ClientNetwork.handleResponse(response: any)
    if not Network.validateRequest({action="", timestamp=0, requestId=""}) then
        -- Use simpler validation for responses
        if type(response) ~= "table" or not response.requestId then
            Debug.network("Invalid response format")
            return
        end
    end
    
    local requestId = response.requestId
    
    -- Check if this is a response to a pending request
    local pendingRequest = pendingRequests[requestId]
    if pendingRequest then
        pendingRequests[requestId] = nil
        
        if response.success then
            pendingRequest.resolve(response)
            Debug.network(`Received success response: ${requestId}`)
        else
            pendingRequest.reject(response.error or "Unknown error")
            Debug.network(`Received error response: ${requestId} - ${response.error or "Unknown"}`)
        end
        return
    end
    
    -- Check if this is a server-initiated message
    if response.success and response.data and type(response.data) == "table" then
        local messageData = response.data
        if messageData.action then
            local handler = responseHandlers[messageData.action]
            if handler then
                local success, error = pcall(function()
                    handler(messageData.data)
                end)
                if not success then
                    Debug.error(`Error in response handler for ${messageData.action}: ${error}`)
                end
                return
            end
        end
    end
    
    Debug.network(`Unhandled response: ${requestId}`)
end

-- Built-in client middleware: Request throttling
function ClientNetwork.createThrottleMiddleware(minInterval: number): Middleware
    local lastRequestTime = 0
    
    return function(context: MiddlewareContext, next: () -> ())
        local currentTime = tick()
        local timeSinceLastRequest = currentTime - lastRequestTime
        
        if timeSinceLastRequest < minInterval then
            Debug.network(`Request throttled (${timeSinceLastRequest}s < ${minInterval}s)`)
            context.cancel = true
            return
        end
        
        lastRequestTime = currentTime
        next()
    end
end

-- Built-in client middleware: Request retry
function ClientNetwork.createRetryMiddleware(maxRetries: number, retryDelay: number): Middleware
    return function(context: MiddlewareContext, next: () -> ())
        local attempts = 0
        local function attemptRequest()
            attempts += 1
            
            if attempts > maxRetries then
                context.cancel = true
                return
            end
            
            -- Add retry attempt to metadata
            context.metadata.attempt = attempts
            
            if attempts > 1 then
                Debug.network(`Retry attempt ${attempts}/${maxRetries} for ${context.request and context.request.action or "unknown"}`)
                task.wait(retryDelay)
            end
            
            next()
        end
        
        attemptRequest()
    end
end

-- Convenience methods for common actions
function ClientNetwork.ping()
    return ClientNetwork.request("ping")
end

function ClientNetwork.getServerData(dataType: string)
    return ClientNetwork.request("getData", {type = dataType})
end

-- Get client network statistics
function ClientNetwork.getStats(): {[string]: any}
    return {
        isInitialized = isInitialized,
        pendingRequests = 0,
        middlewareCount = #globalMiddleware,
        responseHandlers = 0,
    }
end

Debug.config("Client network module loaded")

return ClientNetwork