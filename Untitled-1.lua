-- ============================================================
--  Auto Farm (Egg Collection + Server Hop)
--  Consolidated single-loop, robust fetch, no console spam
--  + File-based hop tracking (visited_servers.json, hop_log.json, stats.json)
--  + Client-safe session tracking (no BindToClose)
--  + Chain-aware hopping: never returns to the previous server
-- ============================================================

local Players          = game:GetService("Players")
local TeleportService  = game:GetService("TeleportService")
local HttpService      = game:GetService("HttpService")

-- ---------- Config ----------
local TARGETS = {
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
local STATS_FLUSH_EVERY = 5   -- seconds between stats.json writes

-- How many recent servers to keep in the "recently visited" set.
-- When we run out of fresh candidates we trim down to this many
-- (most recent first) instead of wiping the whole list.
local VISITED_KEEP_RECENT = 30

-- ---------- Tracking config ----------
local LOG_FILE     = "hop_log.json"
local VISITED_FILE = "visited_servers.json"
local STATS_FILE   = "stats.json"
local LOG_MAX      = 500

-- ---------- State ----------
local fired  = {}
local queued = {}
local queue  = {}

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

-- ---------- Visited servers (ordered list, most recent last) ----------
-- Stored as an array of { id = <string>, at = <os.time> } so we can
-- trim the oldest entries when we need to free up candidates.
local function loadVisited()
    local list = readJSON(VISITED_FILE, {})
    if type(list) ~= "table" then list = {} end

    -- Backwards-compat: old format was a flat array of strings.
    local visited = {}
    for _, entry in ipairs(list) do
        if type(entry) == "string" then
            visited[entry] = os.time()
        elseif type(entry) == "table" and type(entry.id) == "string" then
            visited[entry.id] = tonumber(entry.at) or os.time()
        end
    end
    visited[game.JobId] = os.time()
    return visited
end

local function saveVisited(visited)
    local list = {}
    for id, at in pairs(visited) do
        table.insert(list, { id = id, at = at })
    end
    -- Most recent last
    table.sort(list, function(a, b) return a.at < b.at end)
    writeJSON(VISITED_FILE, list)
end

-- Drop the oldest visited entries until we're at or below `keep`.
local function trimVisited(visited, keep, protect)
    keep = keep or VISITED_KEEP_RECENT
    protect = protect or {}

    local list = {}
    for id, at in pairs(visited) do
        table.insert(list, { id = id, at = at })
    end
    table.sort(list, function(a, b) return a.at < b.at end) -- oldest first

    local removed = 0
    for _, entry in ipairs(list) do
        local n = 0
        for _ in pairs(visited) do n = n + 1 end
        if n <= keep then break end
        if not protect[entry.id] then
            visited[entry.id] = nil
            removed = removed + 1
        end
    end
    return removed
end

-- ---------- Hop log ----------
local function appendHopLog(entry)
    local log = readJSON(LOG_FILE, {})
    if type(log) ~= "table" then log = {} end
    table.insert(log, entry)
    while #log > LOG_MAX do table.remove(log, 1) end
    writeJSON(LOG_FILE, log)
end

-- ---------- Stats (with debounced writes) ----------
local function loadStats()
    local s = readJSON(STATS_FILE, nil)
    if type(s) ~= "table" then
        s = {
            hops = 0,
            eggsFired = 0,
            firstSeen = os.time(),
            lastHop = nil,
            lastJobId = nil,
            lastHopFrom = nil,   -- server we were on before the last hop
            lastHopTo   = nil,   -- server we landed on after the last hop
            placeId = game.PlaceId,
        }
    end
    return s
end

local STATS          = loadStats()
local STATS_DIRTY    = false
local STATS_LASTFLUSH = 0

local function markStatsDirty()
    STATS_DIRTY = true
end

local function flushStats(force)
    if not STATS_DIRTY and not force then return end
    if not force and os.clock() - STATS_LASTFLUSH < STATS_FLUSH_EVERY then return end
    STATS.lastJobId = game.JobId
    STATS.placeId   = game.PlaceId
    STATS.updatedAt = os.time()
    writeJSON(STATS_FILE, STATS)
    STATS_DIRTY      = false
    STATS_LASTFLUSH  = os.clock()
end

-- ---------- Session tracking (client-safe) ----------
local function startSession()
    local prev = STATS.activeSession

    if type(prev) == "table" and prev.jobId and prev.jobId ~= game.JobId and not prev.endedAt then
        appendHopLog({
            event   = "session_end_unclean",
            jobId   = prev.jobId,
            placeId = prev.placeId,
            startedAt = prev.startedAt,
            endedAt   = os.time(),
            note    = "previous session did not close cleanly",
        })
    end

    STATS.activeSession = {
        jobId     = game.JobId,
        placeId   = game.PlaceId,
        startedAt = os.time(),
        player    = Players.LocalPlayer and Players.LocalPlayer.Name or "?",
    }
    markStatsDirty()
    flushStats(true)

    appendHopLog({
        event    = "session_start",
        jobId    = game.JobId,
        placeId  = game.PlaceId,
        at       = os.time(),
        player   = STATS.activeSession.player,
    })
end

local function endSession(reason)
    if type(STATS.activeSession) == "table" then
        STATS.activeSession.endedAt = os.time()
        STATS.activeSession.endReason = reason or "unknown"
    end
    markStatsDirty()
    flushStats(true)

    appendHopLog({
        event     = "session_end",
        jobId     = game.JobId,
        at        = os.time(),
        reason    = reason or "unknown",
        eggsFired = STATS.eggsFired or 0,
        hops      = STATS.hops or 0,
    })
end

-- ---------- Boot ----------
local visited = loadVisited()
do
    local n = 0
    for _ in pairs(visited) do n = n + 1 end
    print("[K] Visited servers loaded:", n)
    print(string.format("[K] Session start | job=%s | total hops=%d | eggs fired=%d",
        game.JobId, STATS.hops or 0, STATS.eggsFired or 0))
    print(string.format("[K] Last hop: %s -> %s",
        tostring(STATS.lastHopFrom), tostring(STATS.lastHopTo)))

    startSession()
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

    -- Mark current + remember what we're leaving
    local fromJob = game.JobId
    local previousHopFrom = STATS.lastHopFrom  -- server before our last hop
    local previousHopTo   = STATS.lastHopTo    -- server we landed on last hop

    visited[fromJob] = os.time()
    saveVisited(visited)

    print("[K] Hop: fetching server list (from", fromJob .. ")")

    local servers = fetchServers()

    if not servers then
        warn("[K] Hop: could not fetch server list. Short cooldown, will retry.")
        appendHopLog({
            event   = "hop_failed",
            reason  = "fetch_failed",
            from    = fromJob,
            at      = os.time(),
        })
        STATE.hopping   = false
        STATE.lastHopAt = os.clock() - HOP_COOLDOWN + 4
        return
    end

    -- Servers we must never pick as the next hop:
    --   * the current server
    --   * the server we just came from (previousHopFrom)
    --   * the server we landed on last time (previousHopTo) -- same as current
    --     after a successful hop, but guards against requeue timing
    local banned = {
        [fromJob]             = true,
        [previousHopFrom or ""] = true,
        [previousHopTo   or ""] = true,
    }

    local candidates = {}
    for _, v in ipairs(servers) do
        if type(v) == "table"
            and type(v.id) == "string"
            and tonumber(v.playing) and tonumber(v.maxPlayers)
            and v.playing < v.maxPlayers
            and not banned[v.id]
            and not visited[v.id]
        then
            table.insert(candidates, v.id)
        end
    end

    -- Fallback: if we've already visited every open server, prefer servers
    -- that aren't the previous hop, then allow revisits, but never the
    -- server we just came from.
    if #candidates == 0 then
        print("[K] Hop: no fresh servers; trimming visited cache and allowing revisits")

        local removed = trimVisited(visited, VISITED_KEEP_RECENT, {
            [fromJob] = true,
            [previousHopFrom or ""] = true,
        })
        saveVisited(visited)

        appendHopLog({
            event   = "visited_trim",
            reason  = "no_fresh_candidates",
            from    = fromJob,
            removed = removed,
            at      = os.time(),
        })

        for _, v in ipairs(servers) do
            if type(v) == "table"
                and type(v.id) == "string"
                and tonumber(v.playing) and tonumber(v.maxPlayers)
                and v.playing < v.maxPlayers
                and not banned[v.id]
            then
                table.insert(candidates, v.id)
            end
        end
    end

    if #candidates == 0 then
        -- Extremely rare: everything is full or banned. Back off and retry.
        warn("[K] Hop: no valid candidates at all; backing off")
        appendHopLog({
            event  = "hop_failed",
            reason = "no_candidates",
            from   = fromJob,
            at     = os.time(),
        })
        STATE.hopping   = false
        STATE.lastHopAt = os.clock() - HOP_COOLDOWN + 6
        return
    end

    -- Avoid re-picking the same candidate on retry after a failure.
    local chosen = candidates[math.random(1, #candidates)]
    print("[K] Hop: teleporting to", chosen, "(" .. #candidates .. " candidates)")

    -- Persist the hop edge *before* teleporting so the next session
    -- (reloaded via queue_on_teleport) inherits the chain.
    STATS.lastHopFrom = fromJob
    STATS.lastHopTo   = chosen
    STATS.hops        = (STATS.hops or 0) + 1
    STATS.lastHop     = os.time()
    markStatsDirty()

    visited[chosen] = os.time()
    saveVisited(visited)

    -- Clean session end so hop_log shows the boundary.
    endSession("hop")

    flushStats(true)

    appendHopLog({
        event      = "hop",
        from       = fromJob,
        to         = chosen,
        at         = os.time(),
        candidates = #candidates,
        hopNumber  = STATS.hops,
    })

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
            from   = fromJob,
            to     = chosen,
            error  = tostring(err),
            at     = os.time(),
        })
        -- Roll back the chain edge so the next attempt doesn't inherit
        -- a hop that never happened.
        STATS.lastHopFrom = previousHopFrom
        STATS.lastHopTo   = previousHopTo
        STATS.hops        = math.max(0, (STATS.hops or 1) - 1)
        markStatsDirty()
        flushStats(true)

        visited[chosen] = nil
        saveVisited(visited)

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
                    markStatsDirty()
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

-- ---------- Periodic stats flusher ----------
task.spawn(function()
    while true do
        task.wait(2)
        pcall(flushStats, false)
    end
end)

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

-- ---------- Manual end hook (for executors that support it) ----------
pcall(function()
    if type(getgenv) == "function" then
        local env = getgenv()
        env.__K_endSession = function()
            pcall(endSession, "unload")
        end
    end
end)

print("[K] Loaded. Logs -> hop_log.json, stats.json, visited_servers.json")
