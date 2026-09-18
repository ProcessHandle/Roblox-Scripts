local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FisherKiosk = ReplicatedStorage.Networking.Requests:WaitForChild("FisherKiosk")

local HOP_DELAY = 3
local HOP_COOLDOWN = 15
local MIN_UPGRADE_MARGIN = 1.05
local MIN_OFFER_SCORE_TO_STAY = 120

local function loadVisited()
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile("visited_fisher.json"))
    end)
    local visited = {}
    if ok and type(data) == "table" then
        for i, v in ipairs(data) do
            visited[v] = true
        end
    end
    visited[game.JobId] = true
    return visited
end

local function saveVisited(visited)
    local list = {}
    for i, v in pairs(visited) do
        table.insert(list, i)
    end
    pcall(function()
        writefile("visited_fisher.json", HttpService:JSONEncode(list))
    end)
end

local visited = loadVisited()
local hopping = false
local lastHop = 0

local function score(f)
    if not f then return -math.huge end
    return (f.power or 0) + (f.speed or 0) + (f.efficiency or 0) + (f.quality or 0)
end

local function invoke(action, arg)
    local ok, result = pcall(function()
        return FisherKiosk:InvokeServer(action, arg)
    end)
    return ok and result or nil
end

local function pickWorst(state)
    local idx, s = nil, math.huge
    for i = 1, state.stations do
        local h = state.hired and state.hired[i]
        if h then
            local sc = score(h)
            if sc < s then
                s = sc
                idx = i
            end
        end
    end
    return idx, s
end

local function pickBest(state)
    local best, s = nil, -math.huge
    for i, v in ipairs(state.offers or {}) do
        local sc = score(v)
        if sc > s then
            s = sc
            best = v
        end
    end
    return best, s
end

local function tick(state)
    if not state or not state.harborOk then return false end

    local worstIdx, worstScore = pickWorst(state)
    local bestOffer, bestScore = pickBest(state)
    if not bestOffer then return false end

    local crew = 0
    for i = 1, state.stations do
        if state.hired and state.hired[i] then
            crew = crew + 1
        end
    end

    if crew < state.stations then
        if state.money >= bestOffer.salary then
            print(("[FH] Hire %s (%.0f) cost %d"):format(bestOffer.name, bestScore, bestOffer.salary))
            invoke("hire", bestOffer.uid)
        end
        return true
    end

    if worstIdx and bestScore > worstScore * MIN_UPGRADE_MARGIN then
        print(("[FH] Fire #%d (%.0f) -> hire %s (%.0f)"):format(worstIdx, worstScore, bestOffer.name, bestScore))
        invoke("dismiss", worstIdx)
        task.wait(0.4)
        invoke("hire", bestOffer.uid)
        return true
    end

    if bestScore < MIN_OFFER_SCORE_TO_STAY then
        return false
    end
    return true
end

local function serverHop()
    if hopping then return end
    if os.clock() - lastHop < HOP_COOLDOWN then
        print("[FH] Hop on cooldown:", HOP_COOLDOWN - (os.clock() - lastHop))
        return
    end

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
        print("[FH] Server list fetch failed")
        hopping = false
        return
    end

    local servers = {}
    for i, v in next, body.data do
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
        print("[FH] No fresh servers, resetting visited")
        visited = { [game.JobId] = true }
        saveVisited(visited)
        hopping = false
        return
    end

    local chosen = servers[math.random(1, #servers)]
    print("[FH] Hopping to", chosen)

    local requeue = 'loadstring(game:HttpGet("https://raw.githubusercontent.com/ProcessHandle/Roblox-Scripts/refs/heads/main/autohire.lua"))()'
    if type(syn) == "table" and syn.queue_on_teleport then
        pcall(syn.queue_on_teleport, requeue)
    elseif type(queue_on_teleport) == "function" then
        pcall(queue_on_teleport, requeue)
    end

    task.wait(HOP_DELAY)
    local success = pcall(function()
        TeleportService:TeleportToPlaceInstance(game.PlaceId, chosen, Players.LocalPlayer)
    end)

    if not success then
        hopping = false
    end
end

print("[FH] Started, visited:", (function()
    local n = 0
    for i, v in pairs(visited) do
        n = n + 1
    end
    return n
end)())

local lastRemaining = nil
while true do
    local state = invoke("state")
    if not state then
        task.wait(2)
        continue
    end

    local remaining = state.refreshIn or 0

    if lastRemaining == nil or remaining > lastRemaining then
        local shouldStay = tick(state)
        if not shouldStay then
            print("[FH] Conditions not met, hopping")
            serverHop()
        end
    end

    lastRemaining = remaining
    task.wait(math.max(1, remaining))
end
