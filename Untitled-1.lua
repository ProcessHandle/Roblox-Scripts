local Players          = game:GetService("Players")
local TeleportService  = game:GetService("TeleportService")
local HttpService      = game:GetService("HttpService")

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
local STATS_FLUSH_EVERY = 5
local VISITED_KEEP_RECENT = 30

local LOG_FILE     = "hop_log.json"
local VISITED_FILE = "visited_servers.json"
local STATS_FILE   = "stats.json"
local LOG_MAX      = 500

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

local function loadVisited()
    local list = readJSON(VISITED_FILE, {})
    if type(list) ~= "table" then list = {} end

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
    table.sort(list, function(a, b) return a.at < b.at end)
    writeJSON(VISITED_FILE, list)
end

local function trimVisited(visited, keep, protect)
    keep = keep or VISITED_KEEP_RECENT
    protect = protect or {}

    local list = {}
    for id, at in pairs(visited) do
        table.insert(list, { id = id, at = at })
    end
    table.sort(list, function(a, b) return a.at < b.at end)

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

local function appendHopLog(entry)
    local log = readJSON(LOG_FILE, {})
    if type(log) ~= "table" then log = {} end
    table.insert(log, entry)
    while #log > LOG_MAX do table.remove(log, 1) end
    writeJSON(LOG_FILE, log)
end

local function loadStats()
    local s = readJSON(STATS_FILE, nil)
    if type(s) ~= "table" then
        s = {
            hops = 0,
            eggsFired = 0,
            firstSeen = os.time(),
            lastHop = nil,
            lastJobId = nil,
            lastHopFrom = nil,
            lastHopTo   = nil,
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

local function pickWeighted(list)
    if #list == 0 then return nil end

    local total = 0
    local weights = {}
    for i, c in ipairs(list) do
        local w = 1 / (c.playing + 1)
        weights[i] = w
        total = total + w
    end

    local roll = math.random() * total
    local acc  = 0
    for i, w in ipairs(weights) do
        acc = acc + w
        if roll <= acc then return list[i] end
    end
    return list[#list]
end

local function serverHop()
    if STATE.hopping then return end
    if os.clock() - STATE.lastHopAt < HOP_COOLDOWN then return end
    if STATE.busy or #queue > 0 then return end

    STATE.hopping      = true
    STATE.lastHopAt    = os.clock()
    STATE.hopStartedAt = os.clock()

    local fromJob = game.JobId
    local previousHopFrom = STATS.lastHopFrom
    local previousHopTo   = STATS.lastHopTo

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

    local banned = {
        [fromJob]             = true,
        [previousHopFrom or ""] = true,
        [previousHopTo   or ""] = true,
    }

    local function collect(allowRevisit)
        local out = {}
        for _, v in ipairs(servers) do
            if type(v) == "table"
                and type(v.id) == "string"
                and tonumber(v.playing) and tonumber(v.maxPlayers)
                and v.playing < v.maxPlayers
                and not banned[v.id]
                and (allowRevisit or not visited[v.id])
            then
                table.insert(out, {
                    id      = v.id,
                    playing = tonumber(v.playing) or 0,
                })
            end
        end
        return out
    end

    local candidates = collect(false)

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

        candidates = collect(true)
    end

    if #candidates == 0 then
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

    local pick = pickWeighted(candidates)
    local chosen = pick.id
    print(string.format(
        "[K] Hop: teleporting to %s (%d candidates, picked playing=%d)",
        chosen, #candidates, pick.playing
    ))

    STATS.lastHopFrom = fromJob
    STATS.lastHopTo   = chosen
    STATS.hops        = (STATS.hops or 0) + 1
    STATS.lastHop     = os.time()
    markStatsDirty()

    visited[chosen] = os.time()
    saveVisited(visited)

    endSession("hop")

    flushStats(true)

    appendHopLog({
        event      = "hop",
        from       = fromJob,
        to         = chosen,
        at         = os.time(),
        candidates = #candidates,
        playing    = pick.playing,
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

task.spawn(function()
    while true do
        task.wait(2)
        pcall(flushStats, false)
    end
end)

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

pcall(function()
    if type(getgenv) == "function" then
        local env = getgenv()
        env.__K_endSession = function()
            pcall(endSession, "unload")
        end
    end
end)

print("[K] Loaded. Logs -> hop_log.json, stats.json, visited_servers.json")
