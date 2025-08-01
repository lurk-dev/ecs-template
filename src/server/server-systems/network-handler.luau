--!strict
-- Server Network Handler System - Example of Network System Usage
-- Demonstrates secure server-side request handling with middleware

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Planck = require(ReplicatedStorage.Packages.Planck)
local ServerNetwork = require(script.Parent.Parent.network)
local Debug = require(ReplicatedStorage.Shared.debug)
local components = require(ReplicatedStorage.Shared.components)
local world = require(ReplicatedStorage.Shared.world)

local Phase = Planck.Phase

local systemInitialized = false

-- Example handlers
local function handlePing(player: Player, data: any?): (boolean, any?, string?)
    Debug.network(`Ping from ${player.Name}`)
    return true, {
        message = `Pong from server!`,
        timestamp = tick(),
        playerName = player.Name
    }, nil
end

local function handleGetPlayerData(player: Player, data: any?): (boolean, any?, string?)
    Debug.network(`Player data request from ${player.Name}`)
    
    -- Find player entity using the player bridge system
    local playerQuery = world:query(components.Player, components.PlayerData)
    
    for playerEntity, userId, playerData in playerQuery do
        if userId == player.UserId then
            return true, {
                name = playerData.name,
                -- Add more data as needed
            }, nil
        end
    end
    
    return false, nil, "Player data not found"
end

local function handleUpdatePlayerSetting(player: Player, data: any?): (boolean, any?, string?)
    if not data or type(data) ~= "table" then
        return false, nil, "Invalid data format"
    end
    
    local setting = data.setting
    local value = data.value
    
    -- Validate setting name (whitelist approach)
    local validSettings = {
        displayName = true,
        preferredColor = true,
        -- Add more valid settings
    }
    
    if not validSettings[setting] then
        return false, nil, "Invalid setting name"
    end
    
    Debug.network(`Setting update from ${player.Name}: ${setting} = ${tostring(value)}`)
    
    -- Update player data in ECS
    local playerQuery = world:query(components.Player, components.PlayerData)
    
    for playerEntity, userId, playerData in playerQuery do
        if userId == player.UserId then
            -- Create updated player data
            local newPlayerData = {}
            for key, existingValue in playerData do
                newPlayerData[key] = existingValue
            end
            newPlayerData[setting] = value
            
            world:set(playerEntity, components.PlayerData, newPlayerData)
            
            -- Notify all clients of the update
            ServerNetwork.broadcast("playerDataUpdated", {
                playerId = player.UserId,
                setting = setting,
                value = value
            })
            
            return true, {setting = setting, value = value}, nil
        end
    end
    
    return false, nil, "Player not found"
end

-- Custom middleware for logging player actions
local function createPlayerActionLoggingMiddleware(): ServerNetwork.Middleware
    return function(context: ServerNetwork.MiddlewareContext, next: () -> ())
        if context.request and context.player then
            Debug.gameplay(`Action: ${context.request.action} by ${context.player.Name}`)
        end
        next()
    end
end

-- Admin-only handler example
local function handleAdminCommand(player: Player, data: any?): (boolean, any?, string?)
    if not data or type(data) ~= "table" or not data.command then
        return false, nil, "Invalid command format"
    end
    
    Debug.system(`Admin command from ${player.Name}: ${data.command}`)
    
    -- Execute admin command (placeholder)
    local command = data.command
    local result = `Executed command: ${command}`
    
    return true, {result = result}, nil
end

local function networkHandlerSystem()
    if systemInitialized then return end
    systemInitialized = true
    
    Debug.system("Initializing network handler system...")
    
    -- Initialize server network
    ServerNetwork.init()
    
    -- Register middleware
    ServerNetwork.use(createPlayerActionLoggingMiddleware())
    
    -- Register admin middleware for admin actions
    ServerNetwork.useForAction("adminCommand", ServerNetwork.createAdminMiddleware())
    
    -- Register handlers
    ServerNetwork.handle("ping", handlePing)
    ServerNetwork.handle("getPlayerData", handleGetPlayerData)
    ServerNetwork.handle("updatePlayerSetting", handleUpdatePlayerSetting)
    ServerNetwork.handle("adminCommand", handleAdminCommand)
    
    -- Example of sending data to all clients periodically
    task.spawn(function()
        local function broadcastStats()
            local serverStats = {
                playerCount = #Players:GetPlayers(),
                uptime = tick(),
                timestamp = tick()
            }
            
            ServerNetwork.broadcast("serverStats", serverStats)
        end
        
        -- Send stats every 60 seconds
        while true do
            task.wait(60)
            broadcastStats()
        end
    end)
    
    Debug.config("Network handler system initialized")
end

return {
    system = networkHandlerSystem,
    phase = Phase.Startup,
    name = "NetworkHandler"
}