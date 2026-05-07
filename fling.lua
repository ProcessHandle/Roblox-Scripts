local niggas = {
  1288458401,
  910140467,
  8609879786,
  276351174,
  4538128446,
  2861657607,
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local localPlayer = Players.LocalPlayer
local activeConnection = nil
local currentThread = nil
local isRunning = false
local currentTarget = nil

print("=== SCRIPT LOADED ===")
print("Local Player: " .. localPlayer.Name)

local function getRoot(character)
	return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
end

local function isSpectator(player)
	print("Checking if " .. player.Name .. " is spectator...")
	local char = player.Character
	if not char then 
		print("No character found for " .. player.Name)
		return false 
	end
	
	local team = player.Team
	if team then
		local teamName = team.Name:lower()
		print("Team name: " .. teamName)
		if teamName:find("spectator") or teamName:find("spec") or teamName:find("ghost") then
			print(player.Name .. " is spectator (team check)")
			return true
		end
	end
	
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if char:GetAttribute("Spectator") == true then
			print(player.Name .. " is spectator (attribute check)")
			return true
		end
	end
	
	print(player.Name .. " is NOT a spectator")
	return false
end

local function stopEffect()
	print("Stopping effect...")
	isRunning = false
	
	if activeConnection then
		activeConnection:Disconnect()
		activeConnection = nil
	end
	
	if currentThread then
		coroutine.close(currentThread)
		currentThread = nil
	end
	
	if currentTarget and currentTarget.Character then
		local char = currentTarget.Character
		local root = getRoot(char)
		if root then
			root.Velocity = Vector3.new(0, 0, 0)
		end
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Sit = false
		end
	end
	
	currentTarget = nil
	print("Effect stopped")
end

local function combinedEffectOnTarget(targetPlayer)
	print("=== combinedEffectOnTarget called ===")
	print("Target: " .. targetPlayer.Name)
	
	if not targetPlayer then
		print("ERROR: No target player")
		return
	end
	
	if isSpectator(targetPlayer) then
		print("Target is spectator, skipping")
		return
	end
	
	print("Stopping any existing effect...")
	stopEffect()
	
	currentTarget = targetPlayer
	print("Current target set to: " .. currentTarget.Name)
	
	local char = currentTarget.Character
	print("Initial character: " .. tostring(char))
	
	if not char then
		print("Waiting for character to load...")
		local success = currentTarget.CharacterAdded:Wait(5)
		print("CharacterAdded event fired: " .. tostring(success))
		char = currentTarget.Character
		print("Character after wait: " .. tostring(char))
		task.wait(0.5)
	end
	
	if not char then
		print("ERROR: No character found for " .. currentTarget.Name)
		return
	end
	
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	print("Humanoid found: " .. tostring(humanoid))
	
	if not humanoid then
		print("ERROR: No humanoid found")
		return
	end
	
	isRunning = true
	print("isRunning set to true")
	
	humanoid.Sit = true
	print("Set humanoid.Sit = true")
	
	activeConnection = RunService.Heartbeat:Connect(function()
		if not isRunning then
			return
		end
		
		if currentTarget and currentTarget.Character then
			local currentChar = currentTarget.Character
			local currentHumanoid = currentChar:FindFirstChildOfClass("Humanoid")
			if currentChar and getRoot(currentChar) and currentHumanoid and currentHumanoid.Sit == true then
				local oldCFrame = getRoot(currentChar).CFrame
				getRoot(currentChar).CFrame = oldCFrame * CFrame.new(0, 1.6, 0.4)
			end
		end
	end)
	print("Heartbeat connection created")
	
	currentThread = task.spawn(function()
		print("Walk fling thread started")
		local vel, movel = nil, 0.1
		local iteration = 0
		
		while isRunning and currentTarget do
			iteration = iteration + 1
			if iteration % 50 == 0 then
				print("Walk fling iteration: " .. iteration .. ", isRunning: " .. tostring(isRunning))
			end
			
			task.wait()
			
			if not currentTarget.Character then
				task.wait()
				continue
			end
			
			local currentChar = currentTarget.Character
			local root = getRoot(currentChar)
			
			if not (currentChar and currentChar.Parent and root and root.Parent) then
				task.wait()
				continue
			end
			
			vel = root.Velocity
			root.Velocity = vel * 10000 + Vector3.new(0, 10000, 0)
			
			task.wait()
			
			if currentChar and currentChar.Parent and root and root.Parent and isRunning then
				root.Velocity = vel
			end
			
			task.wait()
			
			if currentChar and currentChar.Parent and root and root.Parent and isRunning then
				root.Velocity = vel + Vector3.new(0, movel, 0)
				movel = movel * -1
			end
		end
		print("Walk fling thread ended")
	end)
	
	humanoid.Died:Connect(function()
		print("Target died, stopping effect")
		if isRunning then
			stopEffect()
		end
	end)
	
	print("Effect started on " .. targetPlayer.Name)
end

local function getRandomPlayer()
	print("Getting random player...")
	local players = Players:GetPlayers()
	print("Total players: " .. #players)
	
	local validPlayers = {}
	
	for _, player in ipairs(players) do
		print("Checking player: " .. player.Name .. " (ID: " .. player.UserId .. ")")
		if player == localPlayer then
			print("  - Is local player, skipping")
		elseif isSpectator(player) then
			print("  - Is spectator, skipping")
		elseif not player.Character then
			print("  - Has no character, skipping")
		else
			print("  - VALID player found!")
			table.insert(validPlayers, player)
		end
	end
	
	print("Valid players found: " .. #validPlayers)
	
	if #validPlayers > 0 then
		local selected = validPlayers[math.random(1, #validPlayers)]
		print("Selected random player: " .. selected.Name)
		return selected
	end	
	print("No valid players found")
	return nil
end

local kickQueue = {}
local processingKick = false

local function processKickQueue()
	if processingKick then return end
	processingKick = true
	
	while #kickQueue > 0 do
		local player = table.remove(kickQueue, 1)
		if player and player.Parent then
			print("Kicking due to blacklisted player: " .. player.Name)
			localPlayer:Kick("Safety kick: Blacklisted player joined - " .. player.Name)
		end
		task.wait()
	end
	
	processingKick = false
end

for _, userId in pairs(niggas) do
	task.spawn(function()
		local player = Players:FindFirstChild(tostring(userId))
		if player then
			print("Blacklisted player already in game: " .. player.Name)
			table.insert(kickQueue, player)
			processKickQueue()
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	for _, userId in pairs(niggas) do
		if player.UserId == userId then
			print("Blacklisted player joined: " .. player.Name)
			table.insert(kickQueue, player)
			task.spawn(processKickQueue)
			break
		end
	end
end)

print("Attempting to find random target...")
local randomTarget = getRandomPlayer()
if randomTarget then
	print("Found random target, applying effect...")
	combinedEffectOnTarget(randomTarget)
else
	print("No random target found, waiting for player to join...")
	Players.PlayerAdded:Connect(function(player)
		print("Player joined: " .. player.Name)
		task.wait(2)
		if not isSpectator(player) and player ~= localPlayer then
			print("Applying effect to new player: " .. player.Name)
			combinedEffectOnTarget(player)
		else
			print("New player is spectator or local, skipping")
		end
	end)
end

_G.stopCombined = stopEffect
_G.getRandomPlayer = getRandomPlayer
_G.checkSpectator = isSpectator

print("=== SCRIPT READY ===")
print("Type _G.stopCombined() to stop the effect")
print("Type _G.getRandomPlayer() to get a random player")
