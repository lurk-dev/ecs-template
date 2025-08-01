local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

addSystems(ReplicatedStorage.Shared["client-systems"])
addSystems(ReplicatedStorage.Shared["shared-systems"])

startup(systems)
