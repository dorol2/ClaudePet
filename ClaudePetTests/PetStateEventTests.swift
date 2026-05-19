//
//  PetStateEventTests.swift
//  ClaudePetTests
//
//  PetState.apply(event:sessionId:label:) 이벤트 매핑 회귀 방어 테스트.
//  이번 세션에서 발견된 버그(clear의 clearThinking 누락 등)의 재발을 막는 게 주 목적.

import Testing
@testable import ClaudePet

@MainActor
@Suite("PetState 이벤트 매핑")
struct PetStateEventTests {

    // MARK: - 기본 모션 전환

    @Test("thinking 이벤트 → motion = .thinking, isThinking = true")
    func thinkingEvent() {
        let state = PetState()
        state.apply(event: "thinking", sessionId: "s1", label: nil)
        #expect(state.motion == .thinking)
        #expect(state.isThinking == true)
    }

    @Test("tool 이벤트 → motion = .tool, currentToolName 설정")
    func toolEvent() {
        let state = PetState()
        state.apply(event: "tool", sessionId: "s1", label: "Bash")
        #expect(state.motion == .tool)
        #expect(state.isToolActive == true)
        #expect(state.currentToolName == "Bash")
    }

    @Test("done 이벤트 → motion = .done, session 'idle'로 마크")
    func doneEvent() {
        let state = PetState()
        state.apply(event: "done", sessionId: "s1", label: "demo")
        #expect(state.motion == .done)
        #expect(state.isDoneActive == true)
        #expect(state.sessions["s1"]?.state == "idle")
    }

    @Test("waiting 이벤트 (delay=0) → motion = .waiting")
    func waitingEvent() {
        let state = PetState()
        // waitingDelay 기본값 0이므로 즉시 진입
        state.apply(event: "waiting", sessionId: "s1", label: "Confirm")
        #expect(state.motion == .waiting)
        #expect(state.sessions["s1"]?.state == "waiting")
        #expect(state.waitingLabels.contains("Confirm"))
    }

    @Test("clear 이벤트 → motion = .idle, session 제거")
    func clearEvent() {
        let state = PetState()
        state.apply(event: "thinking", sessionId: "s1", label: nil)
        state.apply(event: "clear", sessionId: "s1", label: nil)
        #expect(state.motion == .idle)
        #expect(state.sessions["s1"] == nil)
    }

    // MARK: - 회귀 방어: clear는 thinking도 해소

    @Test("clear 이벤트는 isThinking도 false로 (이번 세션 버그 회귀 방어)")
    func clearAlsoClearsThinking() {
        let state = PetState()
        state.apply(event: "thinking", sessionId: "s1", label: nil)
        #expect(state.isThinking == true)

        state.apply(event: "clear", sessionId: "s1", label: nil)
        #expect(state.isThinking == false, "case clear: 도 clearThinking() 호출되어야 함")
        #expect(state.motion == .idle)
    }

    @Test("done 이벤트도 isThinking을 false로")
    func doneClearsThinking() {
        let state = PetState()
        state.apply(event: "thinking", sessionId: "s1", label: nil)
        state.apply(event: "done", sessionId: "s1", label: nil)
        #expect(state.isThinking == false)
    }

    // MARK: - Permission 오버레이 (다른 상태 보존)

    @Test("permission 이벤트는 isPermissionActive만 켜고 motion = .permission")
    func permissionEvent() {
        let state = PetState()
        state.apply(event: "permission", sessionId: "s1", label: nil)
        #expect(state.motion == .permission)
        #expect(state.isPermissionActive == true)
    }

    @Test("permission_resolved 이벤트는 오버레이만 해제 (다른 transient 유지)")
    func permissionResolvedKeepsOthers() {
        let state = PetState()
        state.apply(event: "tool", sessionId: "s1", label: "Bash")
        #expect(state.motion == .tool)

        state.apply(event: "permission", sessionId: "s1", label: nil)
        #expect(state.motion == .permission)

        state.apply(event: "permission_resolved", sessionId: "s1", label: nil)
        #expect(state.isPermissionActive == false)
        // tool은 아직 살아있어야 함 (permission_resolved는 transient 안 건드림)
        #expect(state.isToolActive == true)
        #expect(state.motion == .tool)
    }

    // MARK: - waitingEnabled 토글

    @Test("waitingEnabled=false면 waiting 이벤트 완전 무시")
    func waitingDisabledIgnoresEvent() {
        let state = PetState()
        state.waitingEnabled = false

        state.apply(event: "waiting", sessionId: "s1", label: "Confirm")
        #expect(state.motion == .idle, "waitingEnabled=false 시 motion 변화 없음")
        #expect(state.sessions["s1"] == nil, "세션도 등록되지 않음")
    }

    @Test("waitingEnabled=false라도 다른 이벤트는 정상 동작")
    func waitingDisabledOtherEventsWork() {
        let state = PetState()
        state.waitingEnabled = false

        state.apply(event: "thinking", sessionId: "s1", label: nil)
        #expect(state.motion == .thinking)

        state.apply(event: "tool", sessionId: "s1", label: "Bash")
        #expect(state.motion == .tool)

        state.apply(event: "done", sessionId: "s1", label: nil)
        #expect(state.motion == .done)
    }
}
