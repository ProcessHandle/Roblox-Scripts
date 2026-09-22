local Players          = game:GetService("Players")
local TeleportService  = game:GetService("TeleportService")
local HttpService      = game:GetService("HttpService")

local TARGETS = {
    BigGloEgg = true, BigHarvestEgg = true, BigBattleEgg = true
}

local TP_DELAY = 0.5
local FIRE_COOLDOWN = 1.5
local RESCAN_DELAY = 2
local REJOIN_DELAY = 3
local REJOIN_COOLDOWN = 12
local REJOIN_TIMEOUT = 25
local JOIN_SETTLE = 20
local FIRE_RETRIES = 3
local FIRE_RETRY_DELAY = 0.4
local STATS_FLUSH_EVERY = 5

local LOG_FILE = "rejoin_log.json"
local STATS_FILE = "stats.json"
local LOG_MAX= 500

local fired = {}
local queued = {}
local queue = {}

local STATE = {
    busy = false,
    hopping = false,
    lastHopAt = 0,
    hopStartedAt = 0,
    joinedAt = os.clock(),
    lastEmptyLog = 0,
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

local function appendRejoinLog(entry)
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
            rejoins    = 0,
            eggsFired  = 0,
            firstSeen  = os.time(),
            lastRejoin = nil,
            lastJobId  = nil,
            placeId    = game.PlaceId,
        }
    end
    return s
end

local STATS           = loadStats()
local STATS_DIRTY     = false
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
    STATS_DIRTY     = false
    STATS_LASTFLUSH = os.clock()
end

local function startSession()
    local prev = STATS.activeSession

    if type(prev) == "table" and prev.jobId and prev.jobId ~= game.JobId and not prev.endedAt then
        appendRejoinLog({
            event     = "session_end_unclean",
            jobId     = prev.jobId,
            placeId   = prev.placeId,
            startedAt = prev.startedAt,
            endedAt   = os.time(),
            note      = "previous session did not close cleanly",
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

    appendRejoinLog({
        event   = "session_start",
        jobId   = game.JobId,
        placeId = game.PlaceId,
        at      = os.time(),
        player  = STATS.activeSession.player,
    })
end

local function endSession(reason)
    if type(STATS.activeSession) == "table" then
        STATS.activeSession.endedAt   = os.time()
        STATS.activeSession.endReason = reason or "unknown"
    end
    markStatsDirty()
    flushStats(true)

    appendRejoinLog({
        event     = "session_end",
        jobId     = game.JobId,
        at        = os.time(),
        reason    = reason or "unknown",
        eggsFired = STATS.eggsFired or 0,
        rejoins   = STATS.rejoins or 0,
    })
end

do
    print(string.format("[K] Session start | job=%s | total rejoins=%d | eggs fired=%d",
        game.JobId, STATS.rejoins or 0, STATS.eggsFired or 0))
    print(string.format("[K] Join settle window: %ds", JOIN_SETTLE))
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

local function rejoin()
    if STATE.hopping then return end
    if os.clock() - STATE.lastHopAt < REJOIN_COOLDOWN then return end
    if STATE.busy or #queue > 0 then return end

    STATE.hopping      = true
    STATE.lastHopAt    = os.clock()
    STATE.hopStartedAt = os.clock()

    local fromJob = game.JobId
    print("[K] Rejoining same instance:", fromJob)

    STATS.rejoins    = (STATS.rejoins or 0) + 1
    STATS.lastRejoin = os.time()
    markStatsDirty()

    endSession("rejoin")
    flushStats(true)

    appendRejoinLog({
        event     = "rejoin",
        from      = fromJob,
        to        = fromJob,
        at        = os.time(),
        rejoinNum = STATS.rejoins,
    })

    local requeue = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/ProcessHandle/Roblox-Scripts/refs/heads/main/Untitled-1.lua"))()'

    local queued_ok = false
    if type(syn) == "table" and syn.queue_on_teleport then
        queued_ok = pcall(syn.queue_on_teleport, requeue)
    elseif type(queue_on_teleport) == "function" then
        queued_ok = pcall(queue_on_teleport, requeue)
    end

    if not queued_ok then
        warn("[K] No queue_on_teleport support - script will NOT reload after rejoin")
        appendRejoinLog({
            event  = "rejoin_failed",
            reason = "no_queue_on_teleport",
            from   = fromJob,
            at     = os.time(),
        })
        STATE.hopping = false
        return
    end

    task.wait(REJOIN_DELAY)

    local success, err = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, fromJob, Players.LocalPlayer)
    end)

    if not success then
        warn("[K] Rejoin: teleport failed:", err)
        appendRejoinLog({
            event  = "teleport_failed",
            from   = fromJob,
            to     = fromJob,
            error  = tostring(err),
            at     = os.time(),
        })
        STATS.rejoins = math.max(0, (STATS.rejoins or 1) - 1)
        markStatsDirty()
        flushStats(true)
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
    if STATE.hopping and os.clock() - STATE.hopStartedAt > REJOIN_TIMEOUT then
        warn("[K] Rejoin timeout, resetting rejoin state")
        appendRejoinLog({
            event = "rejoin_timeout",
            from  = game.JobId,
            at    = os.time(),
        })
        STATE.hopping = false
    end

    if STATE.hopping or STATE.busy or #queue > 0 then
        return
    end

    if os.clock() - STATE.joinedAt < JOIN_SETTLE then
        return
    end

    if not hasTargets() then
        if os.clock() - STATE.lastEmptyLog > 5 then
            print(string.format("[K] No targets after %ds settle, rejoining...", JOIN_SETTLE))
            STATE.lastEmptyLog = os.clock()
        end
        rejoin()
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

print("[K] Loaded. Logs -> rejoin_log.json, stats.json")
