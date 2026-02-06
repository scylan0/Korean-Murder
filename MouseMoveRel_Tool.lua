--[[
    MouseMoveRel Tool - Roblox Executor Script
    마우스 상대 이동(mousemoverel) 기반 유틸리티
    
    기능:
    - 마우스 자동 이동 (방향/속도 조절)
    - 원형/사각형/랜덤 패턴 이동
    - 커스텀 오프셋 이동
    - 키바인드 토글
    
    사용법: 익스큐터에서 실행
]]

-- 환경 검증
assert(mousemoverel, "[MouseMoveRel Tool] mousemoverel 함수를 찾을 수 없습니다. 익스플로잇 환경에서 실행하세요.")

-- 중복 실행 방지
if shared._MouseMoveRelTool then
    if shared._MouseMoveRelTool.Destroy then
        shared._MouseMoveRelTool:Destroy()
    end
end

------------------------------------------------------------------------
-- Services
------------------------------------------------------------------------
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

------------------------------------------------------------------------
-- 설정 (기본값)
------------------------------------------------------------------------
local Config = {
    -- 토글 키
    ToggleKey = Enum.KeyCode.RightShift,

    -- 마우스 이동 설정
    Active = false,
    Pattern = "None",           -- None, Circle, Square, Random, Shake, Smooth
    Speed = 1,                  -- 이동 속도 배율 (0.1 ~ 5)
    Radius = 50,                -- 원형/사각형 패턴 반지름 (px)
    Intensity = 3,              -- 랜덤/쉐이크 강도 (px)
    SmoothX = 0,                -- Smooth 모드 X 오프셋
    SmoothY = 0,                -- Smooth 모드 Y 오프셋
}

------------------------------------------------------------------------
-- 상태 변수
------------------------------------------------------------------------
local UIVisible = true
local Connection = nil
local Tick = 0

------------------------------------------------------------------------
-- UI 생성
------------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "MouseMoveRelTool"
ScreenGui.DisplayOrder = 2147483646
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.ResetOnSpawn = false
ScreenGui.IgnoreGuiInset = true

-- 안전한 UI 부모 설정
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

------------------------------------------------------------------------
-- UI 컴포넌트 헬퍼
------------------------------------------------------------------------
local Theme = {
    bg = Color3.fromRGB(20, 20, 28),
    card = Color3.fromRGB(28, 28, 38),
    accent = Color3.fromRGB(100, 180, 255),
    accentDark = Color3.fromRGB(60, 120, 200),
    text = Color3.fromRGB(220, 220, 230),
    textDim = Color3.fromRGB(130, 130, 150),
    success = Color3.fromRGB(80, 200, 120),
    danger = Color3.fromRGB(255, 80, 80),
    border = Color3.fromRGB(45, 45, 60),
}

local function createCorner(parent, radius)
    local corner = Instance.new("UICorner", parent)
    corner.CornerRadius = UDim.new(0, radius or 8)
    return corner
end

local function createStroke(parent, color, thickness)
    local stroke = Instance.new("UIStroke", parent)
    stroke.Color = color or Theme.border
    stroke.Thickness = thickness or 1
    stroke.Transparency = 0.5
    return stroke
end

local function createPadding(parent, t, b, l, r)
    local padding = Instance.new("UIPadding", parent)
    padding.PaddingTop = UDim.new(0, t or 8)
    padding.PaddingBottom = UDim.new(0, b or 8)
    padding.PaddingLeft = UDim.new(0, l or 10)
    padding.PaddingRight = UDim.new(0, r or 10)
    return padding
end

------------------------------------------------------------------------
-- 메인 프레임
------------------------------------------------------------------------
local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Name = "Main"
MainFrame.BackgroundColor3 = Theme.bg
MainFrame.Size = UDim2.new(0, 280, 0, 420)
MainFrame.Position = UDim2.new(0, 20, 0.5, -210)
MainFrame.AnchorPoint = Vector2.new(0, 0)
MainFrame.BackgroundTransparency = 0.02
createCorner(MainFrame, 12)
createStroke(MainFrame, Theme.border, 1)

-- 그림자
local Shadow = Instance.new("ImageLabel", MainFrame)
Shadow.Name = "Shadow"
Shadow.BackgroundTransparency = 1
Shadow.Image = "rbxassetid://6014261993"
Shadow.ImageColor3 = Color3.fromRGB(0, 0, 0)
Shadow.ImageTransparency = 0.5
Shadow.ScaleType = Enum.ScaleType.Slice
Shadow.SliceCenter = Rect.new(49, 49, 450, 450)
Shadow.Size = UDim2.new(1, 30, 1, 30)
Shadow.Position = UDim2.new(0.5, 0, 0.5, 0)
Shadow.AnchorPoint = Vector2.new(0.5, 0.5)
Shadow.ZIndex = 0

------------------------------------------------------------------------
-- 드래그 기능
------------------------------------------------------------------------
do
    local dragging, dragStart, startPos
    MainFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
        end
    end)
    MainFrame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or
                         input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            MainFrame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

------------------------------------------------------------------------
-- 헤더
------------------------------------------------------------------------
local Header = Instance.new("Frame", MainFrame)
Header.Name = "Header"
Header.BackgroundColor3 = Theme.card
Header.Size = UDim2.new(1, 0, 0, 48)
Header.BorderSizePixel = 0
createCorner(Header, 12)

-- 하단 코너 가리기
local HeaderFix = Instance.new("Frame", Header)
HeaderFix.BackgroundColor3 = Theme.card
HeaderFix.Size = UDim2.new(1, 0, 0, 14)
HeaderFix.Position = UDim2.new(0, 0, 1, -14)
HeaderFix.BorderSizePixel = 0

local Title = Instance.new("TextLabel", Header)
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(1, -80, 1, 0)
Title.Position = UDim2.new(0, 14, 0, 0)
Title.Text = "MouseMoveRel Tool"
Title.TextColor3 = Theme.text
Title.TextSize = 16
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Left

local StatusDot = Instance.new("Frame", Header)
StatusDot.Name = "StatusDot"
StatusDot.BackgroundColor3 = Theme.danger
StatusDot.Size = UDim2.new(0, 10, 0, 10)
StatusDot.Position = UDim2.new(1, -50, 0.5, -5)
createCorner(StatusDot, 5)

local StatusLabel = Instance.new("TextLabel", Header)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Size = UDim2.new(0, 30, 1, 0)
StatusLabel.Position = UDim2.new(1, -36, 0, 0)
StatusLabel.Text = "OFF"
StatusLabel.TextColor3 = Theme.danger
StatusLabel.TextSize = 11
StatusLabel.Font = Enum.Font.GothamBold
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left

------------------------------------------------------------------------
-- 콘텐츠 영역
------------------------------------------------------------------------
local Content = Instance.new("ScrollingFrame", MainFrame)
Content.Name = "Content"
Content.BackgroundTransparency = 1
Content.Size = UDim2.new(1, 0, 1, -56)
Content.Position = UDim2.new(0, 0, 0, 52)
Content.ScrollBarThickness = 3
Content.ScrollBarImageColor3 = Theme.accent
Content.CanvasSize = UDim2.new(0, 0, 0, 0)
Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.BorderSizePixel = 0

local ContentLayout = Instance.new("UIListLayout", Content)
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Padding = UDim.new(0, 6)

local ContentPadding = Instance.new("UIPadding", Content)
ContentPadding.PaddingTop = UDim.new(0, 6)
ContentPadding.PaddingBottom = UDim.new(0, 10)
ContentPadding.PaddingLeft = UDim.new(0, 10)
ContentPadding.PaddingRight = UDim.new(0, 10)

------------------------------------------------------------------------
-- UI 팩토리 함수들
------------------------------------------------------------------------
local function createSection(name, layoutOrder)
    local section = Instance.new("Frame", Content)
    section.Name = name
    section.BackgroundColor3 = Theme.card
    section.Size = UDim2.new(1, 0, 0, 0)
    section.AutomaticSize = Enum.AutomaticSize.Y
    section.LayoutOrder = layoutOrder
    section.BorderSizePixel = 0
    createCorner(section, 8)
    createPadding(section, 10, 10, 10, 10)

    local layout = Instance.new("UIListLayout", section)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)

    local label = Instance.new("TextLabel", section)
    label.Name = "Title"
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, 0, 0, 18)
    label.Text = name
    label.TextColor3 = Theme.accent
    label.TextSize = 12
    label.Font = Enum.Font.GothamBold
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.LayoutOrder = 0

    return section
end

local function createToggle(parent, text, default, layoutOrder, callback)
    local row = Instance.new("Frame", parent)
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 28)
    row.LayoutOrder = layoutOrder

    local label = Instance.new("TextLabel", row)
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -50, 1, 0)
    label.Text = text
    label.TextColor3 = Theme.text
    label.TextSize = 13
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left

    local toggleBg = Instance.new("Frame", row)
    toggleBg.Size = UDim2.new(0, 40, 0, 20)
    toggleBg.Position = UDim2.new(1, -40, 0.5, -10)
    toggleBg.BackgroundColor3 = default and Theme.accent or Color3.fromRGB(50, 50, 65)
    createCorner(toggleBg, 10)

    local toggleCircle = Instance.new("Frame", toggleBg)
    toggleCircle.Size = UDim2.new(0, 16, 0, 16)
    toggleCircle.Position = default and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    toggleCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    createCorner(toggleCircle, 8)

    local state = default
    toggleBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            state = not state
            TweenService:Create(toggleBg, TweenInfo.new(0.2), {
                BackgroundColor3 = state and Theme.accent or Color3.fromRGB(50, 50, 65)
            }):Play()
            TweenService:Create(toggleCircle, TweenInfo.new(0.2, Enum.EasingStyle.Back), {
                Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
            }):Play()
            callback(state)
        end
    end)

    return row, function(v)
        state = v
        toggleBg.BackgroundColor3 = state and Theme.accent or Color3.fromRGB(50, 50, 65)
        toggleCircle.Position = state and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    end
end

local function createSlider(parent, text, min, max, default, step, layoutOrder, callback)
    local row = Instance.new("Frame", parent)
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 40)
    row.LayoutOrder = layoutOrder

    local label = Instance.new("TextLabel", row)
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(1, -50, 0, 16)
    label.Text = text
    label.TextColor3 = Theme.text
    label.TextSize = 12
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left

    local valueLabel = Instance.new("TextLabel", row)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Size = UDim2.new(0, 45, 0, 16)
    valueLabel.Position = UDim2.new(1, -45, 0, 0)
    valueLabel.Text = tostring(default)
    valueLabel.TextColor3 = Theme.accent
    valueLabel.TextSize = 12
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right

    local sliderBg = Instance.new("Frame", row)
    sliderBg.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    sliderBg.Size = UDim2.new(1, 0, 0, 6)
    sliderBg.Position = UDim2.new(0, 0, 0, 26)
    createCorner(sliderBg, 3)

    local sliderFill = Instance.new("Frame", sliderBg)
    sliderFill.BackgroundColor3 = Theme.accent
    sliderFill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
    createCorner(sliderFill, 3)

    local sliderKnob = Instance.new("Frame", sliderBg)
    sliderKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    sliderKnob.Size = UDim2.new(0, 12, 0, 12)
    sliderKnob.Position = UDim2.new((default - min) / (max - min), -6, 0.5, -6)
    sliderKnob.ZIndex = 2
    createCorner(sliderKnob, 6)

    local dragging = false
    local function update(input)
        local rel = (input.Position.X - sliderBg.AbsolutePosition.X) / sliderBg.AbsoluteSize.X
        rel = math.clamp(rel, 0, 1)
        local value = min + (max - min) * rel
        if step then
            value = math.floor(value / step + 0.5) * step
        end
        value = math.clamp(value, min, max)
        local norm = (value - min) / (max - min)
        sliderFill.Size = UDim2.new(norm, 0, 1, 0)
        sliderKnob.Position = UDim2.new(norm, -6, 0.5, -6)
        valueLabel.Text = step and step >= 1 and tostring(math.floor(value)) or string.format("%.1f", value)
        callback(value)
    end

    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            update(input)
        end
    end)
    sliderKnob.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            update(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    return row
end

local function createDropdown(parent, text, options, default, layoutOrder, callback)
    local row = Instance.new("Frame", parent)
    row.BackgroundTransparency = 1
    row.Size = UDim2.new(1, 0, 0, 28)
    row.LayoutOrder = layoutOrder

    local label = Instance.new("TextLabel", row)
    label.BackgroundTransparency = 1
    label.Size = UDim2.new(0.4, 0, 1, 0)
    label.Text = text
    label.TextColor3 = Theme.text
    label.TextSize = 12
    label.Font = Enum.Font.Gotham
    label.TextXAlignment = Enum.TextXAlignment.Left

    local btnFrame = Instance.new("Frame", row)
    btnFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
    btnFrame.Size = UDim2.new(0.58, 0, 0, 24)
    btnFrame.Position = UDim2.new(0.42, 0, 0.5, -12)
    createCorner(btnFrame, 6)

    local btnLabel = Instance.new("TextLabel", btnFrame)
    btnLabel.BackgroundTransparency = 1
    btnLabel.Size = UDim2.new(1, -20, 1, 0)
    btnLabel.Position = UDim2.new(0, 8, 0, 0)
    btnLabel.Text = default
    btnLabel.TextColor3 = Theme.text
    btnLabel.TextSize = 11
    btnLabel.Font = Enum.Font.Gotham
    btnLabel.TextXAlignment = Enum.TextXAlignment.Left

    local arrow = Instance.new("TextLabel", btnFrame)
    arrow.BackgroundTransparency = 1
    arrow.Size = UDim2.new(0, 16, 1, 0)
    arrow.Position = UDim2.new(1, -18, 0, 0)
    arrow.Text = "v"
    arrow.TextColor3 = Theme.textDim
    arrow.TextSize = 10
    arrow.Font = Enum.Font.GothamBold

    local dropdownOpen = false
    local dropdownFrame = Instance.new("Frame", row)
    dropdownFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    dropdownFrame.Size = UDim2.new(0.58, 0, 0, #options * 24)
    dropdownFrame.Position = UDim2.new(0.42, 0, 1, 2)
    dropdownFrame.ZIndex = 10
    dropdownFrame.Visible = false
    createCorner(dropdownFrame, 6)
    createStroke(dropdownFrame, Theme.border)

    local ddLayout = Instance.new("UIListLayout", dropdownFrame)
    ddLayout.SortOrder = Enum.SortOrder.LayoutOrder

    for i, opt in ipairs(options) do
        local optBtn = Instance.new("TextButton", dropdownFrame)
        optBtn.BackgroundTransparency = 1
        optBtn.Size = UDim2.new(1, 0, 0, 24)
        optBtn.Text = ""
        optBtn.LayoutOrder = i
        optBtn.ZIndex = 10

        local optLabel = Instance.new("TextLabel", optBtn)
        optLabel.BackgroundTransparency = 1
        optLabel.Size = UDim2.new(1, -16, 1, 0)
        optLabel.Position = UDim2.new(0, 8, 0, 0)
        optLabel.Text = opt
        optLabel.TextColor3 = opt == default and Theme.accent or Theme.text
        optLabel.TextSize = 11
        optLabel.Font = Enum.Font.Gotham
        optLabel.TextXAlignment = Enum.TextXAlignment.Left
        optLabel.ZIndex = 10

        optBtn.MouseEnter:Connect(function()
            optBtn.BackgroundTransparency = 0.8
            optBtn.BackgroundColor3 = Theme.accent
        end)
        optBtn.MouseLeave:Connect(function()
            optBtn.BackgroundTransparency = 1
        end)
        optBtn.MouseButton1Click:Connect(function()
            btnLabel.Text = opt
            dropdownFrame.Visible = false
            dropdownOpen = false
            for _, c in ipairs(dropdownFrame:GetChildren()) do
                if c:IsA("TextButton") then
                    local lbl = c:FindFirstChildOfClass("TextLabel")
                    if lbl then
                        lbl.TextColor3 = lbl.Text == opt and Theme.accent or Theme.text
                    end
                end
            end
            callback(opt)
        end)
    end

    btnFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dropdownOpen = not dropdownOpen
            dropdownFrame.Visible = dropdownOpen
        end
    end)

    return row
end

local function createButton(parent, text, color, layoutOrder, callback)
    local btn = Instance.new("TextButton", parent)
    btn.BackgroundColor3 = color or Theme.accent
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.Text = text
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 13
    btn.Font = Enum.Font.GothamBold
    btn.LayoutOrder = layoutOrder
    btn.AutoButtonColor = false
    createCorner(btn, 6)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0.15}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn, TweenInfo.new(0.15), {BackgroundTransparency = 0}):Play()
    end)
    btn.MouseButton1Click:Connect(callback)

    return btn
end

------------------------------------------------------------------------
-- 섹션 1: 패턴 선택
------------------------------------------------------------------------
local patternSection = createSection("PATTERN", 1)
createDropdown(patternSection, "Mode", {
    "None", "Circle", "Square", "Random", "Shake", "Smooth"
}, Config.Pattern, 1, function(val)
    Config.Pattern = val
end)

------------------------------------------------------------------------
-- 섹션 2: 파라미터
------------------------------------------------------------------------
local paramSection = createSection("PARAMETERS", 2)
createSlider(paramSection, "Speed", 0.1, 5, Config.Speed, 0.1, 1, function(val)
    Config.Speed = val
end)
createSlider(paramSection, "Radius", 5, 200, Config.Radius, 1, 2, function(val)
    Config.Radius = val
end)
createSlider(paramSection, "Intensity", 1, 30, Config.Intensity, 1, 3, function(val)
    Config.Intensity = val
end)

------------------------------------------------------------------------
-- 섹션 3: Smooth 모드 (커스텀 오프셋)
------------------------------------------------------------------------
local smoothSection = createSection("SMOOTH OFFSET", 3)
createSlider(smoothSection, "X Offset", -50, 50, Config.SmoothX, 1, 1, function(val)
    Config.SmoothX = val
end)
createSlider(smoothSection, "Y Offset", -50, 50, Config.SmoothY, 1, 2, function(val)
    Config.SmoothY = val
end)

------------------------------------------------------------------------
-- 섹션 4: 컨트롤
------------------------------------------------------------------------
local controlSection = createSection("CONTROL", 4)

local _, setActiveToggle = createToggle(controlSection, "Active", Config.Active, 1, function(val)
    Config.Active = val
end)

createButton(controlSection, "Single Move (10, 0)", Theme.accentDark, 2, function()
    mousemoverel(10, 0)
end)

createButton(controlSection, "Single Move (0, -10)", Theme.accentDark, 3, function()
    mousemoverel(0, -10)
end)

createButton(controlSection, "Test Circle (1 rotation)", Theme.accentDark, 4, function()
    task.spawn(function()
        for i = 0, 360, 5 do
            local rad = math.rad(i)
            local dx = math.cos(rad) * 2
            local dy = math.sin(rad) * 2
            mousemoverel(dx, dy)
            task.wait(0.01)
        end
    end)
end)

------------------------------------------------------------------------
-- 섹션 5: 정보
------------------------------------------------------------------------
local infoSection = createSection("INFO", 5)
local infoLabel = Instance.new("TextLabel", infoSection)
infoLabel.BackgroundTransparency = 1
infoLabel.Size = UDim2.new(1, 0, 0, 36)
infoLabel.Text = "Toggle Key: RightShift\nUI Toggle: RightControl"
infoLabel.TextColor3 = Theme.textDim
infoLabel.TextSize = 11
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextWrapped = true
infoLabel.LayoutOrder = 1

------------------------------------------------------------------------
-- 마우스 이동 로직
------------------------------------------------------------------------
local function updateMouseMove(dt)
    if not Config.Active then return end
    if Config.Pattern == "None" then return end

    Tick = Tick + dt * Config.Speed

    local dx, dy = 0, 0

    if Config.Pattern == "Circle" then
        -- 원형 패턴: 현재 각도에서의 미분 변화량
        local angle = Tick * 3
        dx = math.cos(angle) * Config.Radius * dt * Config.Speed * 3
        dy = math.sin(angle) * Config.Radius * dt * Config.Speed * 3

    elseif Config.Pattern == "Square" then
        -- 사각형 패턴
        local phase = (Tick * 2) % 4
        local speed = Config.Radius * dt * Config.Speed * 3
        if phase < 1 then
            dx, dy = speed, 0
        elseif phase < 2 then
            dx, dy = 0, speed
        elseif phase < 3 then
            dx, dy = -speed, 0
        else
            dx, dy = 0, -speed
        end

    elseif Config.Pattern == "Random" then
        -- 랜덤 패턴
        dx = (math.random() * 2 - 1) * Config.Intensity
        dy = (math.random() * 2 - 1) * Config.Intensity

    elseif Config.Pattern == "Shake" then
        -- 빠른 흔들림 (반동 시뮬레이션)
        dx = (math.random() * 2 - 1) * Config.Intensity * 2
        dy = -math.abs((math.random() * 2 - 1) * Config.Intensity)

    elseif Config.Pattern == "Smooth" then
        -- 부드러운 일정 오프셋 이동
        dx = Config.SmoothX * dt * Config.Speed
        dy = Config.SmoothY * dt * Config.Speed
    end

    if dx ~= 0 or dy ~= 0 then
        mousemoverel(dx, dy)
    end
end

------------------------------------------------------------------------
-- 상태 업데이트
------------------------------------------------------------------------
local function updateStatus()
    if Config.Active and Config.Pattern ~= "None" then
        StatusDot.BackgroundColor3 = Theme.success
        StatusLabel.Text = "ON"
        StatusLabel.TextColor3 = Theme.success
    else
        StatusDot.BackgroundColor3 = Theme.danger
        StatusLabel.Text = "OFF"
        StatusLabel.TextColor3 = Theme.danger
    end
end

------------------------------------------------------------------------
-- 메인 루프
------------------------------------------------------------------------
Connection = RunService.RenderStepped:Connect(function(dt)
    updateMouseMove(dt)
    updateStatus()
end)

------------------------------------------------------------------------
-- 키바인드
------------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    -- RightShift: Active 토글
    if input.KeyCode == Enum.KeyCode.RightShift then
        Config.Active = not Config.Active
        setActiveToggle(Config.Active)
    end

    -- RightControl: UI 표시/숨기기
    if input.KeyCode == Enum.KeyCode.RightControl then
        UIVisible = not UIVisible
        MainFrame.Visible = UIVisible
    end
end)

------------------------------------------------------------------------
-- Destroy 함수
------------------------------------------------------------------------
local Tool = {}
function Tool:Destroy()
    if Connection then
        Connection:Disconnect()
        Connection = nil
    end
    if ScreenGui then
        ScreenGui:Destroy()
    end
    shared._MouseMoveRelTool = nil
end

shared._MouseMoveRelTool = Tool

------------------------------------------------------------------------
-- 초기화 완료 메시지
------------------------------------------------------------------------
print("[MouseMoveRel Tool] Loaded!")
print("[MouseMoveRel Tool] RightShift = Toggle Active | RightControl = Toggle UI")
