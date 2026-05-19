// MotionKey.swift
//
// 모든 motion 식별자를 한 곳에 모은 타입 안전 enum.
// rawValue는 UserDefaults/JSON 직렬화 시 사용하는 문자열 키와 동일.
import Foundation

enum MotionKey: String, CaseIterable, Codable {
    case idle, waiting, done, tool
    case toolBash, toolWrite, toolEdit, toolWebFetch, toolWebSearch
    case typing, thinking, permission

    /// PetState의 Motion 값을 MotionKey로 변환. tool 모션은 일반 .tool로 매핑 (도구별 키는 PetView가 별도 처리).
    init?(motion: Motion) {
        switch motion {
        case .idle:       self = .idle
        case .waiting:    self = .waiting
        case .done:       self = .done
        case .tool:       self = .tool
        case .typing:     self = .typing
        case .thinking:   self = .thinking
        case .permission: self = .permission
        }
    }

    /// 도구 이름(Bash/Write/Edit/...)에 대응하는 per-tool MotionKey. 매칭 안 되면 nil.
    static func fromToolName(_ name: String?) -> MotionKey? {
        guard let name else { return nil }
        switch name {
        case "Bash":      return .toolBash
        case "Write":     return .toolWrite
        case "Edit":      return .toolEdit
        case "WebFetch":  return .toolWebFetch
        case "WebSearch": return .toolWebSearch
        default:          return nil
        }
    }
}
