//
//  MotionKeyTests.swift
//  ClaudePetTests
//
//  MotionKey enum의 Motion ↔ MotionKey 변환, 도구 이름 매핑.

import Testing
@testable import ClaudePet

@Suite("MotionKey 변환")
struct MotionKeyTests {

    @Test("MotionKey.allCases 는 12개")
    func allCasesCount() {
        #expect(MotionKey.allCases.count == 12)
    }

    @Test("rawValue 는 외부 직렬화에 쓰이는 문자열 키와 일치")
    func rawValueStability() {
        let expected: Set<String> = [
            "idle", "waiting", "done", "tool",
            "toolBash", "toolWrite", "toolEdit", "toolWebFetch", "toolWebSearch",
            "typing", "thinking", "permission",
        ]
        let actual = Set(MotionKey.allCases.map(\.rawValue))
        #expect(actual == expected)
    }

    @Test("Motion enum의 7개 case 모두 MotionKey로 변환 가능")
    func motionToKey() {
        #expect(MotionKey(motion: .idle) == .idle)
        #expect(MotionKey(motion: .waiting) == .waiting)
        #expect(MotionKey(motion: .done) == .done)
        #expect(MotionKey(motion: .tool) == .tool)
        #expect(MotionKey(motion: .typing) == .typing)
        #expect(MotionKey(motion: .thinking) == .thinking)
        #expect(MotionKey(motion: .permission) == .permission)
    }

    @Test("도구 이름 → MotionKey 매핑")
    func fromToolName() {
        #expect(MotionKey.fromToolName("Bash") == .toolBash)
        #expect(MotionKey.fromToolName("Write") == .toolWrite)
        #expect(MotionKey.fromToolName("Edit") == .toolEdit)
        #expect(MotionKey.fromToolName("WebFetch") == .toolWebFetch)
        #expect(MotionKey.fromToolName("WebSearch") == .toolWebSearch)
    }

    @Test("알 수 없는 도구 이름 → nil")
    func unknownToolName() {
        #expect(MotionKey.fromToolName("Grep") == nil)
        #expect(MotionKey.fromToolName(nil) == nil)
        #expect(MotionKey.fromToolName("") == nil)
    }
}
