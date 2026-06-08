local BUTTONS_PATH = workspace.Map.Lobby.Lobby.Minigames.Minesweeper.Buttons
local DISPLAYS_PATH = workspace.Map.Lobby.Lobby.Minigames.Minesweeper.Displays

local GRID_SIZE = 10
local TOTAL_MINES = 20
local RESET_DELAY = 3

local FIRST_CLICK = {5, 5}

local stats = {
    roundsCompleted = 0,
    safeClicks = 0,
    mineHits = 0,
    sevensFound = 0,
    sixesFound = 0,
    fivesFound = 0,
    highestEver = 0,
    startTime = os.clock(),
    boardsCompleted = 0,
    consecutiveWins = 0,
    bestWinStreak = 0,
}

local roundStats = {
    tilesRevealed = 0,
    highestSeen = 0,
    minesFlagged = 0,
    minesHitThisRound = 0,
    startTime = 0,
}

local grid = {}

local function buildGrid()
    grid = {}
    local missingCount = 0

    for row = 1, GRID_SIZE do
        grid[row] = {}
        for col = 1, GRID_SIZE do
            local button  = BUTTONS_PATH:FindFirstChild(tostring(row))
                        and BUTTONS_PATH[tostring(row)]:FindFirstChild(tostring(col))
            local display = DISPLAYS_PATH:FindFirstChild(tostring(row))
                        and DISPLAYS_PATH[tostring(row)]:FindFirstChild(tostring(col))

            if button and display then
                local clickDetector = button:FindFirstChild("ClickDetector")
                local sg            = display:FindFirstChild("SG")

                if clickDetector and sg then
                    local nLabel    = sg:FindFirstChild("NLabel")
                    local bombImage = sg:FindFirstChild("BImage")

                    if nLabel and bombImage then
                        grid[row][col] = {
                            row          = row,
                            col          = col,
                            button       = button,
                            display      = display,
                            clickDetector = clickDetector,
                            nLabel       = nLabel,
                            bombImage    = bombImage,
                            state        = "unclicked",
                            num          = nil,
                            neighborMines = nil,
                            isMine       = false,
                        }
                    else missingCount = missingCount + 1 end
                else missingCount = missingCount + 1 end
            else missingCount = missingCount + 1 end
        end
    end

    if missingCount > 0 then
        warn("Missing cells: " .. missingCount)
    else
        print("✅ Grid built — all " .. (GRID_SIZE * GRID_SIZE) .. " cells found")
    end
end

local function getNeighbors(row, col)
    local neighbors = {}
    for dr = -1, 1 do
        for dc = -1, 1 do
            if (dr ~= 0 or dc ~= 0) then
                local r, c = row + dr, col + dc
                if grid[r] and grid[r][c] then
                    table.insert(neighbors, {row = r, col = c})
                end
            end
        end
    end
    return neighbors
end

local function isBombRevealed(row, col)
    local cell = grid[row][col]
    return cell and cell.bombImage and cell.bombImage.Visible == true
end

local function readNumber(row, col)
    local cell = grid[row][col]
    if cell and cell.nLabel then
        return tonumber(cell.nLabel.Text)
    end
    return nil
end

local function scanBoardForMissedTiles()
    local foundCount = 0
    for row = 1, GRID_SIZE do
        for col = 1, GRID_SIZE do
            local cell = grid[row][col]
            if cell and cell.state == "unclicked" then
                local isTransparent = cell.button and cell.button.Transparency > 0.9
                local hasNumber     = cell.nLabel and cell.nLabel.Visible
                                      and cell.nLabel.Text and cell.nLabel.Text ~= ""
                local isBomb        = cell.bombImage and cell.bombImage.Visible

                if isBomb then
                    cell.state  = "bomb"
                    cell.isMine = true
                    roundStats.minesHitThisRound = roundStats.minesHitThisRound + 1
                    stats.mineHits = stats.mineHits + 1
                    foundCount = foundCount + 1

                elseif isTransparent or hasNumber then
                    cell.state = "clicked"
                    roundStats.tilesRevealed = roundStats.tilesRevealed + 1

                    local num = hasNumber and tonumber(cell.nLabel.Text) or 0
                    cell.num          = num or 0
                    cell.neighborMines = num or 0

                    if num and num > 0 then
                        if num == 5 then stats.fivesFound = stats.fivesFound + 1
                        elseif num == 6 then stats.sixesFound = stats.sixesFound + 1
                        elseif num == 7 then
                            stats.sevensFound = stats.sevensFound + 1
                            stats.highestEver = 7
                            print("🎉 FOUND 7 at [" .. row .. "," .. col .. "]!")
                        end
                        if num > roundStats.highestSeen then
                            roundStats.highestSeen = num
                        end
                    end
                    foundCount = foundCount + 1
                end
            end
        end
    end
    return foundCount
end

local function clickCell(row, col)
    local cell = grid[row][col]
    if not cell then return false, nil end
    if cell.state ~= "unclicked" then return false, nil end
    if cell.isMine then return false, nil end

    fireclickdetector(cell.clickDetector)
    task.wait(0.05)

    if isBombRevealed(row, col) then
        cell.state  = "bomb"
        cell.isMine = true
        roundStats.minesHitThisRound = roundStats.minesHitThisRound + 1
        stats.mineHits = stats.mineHits + 1
        return false, "mine"
    end

    cell.state = "clicked"
    roundStats.tilesRevealed = roundStats.tilesRevealed + 1

    local num = readNumber(row, col) or 0
    cell.num          = num
    cell.neighborMines = num

    if num == 5 then stats.fivesFound = stats.fivesFound + 1
    elseif num == 6 then stats.sixesFound = stats.sixesFound + 1
    elseif num == 7 then
        stats.sevensFound = stats.sevensFound + 1
        stats.highestEver = 7
        print("🎉 FOUND 7 at [" .. row .. "," .. col .. "]!")
    end
    if num > roundStats.highestSeen then roundStats.highestSeen = num end

    scanBoardForMissedTiles()
    return true, num
end

local function resetBoardState()
    for row = 1, GRID_SIZE do
        for col = 1, GRID_SIZE do
            if grid[row][col] then
                grid[row][col].state        = "unclicked"
                grid[row][col].num          = nil
                grid[row][col].isMine       = false
                grid[row][col].neighborMines = nil
            end
        end
    end
    roundStats.tilesRevealed     = 0
    roundStats.highestSeen       = 0
    roundStats.minesFlagged      = 0
    roundStats.minesHitThisRound = 0
    roundStats.startTime         = os.clock()
end

local function countRemainingMines()
    local flagged = 0
    for row = 1, GRID_SIZE do
        for col = 1, GRID_SIZE do
            if grid[row][col] and grid[row][col].isMine then
                flagged = flagged + 1
            end
        end
    end
    return TOTAL_MINES - flagged
end

local function isBoardSolved()
    for row = 1, GRID_SIZE do
        for col = 1, GRID_SIZE do
            local cell = grid[row][col]
            if cell and cell.state == "unclicked" and not cell.isMine then
                return false
            end
        end
    end
    return true
end

local function checkRoundLost()
    scanBoardForMissedTiles()
    for row = 1, GRID_SIZE do
        for col = 1, GRID_SIZE do
            if grid[row][col] and grid[row][col].state == "bomb" then
                return true
            end
        end
    end
    return false
end

local function buildConstraints()
    local constraints = {}

    for row = 1, GRID_SIZE do
        for col = 1, GRID_SIZE do
            local cell = grid[row][col]
            if cell and cell.state == "clicked" and cell.neighborMines then
                local unknowns   = {}
                local knownMines = 0

                for _, n in ipairs(getNeighbors(row, col)) do
                    local nc = grid[n.row][n.col]
                    if nc.isMine and nc.state ~= "unclicked" then
                        knownMines = knownMines + 1
                    elseif nc.isMine then
                        knownMines = knownMines + 1
                    elseif nc.state == "unclicked" then
                        table.insert(unknowns, {row = n.row, col = n.col})
                    end
                end

                local remaining = cell.neighborMines - knownMines
                if #unknowns > 0 and remaining >= 0 then
                    table.insert(constraints, {cells = unknowns, mines = remaining})
                end
            end
        end
    end

    return constraints
end

local function runConstraintSolver(constraints)
    local safes = {}
    local mines = {}

    local function cellKey(c) return c.row .. "," .. c.col end

    local function isSubset(setA, setB)
        local lookup = {}
        for _, c in ipairs(setB) do lookup[cellKey(c)] = true end
        for _, c in ipairs(setA) do
            if not lookup[cellKey(c)] then return false end
        end
        return true
    end

    local function setDifference(setB, setA)
        local lookup = {}
        for _, c in ipairs(setA) do lookup[cellKey(c)] = true end
        local diff = {}
        for _, c in ipairs(setB) do
            if not lookup[cellKey(c)] then table.insert(diff, c) end
        end
        return diff
    end

    for _, con in ipairs(constraints) do
        if con.mines == 0 then
            for _, c in ipairs(con.cells) do
                safes[cellKey(c)] = {row = c.row, col = c.col}
            end
        elseif con.mines == #con.cells then
            for _, c in ipairs(con.cells) do
                mines[cellKey(c)] = {row = c.row, col = c.col}
            end
        end
    end

    for i = 1, #constraints do
        for j = 1, #constraints do
            if i ~= j then
                local A = constraints[i]
                local B = constraints[j]

                if #A.cells < #B.cells and isSubset(A.cells, B.cells) then
                    local diff     = setDifference(B.cells, A.cells)
                    local diffMines = B.mines - A.mines

                    if diffMines == 0 then
                        for _, c in ipairs(diff) do
                            safes[cellKey(c)] = {row = c.row, col = c.col}
                        end
                    elseif diffMines == #diff then
                        for _, c in ipairs(diff) do
                            mines[cellKey(c)] = {row = c.row, col = c.col}
                        end
                    end
                end
            end
        end
    end

    local safeList, mineList = {}, {}
    for _, v in pairs(safes) do table.insert(safeList, v) end
    for _, v in pairs(mines) do table.insert(mineList, v) end

    return safeList, mineList
end

local function fullDeductionPass()
    local anyChange = false

    for _ = 1, 50 do
        local constraints      = buildConstraints()
        local safeList, mineList = runConstraintSolver(constraints)
        local changed          = false

        for _, m in ipairs(mineList) do
            local cell = grid[m.row][m.col]
            if cell and cell.state == "unclicked" and not cell.isMine then
                cell.isMine = true
                roundStats.minesFlagged = roundStats.minesFlagged + 1
                changed   = true
                anyChange = true
            end
        end

        for _, s in ipairs(safeList) do
            local cell = grid[s.row][s.col]
            if cell and cell.state == "unclicked" and not cell.isMine then
                local success = clickCell(s.row, s.col)
                if success then
                    stats.safeClicks = stats.safeClicks + 1
                    changed   = true
                    anyChange = true
                end
                task.wait(0.01)
                if checkRoundLost() or isBoardSolved() then return anyChange end
            end
        end

        if not changed then break end
        task.wait(0.01)
    end

    return anyChange
end

local function estimateProbabilities(constraints)
    local counts    = {}  
    local numTerms  = {} 

    local function key(r, c) return r .. "," .. c end

    for _, con in ipairs(constraints) do
        local density = #con.cells > 0 and (con.mines / #con.cells) or 0
        for _, c in ipairs(con.cells) do
            local k = key(c.row, c.col)
            counts[k]   = (counts[k]   or 0) + density
            numTerms[k] = (numTerms[k] or 0) + 1
        end
    end

    local remaining   = countRemainingMines()
    local totalUnknown = 0
    for row = 1, GRID_SIZE do
        for col = 1, GRID_SIZE do
            local cell = grid[row][col]
            if cell and cell.state == "unclicked" and not cell.isMine then
                totalUnknown = totalUnknown + 1
            end
        end
    end
    local globalDensity = totalUnknown > 0 and (remaining / totalUnknown) or 0.5

    local candidates = {}
    for row = 1, GRID_SIZE do
        for col = 1, GRID_SIZE do
            local cell = grid[row][col]
            if cell and cell.state == "unclicked" and not cell.isMine then
                local k    = key(row, col)
                local prob

                if numTerms[k] and numTerms[k] > 0 then
                    prob = counts[k] / numTerms[k]
                else
                    local edgeDist = math.min(row - 1, GRID_SIZE - row, col - 1, GRID_SIZE - col)
                    prob = globalDensity * (1 - edgeDist * 0.02)
                end

                table.insert(candidates, {row = row, col = col, prob = prob})
            end
        end
    end

    table.sort(candidates, function(a, b) return a.prob < b.prob end)
    return candidates
end

local function printStats()
    local elapsed     = os.clock() - stats.startTime
    local totalClicks = stats.safeClicks + stats.mineHits
    local winRate     = stats.roundsCompleted > 0
                        and (stats.boardsCompleted / stats.roundsCompleted * 100) or 0
    local roundsPerMin = stats.roundsCompleted / math.max(elapsed / 60, 0.01)

    print(string.format([[
╔══════════════════════════════════════╗
║      MINESWEEPER SOLVER STATS       ║
╠══════════════════════════════════════╣
║ Rounds:           %-18d ║
║ Boards Won:       %-18d ║
║ Win Rate:         %-17.1f%% ║
║ Win Streak:       %-18d ║
║ Best Streak:      %-18d ║
║ Safe Clicks:      %-18d ║
║ Mine Hits:        %-18d ║
║ 7s Found:         %-18d ║
║ 6s Found:         %-18d ║
║ 5s Found:         %-18d ║
║ Rounds/min:       %-18.1f ║
║ Time:             %-14.1f min ║
╚══════════════════════════════════════╝]],
        stats.roundsCompleted,
        stats.boardsCompleted,
        winRate,
        stats.consecutiveWins,
        stats.bestWinStreak,
        stats.safeClicks,
        stats.mineHits,
        stats.sevensFound,
        stats.sixesFound,
        stats.fivesFound,
        roundsPerMin,
        elapsed / 60
    ))
end

print("🚀 Minesweeper Solver — Constraint Propagation Edition")
print("📊 10x10 grid | 20 mines")
print("🧠 Uses subset/constraint analysis for maximum logical deduction")
print("")

buildGrid()
resetBoardState()

local lastStatsTime = os.clock()
local roundPhase    = "first_click"
local roundEnded    = false  

while true do

    if roundPhase == "first_click" then
        roundEnded = false
        local success = clickCell(FIRST_CLICK[1], FIRST_CLICK[2])
        if success then stats.safeClicks = stats.safeClicks + 1 end
        roundPhase = "solving"
        task.wait(0.05)
        continue
    end

    if roundEnded then
        task.wait(0.1)
        continue
    end

    if isBoardSolved() then
        roundEnded = true
        stats.roundsCompleted  = stats.roundsCompleted + 1
        stats.boardsCompleted  = stats.boardsCompleted + 1
        stats.consecutiveWins  = stats.consecutiveWins + 1
        stats.bestWinStreak    = math.max(stats.bestWinStreak, stats.consecutiveWins)

        print(string.format("✅ WIN #%d! Streak: %d | Win rate: %.1f%%",
            stats.boardsCompleted,
            stats.consecutiveWins,
            stats.boardsCompleted / stats.roundsCompleted * 100))

        task.wait(RESET_DELAY)
        resetBoardState()
        roundPhase = "first_click"
        continue
    end

    if checkRoundLost() then
        roundEnded = true
        stats.roundsCompleted = stats.roundsCompleted + 1
        stats.consecutiveWins = 0

        print(string.format("💥 Loss. Rounds: %d | Wins: %d | Win rate: %.1f%%",
            stats.roundsCompleted,
            stats.boardsCompleted,
            stats.boardsCompleted / stats.roundsCompleted * 100))

        task.wait(RESET_DELAY)
        resetBoardState()
        roundPhase = "first_click"
        continue
    end

    fullDeductionPass()

    if isBoardSolved() or checkRoundLost() then continue end

    local constraints  = buildConstraints()
    local candidates   = estimateProbabilities(constraints)

    if #candidates == 0 then
        scanBoardForMissedTiles()
        task.wait(0.1)
    else
        local best = candidates[1]

        if best.prob > 0.6 then
            for _, c in ipairs(candidates) do
                local edgeDist = math.min(c.row - 1, GRID_SIZE - c.row,
                                          c.col - 1, GRID_SIZE - c.col)
                if edgeDist >= 2 and c.prob <= best.prob then
                    best = c
                    break
                end
            end
        end

        local success = clickCell(best.row, best.col)
        if success then
            stats.safeClicks = stats.safeClicks + 1
        end
    end

    if os.clock() - lastStatsTime > 60 then
        printStats()
        lastStatsTime = os.clock()
    end

    task.wait(0.02)
end