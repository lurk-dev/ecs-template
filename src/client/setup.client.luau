local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local startup = require(ReplicatedStorage.Shared.startup)

local systems = {}

local function addSystems(folder)
    for _, system in folder:GetChildren() do
        if not system:IsA("ModuleScript") then
            continue
        end

        table.insert(systems, require(system))
    end
end

local function addTestSystems(folder)
    local testsFolder = folder:FindFirstChild("tests")
    if testsFolder then
        addSystems(testsFolder)
    end
end

-- Load production systems
addSystems(ReplicatedStorage.Shared["client-systems"])
addSystems(ReplicatedStorage.Shared["shared-systems"])

-- Load test systems only in Studio
if RunService:IsStudio() then
    addTestSystems(ReplicatedStorage.Shared["client-systems"])
    addTestSystems(ReplicatedStorage.Shared["shared-systems"])
end

startup(systems)
