local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer

local targetPlayer = nil
local active = false
local headSitConn = nil
local flingThread = nil

-- Function to check if a player is a spectator
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

-- Get a random player (not local, not spectator)
local function getRandomPlayer()
	local validPlayers = {}
	for _, plr in pairs(Players:GetPlayers()) do
		if plr ~= localPlayer and not isSpectator(plr) and plr.Character then
			table.insert(validPlayers, plr)
		end
	end
	if #validPlayers > 0 then
		return validPlayers[math.random(1, #validPlayers)]
	end
	return nil
end

function startEffect()
	if active then return end
	
	targetPlayer = getRandomPlayer()
	if not targetPlayer then
		print("No valid target found")
		return
	end
	
	print("Target found: " .. targetPlayer.Name)
	
	-- Wait for character if needed
	if not targetPlayer.Character then
		targetPlayer.CharacterAdded:Wait()
		task.wait(1)
	end
	
	local char = targetPlayer.Character
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local rootPart = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
	
	if not humanoid or not rootPart then
		print("Could not find humanoid or root part")
		return
	end
	
	print("Starting effect on: " .. targetPlayer.Name)
	active = true
	
	-- Make them sit
	humanoid.Sit = true
	
	-- Head sit - keep them on their own head
	headSitConn = RunService.Heartbeat:Connect(function()
		if not active or not targetPlayer or not targetPlayer.Character then
			if headSitConn then headSitConn:Disconnect() end
			return
		end
		local currentChar = targetPlayer.Character
		local currentRoot = currentChar:FindFirstChild("HumanoidRootPart") or currentChar:FindFirstChild("Torso")
		local currentHumanoid = currentChar:FindFirstChildOfClass("Humanoid")
		if currentRoot and currentHumanoid and currentHumanoid.Sit == true then
			currentRoot.CFrame = currentRoot.CFrame * CFrame.new(0, 1.6, 0.4)
		end
	end)
	
	-- Walk fling
	flingThread = task.spawn(function()
		local vel, movel = nil, 0.1
		while active and targetPlayer and targetPlayer.Character do
			task.wait()
			local currentChar = targetPlayer.Character
			local root = currentChar:FindFirstChild("HumanoidRootPart") or currentChar:FindFirstChild("Torso")
			
			if root then
				vel = root.Velocity
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
			end
		end
	end)
	
	-- Stop if they die
	humanoid.Died:Connect(function()
		print("Target died, stopping")
		stopEffect()
	end)
end

function stopEffect()
	active = false
	if headSitConn then headSitConn:Disconnect() end
	if flingThread then task.cancel(flingThread) end
	if targetPlayer and targetPlayer.Character then
		local humanoid = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Sit = false
		end
		local root = targetPlayer.Character:FindFirstChild("HumanoidRootPart") or targetPlayer.Character:FindFirstChild("Torso")
		if root then
			root.Velocity = Vector3.new(0, 0, 0)
		end
	end
	print("Effect stopped")
end

-- Start immediately
startEffect()

_G.stop = stopEffect
_G.restart = startEffect

print("Script loaded - targeting a random player (not local, not spectator)")
print("Type _G.stop() to stop")
print("Type _G.restart() to pick a new random player and start again")
