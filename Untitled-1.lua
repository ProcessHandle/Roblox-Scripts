-- ============================================================
--  Auto Farm (Egg Collection + Server Hop)
--  Consolidated single-loop, robust fetch, no console spam
--  + File-based hop tracking (visited_servers.json, hop_log.json, stats.json)
-- ============================================================

local Players          = game:GetService("Players")
local TeleportService  = game:GetService("TeleportService")
local HttpService      = game:GetService("HttpService")

-- ---------- Config ----------
local TARGETS = {
    BattleEgg = true,
    BigGloEgg = true, BigHarvestEgg = true, BigBattleEgg = true
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

-- ---------- Tracking config ----------
local LOG_FILE    = "hop_log.json"
local VISITED_FILE = "visited_servers.json"
local STATS_FILE  = "stats.json"
local LOG_MAX     = 500   -- cap hop_log.json entries

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

-- ============================================================
--  File helpers
-- ============================================================

local function readJSON(path, fallback)
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)
    if ok and type(data) == "table" then return data end
    return fallback
end

local function writeJSON(path, tbl)
    pcall(function()
        writefile(path, HttpService:JSONEncode(tbl))
    end)
end

-- ---------- Visited server persistence ----------
local function loadVisited()
    local visited = {}
    local data = readJSON(VISITED_FILE, {})
    for _, id in ipairs(data) do
        if type(id) == "string" then visited[id] = true end
    end
    visited[game.JobId] = true
    return visited
end

local function saveVisited(visited)
    local list = {}
    for id in pairs(visited) do table.insert(list, id) end
    writeJSON(VISITED_FILE, list)
end

-- ---------- Hop log (append-only, capped) ----------
local function appendHopLog(entry)
    local log = readJSON(LOG_FILE, {})
    if type(log) ~= "table" then log = {} end
    table.insert(log, entry)
    while #log > LOG_MAX do table.remove(log, 1) end
    writeJSON(LOG_FILE, log)
end

-- ---------- Stats (aggregate counters) ----------
local function loadStats()
    local s = readJSON(STATS_FILE, nil)
    if type(s) ~= "table" then
        s = {
            hops = 0,
            eggsFired = 0,
            firstSeen = os.time(),
            lastHop = nil,
            lastJobId = nil,
            placeId = game.PlaceId,
        }
    end
    return s
end

local function saveStats(s)
    s.lastJobId = game.JobId
    s.placeId   = game.PlaceId
    s.updatedAt = os.time()
    writeJSON(STATS_FILE, s)
end

local STATS = loadStats()

-- ---------- Boot log ----------
local visited = loadVisited()
do
    local n = 0
    for _ in pairs(visited) do n = n + 1 end
    print("[K] Visited servers loaded:", n)
    print(string.format("[K] Session start | job=%s | total hops logged=%d | eggs fired=%d",
        game.JobId, STATS.hops or 0, STATS.eggsFired or 0))

    -- Record this session's entry into the hop log
    appendHopLog({
        event    = "session_start",
        jobId    = game.JobId,
        placeId  = game.PlaceId,
        at       = os.time(),
        player   = Players.LocalPlayer and Players.LocalPlayer.Name or "?",
    })
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
        appendHopLog({
            event   = "hop_failed",
            reason  = "fetch_failed",
            from    = game.JobId,
            at      = os.time(),
        })
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
        appendHopLog({
            event   = "visited_reset",
            reason  = "no_fresh_candidates",
            from    = game.JobId,
            at      = os.time(),
        })
        visited = { [game.JobId] = true }
        saveVisited(visited)
        STATE.hopping   = false
        STATE.lastHopAt = os.clock() - HOP_COOLDOWN + 2
        return
    end

    local chosen = candidates[math.random(1, #candidates)]
    print("[K] Hop: teleporting to", chosen, "(" .. #candidates .. " candidates)")

    -- ---------- Persistent tracking before we leave ----------
    STATS.hops      = (STATS.hops or 0) + 1
    STATS.lastHop   = os.time()
    STATS.eggsFired = STATS.eggsFired or 0
    saveStats(STATS)

    appendHopLog({
        event     = "hop",
        from      = game.JobId,
        to        = chosen,
        at        = os.time(),
        candidates = #candidates,
        hopNumber = STATS.hops,
    })
    -- ----------------------------------------------------------

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
        appendHopLog({
            event  = "teleport_failed",
            from   = game.JobId,
            to     = chosen,
            error  = tostring(err),
            at     = os.time(),
        })
        STATE.hopping = false
    end
end

-- ---------- Scanning ----------
local function scan()
    for _, child in ipairs(workspace:GetChildren()) do
        if TARGETS[child.Name] then
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
                    STATS.eggsFired = (STATS.eggsFired or 0) + 1
                    saveStats(STATS)
                end
            end
        end

        task.wait(FIRE_COOLDOWN)
    end

    STATE.busy = false
end

-- ---------- Empty check ----------
local function checkEmpty()
    if STATE.hopping and os.clock() - STATE.hopStartedAt > HOP_TIMEOUT then
        warn("[K] Hop timeout, resetting hop state")
        appendHopLog({
            event  = "hop_timeout",
            from   = game.JobId,
            at     = os.time(),
        })
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

-- ---------- Shutdown hook (best effort) ----------
game:BindToClose(function()
    appendHopLog({
        event   = "session_end",
        jobId   = game.JobId,
        at      = os.time(),
        eggsFired = STATS.eggsFired or 0,
        hops    = STATS.hops or 0,
    })
end)

print("[K] Loaded. Logs -> hop_log.json, stats.json, visited_servers.json")
