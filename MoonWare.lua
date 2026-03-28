local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")

local Player = Players.LocalPlayer
assert(Player, "Failed to get LocalPlayer")

local function Notify(title, text)
    local success, err = pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = tostring(title),
            Text = tostring(text),
            Duration = 2
        })
    end)
    if not success then
        print("Notify error:", err)
    end
end

local ScreenGui
local _, err = pcall(function()
    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "MoonWareGUI"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = CoreGui
end)

assert(ScreenGui, "Failed to create GUI: " .. tostring(err))

-- Main Frame
local MainFrame
_, err = pcall(function()
    MainFrame = Instance.new("Frame")
    MainFrame.Size = UDim2.new(0, 300, 0, 380)
    MainFrame.Position = UDim2.new(0.5, -150, 0.5, -190)
    MainFrame.BackgroundColor3 = Color3.new(0.08, 0.05, 0.12)
    MainFrame.BackgroundTransparency = 0.15
    MainFrame.BorderSizePixel = 0
    MainFrame.Parent = ScreenGui
end)
assert(MainFrame, "Failed to create MainFrame: " .. tostring(err))

pcall(function()
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = MainFrame
end)

local TitleBar
_, err = pcall(function()
    TitleBar = Instance.new("Frame")
    TitleBar.Size = UDim2.new(1, 0, 0, 40)
    TitleBar.BackgroundColor3 = Color3.new(0.12, 0.08, 0.18)
    TitleBar.BackgroundTransparency = 0.2
    TitleBar.BorderSizePixel = 0
    TitleBar.Parent = MainFrame
end)
assert(TitleBar, "Failed to create TitleBar")

pcall(function()
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = TitleBar
end)

local TitleText
_, err = pcall(function()
    TitleText = Instance.new("TextLabel")
    TitleText.Size = UDim2.new(1, -35, 1, 0)
    TitleText.Position = UDim2.new(0, 12, 0, 0)
    TitleText.BackgroundTransparency = 1
    TitleText.Text = "🌙 MoonWare"
    TitleText.TextColor3 = Color3.new(0.9, 0.7, 0.35)
    TitleText.Font = Enum.Font.GothamBold
    TitleText.TextSize = 18
    TitleText.TextXAlignment = Enum.TextXAlignment.Left
    TitleText.Parent = TitleBar
end)

local SubtitleText
pcall(function()
    SubtitleText = Instance.new("TextLabel")
    SubtitleText.Size = UDim2.new(1, -35, 1, 0)
    SubtitleText.Position = UDim2.new(0, 12, 0, 22)
    SubtitleText.BackgroundTransparency = 1
    SubtitleText.Text = "multi-target"
    SubtitleText.TextColor3 = Color3.new(0.7, 0.55, 0.85)
    SubtitleText.Font = Enum.Font.Gotham
    SubtitleText.TextSize = 10
    SubtitleText.TextXAlignment = Enum.TextXAlignment.Left
    SubtitleText.Parent = TitleBar
end)

local CloseButton
_, err = pcall(function()
    CloseButton = Instance.new("TextButton")
    CloseButton.Size = UDim2.new(0, 30, 0, 30)
    CloseButton.Position = UDim2.new(1, -35, 0, 5)
    CloseButton.BackgroundTransparency = 1
    CloseButton.Text = "✕"
    CloseButton.TextColor3 = Color3.new(0.8, 0.6, 0.4)
    CloseButton.Font = Enum.Font.GothamBold
    CloseButton.TextSize = 16
    CloseButton.Parent = TitleBar
end)

local StatusFrame
_, err = pcall(function()
    StatusFrame = Instance.new("Frame")
    StatusFrame.Size = UDim2.new(1, -20, 0, 32)
    StatusFrame.Position = UDim2.new(0, 10, 0, 48)
    StatusFrame.BackgroundColor3 = Color3.new(0.18, 0.12, 0.22)
    StatusFrame.BackgroundTransparency = 0.4
    StatusFrame.BorderSizePixel = 0
    StatusFrame.Parent = MainFrame
end)

pcall(function()
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = StatusFrame
end)

local StatusLabel
_, err = pcall(function()
    StatusLabel = Instance.new("TextLabel")
    StatusLabel.Size = UDim2.new(1, -15, 1, 0)
    StatusLabel.Position = UDim2.new(0, 12, 0, 0)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = "0 targets"
    StatusLabel.TextColor3 = Color3.new(0.85, 0.8, 0.95)
    StatusLabel.Font = Enum.Font.Gotham
    StatusLabel.TextSize = 12
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
    StatusLabel.Parent = StatusFrame
end)

local ListFrame
_, err = pcall(function()
    ListFrame = Instance.new("Frame")
    ListFrame.Size = UDim2.new(1, -20, 0, 190)
    ListFrame.Position = UDim2.new(0, 10, 0, 88)
    ListFrame.BackgroundColor3 = Color3.new(0.12, 0.08, 0.18)
    ListFrame.BackgroundTransparency = 0.3
    ListFrame.BorderSizePixel = 0
    ListFrame.Parent = MainFrame
end)

pcall(function()
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = ListFrame
end)

local ScrollFrame
_, err = pcall(function()
    ScrollFrame = Instance.new("ScrollingFrame")
    ScrollFrame.Size = UDim2.new(1, -10, 1, -10)
    ScrollFrame.Position = UDim2.new(0, 5, 0, 5)
    ScrollFrame.BackgroundTransparency = 1
    ScrollFrame.BorderSizePixel = 0
    ScrollFrame.ScrollBarThickness = 3
    ScrollFrame.Parent = ListFrame
end)

local ButtonFrame
_, err = pcall(function()
    ButtonFrame = Instance.new("Frame")
    ButtonFrame.Size = UDim2.new(1, -20, 0, 38)
    ButtonFrame.Position = UDim2.new(0, 10, 0, 286)
    ButtonFrame.BackgroundTransparency = 1
    ButtonFrame.Parent = MainFrame
end)

local StartButton
_, err = pcall(function()
    StartButton = Instance.new("TextButton")
    StartButton.Size = UDim2.new(0.45, -5, 1, 0)
    StartButton.Position = UDim2.new(0, 0, 0, 0)
    StartButton.BackgroundColor3 = Color3.new(0.35, 0.2, 0.5)
    StartButton.Text = "START"
    StartButton.TextColor3 = Color3.new(1, 1, 1)
    StartButton.Font = Enum.Font.GothamBold
    StartButton.TextSize = 13
    StartButton.Parent = ButtonFrame
end)

pcall(function()
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = StartButton
end)

-- Stop button
local StopButton
_, err = pcall(function()
    StopButton = Instance.new("TextButton")
    StopButton.Size = UDim2.new(0.45, -5, 1, 0)
    StopButton.Position = UDim2.new(0.55, 5, 0, 0)
    StopButton.BackgroundColor3 = Color3.new(0.25, 0.18, 0.3)
    StopButton.Text = "STOP"
    StopButton.TextColor3 = Color3.new(1, 1, 1)
    StopButton.Font = Enum.Font.GothamBold
    StopButton.TextSize = 13
    StopButton.Parent = ButtonFrame
end)

pcall(function()
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = StopButton
end)

-- Action frame
local ActionFrame
_, err = pcall(function()
    ActionFrame = Instance.new("Frame")
    ActionFrame.Size = UDim2.new(1, -20, 0, 24)
    ActionFrame.Position = UDim2.new(0, 10, 0, 330)
    ActionFrame.BackgroundTransparency = 1
    ActionFrame.Parent = MainFrame
end)

-- Select all button
local SelectAllBtn
_, err = pcall(function()
    SelectAllBtn = Instance.new("TextButton")
    SelectAllBtn.Size = UDim2.new(0.45, -5, 1, 0)
    SelectAllBtn.Position = UDim2.new(0, 0, 0, 0)
    SelectAllBtn.BackgroundTransparency = 1
    SelectAllBtn.Text = "SELECT ALL"
    SelectAllBtn.TextColor3 = Color3.new(0.8, 0.6, 0.4)
    SelectAllBtn.Font = Enum.Font.Gotham
    SelectAllBtn.TextSize = 10
    SelectAllBtn.Parent = ActionFrame
end)

-- Deselect all button
local DeselectAllBtn
_, err = pcall(function()
    DeselectAllBtn = Instance.new("TextButton")
    DeselectAllBtn.Size = UDim2.new(0.45, -5, 1, 0)
    DeselectAllBtn.Position = UDim2.new(0.55, 5, 0, 0)
    DeselectAllBtn.BackgroundTransparency = 1
    DeselectAllBtn.Text = "DESELECT ALL"
    DeselectAllBtn.TextColor3 = Color3.new(0.8, 0.6, 0.4)
    DeselectAllBtn.Font = Enum.Font.Gotham
    DeselectAllBtn.TextSize = 10
    DeselectAllBtn.Parent = ActionFrame
end)

-- Variables
local SelectedTargets = {}
local IsFlinging = false
local FlingCoroutine = nil

-- Safe function to check if target is valid
local function IsValidTarget(target)
    if not target then return false end
    if target == Player then return false end
    
    local success, char = pcall(function()
        return target.Character
    end)
    if not success or not char then return false end
    
    local success, hum = pcall(function()
        return char:FindFirstChild("Humanoid")
    end)
    if not success or not hum then return false end
    
    local success, health = pcall(function()
        return hum.Health
    end)
    if not success or health <= 0 then return false end
    
    local success, team = pcall(function()
        return target.Team
    end)
    if success and team then
        local success, teamName = pcall(function()
            return team.Name
        end)
        if success and teamName == "Survivors" then
            return false
        end
    end
    
    return true
end

-- Update status display
local function UpdateStatus()
    local count = 0
    for _ in pairs(SelectedTargets) do
        count = count + 1
    end
    
    if IsFlinging then
        StatusLabel.Text = "⚡ Flinging " .. count .. " target(s)"
    else
        StatusLabel.Text = count .. " target(s) selected"
    end
end

-- Refresh player list
local function RefreshPlayerList()
    pcall(function()
        -- Clear old entries
        for _, child in ipairs(ScrollFrame:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        
        local yPos = 5
        local players = Players:GetPlayers()
        
        for _, player in ipairs(players) do
            if IsValidTarget(player) then
                -- Entry frame
                local entry = Instance.new("Frame")
                entry.Size = UDim2.new(1, -10, 0, 44)
                entry.Position = UDim2.new(0, 5, 0, yPos)
                entry.BackgroundColor3 = Color3.new(0.18, 0.12, 0.22)
                entry.BackgroundTransparency = 0.2
                entry.BorderSizePixel = 0
                entry.Parent = ScrollFrame
                
                -- Corner
                local corner = Instance.new("UICorner")
                corner.CornerRadius = UDim.new(0, 6)
                corner.Parent = entry
                
                -- Name label
                local nameLabel = Instance.new("TextLabel")
                nameLabel.Size = UDim2.new(1, -45, 0.5, 0)
                nameLabel.Position = UDim2.new(0, 8, 0, 4)
                nameLabel.BackgroundTransparency = 1
                nameLabel.Text = player.Name
                nameLabel.TextColor3 = Color3.new(1, 0.95, 1)
                nameLabel.Font = Enum.Font.GothamBold
                nameLabel.TextSize = 12
                nameLabel.TextXAlignment = Enum.TextXAlignment.Left
                nameLabel.Parent = entry
                
                -- Team label
                local teamName = "No Team"
                pcall(function()
                    if player.Team then
                        teamName = player.Team.Name
                    end
                end)
                
                local teamLabel = Instance.new("TextLabel")
                teamLabel.Size = UDim2.new(1, -45, 0.5, 0)
                teamLabel.Position = UDim2.new(0, 8, 0, 22)
                teamLabel.BackgroundTransparency = 1
                teamLabel.Text = teamName
                teamLabel.TextColor3 = Color3.new(0.7, 0.6, 0.8)
                teamLabel.Font = Enum.Font.Gotham
                teamLabel.TextSize = 10
                teamLabel.TextXAlignment = Enum.TextXAlignment.Left
                teamLabel.Parent = entry
                
                -- Checkbox frame
                local checkBox = Instance.new("Frame")
                checkBox.Size = UDim2.new(0, 22, 0, 22)
                checkBox.Position = UDim2.new(1, -30, 0.5, -11)
                checkBox.BackgroundColor3 = Color3.new(0.25, 0.18, 0.3)
                checkBox.BorderSizePixel = 0
                checkBox.Parent = entry
                
                local checkCorner = Instance.new("UICorner")
                checkCorner.CornerRadius = UDim.new(0, 4)
                checkCorner.Parent = checkBox
                
                -- Checkmark
                local checkMark = Instance.new("TextLabel")
                checkMark.Size = UDim2.new(1, 0, 1, 0)
                checkMark.BackgroundTransparency = 1
                checkMark.Text = "✓"
                checkMark.TextColor3 = Color3.new(0.9, 0.7, 0.35)
                checkMark.TextSize = 16
                checkMark.Font = Enum.Font.GothamBold
                checkMark.Visible = SelectedTargets[player.Name] ~= nil
                checkMark.Parent = checkBox
                
                -- Click area
                local clickArea = Instance.new("TextButton")
                clickArea.Size = UDim2.new(1, 0, 1, 0)
                clickArea.BackgroundTransparency = 1
                clickArea.Text = ""
                clickArea.Parent = entry
                
                clickArea.MouseButton1Click:Connect(function()
                    if SelectedTargets[player.Name] then
                        SelectedTargets[player.Name] = nil
                        checkMark.Visible = false
                    else
                        SelectedTargets[player.Name] = player
                        checkMark.Visible = true
                    end
                    UpdateStatus()
                end)
                
                yPos = yPos + 48
            end
        end
        
        ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, yPos + 5)
    end)
end

-- Select/Deselect all
local function ToggleAllPlayers(select)
    pcall(function()
        for _, child in ipairs(ScrollFrame:GetChildren()) do
            if child:IsA("Frame") then
                local nameLabel = child:FindFirstChild("TextLabel")
                if nameLabel then
                    local player = Players:FindFirstChild(nameLabel.Text)
                    if player and IsValidTarget(player) then
                        local checkBox = child:FindFirstChild("Frame")
                        local checkMark = checkBox and checkBox:FindFirstChild("TextLabel")
                        
                        if select then
                            SelectedTargets[player.Name] = player
                            if checkMark then checkMark.Visible = true end
                        else
                            SelectedTargets[player.Name] = nil
                            if checkMark then checkMark.Visible = false end
                        end
                    end
                end
            end
        end
        UpdateStatus()
    end)
end

-- Fling function
local function FlingTarget(target)
    pcall(function()
        local character = Player.Character
        if not character then return end
        
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid then return end
        
        local rootPart = humanoid.RootPart
        if not rootPart then return end
        
        local targetChar = target.Character
        if not targetChar then return end
        
        local targetHumanoid = targetChar:FindFirstChild("Humanoid")
        if not targetHumanoid then return end
        
        local targetRoot = targetHumanoid.RootPart
        if not targetRoot then return end
        
        -- Store original position
        local originalPos = rootPart.CFrame
        
        -- Create body velocity
        local bodyVel = Instance.new("BodyVelocity")
        bodyVel.Velocity = Vector3.new(99999999, 199999998, 99999999)
        bodyVel.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        bodyVel.Parent = rootPart
        
        -- Disable sitting
        humanoid.Sit = false
        
        -- Fling loop
        for i = 1, 15 do
            if not IsFlinging then break end
            if not rootPart.Parent or not targetRoot.Parent then break end
            
            rootPart.CFrame = targetRoot.CFrame * CFrame.new(0, 2, 0)
            pcall(function()
                character:SetPrimaryPartCFrame(rootPart.CFrame)
            end)
            
            task.wait(0.05)
        end
        
        -- Cleanup
        bodyVel:Destroy()
        
        -- Return to original position
        for i = 1, 8 do
            rootPart.CFrame = originalPos * CFrame.new(0, 0.5, 0)
            pcall(function()
                character:SetPrimaryPartCFrame(rootPart.CFrame)
            end)
            task.wait(0.05)
        end
    end)
end

-- Start flinging
local function StartFling()
    if IsFlinging then return end
    
    local count = 0
    for _ in pairs(SelectedTargets) do
        count = count + 1
    end
    
    if count == 0 then
        Notify("MoonWare", "No targets selected")
        return
    end
    
    IsFlinging = true
    UpdateStatus()
    Notify("MoonWare", "Flinging " .. count .. " targets")
    
    FlingCoroutine = coroutine.create(function()
        while IsFlinging do
            local targets = {}
            for name, player in pairs(SelectedTargets) do
                if player and player.Character then
                    table.insert(targets, player)
                else
                    SelectedTargets[name] = nil
                end
            end
            
            for _, player in ipairs(targets) do
                if not IsFlinging then break end
                FlingTarget(player)
                task.wait(0.1)
            end
            
            UpdateStatus()
            task.wait(0.3)
        end
    end)
    
    coroutine.resume(FlingCoroutine)
end

local function StopFling()
    if not IsFlinging then return end
    IsFlinging = false
    FlingCoroutine = nil
    UpdateStatus()
    Notify("MoonWare", "Fling stopped")
end

if StartButton then
    StartButton.MouseButton1Click:Connect(StartFling)
end

if StopButton then
    StopButton.MouseButton1Click:Connect(StopFling)
end

if SelectAllBtn then
    SelectAllBtn.MouseButton1Click:Connect(function() ToggleAllPlayers(true) end)
end

if DeselectAllBtn then
    DeselectAllBtn.MouseButton1Click:Connect(function() ToggleAllPlayers(false) end)
end

if CloseButton then
    CloseButton.MouseButton1Click:Connect(function()
        StopFling()
        if ScreenGui then
            ScreenGui:Destroy()
        end
    end)
end

Players.PlayerAdded:Connect(RefreshPlayerList)
Players.PlayerRemoving:Connect(RefreshPlayerList)

RefreshPlayerList()
UpdateStatus()
Notify("MoonWare", "Loaded successfully")