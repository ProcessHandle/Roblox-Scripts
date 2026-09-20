local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local TARGETS = {
    GloEgg = true, HarvestEgg = true, FarmEgg = true, BattleEgg = true,
    BigGloEgg = true, BigHarvestEgg = true, BigFarmEgg = true
}

local TP_DELAY = 0.5
local FIRE_COOLDOWN = 1.5
local RESCAN_DELAY = 2
local HOP_DELAY = 3
local HOP_COOLDOWN = 10
local FIRE_RETRIES = 3
local FIRE_RETRY_DELAY = 0.4

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
print("[K] Loaded visited count:", (function() local n=0 for _ in pairs(visited) do n=n+1 end return n end)())

local function getRoot()
    local lp = Players.LocalPlayer
    if not lp then
        repeat task.wait(0.1) until Players.LocalPlayer
        lp = Players.LocalPlayer
    end
    local char = lp.Character or lp.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart", 5)
end

local function fireWithRetry(prompt, part)
    for attempt = 1, FIRE_RETRIES do
        print("[K] Fire attempt", attempt, "on", prompt:GetFullName())

        local root = getRoot()
        if not root then
            print("[K] No root, aborting")
            return false
        end

        root.CFrame = part.CFrame
        task.wait(TP_DELAY)

        local ok, err = pcall(function()
            fireproximityprompt(prompt)
        end)

        print("[K] fireproximityprompt ok:", ok, err or "")

        task.wait(FIRE_RETRY_DELAY)

        if not prompt.Parent then
            print("[K] Prompt destroyed, success")
            return true
        end

        if not prompt.Enabled then
            print("[K] Prompt disabled, success")
            return true
        end

        print("[K] Prompt still active, retrying")
    end
    return false
end

local function serverHop()
    if hopping then
        print("[K] Hop blocked: already hopping")
        return
    end
    if os.clock() - lastHop < HOP_COOLDOWN then
        print("[K] Hop blocked: cooldown", HOP_COOLDOWN - (os.clock() - lastHop))
        return
    end

    hopping = true
    lastHop = os.clock()
    visited[game.JobId] = true
    saveVisited(visited)

    print("[K] Current JobId:", game.JobId)

    local ok, body = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/" .. game.PlaceId ..
            "/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true"
        ))
    end)

    if not ok or not body or not body.data then
        print("[K] Server list fetch failed:", ok, body)
        hopping = false
        return
    end

    print("[K] Fetched", #body.data, "servers")

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

    print("[K] Fresh candidates:", #servers)

    if #servers == 0 then
        print("[K] No fresh servers, resetting visited")
        visited = { [game.JobId] = true }
        saveVisited(visited)
        hopping = false
        return
    end

    local chosen = servers[math.random(1, #servers)]
    print("[K] Chosen:", chosen)

    if type(syn) == "table" and syn.queue_on_teleport then
        pcall(syn.queue_on_teleport, 'loadstring(game:HttpGet("https://raw.githubusercontent.com/ProcessHandle/Roblox-Scripts/refs/heads/main/Untitled-1.lua"))()')
        print("[K] Queued via syn")
    elseif type(queue_on_teleport) == "function" then
        pcall(queue_on_teleport, 'loadstring(game:HttpGet("https://raw.githubusercontent.com/ProcessHandle/Roblox-Scripts/refs/heads/main/Untitled-1.lua"))()')
        print("[K] Queued via queue_on_teleport")
    else
        print("[K] WARNING: no queue_on_teleport support")
    end

    task.wait(HOP_DELAY)

    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, chosen, Players.LocalPlayer)
    end)

    print("[K] Teleport result:", success, err or "")

    if not success then
        hopping = false
    end
end

local function scan()
    local count = 0
    for _, child in ipairs(workspace:GetChildren()) do
        if TARGETS[child.Name] then
            count = count + 1
            for _, desc in ipairs(child:GetDescendants()) do
                if desc:IsA("ProximityPrompt") and not fired[desc] and not queued[desc] then
                    local part = desc.Parent
                    if part and part:IsA("BasePart") then
                        queued[desc] = true
                        table.insert(queue, desc)
                        print("[K] Queued:", desc:GetFullName())
                    end
                end
            end
        end
    end
    if count > 0 then
        print("[K] Scan found", count, "targets, queue size:", #queue)
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

            if part and part:IsA("BasePart") then
                print("[K] Processing:", prompt:GetFullName())
                local success = fireWithRetry(prompt, part)
                if success then
                    fired[prompt] = true
                    print("[K] Marked fired:", prompt:GetFullName())
                else
                    print("[K] Gave up on:", prompt:GetFullName())
                end
            end
        end

        task.wait(FIRE_COOLDOWN)
    end

    busy = false
end

local function checkEmpty()
    if hopping then
        print("[K] checkEmpty: hopping, skip")
        return
    end
    task.wait(2)

    local foundAny = false
    for _, child in ipairs(workspace:GetChildren()) do
        if TARGETS[child.Name] then
            foundAny = true
            break
        end
    end

    print("[K] checkEmpty: foundAny:", foundAny, "queue:", #queue, "busy:", busy)

    if not foundAny and #queue == 0 and not busy then
        print("[K] Empty, hopping")
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
