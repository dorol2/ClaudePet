<h1 align="center">🐾 ClaudePet</h1>

<p align="center">
  <em>Claude Code 세션과 함께 살아 움직이는 macOS 데스크탑 펫</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2013%2B-lightgrey" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-6-orange" alt="Swift 6">
  <img src="https://img.shields.io/badge/SwiftUI%20%2B%20AppKit-blue" alt="SwiftUI + AppKit">
  <a href="https://github.com/miseon-medit/claude_pet/releases/latest"><img src="https://img.shields.io/github/v/release/miseon-medit/claude_pet" alt="Release"></a>
</p>

---

ClaudePet은 데스크탑 위에 떠다니며 **Claude Code 세션의 상태**(생각 중 · 도구 사용 · 권한 요청 · 응답 완료 등)에 실시간으로 반응하는 macOS 펫입니다.

긴 작업을 시작하고 자리를 비워도 펫이 모션으로 알려주고, 권한 요청이 오면 색이 바뀌고, 응답이 끝나면 축하 모션을 보여줍니다. 색·이모지·이미지·말풍선 등을 모두 사용자 정의할 수 있습니다.

## 🆕 최근 업데이트 — [v0.2.1](https://github.com/miseon-medit/claude_pet/releases/tag/v0.2.1)

#### 🎛️ Waiting 모션 UX 개선
- **사용 토글** — Preferences → 모션 → Waiting 맨 위 "Waiting 모션 사용" 체크박스. 끄면 waiting 이벤트 완전 무시 (다른 모션은 영향 없음).
- **진입 지연 0~3600초 (1시간)** — 슬라이더 제거, 숫자 직접 입력. 잠깐 자리 비울 때만 알림 받고 싶을 때 유용.
- **Typing 중 응답 인식** — waiting 상태에서 키 입력이 들어오면 사용자가 응답한 것으로 간주, typing 모션 → 종료 후 idle (waiting 복귀 X). Preferences → 타이핑 → 동작 옵션에서 토글.

#### 🪝 Claude Code 훅 매핑 개선
- **Notification 메시지 자동 분기** — `permission/approval` 키워드 → 🙋 permission 모션, `denied/cancel/interrupt/abort` 키워드 → `cancel` 이벤트, 그 외 → waiting.
- **세션별 done 스킵** — `cancel` 직후 2초 내 같은 세션의 Stop이 와도 축하 모션 스킵 (권한 거부 후 Claude 마무리 응답에서 done 안 뜨도록). 여러 Claude 세션 동시 작업 시 세션 간 신호 간섭 없음.

#### 🛠️ 입력 UX
- **모든 duration 직접 입력** — done/tool/typing/thinking 등 유지 시간 슬라이더 옆에 숫자 입력 필드 추가 (clamp 처리).

#### 🐛 버그 수정
- 이미지 변경/선택 버튼이 클릭해도 반응 없던 문제 (sandbox 앱 `user-selected.read-write` entitlement 누락 + LSUIElement 앱의 NSOpenPanel 포커스 문제).
- `clear` 이벤트가 thinking 상태를 해소하지 않던 빈틈.
- Xcode 자동 서명 설정 통합 (`DEVELOPMENT_TEAM` 일원화).

### 이전: [v0.2.0](https://github.com/miseon-medit/claude_pet/releases/tag/v0.2.0)

- 🎨 **외형 프리셋(테마) 시스템** — 빌트인 Default 테마 + 사용자 정의 테마 추가/수정/삭제. 메뉴바 🐾 → Theme 서브메뉴에서 빠른 전환.
- 📍 **위치 영속화** — 펫을 드래그한 마지막 위치 자동 저장, 재실행 시 같은 자리에 복귀.
- 🚀 **로그인 시 자동 시작** — `SMAppService` 기반 토글.
- ⌨️ **터미널 키 입력 감지 개선** — 감지 대상 bundle ID 목록을 Preferences에서 직접 편집.
- 🎨 **Preferences UI 개편** — NavigationSplitView 사이드바, 모션별 페이지, Tool 통합/분리 토글, 사이드바 아이콘 개편, README 가독성 개편.

전체 변경 이력은 [Releases 페이지](https://github.com/miseon-medit/claude_pet/releases) 참고.

## 📑 목차

- [✨ 기능](#-기능)
- [🚀 시작하기](#-시작하기)
- [⚙️ Preferences](#️-preferences)
- [🔌 Claude Code 훅 매핑](#-claude-code-훅-매핑)
- [🛠️ 개발 / 디버깅](#️-개발--디버깅)
- [⚠️ 알려진 제한 사항](#️-알려진-제한-사항)
- [📄 라이선스](#-라이선스)

---

## ✨ 기능

<table>
<tr>
<td valign="top" width="33%">

### 🎭 모션
- **7개 기본 모션**
- **Permission 오버레이** — 직전 상태 자동 복귀
- **모션 우선순위 규칙**
- **도구별 분리 스타일** (5종)

</td>
<td valign="top" width="33%">

### 🎨 커스터마이즈
- 색 그라데이션 + 이모지
- 이미지/GIF (NSImageView 자동 재생)
- 말풍선 템플릿 (변수 치환)
- 지속 시간 / "유지" 모드
- Waiting 진입 지연
- Thinking verb 리스트
- 펫 크기 (S/M/L)

</td>
<td valign="top" width="33%">

### 🖥️ 시스템
- 떠다니는 NSPanel
- 드래그 + 위치 자동 저장
- 메뉴바 아이콘 🐾
- 로그인 시 자동 시작
- 로컬 HTTP 서버
- 멀티 세션 추적
- 실시간 로그 뷰

</td>
</tr>
</table>

**모션 우선순위**: `permission` > `done` > `tool` > `waiting` > `thinking` > `typing` > `idle`

> 기본 빌트인 테마는 **이모지 + 그라데이션 배경**(이미지 없음). 본인 이미지/GIF는 Preferences에서 모션마다 직접 등록할 수 있습니다.

---

## 🚀 시작하기

> 요구사항: macOS 13+

### 1️⃣ 다운로드 & 설치

[**GitHub Releases**](https://github.com/miseon-medit/claude_pet/releases/latest)에서 최신 `ClaudePet-vX.Y.Z.zip` 받기.

압축 해제 후 `ClaudePet.app`을 `/Applications/`로 드래그 (또는 아래 명령):

```bash
unzip ~/Downloads/ClaudePet-v*.zip -d ~/Downloads/
mv ~/Downloads/ClaudePet.app /Applications/
```

### 2️⃣ 첫 실행 (Gatekeeper 우회)

> ⚠️ 서명 안 된 빌드라 첫 실행 시 macOS가 차단합니다.

1. Finder에서 **ClaudePet.app 우클릭 → 열기**
2. "확인되지 않은 개발자" 경고 → **열기** 클릭
3. 이후엔 더블클릭으로 그냥 실행됨

✅ 실행되면 메뉴바에 **🐾 아이콘**이 뜨고 화면 우측 하단에 펫이 떠다닙니다.

### 3️⃣ Claude Code 훅 연동

`~/.claude/settings.json` (글로벌) 또는 `<프로젝트>/.claude/settings.json`에 훅을 등록하세요.

> 이 리포의 [`.claude/settings.json`](.claude/settings.json) 내용을 그대로 복사하거나, 기존 파일이 있으면 `hooks` 블록만 병합하면 됩니다.

새 Claude Code 세션을 띄우면 펫이 반응합니다.

### 4️⃣ 펫 외형 커스터마이즈 *(선택)*

기본 이모지 + 그라데이션 외에 본인 이미지/GIF를 펫으로 쓰고 싶다면:

1. **🐾 메뉴바 → Preferences → 모션** (Idle/Waiting/Done/Tool/Thinking/Permission/Typing 각 페이지)
2. 페이지의 **"이미지 선택…"** 버튼으로 PNG/GIF/APNG/JPG 등 등록
3. (선택) Preferences → **테마** 페이지의 "현재 설정 저장…"으로 사용자 정의 테마로 묶어서 저장 → 메뉴바 🐾 → Theme 서브메뉴에서 빠르게 전환

> GIF의 경우 NSImageView가 자동 재생합니다.

### 5️⃣ Typing 모션 *(선택)*

터미널에서 타이핑할 때 typing 모션을 보고 싶으면:

1. Preferences → **Typing** → "터미널 키 입력 감지" ON
2. macOS 권한 다이얼로그 → **시스템 설정 → 손쉬운 사용**에서 ClaudePet 허용
3. 앱 재시작

> 본인 터미널이 기본 목록에 없으면 Typing 페이지의 "감지 대상 앱 (Bundle ID)" 섹션에서 추가.

---

## ⚙️ Preferences

`Cmd+,` 또는 **🐾 메뉴바 → Preferences…** 로 열기.

```
모션
  Idle / Waiting / Done / Tool / Thinking / Permission / Typing
기타
  말풍선 / 일반
개발자
  로그
```

### 모션 페이지 (공통)
- 미리보기 (클릭하면 이미지 변경)
- 이모지 / 상단 색상 / 하단 색상 / 이미지
- 지속 시간 + "유지" 토글
- 말풍선 표시 토글 + 텍스트 템플릿

### 모션별 특화 옵션

| 페이지 | 특화 옵션 |
|--------|-----------|
| **Tool** | 통합/분리 토글 + 세그먼티드 피커 (통합·Bash·Write·Edit·WebFetch·WebSearch) |
| **Waiting** | 진입 지연 숫자 입력 (0~3600초 / 1시간) |
| **Thinking** | Verb 리스트 편집기 (1.5초마다 순환) |
| **Typing** | 키 입력 감지 토글 + bundle ID 목록 편집기 |
| **일반** | 펫 크기 (S/M/L), 로그인 시 자동 시작, 기본값으로 리셋 |
| **개발자** | 실시간 HTTP 로그 토글 (최대 300개, 자동 스크롤) |

### 말풍선 템플릿 변수

| 변수 | 의미 |
|------|------|
| `{emoji}` | 해당 모션의 이모지 |
| `{label}` | waiting 세션 라벨 (여러 개면 라벨별로 줄바꿈) |
| `{tool}` | tool 모션의 도구 이름 |
| `{tool_emoji}` | 도구별 폴백 이모지 (💻/✍️/✏️/🌐/🔍) |
| `{verb}` | thinking 모션의 현재 verb |

---

## 🔌 Claude Code 훅 매핑

펫 서버는 `http://127.0.0.1:9876/event`에서 form-encoded POST를 받습니다. `.claude/settings.json`에 jq + curl을 거쳐 다음과 같이 매핑됩니다.

| Claude Code 훅 | 펫 `type` | 효과 |
|---------------|-----------|------|
| `UserPromptSubmit` | `clear` → `thinking` | 세션 정리 + thinking 모션 시작 |
| `PermissionRequest` | `permission` | 🙋 권한 오버레이 진입 (CLI에 권한 dialog 뜰 때) |
| `PermissionDenied` | `permission_resolved` | 오버레이 해제 (auto-mode classifier가 도구 차단 시) |
| `Notification` (메시지에 denied/declined/rejected/cancel/interrupt/abort 포함) | `cancel` | 세션 비움 + idle. 직후 2초 내 같은 세션 done은 축하 모션 스킵 |
| `Notification` (메시지에 permission/approval/approve/permit 포함) | `permission` | permission 오버레이 진입 (이중 보호) |
| `Notification` (그 외) | `waiting` | (선택적 지연 후) waiting 모션 |
| `Stop` | `done` | 4초간 done 축하 모션. 단, 같은 세션에서 직전에 cancel 받았으면 스킵 |
| `PreToolUse` | `tool` | 2초간 tool 모션 (도구 이름별 스타일) |
| `PostToolUse` | `permission_resolved` | permission 오버레이 해제 |

**공통 필드**: `session` (세션 ID), `label` (cwd 또는 도구 이름), `hook` (원본 훅 이름). 훅별 추가 필드: `message`, `tool` 등.

> `PermissionRequest` / `PermissionDenied`는 Claude Code 공식 훅 이벤트입니다. Notification 키워드 분기는 안전망(이중 보호)으로 함께 유지합니다.

---

## 🛠️ 개발 / 디버깅

<details>
<summary><b>📥 소스에서 빌드</b></summary>

요구사항: macOS 13+, Xcode 16+

```bash
git clone https://github.com/miseon-medit/claude_pet.git
cd claude_pet
open ClaudePet.xcodeproj    # Xcode에서 Cmd+R

# 또는 커맨드라인
xcodebuild -project ClaudePet.xcodeproj -scheme ClaudePet build
```

</details>

<details>
<summary><b>🧪 수동 테스트 (curl)</b></summary>

앱 실행 중인 상태에서 어디서든:

```bash
curl -X POST -d "type=thinking&session=t1&label=demo" http://127.0.0.1:9876/event
curl -X POST -d "type=tool&session=t1&label=Bash"     http://127.0.0.1:9876/event
curl -X POST -d "type=permission&session=t1"          http://127.0.0.1:9876/event
curl -X POST -d "type=permission_resolved&session=t1" http://127.0.0.1:9876/event
curl -X POST -d "type=done&session=t1"                http://127.0.0.1:9876/event
curl -X POST -d "type=clear&session=t1"               http://127.0.0.1:9876/event
curl http://127.0.0.1:9876/status
```

</details>

<details>
<summary><b>📋 Xcode 콘솔 로그 포맷</b></summary>

```
┌─ [14:32:01.234] POST /event
│  raw  : type=waiting&session=abc123&label=ClaudePet&hook=Notification
│  form : hook=Notification, label=ClaudePet, session=abc123, type=waiting
└─
```

기본은 비활성화. PetServer.logEvent의 `print(...)` 블록 주석 해제하면 표시됩니다. Preferences 개발자 페이지의 로그 뷰는 별도로 항상 사용 가능.

</details>

<details>
<summary><b>📁 폴더 구조</b></summary>

```
ClaudePet/                              ← 리포 루트
├── ClaudePet.xcodeproj/
├── ClaudePet/
│   ├── App/                            진입점/생명주기
│   │   ├── ClaudePetApp.swift
│   │   └── AppDelegate.swift
│   ├── Models/                         도메인 모델
│   │   ├── MotionKey.swift             motion 식별자 enum (단일 source of truth)
│   │   ├── PetState.swift              세션·모션 상태 머신
│   │   ├── Theme.swift                 빌트인/사용자 테마 정의
│   │   └── PetTheme.swift              사용자 설정 (UserDefaults 저장)
│   ├── Views/
│   │   ├── PetView.swift               펫 윈도우
│   │   ├── PreferencesView.swift       설정 UI
│   │   └── Components/
│   │       └── AnimatedImageView.swift NSImageView 래퍼 (GIF + 드래그)
│   ├── Services/                       외부 시스템 어댑터
│   │   ├── PetServer.swift             NWListener HTTP 서버
│   │   ├── KeystrokeMonitor.swift      NSEvent 글로벌 모니터
│   │   ├── ImageStore.swift            이미지 영속 저장
│   │   ├── ThemeStore.swift            사용자 정의 테마 영속 저장
│   │   └── LogStore.swift              개발자 페이지용 로그 버퍼
│   ├── Assets.xcassets/
│   └── ClaudePet.entitlements
├── ClaudePetTests/                     unit tests (Swift Testing)
├── ClaudePetUITests/                   UI tests (XCUITest)
├── .claude/settings.json               Claude Code 훅 매핑 예시
└── README.md
```

</details>

<details>
<summary><b>💾 영속화 위치</b></summary>

| 데이터 | 위치 |
|--------|------|
| 테마 설정 (색/이모지/시간/이미지경로/토글/터미널 bundle ID 등) | `UserDefaults` 키 `petTheme.v1` (JSON) |
| 펫 윈도우 마지막 위치 | `UserDefaults` 키 `ClaudePet.panelOrigin` |
| 사용자 지정 이미지 | `~/Library/Application Support/ClaudePet/images/` |
| 훅 매핑 | `.claude/settings.json` 또는 `~/.claude/settings.json` |
| 로그인 항목 등록 상태 | `SMAppService` (macOS 시스템 관리) |

</details>

---

## ⚠️ 알려진 제한 사항

- 🔐 **Typing 모션 권한** — macOS Accessibility 권한이 필요. **시스템 설정 → 손쉬운 사용**에 ClaudePet 추가 후 앱 재시작. Xcode debug 빌드는 코드 사인이 흔들리면 권한이 무효화될 수 있음.
- 🖥️ **다중 모니터** — 위치는 어느 스크린에 있든 저장되지만, 모니터 분리 시 자동으로 기본 위치(메인 디스플레이 우측 하단)로 fallback.
- 🔏 **코드 서명** — Release 빌드는 서명되지 않음. 본인 컴퓨터/개인 사용 목적. 공식 배포하려면 Apple Developer ID로 서명 + 공증 필요.
- 🚫 **Linux/Windows** — macOS 전용 (AppKit/NSPanel 기반).

---

## 📄 라이선스

별도 LICENSE 파일 추가 전까지는 개인 학습/사용 용도로 fork/수정 권장.

> 펫 이미지는 기본 제공되지 않습니다. 본인 이미지/GIF를 Preferences에서 직접 등록해서 사용하세요.
