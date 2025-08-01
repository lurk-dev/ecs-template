--!strict
-- CLIENT Configuration - Client-Specific Settings
-- Contains client-side settings and preferences
-- NO SENSITIVE BALANCE DATA - only presentation and input settings

-- CLIENT CONFIGURATION
-- Safe for client access - no sensitive game balance data
local ClientConfig = {
    -- UI Layout Settings (client presentation)
    UI = {
        -- Add UI layout settings here
        -- Example: windowPadding = 10, buttonSize = UDim2.new(0, 100, 0, 30)
    },
    
    -- Input Bindings (client controls)
    Input = {
        -- Add input binding settings here
        -- Example: primaryAction = Enum.KeyCode.E, secondaryAction = Enum.KeyCode.F
    },
    
    -- Visual Preferences (client rendering)
    Visual = {
        -- Add visual preference settings here
        -- Example: particleCount = 50, effectQuality = "Medium", viewDistance = 100
    },
    
    -- Performance Settings (client optimization)
    Performance = {
        -- Add performance settings here
        -- Example: maxFrameRate = 60, renderDistance = 100, enableShadows = true
    }
}

-- Helper functions for client config access
local ClientConfigHelpers = {
    -- UI helpers
    getUISettings = function()
        return ClientConfig.UI
    end,
    
    getUISetting = function(key: string)
        return ClientConfig.UI[key]
    end,
    
    -- Input helpers
    getInputBindings = function()
        return ClientConfig.Input
    end,
    
    getInputBinding = function(action: string)
        return ClientConfig.Input[action]
    end,
    
    -- Visual helpers
    getVisualSettings = function()
        return ClientConfig.Visual
    end,
    
    getVisualSetting = function(key: string)
        return ClientConfig.Visual[key]
    end,
    
    -- Performance helpers
    getPerformanceSettings = function()
        return ClientConfig.Performance
    end,
    
    getPerformanceSetting = function(key: string)
        return ClientConfig.Performance[key]
    end,
}

print("🖥️ Client configuration loaded (client-specific settings)")

-- Export client configuration (accessible to clients)
return {
    Config = ClientConfig,
    Helpers = ClientConfigHelpers,
}