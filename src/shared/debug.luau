--!strict
-- Generic Debug utility for consistent logging across client/server with configurable categories
-- Automatically detects context and formats messages with appropriate prefixes

local RunService = game:GetService("RunService")

local Debug = {}

-- Get debug config from shared config
local debugConfig = nil
local function getDebugConfig()
    if not debugConfig then
        local success, result = pcall(function()
            local ReplicatedStorage = game:GetService("ReplicatedStorage")
            local sharedConfig = require(ReplicatedStorage.Shared["shared-config"])
            return sharedConfig.Config.Debug
        end)
        if success then
            debugConfig = result
        else
            -- Fallback config if shared-config is not available
            debugConfig = {
                enableDebugPrints = true,
                categories = {
                    system = true, config = true, error = true,
                    gameplay = false, movement = false, interaction = false,
                    visual = false, network = false, ui = false,
                    target = false, search = false, link = false,
                    debug = false, info = false, success = false
                }
            }
        end
    end
    return debugConfig
end

-- Check if a debug category is enabled
local function isCategoryEnabled(category: string): boolean
    local config = getDebugConfig()
    
    -- Master toggle
    if not config.enableDebugPrints then
        return false
    end
    
    -- Category-specific toggle (default true if not specified)
    if config.categories then
        return config.categories[category] ~= false
    end
    
    return true
end

-- Detect if we're on client or server
local function getContext(): string
    if RunService:IsClient() then
        return "CLIENT"
    elseif RunService:IsServer() then
        return "SERVER"
    else
        return "UNKNOWN"
    end
end

-- Standard debug print with context
function Debug.print(...: any)
    if not isCategoryEnabled("debug") then return end
    local context = getContext()
    print(`[{context}]`, ...)
end

-- Info level (blue dot)
function Debug.info(...: any)
    if not isCategoryEnabled("info") then return end
    local context = getContext()
    print(`🔵 [{context}]:`, ...)
end

-- Success level (green checkmark)
function Debug.success(...: any)
    if not isCategoryEnabled("success") then return end
    local context = getContext()
    print(`✅ [{context}]:`, ...)
end

-- Warning level (yellow warning)
function Debug.warn(...: any)
    if not isCategoryEnabled("error") then return end
    local context = getContext()
    warn(`⚠️ [{context}]:`, ...)
end

-- Error level (red X) - always show errors
function Debug.error(...: any)
    if not isCategoryEnabled("error") then return end
    local context = getContext()
    error(`❌ [{context}]: ` .. tostring((...)))
end

-- Debug level (bug emoji)
function Debug.debug(...: any)
    if not isCategoryEnabled("debug") then return end
    local context = getContext()
    print(`🐛 [{context}]:`, ...)
end

-- Network/communication level (satellite)
function Debug.network(...: any)
    if not isCategoryEnabled("network") then return end
    local context = getContext()
    print(`📡 [{context}]:`, ...)
end

-- System/process level (gear)
function Debug.system(...: any)
    if not isCategoryEnabled("system") then return end
    local context = getContext()
    print(`⚙️ [{context}]:`, ...)
end

-- Target/action level (dart)
function Debug.target(...: any)
    if not isCategoryEnabled("target") then return end
    local context = getContext()
    print(`🎯 [{context}]:`, ...)
end

-- Search/scan level (magnifying glass)
function Debug.search(...: any)
    if not isCategoryEnabled("search") then return end
    local context = getContext()
    print(`🔍 [{context}]:`, ...)
end

-- Link/connection level (link)
function Debug.link(...: any)
    if not isCategoryEnabled("link") then return end
    local context = getContext()
    print(`🔗 [{context}]:`, ...)
end

-- Configuration level (wrench)
function Debug.config(...: any)
    if not isCategoryEnabled("config") then return end
    local context = getContext()
    print(`🔧 [{context}]:`, ...)
end

-- Generic category-specific functions
function Debug.gameplay(...: any)
    if not isCategoryEnabled("gameplay") then return end
    local context = getContext()
    print(`🎮 [{context}]:`, ...)
end

function Debug.movement(...: any)
    if not isCategoryEnabled("movement") then return end
    local context = getContext()
    print(`🏃 [{context}]:`, ...)
end

function Debug.interaction(...: any)
    if not isCategoryEnabled("interaction") then return end
    local context = getContext()
    print(`🤝 [{context}]:`, ...)
end

function Debug.visual(...: any)
    if not isCategoryEnabled("visual") then return end
    local context = getContext()
    print(`🎨 [{context}]:`, ...)
end

function Debug.ui(...: any)
    if not isCategoryEnabled("ui") then return end
    local context = getContext()
    print(`🖥️ [{context}]:`, ...)
end

-- Get current context string (useful for conditional logic)
function Debug.getContext(): string
    return getContext()
end

-- Check if running on client
function Debug.isClient(): boolean
    return RunService:IsClient()
end

-- Check if running on server
function Debug.isServer(): boolean
    return RunService:IsServer()
end

-- Basic utility functions for debug management
function Debug.enableCategory(category: string)
    local config = getDebugConfig()
    if config.categories then
        config.categories[category] = true
        print(`🔧 Debug: Enabled category '${category}'`)
    end
end

function Debug.disableCategory(category: string)
    local config = getDebugConfig()
    if config.categories then
        config.categories[category] = false
        print(`🔧 Debug: Disabled category '${category}'`)
    end
end

function Debug.listCategories()
    local config = getDebugConfig()
    print("🔧 Debug Categories:")
    if config.categories then
        for category, enabled in pairs(config.categories) do
            local status = enabled and "✅" or "❌"
            print(`  ${status} ${category}`)
        end
    end
end

function Debug.enableOnlyCategory(category: string)
    local config = getDebugConfig()
    if config.categories then
        -- Disable all categories
        for cat, _ in pairs(config.categories) do
            config.categories[cat] = false
        end
        -- Enable only the specified category (and core categories)
        config.categories[category] = true
        config.categories.system = true
        config.categories.config = true
        config.categories.error = true
        print(`🔧 Debug: Enabled only '${category}' (plus core categories)`)
    end
end

return Debug