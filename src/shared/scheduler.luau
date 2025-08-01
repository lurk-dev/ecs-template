local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Planck = require(ReplicatedStorage.Packages.Planck)
local PlanckJabby = require(ReplicatedStorage.Packages.PlanckJabby)
local PlanckRunService = require(ReplicatedStorage.Packages.PlanckRunService)
local world = require(ReplicatedStorage.Shared.world)

local Scheduler = Planck.Scheduler
local jabbyPlugin = PlanckJabby.new()
local runServicePlugin = PlanckRunService.Plugin.new()

local scheduler = Scheduler.new(world)
	:addPlugin(jabbyPlugin)
	:addPlugin(runServicePlugin)

return scheduler