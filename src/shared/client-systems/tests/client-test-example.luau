--!strict
-- Example Client Test System
-- This system demonstrates how to create test systems that only run in Studio

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Planck = require(ReplicatedStorage.Packages.Planck)
local Debug = require(ReplicatedStorage.Shared.debug)

local Phase = Planck.Phase

local systemInitialized = false

local function clientTestSystem()
    if systemInitialized then return end
    systemInitialized = true
    
    Debug.system("🧪 Client Test System initialized (Studio only)")
    
    -- Example: Bind a test key
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.F6 then
            Debug.info("🧪 F6 pressed - Client test triggered")
        end
    end)
    
    Debug.config("🧪 Press F6 to trigger client test")
end

return {
    system = clientTestSystem,
    phase = Phase.Startup,
    name = "ClientTestExample"
}