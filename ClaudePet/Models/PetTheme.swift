// PetTheme.swift
//
// 사용자 커스터마이즈 가능한 외형 설정. UserDefaults에 자동 저장.
import SwiftUI
import Combine

enum PetSize: String, Codable, CaseIterable, Identifiable {
    case small, medium, large
    var id: String { rawValue }

    var characterSize: CGFloat {
        switch self {
        case .small:  return 96
        case .medium: return 128
        case .large:  return 160
        }
    }
    var panelWidth: CGFloat {
        switch self {
        case .small:  return 128
        case .medium: return 160
        case .large:  return 200
        }
    }
    var panelHeight: CGFloat {
        switch self {
        case .small:  return 144
        case .medium: return 180
        case .large:  return 224
        }
    }
    var displayName: String {
        switch self {
        case .small:  return "작게"
        case .medium: return "보통"
        case .large:  return "크게"
        }
    }
}

struct MotionStyle: Codable, Equatable {
    var emoji: String
    var topColorHex: String
    var bottomColorHex: String
    var imagePath: String?       // 설정되면 emoji 대신 이미지로 표시
    var bubbleText: String       // 말풍선 템플릿. {emoji} {tool} {verb} {label} 치환됨
    var bubbleEnabled: Bool      // 이 모션에서 말풍선 표시 여부

    init(emoji: String,
         topColorHex: String,
         bottomColorHex: String,
         imagePath: String? = nil,
         bubbleText: String = "",
         bubbleEnabled: Bool = false) {
        self.emoji = emoji
        self.topColorHex = topColorHex
        self.bottomColorHex = bottomColorHex
        self.imagePath = imagePath
        self.bubbleText = bubbleText
        self.bubbleEnabled = bubbleEnabled
    }

    // 구버전 데이터(bubbleText/bubbleEnabled 없는)도 디코딩 가능하도록
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        emoji          = try c.decode(String.self, forKey: .emoji)
        topColorHex    = try c.decode(String.self, forKey: .topColorHex)
        bottomColorHex = try c.decode(String.self, forKey: .bottomColorHex)
        imagePath      = try c.decodeIfPresent(String.self, forKey: .imagePath)
        bubbleText     = try c.decodeIfPresent(String.self, forKey: .bubbleText) ?? ""
        bubbleEnabled  = try c.decodeIfPresent(Bool.self,   forKey: .bubbleEnabled) ?? false
    }
}

@MainActor
final class PetTheme: ObservableObject {
    /// 모든 motion 스타일을 단일 dict에 저장. 12개 개별 @Published 필드 대신 통합.
    /// Phase 2 마이그레이션: 옛 개별 필드 (idle/waiting/...)는 init에서 dict로 흡수, save 시점에 새 포맷으로만 기록.
    @Published var motions: [MotionKey: MotionStyle]
    @Published var thinkingVerbs: [String]
    @Published var keystrokeMonitorEnabled: Bool
    /// typing 모션 발화 대상이 되는 터미널 앱들의 bundle ID 목록
    @Published var keystrokeBundleIDs: [String]
    @Published var doneDuration: TimeInterval
    @Published var toolDuration: TimeInterval
    @Published var typingDuration: TimeInterval
    @Published var thinkingVerbInterval: TimeInterval
    /// waiting 이벤트 수신 후 실제로 waiting 모션 진입하기까지의 지연(초). 0 = 즉시.
    @Published var waitingDelay: TimeInterval
    /// false면 waiting 이벤트를 완전히 무시 (펫에 표시하지 않음). 기본 true.
    @Published var waitingEnabled: Bool
    /// true면 타이머 무시하고 다음 이벤트가 올 때까지 모션 유지
    @Published var donePersistent: Bool
    @Published var toolPersistent: Bool
    @Published var typingPersistent: Bool
    /// true면 waiting 모션 중에 typing이 감지되면 "사용자가 응답함"으로 간주하여
    /// waiting 세션을 즉시 해소하고 typing 모션으로 전환. typing 종료 후엔 idle.
    @Published var typingOverridesWaiting: Bool
    @Published var bubbleEnabled: Bool
    @Published var petSize: PetSize
    /// true면 도구마다 별도 스타일 사용. false면 모든 도구가 theme.tool 사용.
    @Published var toolPerToolEnabled: Bool
    /// 현재 적용된 빌트인 테마 ID. 사용자가 개별 필드 수정하면 nil로 리셋 가능 (현재는 추적만).
    @Published var activeThemeId: String?

    private static let storageKey = "petTheme.v1"
    private var cancellables = Set<AnyCancellable>()

    static let defaultIdle     = MotionStyle(emoji: "😊", topColorHex: "#EBF2FF", bottomColorHex: "#B8CCEF",
                                              bubbleText: "", bubbleEnabled: false)
    static let defaultWaiting  = MotionStyle(emoji: "👀", topColorHex: "#FFE5A8", bottomColorHex: "#FFB36B",
                                              bubbleText: "⌛ {label}", bubbleEnabled: true)
    static let defaultDone     = MotionStyle(emoji: "🎉", topColorHex: "#CCF5D4", bottomColorHex: "#73D199",
                                              bubbleText: "🎉 완료!", bubbleEnabled: true)
    static let defaultTool     = MotionStyle(emoji: "🛠️", topColorHex: "#E5DBFF", bottomColorHex: "#A78BFA",
                                              bubbleText: "{emoji} {tool}", bubbleEnabled: true)
    static let defaultToolBash      = MotionStyle(emoji: "💻", topColorHex: "#DBE4FF", bottomColorHex: "#4F46E5",
                                                   bubbleText: "{emoji} Bash", bubbleEnabled: true)
    static let defaultToolWrite     = MotionStyle(emoji: "✍️", topColorHex: "#FEF3C7", bottomColorHex: "#D97706",
                                                   bubbleText: "{emoji} Write", bubbleEnabled: true)
    static let defaultToolEdit      = MotionStyle(emoji: "✏️", topColorHex: "#FFE4D6", bottomColorHex: "#EA580C",
                                                   bubbleText: "{emoji} Edit", bubbleEnabled: true)
    static let defaultToolWebFetch  = MotionStyle(emoji: "🌐", topColorHex: "#CFFAFE", bottomColorHex: "#06B6D4",
                                                   bubbleText: "{emoji} WebFetch", bubbleEnabled: true)
    static let defaultToolWebSearch = MotionStyle(emoji: "🔍", topColorHex: "#FEF9C3", bottomColorHex: "#CA8A04",
                                                   bubbleText: "{emoji} WebSearch", bubbleEnabled: true)
    static let defaultTyping   = MotionStyle(emoji: "✍️", topColorHex: "#FFF9D6", bottomColorHex: "#F5C24A",
                                              bubbleText: "", bubbleEnabled: false)
    static let defaultThinking   = MotionStyle(emoji: "🤔", topColorHex: "#FFE0EC", bottomColorHex: "#FB7185",
                                                bubbleText: "{emoji} {verb}", bubbleEnabled: true)
    static let defaultPermission = MotionStyle(emoji: "🙋", topColorHex: "#FFD9E5", bottomColorHex: "#EC4899",
                                                bubbleText: "🙋 권한 요청", bubbleEnabled: true)
    static let defaultThinkingVerbs = [
        "Cooking…", "Pondering…", "Flummoxing…", "Plotting…", "Brewing…",
        "Conjuring…", "Calculating…", "Untangling…", "Daydreaming…", "Marinating…",
    ]
    static let defaultKeystrokeBundleIDs = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "io.alacritty",
        "net.kovidgoyal.kitty",
        "com.github.wez.wezterm",
        "co.zeit.hyper",
    ]
    static let defaultDoneDuration: TimeInterval = 4.0
    static let defaultToolDuration: TimeInterval = 2.0
    static let defaultTypingDuration: TimeInterval = 1.5
    static let defaultThinkingVerbInterval: TimeInterval = 1.5

    /// 모든 motion에 대한 기본 스타일 dict. motions 필드 초기값 / fallback에 사용.
    static let defaultMotions: [MotionKey: MotionStyle] = [
        .idle:          defaultIdle,
        .waiting:       defaultWaiting,
        .done:          defaultDone,
        .tool:          defaultTool,
        .toolBash:      defaultToolBash,
        .toolWrite:     defaultToolWrite,
        .toolEdit:      defaultToolEdit,
        .toolWebFetch:  defaultToolWebFetch,
        .toolWebSearch: defaultToolWebSearch,
        .typing:        defaultTyping,
        .thinking:      defaultThinking,
        .permission:    defaultPermission,
    ]

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let snap = try? JSONDecoder().decode(Snapshot.self, from: data) {
            // motions dict 우선. 없으면 옛 개별 필드(idle/waiting/...)에서 복원, 그것도 없으면 기본값.
            self.motions = Self.loadMotions(from: snap)
            self.thinkingVerbs = snap.thinkingVerbs ?? Self.defaultThinkingVerbs
            self.keystrokeMonitorEnabled = snap.keystrokeMonitorEnabled ?? false
            self.keystrokeBundleIDs = snap.keystrokeBundleIDs ?? Self.defaultKeystrokeBundleIDs
            self.doneDuration = snap.doneDuration ?? Self.defaultDoneDuration
            self.toolDuration = snap.toolDuration ?? Self.defaultToolDuration
            self.typingDuration = snap.typingDuration ?? Self.defaultTypingDuration
            self.thinkingVerbInterval = snap.thinkingVerbInterval ?? Self.defaultThinkingVerbInterval
            self.waitingDelay = snap.waitingDelay ?? 0
            self.waitingEnabled = snap.waitingEnabled ?? true
            self.donePersistent = snap.donePersistent ?? false
            self.toolPersistent = snap.toolPersistent ?? false
            self.typingPersistent = snap.typingPersistent ?? false
            self.typingOverridesWaiting = snap.typingOverridesWaiting ?? false
            self.bubbleEnabled = snap.bubbleEnabled ?? true
            self.petSize = snap.petSize ?? .medium
            self.toolPerToolEnabled = snap.toolPerToolEnabled ?? false
            self.activeThemeId = snap.activeThemeId
            // v3 → v4 마이그레이션: 옛 waitingPrefixEmoji/doneBubbleText → motion.bubbleText
            if var w = motions[.waiting], w.bubbleText.isEmpty {
                let prefix = snap.waitingPrefixEmoji ?? "⌛"
                w.bubbleText = "\(prefix) {label}"
                w.bubbleEnabled = true
                motions[.waiting] = w
            }
            if var d = motions[.done], d.bubbleText.isEmpty {
                d.bubbleText = snap.doneBubbleText ?? "🎉 완료!"
                d.bubbleEnabled = true
                motions[.done] = d
            }
        } else {
            self.motions = Self.defaultMotions
            self.thinkingVerbs = Self.defaultThinkingVerbs
            self.keystrokeMonitorEnabled = false
            self.keystrokeBundleIDs = Self.defaultKeystrokeBundleIDs
            self.doneDuration = Self.defaultDoneDuration
            self.toolDuration = Self.defaultToolDuration
            self.typingDuration = Self.defaultTypingDuration
            self.thinkingVerbInterval = Self.defaultThinkingVerbInterval
            self.waitingDelay = 0
            self.waitingEnabled = true
            self.donePersistent = false
            self.toolPersistent = false
            self.typingPersistent = false
            self.typingOverridesWaiting = false
            self.bubbleEnabled = true
            self.petSize = .medium
            self.toolPerToolEnabled = false
            self.activeThemeId = "default"
        }
        objectWillChange
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                Task { @MainActor in self?.save() }
            }
            .store(in: &cancellables)
    }

    private struct Snapshot: Codable {
        /// Phase 2 신규 포맷: 모든 motion을 [String: MotionStyle]로 저장.
        var motions: [String: MotionStyle]?
        // v1~Phase1 호환: 옛 개별 필드. 새 포맷이 nil일 때만 fallback으로 읽음. save 시 항상 nil 기록.
        var idle: MotionStyle?
        var waiting: MotionStyle?
        var done: MotionStyle?
        var tool: MotionStyle?
        var toolBash: MotionStyle?
        var toolWrite: MotionStyle?
        var toolEdit: MotionStyle?
        var toolWebFetch: MotionStyle?
        var toolWebSearch: MotionStyle?
        var typing: MotionStyle?
        var thinking: MotionStyle?
        var permission: MotionStyle?
        var thinkingVerbs: [String]?
        // v3 호환을 위해 읽기만 (저장하진 않음). 마이그레이션 후 motion.bubbleText로 흡수.
        var waitingPrefixEmoji: String?
        var doneBubbleText: String?
        var keystrokeMonitorEnabled: Bool?
        var keystrokeBundleIDs: [String]?
        var doneDuration: TimeInterval?
        var toolDuration: TimeInterval?
        var typingDuration: TimeInterval?
        var thinkingVerbInterval: TimeInterval?
        var waitingDelay: TimeInterval?
        var waitingEnabled: Bool?
        var donePersistent: Bool?
        var toolPersistent: Bool?
        var typingPersistent: Bool?
        var typingOverridesWaiting: Bool?
        var bubbleEnabled: Bool?
        var petSize: PetSize?
        var toolPerToolEnabled: Bool?
        var activeThemeId: String?
    }

    private func save() {
        // motions를 [String: MotionStyle]로 직렬화. 옛 개별 필드는 모두 nil로 기록(폐기).
        var rawMotions: [String: MotionStyle] = [:]
        for (key, style) in motions {
            rawMotions[key.rawValue] = style
        }
        let snap = Snapshot(
            motions: rawMotions,
            idle: nil, waiting: nil, done: nil, tool: nil,
            toolBash: nil, toolWrite: nil, toolEdit: nil,
            toolWebFetch: nil, toolWebSearch: nil,
            typing: nil,
            thinking: nil, permission: nil, thinkingVerbs: thinkingVerbs,
            waitingPrefixEmoji: nil,
            doneBubbleText: nil,
            keystrokeMonitorEnabled: keystrokeMonitorEnabled,
            keystrokeBundleIDs: keystrokeBundleIDs,
            doneDuration: doneDuration,
            toolDuration: toolDuration,
            typingDuration: typingDuration,
            thinkingVerbInterval: thinkingVerbInterval,
            waitingDelay: waitingDelay,
            waitingEnabled: waitingEnabled,
            donePersistent: donePersistent,
            toolPersistent: toolPersistent,
            typingPersistent: typingPersistent,
            typingOverridesWaiting: typingOverridesWaiting,
            bubbleEnabled: bubbleEnabled,
            petSize: petSize,
            toolPerToolEnabled: toolPerToolEnabled,
            activeThemeId: activeThemeId
        )
        if let data = try? JSONEncoder().encode(snap) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }

    func resetToDefaults() {
        motions = Self.defaultMotions
        thinkingVerbs = Self.defaultThinkingVerbs
        keystrokeMonitorEnabled = false
        keystrokeBundleIDs = Self.defaultKeystrokeBundleIDs
        doneDuration = Self.defaultDoneDuration
        toolDuration = Self.defaultToolDuration
        typingDuration = Self.defaultTypingDuration
        thinkingVerbInterval = Self.defaultThinkingVerbInterval
        waitingDelay = 0
        waitingEnabled = true
        donePersistent = false
        toolPersistent = false
        typingPersistent = false
        typingOverridesWaiting = false
        bubbleEnabled = true
        petSize = .medium
        toolPerToolEnabled = false
        activeThemeId = "default"
    }

    // MARK: - Theme 적용

    /// 빌트인/사용자 테마를 현재 PetTheme에 반영.
    func applyTheme(_ theme: Theme) {
        clearAllImages()
        for (rawKey, style) in theme.motions {
            // Theme JSON은 [String: MotionStyle]이지만 내부 dispatch는 MotionKey enum으로.
            // 알 수 없는 key는 무시 (앞으로 enum case 빠뜨려도 무시되는 안전 동작).
            guard let key = MotionKey(rawValue: rawKey) else { continue }
            var s = style
            // 사용자 테마의 imagePath는 themes/<id>/ 폴더를 가리킬 수 있음.
            // 그 파일을 ImageStore로 복사해서 fresh 경로로 교체.
            if let path = s.imagePath, !path.isEmpty,
               FileManager.default.fileExists(atPath: path) {
                let src = URL(fileURLWithPath: path)
                if let copied = try? ImageStore.copy(from: src, motionKey: rawKey) {
                    s.imagePath = copied
                } else {
                    s.imagePath = nil
                }
            } else if s.imagePath != nil {
                // 경로는 있는데 파일이 없으면 nil로
                s.imagePath = nil
            }
            setStyle(s, forKey: key)
        }
        if let verbs = theme.thinkingVerbs {
            thinkingVerbs = verbs
        }
        if let prefix = theme.bundledImagePrefix {
            applyBundledImages(prefix: prefix)
        }
        activeThemeId = theme.id
    }

    /// 현재 PetTheme 상태를 사용자 테마로 캡처. 이미지는 themes/<id>/ 폴더로 복사하여 자가 포함.
    func captureCurrentAsTheme(id: String, name: String, description: String) -> Theme {
        let themeDir = ThemeStore.imageDir(forThemeId: id)
        try? FileManager.default.createDirectory(at: themeDir, withIntermediateDirectories: true)

        var motions: [String: MotionStyle] = [:]
        for key in MotionKey.allCases {
            let rawKey = key.rawValue
            var style = self.style(forKey: key)
            if let path = style.imagePath, !path.isEmpty,
               FileManager.default.fileExists(atPath: path) {
                let src = URL(fileURLWithPath: path)
                let ext = src.pathExtension.isEmpty ? "png" : src.pathExtension
                let dest = themeDir.appendingPathComponent("\(rawKey).\(ext)")
                try? FileManager.default.removeItem(at: dest)
                do {
                    try FileManager.default.copyItem(at: src, to: dest)
                    style.imagePath = dest.path
                } catch {
                    style.imagePath = nil
                }
            }
            motions[rawKey] = style
        }

        return Theme(
            id: id,
            name: name,
            themeDescription: description,
            isBuiltin: false,
            motions: motions,
            thinkingVerbs: thinkingVerbs,
            bundledImagePrefix: nil
        )
    }

    // MARK: - MotionKey 기반 dict 접근
    //
    // 모든 motion 스타일은 `motions: [MotionKey: MotionStyle]` dict에 저장됨.
    // 외부에서 SwiftUI Binding이 필요하면 binding(for:)을 사용.

    /// MotionKey에 해당하는 MotionStyle을 가져옴. dict에 없으면 정적 기본값.
    func style(forKey key: MotionKey) -> MotionStyle {
        motions[key] ?? Self.defaultMotions[key] ?? Self.defaultIdle
    }

    /// MotionKey에 해당하는 MotionStyle을 통째로 교체.
    func setStyle(_ style: MotionStyle, forKey key: MotionKey) {
        motions[key] = style
    }

    /// MotionKey에 해당하는 MotionStyle.imagePath만 교체. (read-modify-write로 @Published 트리거 보장)
    func setImagePath(_ path: String?, forKey key: MotionKey) {
        var s = style(forKey: key)
        s.imagePath = path
        motions[key] = s
    }

    /// SwiftUI에서 `$theme.idle` 대체로 사용. 항상 비-옵셔널 MotionStyle 보장.
    func binding(for key: MotionKey) -> Binding<MotionStyle> {
        Binding(
            get: { self.style(forKey: key) },
            set: { self.motions[key] = $0 }
        )
    }

    /// Snapshot의 motions/legacy fields 둘 중 가능한 데이터를 모아 dict 복원.
    private static func loadMotions(from snap: Snapshot) -> [MotionKey: MotionStyle] {
        if let raw = snap.motions {
            var result: [MotionKey: MotionStyle] = defaultMotions
            for (rawKey, style) in raw {
                if let key = MotionKey(rawValue: rawKey) {
                    result[key] = style
                }
            }
            return result
        }
        // Legacy 개별 필드 복원
        return [
            .idle:          snap.idle          ?? defaultIdle,
            .waiting:       snap.waiting       ?? defaultWaiting,
            .done:          snap.done          ?? defaultDone,
            .tool:          snap.tool          ?? defaultTool,
            .toolBash:      snap.toolBash      ?? defaultToolBash,
            .toolWrite:     snap.toolWrite     ?? defaultToolWrite,
            .toolEdit:      snap.toolEdit      ?? defaultToolEdit,
            .toolWebFetch:  snap.toolWebFetch  ?? defaultToolWebFetch,
            .toolWebSearch: snap.toolWebSearch ?? defaultToolWebSearch,
            .typing:        snap.typing        ?? defaultTyping,
            .thinking:      snap.thinking      ?? defaultThinking,
            .permission:    snap.permission    ?? defaultPermission,
        ]
    }

    // MARK: - 일괄 처리

    private func clearAllImages() {
        for key in MotionKey.allCases {
            ImageStore.delete(path: style(forKey: key).imagePath)
            setImagePath(nil, forKey: key)
        }
    }

    private func applyBundledImages(prefix: String) {
        let extensions = ["gif", "png", "jpg", "jpeg", "apng", "heic"]
        let subdir: String? = prefix.isEmpty ? nil : prefix
        for key in MotionKey.allCases {
            let name = key.rawValue
            var foundURL: URL?
            for ext in extensions {
                if let url = Bundle.main.url(forResource: name, withExtension: ext, subdirectory: subdir) {
                    foundURL = url
                    break
                }
            }
            guard let url = foundURL else { continue }
            do {
                let saved = try ImageStore.copy(from: url, motionKey: name)
                setImagePath(saved, forKey: key)
            } catch {
                print("[Theme] image copy \(name) failed: \(error)")
            }
        }
    }

    func style(for motion: Motion) -> MotionStyle {
        guard let key = MotionKey(motion: motion) else { return Self.defaultIdle }
        return style(forKey: key)
    }

    /// 도구 이름별로 별도 MotionStyle 매핑. 매칭 안 되면 nil → 호출자는 self.tool 폴백.
    func style(forToolName name: String?) -> MotionStyle? {
        guard let key = MotionKey.fromToolName(name) else { return nil }
        return style(forKey: key)
    }
}

extension Color {
    init(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        var rgb: UInt64 = 0
        Scanner(string: s).scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8)  & 0xFF) / 255.0
        let b = Double( rgb        & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }

    var hexString: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .black
        let r = Int((ns.redComponent   * 255.0).rounded())
        let g = Int((ns.greenComponent * 255.0).rounded())
        let b = Int((ns.blueComponent  * 255.0).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
