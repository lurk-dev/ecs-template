local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Planck = require(ReplicatedStorage.Packages.Planck)
local components = require(ReplicatedStorage.Shared.components)
local world = require(ReplicatedStorage.Shared.world)
local mk = require(ReplicatedStorage.Shared.mk)
local Debug = require(ReplicatedStorage.Shared.debug)

local Phase = Planck.Phase

local Player = components.Player
local PlayerData = components.PlayerData
local Possesses = components.Possesses

-- Create a component to hold our resource data
local PlayerEntityMap = mk.mkComponent(world, "PlayerEntityMap")

-- Reusable function for character cleanup (DRY principle)
local function cleanupCharacter(playerEntity)
    if world:has(playerEntity, Possesses) then
        local characterEntity = world:get(playerEntity, Possesses)
        if characterEntity then
            world:delete(characterEntity)
        end
        world:remove(playerEntity, Possesses)
    end
end

local function initCharacter(player, playerEntity, character)
    -- Debug.system("Initializing character for player:", player.Name) -- Commented out to reduce noise
    
    -- Defensive check for character validity
    if not character then
        Debug.error("Cannot initialize character - character is nil for player:", player.Name)
        return
    end
    
    -- Create a separate entity for the character
    local characterEntity = mk.mkEntity(world, "Character_" .. player.Name)
    
    -- Create relationship between player and character
    world:set(playerEntity, Possesses, characterEntity)
    
    -- Additional character initialization can be added here
end

local function initPlayer(player, playerEntityMap)
    -- Debug.system("Initializing player:", player.Name) -- Commented out to reduce noise
    
    local playerEntity = mk.mkEntity(world, "Player_" .. player.Name)
    
    -- Store data, not the player object directly
    world:set(playerEntity, Player, player.UserId)
    world:set(playerEntity, PlayerData, {
        name = player.Name,
        -- Additional player data fields can be added here
    })
    
    -- Store mapping for cleanup
    playerEntityMap[player] = playerEntity
    
    local function onCharacterAdded(character)
        initCharacter(player, playerEntity, character)
    end
    
    local function onCharacterRemoving(character)
        Debug.system("Character removed from player:", player.Name)
        cleanupCharacter(playerEntity)
    end
    
    if player.Character then
        onCharacterAdded(player.Character)
    end
    
    player.CharacterAdded:Connect(onCharacterAdded)
    player.CharacterRemoving:Connect(onCharacterRemoving)
end

local function onPlayerRemoving(player, playerEntityMap)
    Debug.system("Player leaving:", player.Name)
    
    local playerEntity = playerEntityMap[player]
    if playerEntity and world:has(playerEntity, Player) then
        -- Clean up character entity if it exists
        cleanupCharacter(playerEntity)
        
        -- Delete player entity
        world:delete(playerEntity)
        playerEntityMap[player] = nil
        Debug.system("Deleted entity for player:", player.Name)
    end
end

local function playerSetupSystem()
    -- Create a resource entity to hold our player entity map
    local resourceEntity = mk.mkEntity(world, "PlayerEntityMapResource")
    local playerEntityMap = {}
    world:set(resourceEntity, PlayerEntityMap, playerEntityMap)
    
    -- Connect event listeners FIRST to avoid race conditions
    Players.PlayerAdded:Connect(function(player)
        initPlayer(player, playerEntityMap)
    end)
    
    Players.PlayerRemoving:Connect(function(player)
        onPlayerRemoving(player, playerEntityMap)
    end)
    
    -- THEN process existing players
    for _, player in ipairs(Players:GetPlayers()) do
        initPlayer(player, playerEntityMap)
    end
end

return {
    system = playerSetupSystem,
    phase = Phase.Startup,
    name = "PlayerBridge"
}