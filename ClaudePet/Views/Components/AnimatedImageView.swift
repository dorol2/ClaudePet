// AnimatedImageView.swift
//
// GIF/APNG 등 애니메이션 이미지를 SwiftUI에서 재생할 수 있게 NSImageView를 감싼 뷰.
// 정지 이미지(PNG/JPG)에도 그대로 사용 가능.
import SwiftUI
import AppKit

/// NSImageView가 클릭 이벤트를 가로채면 윈도우 드래그가 막힘.
/// mouseDownCanMoveWindow=true로 패널의 isMovableByWindowBackground 동작을 보장.
final class DraggableImageView: NSImageView {
    override var mouseDownCanMoveWindow: Bool { true }
}

struct AnimatedImageView: NSViewRepresentable {
    let filePath: String

    final class Coordinator {
        var loadedPath: String?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSImageView {
        let view = DraggableImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        // 바닥 중앙 정렬: 이미지 크기가 달라져도 "발"이 같은 위치에 놓이게
        view.imageAlignment = .alignBottom
        view.animates = true   // GIF/APNG 자동 재생
        view.canDrawSubviewsIntoLayer = true
        // 이미지 intrinsic size가 SwiftUI .frame()을 무시하지 않도록
        view.setContentHuggingPriority(.defaultLow, for: .horizontal)
        view.setContentHuggingPriority(.defaultLow, for: .vertical)
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSImageView, context: Context) -> CGSize? {
        // SwiftUI가 제안한 크기를 그대로 사용. 이미지 intrinsic size 무시.
        proposal.replacingUnspecifiedDimensions(by: CGSize(width: 70, height: 70))
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        // 같은 파일이면 재할당하지 않아 애니메이션 끊김 방지
        if context.coordinator.loadedPath == filePath { return }
        guard FileManager.default.fileExists(atPath: filePath),
              let img = NSImage(contentsOfFile: filePath) else {
            nsView.image = nil
            context.coordinator.loadedPath = nil
            return
        }
        nsView.image = img
        context.coordinator.loadedPath = filePath
    }
}
