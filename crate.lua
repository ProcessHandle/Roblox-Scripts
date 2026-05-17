local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

local dump = workspace:FindFirstChild("Dump")
if not dump then
    warn("Workspace.Dump not found!")
    return
end

_G.TeleporterEnabled = _G.TeleporterEnabled ~= nil and _G.TeleporterEnabled or true

local function isValidTarget(obj)
    if not obj:IsA("BasePart") then return false end
    local nameLower = obj.Name:lower()
    return string.find(nameLower, "crate") or string.find(nameLower, "rocoin")
end

local function teleportToTarget(target)
    if not _G.TeleporterEnabled then return end
    if target and target:IsA("BasePart") and target.Parent == dump then
        humanoidRootPart.CFrame = CFrame.new(target.Position + Vector3.new(0, 3, 0))
        print("Teleported to: " .. target.Name)
    end
end

for _, child in ipairs(dump:GetChildren()) do
    if isValidTarget(child) then
        teleportToTarget(child)
    end
end

dump.ChildAdded:Connect(function(child)
    if isValidTarget(child) then
        teleportToTarget(child)
    end
end)

player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    print("Character respawned - Teleporter " .. (_G.TeleporterEnabled and "ENABLED" or "DISABLED"))
end)

print("CONSTANT teleporter ACTIVE - Type _G.TeleporterEnabled = false to disable")
print("Current: " .. (_G.TeleporterEnabled and "ENABLED" or "DISABLED"))