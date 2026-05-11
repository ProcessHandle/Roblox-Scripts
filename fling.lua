"-- MODE SELECTION
-- Set this before loading script:
-- _G.Mode = "Specific"  -- Target a specific user by ID
-- _G.Mode = "Killers"   -- Target everyone on team "Killers"
-- _G.TargetId = 10107875918  -- Only needed for Specific mode

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local localPlayer = Players.LocalPlayer

local MODE = _G.Mode or "Specific"
local TARGET_USER_ID = _G.TargetId

if MODE == "Specific" and not TARGET_USER_ID then
    task.wait(0.2)
    TARGET_USER_ID = _G.TargetId
end

if MODE == "Specific" and not TARGET_USER_ID then
    error("You must set _G.TargetId before loading the script!\nExample: _G.TargetId = 10107875918")
end

print("[MODE] Running in " .. MODE .. " mode")

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
local noclipConnection = nil
local killersQueue = {}

local function getHeadPosition(char)
    if not char then return nil end
    
    local head = char:FindFirstChild("Head")
    if head and head:IsA("BasePart") then
        return head.CFrame
    end
    
    local root = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
    if root then
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if humanoid then
            if humanoid:GetState() == Enum.HumanoidStateType.Prone then
                return root.CFrame * CFrame.new(0, 0.3, 0)
            elseif humanoid:GetState() == Enum.HumanoidStateType.Seated or humanoid.Sit then
                return root.CFrame * CFrame.new(0, 1.2, 0)
            elseif humanoid:GetState() == Enum.HumanoidStateType.GettingUp then
                return root.CFrame * CFrame.new(0, 0.8, 0)
            elseif humanoid:GetState() == Enum.HumanoidStateType.Climbing then
                return root.CFrame * CFrame.new(0, 0.5, 0)
            else
                local lowerTorso = char:FindFirstChild("LowerTorso")
                if lowerTorso and lowerTorso.Position.Y < root.Position.Y + 0.5 then
                    return root.CFrame * CFrame.new(0, 0.6, 0)
                end
                return root.CFrame * CFrame.new(0, 1.6, 0)
            end
        end
        return root.CFrame * CFrame.new(0, 1.6, 0)
    end
    return nil
end

local function getRoot(char)
	return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
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
	if noclipConnection then
		noclipConnection:Disconnect()
		noclipConnection = nil
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
		local targetHeadCFrame = getHeadPosition(targetChar)
		local myRoot = getRoot(myChar)
		if targetHeadCFrame and myRoot then
			print("[DEBUG] Step 2: Teleporting to target's dynamic head position")
			myRoot.CFrame = targetHeadCFrame
			myHumanoid.Sit = true
		end
	end
	
	local function noclipLoop()
		if currentTarget and localPlayer.Character then
			for _, child in pairs(localPlayer.Character:GetDescendants()) do
				if child:IsA("BasePart") and child.CanCollide == true then
					child.CanCollide = false
				end
			end
		end
	end
	noclipConnection = RunService.Stepped:Connect(noclipLoop)
	
	headSit = RunService.Heartbeat:Connect(function()
		if not currentTarget or not currentTarget.Character then return end
		
		local myCurrChar = localPlayer.Character
		local targetChar = currentTarget.Character
		local myRoot = getRoot(myCurrChar)
		local myHum = myCurrChar and myCurrChar:FindFirstChildOfClass("Humanoid")
		
		if myRoot and myHum and myHum.Sit == true then
			local targetHeadCFrame = getHeadPosition(targetChar)
			if targetHeadCFrame then
				myRoot.CFrame = targetHeadCFrame
			end
		end
	end)
	
	task.wait(0.3)
	print("[DEBUG] Step 3: Starting IY-style walkfling")
	
	walkflinging = true
	task.spawn(function()
		repeat 
			RunService.Heartbeat:Wait()
			local character = localPlayer.Character
			local root = getRoot(character)
			local vel, movel = nil, 0.1

			while not (character and character.Parent and root and root.Parent) do
				RunService.Heartbeat:Wait()
				character = localPlayer.Character
				root = getRoot(character)
			end

			vel = root.Velocity
			root.Velocity = vel * 100000 + Vector3.new(0, 100000, 0)

			RunService.RenderStepped:Wait()
			if character and character.Parent and root and root.Parent and walkflinging then
				root.Velocity = vel
			end

			RunService.Stepped:Wait()
			if character and character.Parent and root and root.Parent and walkflinging then
				root.Velocity = vel + Vector3.new(0, movel * 100, 0)
				movel = movel * -1
			end
		until walkflinging == false
	end)
	
	local function checkTargetLost()
		if currentTarget and (not currentTarget.Character or isSpectator(currentTarget)) then
			print("[DEBUG] Target lost or became spectator, stopping")
			stopAll()
			
			if MODE == "Killers" then
				for i, killer in pairs(killersQueue) do
					if killer == currentTarget then
						table.remove(killersQueue, i)
						break
					end
				end
				if #killersQueue > 0 then
					task.wait(1)
					startOnTarget(killersQueue[1])
				end
			end
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

local function updateKillersQueue()
	if MODE ~= "Killers" then return end
	
	local newKillers = {}
	for _, plr in pairs(Players:GetPlayers()) do
		if plr ~= localPlayer and plr.Team and plr.Team.Name == "Killers" then
			if not isSpectator(plr) then
				table.insert(newKillers, plr)
			end
		end
	end
	
	local changed = false
	if #newKillers ~= #killersQueue then
		changed = true
	else
		for i, killer in pairs(newKillers) do
			if killersQueue[i] ~= killer then
				changed = true
				break
			end
		end
	end
	
	if changed then
		killersQueue = newKillers
		print("[KILLERS MODE] Updated killers queue. Found " .. #killersQueue .. " players on Killers team:")
		for i, killer in pairs(killersQueue) do
			print("  " .. i .. ". " .. killer.Name .. " (ID: " .. killer.UserId .. ")")
		end
		
		if not currentTarget and #killersQueue > 0 then
			startOnTarget(killersQueue[1])
		end
	end
end

if MODE == "Killers" then
	updateKillersQueue()
	
	Players.PlayerAdded:Connect(function(plr)
		task.wait(1)
		updateKillersQueue()
	end)
	
	Players.PlayerRemoving:Connect(function()
		task.wait(0.5)
		updateKillersQueue()
	end)
	
	local function watchTeamChanges(plr)
		if plr == localPlayer then return end
		plr:GetPropertyChangedSignal("Team"):Connect(function()
			task.wait(0.5)
			updateKillersQueue()
		end)
	end
	
	for _, plr in pairs(Players:GetPlayers()) do
		watchTeamChanges(plr)
	end
	
	Players.PlayerAdded:Connect(watchTeamChanges)
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
	if MODE == "Specific" then
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
	elseif MODE == "Killers" then
		print("[KILLERS MODE] Ready - targeting all players on team 'Killers'")
		print("[KILLERS MODE] Currently found: " .. #killersQueue .. " players")
	end
end

task.wait(0.5)

if MODE == "Specific" then
	findAndStart()
end

_G.stop = stopAll
_G.restart = findAndStart
_G.setTarget = function(userId)
	if MODE == "Specific" then
		print("[DEBUG] Setting new target to: " .. userId)
		TARGET_USER_ID = userId
		_G.TargetId = userId
		stopAll()
		task.wait(1)
		findAndStart()
	else
		print("[ERROR] Cannot use setTarget() in Killers mode. Switch to Specific mode.")
	end
end

_G.getKillersQueue = function()
	if MODE == "Killers" then
		local queueList = {}
		for i, killer in pairs(killersQueue) do
			queueList[i] = killer.Name .. " (ID: " .. killer.UserId .. ")"
		end
		return queueList
	else
		print("[ERROR] getKillersQueue() only works in Killers mode")
	end
end

print("=== IY-STYLE MEGA FLING LOADED ===")
print("Mode: " .. MODE)
if MODE == "Specific" then
	print("Current Target ID: " .. TARGET_USER_ID)
else
	print("Targeting team: Killers")
	print("Use _G.getKillersQueue() to see current targets")
end
print("Using Infinite Yield's exact walkfling sequence")
print("Velocity: 100x stronger (100,000 instead of 1,000)")
print("To change target (Specific mode): _G.setTarget(USER_ID)")
print("To stop: _G.stop()")
print("To restart: _G.restart()")
