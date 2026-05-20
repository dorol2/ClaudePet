// ThemeStore.swift
//
// 사용자 정의 테마 저장소. ~/Library/Application Support/ClaudePet/themes/
//
// 구조:
//   themes/
//     <theme-id>.json      ← Theme 메타데이터
//     <theme-id>/          ← 해당 테마용 이미지 사본 (이미지 있을 때만)
//       idle.gif
//       waiting.gif
//       ...
import Foundation

@MainActor
final class ThemeStore: ObservableObject {
    @Published private(set) var userThemes: [Theme] = []

    static let directory: URL = {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("ClaudePet/themes", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// 사용자 테마 JSON 파일 1개의 최대 크기 (악의적 OOM 방어). 256 KB면 충분.
    private static let maxThemeFileBytes = 256 * 1024
    /// 문자열 필드(name, description) 최대 길이
    private static let maxStringLength = 256

    init() {
        reload()
    }

    func reload() {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: Self.directory,
            includingPropertiesForKeys: nil
        ) else { return }
        userThemes = urls
            .filter { $0.pathExtension == "json" }
            .compactMap { Self.loadAndSanitize(from: $0) }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    /// JSON 파일을 로드하면서:
    /// 1) 파일 크기 cap 검사 (DoS 방어)
    /// 2) theme.id 정규식 검증 (path traversal 방어)
    /// 3) 문자열 필드 길이 cap
    /// 4) isBuiltin = false 강제
    /// 5) bundledImagePrefix = nil 강제 (사용자 테마가 앱 번들 자원에 접근 못 하게)
    private static func loadAndSanitize(from url: URL) -> Theme? {
        guard let data = try? Data(contentsOf: url),
              data.count > 0,
              data.count <= maxThemeFileBytes,
              let raw = try? JSONDecoder().decode(Theme.self, from: data),
              isValidThemeId(raw.id) else { return nil }

        let safeName = String(raw.name.prefix(maxStringLength))
        let safeDesc = String(raw.themeDescription.prefix(maxStringLength))
        return Theme(
            id: raw.id,
            name: safeName,
            themeDescription: safeDesc,
            isBuiltin: false,                 // 사용자 테마는 항상 false
            motions: raw.motions,
            thinkingVerbs: raw.thinkingVerbs,
            bundledImagePrefix: nil           // 사용자 테마는 번들 자원 접근 금지
        )
    }

    /// theme.id 허용 문자: 영숫자 + `_` + `-`. 길이 1~64.
    static func isValidThemeId(_ id: String) -> Bool {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        return !id.isEmpty
            && id.count <= 64
            && id.unicodeScalars.allSatisfy(allowed.contains)
    }

    func save(_ theme: Theme) {
        guard Self.isValidThemeId(theme.id) else { return }
        let url = Self.directory.appendingPathComponent("\(theme.id).json")
        if let data = try? JSONEncoder().encode(theme), data.count <= Self.maxThemeFileBytes {
            try? data.write(to: url, options: .atomic)
        }
        reload()
    }

    func delete(id: String) {
        guard Self.isValidThemeId(id) else { return }
        let json = Self.directory.appendingPathComponent("\(id).json")
        let dir = Self.directory.appendingPathComponent(id, isDirectory: true)
        try? FileManager.default.removeItem(at: json)
        try? FileManager.default.removeItem(at: dir)
        reload()
    }

    /// 빌트인 + 사용자 테마를 합친 전체 목록
    var allThemes: [Theme] {
        ThemeCatalog.builtin + userThemes
    }

    /// 특정 테마용 이미지 폴더 URL (있을 수 있고 없을 수도 있음)
    static func imageDir(forThemeId id: String) -> URL {
        directory.appendingPathComponent(id, isDirectory: true)
    }
}
