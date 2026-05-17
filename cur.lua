local retardremote = nil

for _, folder in pairs(game:GetDescendants()) do
    if folder.Name == "FilteredSelection" and #folder:GetChildren() > 0 then
        for _, v in pairs(folder:GetChildren()) do
            if v:IsA("RemoteFunction") then
                retardremote = v
                break
            end
        end
    end
end

if retardremote then
    local mt = getrawmetatable(retardremote)
    if mt then
        local oldNamecall = mt.__namecall
        setreadonly(mt, false)
        mt.__namecall = function(self, ...)
            local method = getnamecallmethod()
            if method == "InvokeServer" then
                local args = {...}
                print("[InvokeServer] Args:")
                for i, arg in pairs(args) do
                    if type(arg) == "buffer" then
                        print("  Arg[" .. i .. "] is a buffer of size: " .. buffer.len(arg))
                        pcall(function()
                            local str = buffer.tostring(arg)
                            print("    Buffer as string: " .. str)
                        end)
                        local hex = ""
                        for j = 0, math.min(31, buffer.len(arg)-1) do
                            hex = hex .. string.format("%02x", buffer.readu8(arg, j))
                        end
                        print("    Hex (first 32 bytes): " .. hex)
                    elseif type(arg) == "table" then
                        print("  Arg[" .. i .. "] is a table with contents:")
                        for k, v in pairs(arg) do
                            print("    " .. tostring(k) .. " = " .. tostring(v))
                        end
                    else
                        print("  Arg[" .. i .. "] = " .. tostring(arg) .. " (" .. type(arg) .. ")")
                    end
                end
            end
            return oldNamecall and oldNamecall(self, ...) or nil
        end
        setreadonly(mt, true)
        print("Hooked - will show buffer contents")
    else
        print("No metatable found")
    end
end
