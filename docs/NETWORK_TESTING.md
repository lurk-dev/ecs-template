# Network Testing Guide

Comprehensive network testing system to verify that your ECS template's networking functionality is working correctly.

## 🧪 What Gets Tested

### **Basic Functionality**

- ✅ **Ping/Pong** - Basic server connectivity
- ✅ **Player Data Requests** - ECS data retrieval
- ✅ **Data Updates** - Player setting modifications

### **Error Handling**

- ✅ **Invalid Actions** - Rejection of unknown commands
- ✅ **Invalid Data** - Validation of request formats
- ✅ **Timeout Handling** - Request timeout behavior

### **Promise Features**

- ✅ **Promise.all()** - Concurrent request handling
- ✅ **Timeout Support** - Request timeout functionality
- ✅ **Retry Mechanism** - Automatic request retrying

### **Security Features**

- ✅ **Admin Permissions** - Admin-only command protection
- ✅ **Rate Limiting** - Request spam prevention (light testing)
- ✅ **Data Validation** - Server-side input validation

### **Advanced Features**

- ✅ **Server Broadcasting** - Server-initiated messages
- ✅ **Message Handling** - Client response to server events

## 🚀 How to Run Tests

### **Method 1: Automatic (Recommended)**

1. The network test system runs automatically once when the game starts
2. Check the console for test results after ~5 seconds
3. Look for emoji-coded messages: ✅ = Pass, ❌ = Fail

### **Method 2: Manual Trigger**

1. Press **F5** during gameplay to re-run all tests
2. Tests run sequentially with 1-2 second delays between them
3. Full test suite takes ~15 seconds to complete

### **Method 3: Test Runner Script**

1. Copy `StarterPlayer/StarterPlayerScripts/NetworkTestRunner.client.luau` to your game
2. Tests will run automatically when players join

## 📊 Understanding Test Results

### **Console Output Format**

```
🧪 Starting test: Basic Ping
✅ Basic Ping: Server responded: Pong from server!
🧪 Starting test: Player Data Request
✅ Player Data Request: Got player data: TestPlayer
📊 Test Summary: 10/10 tests passed
🎉 All network tests passed!
```

### **Test Status Indicators**

- **🧪** - Test starting
- **✅** - Test passed
- **❌** - Test failed
- **📊** - Final summary
- **🎉** - All tests successful

## 🔧 Test Configuration

### **Debug Categories**

Enable network debugging for more detailed output:

```lua
-- In shared-config.luau, enable network category
Debug = {
    categories = {
        network = true,  -- Show network messages
        info = true,     -- Show test info
        system = true,   -- Show system messages
    }
}
```

### **Test Timeouts**

Tests use these timeout values:

- **Basic requests**: 5 seconds
- **Promise.all()**: 10 seconds
- **Server messages**: 8 seconds
- **Retry mechanism**: 10 seconds

## 🛠️ Adding Custom Tests

### **Adding a New Test**

```lua
local function testCustomFeature()
    local testName = startTest("Custom Feature")

    ClientNetwork.request("customAction", {param = "value"})
        :timeout(5)
        :andThen(function(response)
            if response.success then
                passTest(testName, "Custom feature works!")
            else
                failTest(testName, `Custom test failed: ${response.error}`)
            end
        end)
        :catch(function(error)
            failTest(testName, `Custom test error: ${error}`)
        end)
end

-- Add to runAllTests() function
local function runAllTests()
    -- ... existing tests ...
    testCustomFeature()
    task.wait(1)
    -- ... rest of tests ...
end
```

### **Custom Test Requirements**

1. **Use `startTest(name)`** to initialize test tracking
2. **Call `passTest(name, message)` or `failTest(name, error)`** to record results
3. **Add delays** between tests with `task.wait(1)`
4. **Handle timeouts** with `:timeout(seconds)`
5. **Include error handling** with `:catch()`

## 🔍 Troubleshooting

### **Common Test Failures**

**❌ "No server messages received"**

- Server broadcasts every 3 seconds for the first 15 seconds (for testing)
- Then broadcasts every 30 seconds for production use
- Check if network-handler system is running on server
- Verify server-side network initialization

**❌ "Player data not found"**

- Player bridge system may not be running
- Check ECS player entity creation
- Verify server-side player management

**❌ "Request timeout"**

- Server network system may not be initialized
- Check RemoteEvent creation and connections
- Verify server-side request handlers

**❌ "Rate limit exceeded"**

- Normal behavior for rate limiting test
- Indicates rate limiting is working correctly
- Reduce test frequency if needed

### **Debug Steps**

1. **Enable network debugging** in shared-config
2. **Check server console** for errors
3. **Verify RemoteEvents** exist in ReplicatedStorage
4. **Confirm handler registration** on server
5. **Test individual requests** manually

## 📝 Test Files

### **Main Test System**

- `src/shared/client-systems/network-tests.luau` - Complete test suite

### **Test Runner**

- `StarterPlayer/StarterPlayerScripts/NetworkTestRunner.client.luau` - Simple test runner

### **Required Dependencies**

- `src/shared/client-network.luau` - Client network system (main implementation)
- `src/client/network.luau` - Client network wrapper (re-exports shared module)
- `src/server/network.luau` - Server network system
- `src/shared/network.luau` - Shared network utilities
- `src/server/server-systems/network-handler.luau` - Server request handlers

## 🎯 Expected Results

### **Healthy Network System**

When everything is working correctly, you should see:

- **10 tests passing** out of 10 total tests
- **Quick response times** (< 1 second per test)
- **Proper error handling** for invalid requests
- **Admin protection** working correctly
- **Server messages** being received (broadcasts every 3 seconds initially)

### **Test Success Criteria**

- ✅ Basic connectivity (ping/pong)
- ✅ Data requests and updates
- ✅ Error handling and validation
- ✅ Promise features working
- ✅ Security features enabled
- ✅ Server communication functional

Run these tests regularly during development to ensure your network system remains stable and secure!
