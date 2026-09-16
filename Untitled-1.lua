local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local TARGETS = { GloEgg = true, HarvestEgg = true, FarmEgg = true }

local TP_DELAY = 0.5
local FIRE_COOLDOWN = 1.5
local RESCAN_DELAY = 2
local HOP_DELAY = 3
local HOP_COOLDOWN = 10

local fired = {}
local queued = {}
local queue = {}
local busy = false
local hopping = false
local lastHop = 0

local function loadVisited()
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile("visited_servers.json"))
    end)
    local visited = {}
    if ok and type(data) == "table" then
        for _, id in ipairs(data) do
            visited[id] = true
        end
    end
    visited[game.JobId] = true
    return visited
end

local function saveVisited(visited)
    local list = {}
    for id in pairs(visited) do
        table.insert(list, id)
    end
    pcall(function()
        writefile("visited_servers.json", HttpService:JSONEncode(list))
    end)
end

local visited = loadVisited()

local function getLP()
    return Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer")
        and Players.LocalPlayer
        or Players:WaitForChild("LocalPlayer", 10)
end

local function getRoot()
    local lp = Players.LocalPlayer
    if not lp then
        lp = Players:GetPropertyChangedSignal("LocalPlayer"):Wait() and Players.LocalPlayer
    end
    if not lp then return nil end

    local char = lp.Character or lp.CharacterAdded:Wait()
    return char:FindFirstChild("HumanoidRootPart") or char:WaitForChild("HumanoidRootPart", 5)
end

local function serverHop()
    if hopping then return end
    if os.clock() - lastHop < HOP_COOLDOWN then return end

    hopping = true
    lastHop = os.clock()
    visited[game.JobId] = true
    saveVisited(visited)

    local ok, body = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/" .. game.PlaceId ..
            "/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true"
        ))
    end)

    if not ok or not body or not body.data then
        hopping = false
        return
    end

    local servers = {}
    for _, v in next, body.data do
        if type(v) == "table"
            and tonumber(v.playing) and tonumber(v.maxPlayers)
            and v.playing < v.maxPlayers
            and v.id ~= game.JobId
            and not visited[v.id]
        then
            table.insert(servers, v.id)
        end
    end

    if #servers == 0 then
        visited = { [game.JobId] = true }
        saveVisited(visited)
        hopping = false
        return
    end

    if type(syn) == "table" and syn.queue_on_teleport then
        pcall(syn.queue_on_teleport, 'loadstring(game:HttpGet("https://raw.githubusercontent.com/ProcessHandle/Roblox-Scripts/refs/heads/main/Untitled-1.lua"))()')
    elseif type(queue_on_teleport) == "function" then
        pcall(queue_on_teleport, 'loadstring(game:HttpGet("https://raw.githubusercontent.com/ProcessHandle/Roblox-Scripts/refs/heads/main/Untitled-1.lua"))()')
    end

    task.wait(HOP_DELAY)

    local success = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, servers[math.random(1, #servers)], Players.LocalPlayer)
    end)

    if not success then
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
        serverHop()
    end
end

task.spawn(function()
    while task.wait(RESCAN_DELAY) do scan() end
end)

task.spawn(function()
    while true do
        if #queue > 0 then processQueue() else task.wait(0.25) end
    end
end)

task.spawn(function()
    while true do
        checkEmpty()
        task.wait(5)
    end
end)
