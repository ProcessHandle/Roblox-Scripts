-- ============================================================
--  Auto Farm (Egg Collection + Server Hop)
--  Consolidated single-loop, robust fetch, no console spam
-- ============================================================

local Players          = game:GetService("Players")
local TeleportService  = game:GetService("TeleportService")
local HttpService      = game:GetService("HttpService")

-- ---------- Config ----------
local TARGETS = {
    GloEgg = true, HarvestEgg = true, BattleEgg = true,
    BigGloEgg = true, BigHarvestEgg = true, BigFarmEgg = true
}

local TP_DELAY          = 0.5
local FIRE_COOLDOWN     = 1.5
local RESCAN_DELAY      = 2
local HOP_DELAY         = 3
local HOP_COOLDOWN      = 12
local HOP_TIMEOUT       = 25
local FIRE_RETRIES      = 3
local FIRE_RETRY_DELAY  = 0.4
local FETCH_ATTEMPTS    = 4
local FETCH_BACKOFF     = 2

-- ---------- State ----------
local fired  = {}   -- [prompt] = true
local queued = {}   -- [prompt] = true  (already in queue)
local queue  = {}   -- array of prompts

local STATE = {
    busy          = false,
    hopping       = false,
    lastHopAt     = 0,
    hopStartedAt  = 0,
    lastEmptyLog  = 0,
    lastFetchWarn = 0,
}

-- ---------- Visited server persistence ----------
local function loadVisited()
    local visited = {}
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile("visited_servers.json"))
    end)
    if ok and type(data) == "table" then
        for _, id in ipairs(data) do
            if type(id) == "string" then visited[id] = true end
        end
    end
    visited[game.JobId] = true
    return visited
end

local function saveVisited(visited)
    local list = {}
    for id in pairs(visited) do table.insert(list, id) end
    pcall(function()
        writefile("visited_servers.json", HttpService:JSONEncode(list))
    end)
end

local visited = loadVisited()
do
    local n = 0
    for _ in pairs(visited) do n = n + 1 end
    print("[K] Visited servers loaded:", n)
end

-- ---------- Character helpers ----------
local function getRoot()
    local lp = Players.LocalPlayer
    if not lp then
        local t = os.clock()
        repeat task.wait(0.1) until Players.LocalPlayer or os.clock() - t > 5
        lp = Players.LocalPlayer
        if not lp then return nil end
    end
    local char = lp.Character or lp.CharacterAdded:Wait()
    if not char then return nil end
    return char:WaitForChild("HumanoidRootPart", 5)
end

-- ---------- Prompt firing ----------
local function fireWithRetry(prompt, part)
    for attempt = 1, FIRE_RETRIES do
        if not prompt or not prompt.Parent then return true end

        local root = getRoot()
        if not root then return false end

        root.CFrame = part.CFrame
        task.wait(TP_DELAY)

        pcall(fireproximityprompt, prompt)
        task.wait(FIRE_RETRY_DELAY)

        if not prompt.Parent or not prompt.Enabled then
            return true
        end
    end
    return false
end

-- ---------- Server list fetching ----------
-- Tries multiple endpoints and returns a list of {id = ...} entries, or nil.
local function fetchServers()
    local placeId = game.PlaceId
    local endpoints = {
        "https://games.roblox.com/v1/games/" .. placeId ..
            "/servers/Public?sortOrder=Desc&limit=100&excludeFullGames=true",
        "https://games.roblox.com/v1/games/" .. placeId ..
            "/servers/Public?sortOrder=Asc&limit=100&excludeFullGames=true",
        "https://games.roblox.com/v1/games/" .. placeId ..
            "/servers/Public?limit=100",
    }

    for attempt = 1, FETCH_ATTEMPTS do
        for _, url in ipairs(endpoints) do
            local ok, raw = pcall(function()
                return game:HttpGet(url, true)
            end)

            if ok and type(raw) == "string" and #raw > 0 then
                local trimmed = raw:match("^%s*(.-)%s*$")
                local first = trimmed:sub(1, 1)

                if first == "{" or first == "[" then
                    local decodeOk, decoded = pcall(function()
                        return HttpService:JSONDecode(trimmed)
                    end)

                    if decodeOk and type(decoded) == "table" then
                        if decoded.data and #decoded.data > 0 then
                            return decoded.data
                        end
                    end
                end
                -- non-JSON response: fall through to next endpoint
            end

            task.wait(0.5)
        end

        if attempt < FETCH_ATTEMPTS then
            if os.clock() - STATE.lastFetchWarn > 10 then
                print("[K] Server list fetch attempt", attempt, "failed, backing off")
                STATE.lastFetchWarn = os.clock()
            end
            task.wait(FETCH_BACKOFF)
        end
    end

    return nil
end

-- ---------- Hop ----------
local function serverHop()
    if STATE.hopping then return end
    if os.clock() - STATE.lastHopAt < HOP_COOLDOWN then return end
    if STATE.busy or #queue > 0 then return end

    STATE.hopping      = true
    STATE.lastHopAt    = os.clock()
    STATE.hopStartedAt = os.clock()

    visited[game.JobId] = true
    saveVisited(visited)

    print("[K] Hop: fetching server list (from", game.JobId .. ")")

    local servers = fetchServers()

    if not servers then
        warn("[K] Hop: could not fetch server list. Short cooldown, will retry.")
        STATE.hopping   = false
        STATE.lastHopAt = os.clock() - HOP_COOLDOWN + 4
        return
    end

    local candidates = {}
    for _, v in ipairs(servers) do
        if type(v) == "table"
            and type(v.id) == "string"
            and tonumber(v.playing) and tonumber(v.maxPlayers)
            and v.playing < v.maxPlayers
            and v.id ~= game.JobId
            and not visited[v.id]
        then
            table.insert(candidates, v.id)
        end
    end

    if #candidates == 0 then
        print("[K] Hop: no fresh servers, resetting visited cache")
        visited = { [game.JobId] = true }
        saveVisited(visited)
        STATE.hopping = false
        return
    end

    local chosen = candidates[math.random(1, #candidates)]
    print("[K] Hop: teleporting to", chosen, "(" .. #candidates .. " candidates)")

    local requeue = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/ProcessHandle/Roblox-Scripts/refs/heads/main/Untitled-1.lua"))()'

    if type(syn) == "table" and syn.queue_on_teleport then
        pcall(syn.queue_on_teleport, requeue)
    elseif type(queue_on_teleport) == "function" then
        pcall(queue_on_teleport, requeue)
    else
        warn("[K] Hop: no queue_on_teleport support, script will NOT reload")
    end

    task.wait(HOP_DELAY)

    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, chosen, Players.LocalPlayer)
    end)

    if not success then
        warn("[K] Hop: teleport failed:", err)
        STATE.hopping = false
    end
    -- if success, Roblox unloads us; no need to reset
end

-- ---------- Scanning ----------
local function scan()
    local found = 0
    for _, child in ipairs(workspace:GetChildren()) do
        if TARGETS[child.Name] then
            found = found + 1
            for _, desc in ipairs(child:GetDescendants()) do
                if desc:IsA("ProximityPrompt")
                    and not fired[desc]
                    and not queued[desc]
                then
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

local function hasTargets()
    for _, child in ipairs(workspace:GetChildren()) do
        if TARGETS[child.Name] then return true end
    end
    return false
end

-- ---------- Queue processing ----------
local function processQueue()
    if STATE.busy then return end
    STATE.busy = true

    while #queue > 0 do
        if STATE.hopping then break end

        local prompt = table.remove(queue, 1)
        if prompt then queued[prompt] = nil end

        if prompt and prompt.Parent and not fired[prompt] then
            local part = prompt.Parent
            if part:IsA("BasePart") then
                if fireWithRetry(prompt, part) then
                    fired[prompt] = true
                end
            end
        end

        task.wait(FIRE_COOLDOWN)
    end

    STATE.busy = false
end

-- ---------- Empty check ----------
local function checkEmpty()
    -- recover from a hop that never unloaded us
    if STATE.hopping and os.clock() - STATE.hopStartedAt > HOP_TIMEOUT then
        warn("[K] Hop timeout, resetting hop state")
        STATE.hopping = false
    end

    if STATE.hopping or STATE.busy or #queue > 0 then
        return
    end

    if not hasTargets() then
        if os.clock() - STATE.lastEmptyLog > 5 then
            print("[K] No targets present, hopping...")
            STATE.lastEmptyLog = os.clock()
        end
        serverHop()
    end
end

-- ---------- Main loop ----------
task.spawn(function()
    while true do
        local ok, err = pcall(function()
            scan()
            if #queue > 0 then
                processQueue()
            else
                checkEmpty()
            end
        end)

        if not ok then
            warn("[K] Main loop error:", err)
        end

        task.wait(RESCAN_DELAY)
    end
end)

print("[K] Loaded.")
