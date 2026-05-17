local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

local dump = workspace:FindFirstChild("Dump")
assert(dump, "Workspace.Dump not found!")
dump = dump or workspace:WaitForChild("Dump", 30)
assert(dump, "Workspace.Dump not found after waiting")

_G.TeleporterEnabled = _G.TeleporterEnabled ~= nil and _G.TeleporterEnabled or true
_G.AutoReincarnate = _G.AutoReincarnate ~= nil and _G.AutoReincarnate or true
_G.SkipLives = _G.SkipLives or 1

local SCRIPT_URL = "https://raw.githubusercontent.com/ProcessHandle/Roblox-Scripts/refs/heads/main/crate.lua"
local queueteleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
if queueteleport then
    queueteleport('loadstring(game:HttpGet("' .. SCRIPT_URL .. '"))()')
end

local gui = player.PlayerGui:WaitForChild("Interface").Frames.Main.Progression
local reincarnateBtn = gui.Holder.List.Reincarnate.Holder.Reincarnate
local loadBlueprintsBtn = gui.Holder.List.Blueprints.LoadAll
local priceLabel = gui.Holder.List.Reincarnate.Holder.Price
local moneyStat = player.leaderstats.Money

assert(reincarnateBtn, "Reincarnate button not found")
assert(loadBlueprintsBtn, "LoadBlueprints button not found")
assert(priceLabel, "Price label not found")
assert(moneyStat, "Money leaderstat not found")

local function isValidTarget(obj)
    if not obj:IsA("BasePart") then return false end
    local nameLower = obj.Name:lower()
    return string.find(nameLower, "crate") or string.find(nameLower, "rocoin")
end

local function teleportToTarget(target)
    if not _G.TeleporterEnabled then return end
    pcall(function()
        humanoidRootPart.CFrame = CFrame.new(target.Position + Vector3.new(0, 3, 0))
        print("[Teleporter] " .. target.Name)
    end)
end

local function getRequiredMoney()
    local priceText = priceLabel.Text:gsub("[^%d]", "")
    return tonumber(priceText) or 0
end

local function getCurrentMoney()
    return moneyStat.Value
end

local function canReincarnate()
    return getCurrentMoney() >= getRequiredMoney()
end

local function reincarnate()
    if canReincarnate() then
        reincarnateBtn:Click()
        print("[Reincarnate] Skipping " .. _G.SkipLives .. " lives")
        return true
    end
    return false
end

local function placeBlueprints()
    loadBlueprintsBtn:Click()
    print("[Blueprints] Placed!")
end

for _, child in ipairs(dump:GetChildren()) do
    if isValidTarget(child) then teleportToTarget(child) end
end

dump.ChildAdded:Connect(function(child)
    task.wait(0.05)
    if isValidTarget(child) then teleportToTarget(child) end
end)

player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    task.wait(0.2)
    for _, child in ipairs(dump:GetChildren()) do
        if isValidTarget(child) then teleportToTarget(child) end
    end
end)

task.spawn(function()
    while true do
        if _G.AutoReincarnate and canReincarnate() then
            reincarnate()
            task.wait(2)
            placeBlueprints()
        end
        task.wait(1)
    end
end)

print("═══════════════════════════════════════")
print("  TELEPORTER + AUTO REINCARNATE (NICE ANTICHEAT RETARDS LOOOL)")
print("═══════════════════════════════════════")
print("[Teleporter] " .. (_G.TeleporterEnabled and "ON" or "OFF"))
print("[Reincarnate] " .. (_G.AutoReincarnate and "ON" or "OFF"))
print("───────────────────────────────────────")
print("Commands:")
print("  _G.TeleporterEnabled = false/true")
print("  _G.AutoReincarnate = false/true")
print("  _G.SkipLives = 1-4")
print("═══════════════════════════════════════")
