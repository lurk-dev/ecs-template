--!strict
-- Example Shared Test System
-- This system demonstrates how to create test systems that run on both client and server in Studio

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Planck = require(ReplicatedStorage.Packages.Planck)
local Debug = require(ReplicatedStorage.Shared.debug)

local Phase = Planck.Phase

local systemInitialized = false

local function sharedTestSystem()
    if systemInitialized then return end
    systemInitialized = true
    
    local context = RunService:IsClient() and "CLIENT" or "SERVER"
    Debug.system(`🧪 Shared Test System initialized on {context} (Studio only)`)
    
    -- Example test functionality that works on both client and server
    task.spawn(function()
        task.wait(5) -- Wait 5 seconds after startup
        Debug.info(`🧪 Shared test system active on {context}`)
    end)
end

return {
    system = sharedTestSystem,
    phase = Phase.Startup,
    name = "SharedTestExample"
}