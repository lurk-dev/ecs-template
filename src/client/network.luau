--!strict
-- Client Network - Re-export of shared client network module
-- This allows client scripts to use a familiar import path

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Re-export the shared client network module
return require(ReplicatedStorage.Shared["client-network"])