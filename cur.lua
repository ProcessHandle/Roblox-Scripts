local reincRemote = nil
local bufferHistory = {}

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
    local mt = getrawmetatable(reincRemote)
    local oldNamecall = mt.__namecall
    setreadonly(mt, false)
    mt.__namecall = function(self, ...)
        local method = getnamecallmethod()
        if method == "InvokeServer" and self == reincRemote then
            local args = {...}
            for i, arg in pairs(args) do
                if type(arg) == "buffer" then
                    local str = pcall(buffer.tostring, arg) and buffer.tostring(arg) or "cannot read"
                    local size = buffer.len(arg)
                    
                    table.insert(bufferHistory, {str = str, size = size, time = os.time()})
                    
                    print("=== Reincarnation Buffer " .. #bufferHistory .. " ===")
                    print("Size: " .. size)
                    print("String: " .. str)
                    
                    if #bufferHistory >= 2 then
                        print("--- Comparison with previous buffer ---")
                        local prev = bufferHistory[#bufferHistory-1].str
                        local curr = str
                        for j = 1, math.min(#prev, #curr) do
                            if prev:sub(j,j) ~= curr:sub(j,j) then
                                print("First difference at position " .. j)
                                print("  Was: " .. prev:sub(math.max(1,j-5), j+5))
                                print("  Now: " .. curr:sub(math.max(1,j-5), j+5))
                                break
                            end
                        end
                    end
                end
            end
        end
        return oldNamecall(self, ...)
    end
    setreadonly(mt, true)
    print("Hook ready. Reincarnate MULTIPLE times to compare buffers")
end
