-- DO NOT set a default here - let _G.TargetId control it
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local localPlayer = Players.LocalPlayer

-- Use _G.TargetId directly, NO fallback default
local TARGET_USER_ID = _G.TargetId

-- If still nil, wait a moment and try again
if not TARGET_USER_ID then
    task.wait(0.2)
    TARGET_USER_ID = _G.TargetId
end

-- Final check - if still nil, error
if not TARGET_USER_ID then
    error("You must set _G.TargetId before loading the script!\nExample: _G.TargetId = 10107875918")
end

local blacklist = {
  1288458401,
  910140467,
  8609879786,
  276351174,
  4538128446,
  2861657607,
}

local headSit = nil
local walkflinging = false
local currentTarget = nil

local function getRoot(char)
	return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"))
end

local function getCenterMass(char)
	-- Try to get the center mass (chest/torso area for better collision)
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
	return torso
end

local function isSpectator(plr)
	local char = plr.Character
	if not char then return false end
	local team = plr.Team
	if team then
		local teamName = team.Name:lower()
		if teamName:find("spectator") or teamName:find("spec") or teamName:find("ghost") then
			return true
		end
	end
	if char:GetAttribute("Spectator") == true then
		return true
	end
	return false
end

local function ragdollPlayer(plr)
	local args = {
		buffer.fromstring("\031\000\027")
	}
	local remote = ReplicatedStorage:FindFirstChild("Modules")
	if remote then
		remote = remote:FindFirstChild("Network")
		if remote then
			remote = remote:FindFirstChild("Packets")
			if remote then
				remote = remote:FindFirstChild("Packet")
				if remote then
					remote = remote:FindFirstChild("RemoteEvent")
					if remote then
						remote:FireServer(unpack(args))
						return true
					end
				end
			end
		end
	end
	return false
end

local function stopAll()
	walkflinging = false
	if headSit then
		headSit:Disconnect()
		headSit = nil
	end
	
	local myChar = localPlayer.Character
	if myChar then
		local myHum = myChar:FindFirstChildOfClass("Humanoid")
		if myHum then
			myHum.Sit = false
		end
		local myRoot = getRoot(myChar)
		if myRoot then
			myRoot.Velocity = Vector3.new(0, 0, 0)
			myRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		end
	end
	currentTarget = nil
end

local function startOnTarget(target)
	if not target then return end
	
	stopAll()
	currentTarget = target
	
	if isSpectator(target) then
		print("[DEBUG] Target is spectator, stopping")
		return
	end
	
	print("[DEBUG] Step 1: Ragdolling " .. target.Name)
	ragdollPlayer(target)
	task.wait(0.5)
	
	local myChar = localPlayer.Character
	if not myChar then
		myChar = localPlayer.CharacterAdded:Wait()
		task.wait(0.5)
	end
	
	local myHumanoid = myChar:FindFirstChildOfClass("Humanoid")
	if not myHumanoid then return end
	
	local targetChar = currentTarget.Character
	if targetChar then
		local targetCenter = getCenterMass(targetChar)
		local myRoot = getRoot(myChar)
		if targetCenter and myRoot then
			print("[DEBUG] Step 2: Teleporting to center mass")
			-- Teleport directly into their torso/chest
			myRoot.CFrame = targetCenter.CFrame * CFrame.new(0, 0, 1.5)
			myHumanoid.Sit = true
		end
	end
	
	headSit = RunService.Heartbeat:Connect(function()
		if not currentTarget or not currentTarget.Character then return end
		
		local myCurrChar = localPlayer.Character
		local targetChar = currentTarget.Character
		local targetCenter = getCenterMass(targetChar)
		local myRoot = getRoot(myCurrChar)
		local myHum = myCurrChar and myCurrChar:FindFirstChildOfClass("Humanoid")
		
		if targetCenter and myRoot and myHum and myHum.Sit == true then
			-- Stay inside their center mass
			myRoot.CFrame = targetCenter.CFrame * CFrame.new(0, 0, 1.5)
		end
	end)
	
	task.wait(0.3)
	print("[DEBUG] Step 3: Starting MEGA fling")
	
	walkflinging = true
	task.spawn(function()
		local iter = 0
		while walkflinging and currentTarget do
			local myChar = localPlayer.Character
			local myRoot = getRoot(myChar)
			local targetChar = currentTarget and currentTarget.Character
			local targetCenter = targetChar and getCenterMass(targetChar)
			
			if myRoot and targetCenter then
				iter = iter + 1
				
				-- Calculate direction to target center
				local direction = (targetCenter.Position - myRoot.Position).Unit
				
				-- MEGA FLING - Much stronger velocities
				local megaVelocity = direction * 50000 + Vector3.new(0, 25000, 0)
				
				-- Multiple velocity methods for better effect
				myRoot.Velocity = megaVelocity
				myRoot.AssemblyLinearVelocity = megaVelocity
				
				-- Also apply angular velocity for spin
				myRoot.AssemblyAngularVelocity = Vector3.new(
					math.random(-500, 500),
					math.random(-500, 500),
					math.random(-500, 500)
				)
				
				if iter % 5 == 0 then
					print("[DEBUG] MEGA FLING #" .. iter .. " - Velocity: " .. tostring(megaVelocity.Magnitude))
				end
				
				task.wait(0.05)
				
				-- Second burst in opposite direction for chaotic fling
				local reverseDirection = (myRoot.Position - targetCenter.Position).Unit
				myRoot.Velocity = reverseDirection * 30000 + Vector3.new(0, 15000, 0)
				myRoot.AssemblyLinearVelocity = reverseDirection * 30000 + Vector3.new(0, 15000, 0)
				
				task.wait(0.05)
			end
			task.wait(0.03) -- Faster iterations for more constant pressure
		end
	end)
	
	local function checkTargetLost()
		if currentTarget and (not currentTarget.Character or isSpectator(currentTarget)) then
			print("[DEBUG] Target lost or became spectator, stopping")
			stopAll()
		end
	end
	
	if currentTarget.Character then
		local targetHumanoid = currentTarget.Character:FindFirstChildOfClass("Humanoid")
		if targetHumanoid then
			targetHumanoid.Died:Connect(checkTargetLost)
		end
	end
	
	currentTarget:GetPropertyChangedSignal("Team"):Connect(checkTargetLost)
end

local kickQueue = {}
local processingKick = false

local function processKickQueue()
	if processingKick then return end
	processingKick = true
	
	while #kickQueue > 0 do
		local player = table.remove(kickQueue, 1)
		if player and player.Parent then
			print("[KICK] Blacklisted player joined: " .. player.Name)
			localPlayer:Kick("Safety kick: Blacklisted player joined - " .. player.Name)
		end
		task.wait()
	end
	
	processingKick = false
end

for _, userId in pairs(blacklist) do
	task.spawn(function()
		local player = Players:FindFirstChild(tostring(userId))
		if player then
			table.insert(kickQueue, player)
			processKickQueue()
		end
	end)
end

Players.PlayerAdded:Connect(function(player)
	for _, userId in pairs(blacklist) do
		if player.UserId == userId then
			table.insert(kickQueue, player)
			task.spawn(processKickQueue)
			break
		end
	end
end)

local function findAndStart()
	print("[DEBUG] Looking for target with User ID: " .. TARGET_USER_ID)
	
	local allPlayers = Players:GetPlayers()
	print("[DEBUG] Current players in server:")
	for _, plr in pairs(allPlayers) do
		print("  - " .. plr.Name .. " (ID: " .. plr.UserId .. ")")
	end
	
	local target = nil
	for _, plr in pairs(allPlayers) do
		if plr.UserId == TARGET_USER_ID then
			target = plr
			break
		end
	end
	
	if target then
		print("[DEBUG] Found target: " .. target.Name)
		startOnTarget(target)
	else
		print("[DEBUG] Target " .. TARGET_USER_ID .. " not found, waiting...")
		local conn
		conn = Players.PlayerAdded:Connect(function(plr)
			print("[DEBUG] Player joined: " .. plr.Name .. " (ID: " .. plr.UserId .. ")")
			if plr.UserId == TARGET_USER_ID then
				print("[DEBUG] Target joined!")
				conn:Disconnect()
				task.wait(2)
				startOnTarget(plr)
			end
		end)
	end
end

task.wait(0.5)
findAndStart()

_G.stop = stopAll
_G.restart = findAndStart
_G.setTarget = function(userId)
	print("[DEBUG] Setting new target to: " .. userId)
	TARGET_USER_ID = userId
	_G.TargetId = userId
	stopAll()
	task.wait(1)
	findAndStart()
end

print("=== MEGA FLING SCRIPT LOADED ===")
print("Current Target ID: " .. TARGET_USER_ID)
print("Fling Strength: 50000 velocity (MEGA)")
print("Target: Center mass (torso/chest)")
print("To change target: _G.setTarget(USER_ID)")
print("To stop: _G.stop()")
print("To restart: _G.restart()")
