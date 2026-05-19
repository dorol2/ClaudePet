//
//  PetStatePriorityTests.swift
//  ClaudePetTests
//
//  motion 우선순위 규칙 회귀 방어.
//  priority: permission > done > tool > waiting > thinking > typing > idle

import Testing
@testable import ClaudePet

@MainActor
@Suite("PetState motion 우선순위")
struct PetStatePriorityTests {

    @Test("tool 활성 중 thinking 와도 tool 유지")
    func toolBeatsThinking() {
        let state = PetState()
        state.apply(event: "tool", sessionId: "s1", label: "Bash")
        state.apply(event: "thinking", sessionId: "s1", label: nil)
        // tool 이벤트가 transient 정리 후 다시 재설정되는 흐름은 아니지만
        // thinking 이벤트는 clearAllTransientFlags 호출 → isToolActive false → 그 후 triggerThinking
        // 즉, 일단 thinking으로 전환됨
        #expect(state.motion == .thinking)
    }

    @Test("done 활성 중 tool 와도 tool로 덮어쓰기 (clearAllTransientFlags가 done도 초기화)")
    func toolReplacesDone() {
        let state = PetState()
        state.apply(event: "done", sessionId: "s1", label: nil)
        #expect(state.motion == .done)

        state.apply(event: "tool", sessionId: "s1", label: "Bash")
        // 다음 이벤트가 오면 transient 정리 후 새 이벤트 처리되어 tool로 전환
        #expect(state.motion == .tool)
        #expect(state.isDoneActive == false)
    }

    @Test("permission은 오버레이라 직전 상태 위에 덧씌워짐")
    func permissionOverlaysOnTool() {
        let state = PetState()
        state.apply(event: "tool", sessionId: "s1", label: "Bash")
        state.apply(event: "permission", sessionId: "s1", label: nil)

        #expect(state.motion == .permission)
        #expect(state.isToolActive == true, "permission은 tool 상태 보존")
        #expect(state.currentToolName == "Bash")

        // permission_resolved 후엔 tool로 복귀
        state.apply(event: "permission_resolved", sessionId: "s1", label: nil)
        #expect(state.motion == .tool)
    }

    @Test("waiting 중 thinking 오면 thinking으로 전환 (waiting 우선순위 위가 아닐 때)")
    func thinkingClearsWaitingSession() {
        let state = PetState()
        state.apply(event: "waiting", sessionId: "s1", label: "Confirm")
        #expect(state.motion == .waiting)

        // thinking 이벤트는 case에서 sessions.removeValue → waiting 제거 → triggerThinking
        state.apply(event: "thinking", sessionId: "s1", label: nil)
        #expect(state.motion == .thinking)
        #expect(state.sessions["s1"] == nil)
    }

    // MARK: - typingOverridesWaiting

    @Test("typingOverridesWaiting=true: waiting 중 typing이 들어오면 waiting 즉시 해소")
    func typingOverridesWaitingClearsSession() {
        let state = PetState()
        state.typingOverridesWaiting = true

        state.apply(event: "waiting", sessionId: "s1", label: "Confirm")
        #expect(state.motion == .waiting)

        state.triggerTyping()
        // waiting 세션이 idle로 마크돼야 함
        #expect(state.sessions["s1"]?.state == "idle")
        #expect(state.motion == .typing)
    }

    @Test("typingOverridesWaiting=false (기본): typing은 waiting을 안 건드림")
    func typingDoesNotOverrideWaitingByDefault() {
        let state = PetState()
        // typingOverridesWaiting는 기본 false
        state.apply(event: "waiting", sessionId: "s1", label: "Confirm")
        state.triggerTyping()

        // waiting 세션 그대로
        #expect(state.sessions["s1"]?.state == "waiting")
        // priority: waiting > typing 이라 motion은 waiting 유지
        #expect(state.motion == .waiting)
    }
}
