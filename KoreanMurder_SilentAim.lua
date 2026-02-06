--[[
    Korean Murder - Silent Aim Suite
    PlaceId: 5720801512
    
    V키 = Silent Aim ON/OFF
    RightShift = UI 표시/숨김
    
    기능:
    - Silent Aimbot (namecall + Mouse.Hit 스푸핑)
    - Wallbang (벽 관통)
    - Auto Shoot (자동 발사)
    - Auto Grab Gun (총 자동 줍기)
    - Murder Finder (머더 표시)
    - FOV Circle
]]

-------------------------------------------------------
-- 환경 검증
-------------------------------------------------------
assert(hookmetamethod,    "[KM] hookmetamethod 필요")
assert(newcclosure,       "[KM] newcclosure 필요")
assert(checkcaller,       "[KM] checkcaller 필요")
assert(getnamecallmethod, "[KM] getnamecallmethod 필요")
assert(getrawmetatable,   "[KM] getrawmetatable 필요")

if shared._KM_SilentAim then shared._KM_SilentAim(); task.wait(0.2) end

-------------------------------------------------------
-- Services
-------------------------------------------------------
local cloneref   = cloneref or function(x) return x end
local Players    = cloneref(game:GetService("Players"))
local RS         = cloneref(game:GetService("RunService"))
local UIS        = cloneref(game:GetService("UserInputService"))
local TS         = cloneref(game:GetService("TweenService"))
local WS         = cloneref(game:GetService("Workspace"))
local RP         = cloneref(game:GetService("ReplicatedStorage"))
local Camera     = WS.CurrentCamera
local LP         = Players.LocalPlayer
local Mouse      = LP:GetMouse()

-------------------------------------------------------
-- Config
-------------------------------------------------------
local CFG = {
    -- Silent Aim
    SilentAim      = false,
    FOV            = 150,
    TargetPart     = "Head",
    Prediction     = true,
    PredScale      = 1.0,
    
    -- Wallbang
    Wallbang       = false,
    
    -- Auto
    AutoShoot      = false,
    AutoGrabGun    = false,
    
    -- Visuals
    ShowFOV        = true,
    ShowTarget     = true,
    MurderESP      = false,
    
    -- Keys
    ToggleKey      = Enum.KeyCode.V,
    UIKey          = Enum.KeyCode.RightShift,
}

-------------------------------------------------------
-- State
-------------------------------------------------------
local Target      = nil
local Conns       = {}
local DrawClean   = {}
local VelCache    = {}
local Hooks       = {}

-------------------------------------------------------
-- Drawing
-------------------------------------------------------
local function newDraw(class, props)
    local d = Drawing.new(class)
    for k,v in pairs(props) do d[k] = v end
    table.insert(DrawClean, d)
    return d
end

local FOVCircle = newDraw("Circle", {
    Thickness = 1, NumSides = 60, Filled = false,
    Transparency = 0.5, Color = Color3.fromRGB(100,180,255), Visible = false,
})
local TargetDot = newDraw("Circle", {
    Thickness = 0, NumSides = 20, Radius = 5, Filled = true,
    Transparency = 0.15, Color = Color3.fromRGB(255,60,60), Visible = false,
})
local TargetLine = newDraw("Line", {
    Thickness = 1, Transparency = 0.4,
    Color = Color3.fromRGB(255,60,60), Visible = false,
})
local StatusDraw = newDraw("Text", {
    Size = 15, Center = false, Outline = true,
    OutlineColor = Color3.new(0,0,0), Position = Vector2.new(10,10), Font = 2, Visible = true,
})

-------------------------------------------------------
-- Korean Murder 게임 유틸
-------------------------------------------------------
local function getRole(player)
    -- Korean Murder는 역할 값을 캐릭터 또는 리더스탯에 저장
    local ch = player.Character
    if not ch then return "Unknown" end
    
    -- 방법 1: 총(Tool)을 가지고 있으면 Sheriff
    for _, tool in ipairs(player.Backpack:GetChildren()) do
        if tool:IsA("Tool") and (tool.Name:lower():find("gun") or tool.Name:lower():find("revolver") or tool.Name:lower():find("pistol")) then
            return "Sheriff"
        end
    end
    for _, tool in ipairs(ch:GetChildren()) do
        if tool:IsA("Tool") and (tool.Name:lower():find("gun") or tool.Name:lower():find("revolver") or tool.Name:lower():find("pistol")) then
            return "Sheriff"
        end
    end
    
    -- 방법 2: 나이프를 가지고 있으면 Murder
    for _, tool in ipairs(player.Backpack:GetChildren()) do
        if tool:IsA("Tool") and (tool.Name:lower():find("knife") or tool.Name:lower():find("blade")) then
            return "Murder"
        end
    end
    for _, tool in ipairs(ch:GetChildren()) do
        if tool:IsA("Tool") and (tool.Name:lower():find("knife") or tool.Name:lower():find("blade")) then
            return "Murder"
        end
    end
    
    return "Innocent"
end

local function isMurder(player)
    return getRole(player) == "Murder"
end

local function isSheriff(player)
    return getRole(player) == "Sheriff"
end

local function amISheriff()
    return isSheriff(LP)
end

local function findGunOnGround()
    for _, obj in ipairs(WS:GetDescendants()) do
        if obj:IsA("Tool") and (obj.Name:lower():find("gun") or obj.Name:lower():find("revolver") or obj.Name:lower():find("pistol")) then
            if not obj.Parent:IsA("Backpack") and not obj.Parent:FindFirstChildOfClass("Humanoid") then
                local handle = obj:FindFirstChild("Handle")
                if handle then return obj, handle end
            end
        end
    end
    return nil
end

-------------------------------------------------------
-- Prediction
-------------------------------------------------------
local function getVel(ch)
    local hrp = ch:FindFirstChild("HumanoidRootPart")
    if not hrp then return Vector3.zero end
    local id = ch:GetFullName()
    local now = tick()
    local c = VelCache[id]
    if c and (now - c.T) > 0 and (now - c.T) < 0.5 then
        local v = (hrp.Position - c.P) / (now - c.T)
        VelCache[id] = {P=hrp.Position, T=now}
        return v
    end
    VelCache[id] = {P=hrp.Position, T=now}
    return Vector3.zero
end

local function predict(part, ch)
    if not CFG.Prediction then return part.Position end
    local vel = getVel(ch)
    local dist = (part.Position - Camera.CFrame.Position).Magnitude
    return part.Position + vel * (dist / 1000) * CFG.PredScale
end

-------------------------------------------------------
-- Target Selection
-------------------------------------------------------
local function getBestTarget()
    local best, bestD = nil, CFG.FOV
    local ctr = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    
    for _, p in ipairs(Players:GetPlayers()) do
        if p == LP then continue end
        local ch = p.Character
        if not ch then continue end
        local hum = ch:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then continue end
        
        local part = ch:FindFirstChild(CFG.TargetPart) or ch:FindFirstChild("Head")
        if not part then continue end
        
        local pred = predict(part, ch)
        local sp, vis = Camera:WorldToViewportPoint(pred)
        if not vis then continue end
        
        local d = (Vector2.new(sp.X, sp.Y) - ctr).Magnitude
        if d < bestD then
            -- Visible check (wallbang off)
            if not CFG.Wallbang then
                local rp = RaycastParams.new()
                rp.FilterType = Enum.RaycastFilterType.Exclude
                rp.FilterDescendantsInstances = {LP.Character, Camera}
                local r = WS:Raycast(Camera.CFrame.Position, part.Position - Camera.CFrame.Position, rp)
                if r and not r.Instance:IsDescendantOf(ch) then continue end
            end
            bestD = d
            best = {
                Player = p, Character = ch, Part = part,
                Predicted = pred, ScreenPos = Vector2.new(sp.X, sp.Y),
                Dist = (part.Position - Camera.CFrame.Position).Magnitude,
                Role = getRole(p),
            }
        end
    end
    return best
end

-------------------------------------------------------
-- 핵심: Silent Aim Hooks
-------------------------------------------------------
-- 1. __namecall 후킹
local oldNC
Hooks.namecall = newcclosure(function(self, ...)
    local m = getnamecallmethod()
    
    if CFG.SilentAim and Target and Target.Part and Target.Part.Parent then
        local pp = Target.Predicted or Target.Part.Position
        
        -- Raycast 후킹
        if m == "Raycast" and self == WS then
            local a = {...}
            if typeof(a[1]) == "Vector3" and typeof(a[2]) == "Vector3" then
                local origin = a[1]
                local newDir = (pp - origin).Unit * a[2].Magnitude
                -- Wallbang: RaycastParams에서 벽 제거
                if CFG.Wallbang and typeof(a[3]) == "RaycastParams" then
                    -- 그대로 통과 (벽 무시)
                end
                return oldNC(self, origin, newDir, select(3, ...))
            end
        end
        
        -- FindPartOnRay 계열
        if m == "FindPartOnRayWithIgnoreList" or m == "FindPartOnRay" then
            local a = {...}
            if typeof(a[1]) == "Ray" then
                local o = a[1].Origin
                local d = (pp - o).Unit * a[1].Direction.Magnitude
                a[1] = Ray.new(o, d)
                return oldNC(self, unpack(a))
            end
        end
    end
    
    return oldNC(self, ...)
end)
oldNC = hookmetamethod(game, "__namecall", Hooks.namecall)

-- 2. Mouse 스푸핑
local mt = getrawmetatable(Mouse)
if mt then
    pcall(function() if setreadonly then setreadonly(mt, false) end end)
    Hooks.oldIndex = mt.__index
    mt.__index = newcclosure(function(s, k)
        if CFG.SilentAim and Target and Target.Part and Target.Part.Parent then
            local pos = Target.Predicted or Target.Part.Position
            if k == "Hit" then return CFrame.new(pos) end
            if k == "UnitRay" then
                return Ray.new(Camera.CFrame.Position, (pos - Camera.CFrame.Position).Unit)
            end
            if k == "Target" then return Target.Part end
            if k == "X" then return (Camera:WorldToViewportPoint(pos)).X end
            if k == "Y" then return (Camera:WorldToViewportPoint(pos)).Y end
        end
        return Hooks.oldIndex(s, k)
    end)
end

-------------------------------------------------------
-- GUI
-------------------------------------------------------
local Gui = Instance.new("ScreenGui")
Gui.Name = "KM_SilentAim"; Gui.DisplayOrder = 2147483647
Gui.ResetOnSpawn = false; Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling; Gui.IgnoreGuiInset = true
pcall(function()
    if gethui then Gui.Parent = gethui()
    elseif syn and syn.protect_gui then syn.protect_gui(Gui); Gui.Parent = game:GetService("CoreGui")
    else Gui.Parent = game:GetService("CoreGui") end
end)

local CL = {
    bg=Color3.fromRGB(16,16,22), card=Color3.fromRGB(24,24,32),
    accent=Color3.fromRGB(130,90,220), on=Color3.fromRGB(80,220,120), off=Color3.fromRGB(220,65,65),
    text=Color3.fromRGB(225,225,235), sub=Color3.fromRGB(115,115,135),
    border=Color3.fromRGB(40,40,52), slBg=Color3.fromRGB(40,40,54),
}

local Main = Instance.new("Frame", Gui)
Main.Size = UDim2.new(0,280,0,500); Main.Position = UDim2.new(1,-300,0,20)
Main.BackgroundColor3 = CL.bg; Main.BorderSizePixel = 0
Instance.new("UICorner", Main).CornerRadius = UDim.new(0,10)
Instance.new("UIStroke", Main).Color = CL.border

-- Title
local Title = Instance.new("Frame", Main)
Title.Size = UDim2.new(1,0,0,40); Title.BackgroundColor3 = CL.card; Title.BorderSizePixel = 0
Instance.new("UICorner", Title).CornerRadius = UDim.new(0,10)
local tf = Instance.new("Frame", Title); tf.Size = UDim2.new(1,0,0,10)
tf.Position = UDim2.new(0,0,1,-10); tf.BackgroundColor3 = CL.card; tf.BorderSizePixel = 0
local tl = Instance.new("TextLabel", Title)
tl.Size = UDim2.new(1,-16,1,0); tl.Position = UDim2.new(0,14,0,0); tl.BackgroundTransparency = 1
tl.Text = "Korean Murder - Silent Aim"; tl.TextColor3 = CL.text; tl.TextSize = 14
tl.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Bold)
tl.TextXAlignment = Enum.TextXAlignment.Left

-- Drag
do local dr,ds,sp
    Title.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dr=true;ds=i.Position;sp=Main.Position end end)
    UIS.InputChanged:Connect(function(i) if dr and i.UserInputType==Enum.UserInputType.MouseMovement then local d=i.Position-ds;Main.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then dr=false end end)
end

-- Content
local Con = Instance.new("ScrollingFrame", Main)
Con.Size = UDim2.new(1,-16,1,-50); Con.Position = UDim2.new(0,8,0,44)
Con.BackgroundTransparency = 1; Con.BorderSizePixel = 0; Con.ScrollBarThickness = 2
Con.ScrollBarImageColor3 = CL.accent; Con.AutomaticCanvasSize = Enum.AutomaticSize.Y
Con.CanvasSize = UDim2.new(0,0,0,0)
Instance.new("UIListLayout", Con).Padding = UDim.new(0,5)

-- UI 빌더
local function lbl(t)
    local l = Instance.new("TextLabel", Con); l.Size = UDim2.new(1,0,0,16)
    l.BackgroundTransparency = 1; l.Text = "  "..t; l.TextColor3 = CL.accent; l.TextSize = 10
    l.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Bold)
    l.TextXAlignment = Enum.TextXAlignment.Left
end

local function crd(h)
    local f = Instance.new("Frame", Con); f.Size = UDim2.new(1,0,0,h or 36)
    f.BackgroundColor3 = CL.card; f.BorderSizePixel = 0
    Instance.new("UICorner", f).CornerRadius = UDim.new(0,7); return f
end

local refreshFns = {}
local function tog(name, get, set)
    local c = crd(36)
    local l = Instance.new("TextLabel", c)
    l.Size = UDim2.new(1,-62,1,0); l.Position = UDim2.new(0,10,0,0)
    l.BackgroundTransparency = 1; l.Text = name; l.TextColor3 = CL.text; l.TextSize = 13
    l.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Medium)
    l.TextXAlignment = Enum.TextXAlignment.Left
    local bg = Instance.new("Frame", c)
    bg.Size = UDim2.new(0,36,0,18); bg.Position = UDim2.new(1,-46,0.5,-9)
    bg.BackgroundColor3 = get() and CL.on or CL.off; bg.BorderSizePixel = 0
    Instance.new("UICorner", bg).CornerRadius = UDim.new(1,0)
    local dot = Instance.new("Frame", bg)
    dot.Size = UDim2.new(0,14,0,14); dot.BackgroundColor3 = Color3.new(1,1,1); dot.BorderSizePixel = 0
    dot.Position = get() and UDim2.new(1,-16,0,2) or UDim2.new(0,2,0,2)
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1,0)
    local function rf()
        TS:Create(bg, TweenInfo.new(0.15), {BackgroundColor3 = get() and CL.on or CL.off}):Play()
        TS:Create(dot, TweenInfo.new(0.15,Enum.EasingStyle.Quad,Enum.EasingDirection.Out), {
            Position = get() and UDim2.new(1,-16,0,2) or UDim2.new(0,2,0,2)}):Play()
    end
    local btn = Instance.new("TextButton", c)
    btn.Size = UDim2.new(1,0,1,0); btn.BackgroundTransparency = 1; btn.Text = ""; btn.ZIndex = 5
    btn.MouseButton1Click:Connect(function() set(not get()); rf() end)
    refreshFns[name] = rf
    return rf
end

local function sld(name, mn, mx, get, set)
    local c = crd(48)
    local l = Instance.new("TextLabel", c)
    l.Size = UDim2.new(1,-46,0,20); l.Position = UDim2.new(0,10,0,2)
    l.BackgroundTransparency = 1; l.Text = name; l.TextColor3 = CL.text; l.TextSize = 12
    l.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Medium)
    l.TextXAlignment = Enum.TextXAlignment.Left
    local vl = Instance.new("TextLabel", c)
    vl.Size = UDim2.new(0,36,0,20); vl.Position = UDim2.new(1,-46,0,2)
    vl.BackgroundTransparency = 1; vl.TextColor3 = CL.accent; vl.TextSize = 12
    vl.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Bold)
    vl.TextXAlignment = Enum.TextXAlignment.Right
    local bar = Instance.new("Frame", c)
    bar.Size = UDim2.new(1,-20,0,5); bar.Position = UDim2.new(0,10,0,32)
    bar.BackgroundColor3 = CL.slBg; bar.BorderSizePixel = 0
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1,0)
    local fill = Instance.new("Frame", bar)
    fill.BackgroundColor3 = CL.accent; fill.BorderSizePixel = 0
    Instance.new("UICorner", fill).CornerRadius = UDim.new(1,0)
    local knob = Instance.new("Frame", bar)
    knob.Size = UDim2.new(0,10,0,10); knob.BackgroundColor3 = Color3.new(1,1,1)
    knob.BorderSizePixel = 0; knob.ZIndex = 3
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1,0)
    local function rf()
        local p = (get()-mn)/(mx-mn)
        fill.Size = UDim2.new(p,0,1,0); knob.Position = UDim2.new(p,-5,0.5,-5)
        local v = get(); vl.Text = v==math.floor(v) and tostring(math.floor(v)) or string.format("%.1f",v)
    end
    rf()
    local drag = false
    local hb = Instance.new("TextButton", bar)
    hb.Size = UDim2.new(1,6,0,18); hb.Position = UDim2.new(0,-3,0.5,-9)
    hb.BackgroundTransparency = 1; hb.Text = ""; hb.ZIndex = 5
    local function upd(i)
        local r = math.clamp((i.Position.X-bar.AbsolutePosition.X)/bar.AbsoluteSize.X,0,1)
        local step = (mx-mn>=10) and 1 or 0.1
        local v = math.clamp(math.floor((mn+(mx-mn)*r)/step+0.5)*step, mn, mx)
        set(v); rf()
    end
    hb.InputBegan:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=true;upd(i) end end)
    UIS.InputChanged:Connect(function(i) if drag and i.UserInputType==Enum.UserInputType.MouseMovement then upd(i) end end)
    UIS.InputEnded:Connect(function(i) if i.UserInputType==Enum.UserInputType.MouseButton1 then drag=false end end)
end

local function btn(name, cb)
    local c = crd(32)
    local b = Instance.new("TextButton", c)
    b.Size = UDim2.new(1,-8,1,-6); b.Position = UDim2.new(0,4,0,3)
    b.BackgroundColor3 = CL.slBg; b.BorderSizePixel = 0; b.Text = name
    b.TextColor3 = CL.text; b.TextSize = 13
    b.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Medium)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,6)
    b.MouseButton1Click:Connect(cb)
end

local function dropdown(name, opts, get, set)
    local c = crd(36)
    local l = Instance.new("TextLabel", c)
    l.Size = UDim2.new(0.5,0,1,0); l.Position = UDim2.new(0,10,0,0)
    l.BackgroundTransparency = 1; l.Text = name; l.TextColor3 = CL.text; l.TextSize = 12
    l.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Medium)
    l.TextXAlignment = Enum.TextXAlignment.Left
    local idx = table.find(opts, get()) or 1
    local b = Instance.new("TextButton", c)
    b.Size = UDim2.new(0,95,0,24); b.Position = UDim2.new(1,-105,0.5,-12)
    b.BackgroundColor3 = CL.slBg; b.BorderSizePixel = 0
    b.Text = " "..opts[idx].." "; b.TextColor3 = CL.accent; b.TextSize = 11
    b.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Medium)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,5)
    b.MouseButton1Click:Connect(function()
        idx = idx%#opts+1; b.Text = " "..opts[idx].." "; set(opts[idx])
    end)
end

-------------------------------------------------------
-- Status Card
-------------------------------------------------------
local sc = crd(50)
local sdot = Instance.new("Frame", sc)
sdot.Size = UDim2.new(0,10,0,10); sdot.Position = UDim2.new(0,10,0,8)
sdot.BackgroundColor3 = CL.off; sdot.BorderSizePixel = 0
Instance.new("UICorner", sdot).CornerRadius = UDim.new(1,0)
local slbl = Instance.new("TextLabel", sc)
slbl.Size = UDim2.new(1,-28,0,16); slbl.Position = UDim2.new(0,26,0,5)
slbl.BackgroundTransparency = 1; slbl.Text = "OFF - V to toggle"; slbl.TextColor3 = CL.sub
slbl.TextSize = 13; slbl.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Bold)
slbl.TextXAlignment = Enum.TextXAlignment.Left
local tlbl = Instance.new("TextLabel", sc)
tlbl.Size = UDim2.new(1,-28,0,14); tlbl.Position = UDim2.new(0,26,0,24)
tlbl.BackgroundTransparency = 1; tlbl.Text = "Target: -"; tlbl.TextColor3 = CL.sub
tlbl.TextSize = 11; tlbl.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Regular)
tlbl.TextXAlignment = Enum.TextXAlignment.Left
local rlbl = Instance.new("TextLabel", sc)
rlbl.Size = UDim2.new(1,-28,0,14); rlbl.Position = UDim2.new(0,26,0,36)
rlbl.BackgroundTransparency = 1; rlbl.Text = "Role: -"; rlbl.TextColor3 = CL.sub
rlbl.TextSize = 10; rlbl.FontFace = Font.new("rbxasset://fonts/families/Ubuntu.json", Enum.FontWeight.Regular)
rlbl.TextXAlignment = Enum.TextXAlignment.Left

local function rfStatus()
    sdot.BackgroundColor3 = CFG.SilentAim and CL.on or CL.off
    slbl.Text = CFG.SilentAim and "ON - Silent Aim Active" or "OFF - V to toggle"
    slbl.TextColor3 = CFG.SilentAim and CL.on or CL.sub
end

-------------------------------------------------------
-- Build UI
-------------------------------------------------------
lbl("SILENT AIM")
local rfSA = tog("Silent Aim", function() return CFG.SilentAim end, function(v) CFG.SilentAim=v; rfStatus() end)
tog("Wallbang (벽 관통)", function() return CFG.Wallbang end, function(v) CFG.Wallbang=v end)
tog("Prediction (예측)", function() return CFG.Prediction end, function(v) CFG.Prediction=v end)
sld("FOV", 30, 400, function() return CFG.FOV end, function(v) CFG.FOV=v end)
sld("Pred. Scale", 0.1, 3.0, function() return CFG.PredScale end, function(v) CFG.PredScale=v end)
dropdown("Target Part", {"Head","HumanoidRootPart","UpperTorso"}, function() return CFG.TargetPart end, function(v) CFG.TargetPart=v end)

lbl("AUTOMATION")
tog("Auto Shoot", function() return CFG.AutoShoot end, function(v) CFG.AutoShoot=v end)
tog("Auto Grab Gun", function() return CFG.AutoGrabGun end, function(v) CFG.AutoGrabGun=v end)

lbl("VISUALS")
tog("Show FOV", function() return CFG.ShowFOV end, function(v) CFG.ShowFOV=v end)
tog("Show Target", function() return CFG.ShowTarget end, function(v) CFG.ShowTarget=v end)
tog("Murder ESP", function() return CFG.MurderESP end, function(v) CFG.MurderESP=v end)

lbl("ACTIONS")
btn("Shoot Murder", function()
    if not amISheriff() then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP and isMurder(p) then
            Target = {Player=p, Character=p.Character, Part=p.Character:FindFirstChild("Head"),
                Predicted=p.Character:FindFirstChild("Head") and p.Character.Head.Position}
            -- 총 사용 시뮬레이션
            local tool = LP.Character:FindFirstChildOfClass("Tool")
            if tool then tool:Activate() end
            break
        end
    end
end)
btn("Grab Gun", function()
    local gun, handle = findGunOnGround()
    if gun and LP.Character then
        local hrp = LP.Character:FindFirstChild("HumanoidRootPart")
        if hrp and handle then
            hrp.CFrame = handle.CFrame
            task.wait(0.1)
            -- 자동 줍기 시도
            pcall(function() LP.Character.Humanoid:EquipTool(gun) end)
        end
    end
end)

-------------------------------------------------------
-- Main Loop
-------------------------------------------------------
Conns.Render = RS.RenderStepped:Connect(function()
    Camera = WS.CurrentCamera
    local ctr = Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)
    
    -- FOV
    FOVCircle.Position = ctr; FOVCircle.Radius = CFG.FOV
    FOVCircle.Visible = CFG.ShowFOV
    FOVCircle.Color = CFG.SilentAim and CL.on or Color3.fromRGB(130,90,220)
    
    -- Target
    if CFG.SilentAim then
        Target = getBestTarget()
    else
        Target = nil
    end
    
    -- Info
    if Target then
        tlbl.Text = string.format("Target: %s (%.0f studs)", Target.Player.Name, Target.Dist)
        rlbl.Text = "Role: " .. (Target.Role or "?")
    else
        tlbl.Text = CFG.SilentAim and "Target: scanning..." or "Target: -"
        rlbl.Text = "Role: " .. getRole(LP)
    end
    
    -- Target visual
    if Target and CFG.ShowTarget then
        local sp, vis = Camera:WorldToViewportPoint(Target.Predicted or Target.Part.Position)
        if vis then
            local sv = Vector2.new(sp.X, sp.Y)
            TargetDot.Position = sv; TargetDot.Visible = true
            TargetLine.From = ctr; TargetLine.To = sv; TargetLine.Visible = true
        else TargetDot.Visible = false; TargetLine.Visible = false end
    else TargetDot.Visible = false; TargetLine.Visible = false end
    
    -- Murder ESP
    if CFG.MurderESP then
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and p.Character then
                local ch = p.Character
                local hl = ch:FindFirstChild("KM_ESP")
                if isMurder(p) then
                    if not hl then
                        hl = Instance.new("Highlight", ch)
                        hl.Name = "KM_ESP"; hl.FillColor = Color3.fromRGB(255,0,0)
                        hl.OutlineColor = Color3.fromRGB(255,60,60); hl.FillTransparency = 0.7
                    end
                else
                    if hl then hl:Destroy() end
                end
            end
        end
    else
        for _, p in ipairs(Players:GetPlayers()) do
            if p.Character then
                local hl = p.Character:FindFirstChild("KM_ESP")
                if hl then hl:Destroy() end
            end
        end
    end
    
    -- Auto Grab Gun
    if CFG.AutoGrabGun and LP.Character then
        local gun, handle = findGunOnGround()
        if gun and handle then
            local hrp = LP.Character:FindFirstChild("HumanoidRootPart")
            if hrp and (hrp.Position - handle.Position).Magnitude < 20 then
                pcall(function() LP.Character.Humanoid:EquipTool(gun) end)
            end
        end
    end
end)

-------------------------------------------------------
-- Auto Shoot Loop
-------------------------------------------------------
Conns.AutoShoot = RS.Heartbeat:Connect(function()
    if not CFG.AutoShoot or not CFG.SilentAim then return end
    if not Target or not Target.Part or not Target.Part.Parent then return end
    local tool = LP.Character and LP.Character:FindFirstChildOfClass("Tool")
    if tool then
        pcall(function() tool:Activate() end)
    end
end)

-------------------------------------------------------
-- Input
-------------------------------------------------------
Conns.Input = UIS.InputBegan:Connect(function(i, gpe)
    if gpe then return end
    if i.KeyCode == CFG.ToggleKey then
        CFG.SilentAim = not CFG.SilentAim; rfStatus(); rfSA()
    end
    if i.KeyCode == CFG.UIKey then
        Main.Visible = not Main.Visible
    end
end)

-------------------------------------------------------
-- Cleanup
-------------------------------------------------------
local function destroy()
    for _,c in pairs(Conns) do pcall(function() c:Disconnect() end) end
    for _,d in ipairs(DrawClean) do pcall(d.Remove, d) end
    if oldNC then pcall(hookmetamethod, game, "__namecall", oldNC) end
    if Hooks.oldIndex and mt then pcall(function() mt.__index = Hooks.oldIndex end) end
    pcall(function() Gui:Destroy() end)
    -- ESP 정리
    for _,p in ipairs(Players:GetPlayers()) do
        if p.Character then
            local h = p.Character:FindFirstChild("KM_ESP"); if h then h:Destroy() end
        end
    end
    shared._KM_SilentAim = nil
end
shared._KM_SilentAim = destroy

rfStatus()
print("[KM SilentAim] Loaded! V=Toggle | RShift=Hide UI")
print("[KM SilentAim] Korean Murder (PlaceId: 5720801512)")
