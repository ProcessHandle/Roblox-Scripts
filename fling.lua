local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer

local walkflinging = false
local headSitConnection = nil
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
	return false
end

local function getRandomTarget()
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

local function stopEffect()
	walkflinging = false
	if headSitConnection then
		headSitConnection:Disconnect()
		headSitConnection = nil
	end
	if currentTarget and currentTarget.Character then
		local hum = currentTarget.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum.Sit = false end
		local root = getRoot(currentTarget.Character)
		if root then root.Velocity = Vector3.new(0, 0, 0) end
	end
	currentTarget = nil
end

local function startEffect()
	stopEffect()
	
	currentTarget = getRandomTarget()
	if not currentTarget then
		print("No valid target found")
		return
	end
	
	print("Targeting: " .. currentTarget.Name)
	
	local char = currentTarget.Character
	if not char then
		char = currentTarget.CharacterAdded:Wait()
		task.wait(0.5)
	end
	
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	local rootPart = getRoot(char)
	
	if not humanoid or not rootPart then
		print("Missing humanoid or root part")
		return
	end
	
	humanoid.Sit = true
	
	headSitConnection = RunService.Heartbeat:Connect(function()
		if currentTarget and currentTarget.Character then
			local currChar = currentTarget.Character
			local currRoot = getRoot(currChar)
			local currHum = currChar:FindFirstChildOfClass("Humanoid")
			if currRoot and currHum and currHum.Sit == true then
				currRoot.CFrame = currRoot.CFrame * CFrame.new(0, 1.6, 0.4)
			end
		end
	end)
	
	walkflinging = true
	
	task.spawn(function()
		repeat 
			RunService.Heartbeat:Wait()
			local character = currentTarget and currentTarget.Character
			local root = character and getRoot(character)
			local vel, movel = nil, 0.1

			while not (character and character.Parent and root and root.Parent) do
				RunService.Heartbeat:Wait()
				character = currentTarget and currentTarget.Character
				root = character and getRoot(character)
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
	end)
	
	humanoid.Died:Connect(function()
		if walkflinging then stopEffect() end
	end)
end

startEffect()

_G.stop = stopEffect
_G.restart = startEffect

print("Script loaded - using Infinite Yield's exact walkfling method")
print("Type _G.stop() to stop, _G.restart() to restart")
