local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")

local dump = workspace:FindFirstChild("Dump")
assert(dump, "Workspace.Dump not found!")
dump = dump or workspace:WaitForChild("Dump", 30)
assert(dump, "Workspace.Dump not found after waiting")

_G.TeleporterEnabled = _G.TeleporterEnabled ~= nil and _G.TeleporterEnabled or true
_G.AutoReincarnate = _G.AutoReincarnate ~= nil and _G.AutoReincarnate or true

local SCRIPT_URL = "https://raw.githubusercontent.com/ProcessHandle/Roblox-Scripts/refs/heads/main/crate.lua"
local queueteleport = queue_on_teleport or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
if queueteleport then
    queueteleport('loadstring(game:HttpGet("' .. SCRIPT_URL .. '"))()')
end

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Interface").Frames.Main.Progression
local moneyLabel = player.PlayerGui:WaitForChild("Interface").Hub.Currency.Money.Label

local reincarnateBtn = gui.Holder.List.Reincarnate.Holder.Reincarnate
local loadBlueprintsBtn = gui.Holder.List.Blueprints.LoadAll
local priceLabel = gui.Holder.List.Reincarnate.Holder.Price

local VirtualUser = game:GetService("VirtualUser")
local UserInputService = game:GetService("UserInputService")

local function clickButton(button)
    local pos = button.AbsolutePosition
    local size = button.AbsoluteSize
    local x = pos.X + size.X / 2
    local y = pos.Y + size.Y / 2
    
    pcall(function()
        VirtualUser:ClickButton1(Vector2.new(x, y))
    end)
    
    pcall(function()
        UserInputService:SetMousePosition(x, y)
    end)
    
    pcall(function()
        button:FireEvent("MouseButton1Down")
        task.wait(0.05)
        button:FireEvent("MouseButton1Up")
    end)
end

local function parseRichTextNumber(text)
    local number = text:match(">(.+?)<")
    if not number then
        number = text:gsub("[^%d.eE+-]", "")
    end
    return tonumber(number) or 0
end

local function getCurrentMoney()
    return parseRichTextNumber(moneyLabel.Text)
end

local function getRequiredMoney()
    return parseRichTextNumber(priceLabel.Text)
end

local function canReincarnate()
    return getCurrentMoney() >= getRequiredMoney()
end

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

local function reincarnate()
    if canReincarnate() then
        clickButton(reincarnateBtn)
        print("[Reincarnate] Done!")
        return true
    end
    return false
end

local function placeBlueprints()
    clickButton(loadBlueprintsBtn)
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
print("  TELEPORTER + AUTO REINCARNATE")
print("═══════════════════════════════════════")
print("[Teleporter] " .. (_G.TeleporterEnabled and "ON" or "OFF"))
print("[Reincarnate] " .. (_G.AutoReincarnate and "ON" or "OFF"))
print("───────────────────────────────────────")
print("Commands:")
print("  _G.TeleporterEnabled = false/true")
print("  _G.AutoReincarnate = false/true")
print("═══════════════════════════════════════")
