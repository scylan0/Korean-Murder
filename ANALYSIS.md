# AntiLua Hub Script - 상세 분석 보고서

> **분석 대상**: `https://raw.githubusercontent.com/Ukrubojvo/AntiLua/run/main.lua`  
> **버전**: v1.3.5  
> **제작자**: AntiLua (Discord: .antilua.)  
> **총 코드 라인**: 510줄

---

## 목차

1. [전체 구조 요약](#1-전체-구조-요약)
2. [초기화 및 보호 메커니즘 (1~30줄)](#2-초기화-및-보호-메커니즘)
3. [printcolor 모듈 - 개발자 콘솔 커스텀 출력 (31~151줄)](#3-printcolor-모듈)
4. [LoadingUI - 로딩 화면 UI (153~377줄)](#4-loadingui---로딩-화면-ui)
5. [메인 로직 - Anti-AFK 및 게임별 스크립트 로더 (379~510줄)](#5-메인-로직)
6. [외부 의존성 및 원격 코드 로딩](#6-외부-의존성-및-원격-코드-로딩)
7. [보안 분석](#7-보안-분석)

---

## 1. 전체 구조 요약

이 스크립트는 **Roblox 익스플로잇 환경**에서 동작하는 **스크립트 허브 로더(Script Hub Loader)**입니다.  
전체 실행 흐름은 다음과 같습니다:

```
[실행 시작]
    │
    ├── 1. 환경 확인 (isfolder/makefolder 존재 확인)
    ├── 2. 중복 로딩 방지 (shared 변수 체크)
    ├── 3. 서비스 캐싱 시스템 초기화
    ├── 4. printcolor 모듈 초기화 (개발자 콘솔 색상 출력)
    ├── 5. DevConsole 감시 시작 (색상 적용 루프)
    ├── 6. LoadingUI 생성 및 애니메이션 시작
    ├── 7. Anti-AFK 적용
    ├── 8. 게임별 스크립트 분기 로딩
    │     ├── PlaceId별 전용 스크립트 존재 → 해당 스크립트 로딩
    │     ├── 오비(Obby) 게임으로 판별 → ObbyAuto.lua 로딩
    │     └── 기타 → Universal.lua 로딩
    ├── 9. 로딩 상태 텍스트 업데이트 (가짜 진행상황)
    └── 10. LoadingUI 페이드아웃 & 제거
```

---

## 2. 초기화 및 보호 메커니즘

### 2-1. 환경 검증 (1줄)

```lua
assert(isfolder and makefolder, "Unable to create folder")
```

- `isfolder`, `makefolder`은 **Roblox 익스플로잇 전용 함수**입니다.
- 정상적인 Roblox 클라이언트에는 존재하지 않으며, Synapse X, Script-Ware, Fluxus 등의 익스플로잇에서 제공됩니다.
- 이 함수들이 없으면 즉시 에러로 중단 → **익스플로잇 환경에서만 동작하도록 보장**합니다.

### 2-2. 글로벌 변수 캐싱 (2줄)

```lua
local _xpcall, _pcall, _task, _math = xpcall, pcall, task, math
```

- 빌트인 함수들을 로컬 변수에 캐싱합니다.
- **목적 1**: 성능 최적화 (글로벌 탐색 회피)
- **목적 2**: 다른 스크립트가 글로벌 함수를 후킹(hooking)하는 것에 대한 보호

### 2-3. 폴더 생성 (3~5줄)

```lua
if not isfolder("AntiLua") then
    makefolder("AntiLua")
end
```

- 익스플로잇의 workspace 디렉토리에 "AntiLua" 폴더를 생성합니다.
- 설정 파일이나 캐시 저장 용도로 추정됩니다.

### 2-4. 중복 로딩 방지 (6~11줄)

```lua
if shared.AntiLuaLoading then
    return "Already Loaded"
end
if shared.AntiLuaLoader then
    return "already"
end
```

- `shared` 테이블은 모든 스크립트 간 공유되는 글로벌 테이블입니다.
- 스크립트가 2번 이상 실행되는 것을 방지하는 **싱글톤 패턴**입니다.
- 두 개의 플래그(`AntiLuaLoading`, `AntiLuaLoader`)를 사용하여 이중 체크합니다.

### 2-5. 유틸리티 함수 `missing` (12~15줄)

```lua
local function missing(t, f, fallback)
    if type(f) == t then return f end
    return fallback
end
```

- 특정 타입의 값이 존재하는지 확인하고, 없으면 대체값(fallback)을 반환합니다.
- 주로 익스플로잇 전용 함수의 존재 여부를 체크하는 데 사용됩니다.

### 2-6. 에러 핸들러 `run` (16~22줄)

```lua
local run = function(func)
    _xpcall(func, function(err)
        shared.AntiLuaLoading = false
        shared.AntiLuaLoader = false
        warn("[AntiLua] An error has occurred!\n- Loader Script\n\n"..err)
    end)
end
```

- 모든 주요 코드 블록을 `xpcall`로 감싸서 실행합니다.
- 에러 발생 시 shared 플래그를 리셋하여 다음번 재실행을 허용합니다.
- 에러 메시지를 `warn`으로 출력합니다.

### 2-7. 서비스 캐싱 프록시 (23~29줄)

```lua
local cloneref = missing("function", cloneref, function(...) return ... end)
local Services = setmetatable({}, {
    __index = function(self, name)
        self[name] = cloneref(game:GetService(name))
        return self[name]
    end
})
```

- `cloneref`는 익스플로잇에서 제공하는 **참조 복제 함수**입니다.
  - Roblox의 탐지 시스템이 스크립트가 어떤 서비스에 접근하는지 추적하는 것을 우회하기 위해 사용됩니다.
- `Services` 테이블은 **지연 로딩(lazy loading)** 패턴을 사용합니다.
  - `Services.Players`처럼 접근하면, 최초 접근 시에만 `game:GetService("Players")`를 호출하고 결과를 캐싱합니다.

### 2-8. LocalPlayer 참조 (30줄)

```lua
local lp = Services.Players.LocalPlayer
```

- 현재 클라이언트의 플레이어 객체를 캐싱합니다.

---

## 3. printcolor 모듈

### 3-1. 개요

이 모듈은 **Roblox 개발자 콘솔(F9)에 색상이 있는 텍스트를 출력**하기 위한 해킹(hack)입니다.  
Roblox의 기본 `print()` 함수는 색상을 지원하지 않으므로, 다음과 같은 트릭을 사용합니다:

```
1. 고유 ID가 붙은 텍스트를 print()로 출력
2. 개발자 콘솔의 UI 요소(TextLabel)를 탐색
3. 고유 ID를 가진 라벨을 찾아서 TextColor3를 직접 변경
4. 원본 텍스트로 교체 (고유 ID 제거)
```

### 3-2. 핵심 함수들

**`printcolor:print(text, color, options)`** (46~96줄)
- `text`: 출력할 문자열
- `color`: `Color3`, 헥스 문자열(`"#AB3CFF"`), 또는 RGB 테이블(`{171, 60, 255}`)
- `options`: `{showTimestamp, icon}` 옵션 테이블
- 고유 ID(GUID 기반)를 텍스트 끝에 붙여서 `print()` 호출
- 300초 이상 된 메시지 데이터는 자동 정리

**`printcolor:processLabel(label)`** (98~121줄)
- 개발자 콘솔의 TextLabel을 검사하여 고유 ID가 매칭되면 색상을 적용합니다.
- 아이콘 옵션이 있으면 부모의 ImageLabel도 변경합니다.

**`printcolor:applyColors(devConsole)`** (123~129줄)
- 개발자 콘솔의 모든 자식 요소를 순회하며 `processLabel`을 호출합니다.

### 3-3. DevConsole 감시 (131~151줄)

```lua
run(function()
    _task.spawn(function()
        local DevConsole = CoreGui:WaitForChild("DevConsoleMaster", 10)
        -- 최초 색상 적용
        printcolor:applyColors(DevConsole)
        -- 새 요소 추가 시 자동 처리
        DevConsole.DescendantAdded:Connect(...)
        -- 1초마다 전체 재적용
        while _task.wait(1) do
            printcolor:applyColors(DevConsole)
        end
    end)
end)
```

- `CoreGui.DevConsoleMaster`를 10초간 기다렸다가 감시를 시작합니다.
- `DescendantAdded` 이벤트로 새로운 라벨이 추가될 때 실시간 처리합니다.
- 1초 간격의 폴링으로 누락된 항목을 보완합니다.

---

## 4. LoadingUI - 로딩 화면 UI

### 4-1. UI 구조

```
ScreenGui ("LoadingUI")  [DisplayOrder = 최대값]
 ├── Frame ("BlurBG")  -- 반투명 검정 배경 (전체 화면)
 └── Frame ("MainContainer")  -- 중앙 카드 (360x200, 다크 테마)
      ├── UICorner (16px 라운딩)
      ├── UIStroke (테두리선)
      ├── TextLabel ("Logo")  -- "AntiLua" 제목 (28pt, 흰색, Ubuntu Bold)
      ├── TextLabel ("Subtitle")  -- "SCRIPT LOADER" (11pt, 보라색)
      ├── Frame ("ProgressBG")  -- 진행 바 배경 (300x3)
      │    ├── UICorner
      │    └── Frame ("ProgressBar")  -- 보라색 진행 바
      │         ├── UICorner
      │         └── UIGradient (보라→파란 그라데이션)
      ├── TextLabel ("Status")  -- 상태 텍스트 ("Loading Software...")
      ├── TextLabel ("PowerBy")  -- "Powered by .antilua. v1.3.5"
      ├── ImageLabel ("Shadow")  -- 그림자 효과
      └── Frame ("TopGlow")  -- 상단 미세 발광 효과
```

### 4-2. 주요 특징

- **DisplayOrder = 2147483647** (32비트 정수 최대값): 모든 다른 UI 위에 표시됩니다.
- **gethui()**: 익스플로잇의 숨겨진 UI 컨테이너를 사용합니다. 없으면 CoreGui로 폴백합니다.
- **테마**: 다크 배경(RGB 18,18,22) + 보라색 악센트(RGB 171,60,255)
- **폰트**: Ubuntu 폰트 패밀리 사용

### 4-3. 애니메이션

**시작 애니메이션 (`startLoadingAnimation`)**:
- 진행 바가 좌(-0.25)에서 우(1.0)로 1.4초간 이동하는 **인디케이터 루프**입니다.
- Sine InOut 이징으로 부드러운 왕복 효과를 줍니다.

**종료 애니메이션 (`stopLoadingAnimation`)**:
1. 진행 바가 전체 너비로 채워짐 (0.4초, "완료" 효과)
2. 0.3초 대기
3. 모든 UI 요소가 동시에 투명해짐 (0.5초)
   - TextLabel → TextTransparency = 1
   - ImageLabel → ImageTransparency = 1
   - Frame → BackgroundTransparency = 1
   - UIStroke → Transparency = 1
4. ScreenGui 전체 삭제 (`Destroy()`)

---

## 5. 메인 로직

### 5-1. 저작권 공지 출력 (380~389줄)

```lua
printcolor:print([[
    ANTILUA HUB SCRIPT
    ...
    Copyright ⓒ 2026 AntiLua Hub - Script. All Rights Reserved.
]], Color3.fromHex("#AB3CFF"), {showTimestamp = true})
```

- 개발자 콘솔에 보라색으로 저작권 공지를 출력합니다.

### 5-2. Anti-AFK 시스템 (391~406줄)

```lua
local GC = getconnections
if GC then
    -- 방법 1: Idled 이벤트의 모든 기존 연결을 비활성화
    for i,v in pairs(GC(lp.Idled)) do
        if v["Disable"] then
            v["Disable"](v)
        elseif v["Disconnect"] then
            v["Disconnect"](v)
        end
    end
else
    -- 방법 2: Idled 이벤트 발생 시 가짜 마우스 클릭
    lp.Idled:Connect(function()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 2, true, ...)
        VirtualInputManager:SendMouseButtonEvent(0, 0, 2, false, ...)
    end)
end
```

**방법 1** (getconnections 사용 가능한 익스플로잇):
- `Player.Idled` 이벤트에 연결된 **Roblox 기본 핸들러를 제거**합니다.
- Roblox가 AFK를 감지하여 킥하는 로직 자체를 무력화합니다.

**방법 2** (getconnections 없는 경우):
- Idled 이벤트가 발생할 때마다 `VirtualInputManager`로 **가짜 마우스 우클릭**을 보냅니다.
- 사용자가 활동 중인 것처럼 속입니다.

### 5-3. 게임별 스크립트 분기 로딩 (407~493줄)

전체 로딩 로직의 **핵심 부분**으로, 3단계 우선순위를 가집니다:

#### 우선순위 1: PlaceId 전용 스크립트 (408~419줄)

```lua
if game:HttpGetAsync(".../games/"..game.PlaceId) ~= "" then
    -- GitRequests 라이브러리를 통해 게임별 전용 스크립트 로딩
    local GitRequests = loadstring(game:HttpGet("...GitRequests.lua"))()
    local Repo = GitRequests.Repo("Ukrubojvo", "AntiLua")
    local content = Repo:getFileContent("games/"..game.PlaceId, "run")
    loadstring(content)()
end
```

- 현재 게임의 PlaceId에 해당하는 전용 스크립트가 GitHub에 존재하는지 확인합니다.
- 존재하면 `Roblox-GitRequests` 라이브러리를 통해 내용을 가져와 실행합니다.
- **지원되는 전용 게임 PlaceId**: `116061507956332`, `189707`, `5593470048`, `5720801512`, `7633631103`, `7633631351`, `7633631511`, `8056702588`

#### 우선순위 2: Obby 게임 (421~478줄)

```lua
local allowObbyGames = {
    ["obby"] = true,       -- 게임 이름에 "obby"가 포함되면 허용
    ["teamwork"] = false,   -- "teamwork"이 포함되면 불허
    [79785575696273] = true, -- 특정 PlaceId는 직접 지정
    ...
}
```

**판별 로직**:
1. 게임 이름에 `"obby"` 문자열이 포함되어 있는지 체크 → `ObbyAuto.lua` 실행
2. 게임 이름에 `"teamwork"`이 포함되면 obby로 취급하지 않음
3. 특정 PlaceId가 하드코딩된 목록에 있으면 값에 따라 판별
4. `false`로 설정된 PlaceId/키워드는 명시적으로 obby 자동화를 **차단**합니다

- `ObbyAuto.lua` (약 95KB): 오비 게임 자동 클리어 스크립트로 추정됩니다.

#### 우선순위 3: 범용 스크립트 (480~487줄)

```lua
loadstring(game:HttpGetAsync(".../games/Universal.lua"), "AntiLua")()
```

- 위 두 경우에 해당하지 않으면 `Universal.lua` (약 186KB) 범용 스크립트를 로딩합니다.
- 이것이 AntiLua Hub의 **메인 UI/기능**이 담긴 스크립트로 추정됩니다.

### 5-4. 가짜 로딩 진행 상태 (495~509줄)

```lua
if LoadingUI["a"] then LoadingUI["a"]["Text"] = "Loading Services..." end
_task.wait(_math.random() * 0.4 + 0.3)
-- "Loading Variables..."
-- "Loading Tables..."
-- "Loading Functions..."
-- "Loading User Interface..."
-- "Loading Assets..."
-- "Finalizing Setup..."
```

- **이 로딩 상태 메시지들은 순전히 시각적 효과(cosmetic)**입니다.
- 실제 해당 작업을 수행하지 않으며, 랜덤 딜레이(0.3~1.5초)로 "로딩 중"인 것처럼 보이게 합니다.
- 실제 스크립트 로딩은 `_task.spawn`으로 **비동기 병렬 실행** 중입니다.
- 모든 가짜 진행이 끝나면 `stopLoadingAnimation()`을 호출하여 UI를 제거합니다.

---

## 6. 외부 의존성 및 원격 코드 로딩

이 스크립트가 원격으로 로딩하는 코드들:

| 소스 | 설명 | 크기 |
|------|------|------|
| `games/{PlaceId}` | 게임별 전용 스크립트 (8개 게임) | 36KB ~ 463KB |
| `games/ObbyAuto.lua` | 오비 자동 클리어 | ~95KB |
| `games/Universal.lua` | 범용 스크립트 허브 | ~186KB |
| `Roblox-GitRequests/GitRequests.lua` | GitHub API 래퍼 (외부 저장소) | - |

**모든 실제 기능은 이 외부 스크립트들에 구현되어 있으며**, `main.lua`는 순수한 **로더/부트스트래퍼**입니다.

---

## 7. 보안 분석

### 사용된 익스플로잇 전용 API

| 함수/기능 | 용도 |
|-----------|------|
| `isfolder` / `makefolder` | 파일시스템 접근 |
| `cloneref` | 서비스 참조 복제 (탐지 우회) |
| `gethui()` | 숨겨진 UI 컨테이너 |
| `getconnections` | 이벤트 연결 목록 접근 |
| `game:HttpGet` / `game:HttpGetAsync` | HTTP 요청 (원격 코드 다운로드) |
| `loadstring` | 문자열을 코드로 실행 |
| `VirtualInputManager` | 가짜 입력 시뮬레이션 |
| `shared` | 전역 공유 상태 |

### 주요 특성 정리

1. **원격 코드 실행(RCE)**: `loadstring(game:HttpGet(...))()` 패턴을 통해 GitHub에서 코드를 다운로드하여 실시간으로 실행합니다. 원격 코드가 변경되면 사용자에게 통보 없이 다른 코드가 실행될 수 있습니다.
2. **Anti-AFK**: 20분 비활동 킥을 우회합니다.
3. **탐지 우회**: `cloneref`, `gethui()` 등을 사용하여 Roblox의 익스플로잇 탐지를 회피하려 합니다.
4. **에러 복구**: 모든 주요 블록을 `xpcall`로 감싸서 하나가 실패해도 다른 부분이 계속 동작합니다.
5. **중복 실행 방지**: `shared` 변수를 사용한 싱글톤 패턴.

---

## 요약

`main.lua`는 **AntiLua Hub v1.3.5의 부트스트래퍼**입니다. 자체적으로 게임을 조작하는 기능은 거의 없으며(Anti-AFK 제외), 주요 역할은:

1. 익스플로잇 환경을 검증하고
2. 보라색 테마의 로딩 UI를 표시하면서
3. 현재 게임에 맞는 적절한 외부 스크립트를 GitHub에서 다운로드하여 실행하는 것입니다.

실제 치트/핵 기능은 `Universal.lua` (186KB), `ObbyAuto.lua` (95KB), 또는 게임별 전용 스크립트에 구현되어 있습니다.

---

## 8. Universal.lua 분석

### 8-1. 개요

`Universal.lua`는 **186,260 바이트 / 1줄**로 구성된 **심하게 난독화(obfuscated)**된 파일입니다.  
정상적인 Lua 코드가 아니라, **커스텀 VM(가상 머신) 기반 난독화 기법**으로 보호되어 있습니다.

### 8-2. 난독화 유형: Custom Lua VM Obfuscator

원본 Lua 소스 코드가 다음과 같은 과정을 거쳐 변환되었습니다:

```
[원본 Lua 소스코드]
      ↓
[커스텀 컴파일러로 바이트코드로 변환]
      ↓
[바이트코드를 인코딩된 문자열로 패킹]
      ↓
[커스텀 VM 인터프리터와 함께 하나의 Lua 파일로 출력]
      ↓
[Universal.lua] ← 이것이 최종 결과물
```

### 8-3. 파일 구조

전체 파일이 하나의 `return` 문입니다:

```lua
return({
    ab = function(...) ... end,
    Ty = function(...) ... end,
    R  = function(...) ... end,
    vy = bit32.bnot,
    ...
    -- 총 ~213개의 키-값 쌍
    Q  = setmetatable
}):Gy()(...)
```

- 거대한 **테이블 리터럴**을 생성하고
- 그 테이블의 `:Gy()` 메서드를 호출하여 **VM을 초기화**
- 반환된 함수를 `(...)` 로 즉시 실행

### 8-4. VM 내부 구조 분석

| 구성 요소 | 상세 |
|-----------|------|
| **전체 함수 수** | 113개 |
| **VM 옵코드 수** | 48개 (11 ~ 61167 범위) |
| **인코딩된 바이트코드 문자열** | 31개 (최대 9,214자) |
| **VM 디스패치 루프** | 23개의 `until false` 루프 |
| **16진수 리터럴** | 1,044개 |
| **2진수 리터럴** | 483개 |
| **엔트리 포인트** | `:Gy()` 메서드 |

#### VM 레지스터 시스템

VM은 레지스터 기반 아키텍처를 사용합니다:

| 심볼 | 역할 |
|------|------|
| `R` | 레지스터 배열 (값 저장) |
| `N[V]`, `T[V]`, `l[V]` | 인스트럭션 오퍼랜드 (레지스터 인덱스) |
| `x[V]` | 상수 테이블 접근 |
| `G[V]` | 글로벌/부가 데이터 접근 |
| `I[N[V]]` | 업밸류(upvalue) 접근 |
| `V` | 프로그램 카운터 (PC) |
| `p` | 스택 탑 포인터 |

#### 48개 VM 옵코드

```
일반 옵코드 (0~199):
  11, 20, 22, 36, 39, 41, 45, 48, 55, 58, 61, 64, 74, 77, 79, 80,
  83, 85, 89, 95, 97, 108, 111, 116, 124, 127, 130, 133, 136, 139,
  152, 155, 158, 167, 170, 172, 180, 183, 186, 189, 195, 197, 199

특수 옵코드 (대형 값):
  18791, 20354, 32741, 47002, 61167
```

옵코드 디스패치는 **이진 탐색(binary search) 스타일**의 중첩 `if` 문으로 구현되어 있습니다:

```lua
if j < 100 then
    if j < 50 then
        if j == 11 then ... -- LOADK?
        elseif j == 20 then ... -- MOVE?
        ...
    end
end
```

### 8-5. 참조된 Roblox API

VM 내부에서 직접 참조되는 Roblox 전역 변수/서비스들:

| API | 출현 횟수 | 용도 추정 |
|-----|-----------|-----------|
| `bit32` (band, bxor, lshift, rshift, bnot, rrotate, bor, lrotate) | 15 | VM 바이트코드 디코딩 |
| `string` (byte, sub, char, len) | 5 | 문자열 디코딩 |
| `unpack` | 5 | 테이블 언패킹 |
| `table` (create 등) | 3 | VM 레지스터/스택 관리 |
| `coroutine` | 2 | 비동기 실행 |
| `setmetatable` / `getmetatable` | 2/1 | 메타테이블 조작 |
| `select` | 2 | 가변 인자 처리 |
| `configFile` | 2 | 익스플로잇 설정 파일 접근 |
| `checkcaller` | 1 | 호출자 검증 (탐지 우회) |
| `rawset` / `rawget` | 1/1 | 메타메서드 우회 직접 접근 |
| `game`, `workspace`, `Instance`, `Enum` | 각 1 | Roblox 코어 |
| `Color3`, `Vector2`, `Vector3` | 각 1 | 값 타입 |
| `UDim`, `UDim2`, `CFrame` | 각 1 | UI/3D 위치 |
| `TweenInfo`, `Font` | 각 1 | 애니메이션/폰트 |
| `loadstring`, `require` | 각 1 | 동적 코드 로딩 |
| `pcall`, `xpcall` | 각 1 | 에러 핸들링 |

### 8-6. 발견된 기능 키워드

난독화를 뚫고 발견된 키워드 (부분적):

| 키워드 | 출현 | 추정 기능 |
|--------|------|-----------|
| `Teleport` | 1 | 텔레포트 기능 |
| `ESP` | 1 | 플레이어/아이템 투시(ESP) |
| `God` | 1 | 갓모드 (무적) |

> **주의**: 난독화로 인해 대부분의 문자열이 인코딩되어 있어, 실제 기능은 이보다 훨씬 많을 것으로 추정됩니다.

### 8-7. 결론

`Universal.lua`는 **커스텀 VM 난독화**로 완전히 보호되어 있어, 정적 분석만으로는 원본 로직을 복원하는 것이 사실상 불가능합니다.

확인할 수 있는 사실:
- **48개 옵코드**를 가진 완전한 VM 인터프리터
- **31개의 인코딩된 바이트코드 블록**에 실제 로직이 저장됨
- Roblox UI, 3D, 네트워킹 관련 API를 광범위하게 사용
- `checkcaller`, `configFile` 등 익스플로잇 전용 API 참조
- ESP, Teleport, God 등의 치트 기능 키워드 존재
- 디난독화(deobfuscation)를 위해서는 VM의 옵코드를 하나하나 역분석하거나, 런타임에서 후킹하여 디코딩된 문자열/함수 호출을 추적해야 합니다
