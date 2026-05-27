// PetView.swift
import SwiftUI

/// 말풍선의 현재 자연 크기(꼬리 포함)를 PetState로 전달하는 PreferenceKey.
/// AppDelegate가 이를 받아 NSPanel 폭/높이를 동적으로 확장한다.
private struct BubbleSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

struct PetView: View {
    @EnvironmentObject var state: PetState
    @EnvironmentObject var theme: PetTheme

    var body: some View {
        // NSHostingView가 SwiftUI intrinsic으로 자동 사이징되는 걸 막기 위해
        // GeometryReader로 패널이 준 영역을 명시적으로 가져와서 그 안에서 배치.
        // VStack은 자연 크기, 외곽 frame을 bottom 정렬 → bubble은 캐릭터 바로 위에 붙고
        // 외곽 사이즈가 고정이라 캐릭터는 항상 같은 Y 위치를 유지.
        GeometryReader { geo in
            VStack(spacing: 0) {
                bubble
                character
                    .frame(width: theme.petSize.characterSize,
                           height: theme.petSize.characterSize,
                           alignment: .bottom)
            }
            .padding(8)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
        .onPreferenceChange(BubbleSizeKey.self) { size in
            // SwiftUI는 onPreferenceChange를 main thread에서 호출하지만, Swift 6
            // strict concurrency를 통과하려면 @MainActor isolation을 명시.
            Task { @MainActor in state.measuredBubbleSize = size }
        }
    }

    // MARK: - 말풍선

    @ViewBuilder
    private var bubble: some View {
        if let text = bubbleText {
            VStack(spacing: 0) {
                Text(text)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(.labelColor))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.regularMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.65), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 3)
                    // 라벨이 길어도 한 줄 유지를 위해 폭 상한을 넉넉히. 이 안에서 자연 폭으로
                    // 측정되고, AppDelegate가 그 폭에 맞춰 NSPanel을 확장한다.
                    // 순서 중요: frame(maxWidth:)를 먼저 두어 wrap 한도를 정하고,
                    // fixedSize(horizontal: true)로 부모(panel) 폭 제약을 무시해 자연 폭으로 그린다.
                    // 그 자연 폭이 PreferenceKey로 측정되어 panel 자체를 확장하는 트리거가 된다.
                    .frame(maxWidth: 500)
                    .fixedSize(horizontal: true, vertical: true)
                BubbleTail()
                    .fill(.regularMaterial)
                    .frame(width: 14, height: 7)
                    .shadow(color: .black.opacity(0.10), radius: 2, x: 0, y: 2)
            }
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(key: BubbleSizeKey.self, value: proxy.size)
                }
            )
            .transition(.opacity)
        } else {
            Color.clear
                .frame(height: 0)
                .preference(key: BubbleSizeKey.self, value: .zero)
        }
    }

    private var bubbleText: String? {
        // 마스터 토글 OFF면 항상 숨김
        guard theme.bubbleEnabled else { return nil }
        let style = currentStyle   // tool 모션은 per-tool 스타일까지 반영
        // 각 모션(또는 도구)의 자체 토글
        guard style.bubbleEnabled else { return nil }
        let template = style.bubbleText
        guard !template.isEmpty else { return nil }

        // waiting은 라벨이 여러 개일 수 있어 라벨별로 템플릿 적용 후 join
        if state.motion == .waiting {
            let labels = state.waitingLabels
            guard !labels.isEmpty else { return nil }
            return labels
                .map { substitute(template, motion: state.motion, style: style, label: $0) }
                .joined(separator: "\n")
        }
        return substitute(template, motion: state.motion, style: style, label: nil)
    }

    /// 템플릿의 {emoji} {tool} {verb} {label} 치환.
    private func substitute(_ template: String,
                            motion: Motion,
                            style: MotionStyle,
                            label: String?) -> String {
        var s = template
        s = s.replacingOccurrences(of: "{emoji}", with: style.emoji)
        if let label {
            s = s.replacingOccurrences(of: "{label}", with: label)
        }
        if motion == .tool, let name = state.currentToolName {
            s = s.replacingOccurrences(of: "{tool}", with: name)
            // {emoji}가 이미 치환됐지만, 도구별 이모지로 추가 치환할 수 있도록 {tool_emoji}도 제공
            let toolEmoji = Self.toolEmojis[name] ?? style.emoji
            s = s.replacingOccurrences(of: "{tool_emoji}", with: toolEmoji)
        }
        if motion == .thinking, !theme.thinkingVerbs.isEmpty {
            let v = theme.thinkingVerbs[state.thinkingVerbIndex % theme.thinkingVerbs.count]
            s = s.replacingOccurrences(of: "{verb}", with: v)
        }
        return s
    }

    // MARK: - 캐릭터

    @ViewBuilder
    private var character: some View {
        // 우선순위: 사용자 지정 이미지(GIF/APNG 포함) > 폴백 이모지 placeholder
        // GIF/APNG는 NSImageView.animates = true가 자체 재생하므로 외부 timer 불필요.
        // 이미지가 짤리지 않도록 외곽 128x128 프레임 전체를 사용.
        // NSImageView의 imageAlignment(.alignBottom)이 이미지 비율 차이를 흡수.
        if let path = customImagePath() {
            AnimatedImageView(filePath: path)
        } else {
            placeholder
        }
    }

    /// 현재 적용할 스타일. tool 모션 + toolPerToolEnabled + 도구 이름 매칭 시 per-tool 스타일 사용.
    private var currentStyle: MotionStyle {
        if state.motion == .tool,
           theme.toolPerToolEnabled,
           let perTool = theme.style(forToolName: state.currentToolName) {
            return perTool
        }
        return theme.style(for: state.motion)
    }

    private func customImagePath() -> String? {
        let path = currentStyle.imagePath
        guard let path, !path.isEmpty,
              FileManager.default.fileExists(atPath: path) else { return nil }
        return path
    }

    // sprite 없을 때 폴백. 통통한 몸 + 이모지 표정. theme.petSize에 비례.
    private var placeholder: some View {
        let s = theme.petSize.characterSize
        return ZStack {
            Ellipse()
                .fill(
                    LinearGradient(
                        colors: placeholderColors,
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: s * 0.875, height: s * 0.781)
                .shadow(color: (placeholderColors.last ?? .clear).opacity(0.45),
                        radius: s * 0.094, x: 0, y: s * 0.047)
            Ellipse()
                .fill(Color.white.opacity(0.35))
                .frame(width: s * 0.297, height: s * 0.141)
                .offset(x: -s * 0.141, y: -s * 0.219)
                .blur(radius: s * 0.031)
            Text(motionEmoji)
                .font(.system(size: s * 0.406))
        }
    }

    private var placeholderColors: [Color] {
        let s = currentStyle
        return [Color(hex: s.topColorHex), Color(hex: s.bottomColorHex)]
    }

    // {tool_emoji} 템플릿 변수용 폴백 매핑 (per-tool 스타일이 없을 때).
    private static let toolEmojis: [String: String] = [
        "Bash":      "💻",
        "Write":     "✍️",
        "Edit":      "✏️",
        "WebFetch":  "🌐",
        "WebSearch": "🔍",
    ]

    private var motionEmoji: String {
        // currentStyle이 이미 토글/도구 매칭을 고려해서 적절한 스타일을 반환함
        currentStyle.emoji
    }
}

// 말풍선 꼬리
private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}
