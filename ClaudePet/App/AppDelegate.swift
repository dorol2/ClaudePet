// AppDelegate.swift
import SwiftUI
import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NSPanel?
    private var statusItem: NSStatusItem?
    private let state = PetState()
    private let theme = PetTheme()
    private let logStore = LogStore()
    private let themeStore = ThemeStore()
    private var server: PetServer?
    private var prefsWindow: NSWindow?
    private let keystrokeMonitor = KeystrokeMonitor()
    private var keystrokeObserver: AnyCancellable?
    private var keystrokeBundleObserver: AnyCancellable?
    private var durationObserver: AnyCancellable?
    private var petSizeObserver: AnyCancellable?
    private var bubbleHeightObserver: AnyCancellable?
    private var themeIdObserver: AnyCancellable?
    private var userThemesObserver: AnyCancellable?
    private var themesSubmenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Dock에서 안 보이게 (Info.plist에 LSUIElement도 같이 설정해야 함)
        NSApp.setActivationPolicy(.accessory)

        setupPanel()
        setupStatusItem()
        startServer()
        setupKeystrokeMonitor()
        setupDurationSync()
        setupPetSizeSync()

        // UI test에서 status bar 클릭 우회용. --ui-test-preferences 인자가 있으면
        // Preferences 창을 즉시 띄움.
        if CommandLine.arguments.contains("--ui-test-preferences") {
            Task { @MainActor in
                self.openPreferences()
            }
        }
    }

    // MARK: - PetSize / 말풍선 높이에 따른 패널 사이징

    private func setupPetSizeSync() {
        petSizeObserver = theme.$petSize
            .removeDuplicates()
            .dropFirst()    // 초기값은 setupPanel이 이미 사용
            .sink { [weak self] _ in
                Task { @MainActor in self?.applyPanelSize() }
            }
        // 말풍선이 기본 영역보다 커지면(예: waiting label 여러 개, 긴 라벨) 패널을 확장.
        bubbleHeightObserver = state.$measuredBubbleSize
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor in self?.applyPanelSize() }
            }
    }

    /// 현재 petSize의 기본 패널 크기 + 말풍선이 기본 영역을 넘은 만큼을 더해 패널을 리사이즈.
    /// 높이는 origin.y 유지로 캐릭터 위치를 고정한 채 위로 확장하고,
    /// 폭은 panel midX를 유지하여 캐릭터 X 위치가 흔들리지 않게 한다.
    /// visibleFrame을 벗어나면 clamp.
    private func applyPanelSize() {
        guard let panel = self.panel else { return }
        let size = theme.petSize
        // PetView 외곽 padding 8pt × 2 = 16
        let baseBubbleRoomW = size.panelWidth - 16
        let baseBubbleRoomH = size.panelHeight - size.characterSize - 16
        let measured = state.measuredBubbleSize
        let extraW = max(0, measured.width - baseBubbleRoomW)
        let extraH = max(0, measured.height - baseBubbleRoomH)
        let newW = size.panelWidth + extraW
        let newH = size.panelHeight + extraH

        let oldFrame = panel.frame
        // midX 유지로 캐릭터 X 안 흔들리게.
        var newOriginX = oldFrame.midX - newW / 2
        // 화면 가장자리 clamp (현재 panel이 속한 screen의 visibleFrame 기준).
        if let screen = panel.screen ?? NSScreen.main {
            let v = screen.visibleFrame
            // 패널이 화면 폭보다 클 경우 minX를 시작점으로
            let maxOriginX = max(v.minX, v.maxX - newW)
            newOriginX = min(max(newOriginX, v.minX), maxOriginX)
        }
        let newFrame = NSRect(x: newOriginX, y: oldFrame.minY, width: newW, height: newH)
        panel.setFrame(newFrame, display: true, animate: false)
    }

    // MARK: - Duration 동기화

    private func setupDurationSync() {
        syncDurations()  // 초기 1회
        durationObserver = theme.objectWillChange
            .sink { [weak self] _ in
                // objectWillChange는 변경 직전에 발화 → 다음 런루프에서 읽어야 신값
                Task { @MainActor in self?.syncDurations() }
            }
    }

    private func syncDurations() {
        state.doneDuration = theme.doneDuration
        state.toolDuration = theme.toolDuration
        state.typingDuration = theme.typingDuration
        state.thinkingVerbInterval = theme.thinkingVerbInterval
        state.donePersistent = theme.donePersistent
        state.toolPersistent = theme.toolPersistent
        state.typingPersistent = theme.typingPersistent
        state.typingOverridesWaiting = theme.typingOverridesWaiting
        state.waitingDelay = theme.waitingDelay
        state.waitingEnabled = theme.waitingEnabled
    }

    // MARK: - 키 입력 감지

    private func setupKeystrokeMonitor() {
        keystrokeMonitor.onKeystroke = { [weak self] in
            self?.state.triggerTyping()
        }
        // 초기 bundle ID 동기화
        keystrokeMonitor.allowedBundleIDs = Set(theme.keystrokeBundleIDs)
        // bundle ID 변경 시 즉시 갱신
        keystrokeBundleObserver = theme.$keystrokeBundleIDs
            .sink { [weak self] ids in
                Task { @MainActor in
                    self?.keystrokeMonitor.allowedBundleIDs = Set(ids)
                }
            }
        // theme 토글 변화를 관찰해서 시작/중지
        keystrokeObserver = theme.$keystrokeMonitorEnabled
            .removeDuplicates()
            .sink { [weak self] enabled in
                Task { @MainActor in
                    guard let self else { return }
                    if enabled { self.keystrokeMonitor.start() }
                    else       { self.keystrokeMonitor.stop() }
                }
            }
    }

    // MARK: - 떠다니는 펫 윈도우

    private static let panelOriginKey = "ClaudePet.panelOrigin"

    private func savedPanelOrigin() -> NSPoint? {
        guard let dict = UserDefaults.standard.dictionary(forKey: Self.panelOriginKey),
              let x = dict["x"] as? Double,
              let y = dict["y"] as? Double else { return nil }
        let p = NSPoint(x: x, y: y)
        // 모니터 분리/해상도 변경 대비: 어느 스크린에도 안 닿으면 무시
        for screen in NSScreen.screens where NSPointInRect(p, screen.frame) {
            return p
        }
        return nil
    }

    private func savePanelOrigin() {
        guard let panel = self.panel else { return }
        let p = panel.frame.origin
        UserDefaults.standard.set(["x": p.x, "y": p.y], forKey: Self.panelOriginKey)
    }

    private func defaultPanelOrigin(size: NSSize) -> NSPoint {
        guard let screen = NSScreen.main else { return .zero }
        return NSPoint(
            x: screen.visibleFrame.maxX - size.width - 40,
            y: screen.visibleFrame.minY + 80
        )
    }

    private func setupPanel() {
        let size = NSSize(width: theme.petSize.panelWidth, height: theme.petSize.panelHeight)
        let origin = savedPanelOrigin() ?? defaultPanelOrigin(size: size)

        // NSPanel: nonactivating = 클릭해도 앱이 활성화되지 않음
        let panel = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.delegate = self  // windowDidMove에서 위치 저장

        // SwiftUI 뷰를 패널에 호스팅
        let hosting = NSHostingView(
            rootView: PetView()
                .environmentObject(state)
                .environmentObject(theme)
        )
        hosting.frame = NSRect(origin: .zero, size: size)
        hosting.autoresizingMask = [.width, .height]
        // SwiftUI intrinsic size로 hosting view 크기가 흔들리지 않게.
        if #available(macOS 13.0, *) {
            hosting.sizingOptions = []
        }
        panel.contentView = hosting

        panel.orderFrontRegardless()
        self.panel = panel
    }

    // MARK: - 메뉴바 아이콘

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "🐾"
        let menu = NSMenu()
        menu.addItem(withTitle: "Show / Hide Pet", action: #selector(toggleVisibility), keyEquivalent: "h")
            .target = self
        menu.addItem(withTitle: "Reset Position", action: #selector(resetPosition), keyEquivalent: "")
            .target = self
        menu.addItem(.separator())

        // Theme 서브메뉴
        let themesItem = NSMenuItem(title: "Theme", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        themesItem.submenu = submenu
        self.themesSubmenu = submenu
        menu.addItem(themesItem)
        refreshThemesSubmenu()
        // 테마 변경 시 체크마크 갱신
        themeIdObserver = theme.$activeThemeId
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor in self?.refreshThemesSubmenu() }
            }
        // 사용자 테마 추가/삭제 시 메뉴 갱신
        userThemesObserver = themeStore.$userThemes
            .sink { [weak self] _ in
                Task { @MainActor in self?.refreshThemesSubmenu() }
            }

        menu.addItem(.separator())
        menu.addItem(withTitle: "Preferences…", action: #selector(openPreferences), keyEquivalent: ",")
            .target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "About ClaudePet", action: #selector(showAbout), keyEquivalent: "")
            .target = self
        menu.addItem(withTitle: "Quit ClaudePet", action: #selector(quit), keyEquivalent: "q")
            .target = self
        item.menu = menu
        self.statusItem = item
    }

    @objc private func showAbout() {
        // LSUIElement 앱이라 About panel을 띄울 때 앱 활성화 필요
        NSApp.activate(ignoringOtherApps: true)
        let credits = NSAttributedString(
            string: "Claude Code 세션과 함께 살아 움직이는 macOS 데스크탑 펫\nhttps://github.com/dorol2/ClaudePet",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        )
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: credits,
        ])
    }

    private func refreshThemesSubmenu() {
        guard let submenu = themesSubmenu else { return }
        submenu.removeAllItems()
        let builtin = ThemeCatalog.builtin
        let user = themeStore.userThemes

        for t in builtin {
            submenu.addItem(makeThemeMenuItem(t))
        }
        if !user.isEmpty {
            submenu.addItem(.separator())
            for t in user {
                submenu.addItem(makeThemeMenuItem(t))
            }
        }
    }

    private func makeThemeMenuItem(_ t: Theme) -> NSMenuItem {
        let mi = NSMenuItem(title: t.name,
                            action: #selector(applyThemeFromMenu(_:)),
                            keyEquivalent: "")
        mi.target = self
        mi.representedObject = t.id
        mi.state = (theme.activeThemeId == t.id) ? .on : .off
        return mi
    }

    @objc private func applyThemeFromMenu(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let t = themeStore.allThemes.first(where: { $0.id == id }) else { return }
        theme.applyTheme(t)
    }

    @objc private func toggleVisibility() {
        guard let p = panel else { return }
        if p.isVisible { p.orderOut(nil) } else { p.orderFrontRegardless() }
    }

    @objc private func resetPosition() {
        guard let p = panel else { return }
        let origin = defaultPanelOrigin(size: p.frame.size)
        p.setFrameOrigin(origin)
        savePanelOrigin()
    }

    @objc private func openPreferences() {
        if let w = prefsWindow {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let host = NSHostingController(
            rootView: PreferencesView()
                .environmentObject(theme)
                .environmentObject(logStore)
                .environmentObject(themeStore)
        )
        let w = NSWindow(contentViewController: host)
        w.title = "ClaudePet Preferences"
        w.styleMask = [.titled, .closable]
        w.isReleasedWhenClosed = false
        w.center()
        w.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.prefsWindow = w
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - HTTP 서버

    private func startServer() {
        do {
            let s = try PetServer(port: 9876, state: state, logStore: logStore)
            try s.start()
            server = s
            print("[ClaudePet] listening on http://127.0.0.1:9876")
        } catch {
            print("[ClaudePet] server start failed: \(error)")
        }
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        // 사용자 드래그 후 위치 저장
        savePanelOrigin()
    }
}
