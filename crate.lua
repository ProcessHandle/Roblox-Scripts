local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

local dump = workspace:FindFirstChild("Dump")
if not dump then
    dump = workspace:WaitForChild("Dump", 30)
    if not dump then
        return
    end
end

_G.TeleporterEnabled = _G.TeleporterEnabled ~= nil and _G.TeleporterEnabled or true

local SCRIPT_URL = "https://raw.githubusercontent.com/ProcessHandle/Roblox-Scripts/refs/heads/main/crate.lua"

local queueteleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)

if queueteleport then
    queueteleport('loadstring(game:HttpGet("' .. SCRIPT_URL .. '"))()')
end

local function isValidTarget(obj)
    if not obj:IsA("BasePart") then return false end
    local nameLower = obj.Name:lower()
    return string.find(nameLower, "crate") or string.find(nameLower, "rocoin")
end

local function teleportToTarget(target)
    if not _G.TeleporterEnabled then return end
    if target and target:IsA("BasePart") and target.Parent == dump then
        pcall(function()
            humanoidRootPart.CFrame = CFrame.new(target.Position + Vector3.new(0, 3, 0))
            print("Teleported to: " .. target.Name)
        end)
    end
end

for _, child in ipairs(dump:GetChildren()) do
    if isValidTarget(child) then
        teleportToTarget(child)
    end
end

dump.ChildAdded:Connect(function(child)
    task.wait(0.05)
    if isValidTarget(child) then
        teleportToTarget(child)
    end
end)

player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    task.wait(0.2)
    for _, child in ipairs(dump:GetChildren()) do
        if isValidTarget(child) then
            teleportToTarget(child)
        end
    end
end)

print("Teleporter ACTIVE - _G.TeleporterEnabled = false to disable")
