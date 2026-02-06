--[[
    Silent Aim + Prediction
    
    기능:
    - 사일런트 에임 (화면 변화 없이 서버에서 적중 처리)
    - 자동 예측 (이동 중인 타겟의 미래 위치 계산)
    - FOV 원 / 타겟 하이라이트
    - Mouse4 토글
    
    원리:
    - hookmetamethod로 __namecall을 후킹
    - 게임의 Raycast/FindPartOnRay 호출 시 방향을 타겟으로 변조
    - getMouseLocation을 스푸핑하여 마우스 위치 위조
    
    필요 익스플로잇 API:
    hookmetamethod, newcclosure, checkcaller,
    getrawmetatable, getnamecallmethod, Drawing, cloneref
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
    assert(fn, "[SilentAim] Missing: " .. name .. " - Use a supported executor.")
end

-- 중복 방지
if shared._SilentAimActive then
    shared._SilentAimActive()
    task.wait(0.2)
end

------------------------------------------------------------
-- Services
------------------------------------------------------------
local cloneref = cloneref or function(x) return x end
local Players      = cloneref(game:GetService("Players"))
local RunService   = cloneref(game:GetService("RunService"))
local UserInput    = cloneref(game:GetService("UserInputService"))
local Workspace    = cloneref(game:GetService("Workspace"))
local Camera       = Workspace.CurrentCamera
local LocalPlayer  = Players.LocalPlayer
local Mouse        = LocalPlayer:GetMouse()

------------------------------------------------------------
-- Config
------------------------------------------------------------
local Config = {
    -- 코어
    Enabled         = false,
    ToggleKey       = Enum.UserInputType.MouseButton4,

    -- 타겟팅
    FOV             = 130,
    TargetPart      = "Head",
    TeamCheck       = false,
    VisibleCheck    = false,
    MaxDistance      = 2000,

    -- 예측
    Prediction      = true,
    PredictionScale = 1.0,     -- 예측 보정 계수 (핑 보상용)

    -- 비주얼
    ShowFOV         = true,
    ShowTarget      = true,
    FOVColor        = Color3.fromRGB(100, 180, 255),
    TargetColor     = Color3.fromRGB(255, 80, 80),
}

------------------------------------------------------------
-- State
------------------------------------------------------------
local CurrentTarget = nil
local Connections   = {}
local Cleanup       = {}

------------------------------------------------------------
-- Drawing Objects
------------------------------------------------------------
local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness  = 1
FOVCircle.NumSides   = 60
FOVCircle.Filled     = false
FOVCircle.Transparency = 0.6
FOVCircle.Color      = Config.FOVColor
FOVCircle.Visible    = false

local TargetDot = Drawing.new("Circle")
TargetDot.Thickness  = 0
TargetDot.NumSides   = 20
TargetDot.Radius     = 4
TargetDot.Filled     = true
TargetDot.Transparency = 0.2
TargetDot.Color      = Config.TargetColor
TargetDot.Visible    = false

local TargetLine = Drawing.new("Line")
TargetLine.Thickness   = 1
TargetLine.Transparency = 0.5
TargetLine.Color       = Config.TargetColor
TargetLine.Visible     = false

local StatusText = Drawing.new("Text")
StatusText.Size   = 14
StatusText.Center = false
StatusText.Outline = true
StatusText.OutlineColor = Color3.new(0, 0, 0)
StatusText.Position = Vector2.new(10, 10)
StatusText.Font  = 2
StatusText.Visible = true

table.insert(Cleanup, FOVCircle)
table.insert(Cleanup, TargetDot)
table.insert(Cleanup, TargetLine)
table.insert(Cleanup, StatusText)

------------------------------------------------------------
-- Prediction: 타겟 속도 추적
------------------------------------------------------------
local VelocityCache = {}

local function getTargetVelocity(character)
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then return Vector3.zero end

    local id = character:GetFullName()
    local now = tick()
    local cache = VelocityCache[id]

    if cache then
        local dt = now - cache.Time
        if dt > 0 and dt < 0.5 then
            local vel = (hrp.Position - cache.Position) / dt
            VelocityCache[id] = { Position = hrp.Position, Time = now, Velocity = vel }
            return vel
        end
    end

    VelocityCache[id] = { Position = hrp.Position, Time = now, Velocity = Vector3.zero }
    return Vector3.zero
end

------------------------------------------------------------
-- Prediction: 도달 시간 추정 + 미래 위치 계산
------------------------------------------------------------
local function predictPosition(targetPart, character)
    if not Config.Prediction then
        return targetPart.Position
    end

    local origin = Camera.CFrame.Position
    local targetPos = targetPart.Position
    local velocity = getTargetVelocity(character)

    -- 총알 속도 추정 (대부분 Roblox FPS 게임: 500~2000 studs/s)
    -- 고정값 대신 거리 기반 도달 시간 추정
    local distance = (targetPos - origin).Magnitude
    local bulletSpeed = 1000 -- 기본 추정값
    local travelTime = distance / bulletSpeed

    -- 미래 위치 = 현재 위치 + 속도 * 도달시간 * 보정계수
    local predicted = targetPos + velocity * travelTime * Config.PredictionScale

    return predicted
end

------------------------------------------------------------
-- 타겟 선택
------------------------------------------------------------
local function isAlive(player)
    local char = player.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function isVisible(part)
    if not Config.VisibleCheck then return true end

    local origin = Camera.CFrame.Position
    local direction = (part.Position - origin)

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character, Camera }

    local result = Workspace:Raycast(origin, direction, params)
    if result then
        return result.Instance:IsDescendantOf(part.Parent)
    end
    return true
end

local function getClosestTarget()
    local best = nil
    local bestDist = Config.FOV
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not isAlive(player) then continue end

        if Config.TeamCheck and player.Team and player.Team == LocalPlayer.Team then
            continue
        end

        local char = player.Character
        local part = char:FindFirstChild(Config.TargetPart) or char:FindFirstChild("Head")
        if not part then continue end

        -- 3D 거리 체크
        local dist3D = (part.Position - Camera.CFrame.Position).Magnitude
        if dist3D > Config.MaxDistance then continue end

        -- 예측된 위치로 화면 좌표 계산
        local predicted = predictPosition(part, char)
        local screenPos, onScreen = Camera:WorldToViewportPoint(predicted)
        if not onScreen then continue end

        local screenVec = Vector2.new(screenPos.X, screenPos.Y)
        local dist2D = (screenVec - center).Magnitude

        if dist2D < bestDist then
            if isVisible(part) then
                bestDist = dist2D
                best = {
                    Player    = player,
                    Character = char,
                    Part      = part,
                    Predicted = predicted,
                    ScreenPos = screenVec,
                    Dist2D    = dist2D,
                    Dist3D    = dist3D,
                }
            end
        end
    end

    return best
end

------------------------------------------------------------
-- 사일런트 에임 핵심: __namecall 후킹
------------------------------------------------------------
local oldNamecall
local namecallHook = newcclosure(function(self, ...)
    local method = getnamecallmethod()

    if Config.Enabled and CurrentTarget and CurrentTarget.Part then
        local part = CurrentTarget.Part
        local predictedPos = CurrentTarget.Predicted or part.Position

        -- FindPartOnRayWithIgnoreList (구버전 게임)
        if method == "FindPartOnRayWithIgnoreList" then
            local args = { ... }
            if typeof(args[1]) == "Ray" then
                local origin = args[1].Origin
                local dir = (predictedPos - origin).Unit * args[1].Direction.Magnitude
                args[1] = Ray.new(origin, dir)
                return oldNamecall(self, unpack(args))
            end
        end

        -- Raycast (신버전 게임)
        if method == "Raycast" and self == Workspace then
            local args = { ... }
            if typeof(args[1]) == "Vector3" then
                local origin = args[1]
                local dir = (predictedPos - origin).Unit * args[2].Magnitude
                args[2] = dir
                return oldNamecall(self, args[1], args[2], unpack(args, 3))
            end
        end

        -- FindPartOnRay
        if method == "FindPartOnRay" then
            local args = { ... }
            if typeof(args[1]) == "Ray" then
                local origin = args[1].Origin
                local dir = (predictedPos - origin).Unit * args[1].Direction.Magnitude
                args[1] = Ray.new(origin, dir)
                return oldNamecall(self, unpack(args))
            end
        end
    end

    return oldNamecall(self, ...)
end)

oldNamecall = hookmetamethod(game, "__namecall", namecallHook)

------------------------------------------------------------
-- Mouse.Hit / Mouse.UnitRay 스푸핑 (일부 게임용)
------------------------------------------------------------
local mt = getrawmetatable(Mouse)
local oldIndex

if mt then
    local wasReadonly = false
    pcall(function()
        if setreadonly then
            wasReadonly = true
            setreadonly(mt, false)
        end
    end)

    oldIndex = mt.__index
    mt.__index = newcclosure(function(self, key)
        if Config.Enabled and CurrentTarget and CurrentTarget.Part then
            local pos = CurrentTarget.Predicted or CurrentTarget.Part.Position

            if key == "Hit" then
                return CFrame.new(pos)
            end
            if key == "UnitRay" then
                local origin = Camera.CFrame.Position
                return Ray.new(origin, (pos - origin).Unit)
            end
            if key == "Target" then
                return CurrentTarget.Part
            end
            if key == "X" then
                local sp = Camera:WorldToViewportPoint(pos)
                return sp.X
            end
            if key == "Y" then
                local sp = Camera:WorldToViewportPoint(pos)
                return sp.Y
            end
        end
        return oldIndex(self, key)
    end)

    table.insert(Cleanup, function()
        mt.__index = oldIndex
        if wasReadonly and setreadonly then
            pcall(setreadonly, mt, true)
        end
    end)
end

------------------------------------------------------------
-- 메인 업데이트 루프
------------------------------------------------------------
Connections.Render = RunService.RenderStepped:Connect(function()
    Camera = Workspace.CurrentCamera
    local center = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)

    -- FOV 원
    FOVCircle.Position = center
    FOVCircle.Radius   = Config.FOV
    FOVCircle.Visible  = Config.ShowFOV
    FOVCircle.Color    = Config.Enabled and Color3.fromRGB(80, 220, 130) or Config.FOVColor

    -- 상태 텍스트
    local status = Config.Enabled and "ON" or "OFF"
    local predTxt = Config.Prediction and ("  Pred: x" .. Config.PredictionScale) or ""
    StatusText.Text  = "[Silent Aim: " .. status .. "]  Mouse4 Toggle" .. predTxt
    StatusText.Color = Config.Enabled and Color3.fromRGB(80, 220, 130) or Color3.fromRGB(220, 80, 80)

    if Config.Enabled then
        CurrentTarget = getClosestTarget()
    else
        CurrentTarget = nil
    end

    -- 타겟 비주얼
    if CurrentTarget and Config.ShowTarget then
        local pos = CurrentTarget.Predicted or CurrentTarget.Part.Position
        local sp, onScreen = Camera:WorldToViewportPoint(pos)
        if onScreen then
            local sv = Vector2.new(sp.X, sp.Y)
            TargetDot.Position = sv
            TargetDot.Visible = true
            TargetLine.From = center
            TargetLine.To = sv
            TargetLine.Visible = true
        else
            TargetDot.Visible = false
            TargetLine.Visible = false
        end
    else
        TargetDot.Visible = false
        TargetLine.Visible = false
    end
end)

------------------------------------------------------------
-- 입력 처리: Mouse4 토글
------------------------------------------------------------
Connections.Input = UserInput.InputBegan:Connect(function(input, gpe)
    if gpe then return end

    -- Mouse4 토글
    if input.UserInputType == Config.ToggleKey then
        Config.Enabled = not Config.Enabled
    end

    -- 예측 보정 조절 (PageUp / PageDown)
    if input.KeyCode == Enum.KeyCode.PageUp then
        Config.PredictionScale = math.min(3.0, Config.PredictionScale + 0.1)
        Config.PredictionScale = math.floor(Config.PredictionScale * 10) / 10
    end
    if input.KeyCode == Enum.KeyCode.PageDown then
        Config.PredictionScale = math.max(0.1, Config.PredictionScale - 0.1)
        Config.PredictionScale = math.floor(Config.PredictionScale * 10) / 10
    end

    -- 예측 토글 (P키)
    if input.KeyCode == Enum.KeyCode.P then
        Config.Prediction = not Config.Prediction
    end

    -- FOV 조절 ([ 축소, ] 확대)
    if input.KeyCode == Enum.KeyCode.LeftBracket then
        Config.FOV = math.max(30, Config.FOV - 10)
    end
    if input.KeyCode == Enum.KeyCode.RightBracket then
        Config.FOV = math.min(500, Config.FOV + 10)
    end
end)

------------------------------------------------------------
-- 정리 함수
------------------------------------------------------------
local function destroy()
    -- 연결 해제
    for _, conn in pairs(Connections) do
        if typeof(conn) == "RBXScriptConnection" then
            conn:Disconnect()
        end
    end

    -- Drawing 제거
    for _, obj in ipairs(Cleanup) do
        if type(obj) == "function" then
            pcall(obj)
        elseif obj and obj.Remove then
            pcall(obj.Remove, obj)
        end
    end

    -- 후킹 복원
    if oldNamecall then
        pcall(hookmetamethod, game, "__namecall", oldNamecall)
    end

    shared._SilentAimActive = nil
    CurrentTarget = nil
    VelocityCache = {}
end

shared._SilentAimActive = destroy

------------------------------------------------------------
-- 로딩 완료
------------------------------------------------------------
print("[SilentAim] Loaded!")
print("[SilentAim] Mouse4    = Toggle ON/OFF")
print("[SilentAim] P         = Toggle Prediction")
print("[SilentAim] PgUp/PgDn = Prediction scale (+/- 0.1)")
print("[SilentAim] [ / ]     = FOV size (+/- 10)")
