// Theme.swift
//
// 외형 프리셋. 한 번에 모든 모션의 색/이모지/이미지/말풍선/verb를 묶어서 전환.
// 빌트인 테마는 ThemeCatalog.builtin 에 정의. 향후 사용자 정의 테마는
// ~/Library/Application Support/ClaudePet/themes/*.json 으로 확장 가능.
import Foundation

struct Theme: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let themeDescription: String
    let isBuiltin: Bool
    /// 키: Motion enum의 rawValue 또는 "toolBash"/"toolWrite" 등 도구별 키
    let motions: [String: MotionStyle]
    let thinkingVerbs: [String]?
    /// 번들 안에서 이미지를 찾을 폴더 prefix. nil이면 이미지 적용 안 함(이미지 다 비움).
    /// 빈 문자열이면 번들 루트(Resources/) 직접 사용.
    let bundledImagePrefix: String?
}

enum ThemeCatalog {
    static let builtin: [Theme] = [.default]
}

extension Theme {
    /// 모든 motion 키 (PetTheme 내부 필드명과 매칭). MotionKey enum이 단일 source of truth.
    static let allMotionKeys: [String] = MotionKey.allCases.map(\.rawValue)

    static let `default`: Theme = Theme(
        id: "default",
        name: "Default",
        themeDescription: "기본 컬러풀 이모지. 이미지 없음.",
        isBuiltin: true,
        motions: defaultMotions(),
        thinkingVerbs: PetTheme.defaultThinkingVerbs,
        bundledImagePrefix: nil
    )

    private static func defaultMotions() -> [String: MotionStyle] {
        [
            "idle":          PetTheme.defaultIdle,
            "waiting":       PetTheme.defaultWaiting,
            "done":          PetTheme.defaultDone,
            "tool":          PetTheme.defaultTool,
            "toolBash":      PetTheme.defaultToolBash,
            "toolWrite":     PetTheme.defaultToolWrite,
            "toolEdit":      PetTheme.defaultToolEdit,
            "toolWebFetch":  PetTheme.defaultToolWebFetch,
            "toolWebSearch": PetTheme.defaultToolWebSearch,
            "typing":        PetTheme.defaultTyping,
            "thinking":      PetTheme.defaultThinking,
            "permission":    PetTheme.defaultPermission,
        ]
    }
}
