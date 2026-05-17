local communicator = require(game:GetService("ReplicatedStorage"):FindFirstChild("Libraries").Communicator)

-- Search through all functions in communicator for the one that calls InvokeServer
for k, v in pairs(communicator) do
    if type(v) == "function" then
        local upvalues = {}
        local i = 1
        while true do
            local name, value = debug.getupvalue(v, i)
            if not name then break end
            if type(value) == "function" then
                table.insert(upvalues, {name = name, func = value})
            end
            i = i + 1
        end
        if #upvalues > 0 then
            print("Function " .. k .. " has " .. #upvalues .. " upvalues")
        end
    end
end

-- Hook the actual remote directly using the method that worked before
local reincRemote = nil
for _, folder in pairs(game:GetDescendants()) do
    if folder.Name == "FilteredSelection" and #folder:GetChildren() > 0 then
        for _, v in pairs(folder:GetChildren()) do
            if v:IsA("RemoteFunction") then
                reincRemote = v
                break
            end
        end
    end
end

if reincRemote then
    print("Remote found, tracking calls")
    local mt = getrawmetatable(reincRemote)
    local oldNamecall = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = function(self, ...)
        local method = getnamecallmethod()
        if method == "InvokeServer" and self == reincRemote then
            local args = {...}
            print("=== REINCARNATION INVOKE ===")
            for i, arg in pairs(args) do
                if type(arg) == "buffer" then
                    print("Arg[" .. i .. "] is buffer, size: " .. buffer.len(arg))
                    -- Try to read as different types
                    pcall(function()
                        print("  As string: " .. buffer.tostring(arg))
                    end)
                else
                    print("Arg[" .. i .. "]:", arg, "(" .. type(arg) .. ")")
                end
            end
            print("Stack trace:")
            print(debug.traceback())
        end
        return oldNamecall(self, ...)
    end
    setreadonly(mt, true)
    print("Hook ready - trigger reincarnation")
end
