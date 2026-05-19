//
//  ImageStoreTests.swift
//  ClaudePetTests
//
//  이미지 등록 흐름: NSOpenPanel로 받은 파일을 ImageStore가 앱 저장소로 복사하고
//  PetTheme이 해당 경로를 motion에 매핑하는 부분을 검증.
//  (NSOpenPanel UI 단계는 unit test 범위 밖.)

import Testing
import Foundation
@testable import ClaudePet

@Suite("ImageStore 및 이미지 등록 흐름")
struct ImageStoreTests {

    // MARK: - Helpers

    /// 임시 파일을 만들고 URL 반환. 호출자가 cleanup 책임.
    private static func makeTempSourceFile(ext: String = "png", bytes: Data = Data([0x89, 0x50, 0x4E, 0x47])) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_src_\(UUID().uuidString).\(ext)")
        try bytes.write(to: url)
        return url
    }

    private static func cleanup(_ urls: URL...) {
        for u in urls {
            try? FileManager.default.removeItem(at: u)
        }
    }

    // MARK: - ImageStore 단위

    @Test("ImageStore.copy: 외부 파일을 내부 저장소로 복사")
    func copyToInternalStorage() throws {
        let src = try Self.makeTempSourceFile()
        defer { Self.cleanup(src) }

        let savedPath = try ImageStore.copy(from: src, motionKey: "idle")
        defer { ImageStore.delete(path: savedPath) }

        #expect(FileManager.default.fileExists(atPath: savedPath),
                "복사된 파일이 실제로 존재해야 함")
        #expect(savedPath.contains("ClaudePet/images"),
                "ClaudePet 앱 저장소 안에 저장되어야 함")
        #expect(savedPath.contains("idle_"),
                "파일명에 motionKey가 포함되어야 함")
    }

    @Test("ImageStore.copy: 원본 확장자 보존 (.gif)")
    func copyPreservesExtension() throws {
        let src = try Self.makeTempSourceFile(ext: "gif")
        defer { Self.cleanup(src) }

        let savedPath = try ImageStore.copy(from: src, motionKey: "tool")
        defer { ImageStore.delete(path: savedPath) }

        #expect(savedPath.hasSuffix(".gif"))
    }

    @Test("ImageStore.copy: 매 호출마다 UUID로 고유 경로 생성")
    func copyGeneratesUniquePath() throws {
        let src = try Self.makeTempSourceFile()
        defer { Self.cleanup(src) }

        let path1 = try ImageStore.copy(from: src, motionKey: "idle")
        let path2 = try ImageStore.copy(from: src, motionKey: "idle")
        defer {
            ImageStore.delete(path: path1)
            ImageStore.delete(path: path2)
        }

        #expect(path1 != path2, "같은 motionKey라도 매번 다른 경로 (덮어쓰기 방지)")
        #expect(FileManager.default.fileExists(atPath: path1))
        #expect(FileManager.default.fileExists(atPath: path2))
    }

    @Test("ImageStore.delete: 파일 삭제")
    func deleteRemovesFile() throws {
        let src = try Self.makeTempSourceFile()
        defer { Self.cleanup(src) }

        let savedPath = try ImageStore.copy(from: src, motionKey: "idle")
        #expect(FileManager.default.fileExists(atPath: savedPath))

        ImageStore.delete(path: savedPath)
        #expect(!FileManager.default.fileExists(atPath: savedPath),
                "delete 후 파일이 사라져야 함")
    }

    @Test("ImageStore.delete: nil / 빈 경로는 no-op (크래시 X)")
    func deleteHandlesNilAndEmpty() {
        ImageStore.delete(path: nil)
        ImageStore.delete(path: "")
        ImageStore.delete(path: "/nonexistent/path/that/never/existed.png")
        // 위 3개 호출 모두 throw 없이 통과하면 OK
    }

    // MARK: - PetTheme 통합

    @Test("PetTheme.setImagePath: motion에 imagePath 설정")
    @MainActor
    func setImagePathOnMotion() {
        let theme = PetTheme()
        theme.setImagePath("/tmp/test.png", forKey: .idle)

        let idleStyle = theme.style(forKey: .idle)
        #expect(idleStyle.imagePath == "/tmp/test.png")
    }

    @Test("PetTheme.setImagePath: nil로 이미지 해제")
    @MainActor
    func clearImagePath() {
        let theme = PetTheme()
        theme.setImagePath("/tmp/test.png", forKey: .idle)
        theme.setImagePath(nil, forKey: .idle)
        #expect(theme.style(forKey: .idle).imagePath == nil)
    }

    @Test("이미지 등록 end-to-end: ImageStore.copy + setImagePath + 파일 존재 확인")
    @MainActor
    func endToEndImageRegistration() throws {
        // 1) 사용자가 NSOpenPanel에서 고른 것처럼 임시 파일 생성
        let src = try Self.makeTempSourceFile(ext: "gif")
        defer { Self.cleanup(src) }

        // 2) pickImage() 흐름 시뮬레이션
        let theme = PetTheme()
        let oldPath = theme.style(forKey: .idle).imagePath
        ImageStore.delete(path: oldPath)
        let savedPath = try ImageStore.copy(from: src, motionKey: "idle")
        theme.setImagePath(savedPath, forKey: .idle)
        defer { ImageStore.delete(path: savedPath) }

        // 3) 검증: 펫이 표시할 이미지 경로가 실제 파일을 가리킴
        let resultPath = theme.style(forKey: .idle).imagePath
        #expect(resultPath == savedPath)
        #expect(resultPath != nil)
        #expect(FileManager.default.fileExists(atPath: resultPath!),
                "theme.idle.imagePath가 가리키는 실제 파일이 존재해야 함")
    }

    @Test("이미지 교체: 기존 이미지 삭제 후 새 이미지 등록")
    @MainActor
    func replaceImageDeletesOld() throws {
        let src1 = try Self.makeTempSourceFile(ext: "gif")
        let src2 = try Self.makeTempSourceFile(ext: "png")
        defer { Self.cleanup(src1, src2) }

        let theme = PetTheme()

        // 첫 번째 등록
        let path1 = try ImageStore.copy(from: src1, motionKey: "tool")
        theme.setImagePath(path1, forKey: .tool)
        #expect(FileManager.default.fileExists(atPath: path1))

        // 두 번째 등록 (pickImage가 하듯 이전 것 삭제 후 새것)
        ImageStore.delete(path: theme.style(forKey: .tool).imagePath)
        let path2 = try ImageStore.copy(from: src2, motionKey: "tool")
        theme.setImagePath(path2, forKey: .tool)
        defer { ImageStore.delete(path: path2) }

        #expect(!FileManager.default.fileExists(atPath: path1),
                "이전 이미지는 삭제됐어야 함")
        #expect(FileManager.default.fileExists(atPath: path2))
        #expect(theme.style(forKey: .tool).imagePath == path2)
    }
}
