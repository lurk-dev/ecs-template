local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Jecs = require(ReplicatedStorage.Packages.jecs)
local world = require(ReplicatedStorage.Shared.world)
local mk = require(ReplicatedStorage.Shared.mk)

return {
	Player = mk.mkComponent(world, "Player"),
	PlayerData = mk.mkComponent(world, "PlayerData"),
	Possesses = mk.mkComponent(world, "Possesses"),
}
