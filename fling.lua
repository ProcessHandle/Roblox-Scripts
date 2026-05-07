local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
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
			myRoot.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		end
	end
	currentTarget = nil
end

local function startOnTarget(target)
	if not target then return end
	
	stopAll()
	currentTarget = target
	
	local myChar = localPlayer.Character
	if not myChar then
		myChar = localPlayer.CharacterAdded:Wait()
		task.wait(0.5)
	end
	
	local myHumanoid = myChar:FindFirstChildOfClass("Humanoid")
	if not myHumanoid then return end
	
	-- Teleport YOU directly into the target first
	local targetChar = currentTarget.Character
	if targetChar then
		local targetRoot = getRoot(targetChar)
		local myRoot = getRoot(myChar)
		if targetRoot and myRoot then
			-- Sit on their head
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
			-- Stay on their head
			myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 1.6, 0)
		end
	end)
	
	-- Walkfling - fling YOUR character into them repeatedly
	walkflinging = true
	task.spawn(function()
		local iter = 0
		while walkflinging and currentTarget do
			local myChar = localPlayer.Character
			local myRoot = getRoot(myChar)
			local targetChar = currentTarget and currentTarget.Character
			local targetRoot = targetChar and getRoot(targetChar)
			
			if myRoot and targetRoot then
				-- Face the target
				local direction = (targetRoot.Position - myRoot.Position).Unit
				
				iter = iter + 1
				if iter % 10 == 0 then
					print("[DEBUG] Flinging into " .. currentTarget.Name .. " - Velocity: " .. tostring(myRoot.Velocity))
				end
				
				-- Launch yourself at them
				myRoot.Velocity = direction * 500 + Vector3.new(0, 100, 0)
				
				task.wait(0.1)
				
				-- Reset and launch again
				myRoot.Velocity = direction * 500 + Vector3.new(0, -100, 0)
			end
			task.wait(0.2)
		end
	end)
	
	-- Stop if target dies or becomes spectator
	local function checkTargetLost()
		if currentTarget and (not currentTarget.Character or isSpectator(currentTarget)) then
			print("Target lost or became spectator")
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
	local target = getRandomNonSpectator()
	if target then
		print("Targeting: " .. target.Name)
		startOnTarget(target)
	else
		print("No target, waiting...")
		local conn
		conn = Players.PlayerAdded:Connect(function(plr)
			if plr ~= localPlayer and not isSpectator(plr) then
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

print("=== Loaded ===")
print("Sits you on target's head and flings YOU into them")
print("Your velocity collides with target to fling them")
