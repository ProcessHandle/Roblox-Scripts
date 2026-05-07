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
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local activeConnection = nil
local currentThread = nil
local isRunning = false
local currentTarget = nil

local function getRoot(character)
	return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
end

local function isSpectator()
	local char = localPlayer.Character
	if not char then return false end
	
	local team = localPlayer.Team
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

local function resetCharacter()
	local humanoid = localPlayer.Character and localPlayer.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = 0
	end
	localPlayer:LoadCharacter()
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
		warn("No target player")
		return
	end
	
	if isSpectator() then
		resetCharacter()
		return
	end
	
	stopEffect()
	
	currentTarget = targetPlayer
	
	local char = currentTarget.Character
	if not char then
		local success = currentTarget.CharacterAdded:Wait(5)
		if not success then
			warn("Character failed to load")
			return
		end
		char = currentTarget.Character
		task.wait(0.5)
	end
	
	if not char then
		warn("No character")
		return
	end
	
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		warn("No humanoid")
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
	
	print("Effect started on " .. targetPlayer.Name)
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

local TARGET_USER_ID = 2632374645

local function targetByUserId(userId)
	local target = Players:FindFirstChild(tostring(userId))
	if target then
		combinedEffectOnTarget(target)
	else
		local connection
		connection = Players.PlayerAdded:Connect(function(player)
			if player.UserId == userId then
				connection:Disconnect()
				task.wait(1)
				combinedEffectOnTarget(player)
			end
		end)
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	local key = input.KeyCode
	
	if key == Enum.KeyCode.K then
		print("K key pressed, targeting user: " .. TARGET_USER_ID)
		targetByUserId(TARGET_USER_ID)
	end
end)

_G.combinedEffect = combinedEffectOnTarget
_G.stopCombined = stopEffect
_G.targetUser = targetByUserId

print("Script loaded. Set TARGET_USER_ID to the correct ID. Current: " .. TARGET_USER_ID)
print("Press K to target and effect the player")