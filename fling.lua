local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer

local active = false
local headSitConn = nil
local flingThread = nil
local currentTarget = nil

local function getRoot(char)
	return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
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

local function getRandomPlayer()
	local validPlayers = {}
	for _, plr in pairs(Players:GetPlayers()) do
		if plr ~= localPlayer and not isSpectator(plr) and plr.Character and getRoot(plr.Character) then
			table.insert(validPlayers, plr)
		end
	end
	if #validPlayers > 0 then
		return validPlayers[math.random(1, #validPlayers)]
	end
	return nil
end

local function stopEffect()
	print("Stopping effect...")
	active = false
	if headSitConn then
		headSitConn:Disconnect()
		headSitConn = nil
	end
	if flingThread then
		coroutine.close(flingThread)
		flingThread = nil
	end
	if currentTarget and currentTarget.Character then
		local humanoid = currentTarget.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Sit = false
		end
		local root = getRoot(currentTarget.Character)
		if root then
			root.Velocity = Vector3.new(0, 0, 0)
		end
	end
	currentTarget = nil
end

local function startEffectOnTarget(target)
	if not target then return end
	
	stopEffect()
	currentTarget = target
	
	-- Wait for character if needed
	local char = currentTarget.Character
	if not char then
		print("Waiting for character...")
		char = currentTarget.CharacterAdded:Wait()
		task.wait(0.5)
	end
	
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local root = getRoot(char)
	
	if not humanoid or not root then
		print("No humanoid or root found")
		return
	end
	
	print("Starting effect on: " .. currentTarget.Name)
	active = true
	
	-- Make them sit
	humanoid.Sit = true
	
	-- Head sit connection - keeps them on their own head
	headSitConn = RunService.Heartbeat:Connect(function()
		if not active or not currentTarget or not currentTarget.Character then
			return
		end
		local currChar = currentTarget.Character
		local currRoot = getRoot(currChar)
		local currHumanoid = currChar:FindFirstChildOfClass("Humanoid")
		if currRoot and currHumanoid and currHumanoid.Sit == true then
			currRoot.CFrame = currRoot.CFrame * CFrame.new(0, 1.6, 0.4)
		end
	end)
	
	-- Walk fling thread - CONTINUOUS LOOP
	flingThread = coroutine.create(function()
		local iteration = 0
		local movel = 0.1
		while true do
			if not active or not currentTarget or not currentTarget.Character then
				print("Loop breaking - target lost")
				break
			end
			
			local currChar = currentTarget.Character
			local root = getRoot(currChar)
			
			if not root then
				task.wait()
				continue
			end
			
			iteration = iteration + 1
			if iteration % 10 == 0 then
				print("Fling iteration: " .. iteration .. " on " .. currentTarget.Name)
			end
			
			local vel = root.Velocity
			root.Velocity = vel * 10000 + Vector3.new(0, 10000, 0)
			task.wait()
			
			if active and root and root.Parent then
				root.Velocity = vel
			end
			task.wait()
			
			if active and root and root.Parent then
				root.Velocity = vel + Vector3.new(0, movel, 0)
				movel = movel * -1
			end
			task.wait()
		end
	end)
	coroutine.resume(flingThread)
	
	-- Monitor for spectator status changes
	local function checkSpectator()
		while active and currentTarget do
			task.wait(0.5)
			if isSpectator(currentTarget) then
				print(currentTarget.Name .. " became a spectator! Stopping effect.")
				stopEffect()
				break
			end
		end
	end
	task.spawn(checkSpectator)
	
	-- Stop if they die
	humanoid.Died:Connect(function()
		if active then
			print(currentTarget.Name .. " died, stopping effect")
			stopEffect()
		end
	end)
end

-- Main function to pick random target and start
local function start()
	local target = getRandomPlayer()
	if target then
		startEffectOnTarget(target)
	else
		print("No valid target found, waiting for player to join...")
		local conn
		conn = Players.PlayerAdded:Connect(function(plr)
			if plr ~= localPlayer and not isSpectator(plr) then
				conn:Disconnect()
				task.wait(1)
				startEffectOnTarget(plr)
			end
		end)
	end
end

-- Start the script
start()

_G.stop = stopEffect
_G.restart = start

print("Script loaded!")
print("Type _G.stop() to stop the effect")
print("Type _G.restart() to pick a new random player and restart")
