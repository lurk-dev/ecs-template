--!strict
-- SERVER Configuration - Server-Authoritative Data
-- Contains sensitive data that only the server should access
-- NEVER accessible to clients - prevents exploits and cheating

-- SERVER CONFIGURATION
-- Only accessible to server systems for security
local ServerConfig = {
    -- Game Balance (server-authoritative to prevent cheating)
    Balance = {
        -- Add game balance values here
        -- Example: baseDamage = 25, criticalMultiplier = 2.0
    },
    
    -- Server Settings (server-controlled behavior)
    Server = {
        -- Add server-specific settings here
        -- Example: spawnRate = 5, maxEntitiesPerPlayer = 100
    },
    
    -- Admin Settings (security-sensitive)
    Admin = {
        -- Add admin configuration here
        -- Example: whitelistedUserIds = {}, debugModeEnabled = false
    },
    
    -- Security Settings (validation rules, costs, rewards)
    Security = {
        -- Add security-sensitive data here
        -- Example: actionCooldowns = {}, validationRules = {}
    }
}

-- Helper functions for server config access
local ServerConfigHelpers = {
    -- Balance helpers
    getBalanceValue = function(key: string)
        return ServerConfig.Balance[key]
    end,
    
    -- Server settings helpers
    getServerSetting = function(key: string)
        return ServerConfig.Server[key]
    end,
    
    -- Admin helpers
    isUserAdmin = function(userId: number): boolean
        -- Implementation for admin checking
        return false -- Placeholder
    end,
    
    -- Security helpers
    validateAction = function(action: string, userId: number): boolean
        -- Implementation for action validation
        return true -- Placeholder
    end,
}

-- Removed verbose server config loading message

-- Export server configuration (only accessible to server)
return {
    Config = ServerConfig,
    Helpers = ServerConfigHelpers,
}