local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local localPlayer = Players.LocalPlayer

local target = nil
local headSitConnection = nil
local walkflinging = false

local function getRoot(char)
	return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
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

local function stop()
	walkflinging = false
	if headSitConnection then
		headSitConnection:Disconnect()
		headSitConnection = nil
	end
	if target and target.Character then
		local humanoid = target.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			humanoid.Sit = false
		end
		local root = getRoot(target.Character)
		if root then
			root.Velocity = Vector3.new(0, 0, 0)
		end
	end
	print("Stopped")
end

local function start()
	stop()
	target = getRandomTarget()
	if not target then
		print("No target found")
		return
	end
	
	print("Targeting: " .. target.Name)
	
	local char = target.Character
	if not char then
		char = target.CharacterAdded:Wait()
		task.wait(0.5)
	end
	
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		print("No humanoid")
		return
	end
	
	-- Make them sit
	humanoid.Sit = true
	
	-- Head sit (teleports them onto their own head)
	headSitConnection = RunService.Heartbeat:Connect(function()
		if target and target.Character then
			local currChar = target.Character
			local root = getRoot(currChar)
			local hum = currChar:FindFirstChildOfClass("Humanoid")
			if root and hum and hum.Sit == true then
				root.CFrame = root.CFrame * CFrame.new(0, 1.6, 0.4)
			end
		end
	end)
	
	-- Walk fling (exact copy from Infinite Yield)
	walkflinging = true
	task.spawn(function()
		repeat 
			RunService.Heartbeat:Wait()
			local character = target.Character
			local root = getRoot(character)
			local vel, movel = nil, 0.1

			while not (character and character.Parent and root and root.Parent) do
				RunService.Heartbeat:Wait()
				character = target.Character
				root = getRoot(character)
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
	
	-- Auto stop if they become spectator or die
	task.spawn(function()
		while walkflinging and target do
			task.wait(0.5)
			if not target.Character or isSpectator(target) then
				print("Target is now spectator or dead, stopping")
				stop()
				break
			end
		end
	end)
end

-- Start immediately
start()

_G.stop = stop
_G.restart = start

print("Script loaded! Targeting random player")
print("Type _G.stop() to stop")
print("Type _G.restart() to pick a new target")
