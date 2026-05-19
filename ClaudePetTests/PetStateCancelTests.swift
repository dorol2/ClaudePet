//
//  PetStateCancelTests.swift
//  ClaudePetTests
//
//  cancel 이벤트 + lastCancelAt 추적 + 세션 격리.

import Testing
import Foundation
@testable import ClaudePet

@MainActor
@Suite("PetState cancel 처리 + 세션 격리")
struct PetStateCancelTests {

    @Test("cancel 이벤트는 clear와 동일한 정리를 수행")
    func cancelClearsLikeClear() {
        let state = PetState()
        state.apply(event: "thinking", sessionId: "s1", label: nil)
        state.apply(event: "cancel", sessionId: "s1", label: nil)

        #expect(state.motion == .idle)
        #expect(state.sessions["s1"] == nil)
        #expect(state.isThinking == false)
    }

    @Test("cancel 직후 동일 세션 done은 축하 스킵 (triggerDone 안 함)")
    func cancelSuppressesDoneForSameSession() {
        let state = PetState()
        state.apply(event: "cancel", sessionId: "s1", label: nil)
        state.apply(event: "done", sessionId: "s1", label: nil)

        // session은 idle로 마크되지만 isDoneActive는 false (축하 모션 안 뜸)
        #expect(state.isDoneActive == false, "cancel 직후 같은 세션의 done은 축하 스킵")
        #expect(state.motion == .idle)
    }

    @Test("cancel + 다른 세션의 done은 영향 없음 (세션 격리)")
    func cancelDoesNotAffectOtherSession() {
        let state = PetState()
        state.apply(event: "cancel", sessionId: "s1", label: nil)
        state.apply(event: "done", sessionId: "s2", label: nil)

        // s2의 done은 정상 표시
        #expect(state.isDoneActive == true)
        #expect(state.motion == .done)
        #expect(state.sessions["s2"]?.state == "idle")
    }

    @Test("recentCancelWindow 외에 done이 와도 정상 축하")
    func cancelOutsideWindowAllowsDone() async throws {
        let state = PetState()
        state.apply(event: "cancel", sessionId: "s1", label: nil)

        // window는 PetState 내부 상수 2.0초. 2.5초 대기 시뮬레이션 대신
        // lastCancelAt을 직접 과거로 옮기는 게 빠르지만 private이라 불가.
        // 대신 sleep 사용 (느린 테스트지만 1회만).
        try await Task.sleep(nanoseconds: 2_100_000_000) // 2.1s

        state.apply(event: "done", sessionId: "s1", label: nil)
        #expect(state.isDoneActive == true, "cancel 후 2.1초 지나면 같은 세션도 done 정상 표시")
    }
}
