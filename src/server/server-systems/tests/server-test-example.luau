--!strict
-- Example Server Test System
-- This system demonstrates how to create test systems that only run in Studio

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Planck = require(ReplicatedStorage.Packages.Planck)
local Debug = require(ReplicatedStorage.Shared.debug)

local Phase = Planck.Phase

local systemInitialized = false

local function serverTestSystem()
    if systemInitialized then return end
    systemInitialized = true
    
    Debug.system("🧪 Server Test System initialized (Studio only)")
    
    -- Example test functionality
    task.spawn(function()
        while true do
            task.wait(30) -- Test every 30 seconds
            Debug.info("🧪 Server test heartbeat - system is running")
        end
    end)
end

return {
    system = serverTestSystem,
    phase = Phase.Startup,
    name = "ServerTestExample"
}