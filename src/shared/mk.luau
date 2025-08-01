local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Jecs = require(ReplicatedStorage.Packages.jecs)

local function mkEntity(world, name)
    local newEntity = world:entity()
    world:set(newEntity, Jecs.Name, name .. "_E")
    return newEntity
end

local function mkComponent(world, name)
    local newComponent = world:component()
    world:set(newComponent, Jecs.Name, name .. "_C")
    return newComponent
end

local function mkTag(world, name)
    local newTag = world:tag()
    world:set(newTag, Jecs.Name, name .. "_T")
    return newTag
end

return {
	mkEntity = mkEntity,
	mkComponent = mkComponent,
	mkTag = mkTag,
}
