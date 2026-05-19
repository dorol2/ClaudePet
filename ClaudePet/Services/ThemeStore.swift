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
            .compactMap { try? JSONDecoder().decode(Theme.self, from: Data(contentsOf: $0)) }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    func save(_ theme: Theme) {
        let url = Self.directory.appendingPathComponent("\(theme.id).json")
        if let data = try? JSONEncoder().encode(theme) {
            try? data.write(to: url, options: .atomic)
        }
        reload()
    }

    func delete(id: String) {
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
