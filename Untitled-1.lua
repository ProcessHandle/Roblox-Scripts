local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local LP = Players.LocalPlayer

local TARGETS = {
    GloEgg = true,
    HarvestEgg = true,
    FarmEgg = true
}

local TP_DELAY = 0.5
local FIRE_COOLDOWN = 1.5
local RESCAN_DELAY = 2
local HOP_DELAY = 3
local HOP_COOLDOWN = 10
local SCRIPT_URL = ""

local fired = {}
local queued = {}
local queue = {}
local busy = false
local hopping = false
local lastHop = 0
local previousJobId = nil

local function getRoot()
    local char = LP.Character or LP.CharacterAdded:Wait()
    return char:FindFirstChild("HumanoidRootPart")
end

local function queueOnTeleport(code)
    if type(syn) == "table" and syn.queue_on_teleport then
        pcall(syn.queue_on_teleport, code)
    elseif type(queue_on_teleport) == "function" then
        pcall(queue_on_teleport, code)
    end
end

local function serverHop()
    if hopping then return end
    if os.clock() - lastHop < HOP_COOLDOWN then return end

    local currentJob = game.JobId
    if currentJob == previousJobId then return end

    hopping = true
    previousJobId = currentJob
    lastHop = os.clock()

    queueOnTeleport(string.format([[
        loadstring(game:HttpGet("%s"))()
    ]], SCRIPT_URL))

    task.wait(HOP_DELAY)

    local success, err = pcall(function()
        TeleportService:Teleport(game.PlaceId, LP)
    end)

    if not success then
        warn("[K] Hop failed:", err)
        hopping = false
    end
end

local function scan()
    for _, child in ipairs(workspace:GetChildren()) do
        if TARGETS[child.Name] then
            for _, desc in ipairs(child:GetDescendants()) do
                if desc:IsA("ProximityPrompt") and not fired[desc] and not queued[desc] then
                    local part = desc.Parent
                    if part and part:IsA("BasePart") then
                        queued[desc] = true
                        table.insert(queue, desc)
                    end
                end
            end
        end
    end
end

local function processQueue()
    if busy then return end
    busy = true

    while #queue > 0 do
        local prompt = table.remove(queue, 1)
        queued[prompt] = nil

        if not fired[prompt] and prompt.Parent then
            local part = prompt.Parent
            local root = getRoot()

            if part and part:IsA("BasePart") and root then
                root.CFrame = part.CFrame
                task.wait(TP_DELAY)

                pcall(function()
                    fireproximityprompt(prompt)
                end)

                fired[prompt] = true
                print("[K] Fired:", prompt:GetFullName())
            end
        end

        task.wait(FIRE_COOLDOWN)
    end

    busy = false
end

local function checkEmpty()
    if hopping then return end

    task.wait(2)

    local foundAny = false
    for _, child in ipairs(workspace:GetChildren()) do
        if TARGETS[child.Name] then
            foundAny = true
            break
        end
    end

    if not foundAny and #queue == 0 and not busy then
        print("[K] No targets found, hopping...")
        serverHop()
    end
end

task.spawn(function()
    while task.wait(RESCAN_DELAY) do
        scan()
    end
end)

task.spawn(function()
    while true do
        if #queue > 0 then
            processQueue()
        else
            task.wait(0.25)
        end
    end
end)

task.spawn(function()
    while true do
        checkEmpty()
        task.wait(5)
    end
end)
