-- Roblox Minesweeper - WIN-FOCUSED SOLVER with Real Pattern Learning
local BUTTONS_PATH = workspace.Map.Lobby.Lobby.Minigames.Minesweeper.Buttons
local DISPLAYS_PATH = workspace.Map.Lobby.Lobby.Minigames.Minesweeper.Displays

local GRID_SIZE = 10
local TOTAL_MINES = 20
local RESET_DELAY = 3

-- Pattern learning system
local patternMemory = {
    safePatterns = {},
    minePatterns = {},
    boardHistory = {},
    maxHistory = 200,
    minSamples = 5,
}

-- Track what we've seen this round
local roundStats = {
    tilesRevealed = 0,
    highestSeen = 0,
    minesFlagged = 0,
    startTime = 0,
    minesHitThisRound = 0,
    fivePlusLocations = {},
}

-- Global stats
local stats = {
    roundsCompleted = 0,
    safeClicks = 0,
    mineHits = 0,
    sevensFound = 0,
    highestEver = 0,
    startTime = os.clock(),
    boardsCompleted = 0,
    fivesFound = 0,
    sixesFound = 0,
    consecutiveWins = 0,
    bestWinStreak = 0,
}

-- Best first click positions
local FIRST_CLICK = {5, 5}

-- Build grid
local grid = {}
local function buildGrid()
    grid = {}
    local missingCount = 0
    
    for row = 1, GRID_SIZE do
        grid[row] = {}
        local rowStr = tostring(row)
        
        for col = 1, GRID_SIZE do
            local colStr = tostring(col)
            local button = BUTTONS_PATH:FindFirstChild(rowStr) and BUTTONS_PATH[rowStr]:FindFirstChild(colStr)
            local display = DISPLAYS_PATH:FindFirstChild(rowStr) and DISPLAYS_PATH[rowStr]:FindFirstChild(colStr)
            
            if button and display then
                local clickDetector = button:FindFirstChild("ClickDetector")
                local sg = display:FindFirstChild("SG")
                
                if clickDetector and sg then
                    local nLabel = sg:FindFirstChild("NLabel")
                    local bombImage = sg:FindFirstChild("BImage")
                    
                    if nLabel and bombImage then
                        grid[row][col] = {
                            row = row,
                            col = col,
                            button = button,
                            display = display,
                            clickDetector = clickDetector,
                            nLabel = nLabel,
                            bombImage = bombImage,
                            state = "unclicked",
                            num = nil,
                            isMine = false,
                            neighborMines = nil,
                            patternRisk = 0.5,
                        }
                    else
                        missingCount = missingCount + 1
                    end
                else
                    missingCount = missingCount + 1
                end
            else
                missingCount = missingCount + 1
            end
        end
    end
    
    if missingCount > 0 then
        warn("Missing cells: " .. missingCount)
    else
        print("✅ Grid built - all " .. (GRID_SIZE * GRID_SIZE) .. " cells found")
    end
end

-- Helper: get neighbors
local function getNeighbors(row, col)
    local neighbors = {}
    for dr = -1, 1 do
        for dc = -1, 1 do
            if (dr ~= 0 or dc ~= 0) and grid[row + dr] and grid[row + dr][col + dc] then
                table.insert(neighbors, {row = row + dr, col = col + dc})
            end
        end
    end
    return neighbors
end

-- Extract a 3x3 pattern around a cell
local function extractPattern(row, col)
    local pattern = {}
    for dr = -1, 1 do
        for dc = -1, 1 do
            local r, c = row + dr, col + dc
            local symbol = "X"
            
            if grid[r] and grid[r][c] then
                local cell = grid[r][c]
                if dr == 0 and dc == 0 then
                    symbol = "C"  -- Center (cell we're evaluating)
                elseif cell.state == "clicked" and cell.neighborMines then
                    symbol = tostring(cell.neighborMines)
                elseif cell.isMine then
                    symbol = "M"
                elseif cell.state == "unclicked" then
                    symbol = "?"
                elseif cell.state == "bomb" then
                    symbol = "B"
                end
            end
            
            table.insert(pattern, symbol)
        end
    end
    
    return table.concat(pattern)
end

-- Learn from a revealed cell
local function learnFromCell(row, col, wasMine)
    local patternKey = extractPattern(row, col)
    
    if wasMine then
        patternMemory.minePatterns[patternKey] = (patternMemory.minePatterns[patternKey] or 0) + 1
    else
        patternMemory.safePatterns[patternKey] = (patternMemory.safePatterns[patternKey] or 0) + 1
    end
end

-- Predict mine probability using learned patterns
local function predictMineProbability(row, col)
    local patternKey = extractPattern(row, col)
    local safeCount = patternMemory.safePatterns[patternKey] or 0
    local mineCount = patternMemory.minePatterns[patternKey] or 0
    local total = safeCount + mineCount
    
    if total >= patternMemory.minSamples then
        return mineCount / total, total
    end
    
    return 0.5, total  -- Unknown, 50/50
end

-- Check if bomb is visible
local function isBombRevealed(row, col)
    local cell = grid[row][col]
    if cell and cell.bombImage then
        return cell.bombImage.Visible == true
    end
    return false
end

-- Read number from NLabel
local function readNumber(row, col)
    local cell = grid[row][col]
    if cell and cell.nLabel then
        local text = cell.nLabel.Text
        if text and text ~= "" then
            return tonumber(text)
        end
    end
    return nil
end

-- Scan board for cascade-revealed tiles
local function scanBoardForMissedTiles()
    local foundCount = 0
    
    for row = 1, GRID_SIZE do
        for col = 1, GRID_SIZE do
            local cell = grid[row][col]
            if cell and cell.state == "unclicked" then
                local isTransparent = cell.button and (cell.button.Transparency >= 1 or cell.button.Transparency > 0.9)
                local hasNumber = cell.nLabel and cell.nLabel.Visible and cell.nLabel.Text and cell.nLabel.Text ~= ""
                local isBomb = cell.bombImage and cell.bombImage.Visible
                
                if isTransparent or hasNumber or isBomb then
                    if isBomb then
                        cell.state = "bomb"
                        cell.isMine = true
                        roundStats.minesHitThisRound = roundStats.minesHitThisRound + 1
                        stats.mineHits = stats.mineHits + 1
                        learnFromCell(row, col, true)
                        foundCount = foundCount + 1
                    else
                        cell.state = "clicked"
                        roundStats.tilesRevealed = roundStats.tilesRevealed + 1
                        
                        local num = nil
                        if hasNumber then
                            num = tonumber(cell.nLabel.Text)
                        end
                        
                        if num then
                            cell.num = num
                            cell.neighborMines = num
                            learnFromCell(row, col, false)
                            
                            if num >= 5 then
                                table.insert(roundStats.fivePlusLocations, {row = row, col = col, num = num})
                                if num == 5 then stats.fivesFound = stats.fivesFound + 1
                                elseif num == 6 then stats.sixesFound = stats.sixesFound + 1 end
                            end
                            
                            if num > roundStats.highestSeen then
                                roundStats.highestSeen = num
                            end
                            
                            if num == 7 then
                                stats.sevensFound = stats.sevensFound + 1
                                stats.highestEver = 7
                                print("🎉🎉🎉 FOUND 7 at [" .. row .. "," .. col .. "]! 🎉🎉🎉")
                            end
                        else
                            cell.num = 0
                            cell.neighborMines = 0
                        end
                        
                        foundCount = foundCount + 1
                    end
                end
            end
        end
    end
    
    return foundCount
end

-- Check if round ended
local function checkRoundEnded()
    scanBoardForMissedTiles()
    
    for row = 1, GRID_SIZE do
        for col = 1, GRID_SIZE do
            local cell = grid[row][col]
            if cell and cell.state == "bomb" then
                return true
            end
        end
    end
    return false
end

-- Check if board is completely solved
local function isBoardSolved()
    local safeUnclicked = 0
    for row = 1, GRID_SIZE do
        for col = 1, GRID_SIZE do
            local cell = grid[row][col]
            if cell and cell.state == "unclicked" and not cell.isMine then
                safeUnclicked = safeUnclicked + 1
            end
        end
    end
    return safeUnclicked == 0
end

-- Count remaining unflagged mines
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

-- Reset our tracking
local function resetBoardState()
    for row = 1, GRID_SIZE do
        for col = 1, GRID_SIZE do
            if grid[row][col] then
                grid[row][col].state = "unclicked"
                grid[row][col].num = nil
                grid[row][col].isMine = false
                grid[row][col].neighborMines = nil
                grid[row][col].patternRisk = 0.5
            end
        end
    end
    roundStats.tilesRevealed = 0
    roundStats.highestSeen = 0
    roundStats.minesFlagged = 0
    roundStats.minesHitThisRound = 0
    roundStats.fivePlusLocations = {}
    roundStats.startTime = os.clock()
end

-- Click a cell and return result
local function clickCell(row, col)
    local cell = grid[row][col]
    if not cell then return false, nil end
    if cell.state ~= "unclicked" then return false, nil end
    if cell.isMine then return false, nil end
    
    fireclickdetector(cell.clickDetector)
    task.wait(0.04)
    
    if isBombRevealed(row, col) then
        cell.state = "bomb"
        cell.isMine = true
        roundStats.minesHitThisRound = roundStats.minesHitThisRound + 1
        stats.mineHits = stats.mineHits + 1
        learnFromCell(row, col, true)
        return false, "mine"
    end
    
    cell.state = "clicked"
    roundStats.tilesRevealed = roundStats.tilesRevealed + 1
    
    local num = readNumber(row, col)
    if num then
        cell.num = num
        cell.neighborMines = num
        learnFromCell(row, col, false)
        
        if num >= 5 then
            table.insert(roundStats.fivePlusLocations, {row = row, col = col, num = num})
            if num == 5 then stats.fivesFound = stats.fivesFound + 1
            elseif num == 6 then stats.sixesFound = stats.sixesFound + 1
            elseif num == 7 then
                stats.sevensFound = stats.sevensFound + 1
                stats.highestEver = 7
                print("🎉🎉🎉 FOUND 7 at [" .. row .. "," .. col .. "]! 🎉🎉🎉")
            end
        end
        
        if num > roundStats.highestSeen then
            roundStats.highestSeen = num
        end
        
        scanBoardForMissedTiles()
        return true, num
    else
        cell.num = 0
        cell.neighborMines = 0
        scanBoardForMissedTiles()
        return true, 0
    end
end

-- Check if guaranteed safe
local function isGuaranteedSafe(row, col)
    local neighbors = getNeighbors(row, col)
    for _, n in ipairs(neighbors) do
        local nCell = grid[n.row][n.col]
        if nCell.state == "clicked" and nCell.neighborMines then
            local flaggedCount = 0
            local unclickedCount = 0
            local neighbors2 = getNeighbors(n.row, n.col)
            
            for _, n2 in ipairs(neighbors2) do
                local n2Cell = grid[n2.row][n2.col]
                if n2Cell.state == "unclicked" then
                    unclickedCount = unclickedCount + 1
                elseif n2Cell.isMine then
                    flaggedCount = flaggedCount + 1
                end
            end
            
            if nCell.neighborMines - flaggedCount == 0 and unclickedCount > 0 then
                return true
            end
        end
    end
    return false
end

-- Check if definitely a mine
local function isDefinitelyMine(row, col)
    local neighbors = getNeighbors(row, col)
    for _, n in ipairs(neighbors) do
        local nCell = grid[n.row][n.col]
        if nCell.state == "clicked" and nCell.neighborMines then
            local flaggedCount = 0
            local unclickedCount = 0
            local neighbors2 = getNeighbors(n.row, n.col)
            
            for _, n2 in ipairs(neighbors2) do
                local n2Cell = grid[n2.row][n2.col]
                if n2Cell.state == "unclicked" then
                    unclickedCount = unclickedCount + 1
                elseif n2Cell.isMine then
                    flaggedCount = flaggedCount + 1
                end
            end
            
            if nCell.neighborMines - flaggedCount == unclickedCount and unclickedCount > 0 then
                for _, n2 in ipairs(neighbors2) do
                    if n2.row == row and n2.col == col and grid[n2.row][n2.col].state == "unclicked" then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- Detect 50/50 situations
local function detect5050()
    local pairs = {}
    local visited = {}
    
    for row = 1, GRID_SIZE do
        for col = 1, GRID_SIZE do
            local cell = grid[row][col]
            if cell and cell.state == "unclicked" and not cell.isMine and not visited[row .. "," .. col] then
                local neighbors = getNeighbors(row, col)
                local constrainedBy = {}
                
                for _, n in ipairs(neighbors) do
                    local nCell = grid[n.row][n.col]
                    if nCell.state == "clicked" and nCell.neighborMines then
                        local unclickedCount = 0
                        local flaggedCount = 0
                        local unclickedList = {}
                        
                        for _, n2 in ipairs(getNeighbors(n.row, n.col)) do
                            local n2Cell = grid[n2.row][n2.col]
                            if n2Cell.state == "unclicked" and not n2Cell.isMine then
                                unclickedCount = unclickedCount + 1
                                table.insert(unclickedList, n2)
                            elseif n2Cell.isMine then
                                flaggedCount = flaggedCount + 1
                            end
                        end
                        
                        local remaining = nCell.neighborMines - flaggedCount
                        
                        -- Classic 50/50: 2 unclicked, 1 mine
                        if unclickedCount == 2 and remaining == 1 then
                            table.insert(constrainedBy, {
                                cells = unclickedList,
                                remaining = remaining
                            })
                        end
                    end
                end
                
                if #constrainedBy > 0 then
                    visited[row .. "," .. col] = true
                    for _, constraint in ipairs(constrainedBy) do
                        for _, c in ipairs(constraint.cells) do
                            visited[c.row .. "," .. c.col] = true
                        end
                    end
                    table.insert(pairs, constrainedBy)
                end
            end
        end
    end
    
    return pairs
end

-- Logical deduction
local function logicalDeduction()
    local changed = false
    
    for row = 1, GRID_SIZE do
        for col = 1, GRID_SIZE do
            local cell = grid[row][col]
            if cell and cell.state == "clicked" and cell.neighborMines then
                local neighbors = getNeighbors(row, col)
                local unclicked = {}
                local flaggedCount = 0
                
                for _, n in ipairs(neighbors) do
                    local nCell = grid[n.row][n.col]
                    if nCell.state == "unclicked" and not nCell.isMine then
                        table.insert(unclicked, n)
                    elseif nCell.isMine then
                        flaggedCount = flaggedCount + 1
                    end
                end
                
                local remainingMines = cell.neighborMines - flaggedCount
                
                -- All unclicked are mines
                if remainingMines == #unclicked and #unclicked > 0 then
                    for _, u in ipairs(unclicked) do
                        if not grid[u.row][u.col].isMine then
                            grid[u.row][u.col].isMine = true
                            roundStats.minesFlagged = roundStats.minesFlagged + 1
                            changed = true
                        end
                    end
                end
                
                -- All unclicked are safe
                if remainingMines == 0 and #unclicked > 0 then
                    for _, u in ipairs(unclicked) do
                        if grid[u.row][u.col].state == "unclicked" then
                            local success = clickCell(u.row, u.col)
                            if success then
                                stats.safeClicks = stats.safeClicks + 1
                            end
                            changed = true
                        end
                    end
                end
            end
        end
    end
    
    return changed
end

-- Get best cells to click
local function getBestCells()
    local guaranteed = {}
    local probable = {}
    
    -- Update pattern risks for all unclicked cells
    for row = 1, GRID_SIZE do
        for col = 1, GRID_SIZE do
            local cell = grid[row][col]
            if cell and cell.state == "unclicked" and not cell.isMine then
                cell.patternRisk, _ = predictMineProbability(row, col)
            end
        end
    end
    
    local remainingMines = countRemainingMines()
    
    for row = 1, GRID_SIZE do
        for col = 1, GRID_SIZE do
            local cell = grid[row][col]
            if cell and cell.state == "unclicked" and not cell.isMine then
                if isDefinitelyMine(row, col) then
                    cell.isMine = true
                    roundStats.minesFlagged = roundStats.minesFlagged + 1
                elseif isGuaranteedSafe(row, col) then
                    local score = 1000  -- Guaranteed safe = highest priority
                    table.insert(guaranteed, {row = row, col = col, score = score, risk = 0})
                else
                    -- Score based on: lower mine risk = better
                    local risk = cell.patternRisk
                    local score = (1 - risk) * 100  -- Lower risk = higher score
                    
                    -- Bonus for being near high numbers (more progress)
                    local neighbors = getNeighbors(row, col)
                    for _, n in ipairs(neighbors) do
                        local nCell = grid[n.row][n.col]
                        if nCell.state == "clicked" and nCell.neighborMines then
                            score = score + nCell.neighborMines * 5
                        end
                    end
                    
                    table.insert(probable, {row = row, col = col, score = score, risk = risk})
                end
            end
        end
    end
    
    table.sort(guaranteed, function(a, b) return a.score > b.score end)
    table.sort(probable, function(a, b) return a.score > b.score end)
    
    return guaranteed, probable
end

-- Print stats
local function printStats()
    local elapsed = os.clock() - stats.startTime
    local totalClicks = stats.safeClicks + stats.mineHits
    local successRate = totalClicks > 0 and (stats.safeClicks / totalClicks * 100) or 0
    local roundsPerMin = stats.roundsCompleted / math.max(elapsed / 60, 0.01)
    local winRate = stats.roundsCompleted > 0 and (stats.boardsCompleted / stats.roundsCompleted * 100) or 0
    local totalPatterns = 0
    for _ in pairs(patternMemory.safePatterns) do totalPatterns = totalPatterns + 1 end
    for _ in pairs(patternMemory.minePatterns) do totalPatterns = totalPatterns + 1 end
    
    print(string.format([[
╔══════════════════════════════════════╗
║   MINESWEEPER WIN-FOCUSED STATS     ║
╠══════════════════════════════════════╣
║ Rounds: %-28d ║
║ Boards Won: %-24d ║
║ Win Rate: %-25.1f%% ║
║ Win Streak: %-23d ║
║ Best Streak: %-22d ║
║ Safe Clicks: %-23d ║
║ Mine Hits: %-25d ║
║ Patterns Learned: %-18d ║
║ 7's Found: %-25d ║
║ 6's Found: %-25d ║
║ 5's Found: %-25d ║
║ Rounds/min: %-23.1f ║
║ Time: %-6.1f min                  ║
╚══════════════════════════════════════╝]],
        stats.roundsCompleted,
        stats.boardsCompleted,
        winRate,
        stats.consecutiveWins,
        stats.bestWinStreak,
        stats.safeClicks,
        stats.mineHits,
        totalPatterns,
        stats.sevensFound,
        stats.sixesFound,
        stats.fivesFound,
        roundsPerMin,
        elapsed / 60
    ))
end

-- Main loop
print("🚀 Starting Roblox Minesweeper - WIN FOCUS with Pattern Learning...")
print("📊 Grid: 10x10 with 20 mines")
print("🎯 Goal: Win consistently with pattern memory")
print("🧠 Learning from every click to improve decisions")
print("")

buildGrid()
resetBoardState()

local lastStatsTime = os.clock()
local roundPhase = "first_click"

while true do
    -- First click: Center (guaranteed safe)
    if roundPhase == "first_click" then
        local success = clickCell(FIRST_CLICK[1], FIRST_CLICK[2])
        if success then stats.safeClicks = stats.safeClicks + 1 end
        roundPhase = "solving"
        task.wait(0.02)
        continue
    end
    
    -- Check win
    if isBoardSolved() then
        stats.roundsCompleted = stats.roundsCompleted + 1
        stats.boardsCompleted = stats.boardsCompleted + 1
        stats.consecutiveWins = stats.consecutiveWins + 1
        stats.bestWinStreak = math.max(stats.bestWinStreak, stats.consecutiveWins)
        
        print(string.format("✅ BOARD WON! Streak: %d | Patterns: %d", 
              stats.consecutiveWins, 
              (function() local c=0 for _ in pairs(patternMemory.safePatterns) do c=c+1 end return c end)()))
        
        resetBoardState()
        roundPhase = "first_click"
        task.wait(RESET_DELAY)
        continue
    end
    
    -- Check loss
    if checkRoundEnded() then
        stats.roundsCompleted = stats.roundsCompleted + 1
        stats.consecutiveWins = 0
        resetBoardState()
        roundPhase = "first_click"
        task.wait(RESET_DELAY)
        continue
    end
    
    -- Run logical deduction aggressively
    local deductionCount = 0
    local deductionChanged = true
    while deductionChanged and deductionCount < 100 do
        deductionChanged = logicalDeduction()
        deductionCount = deductionCount + 1
        task.wait(0.01)
        
        if isBoardSolved() or checkRoundEnded() then break end
    end
    
    if isBoardSolved() or checkRoundEnded() then continue end
    
    -- Get best cells
    local guaranteed, probable = getBestCells()
    
    -- Check for 50/50 situations
    local fiftyFifties = detect5050()
    
    if #guaranteed > 0 then
        -- Always click guaranteed safe cells first
        local best = guaranteed[1]
        local success = clickCell(best.row, best.col)
        if success then stats.safeClicks = stats.safeClicks + 1 end
        
    elseif #fiftyFifties > 0 and #probable > 0 then
        -- We're in a 50/50 - pick the one with best pattern learning
        local bestGuess = probable[1]
        print("🎲 50/50 detected, using pattern learning...")
        
        local success = clickCell(bestGuess.row, bestGuess.col)
        if success then stats.safeClicks = stats.safeClicks + 1 end
        
    elseif #probable > 0 then
        -- Best educated guess
        local bestGuess = probable[1]
        
        -- Prefer cells near progress (high numbers)
        for _, cell in ipairs(probable) do
            local neighbors = getNeighbors(cell.row, cell.col)
            for _, n in ipairs(neighbors) do
                local nCell = grid[n.row][n.col]
                if nCell.state == "clicked" and nCell.neighborMines and nCell.neighborMines >= 3 then
                    bestGuess = cell
                    break
                end
            end
            if bestGuess ~= probable[1] then break end
        end
        
        local success = clickCell(bestGuess.row, bestGuess.col)
        if success then stats.safeClicks = stats.safeClicks + 1 end
    end
    
    -- Stats every 60 seconds
    if os.clock() - lastStatsTime > 60 then
        printStats()
        lastStatsTime = os.clock()
    end
    
    task.wait(0.02)
end