local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer

local headSit = nil
local walkflinging = false
local currentTarget = nil
local teamCheck = nil
local monitor = nil

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
		local selected = valid[math.random(1, #valid)]
		print("[DEBUG] Selected target: " .. selected.Name)
		return selected
	end
	print("[DEBUG] No valid target found")
	return nil
end

local function stopAll()
	print("[DEBUG] Stopping all effects")
	walkflinging = false
	
	if headSit then
		headSit:Disconnect()
		headSit = nil
	end
	
	if teamCheck then
		teamCheck:Disconnect()
		teamCheck = nil
	end
	
	if currentTarget and currentTarget.Character then
		local hum = currentTarget.Character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Sit = false
		end
		local root = getRoot(currentTarget.Character)
		if root then
			root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			root.Velocity = Vector3.new(0, 0, 0)
		end
	end
	
	currentTarget = nil
end

local function startOnTarget(target)
	if not target then
		print("[DEBUG] No target provided")
		return
	end
	
	print("[DEBUG] Starting on target: " .. target.Name)
	stopAll()
	currentTarget = target
	
	local char = currentTarget.Character
	if not char then
		print("[DEBUG] Waiting for character...")
		char = currentTarget.CharacterAdded:Wait()
		task.wait(0.5)
	end
	
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		print("[ERROR] No humanoid found")
		return
	end
	
	print("[DEBUG] Setting humanoid.Sit = true")
	humanoid.Sit = true
	
	-- EXACT headsit from IY source
	headSit = RunService.Heartbeat:Connect(function()
		if not currentTarget or not currentTarget.Character then
			return
		end
		
		local currChar = currentTarget.Character
		local currRoot = getRoot(currChar)
		local currHum = currChar:FindFirstChildOfClass("Humanoid")
		
		if currRoot and currHum and currHum.Sit == true then
			currRoot.CFrame = currRoot.CFrame * CFrame.new(0, 1.6, 0.4)
			-- print("[DEBUG] Headsit position updated")
		end
	end)
	
	-- EXACT walkfling from IY source
	walkflinging = true
	task.spawn(function()
		local iteration = 0
		repeat 
			RunService.Heartbeat:Wait()
			
			if not currentTarget or not currentTarget.Character then
				print("[DEBUG] Target lost in walkfling")
				break
			end
			
			local character = currentTarget.Character
			local root = getRoot(character)
			local vel, movel = nil, 0.1

			while not (character and character.Parent and root and root.Parent) do
				RunService.Heartbeat:Wait()
				if not currentTarget then break end
				character = currentTarget.Character
				root = getRoot(character)
				if not walkflinging then break end
			end
			
			if not walkflinging then break end
			if not root then continue end

			iteration = iteration + 1
			if iteration % 10 == 0 then
				print("[DEBUG] Walkfling iteration " .. iteration .. " - Root velocity: " .. tostring(root.Velocity))
			end

			vel = root.Velocity
			root.Velocity = vel * 10000 + Vector3.new(0, 10000, 0)

			RunService.RenderStepped:Wait()
			if character and character.Parent and root and root.Parent and walkflinging then
				root.Velocity = vel
			end

			RunService.Stepped:Wait()
			if character and character.Parent and root and root.Parent and walkflinging then
				root.Velocity = vel + Vector3.new(0, movel, 0)
				movel = movel * -1
			end
		until walkflinging == false
		print("[DEBUG] Walkfling thread ended")
	end)
	
	-- Auto stop if they die
	humanoid.Died:Connect(function()
		print("[DEBUG] Target died, stopping")
		if walkflinging then
			stopAll()
		end
	end)
	
	-- Monitor for spectator status
	if teamCheck then teamCheck:Disconnect() end
	teamCheck = currentTarget:GetPropertyChangedSignal("Team"):Connect(function()
		if not currentTarget then
			if teamCheck then teamCheck:Disconnect() end
			return
		end
		
		if isSpectator(currentTarget) then
			print("[DEBUG] Target became spectator, stopping")
			stopAll()
			if teamCheck then teamCheck:Disconnect() end
		end
	end)
end

local function start()
	print("[DEBUG] Start called")
	local target = getRandomNonSpectator()
	if target then
		startOnTarget(target)
	else
		print("[DEBUG] No valid target, waiting for player join...")
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

-- Auto-start
start()

-- Monitor to restart when target is lost
monitor = RunService.Heartbeat:Connect(function()
	if not walkflinging and not headSit and currentTarget == nil then
		print("[DEBUG] Monitor: No active target, restarting...")
		local newTarget = getRandomNonSpectator()
		if newTarget then
			startOnTarget(newTarget)
		end
	end
end)

-- Global controls
_G.stop = stopAll
_G.restart = start
_G.status = function()
	print("=== STATUS ===")
	print("walkflinging: " .. tostring(walkflinging))
	print("headSit: " .. tostring(headSit ~= nil))
	print("currentTarget: " .. tostring(currentTarget and currentTarget.Name or "nil"))
	print("teamCheck: " .. tostring(teamCheck ~= nil))
end

print("=== Combined Headsit + Walkfling Loaded ===")
print("Type _G.status() to check status")
print("Type _G.stop() to stop")
print("Type _G.restart() to restart")
