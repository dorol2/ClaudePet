// KeystrokeMonitor.swift
//
// NSEvent 글로벌 모니터로 키스트로크 감지. 터미널 앱이 frontmost일 때만 콜백 호출.
// macOS Accessibility 권한 필요 (System Settings → Privacy & Security → Accessibility).
// 키 코드/내용은 사용하지 않고 "키가 눌렸음" 신호만 전달.
import AppKit
import ApplicationServices

@MainActor
final class KeystrokeMonitor {
    /// 키 입력이 감지될 때마다 호출 (메인 액터에서)
    var onKeystroke: (() -> Void)?

    /// 이 번들 ID를 가진 앱이 frontmost일 때만 키 입력으로 카운트
    var allowedBundleIDs: Set<String> = [
        "com.apple.Terminal",
        "com.googlecode.iterm2",
        "dev.warp.Warp-Stable",
        "io.alacritty",
        "net.kovidgoyal.kitty",
        "com.github.wez.wezterm",
        "co.zeit.hyper",
    ]

    private var monitor: Any?

    var isRunning: Bool { monitor != nil }

    /// 현재 Accessibility 권한이 부여되었는지 확인
    static func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    /// 시스템 권한 다이얼로그 띄우면서 확인. 처음 호출 시 사용자에게 안내됨.
    @discardableResult
    static func requestAccessibilityPermission() -> Bool {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let opts: NSDictionary = [key: true]
        return AXIsProcessTrustedWithOptions(opts)
    }

    func start() {
        guard monitor == nil else { return }
        // 권한 없으면 시스템 다이얼로그 안내. 권한 부여 후엔 보통 앱 재시작 필요.
        _ = Self.requestAccessibilityPermission()

        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] _ in
            Task { @MainActor in self?.handleKeyDown() }
        }
        print("[KeystrokeMonitor] started (permission: \(Self.hasAccessibilityPermission()))")
    }

    func stop() {
        if let m = monitor {
            NSEvent.removeMonitor(m)
            monitor = nil
            print("[KeystrokeMonitor] stopped")
        }
    }

    private func handleKeyDown() {
        let bundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "<nil>"
        let allowed = allowedBundleIDs.contains(bundle)
        print("[KeystrokeMonitor] keyDown frontmost=\(bundle) allowed=\(allowed)")
        guard allowed else { return }
        onKeystroke?()
    }
}
