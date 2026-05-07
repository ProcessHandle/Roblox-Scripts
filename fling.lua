local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local localPlayer = Players.LocalPlayer

local niggas = {
  1288458401,
  910140467,
  8609879786,
  276351174,
  4538128446,
  2861657607,
}

local headSitConnection = nil
local walkflinging = false
local currentTarget = nil
local isRunning = false

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
	if humanoid and char:GetAttribute("Spectator") == true then
		return true
	end
	return false
end

local function stopEffect()
	isRunning = false
	if headSitConnection then
		headSitConnection:Disconnect()
		headSitConnection = nil
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

local function combinedEffect(targetPlayer)
	if not targetPlayer then return end
	
	-- Check if target is spectator first
	if isSpectator(targetPlayer) then
		print("Target is on spectators team, skipping")
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
	if not char then return end
	
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end
	
	isRunning = true
	print("Starting combined effect on: " .. currentTarget.Name)
	
	-- Make target sit
	humanoid.Sit = true
	
	-- Head sit - constantly teleport to chosen player's head
	headSitConnection = RunService.Heartbeat:Connect(function()
		if not isRunning or not currentTarget or not currentTarget.Character then
			if headSitConnection then headSitConnection:Disconnect() end
			return
		end
		local currentChar = currentTarget.Character
		local currentHumanoid = currentChar:FindFirstChildOfClass("Humanoid")
		if currentChar and getRoot(currentChar) and currentHumanoid and currentHumanoid.Sit == true then
			-- Teleport to player's head position
			getRoot(currentChar).CFrame = getRoot(currentChar).CFrame * CFrame.new(0, 1.6, 0.4)
		end
	end)
	
	-- Walk fling - exactly as in Infinite Yield
	task.spawn(function()
		walkflinging = true
		-- Enable noclip first
		if Noclipping then Noclipping:Disconnect() end
		Clip = false
		local function NoclipLoop()
			if Clip == false and currentTarget and currentTarget.Character then
				for _, child in pairs(currentTarget.Character:GetDescendants()) do
					if child:IsA("BasePart") and child.CanCollide == true then
						child.CanCollide = false
					end
				end
			end
		end
		local noclipConnection = RunService.Stepped:Connect(NoclipLoop)
		
		repeat 
			RunService.Heartbeat:Wait()
			local character = currentTarget and currentTarget.Character
			local root = character and getRoot(character)
			local vel, movel = nil, 0.1

			while not (character and character.Parent and root and root.Parent) do
				RunService.Heartbeat:Wait()
				character = currentTarget and currentTarget.Character
				root = character and getRoot(character)
				if not isRunning then return end
			end

			vel = root.Velocity
			root.Velocity = vel * 10000 + Vector3.new(0, 10000, 0)

			RunService.RenderStepped:Wait()
			if character and character.Parent and root and root.Parent and isRunning then
				root.Velocity = vel
			end

			RunService.Stepped:Wait()
			if character and character.Parent and root and root.Parent and isRunning then
				root.Velocity = vel + Vector3.new(0, movel, 0)
				movel = movel * -1
			end
		until not isRunning or not walkflinging
		
		noclipConnection:Disconnect()
		-- Re-enable collision
		if currentTarget and currentTarget.Character then
			for _, child in pairs(currentTarget.Character:GetDescendants()) do
				if child:IsA("BasePart") then
					child.CanCollide = true
				end
			end
		end
	end)
	
	-- Stop if target dies
	humanoid.Died:Connect(function()
		if isRunning then
			print("Target died, stopping effect")
			stopEffect()
		end
	end)
	
	-- Also stop if target becomes spectator
	local teamCheck
	teamCheck = currentTarget:GetPropertyChangedSignal("Team"):Connect(function()
		if isSpectator(currentTarget) then
			print("Target became spectator, stopping effect")
			stopEffect()
			teamCheck:Disconnect()
		end
	end)
end

-- Kick system for blacklisted players
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

-- Target the specific user
local TARGET_USER_ID = 2632374645

local function startOnTarget(userId)
	local target = Players:FindFirstChild(tostring(userId))
	if target then
		combinedEffect(target)
	else
		local conn
		conn = Players.PlayerAdded:Connect(function(player)
			if player.UserId == userId then
				conn:Disconnect()
				task.wait(2)
				combinedEffect(player)
			end
		end)
	end
end

startOnTarget(TARGET_USER_ID)

_G.stopEffect = stopEffect
_G.checkSpectator = isSpectator

print("Script loaded. Targeting User ID: " .. TARGET_USER_ID)
print("Type _G.stopEffect() to stop the effect")
print("Type _G.checkSpectator(Players.PlayerName) to check if someone is spectator")
