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

    /// 허용 확장자 화이트리스트. 다른 확장자는 png로 강제 (디코딩 실패 가능성 있어도 임의 파일 복사 차단).
    private static let allowedExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "apng", "heic", "webp",
    ]

    /// 외부 파일을 내부 저장소로 복사. 절대 경로 문자열 반환.
    /// motionKey는 영숫자/_/-만 허용 (path traversal 차단).
    /// source는 일반 파일이어야 함 (심볼릭 링크/디바이스 노드 거부).
    static func copy(from source: URL, motionKey: String) throws -> String {
        // motionKey 검증: 영숫자/언더스코어/하이픈만, 길이 1~64
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        guard !motionKey.isEmpty,
              motionKey.count <= 64,
              motionKey.unicodeScalars.allSatisfy(allowed.contains) else {
            throw NSError(domain: "ClaudePet.ImageStore", code: 10,
                          userInfo: [NSLocalizedDescriptionKey: "invalid motion key"])
        }

        // source 검증: 일반 파일이어야 함 (심볼릭 링크 거부)
        let resourceValues = try source.resourceValues(
            forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard resourceValues.isRegularFile == true,
              resourceValues.isSymbolicLink != true else {
            throw NSError(domain: "ClaudePet.ImageStore", code: 11,
                          userInfo: [NSLocalizedDescriptionKey: "source is not a regular file"])
        }

        // 확장자 화이트리스트 (대소문자 무시). 미허용 확장자는 png로 강제.
        let rawExt = source.pathExtension.lowercased()
        let ext = allowedExtensions.contains(rawExt) ? rawExt : "png"

        let dest = directoryURL.appendingPathComponent("\(motionKey)_\(UUID().uuidString).\(ext)")
        try FileManager.default.copyItem(at: source, to: dest)
        return dest.path
    }

    /// 경로의 파일 삭제. ImageStore 자체 디렉토리 안의 파일만 허용 (path traversal 차단).
    static func delete(path: String?) {
        guard let path, !path.isEmpty else { return }
        let url = URL(fileURLWithPath: path).standardizedFileURL
        let base = directoryURL.standardizedFileURL
        // 반드시 ClaudePet/images/ 내부 경로여야 함
        guard url.path.hasPrefix(base.path + "/") else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
