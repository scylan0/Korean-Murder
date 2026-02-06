--[[
    MouseMoveRel Utility Tool
    마우스 상대 이동 유틸리티
    
    기능:
    - 가장 가까운 플레이어 방향으로 마우스 이동 (Aim Assist)
    - 감도(Sensitivity) 조절
    - FOV(시야각) 원 표시
    - 토글 키 설정
    
    익스플로잇 환경 전용 (mousemoverel 필요)
]]

-- 환경 확인
assert(mousemoverel, "mousemoverel is not available. Use a supported executor.")

-- 중복 실행 방지
if shared.__MouseMoveTool then
    shared.__MouseMoveTool:Destroy()
    shared.__MouseMoveTool = nil
    task.wait(0.3)
end

-- 서비스
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- 설정
local Config = {
    Enabled = false,
    Smoothness = 5,         -- 1(빠름) ~ 20(느림)
    FOV = 120,              -- 시야각 (픽셀)
    ShowFOV = true,         -- FOV 원 표시
    TeamCheck = false,      -- 같은 팀 무시
    ToggleKey = Enum.KeyCode.RightAlt,  -- 토글 키
    TargetPart = "Head",    -- 타겟 부위
}

------------------------------------------------------
-- UI 생성
------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MouseMoveRelTool"
ScreenGui.DisplayOrder = 999999
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true

-- 숨겨진 UI 또는 CoreGui에 배치
pcall(function()
    if gethui then
        ScreenGui.Parent = gethui()
    elseif syn and syn.protect_gui then
        syn.protect_gui(ScreenGui)
        ScreenGui.Parent = game:GetService("CoreGui")
    else
        ScreenGui.Parent = game:GetService("CoreGui")
    end
end)

shared.__MouseMoveTool = ScreenGui

-- 색상 팔레트
local Colors = {
    bg       = Color3.fromRGB(20, 20, 26),
    card     = Color3.fromRGB(28, 28, 36),
    accent   = Color3.fromRGB(100, 180, 255),
    accentOn = Color3.fromRGB(80, 220, 130),
    accentOff= Color3.fromRGB(220, 80, 80),
    text     = Color3.fromRGB(220, 220, 230),
    subtext  = Color3.fromRGB(140, 140, 155),
    border   = Color3.fromRGB(45, 45, 55),
    slider   = Color3.fromRGB(50, 50, 65),
}

------------------------------------------------------
-- FOV 원 (화면 중앙)
------------------------------------------------------
local FOVCircle = Instance.new("Frame", ScreenGui)
FOVCircle.Name = "FOVCircle"
FOVCircle.AnchorPoint = Vector2.new(0.5, 0.5)
FOVCircle.BackgroundTransparency = 1
FOVCircle.Size = UDim2.new(0, Config.FOV * 2, 0, Config.FOV * 2)
FOVCircle.Position = UDim2.new(0.5, 0, 0.5, 0)

local FOVStroke = Instance.new("UIStroke", FOVCircle)
FOVStroke.Color = Colors.accent
FOVStroke.Thickness = 1
FOVStroke.Transparency = 0.6

local FOVCorner = Instance.new("UICorner", FOVCircle)
FOVCorner.CornerRadius = UDim.new(1, 0)

------------------------------------------------------
-- 메인 패널
------------------------------------------------------
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Name = "MainPanel"
MainFrame.AnchorPoint = Vector2.new(0, 0)
MainFrame.Position = UDim2.new(0, 20, 0, 20)
MainFrame.Size = UDim2.new(0, 260, 0, 360)
MainFrame.BackgroundColor3 = Colors.bg
MainFrame.BorderSizePixel = 0

local MainCorner = Instance.new("UICorner", MainFrame)
MainCorner.CornerRadius = UDim.new(0, 12)

local MainBorder = Instance.new("UIStroke", MainFrame)
MainBorder.Color = Colors.border
MainBorder.Thickness = 1
MainBorder.Transparency = 0.3

-- 그림자
local Shadow = Instance.new("ImageLabel", MainFrame)
Shadow.ZIndex = 0
Shadow.BorderSizePixel = 0
Shadow.BackgroundTransparency = 1
Shadow.Image = "rbxassetid://6014261993"
Shadow.ScaleType = Enum.ScaleType.Slice
Shadow.SliceCenter = Rect.new(49, 49, 450, 450)
Shadow.ImageTransparency = 0.5
Shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
Shadow.AnchorPoint = Vector2.new(0.5, 0.5)
Shadow.Size = UDim2.new(1, 30, 1, 30)
Shadow.Position = UDim2.new(0.5, 0, 0.5, 0)

------------------------------------------------------
-- 타이틀 바
------------------------------------------------------
local TitleBar = Instance.new("Frame", MainFrame)
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 42)
TitleBar.BackgroundColor3 = Colors.card
TitleBar.BorderSizePixel = 0

local TitleCorner = Instance.new("UICorner", TitleBar)
TitleCorner.CornerRadius = UDim.new(0, 12)

-- 하단 코너 채우기
local TitleFill = Instance.new("Frame", TitleBar)
TitleFill.Size = UDim2.new(1, 0, 0, 12)
TitleFill.Position = UDim2.new(0, 0, 1, -12)
TitleFill.BackgroundColor3 = Colors.card
TitleFill.BorderSizePixel = 0

local TitleLabel = Instance.new("TextLabel", TitleBar)
TitleLabel.Size = UDim2.new(1, -16, 1, 0)
TitleLabel.Position = UDim2.new(0, 16, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "Mouse Utility"
TitleLabel.TextColor3 = Colors.text
TitleLabel.TextSize = 16
TitleLabel.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Bold)
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

local VersionLabel = Instance.new("TextLabel", TitleBar)
VersionLabel.Size = UDim2.new(0, 50, 1, 0)
VersionLabel.Position = UDim2.new(1, -60, 0, 0)
VersionLabel.BackgroundTransparency = 1
VersionLabel.Text = "v1.0"
VersionLabel.TextColor3 = Colors.subtext
VersionLabel.TextSize = 11
VersionLabel.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Regular)
VersionLabel.TextXAlignment = Enum.TextXAlignment.Right

------------------------------------------------------
-- 헬퍼: UI 요소 생성 함수들
------------------------------------------------------
local ContentFrame = Instance.new("ScrollingFrame", MainFrame)
ContentFrame.Name = "Content"
ContentFrame.Size = UDim2.new(1, -24, 1, -52)
ContentFrame.Position = UDim2.new(0, 12, 0, 48)
ContentFrame.BackgroundTransparency = 1
ContentFrame.BorderSizePixel = 0
ContentFrame.ScrollBarThickness = 3
ContentFrame.ScrollBarImageColor3 = Colors.accent
ContentFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
ContentFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y

local ContentLayout = Instance.new("UIListLayout", ContentFrame)
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Padding = UDim.new(0, 8)

local function createCard(parent, height)
    local card = Instance.new("Frame", parent)
    card.Size = UDim2.new(1, 0, 0, height or 44)
    card.BackgroundColor3 = Colors.card
    card.BorderSizePixel = 0
    local corner = Instance.new("UICorner", card)
    corner.CornerRadius = UDim.new(0, 8)
    return card
end

local function createToggle(parent, label, default, callback)
    local card = createCard(parent, 44)
    
    local lbl = Instance.new("TextLabel", card)
    lbl.Size = UDim2.new(1, -70, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Colors.text
    lbl.TextSize = 13
    lbl.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Medium)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    
    local togBg = Instance.new("Frame", card)
    togBg.Size = UDim2.new(0, 42, 0, 22)
    togBg.Position = UDim2.new(1, -56, 0.5, -11)
    togBg.BackgroundColor3 = default and Colors.accentOn or Colors.accentOff
    togBg.BorderSizePixel = 0
    local togCorner = Instance.new("UICorner", togBg)
    togCorner.CornerRadius = UDim.new(1, 0)
    
    local togCircle = Instance.new("Frame", togBg)
    togCircle.Size = UDim2.new(0, 18, 0, 18)
    togCircle.Position = default and UDim2.new(1, -20, 0, 2) or UDim2.new(0, 2, 0, 2)
    togCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    togCircle.BorderSizePixel = 0
    local circCorner = Instance.new("UICorner", togCircle)
    circCorner.CornerRadius = UDim.new(1, 0)
    
    local state = default
    local btn = Instance.new("TextButton", card)
    btn.Size = UDim2.new(1, 0, 1, 0)
    btn.BackgroundTransparency = 1
    btn.Text = ""
    btn.ZIndex = 5
    
    btn.MouseButton1Click:Connect(function()
        state = not state
        TweenService:Create(togBg, TweenInfo.new(0.2), {
            BackgroundColor3 = state and Colors.accentOn or Colors.accentOff
        }):Play()
        TweenService:Create(togCircle, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = state and UDim2.new(1, -20, 0, 2) or UDim2.new(0, 2, 0, 2)
        }):Play()
        callback(state)
    end)
    
    return card
end

local function createSlider(parent, label, min, max, default, callback)
    local card = createCard(parent, 60)
    
    local lbl = Instance.new("TextLabel", card)
    lbl.Size = UDim2.new(1, -60, 0, 24)
    lbl.Position = UDim2.new(0, 14, 0, 4)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Colors.text
    lbl.TextSize = 13
    lbl.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Medium)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    
    local valLabel = Instance.new("TextLabel", card)
    valLabel.Size = UDim2.new(0, 40, 0, 24)
    valLabel.Position = UDim2.new(1, -54, 0, 4)
    valLabel.BackgroundTransparency = 1
    valLabel.Text = tostring(default)
    valLabel.TextColor3 = Colors.accent
    valLabel.TextSize = 13
    valLabel.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Bold)
    valLabel.TextXAlignment = Enum.TextXAlignment.Right
    
    local sliderBg = Instance.new("Frame", card)
    sliderBg.Size = UDim2.new(1, -28, 0, 6)
    sliderBg.Position = UDim2.new(0, 14, 0, 38)
    sliderBg.BackgroundColor3 = Colors.slider
    sliderBg.BorderSizePixel = 0
    local sliderCorner = Instance.new("UICorner", sliderBg)
    sliderCorner.CornerRadius = UDim.new(1, 0)
    
    local sliderFill = Instance.new("Frame", sliderBg)
    local pct = (default - min) / (max - min)
    sliderFill.Size = UDim2.new(pct, 0, 1, 0)
    sliderFill.BackgroundColor3 = Colors.accent
    sliderFill.BorderSizePixel = 0
    local fillCorner = Instance.new("UICorner", sliderFill)
    fillCorner.CornerRadius = UDim.new(1, 0)
    
    local knob = Instance.new("Frame", sliderBg)
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(pct, -7, 0.5, -7)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.BorderSizePixel = 0
    knob.ZIndex = 3
    local knobCorner = Instance.new("UICorner", knob)
    knobCorner.CornerRadius = UDim.new(1, 0)
    
    local dragging = false
    local inputBtn = Instance.new("TextButton", sliderBg)
    inputBtn.Size = UDim2.new(1, 10, 0, 20)
    inputBtn.Position = UDim2.new(0, -5, 0.5, -10)
    inputBtn.BackgroundTransparency = 1
    inputBtn.Text = ""
    inputBtn.ZIndex = 5
    
    local function update(input)
        local relX = (input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X
        relX = math.clamp(relX, 0, 1)
        local value = math.floor(min + (max - min) * relX)
        sliderFill.Size = UDim2.new(relX, 0, 1, 0)
        knob.Position = UDim2.new(relX, -7, 0.5, -7)
        valLabel.Text = tostring(value)
        callback(value)
    end
    
    inputBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            update(input)
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    return card
end

local function createDropdown(parent, label, options, default, callback)
    local card = createCard(parent, 44)
    
    local lbl = Instance.new("TextLabel", card)
    lbl.Size = UDim2.new(0.5, 0, 1, 0)
    lbl.Position = UDim2.new(0, 14, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = label
    lbl.TextColor3 = Colors.text
    lbl.TextSize = 13
    lbl.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Medium)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    
    local currentIndex = table.find(options, default) or 1
    
    local valBtn = Instance.new("TextButton", card)
    valBtn.Size = UDim2.new(0, 100, 0, 28)
    valBtn.Position = UDim2.new(1, -114, 0.5, -14)
    valBtn.BackgroundColor3 = Colors.slider
    valBtn.BorderSizePixel = 0
    valBtn.Text = "  " .. options[currentIndex] .. "  "
    valBtn.TextColor3 = Colors.accent
    valBtn.TextSize = 12
    valBtn.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Medium)
    local valCorner = Instance.new("UICorner", valBtn)
    valCorner.CornerRadius = UDim.new(0, 6)
    
    valBtn.MouseButton1Click:Connect(function()
        currentIndex = (currentIndex % #options) + 1
        valBtn.Text = "  " .. options[currentIndex] .. "  "
        callback(options[currentIndex])
    end)
    
    return card
end

local function createLabel(parent, text)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size = UDim2.new(1, 0, 0, 20)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Colors.subtext
    lbl.TextSize = 11
    lbl.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Regular)
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    return lbl
end

------------------------------------------------------
-- UI 요소 배치
------------------------------------------------------

-- 상태 표시
local statusCard = createCard(ContentFrame, 36)
local statusDot = Instance.new("Frame", statusCard)
statusDot.Size = UDim2.new(0, 8, 0, 8)
statusDot.Position = UDim2.new(0, 14, 0.5, -4)
statusDot.BackgroundColor3 = Colors.accentOff
statusDot.BorderSizePixel = 0
local dotCorner = Instance.new("UICorner", statusDot)
dotCorner.CornerRadius = UDim.new(1, 0)

local statusLabel = Instance.new("TextLabel", statusCard)
statusLabel.Size = UDim2.new(1, -32, 1, 0)
statusLabel.Position = UDim2.new(0, 28, 0, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "OFF  |  RightAlt to toggle"
statusLabel.TextColor3 = Colors.subtext
statusLabel.TextSize = 12
statusLabel.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Regular)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left

-- 메인 토글
createToggle(ContentFrame, "Aim Assist", Config.Enabled, function(state)
    Config.Enabled = state
    statusDot.BackgroundColor3 = state and Colors.accentOn or Colors.accentOff
    statusLabel.Text = state and "ON  |  Active" or "OFF  |  RightAlt to toggle"
    FOVStroke.Color = state and Colors.accentOn or Colors.accent
end)

-- FOV 표시 토글
createToggle(ContentFrame, "Show FOV Circle", Config.ShowFOV, function(state)
    Config.ShowFOV = state
    FOVCircle.Visible = state
end)

-- 팀 체크 토글
createToggle(ContentFrame, "Team Check", Config.TeamCheck, function(state)
    Config.TeamCheck = state
end)

createLabel(ContentFrame, "  SETTINGS")

-- 감도 슬라이더
createSlider(ContentFrame, "Smoothness", 1, 20, Config.Smoothness, function(val)
    Config.Smoothness = val
end)

-- FOV 슬라이더
createSlider(ContentFrame, "FOV Radius", 30, 400, Config.FOV, function(val)
    Config.FOV = val
    FOVCircle.Size = UDim2.new(0, val * 2, 0, val * 2)
end)

-- 타겟 부위 선택
createDropdown(ContentFrame, "Target Part", {"Head", "HumanoidRootPart", "UpperTorso"}, Config.TargetPart, function(val)
    Config.TargetPart = val
end)

createLabel(ContentFrame, "  INFO")

-- 정보 카드
local infoCard = createCard(ContentFrame, 50)
local targetInfoLabel = Instance.new("TextLabel", infoCard)
targetInfoLabel.Size = UDim2.new(1, -28, 1, 0)
targetInfoLabel.Position = UDim2.new(0, 14, 0, 0)
targetInfoLabel.BackgroundTransparency = 1
targetInfoLabel.Text = "Target: None\nDistance: -"
targetInfoLabel.TextColor3 = Colors.subtext
targetInfoLabel.TextSize = 11
targetInfoLabel.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Regular)
targetInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
targetInfoLabel.TextYAlignment = Enum.TextYAlignment.Center
targetInfoLabel.LineHeight = 1.4

------------------------------------------------------
-- 드래그 기능
------------------------------------------------------
local dragToggle, dragStart, startPos = false, nil, nil

TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragToggle = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragToggle and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragToggle = false
    end
end)

------------------------------------------------------
-- 토글 키
------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Config.ToggleKey then
        Config.Enabled = not Config.Enabled
        statusDot.BackgroundColor3 = Config.Enabled and Colors.accentOn or Colors.accentOff
        statusLabel.Text = Config.Enabled and "ON  |  Active" or "OFF  |  RightAlt to toggle"
        FOVStroke.Color = Config.Enabled and Colors.accentOn or Colors.accent
    end
    -- UI 표시/숨김 (Insert 키)
    if input.KeyCode == Enum.KeyCode.Insert then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

------------------------------------------------------
-- 핵심 기능: 가장 가까운 플레이어 찾기 + mousemoverel
------------------------------------------------------

local function getClosestPlayer()
    local closest = nil
    local closestDist = Config.FOV
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not player.Character then continue end
        
        -- 팀 체크
        if Config.TeamCheck and player.Team and player.Team == LocalPlayer.Team then
            continue
        end
        
        local character = player.Character
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        
        local targetPart = character:FindFirstChild(Config.TargetPart) or character:FindFirstChild("Head")
        if not targetPart then continue end
        
        local screenPos, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
        if not onScreen then continue end
        
        local screenVec = Vector2.new(screenPos.X, screenPos.Y)
        local dist = (screenVec - screenCenter).Magnitude
        
        if dist < closestDist then
            closestDist = dist
            closest = {
                Player = player,
                Part = targetPart,
                ScreenPos = screenVec,
                Distance = dist,
            }
        end
    end
    
    return closest
end

-- 메인 루프
local connection
connection = RunService.RenderStepped:Connect(function()
    if not ScreenGui.Parent then
        connection:Disconnect()
        return
    end
    
    -- FOV 원 업데이트
    FOVCircle.Visible = Config.ShowFOV
    
    if not Config.Enabled then
        targetInfoLabel.Text = "Target: None\nDistance: -"
        return
    end
    
    -- 마우스 버튼이 눌려있을 때만 작동 (안전장치)
    if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        targetInfoLabel.Text = "Target: Waiting (Hold RMB)\nDistance: -"
        return
    end
    
    local target = getClosestPlayer()
    
    if not target then
        targetInfoLabel.Text = "Target: None in FOV\nDistance: -"
        return
    end
    
    -- 정보 업데이트
    local dist3D = (target.Part.Position - Camera.CFrame.Position).Magnitude
    targetInfoLabel.Text = string.format("Target: %s\nDistance: %.1f studs", target.Player.Name, dist3D)
    
    -- mousemoverel로 마우스 이동
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    local delta = target.ScreenPos - screenCenter
    
    -- 감도 적용 (Smoothness가 높을수록 느리게)
    local moveX = delta.X / Config.Smoothness
    local moveY = delta.Y / Config.Smoothness
    
    -- 최소 이동량 제한 (떨림 방지)
    if math.abs(moveX) < 0.5 and math.abs(moveY) < 0.5 then
        return
    end
    
    mousemoverel(math.floor(moveX), math.floor(moveY))
end)

------------------------------------------------------
-- 정리
------------------------------------------------------
ScreenGui.Destroying:Connect(function()
    if connection then
        connection:Disconnect()
    end
end)

print("[MouseMoveTool] Loaded successfully!")
print("[MouseMoveTool] RightAlt = Toggle Aim | Insert = Toggle UI | RMB = Activate")
