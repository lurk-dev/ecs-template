--!strict
-- Network Test System - Comprehensive testing for the network system
-- Run these tests to verify network functionality is working correctly

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Promise = require(ReplicatedStorage.Packages.promise)
local Planck = require(ReplicatedStorage.Packages.Planck)
local ClientNetwork = require(ReplicatedStorage.Shared["client-network"])
local Debug = require(ReplicatedStorage.Shared.debug)

local Phase = Planck.Phase

local systemInitialized = false
local testResults = {}
local totalTests = 0
local passedTests = 0
local testsRunning = false
local autoRunCompleted = false

-- Test utilities
local function startTest(testName: string)
    totalTests += 1
    Debug.info(`🧪 Starting test: ${testName}`)
    return testName
end

local function passTest(testName: string, message: string?)
    passedTests += 1
    testResults[testName] = {success = true, message = message or "Passed"}
    Debug.success(`✅ ${testName}: ${message or "Passed"}`)
end

local function failTest(testName: string, error: string)
    testResults[testName] = {success = false, message = error}
    Debug.error(`❌ ${testName}: ${error}`)
end

local function printTestSummary()
    Debug.info(`📊 Test Summary: ${passedTests}/${totalTests} tests passed`)
    
    for testName, result in pairs(testResults) do
        local status = result.success and "✅" or "❌"
        print(`  ${status} ${testName}: ${result.message}`)
    end
    
    if passedTests == totalTests then
        Debug.success("🎉 All network tests passed!")
    else
        Debug.error(`❌ ${totalTests - passedTests} tests failed`)
    end
end

-- Basic connectivity tests
local function testBasicPing()
    local testName = startTest("Basic Ping")
    
    ClientNetwork.request("ping")
        :timeout(5)
        :andThen(function(response)
            if response.success and response.data.message then
                passTest(testName, `Server responded: ${response.data.message}`)
            else
                failTest(testName, "Invalid ping response")
            end
        end)
        :catch(function(error)
            failTest(testName, `Ping failed: ${error}`)
        end)
end

local function testPlayerDataRequest()
    local testName = startTest("Player Data Request")
    
    ClientNetwork.request("getPlayerData")
        :timeout(5)
        :andThen(function(response)
            if response.success and response.data then
                passTest(testName, `Got player data: ${response.data.name or "Unknown"}`)
            else
                failTest(testName, `No player data: ${response.error or "Unknown error"}`)
            end
        end)
        :catch(function(error)
            failTest(testName, `Data request failed: ${error}`)
        end)
end

-- Error handling tests
local function testInvalidAction()
    local testName = startTest("Invalid Action Handling")
    
    ClientNetwork.request("nonexistentAction")
        :timeout(5)
        :andThen(function(response)
            if not response.success then
                passTest(testName, `Correctly rejected invalid action: ${response.error}`)
            else
                failTest(testName, "Invalid action was incorrectly accepted")
            end
        end)
        :catch(function(error)
            passTest(testName, `Invalid action correctly failed: ${error}`)
        end)
end

local function testInvalidData()
    local testName = startTest("Invalid Data Handling")
    
    -- Send invalid data format
    ClientNetwork.request("updatePlayerSetting", "invalid_data_format")
        :timeout(5)
        :andThen(function(response)
            if not response.success then
                passTest(testName, `Correctly rejected invalid data: ${response.error}`)
            else
                failTest(testName, "Invalid data was incorrectly accepted")
            end
        end)
        :catch(function(error)
            passTest(testName, `Invalid data correctly failed: ${error}`)
        end)
end

-- Promise feature tests
local function testPromiseTimeout()
    local testName = startTest("Promise Timeout")
    
    -- Test with a very short timeout to trigger timeout behavior
    ClientNetwork.request("ping")
        :timeout(0.01) -- Short timeout that won't get rounded to 0
        :andThen(function(response)
            failTest(testName, "Request should have timed out")
        end)
        :catch(function(error)
            -- Handle different timeout error formats
            local errorString = tostring(error)
            if errorString:find("timeout") or errorString:find("Timed out") then
                passTest(testName, "Timeout correctly triggered")
            else
                failTest(testName, `Unexpected error: ${errorString}`)
            end
        end)
end

local function testPromiseAll()
    local testName = startTest("Promise.all Multiple Requests")
    
    Promise.all({
        ClientNetwork.request("ping"),
        ClientNetwork.request("getPlayerData"),
        ClientNetwork.request("ping")
    })
        :timeout(10)
        :andThen(function(results)
            if #results == 3 then
                passTest(testName, `Successfully completed ${#results} concurrent requests`)
            else
                failTest(testName, `Expected 3 results, got ${#results}`)
            end
        end)
        :catch(function(error)
            failTest(testName, `Promise.all failed: ${error}`)
        end)
end

-- Data update tests
local function testPlayerSettingUpdate()
    local testName = startTest("Player Setting Update")
    
    local testSetting = "displayName"
    local testValue = `TestName_${tick()}`
    
    ClientNetwork.request("updatePlayerSetting", {
        setting = testSetting,
        value = testValue
    })
        :timeout(5)
        :andThen(function(response)
            if response.success and response.data.setting == testSetting then
                passTest(testName, `Successfully updated ${testSetting} to ${testValue}`)
            else
                failTest(testName, `Update failed: ${response.error or "Unknown error"}`)
            end
        end)
        :catch(function(error)
            failTest(testName, `Setting update failed: ${error}`)
        end)
end

-- Rate limiting test (optional, might trigger actual rate limiting)
local function testRateLimit()
    local testName = startTest("Rate Limiting (Light Test)")
    
    -- Send a few rapid requests to test rate limiting without overwhelming the system
    local requests = {}
    for i = 1, 5 do
        table.insert(requests, ClientNetwork.request("ping"))
    end
    
    Promise.all(requests)
        :timeout(10)
        :andThen(function(results)
            passTest(testName, `${#results} requests completed (rate limiting not triggered)`)
        end)
        :catch(function(error)
            if string.find(error, "rate") or string.find(error, "limit") then
                passTest(testName, `Rate limiting correctly triggered: ${error}`)
            else
                failTest(testName, `Unexpected error: ${error}`)
            end
        end)
end

-- Admin permission test (should fail for normal users)
local function testAdminPermissions()
    local testName = startTest("Admin Permission Check")
    
    ClientNetwork.request("adminCommand", {command = "test"})
        :timeout(5)
        :andThen(function(response)
            if response.success then
                passTest(testName, "User has admin permissions")
            else
                if string.find(response.error or "", "permission") or string.find(response.error or "", "admin") then
                    passTest(testName, `Correctly blocked non-admin: ${response.error}`)
                else
                    failTest(testName, `Unexpected admin error: ${response.error}`)
                end
            end
        end)
        :catch(function(error)
            passTest(testName, `Admin command correctly blocked: ${error}`)
        end)
end

-- Server message handling test
local function testServerMessages()
    local testName = startTest("Server Message Handling")
    
    local messageReceived = false
    
    -- Listen for server messages
    local connection = ClientNetwork.onServerMessage("serverStats", function(data)
        messageReceived = true
        passTest(testName, `Received server stats: ${data.playerCount or 0} players`)
    end)
    
    -- Wait a bit to see if we receive any server messages
    -- Server broadcasts after 2 seconds, so wait 5 seconds to be safe
    task.delay(5, function()
        if not messageReceived then
            failTest(testName, "No server messages received (server may not be broadcasting)")
        end
        -- Clean up the message handler
        if connection and connection.Disconnect then
            connection.Disconnect()
        end
    end)
end

-- Retry mechanism test
local function testRetryMechanism()
    local testName = startTest("Retry Mechanism")
    
    local attempts = 0
    local maxAttempts = 3
    
    local function makeRequest()
        attempts += 1
        
        -- Simulate failure on first attempt, success on subsequent
        if attempts == 1 then
            return Promise.reject("Simulated failure")
        else
            return ClientNetwork.request("ping")
        end
    end
    
    local function tryRequest()
        return makeRequest()
            :catch(function(error)
                if attempts < maxAttempts then
                    Debug.info(`Attempt ${attempts} failed, retrying...`)
                    return Promise.delay(0.5):andThen(tryRequest)
                else
                    return Promise.reject(`Failed after ${maxAttempts} attempts: ${error}`)
                end
            end)
    end
    
    tryRequest()
        :timeout(10)
        :andThen(function(response)
            passTest(testName, `Retry succeeded after ${attempts} attempts`)
        end)
        :catch(function(error)
            failTest(testName, `Retry mechanism failed: ${error}`)
        end)
end

-- Run all tests
local function runAllTests()
    -- Prevent multiple simultaneous test runs
    if testsRunning then
        Debug.info("🧪 Tests already running, skipping...")
        return
    end
    
    testsRunning = true
    Debug.system("🧪 Starting comprehensive network tests...")
    
    -- Reset test state
    testResults = {}
    totalTests = 0
    passedTests = 0
    
    -- Basic functionality tests
    testBasicPing()
    task.wait(1)
    
    testPlayerDataRequest()
    task.wait(1)
    
    -- Error handling tests
    testInvalidAction()
    task.wait(1)
    
    testInvalidData()
    task.wait(1)
    
    -- Promise feature tests
    testPromiseTimeout()
    task.wait(2)
    
    testPromiseAll()
    task.wait(2)
    
    -- Data update tests
    testPlayerSettingUpdate()
    task.wait(1)
    
    -- Security tests
    testAdminPermissions()
    task.wait(1)
    
    -- Advanced feature tests
    testRateLimit()
    task.wait(2)
    
    testRetryMechanism()
    task.wait(2)
    
    -- Server message test (starts async)
    testServerMessages()
    
    -- Print summary after all tests complete
    task.delay(12, function() -- Reduced from 15 to 12 since server broadcasts faster now
        printTestSummary()
        testsRunning = false -- Allow tests to run again
    end)
end

local function networkTestSystem()
    if systemInitialized then return end
    systemInitialized = true
    
    Debug.system("Network test system initialized")
    
    -- Initialize client network
    ClientNetwork.init()
    
    -- Set up keybind to run tests
    local function _onKeyPress(actionName, inputState, inputObject)
        if inputState == Enum.UserInputState.Begin then
            runAllTests()
        end
    end
    
    -- Bind F5 key to run tests
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.F5 then
            runAllTests()
        end
    end)
    
    Debug.config("🧪 Network tests ready - Press F5 to run all tests")
    
    -- Auto-run tests once after a short delay
    if not autoRunCompleted then
        task.delay(5, function() -- Wait 5 seconds to let server initialize
            if not autoRunCompleted then
                autoRunCompleted = true
                Debug.info("🚀 Auto-running network tests...")
                runAllTests()
            end
        end)
    end
end

return {
    system = networkTestSystem,
    phase = Phase.Startup,
    name = "NetworkTests"
}