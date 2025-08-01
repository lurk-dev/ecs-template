--!strict
-- Network Test Runner - Simple script to run network tests
-- Place this in StarterPlayer/StarterPlayerScripts to test networking

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Wait for shared systems to be available
ReplicatedStorage:WaitForChild("Shared")

-- Import the network test system (for side effects)
local _networkTests = require(ReplicatedStorage.Shared["client-systems"]["network-tests"])

-- The test system will automatically run on startup
-- You can also press F5 to manually run tests again

print("🧪 Network Test Runner loaded - Tests will run automatically")
print("🔄 Press F5 to manually run tests again")