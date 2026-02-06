# Universal.lua 디옵퓨스케이션 보고서

> **파일**: `games/Universal.lua`  
> **원본 크기**: 186,260 바이트 (1줄)  
> **디코딩된 바이트코드**: 112,444 바이트  
> **난독화 유형**: 커스텀 Lua VM (가상 머신) 기반

---

## 1. 난독화 구조 요약

```
Universal.lua (186KB, 1줄)
│
├── 전체가 하나의 return 문: return({...}):Gy()(...)
│
├── 최상위 테이블: ~213개의 키-값 쌍
│   ├── VM 인터프리터 함수들 (48개 옵코드 처리)
│   ├── 바이트코드 디시리얼라이저
│   ├── Ascii85 디코더
│   ├── bit32 헬퍼 (band, bxor, bor, bnot, lshift, rshift, rrotate, lrotate)
│   └── 문자열/숫자 디코더
│
├── 인코딩된 데이터: [==[...]==] (138,639자 Ascii85)
│   └── 디코딩 → 112,444 바이트 바이트코드
│       ├── 4바이트 헤더: C2 C4 05 00
│       ├── 상수 테이블: 158개 항목
│       │   ├── 문자열 상수: 116개
│       │   ├── 실수(double) 상수: 23개
│       │   ├── 정수(int) 상수: 17개
│       │   └── 불리언/nil 상수: 2개
│       └── 인스트럭션 + 중첩 프로토타입: ~111KB
│
└── 엔트리 포인트: :Gy() → VM 초기화 및 실행
```

---

## 2. Ascii85 디코딩

### 인코딩 방식

Lua 코드 내의 디코더:

```lua
-- 1단계: 'z' → '!!!!!' (제로 축약)
K = string.gsub(K, "z", "!!!!!")

-- 2단계: 5문자씩 그룹으로 Base-85 디코딩
string.gsub(K, ".....", function(X)
    local j, x, T, H, l = string.byte(X, 1, 5)
    local a = (l-33) + (H-33)*85 + (T-33)*7225 + (x-33)*614125 + (j-33)*52200625
    return string.pack('>I4', a)  -- Big-endian 32비트
end)
```

### 디코딩 결과

- **입력**: 138,639자 Ascii85 텍스트 (앞 4자 'LPH@' 스킵)
- **출력**: 112,444 바이트 바이너리
- **에러**: 0건 (100% 성공)

---

## 3. 상수 테이블 (158개 항목)

### 문자열 상수 (116개)

주로 **VM 인프라스트럭처** 관련 문자열:

#### 메타메서드 (16개)
```
__index, __newindex, __call, __tostring, __metatable,
__eq, __lt, __le, __add, __sub, __mul, __div, __mod, __pow, __concat, __type
```

#### 문자열 라이브러리 (12개)
```
string, gmatch, gsub, find, match, format, sub, byte, char, rep, concat, pack
```

#### 비트 연산 라이브러리 (6개)
```
bxor, bor, band, rrotate, countlz, countrz
```

#### 테이블 라이브러리 (3개)
```
table, insert, unpack
```

#### 타입명 (4개)
```
boolean, number, table, string
```

#### 기타
```
context_type, :(%d+)[:\r\n], .?, #, 1
```

#### 단일/이중 문자 키 (~70개)
```
n, C, V, r, J, R, h, e, p, s, X, d, H, Z, u, Q, f, o, U, v, G, W, t, M, q, T, m, k, S, I, i, _, P, a, Y, y, b, A, c, N, w, l, E, K, j, x, O, F, g, #, ar, Gr, Vr, Or, pr, tr, Ur, Rr, Tr, nr, kr, ur, Yr, Ir, hr, br, Fr, D
```

> **참고**: 단일/이중 문자 상수는 VM 내부의 테이블 키 또는 변수 참조로 사용됩니다. 이들은 원본 코드의 문자열이 아닌 난독화기가 생성한 축약 명칭입니다.

### 숫자 상수 (23개)

| 값 | 의미 추정 |
|---|---|
| 0.0, 1.0, 2.0, 3.0, 4.0 | 기본 수치 |
| 8.0, 16.0, 32.0, 64.0 | 비트 시프트 값 |
| 255.0, 256.0 | 바이트 범위 |
| 1023.0, 2047.0 | 비트 마스크 |
| 65536.0 (2^16) | 16비트 범위 |
| 1048576.0 (2^20) | 20비트 |
| 16777216.0 (2^24) | 24비트 |
| 2147483647.0 (2^31-1) | 32비트 signed max |
| 4294967296.0 (2^32) | 32비트 unsigned 범위 |
| 4503599627370496.0 (2^52) | IEEE 754 mantissa |
| 13213.0, 20.0, 21.0, 31.0 | 기타 |

### 정수 상수 (17개)

```
1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 14, 133, 166, 179, 239,
-3481074194, 2032517243
```

> `-3481074194`와 `2032517243`는 해시값 또는 XOR 키로 추정됩니다.

---

## 4. VM 옵코드 맵 (48개)

### 4-1. 전체 옵코드 테이블

| OP | 이름 | 동작 | 설명 |
|----|------|------|------|
| 0 | SUB | `R[l] = R[N] - R[T]` | 산술 뺄셈 |
| 1 | LEN | `R[N] = #R[l]` | 테이블/문자열 길이 |
| 2 | LOADK_Font | `R[l] = Font` | Font 글로벌 로드 |
| 3 | TFORPREP | for-state 저장; coroutine.wrap; V=T | 제너릭 for 루프 준비 |
| 4 | SETUPVAL_KC | `(I[l])[G] = a` | 업밸류 테이블에 상수 설정 |
| 5 | LOADK_mousemoverel | `R[N] = mousemoverel` | mousemoverel 글로벌 로드 |
| 6 | FORLOOP | u+=w; limit 체크; `R[T+3]=u; V=l` | 숫자 for 루프 스텝 |
| 7 | LOADK_error | `R[l] = error` | error 글로벌 로드 |
| 8 | TFORCALL | `K,H,Y,e = u(); if K then V=N` | 제너릭 for 이터레이터 호출 |
| 9 | SETTABLE | `(R[T])[x] = R[N]` | 테이블 필드 설정 |
| 10 | LT_CONST | `R[l] = (a < G)` | 상수 비교 (<) |
| 11 | JLE | `if not(G <= R[l]) then V=N` | 조건부 점프 (<=) |
| 12 | JLT | `if G < R[N] then V=l` | 조건부 점프 (<) |
| 13 | CALL_VOID | `R[p](); cleanup` | 인자/반환 없는 호출 |
| 14 | LOADK_rawset | `R[l] = rawset` | rawset 글로벌 로드 |
| 15 | GETUPVAL | `K=I[N]; R[T]=K[3][K[2]]` | 업밸류 읽기 |
| 16 | LOADK_checkcaller | `R[T] = checkcaller` | checkcaller 글로벌 로드 |
| 17 | SETUPVAL | `I[N][G] = R[l]` | 업밸류 쓰기 |
| 18 | LOADK_print | `R[N] = print` | print 글로벌 로드 |
| 19 | LOADK_configFile | `R[N] = configFile` | configFile 글로벌 로드 |
| 20 | SETUPVAL_DEEP | `K=I[N]; (K[3][K[2]])[x] = G` | 깊은 업밸류 상수 설정 |
| 21 | MUL_CONST | `R[T] = x * R[N]` | 상수 곱셈 |
| 22 | CONCAT | `R[N] = x .. R[T]` | 문자열 연결 |
| 23 | LOADK_typeof | `R[T] = typeof` | typeof 글로벌 로드 |
| 24 | VARARG | 가변인자를 레지스터에 로드 | 가변 인자 로드 |
| 25 | CALL_0A_1R | `R[p] = R[p](); cleanup` | 0인자 1반환 호출 |
| 26 | LOADK_getgenv | `R[l] = getgenv` | getgenv 글로벌 로드 |
| 27 | SETUPVAL_DEEP2 | `K=I[l]; (K[3][K[2]])[a]=R[T]` | 깊은 업밸류 레지스터 설정 |
| 28 | LOADK_gethui | `R[l] = gethui` | gethui 글로벌 로드 |
| 29 | RETURN | 업밸류 닫기; `return R[l]()` | 반환 |
| 30 | SETLIST | `X[2](R, K+1, p, Y+1, H)` | 테이블 다중 설정 |
| 31 | GETUPVAL_IDX | `K=I[l]; R[N]=K[3][K[2]][G]` | 인덱싱된 업밸류 읽기 |
| 32 | LOADK_shared | `R[N] = shared` | shared 글로벌 로드 |
| 33 | LOADK_typeof2 | `R[T] = typeof` | typeof 글로벌 로드 (2) |
| 34 | MUL | `R[T] = x * R[N]` | 곱셈 |
| 35 | UNM | `R[T] = -R[N]` | 단항 마이너스 |
| 36 | LOADK_getrawmetatable | `R[N] = getrawmetatable` | getrawmetatable 로드 |
| 37 | FORPREP | `w=R[K+2]; S=R[K+1]; u=R[K]-w; V=T` | 숫자 for 초기화 |
| 38 | CALL_1A_1R | `R[K]=R[K](R[K+1]); cleanup` | 1인자 1반환 호출 |
| 39 | LOADK_RaycastParams | `R[T] = RaycastParams` | RaycastParams 로드 |
| 40 | GE | `R[N] = (G >= x)` | 비교 (>=) |
| 41 | LOADK_isfolder | `R[l] = isfolder` | isfolder 글로벌 로드 |
| 42 | JGE | `if not(G < R[N]) then V=l` | 조건부 점프 (>=) |
| 43 | LOADK_UDim2 | `R[l] = UDim2` | UDim2 글로벌 로드 |
| 44 | SELF | `R[K+1]=R[T]; R[K]=R[T][a]` | self 메서드 호출 준비 |
| 45 | CALL_VA | `R[K](unpack(R, K+1, p))` | 가변인자 호출 |
| 46 | SETGLOBAL | `(X[1][3])[N] = R[l]` | 글로벌 설정 |
| 47 | ADD_CONST | `R[l] = G + R[N]` | 상수 덧셈 |
| 48 | LOADK_l | `R[l] = l` | 내부 배열 로드 |
| 49 | LE_CONST | `R[l] = (G <= a)` | 상수 비교 (<=) |
| 50 | ADD | `R[T] = R[N] + R[l]` | 산술 덧셈 |
| 51 | CALL_UTIL | `R[l] = X[1][14](R[N], G)` | 유틸 함수 호출 |
| 52 | LOADK_xpcall | `R[T] = xpcall` | xpcall 로드 |
| 53 | CLOSURE_RET | 업밸류 닫기; `return R[K](R[K+1])` | 클로저 반환 |
| 54 | LOADK_unpack | `R[N] = unpack` | unpack 로드 |
| 55 | VARARG_LOAD | 가변인자 → 레지스터 | 가변인자 로드 |
| 56 | GETUPVAL_TAB | `R[N] = I[l][R[T]]` | 업밸류 테이블 읽기 |
| 58 | SUB_CONST | `R[l] = a - G` | 상수 뺄셈 |

### 4-2. 카테고리별 분류

```
┌──────────────────────────────────────────────────┐
│ 글로벌 로드 (LOADK_*)          : 19개 (39.6%)     │
│ 업밸류 접근                     :  7개 (14.6%)     │
│ 산술 연산                       :  8개 (16.7%)     │
│ 비교/분기                       :  6개 (12.5%)     │
│ 함수 호출                       :  5개 (10.4%)     │
│ 제어 흐름 (for/return/vararg)  :  7개 (14.6%)     │
│ 테이블 연산                     :  3개  (6.3%)     │
│ 문자열 연산                     :  2개  (4.2%)     │
│ 글로벌 설정                     :  1개  (2.1%)     │
└──────────────────────────────────────────────────┘
```

> **핵심 관찰**: 48개 옵코드 중 **19개(39.6%)**가 특정 글로벌 변수를 로드하는 전용 옵코드입니다. 일반 VM에서는 하나의 LOADGLOBAL 옵코드가 문자열 이름으로 접근하지만, 이 VM은 각 글로벌에 고유 옵코드를 배정하여 **문자열 검색 기반 분석을 무력화**합니다.

---

## 5. 로드되는 글로벌 변수 분석 (17개)

### Roblox 코어 (3개)
| 글로벌 | 용도 |
|--------|------|
| `Font` | 텍스트 UI 폰트 생성 |
| `UDim2` | UI 요소의 크기/위치 지정 |
| `RaycastParams` | 3D 레이캐스트 매개변수 (벽뚫기/ESP 관련 가능) |

### 익스플로잇 전용 (7개)
| 글로벌 | 용도 |
|--------|------|
| `checkcaller` | 현재 호출자가 익스플로잇인지 확인 (안티치트 우회) |
| `configFile` | 익스플로잇 설정 파일 접근 |
| `getgenv` | 글로벌 환경 테이블 접근 |
| `gethui` | 숨겨진 UI 컨테이너 (Roblox 탐지 우회) |
| `getrawmetatable` | 보호된 메타테이블 직접 접근 |
| `isfolder` | 파일시스템 폴더 확인 |
| `mousemoverel` | 마우스 상대 이동 시뮬레이션 |

### Lua 표준 (7개)
| 글로벌 | 용도 |
|--------|------|
| `error` | 에러 발생 |
| `print` | 콘솔 출력 |
| `rawset` | 메타메서드 우회 테이블 설정 |
| `shared` | 전역 공유 테이블 |
| `typeof` | Roblox 타입 확인 |
| `unpack` | 테이블 언패킹 |
| `xpcall` | 보호된 함수 호출 (에러 핸들링) |

---

## 6. 추정 기능 분석

### 상수 테이블에서의 증거

1. **BigNumber/BitField 라이브러리**: 비트 연산 함수(bxor, bor, band, rrotate, countlz, countrz) + 2의 거듭제곱 상수(2^8, 2^16, 2^20, 2^24, 2^32, 2^52) + IEEE 754 관련 값(4503599627370496 = 2^52, 2047, 1023)이 포함되어 있어, VM의 최상위 프로토타입은 **커스텀 숫자/비트 연산 라이브러리**를 구현합니다.

2. **메타테이블 기반 OOP**: __index, __newindex, __call, __tostring 등 완전한 메타메서드 세트는 **객체지향 프로그래밍 프레임워크**가 포함되어 있음을 의미합니다.

3. **문자열 처리**: gmatch, gsub, find, match, format, sub, byte, char, rep, concat 등 문자열 라이브러리 함수가 포함되어 있어, 동적으로 문자열을 **런타임에 생성/조작**합니다.

### 글로벌 변수에서의 증거

| 글로벌 조합 | 추정 기능 |
|-------------|-----------|
| `Font` + `UDim2` | **커스텀 UI** (메뉴/HUD) |
| `RaycastParams` | **ESP/벽투시** 또는 에임봇 |
| `mousemoverel` | **에임봇** (마우스 자동 이동) |
| `checkcaller` + `getrawmetatable` | **안티치트 우회** |
| `gethui` | **UI 숨김** (탐지 회피) |
| `configFile` | **설정 저장/로드** |
| `shared` + `getgenv` | **다른 스크립트와 통신** |
| `isfolder` | **파일 시스템 접근** (설정/캐시) |

### 종합 추정

Universal.lua는 다음 기능을 포함하는 **범용 치트 허브 UI**로 추정됩니다:

1. **커스텀 UI 프레임워크** - Font, UDim2를 사용한 메뉴 시스템
2. **ESP (투시)** - RaycastParams를 사용한 벽 너머 플레이어/아이템 표시
3. **에임봇** - mousemoverel을 사용한 자동 조준
4. **안티탐지** - checkcaller, getrawmetatable, gethui로 Roblox 보안 우회
5. **설정 관리** - configFile, isfolder로 사용자 설정 저장/불러오기
6. **에러 복구** - xpcall로 크래시 방지

---

## 7. 디옵퓨스케이션 한계

### 완전한 디컴파일이 불가능한 이유

1. **이중 인코딩**: 원본 Lua 코드 → 커스텀 바이트코드 → Ascii85 인코딩의 2단계를 거칩니다.

2. **중첩 프로토타입**: 112KB의 디코딩된 바이너리에서 최상위 상수 테이블(158개)만 추출 가능했습니다. **실제 게임 관련 문자열**(예: "Workspace", "Character", "Humanoid", "WalkSpeed" 등)은 중첩된 프로토타입에 저장되어 있으나, 인스트럭션 포맷을 완전히 역분석하지 못해 접근할 수 없었습니다.

3. **전용 옵코드 글로벌 로딩**: 19개의 글로벌 변수가 각각 고유한 옵코드를 가지고 있어, 문자열 기반 검색으로는 찾을 수 없습니다. 이는 의도적인 안티분석 기법입니다.

4. **런타임 문자열 생성**: 단일 문자 상수가 70개 이상 존재하는 것으로 보아, 게임 관련 문자열(예: "Workspace")은 런타임에 'W'+'o'+'r'+'k'+'s'+'p'+'a'+'c'+'e' 형태로 조합될 가능성이 높습니다.

5. **미해독 인스트럭션 포맷**: 상수 테이블 이후의 ~111KB 바이너리는 인스트럭션과 중첩 프로토타입을 포함하지만, 정확한 인코딩 포맷(인스트럭션 크기, 오퍼랜드 배치)을 결정하지 못했습니다.

### 완전한 디컴파일을 위해 필요한 것

1. **런타임 트레이싱**: Roblox 익스플로잇 환경에서 VM을 실행하면서 모든 함수 호출, 문자열 생성, API 접근을 후킹하여 로깅
2. **인스트럭션 포맷 역분석**: VM의 `Cb`, `sb`, `Zb` 함수를 완전히 역분석하여 바이트코드 인코딩 이해
3. **프로토타입 파서**: 중첩된 모든 프로토타입의 상수 테이블을 추출
4. **디컴파일러**: 각 프로토타입의 인스트럭션을 Lua 소스코드로 변환

---

## 8. 생성된 파일

| 파일 | 설명 |
|------|------|
| `Universal.lua` | 원본 난독화 스크립트 (186KB, 1줄) |
| `Universal_formatted.lua` | 세미콜론 기준 줄바꿈 (3,477줄) |
| `decoded_bytecode.bin` | Ascii85 디코딩된 바이트코드 (112KB) |
| `Universal_DEOBFUSCATION.md` | 이 분석 보고서 |
