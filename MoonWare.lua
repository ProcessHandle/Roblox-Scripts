local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Player = Players.LocalPlayer
assert(Player, "Failed to get LocalPlayer")

local CONFIG = {
    FLING_POWER = 9e7,
    ROTATION_POWER = 9e8,
    FLING_DURATION = 1.5,
    UPDATE_INTERVAL = 0.1,
    SAFE_MODE = true
}

local function Notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 3
        })
    end)
end

local function safeCreate(class, parent, properties)
    local instance = Instance.new(class)
    for prop, value in pairs(properties or {}) do
        pcall(function()
            instance[prop] = value
        end)
    end
    if parent then
        instance.Parent = parent
    end
    return instance
end

local function addCorner(instance, radius)
    pcall(function()
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0, radius)
        corner.Parent = instance
    end)
end

local function addStroke(instance, color, thickness, transparency)
    pcall(function()
        local stroke = Instance.new("UIStroke")
        stroke.Color = color
        stroke.Thickness = thickness
        stroke.Transparency = transparency or 0
        stroke.Parent = instance
    end)
end

local ScreenGui = safeCreate("ScreenGui", CoreGui, {
    Name = "aask2gfa12sdasdk12r12dak12j2kal2m9fs74k12sfbn46z",
    ResetOnSpawn = false
})

if not ScreenGui then
    Notify("MoonWare Error", "Failed to create GUI", 5)
    return
end

local MainFrame = safeCreate("Frame", ScreenGui, {
    Size = UDim2.new(0, 380, 0, 520),
    Position = UDim2.new(0.5, -190, 0.5, -260),
    BackgroundColor3 = Color3.fromRGB(20, 15, 25),
    BackgroundTransparency = 0.05,
    BorderSizePixel = 0,
    ClipsDescendants = true,
    Active = true,
    Draggable = true
})

addCorner(MainFrame, 12)
addStroke(MainFrame, Color3.fromRGB(200, 160, 80), 1, 0.3)

local dragStart, startPos
MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement and dragStart then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragStart = nil
    end
end)

local TitleBar = safeCreate("Frame", MainFrame, {
    Size = UDim2.new(1, 0, 0, 50),
    BackgroundColor3 = Color3.fromRGB(30, 20, 40),
    BackgroundTransparency = 0.3,
    BorderSizePixel = 0
})

addCorner(TitleBar, 12)

local Title = safeCreate("TextLabel", TitleBar, {
    Size = UDim2.new(1, -50, 1, 0),
    Position = UDim2.new(0, 15, 0, 0),
    BackgroundTransparency = 1,
    Text = "🌙 MoonWare",
    TextColor3 = Color3.fromRGB(230, 190, 100),
    Font = Enum.Font.GothamBold,
    TextSize = 22,
    TextXAlignment = Enum.TextXAlignment.Left
})

local Subtitle = safeCreate("TextLabel", TitleBar, {
    Size = UDim2.new(1, -50, 1, 0),
    Position = UDim2.new(0, 15, 0, 28),
    BackgroundTransparency = 1,
    Text = "multi-target fling",
    TextColor3 = Color3.fromRGB(180, 150, 220),
    Font = Enum.Font.Gotham,
    TextSize = 12,
    TextXAlignment = Enum.TextXAlignment.Left
})

local CloseButton = safeCreate("TextButton", TitleBar, {
    Position = UDim2.new(1, -40, 0, 0),
    Size = UDim2.new(0, 40, 0, 50),
    BackgroundTransparency = 1,
    Text = "✕",
    TextColor3 = Color3.fromRGB(200, 160, 100),
    Font = Enum.Font.GothamBold,
    TextSize = 20
})

local StatusCard = safeCreate("Frame", MainFrame, {
    Position = UDim2.new(0, 15, 0, 65),
    Size = UDim2.new(1, -30, 0, 45),
    BackgroundColor3 = Color3.fromRGB(40, 30, 50),
    BackgroundTransparency = 0.5,
    BorderSizePixel = 0
})

addCorner(StatusCard, 8)

local StatusIcon = safeCreate("TextLabel", StatusCard, {
    Size = UDim2.new(0, 35, 1, 0),
    BackgroundTransparency = 1,
    Text = "🎯",
    TextColor3 = Color3.fromRGB(230, 190, 100),
    TextSize = 20,
    Font = Enum.Font.Gotham
})

local StatusLabel = safeCreate("TextLabel", StatusCard, {
    Position = UDim2.new(0, 40, 0, 0),
    Size = UDim2.new(1, -50, 1, 0),
    BackgroundTransparency = 1,
    Text = "0 targets selected",
    TextColor3 = Color3.fromRGB(220, 210, 240),
    Font = Enum.Font.Gotham,
    TextSize = 14,
    TextXAlignment = Enum.TextXAlignment.Left
})

local PlayerFrame = safeCreate("Frame", MainFrame, {
    Position = UDim2.new(0, 15, 0, 120),
    Size = UDim2.new(1, -30, 0, 280),
    BackgroundColor3 = Color3.fromRGB(30, 22, 38),
    BackgroundTransparency = 0.4,
    BorderSizePixel = 0
})

addCorner(PlayerFrame, 10)

local PlayerScroll = safeCreate("ScrollingFrame", PlayerFrame, {
    Position = UDim2.new(0, 5, 0, 5),
    Size = UDim2.new(1, -10, 1, -10),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = Color3.fromRGB(200, 160, 80),
    CanvasSize = UDim2.new(0, 0, 0, 0)
})

local ButtonFrame = safeCreate("Frame", MainFrame, {
    Position = UDim2.new(0, 15, 0, 410),
    Size = UDim2.new(1, -30, 0, 50),
    BackgroundTransparency = 1
})

local StartButton = safeCreate("TextButton", ButtonFrame, {
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(0.45, -5, 1, 0),
    BackgroundColor3 = Color3.fromRGB(80, 50, 120),
    BorderSizePixel = 0,
    Text = "🌙 START FLING",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 14
})

addCorner(StartButton, 8)

local StopButton = safeCreate("TextButton", ButtonFrame, {
    Position = UDim2.new(0.55, 5, 0, 0),
    Size = UDim2.new(0.45, -5, 1, 0),
    BackgroundColor3 = Color3.fromRGB(60, 45, 75),
    BorderSizePixel = 0,
    Text = "⏹ STOP FLING",
    TextColor3 = Color3.fromRGB(255, 255, 255),
    Font = Enum.Font.GothamBold,
    TextSize = 14
})

addCorner(StopButton, 8)

local ActionFrame = safeCreate("Frame", MainFrame, {
    Position = UDim2.new(0, 15, 0, 465),
    Size = UDim2.new(1, -30, 0, 25),
    BackgroundTransparency = 1
})

local SelectAllButton = safeCreate("TextButton", ActionFrame, {
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(0.45, -5, 1, 0),
    BackgroundTransparency = 1,
    Text = "SELECT ALL",
    TextColor3 = Color3.fromRGB(200, 160, 100),
    Font = Enum.Font.Gotham,
    TextSize = 12
})

local DeselectAllButton = safeCreate("TextButton", ActionFrame, {
    Position = UDim2.new(0.55, 5, 0, 0),
    Size = UDim2.new(0.45, -5, 1, 0),
    BackgroundTransparency = 1,
    Text = "DESELECT ALL",
    TextColor3 = Color3.fromRGB(200, 160, 100),
    Font = Enum.Font.Gotham,
    TextSize = 12
})

local SettingsFrame = safeCreate("Frame", MainFrame, {
    Position = UDim2.new(0, 15, 0, 495),
    Size = UDim2.new(1, -30, 0, 20),
    BackgroundTransparency = 1
})

local PowerLabel = safeCreate("TextLabel", SettingsFrame, {
    Position = UDim2.new(0, 0, 0, 0),
    Size = UDim2.new(0.3, 0, 1, 0),
    BackgroundTransparency = 1,
    Text = "Power: 9e7",
    TextColor3 = Color3.fromRGB(200, 160, 100),
    Font = Enum.Font.Gotham,
    TextSize = 10
})

local SelectedTargets = {}
local PlayerEntries = {}
local FlingActive = false
local FlingLoop = nil

local OriginalFPDH = workspace.FallenPartsDestroyHeight
local OriginalCameraSubject = nil

local function IsTargetValid(target)
    if not target or target == Player then return false end
    local success, character = pcall(function()
        return target.Character
    end)
    if not success or not character then return false end
    
    local success, humanoid = pcall(function()
        return character:FindFirstChildOfClass("Humanoid")
    end)
    if not success or not humanoid or humanoid.Health <= 0 then return false end
    
    -- Check if target is in Survivors team
    local success, team = pcall(function()
        return target.Team
    end)
    if success and team then
        return team.Name ~= "Survivors"
    end
    
    return true
end

local function GetPlayerThumbnail(player)
    local success, url = pcall(function()
        return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size60x60)
    end)
    if success and url then
        return url
    end
    return "rbxasset://textures/ui/GuiImagePlaceholder.png"
end

local function UpdateStatus()
    local count = 0
    for _ in pairs(SelectedTargets) do 
        count = count + 1 
    end
    pcall(function()
        if FlingActive then
            StatusLabel.Text = "✨ flinging " .. count .. " target(s)"
            StatusLabel.TextColor3 = Color3.fromRGB(230, 190, 100)
        else
            StatusLabel.Text = count .. " target(s) selected"
            StatusLabel.TextColor3 = Color3.fromRGB(220, 210, 240)
        end
    end)
end

local function RefreshPlayerList()
    pcall(function()
        for _, child in pairs(PlayerScroll:GetChildren()) do
            if child:IsA("Frame") then
                child:Destroy()
            end
        end
        PlayerEntries = {}
        
        local playerList = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if IsTargetValid(p) then
                table.insert(playerList, p)
            end
        end
        table.sort(playerList, function(a, b) 
            return a and b and a.Name:lower() < b.Name:lower() 
        end)
        
        local yPos = 5
        for _, targetPlayer in ipairs(playerList) do
            local entry = safeCreate("Frame", PlayerScroll, {
                Size = UDim2.new(1, -10, 0, 55),
                Position = UDim2.new(0, 5, 0, yPos),
                BackgroundColor3 = Color3.fromRGB(45, 35, 55),
                BackgroundTransparency = 0.3,
                BorderSizePixel = 0
            })
            
            addCorner(entry, 8)
            
            local thumbContainer = safeCreate("Frame", entry, {
                Size = UDim2.new(0, 40, 0, 40),
                Position = UDim2.new(0, 8, 0.5, -20),
                BackgroundColor3 = Color3.fromRGB(30, 22, 38),
                BorderSizePixel = 0
            })
            
            addCorner(thumbContainer, 20)
            
            local thumbnail = safeCreate("ImageLabel", thumbContainer, {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1
            })
            
            pcall(function()
                thumbnail.Image = GetPlayerThumbnail(targetPlayer)
            end)
            
            local nameLabel = safeCreate("TextLabel", entry, {
                Position = UDim2.new(0, 55, 0, 8),
                Size = UDim2.new(1, -130, 0, 22),
                BackgroundTransparency = 1,
                Text = targetPlayer.Name,
                TextColor3 = Color3.fromRGB(255, 245, 255),
                Font = Enum.Font.GothamBold,
                TextSize = 14,
                TextXAlignment = Enum.TextXAlignment.Left
            })
            
            local teamName = "No Team"
            pcall(function()
                if targetPlayer.Team then
                    teamName = targetPlayer.Team.Name
                end
            end)
            
            local teamLabel = safeCreate("TextLabel", entry, {
                Position = UDim2.new(0, 55, 0, 30),
                Size = UDim2.new(1, -130, 0, 18),
                BackgroundTransparency = 1,
                Text = teamName,
                TextColor3 = Color3.fromRGB(180, 160, 200),
                Font = Enum.Font.Gotham,
                TextSize = 11,
                TextXAlignment = Enum.TextXAlignment.Left
            })
            
            local checkBox = safeCreate("Frame", entry, {
                Position = UDim2.new(1, -45, 0.5, -15),
                Size = UDim2.new(0, 30, 0, 30),
                BackgroundColor3 = Color3.fromRGB(60, 45, 75),
                BorderSizePixel = 0
            })
            
            addCorner(checkBox, 8)
            
            local checkMark = safeCreate("TextLabel", checkBox, {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "✓",
                TextColor3 = Color3.fromRGB(230, 190, 100),
                TextSize = 20,
                Font = Enum.Font.GothamBold,
                Visible = SelectedTargets[targetPlayer.Name] ~= nil
            })
            
            local clickArea = safeCreate("TextButton", entry, {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = ""
            })
            
            clickArea.MouseButton1Click:Connect(function()
                if SelectedTargets[targetPlayer.Name] then
                    SelectedTargets[targetPlayer.Name] = nil
                    checkMark.Visible = false
                else
                    SelectedTargets[targetPlayer.Name] = targetPlayer
                    checkMark.Visible = true
                end
                UpdateStatus()
            end)
            
            PlayerEntries[targetPlayer.Name] = {
                Entry = entry,
                CheckMark = checkMark
            }
            
            yPos = yPos + 62
        end
        
        PlayerScroll.CanvasSize = UDim2.new(0, 0, 0, yPos + 5)
    end)
end

local function ToggleAllPlayers(select)
    pcall(function()
        for name, entry in pairs(PlayerEntries) do
            local player = Players:FindFirstChild(name)
            if player and IsTargetValid(player) then
                if select then
                    SelectedTargets[name] = player
                    entry.CheckMark.Visible = true
                else
                    SelectedTargets[name] = nil
                    entry.CheckMark.Visible = false
                end
            end
        end
        UpdateStatus()
    end)
end

local function FlingTarget(targetPlayer)
    return pcall(function()
        local character = Player.Character
        if not character then return false end
        
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then return false end
        
        local rootPart = humanoid.RootPart
        if not rootPart then return false end
        
        local targetChar = targetPlayer.Character
        if not targetChar then return false end
        
        local targetHumanoid = targetChar:FindFirstChildOfClass("Humanoid")
        if not targetHumanoid or targetHumanoid.Health <= 0 then return false end
        
        local targetRoot = targetHumanoid.RootPart
        if not targetRoot then return false end
        
        if not OriginalCameraSubject then
            OriginalCameraSubject = workspace.CurrentCamera.CameraSubject
        end
        
        workspace.CurrentCamera.CameraSubject = targetHumanoid
        
        local originalSeatState = humanoid.Sit
        humanoid.Sit = false
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, false)
        
        local originalPos = rootPart.CFrame
        
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.Velocity = Vector3.new(CONFIG.FLING_POWER, CONFIG.FLING_POWER * 2, CONFIG.FLING_POWER)
        bodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
        bodyVelocity.Parent = rootPart
        
        local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
        bodyAngularVelocity.AngularVelocity = Vector3.new(CONFIG.ROTATION_POWER, CONFIG.ROTATION_POWER, CONFIG.ROTATION_POWER)
        bodyAngularVelocity.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
        bodyAngularVelocity.Parent = rootPart
        
        local attachment = Instance.new("Attachment")
        attachment.Parent = targetRoot
        
        local alignPosition = Instance.new("AlignPosition")
        alignPosition.Parent = rootPart
        alignPosition.Attachment0 = rootPart:FindFirstChildOfClass("Attachment") or Instance.new("Attachment", rootPart)
        alignPosition.Attachment1 = attachment
        alignPosition.RigidityEnabled = true
        alignPosition.MaxForce = 9e9
        alignPosition.MaxVelocity = 9e9
        
        local startTime = tick()
        local angle = 0
        
        while FlingActive and tick() - startTime < CONFIG.FLING_DURATION do
            if not rootPart.Parent or not targetRoot.Parent then break end
            
            angle = angle + 100
            
            rootPart.CFrame = targetRoot.CFrame * CFrame.new(0, 1.5, 0) * CFrame.Angles(math.rad(angle), 0, 0)
            character:SetPrimaryPartCFrame(rootPart.CFrame)
            
            bodyVelocity.Velocity = Vector3.new(CONFIG.FLING_POWER, CONFIG.FLING_POWER * 2, CONFIG.FLING_POWER)
            bodyAngularVelocity.AngularVelocity = Vector3.new(CONFIG.ROTATION_POWER, CONFIG.ROTATION_POWER, CONFIG.ROTATION_POWER)
            
            task.wait()
        end
        
        alignPosition:Destroy()
        attachment:Destroy()
        bodyVelocity:Destroy()
        bodyAngularVelocity:Destroy()
        
        humanoid.Sit = originalSeatState
        humanoid:SetStateEnabled(Enum.HumanoidStateType.Seated, true)
        
        local returnTime = tick()
        while tick() - returnTime < 0.5 do
            rootPart.CFrame = originalPos * CFrame.new(0, 0.5, 0)
            character:SetPrimaryPartCFrame(rootPart.CFrame)
            humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            task.wait()
        end
        
        if OriginalCameraSubject then
            workspace.CurrentCamera.CameraSubject = OriginalCameraSubject
        end
        
        return true
    end)
end

local function StartFling()
    if FlingActive then 
        Notify("MoonWare", "Fling already active!", 2)
        return 
    end
    
    local count = 0
    for _ in pairs(SelectedTargets) do 
        count = count + 1 
    end
    
    if count == 0 then
        StatusLabel.Text = "⚠ no targets selected"
        task.wait(1.5)
        UpdateStatus()
        Notify("MoonWare", "Please select at least one target", 2)
        return
    end
    
    FlingActive = true
    UpdateStatus()
    Notify("MoonWare", "🌙 Flinging " .. count .. " targets", 2)
    
    if CONFIG.SAFE_MODE then
        OriginalFPDH = workspace.FallenPartsDestroyHeight
        workspace.FallenPartsDestroyHeight = -9e9
    end
    
    FlingLoop = task.spawn(function()
        while FlingActive do
            local targets = {}
            for name, player in pairs(SelectedTargets) do
                if player and player.Parent and IsTargetValid(player) then
                    table.insert(targets, player)
                else
                    SelectedTargets[name] = nil
                end
            end
            
            for _, target in ipairs(targets) do
                if not FlingActive then break end
                
                local success = FlingTarget(target)
                if not success then
                    SelectedTargets[target.Name] = nil
                    RefreshPlayerList()
                end
                
                task.wait(CONFIG.UPDATE_INTERVAL)
            end
            
            UpdateStatus()
            task.wait(0.3)
        end
    end)
end

local function StopFling()
    if not FlingActive then return end
    
    FlingActive = false
    if FlingLoop then
        task.cancel(FlingLoop)
        FlingLoop = nil
    end
    
    -- Restore FallenPartsDestroyHeight
    if CONFIG.SAFE_MODE and OriginalFPDH then
        workspace.FallenPartsDestroyHeight = OriginalFPDH
    end
    
    -- Restore camera
    if OriginalCameraSubject then
        workspace.CurrentCamera.CameraSubject = OriginalCameraSubject
        OriginalCameraSubject = nil
    end
    
    UpdateStatus()
    Notify("MoonWare", "⏹ Fling stopped", 2)
end

local function addHoverEffect(button, color1, color2)
    button.MouseEnter:Connect(function()
        pcall(function()
            TweenService:Create(button, TweenInfo.new(0.2), {
                BackgroundColor3 = color2 or Color3.fromRGB(100, 70, 140)
            }):Play()
        end)
    end)
    
    button.MouseLeave:Connect(function()
        pcall(function()
            TweenService:Create(button, TweenInfo.new(0.2), {
                BackgroundColor3 = color1
            }):Play()
        end)
    end)
end

addHoverEffect(StartButton, Color3.fromRGB(80, 50, 120), Color3.fromRGB(100, 70, 140))
addHoverEffect(StopButton, Color3.fromRGB(60, 45, 75), Color3.fromRGB(80, 60, 100))

StartButton.MouseButton1Click:Connect(StartFling)
StopButton.MouseButton1Click:Connect(StopFling)
SelectAllButton.MouseButton1Click:Connect(function() ToggleAllPlayers(true) end)
DeselectAllButton.MouseButton1Click:Connect(function() ToggleAllPlayers(false) end)
CloseButton.MouseButton1Click:Connect(function()
    StopFling()
    ScreenGui:Destroy()
end)

Players.PlayerAdded:Connect(RefreshPlayerList)
Players.PlayerRemoving:Connect(RefreshPlayerList)

Players.PlayerAdded:Connect(function(p)
    pcall(function()
        p:WaitForChild("Team")
        RefreshPlayerList()
    end)
end)

game:GetService("Players").LocalPlayer.CharacterAdded:Connect(function()
    if FlingActive then
        StopFling()
    end
end)

-- Init
RefreshPlayerList()
UpdateStatus()
Notify("MoonWare", "🌙 Loaded • Survivors excluded", 3)
