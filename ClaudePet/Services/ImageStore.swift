// ImageStore.swift
//
// 사용자가 선택한 이미지를 앱 Support 폴더로 복사 보관.
// 원본 파일이 사라져도 펫이 동작하도록.
import Foundation

enum ImageStore {
    static let directoryURL: URL = {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("ClaudePet/images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    /// 외부 파일을 내부 저장소로 복사. 절대 경로 문자열 반환.
    static func copy(from source: URL, motionKey: String) throws -> String {
        let ext = source.pathExtension.isEmpty ? "png" : source.pathExtension
        let dest = directoryURL.appendingPathComponent("\(motionKey)_\(UUID().uuidString).\(ext)")
        try FileManager.default.copyItem(at: source, to: dest)
        return dest.path
    }

    static func delete(path: String?) {
        guard let path, !path.isEmpty else { return }
        try? FileManager.default.removeItem(atPath: path)
    }
}
