local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local localPlayer = Players.LocalPlayer

local headSit = nil
local walkflinging = false
local currentTarget = nil

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
						print("[DEBUG] Ragdoll remote fired")
						return true
					end
				end
			end
		end
	end
	print("[WARN] Could not find ragdoll remote")
	return false
end

local function getRandomNonSpectator()
	local valid = {}
	for _, plr in pairs(Players:GetPlayers()) do
		if plr ~= localPlayer and not isSpectator(plr) and plr.Character and getRoot(plr.Character) then
			table.insert(valid, plr)
		end
	end
	if #valid > 0 then
		return valid[math.random(1, #valid)]
	end
	return nil
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
		end
	end
	currentTarget = nil
end

local function startOnTarget(target)
	if not target then return end
	
	stopAll()
	currentTarget = target
	
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
	
	-- Make YOU sit on their head
	local targetChar = currentTarget.Character
	if targetChar then
		local targetRoot = getRoot(targetChar)
		local myRoot = getRoot(myChar)
		if targetRoot and myRoot then
			print("[DEBUG] Step 2: Teleporting to head")
			myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 1.6, 0)
			myHumanoid.Sit = true
		end
	end
	
	-- Headsit - keep you on their head
	headSit = RunService.Heartbeat:Connect(function()
		if not currentTarget or not currentTarget.Character then return end
		
		local myCurrChar = localPlayer.Character
		local targetChar = currentTarget.Character
		local targetRoot = getRoot(targetChar)
		local myRoot = getRoot(myCurrChar)
		local myHum = myCurrChar and myCurrChar:FindFirstChildOfClass("Humanoid")
		
		if targetRoot and myRoot and myHum and myHum.Sit == true then
			myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 1.6, 0)
		end
	end)
	
	-- Walkfling - fling YOUR character into them
	task.wait(0.3)
	print("[DEBUG] Step 3: Starting fling")
	
	walkflinging = true
	task.spawn(function()
		local iter = 0
		while walkflinging and currentTarget do
			local myChar = localPlayer.Character
			local myRoot = getRoot(myChar)
			local targetChar = currentTarget and currentTarget.Character
			local targetRoot = targetChar and getRoot(targetChar)
			
			if myRoot and targetRoot then
				local direction = (targetRoot.Position - myRoot.Position).Unit
				
				iter = iter + 1
				local vel, movel = nil, 0.1
				
				-- Massive velocity spike into them
				myRoot.Velocity = direction * 10000 + Vector3.new(0, 10000, 0)
				
				task.wait()
				if myRoot and myRoot.Parent and walkflinging then
					myRoot.Velocity = vel or Vector3.new()
				end
				
				task.wait()
				if myRoot and myRoot.Parent and walkflinging then
					myRoot.Velocity = (vel or Vector3.new()) + Vector3.new(0, movel, 0)
					movel = movel * -1
				end
			end
			task.wait()
		end
	end)
	
	-- Stop if target dies or becomes spectator
	local function checkTargetLost()
		if currentTarget and (not currentTarget.Character or isSpectator(currentTarget)) then
			print("[DEBUG] Target lost, stopping")
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

local function start()
	print("[DEBUG] Looking for target...")
	local target = getRandomNonSpectator()
	if target then
		print("[DEBUG] Found target: " .. target.Name)
		startOnTarget(target)
	else
		print("[DEBUG] No target, waiting for player...")
		local conn
		conn = Players.PlayerAdded:Connect(function(plr)
			if plr ~= localPlayer and not isSpectator(plr) then
				print("[DEBUG] Player joined: " .. plr.Name)
				conn:Disconnect()
				task.wait(1)
				startOnTarget(plr)
			end
		end)
	end
end

start()

RunService.Heartbeat:Connect(function()
	if not walkflinging and not headSit and currentTarget == nil then
		local newTarget = getRandomNonSpectator()
		if newTarget then startOnTarget(newTarget) end
	end
end)

_G.stop = stopAll
_G.restart = start

print("=== Script Loaded ===")
print("Step 1: Ragdolls target player")
print("Step 2: Sits on their head")
print("Step 3: Flings into them repeatedly")
print("Type _G.stop() to stop")
print("Type _G.restart() to restart")
