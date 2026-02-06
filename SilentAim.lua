--[[
    Silent Aim + Prediction + GUI
    
    Mouse4 = 사일런트 에임 ON/OFF
    RightShift = GUI 표시/숨김
    
    필요: hookmetamethod, newcclosure, checkcaller,
          getrawmetatable, getnamecallmethod, Drawing
]]

-- 환경 검증
local required = {
    hookmetamethod = hookmetamethod,
    newcclosure = newcclosure,
    checkcaller = checkcaller,
    getnamecallmethod = getnamecallmethod,
    getrawmetatable = getrawmetatable,
}
for name, fn in pairs(required) do
    assert(fn, "[SilentAim] Missing: " .. name)
end

-- 중복 방지
if shared._SilentAimActive then
    shared._SilentAimActive()
    task.wait(0.2)
end

------------------------------------------------------------
-- Services
------------------------------------------------------------
local cloneref    = cloneref or function(x) return x end
local Players     = cloneref(game:GetService("Players"))
local RunService  = cloneref(game:GetService("RunService"))
local UserInput   = cloneref(game:GetService("UserInputService"))
local TweenSvc    = cloneref(game:GetService("TweenService"))
local WS          = cloneref(game:GetService("Workspace"))
local Camera      = WS.CurrentCamera
local LP          = Players.LocalPlayer
local Mouse       = LP:GetMouse()

------------------------------------------------------------
-- Config
------------------------------------------------------------
local Config = {
    Enabled         = false,
    ToggleKey       = Enum.KeyCode.V,          -- V키 토글 (Mouse4 미지원 호환)
    UIToggleKey     = Enum.KeyCode.RightShift,

    FOV             = 130,
    TargetPart      = "Head",
    TeamCheck       = false,
    VisibleCheck    = false,
    MaxDistance      = 2000,

    Prediction      = true,
    PredictionScale = 1.0,

    ShowFOV         = true,
    ShowTarget      = true,
}

------------------------------------------------------------
-- State
------------------------------------------------------------
local CurrentTarget   = nil
local Connections     = {}
local CleanupDrawing  = {}
local VelocityCache   = {}

------------------------------------------------------------
-- Drawing (FOV circle, target dot, status)
------------------------------------------------------------
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1; FOVCircle.NumSides = 60; FOVCircle.Filled = false
FOVCircle.Transparency = 0.6; FOVCircle.Color = Color3.fromRGB(100,180,255); FOVCircle.Visible = false
table.insert(CleanupDrawing, FOVCircle)

local TargetDot = Drawing.new("Circle")
TargetDot.Thickness = 0; TargetDot.NumSides = 20; TargetDot.Radius = 4
TargetDot.Filled = true; TargetDot.Color = Color3.fromRGB(255,80,80); TargetDot.Visible = false
table.insert(CleanupDrawing, TargetDot)

local TargetLine = Drawing.new("Line")
TargetLine.Thickness = 1; TargetLine.Transparency = 0.5
TargetLine.Color = Color3.fromRGB(255,80,80); TargetLine.Visible = false
table.insert(CleanupDrawing, TargetLine)

------------------------------------------------------------
-- GUI
------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SilentAimGUI"
ScreenGui.DisplayOrder = 2147483647
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
pcall(function()
    if gethui then ScreenGui.Parent = gethui()
    elseif syn and syn.protect_gui then syn.protect_gui(ScreenGui); ScreenGui.Parent = game:GetService("CoreGui")
    else ScreenGui.Parent = game:GetService("CoreGui") end
end)

local C = {
    bg      = Color3.fromRGB(18,18,24),
    card    = Color3.fromRGB(26,26,34),
    accent  = Color3.fromRGB(100,180,255),
    on      = Color3.fromRGB(80,220,130),
    off     = Color3.fromRGB(220,70,70),
    text    = Color3.fromRGB(220,220,230),
    sub     = Color3.fromRGB(120,120,140),
    border  = Color3.fromRGB(42,42,52),
    sliderBg= Color3.fromRGB(44,44,56),
}

-- Main Frame
local Main = Instance.new("Frame", ScreenGui)
Main.Name = "Main"; Main.Size = UDim2.new(0,270,0,420)
Main.Position = UDim2.new(1,-290,0,20); Main.BackgroundColor3 = C.bg; Main.BorderSizePixel = 0
Instance.new("UICorner", Main).CornerRadius = UDim.new(0,10)
local stroke = Instance.new("UIStroke", Main); stroke.Color = C.border; stroke.Thickness = 1

-- Shadow
local sh = Instance.new("ImageLabel", Main); sh.ZIndex = 0; sh.BackgroundTransparency = 1
sh.Image = "rbxassetid://6014261993"; sh.ScaleType = Enum.ScaleType.Slice
sh.SliceCenter = Rect.new(49,49,450,450); sh.ImageTransparency = 0.5; sh.ImageColor3 = Color3.new(0,0,0)
sh.AnchorPoint = Vector2.new(0.5,0.5); sh.Size = UDim2.new(1,30,1,30); sh.Position = UDim2.new(0.5,0,0.5,0)

-- Title bar
local TitleBar = Instance.new("Frame", Main)
TitleBar.Size = UDim2.new(1,0,0,38); TitleBar.BackgroundColor3 = C.card; TitleBar.BorderSizePixel = 0
Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0,10)
local titleFill = Instance.new("Frame", TitleBar)
titleFill.Size = UDim2.new(1,0,0,10); titleFill.Position = UDim2.new(0,0,1,-10)
titleFill.BackgroundColor3 = C.card; titleFill.BorderSizePixel = 0

local TitleText = Instance.new("TextLabel", TitleBar)
TitleText.Size = UDim2.new(1,-16,1,0); TitleText.Position = UDim2.new(0,14,0,0)
TitleText.BackgroundTransparency = 1; TitleText.Text = "Silent Aim"
TitleText.TextColor3 = C.text; TitleText.TextSize = 15
TitleText.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Bold)
TitleText.TextXAlignment = Enum.TextXAlignment.Left

local VerText = Instance.new("TextLabel", TitleBar)
VerText.Size = UDim2.new(0,60,1,0); VerText.Position = UDim2.new(1,-70,0,0)
VerText.BackgroundTransparency = 1; VerText.Text = "RShift: hide"
VerText.TextColor3 = C.sub; VerText.TextSize = 10
VerText.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Regular)
VerText.TextXAlignment = Enum.TextXAlignment.Right

-- Content scroll
local Content = Instance.new("ScrollingFrame", Main)
Content.Size = UDim2.new(1,-20,1,-48); Content.Position = UDim2.new(0,10,0,42)
Content.BackgroundTransparency = 1; Content.BorderSizePixel = 0; Content.ScrollBarThickness = 2
Content.ScrollBarImageColor3 = C.accent; Content.AutomaticCanvasSize = Enum.AutomaticSize.Y
Content.CanvasSize = UDim2.new(0,0,0,0)
Instance.new("UIListLayout", Content).Padding = UDim.new(0,6)

-- Drag
do
    local dragging, dragStart, startPos
    TitleBar.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; dragStart = i.Position; startPos = Main.Position end
    end)
    UserInput.InputChanged:Connect(function(i)
        if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
            local d = i.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X, startPos.Y.Scale, startPos.Y.Offset+d.Y)
        end
    end)
    UserInput.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
    end)
end

------------------------------------------------------------
-- UI Builders
------------------------------------------------------------
local function card(h)
    local f = Instance.new("Frame", Content); f.Size = UDim2.new(1,0,0,h or 40)
    f.BackgroundColor3 = C.card; f.BorderSizePixel = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0,8); return f
end

local function label(txt)
    local l = Instance.new("TextLabel", Content); l.Size = UDim2.new(1,0,0,18)
    l.BackgroundTransparency = 1; l.Text = "  "..txt; l.TextColor3 = C.sub; l.TextSize = 10
    l.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Bold)
    l.TextXAlignment = Enum.TextXAlignment.Left
end

local function makeToggle(name, getter, setter)
    local c = card(38)
    local l = Instance.new("TextLabel", c)
    l.Size = UDim2.new(1,-66,1,0); l.Position = UDim2.new(0,12,0,0)
    l.BackgroundTransparency = 1; l.Text = name; l.TextColor3 = C.text; l.TextSize = 13
    l.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Medium)
    l.TextXAlignment = Enum.TextXAlignment.Left

    local bg = Instance.new("Frame", c)
    bg.Size = UDim2.new(0,38,0,20); bg.Position = UDim2.new(1,-50,0.5,-10)
    bg.BackgroundColor3 = getter() and C.on or C.off; bg.BorderSizePixel = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(1,0)

    local dot = Instance.new("Frame", bg)
    dot.Size = UDim2.new(0,16,0,16); dot.BackgroundColor3 = Color3.new(1,1,1); dot.BorderSizePixel = 0
    dot.Position = getter() and UDim2.new(1,-18,0,2) or UDim2.new(0,2,0,2)
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1,0)

    local btn = Instance.new("TextButton", c)
    btn.Size = UDim2.new(1,0,1,0); btn.BackgroundTransparency = 1; btn.Text = ""; btn.ZIndex = 5

    local function refresh()
        local v = getter()
        TweenSvc:Create(bg, TweenInfo.new(0.15), {BackgroundColor3 = v and C.on or C.off}):Play()
        TweenSvc:Create(dot, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = v and UDim2.new(1,-18,0,2) or UDim2.new(0,2,0,2)
        }):Play()
    end

    btn.MouseButton1Click:Connect(function() setter(not getter()); refresh() end)
    return refresh
end

local function makeSlider(name, min, max, getter, setter)
    local c = card(52)
    local l = Instance.new("TextLabel", c)
    l.Size = UDim2.new(1,-50,0,22); l.Position = UDim2.new(0,12,0,2)
    l.BackgroundTransparency = 1; l.Text = name; l.TextColor3 = C.text; l.TextSize = 13
    l.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Medium)
    l.TextXAlignment = Enum.TextXAlignment.Left

    local vl = Instance.new("TextLabel", c)
    vl.Size = UDim2.new(0,40,0,22); vl.Position = UDim2.new(1,-52,0,2)
    vl.BackgroundTransparency = 1; vl.TextColor3 = C.accent; vl.TextSize = 13
    vl.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Bold)
    vl.TextXAlignment = Enum.TextXAlignment.Right

    local bar = Instance.new("Frame", c)
    bar.Size = UDim2.new(1,-24,0,6); bar.Position = UDim2.new(0,12,0,34)
    bar.BackgroundColor3 = C.sliderBg; bar.BorderSizePixel = 0
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1,0)

    local fill = Instance.new("Frame", bar)
    fill.BackgroundColor3 = C.accent; fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)

    local knob = Instance.new("Frame", bar)
    knob.Size = UDim2.new(0,12,0,12); knob.BackgroundColor3 = Color3.new(1,1,1); knob.BorderSizePixel = 0; knob.ZIndex = 3
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)

    local function refresh()
        local pct = (getter() - min) / (max - min)
        fill.Size = UDim2.new(pct, 0, 1, 0)
        knob.Position = UDim2.new(pct, -6, 0.5, -6)
        local val = getter()
        vl.Text = (val == math.floor(val)) and tostring(math.floor(val)) or string.format("%.1f", val)
    end
    refresh()

    local dragging = false
    local hitbox = Instance.new("TextButton", bar)
    hitbox.Size = UDim2.new(1,8,0,20); hitbox.Position = UDim2.new(0,-4,0.5,-10)
    hitbox.BackgroundTransparency = 1; hitbox.Text = ""; hitbox.ZIndex = 5

    local function upd(input)
        local rel = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
        local step = (max - min >= 10) and 1 or 0.1
        local raw = min + (max - min) * rel
        local val = math.floor(raw / step + 0.5) * step
        val = math.clamp(val, min, max)
        setter(val); refresh()
    end
    hitbox.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; upd(i) end end)
    UserInput.InputChanged:Connect(function(i) if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then upd(i) end end)
    UserInput.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
    return refresh
end

local function makeDropdown(name, options, getter, setter)
    local c = card(38)
    local l = Instance.new("TextLabel", c)
    l.Size = UDim2.new(0.5,0,1,0); l.Position = UDim2.new(0,12,0,0)
    l.BackgroundTransparency = 1; l.Text = name; l.TextColor3 = C.text; l.TextSize = 13
    l.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Medium)
    l.TextXAlignment = Enum.TextXAlignment.Left

    local idx = table.find(options, getter()) or 1
    local btn = Instance.new("TextButton", c)
    btn.Size = UDim2.new(0,100,0,26); btn.Position = UDim2.new(1,-112,0.5,-13)
    btn.BackgroundColor3 = C.sliderBg; btn.BorderSizePixel = 0
    btn.Text = " "..options[idx].." "; btn.TextColor3 = C.accent; btn.TextSize = 12
    btn.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Medium)
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)

    btn.MouseButton1Click:Connect(function()
        idx = (idx % #options) + 1
        btn.Text = " "..options[idx].." "
        setter(options[idx])
    end)
end

------------------------------------------------------------
-- Status card
------------------------------------------------------------
local statusCard = card(44)
local statusDot = Instance.new("Frame", statusCard)
statusDot.Size = UDim2.new(0,10,0,10); statusDot.Position = UDim2.new(0,12,0.5,-5)
statusDot.BackgroundColor3 = C.off; statusDot.BorderSizePixel = 0
Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1,0)

local statusLbl = Instance.new("TextLabel", statusCard)
statusLbl.Size = UDim2.new(1,-32,0,16); statusLbl.Position = UDim2.new(0,28,0,6)
statusLbl.BackgroundTransparency = 1; statusLbl.Text = "OFF - V to toggle"
statusLbl.TextColor3 = C.sub; statusLbl.TextSize = 13
statusLbl.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Bold)
statusLbl.TextXAlignment = Enum.TextXAlignment.Left

local targetLbl = Instance.new("TextLabel", statusCard)
targetLbl.Size = UDim2.new(1,-32,0,14); targetLbl.Position = UDim2.new(0,28,0,24)
targetLbl.BackgroundTransparency = 1; targetLbl.Text = "Target: -"
targetLbl.TextColor3 = C.sub; targetLbl.TextSize = 11
targetLbl.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Regular)
targetLbl.TextXAlignment = Enum.TextXAlignment.Left

local function refreshStatus()
    statusDot.BackgroundColor3 = Config.Enabled and C.on or C.off
    statusLbl.Text = Config.Enabled and "ON - Silent Aim Active" or "OFF - V to toggle"
    statusLbl.TextColor3 = Config.Enabled and C.on or C.sub
end

------------------------------------------------------------
-- Build UI controls
------------------------------------------------------------
label("CORE")
local refreshEnabled = makeToggle("Silent Aim", function() return Config.Enabled end, function(v) Config.Enabled = v; refreshStatus() end)

label("TARGETING")
makeSlider("FOV Radius", 30, 400, function() return Config.FOV end, function(v) Config.FOV = v end)
makeDropdown("Target Part", {"Head","HumanoidRootPart","UpperTorso"}, function() return Config.TargetPart end, function(v) Config.TargetPart = v end)
makeSlider("Max Distance", 200, 5000, function() return Config.MaxDistance end, function(v) Config.MaxDistance = v end)
makeToggle("Team Check", function() return Config.TeamCheck end, function(v) Config.TeamCheck = v end)
makeToggle("Visible Check", function() return Config.VisibleCheck end, function(v) Config.VisibleCheck = v end)

label("PREDICTION")
makeToggle("Auto Prediction", function() return Config.Prediction end, function(v) Config.Prediction = v end)
makeSlider("Pred. Scale", 0.1, 3.0, function() return Config.PredictionScale end, function(v) Config.PredictionScale = v end)

label("VISUALS")
makeToggle("Show FOV", function() return Config.ShowFOV end, function(v) Config.ShowFOV = v end)
makeToggle("Show Target", function() return Config.ShowTarget end, function(v) Config.ShowTarget = v end)

------------------------------------------------------------
-- Prediction engine
------------------------------------------------------------
local function getVelocity(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return Vector3.zero end
    local id = char:GetFullName()
    local now = tick()
    local c = VelocityCache[id]
    if c and (now - c.T) > 0 and (now - c.T) < 0.5 then
        local vel = (hrp.Position - c.P) / (now - c.T)
        VelocityCache[id] = {P = hrp.Position, T = now, V = vel}
        return vel
    end
    VelocityCache[id] = {P = hrp.Position, T = now, V = Vector3.zero}
    return Vector3.zero
end

local function predict(part, char)
    if not Config.Prediction then return part.Position end
    local origin = Camera.CFrame.Position
    local pos = part.Position
    local vel = getVelocity(char)
    local dist = (pos - origin).Magnitude
    local time = dist / 1000
    return pos + vel * time * Config.PredictionScale
end

------------------------------------------------------------
-- Target selection
------------------------------------------------------------
local function getTarget()
    local best, bestD = nil, Config.FOV
    local ctr = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LP then continue end
        local ch = p.Character; if not ch then continue end
        local hum = ch:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        if Config.TeamCheck and p.Team and p.Team == LP.Team then continue end
        local part = ch:FindFirstChild(Config.TargetPart) or ch:FindFirstChild("Head")
        if not part then continue end
        if (part.Position - Camera.CFrame.Position).Magnitude > Config.MaxDistance then continue end
        if Config.VisibleCheck then
            local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude
            rp.FilterDescendantsInstances = {LP.Character, Camera}
            local r = WS:Raycast(Camera.CFrame.Position, part.Position - Camera.CFrame.Position, rp)
            if r and not r.Instance:IsDescendantOf(ch) then continue end
        end
        local pred = predict(part, ch)
        local sp, vis = Camera:WorldToViewportPoint(pred)
        if not vis then continue end
        local d = (Vector2.new(sp.X,sp.Y) - ctr).Magnitude
        if d < bestD then
            bestD = d
            best = {Player=p, Character=ch, Part=part, Predicted=pred, ScreenPos=Vector2.new(sp.X,sp.Y), Dist3D=(part.Position-Camera.CFrame.Position).Magnitude}
        end
    end
    return best
end

------------------------------------------------------------
-- Silent aim hooks
------------------------------------------------------------
local oldNC
local ncHook = newcclosure(function(self, ...)
    local m = getnamecallmethod()
    if Config.Enabled and CurrentTarget and CurrentTarget.Part then
        local pp = CurrentTarget.Predicted or CurrentTarget.Part.Position
        if m == "FindPartOnRayWithIgnoreList" or m == "FindPartOnRay" then
            local a = {...}
            if typeof(a[1]) == "Ray" then
                local o = a[1].Origin
                a[1] = Ray.new(o, (pp-o).Unit * a[1].Direction.Magnitude)
                return oldNC(self, unpack(a))
            end
        end
        if m == "Raycast" and self == WS then
            local a = {...}
            if typeof(a[1]) == "Vector3" then
                a[2] = (pp-a[1]).Unit * a[2].Magnitude
                return oldNC(self, a[1], a[2], unpack(a,3))
            end
        end
    end
    return oldNC(self, ...)
end)
oldNC = hookmetamethod(game, "__namecall", ncHook)

-- Mouse spoof
local mt = getrawmetatable(Mouse)
local oldIdx
if mt then
    pcall(function() if setreadonly then setreadonly(mt, false) end end)
    oldIdx = mt.__index
    mt.__index = newcclosure(function(s, k)
        if Config.Enabled and CurrentTarget and CurrentTarget.Part then
            local pos = CurrentTarget.Predicted or CurrentTarget.Part.Position
            if k == "Hit" then return CFrame.new(pos) end
            if k == "UnitRay" then return Ray.new(Camera.CFrame.Position, (pos-Camera.CFrame.Position).Unit) end
            if k == "Target" then return CurrentTarget.Part end
        end
        return oldIdx(s, k)
    end)
end

------------------------------------------------------------
-- Main loop
------------------------------------------------------------
Connections.Render = RunService.RenderStepped:Connect(function()
    Camera = WS.CurrentCamera
    local ctr = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)

    FOVCircle.Position = ctr; FOVCircle.Radius = Config.FOV
    FOVCircle.Visible = Config.ShowFOV
    FOVCircle.Color = Config.Enabled and C.on or Color3.fromRGB(100,180,255)

    if Config.Enabled then
        CurrentTarget = getTarget()
    else
        CurrentTarget = nil
    end

    if CurrentTarget then
        local nm = CurrentTarget.Player.Name
        local d = CurrentTarget.Dist3D
        targetLbl.Text = string.format("Target: %s (%.0f studs)", nm, d)
    else
        targetLbl.Text = Config.Enabled and "Target: scanning..." or "Target: -"
    end

    if CurrentTarget and Config.ShowTarget then
        local sp, vis = Camera:WorldToViewportPoint(CurrentTarget.Predicted or CurrentTarget.Part.Position)
        if vis then
            local sv = Vector2.new(sp.X, sp.Y)
            TargetDot.Position = sv; TargetDot.Visible = true
            TargetLine.From = ctr; TargetLine.To = sv; TargetLine.Visible = true
        else TargetDot.Visible = false; TargetLine.Visible = false end
    else TargetDot.Visible = false; TargetLine.Visible = false end
end)

------------------------------------------------------------
-- Input
------------------------------------------------------------
Connections.Input = UserInput.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Config.ToggleKey then
        Config.Enabled = not Config.Enabled
        refreshStatus(); refreshEnabled()
    end
    if input.KeyCode == Config.UIToggleKey then
        Main.Visible = not Main.Visible
    end
end)

------------------------------------------------------------
-- Cleanup
------------------------------------------------------------
local function destroy()
    for _, cn in pairs(Connections) do pcall(function() cn:Disconnect() end) end
    for _, d in ipairs(CleanupDrawing) do pcall(d.Remove, d) end
    if oldNC then pcall(hookmetamethod, game, "__namecall", oldNC) end
    if oldIdx and mt then pcall(function() mt.__index = oldIdx end) end
    pcall(function() ScreenGui:Destroy() end)
    shared._SilentAimActive = nil
end
shared._SilentAimActive = destroy

refreshStatus()
print("[SilentAim] Loaded! V=Toggle | RShift=Hide GUI")
