# ClaudePet

macOS 데스크탑 펫 앱. Claude CLI hook으로부터 이벤트 받아 캐릭터 모션 표시.

## 빌드/실행
- Xcode에서 Cmd+R, 또는
- `xcodebuild -project ClaudePet.xcodeproj -scheme ClaudePet build`

## 아키텍처
- ClaudePetApp.swift: @main, AppDelegate 어댑터
- AppDelegate.swift: @MainActor, NSPanel/메뉴바/서버 셋업
- PetState.swift: @MainActor ObservableObject, 세션 dict 관리
- PetView.swift: SwiftUI, sprite 애니메이션
- PetServer.swift: NWListener 기반 HTTP 서버, localhost:9876

## 주의
- Swift 6 strict concurrency 모드
- UI 다루는 곳은 모두 @MainActor
- App Sandbox 켠 상태에서 Network > Incoming Connections (Server) 권한 필요
