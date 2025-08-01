--!strict
-- SHARED Configuration - Generic Template
-- Contains data that both client and server need access to
-- NO SENSITIVE BALANCE DATA - only display info and coordination constants

-- SHARED CONFIGURATION
-- Safe for both client and server access
local SharedConfig = {
    -- Basic Game Limits (coordination between client/server)
    Limits = {},
    
    -- Network Configuration (coordination between client/server)
    Network = {
        -- Core RemoteEvents (automatically created by network system)
        remoteEvents = {
            request = "NetworkRequest",
            response = "NetworkResponse",
        },
        
        -- Common action names (for reference and validation)
        actions = {
            "ping",
            "getData",
            "playerAction",
            "updateData",
            "stateChange",
        },
        
        -- Action validation set
        validActions = {
            ping = true,
            getData = true,
            playerAction = true,
            updateData = true,
            stateChange = true,
        },
        
        -- Network timing constraints
        maxRequestRate = 30,        -- Requests per second (rate limiting)
        requestTimeout = 30,        -- Seconds before request times out
        maxRequestAge = 30,         -- Maximum age of requests (replay protection)
        throttleInterval = 0.1,     -- Minimum time between client requests
        heartbeatInterval = 5,      -- Seconds between heartbeats
        
        -- Security settings
        enableTimestampValidation = true,   -- Validate request timestamps
        enableRateLimiting = true,          -- Enable rate limiting middleware
        enableRequestLogging = true,        -- Log network requests
    },
    
    -- World Coordination
    World = {
        spawnHeight = 10,           -- Height for spawning entities
        maxRenderDistance = 100,    -- Maximum render distance
    },
    
    -- Error Messages (both sides show to players)
    Messages = {
        errors = {
            outOfRange = "Target is out of range!",
            invalidTarget = "Invalid target!",
            actionFailed = "Action failed!",
        },
        
        success = {
            actionCompleted = "Action completed successfully!",
            dataUpdated = "Data updated!",
        }
    },
    
    -- Debug Settings (configurable debug categories)
    Debug = {
        enableDebugPrints = true,      -- Master toggle for debug output
        categories = {
            -- Core Categories (minimized for production)
            system = false,            -- System messages (disabled to reduce noise)
            config = false,            -- Configuration messages (disabled to reduce noise)
            error = true,              -- Error messages (keep enabled)
            
            -- Gameplay Categories (toggle as needed)
            gameplay = false,          -- Core game mechanics (disabled by default)
            movement = false,          -- Movement and positioning (usually disable)
            interaction = false,       -- Player interactions
            
            -- Visual Categories (usually disable)
            visual = false,            -- Visual effects, UI updates
            network = false,           -- Network messages (usually disable)
            ui = false,                -- UI updates and changes
            
            -- Development Categories (enable when debugging specific issues)
            target = false,            -- Targeting and interaction detection
            search = false,            -- Search operations
            link = false,              -- Entity linking
            debug = false,             -- General debug info
            info = false,              -- Informational messages
            success = false,           -- Success confirmations
        }
    }
}

-- Helper functions for shared config access
local SharedConfigHelpers = {
    -- Display helpers
    getDisplayName = function(itemType: string)
        -- Generic display name helper - can be extended based on project needs
        return itemType or "Unknown"
    end,
    
    -- Message helpers
    getErrorMessage = function(errorType: string)
        return SharedConfig.Messages.errors[errorType] or "Unknown error"
    end,
    
    getSuccessMessage = function(successType: string)
        return SharedConfig.Messages.success[successType] or "Success!"
    end,
    
    -- Network helpers
    getNetworkTimeout = function()
        return SharedConfig.Network.requestTimeout
    end,
    
    getMaxRequestRate = function()
        return SharedConfig.Network.maxRequestRate
    end,
    
    isValidAction = function(action: string): boolean
        return SharedConfig.Network.validActions[action] == true
    end,
    
    getRemoteEventName = function(eventType: string): string
        return SharedConfig.Network.remoteEvents[eventType] or eventType
    end,
    
    -- Debug helpers
    enableDebugCategory = function(category: string)
        if SharedConfig.Debug.categories then
            SharedConfig.Debug.categories[category] = true
            print(`🔧 Debug: Enabled category '${category}'`)
        end
    end,
    
    disableDebugCategory = function(category: string)
        if SharedConfig.Debug.categories then
            SharedConfig.Debug.categories[category] = false
            print(`🔧 Debug: Disabled category '${category}'`)
        end
    end,
    
    listDebugCategories = function()
        print("🔧 Debug Categories:")
        if SharedConfig.Debug.categories then
            for category, enabled in pairs(SharedConfig.Debug.categories) do
                local status = enabled and "✅" or "❌"
                print(`  ${status} ${category}`)
            end
        end
    end,
    
    -- Quick debug presets
    debugOnlyCore = function()
        -- Disable all categories except core ones
        for category, _ in pairs(SharedConfig.Debug.categories) do
            SharedConfig.Debug.categories[category] = false
        end
        SharedConfig.Debug.categories.system = true
        SharedConfig.Debug.categories.config = true
        SharedConfig.Debug.categories.error = true
        print("🔧 Debug: Enabled only core categories")
    end,
    
    debugQuiet = function()
        -- Only essential system messages
        for category, _ in pairs(SharedConfig.Debug.categories) do
            SharedConfig.Debug.categories[category] = false
        end
        SharedConfig.Debug.categories.system = true
        SharedConfig.Debug.categories.error = true
        print("🔧 Debug: Quiet mode enabled")
    end,
    
    debugVerbose = function()
        -- Enable all categories
        for category, _ in pairs(SharedConfig.Debug.categories) do
            SharedConfig.Debug.categories[category] = true
        end
        print("🔧 Debug: Verbose mode enabled")
    end,
}

-- Initialize and display shared configuration (minimized)
local function displayConfigInfo()
    -- Only show config loading in verbose mode
    if SharedConfig.Debug.categories.config then
        print("🤝 Shared configuration loaded!")
        
        -- Get enabled debug categories for display
        local enabledCategories = {}
        for category, enabled in pairs(SharedConfig.Debug.categories) do
            if enabled then
                table.insert(enabledCategories, category)
            end
        end
        if #enabledCategories > 0 then
            print("🔧 Debug categories enabled:", table.concat(enabledCategories, ", "))
        end
    end
end

-- Display config info on load
displayConfigInfo()

-- Export shared configuration
return {
    Config = SharedConfig,
    Helpers = SharedConfigHelpers,
}