local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local TARGETS = {
    GloEgg = true, HarvestEgg = true, BattleEgg = true,
    BigGloEgg = true, BigHarvestEgg = true, BigFarmEgg = true
}

local TP_DELAY = 0.5
local FIRE_COOLDOWN = 1.5
local RESCAN_DELAY = 2
local HOP_DELAY = 3
local HOP_COOLDOWN = 10
local HOP_TIMEOUT = 25
local FIRE_RETRIES = 3
local FIRE_RETRY_DELAY = 0.4

local fired = {}
local queued = {}
local queue = {}

local STATE = {
    busy = false,
    hopping = false,
    lastHopAttempt = 0,
    hopStartedAt = 0,
    lastEmptyLog = 0,
}

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
do
    local n = 0
    for _ in pairs(visited) do n = n + 1 end
    print("[K] Loaded visited count:", n)
end

local function getRoot()
    local lp = Players.LocalPlayer
    if not lp then
        local t = os.clock()
        repeat task.wait(0.1) until Players.LocalPlayer or os.clock() - t > 5
        lp = Players.LocalPlayer
        if not lp then return nil end
    end
    local char = lp.Character or lp.CharacterAdded:Wait()
    return char:WaitForChild("HumanoidRootPart", 5)
end

local function fireWithRetry(prompt, part)
    for attempt = 1, FIRE_RETRIES do
        if not prompt or not prompt.Parent then
            return true
        end

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

        if not ok then
            print("[K] fireproximityprompt error:", err)
        end

        task.wait(FIRE_RETRY_DELAY)

        if not prompt.Parent then
            return true
        end
        if not prompt.Enabled then
            return true
        end
    end
    return false
end

local function serverHop()
    if STATE.hopping then return end
    if os.clock() - STATE.lastHopAttempt < HOP_COOLDOWN then return end
    if STATE.busy or #queue > 0 then return end

    STATE.hopping = true
    STATE.lastHopAttempt = os.clock()
    STATE.hopStartedAt = os.clock()

    visited[game.JobId] = true
    saveVisited(visited)

    print("[K] Hopping from JobId:", game.JobId)

    local ok, body = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(
            "https://games.roblox.com/v1/games/" .. game.PlaceId ..
            "/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true"
        ))
    end)

    if not ok or not body or not body.data then
        print("[K] Server list fetch failed")
        STATE.hopping = false
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
        print("[K] No fresh servers, resetting visited list")
        visited = { [game.JobId] = true }
        saveVisited(visited)
        STATE.hopping = false
        return
    end

    local chosen = servers[math.random(1, #servers)]
    print("[K] Chosen server:", chosen, "(", #servers, "candidates )")

    local requeue = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/ProcessHandle/Roblox-Scripts/refs/heads/main/Untitled-1.lua"))()'

    if type(syn) == "table" and syn.queue_on_teleport then
        pcall(syn.queue_on_teleport, requeue)
    elseif type(queue_on_teleport) == "function" then
        pcall(queue_on_teleport, requeue)
    else
        print("[K] WARNING: no queue_on_teleport support, script will not reload")
    end

    task.wait(HOP_DELAY)

    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, chosen, Players.LocalPlayer)
    end)

    if not success then
        print("[K] Teleport failed:", err)
        STATE.hopping = false
    end
    -- on success Roblox unloads us; STATE.hopping stays true which is fine
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
                    end
                end
            end
        end
    end
    if count > 0 and #queue > 0 then
        print("[K] Scan found", count, "targets, queue:", #queue)
    end
end

local function processQueue()
    if STATE.busy then return end
    STATE.busy = true

    while #queue > 0 do
        if STATE.hopping then break end

        local prompt = table.remove(queue, 1)
        queued[prompt] = nil

        if prompt and prompt.Parent and not fired[prompt] then
            local part = prompt.Parent
            if part:IsA("BasePart") then
                local success = fireWithRetry(prompt, part)
                if success then
                    fired[prompt] = true
                    print("[K] Fired:", prompt:GetFullName())
                else
                    print("[K] Gave up:", prompt:GetFullName())
                end
            end
        end

        task.wait(FIRE_COOLDOWN)
    end

    STATE.busy = false
end

local function hasTargets()
    for _, child in ipairs(workspace:GetChildren()) do
        if TARGETS[child.Name] then
            return true
        end
    end
    return false
end

local function checkEmpty()
    -- recover from a hop that never actually unloaded us
    if STATE.hopping and os.clock() - STATE.hopStartedAt > HOP_TIMEOUT then
        warn("[K] Hop timeout, resetting state")
        STATE.hopping = false
    end

    -- hard gate: don't hop while working or already hopping
    if STATE.hopping or STATE.busy or #queue > 0 then
        return
    end

    if not hasTargets() then
        -- rate-limit the log so we don't spam
        if os.clock() - STATE.lastEmptyLog > 5 then
            print("[K] No targets, attempting hop")
            STATE.lastEmptyLog = os.clock()
        end
        serverHop()
    end
end

task.spawn(function()
    while true do
        scan()
        if #queue > 0 then
            processQueue()
        else
            checkEmpty()
        end
        task.wait(RESCAN_DELAY)
    end
end)
