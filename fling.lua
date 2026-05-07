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

local function getRoot(character)
	return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
end

local function isSpectator(player)
	local char = player.Character
	if not char then return false end
	
	local team = player.Team
	if team then
		local teamName = team.Name:lower()
		if teamName:find("spectator") or teamName:find("spec") or teamName:find("ghost") then
			return true
		end
	end
	
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if char:GetAttribute("Spectator") == true then
			return true
		end
	end
	
	return false
end

local function stopEffect()
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
end

local function combinedEffectOnTarget(targetPlayer)
	if not targetPlayer then
		return
	end
	
	if isSpectator(targetPlayer) then
		return
	end
	
	stopEffect()
	
	currentTarget = targetPlayer
	
	local char = currentTarget.Character
	if not char then
		currentTarget.CharacterAdded:Wait()
		char = currentTarget.Character
		task.wait(0.5)
	end
	
	if not char then
		return
	end
	
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	
	isRunning = true
	
	humanoid.Sit = true
	
	activeConnection = RunService.Heartbeat:Connect(function()
		if not isRunning then
			return
		end
		
		if currentTarget and currentTarget.Character then
			local currentChar = currentTarget.Character
			local currentHumanoid = currentChar:FindFirstChildOfClass("Humanoid")
			if currentChar and getRoot(currentChar) and currentHumanoid and currentHumanoid.Sit == true then
				getRoot(currentChar).CFrame = getRoot(currentChar).CFrame * CFrame.new(0, 1.6, 0.4)
			end
		end
	end)
	
	currentThread = task.spawn(function()
		local vel, movel = nil, 0.1
		
		while isRunning and currentTarget do
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
	end)
	
	humanoid.Died:Connect(function()
		if isRunning then
			stopEffect()
		end
	end)
end

local function getRandomPlayer()
	local players = Players:GetPlayers()
	local validPlayers = {}
	
	for _, player in ipairs(players) do
		if player ~= localPlayer and not isSpectator(player) and player.Character then
			table.insert(validPlayers, player)
		end
	end
	
	if #validPlayers > 0 then
		return validPlayers[math.random(1, #validPlayers)]
	end
	
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
			table.insert(kickQueue, player)
			processKickQueue()
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	for _, userId in pairs(niggas) do
		if player.UserId == userId then
			table.insert(kickQueue, player)
			task.spawn(processKickQueue)
			break
		end
	end
end)

local randomTarget = getRandomPlayer()
if randomTarget then
	combinedEffectOnTarget(randomTarget)
else
	Players.PlayerAdded:Connect(function(player)
		if not isSpectator(player) and player ~= localPlayer then
			task.wait(1)
			combinedEffectOnTarget(player)
		end
	end)
end

_G.stopCombined = stopEffect
