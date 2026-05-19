// PreferencesView.swift
import SwiftUI
import ServiceManagement

struct PreferencesView: View {
    @EnvironmentObject var theme: PetTheme
    @EnvironmentObject var logStore: LogStore
    @EnvironmentObject var themeStore: ThemeStore
    @State private var launchAtLogin: Bool = false
    @State private var selection: PrefPage = .idle
    @State private var showingNewThemeSheet = false
    @State private var editingThemeId: String? = nil
    @State private var newThemeName = ""
    @State private var newThemeDescription = ""
    @State private var deleteConfirmTheme: Theme? = nil

    enum PrefPage: String, Identifiable, CaseIterable, Hashable {
        case idle, waiting, done, tool, typing, thinking, permission
        case bubble
        case themes
        case general
        case developer

        var id: String { rawValue }

        var title: String {
            switch self {
            case .idle:       return "Idle"
            case .waiting:    return "Waiting"
            case .done:       return "Done"
            case .tool:       return "Tool"
            case .typing:     return "Typing"
            case .thinking:   return "Thinking"
            case .permission:    return "Permission"
            case .bubble:        return "말풍선"
            case .themes:        return "테마"
            case .general:       return "일반"
            case .developer:     return "개발자"
            }
        }

        var subtitle: String {
            switch self {
            case .idle:          return "대기"
            case .waiting:       return "입력 대기"
            case .done:          return "완료"
            case .tool:          return "도구 실행"
            case .typing:        return "타이핑 중"
            case .thinking:      return "생각 중"
            case .permission:    return "권한 요청"
            case .bubble:        return "표시 / 문구"
            case .themes:        return "외형 프리셋"
            case .general:       return "옵션 / 초기화"
            case .developer:     return "로그"
            }
        }

        var systemImage: String {
            switch self {
            case .idle:          return "pawprint"
            case .waiting:       return "moon.zzz"
            case .done:          return "party.popper"
            case .tool:          return "hammer"
            case .typing:        return "keyboard"
            case .thinking:      return "brain"
            case .permission:    return "hand.raised"
            case .bubble:        return "bubble.left"
            case .themes:        return "paintpalette"
            case .general:       return "gearshape"
            case .developer:     return "ladybug"
            }
        }
    }

    /// Tool 페이지 안에서 통합/개별 도구를 전환하는 sub-picker용
    enum ToolSubPage: String, Identifiable, CaseIterable, Hashable {
        case unified, bash, write, edit, webFetch, webSearch
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .unified:   return "통합"
            case .bash:      return "Bash"
            case .write:     return "Write"
            case .edit:      return "Edit"
            case .webFetch:  return "WebFetch"
            case .webSearch: return "WebSearch"
            }
        }
    }

    @State private var selectedTool: ToolSubPage = .unified

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .frame(minWidth: 720, minHeight: 540)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            Section("모션") {
                ForEach([
                    PrefPage.idle, .waiting, .done,
                    .tool, .thinking, .permission, .typing
                ]) { p in
                    sidebarRow(p)
                }
            }
            Section("기타") {
                sidebarRow(.general)
                sidebarRow(.bubble)
                sidebarRow(.themes)
            }
            Section("개발자") {
                sidebarRow(.developer)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 240)
    }

    @ViewBuilder
    private func sidebarRow(_ page: PrefPage) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(page.title).font(.system(size: 13))
                Text(page.subtitle).font(.system(size: 10)).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: page.systemImage)
        }
        .tag(page)
        .accessibilityIdentifier("sidebar-\(page.rawValue)")
    }

    // MARK: - Detail

    @ViewBuilder
    private var detail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                pageBody
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(selection.title).font(.system(size: 22, weight: .bold))
            Text(selection.subtitle).font(.system(size: 12)).foregroundStyle(.secondary)
        }
        .padding(.bottom, 6)
    }

    @ViewBuilder
    private var pageBody: some View {
        switch selection {
        case .idle:
            MotionStyleEditor(title: "Idle (대기)", motionKey: "idle", style: theme.binding(for: .idle))
        case .waiting:
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Waiting 모션 사용", isOn: $theme.waitingEnabled)
                    .toggleStyle(.checkbox)
                    .accessibilityIdentifier("toggle-waiting-enabled")
                Text("끄면 Claude의 응답 대기 알림이 와도 펫에 표시하지 않습니다. (다른 모션은 영향 없음)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Divider().padding(.vertical, 4)
                MotionStyleEditor(title: "Waiting (입력 대기)", motionKey: "waiting", style: theme.binding(for: .waiting),
                                  duration: .init(label: "진입 지연", value: $theme.waitingDelay,
                                                  range: 0...3600, step: 0.5,
                                                  sliderHidden: true))
                    .disabled(!theme.waitingEnabled)
                    .opacity(theme.waitingEnabled ? 1.0 : 0.5)
                Text("진입 지연: waiting 이벤트가 와도 이 시간만큼 기다린 뒤 모션 전환. 그 사이 다른 이벤트(done/clear/thinking)가 오면 진입 안 함. 0초 = 즉시.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .done:
            MotionStyleEditor(title: "Done (완료)", motionKey: "done", style: theme.binding(for: .done),
                              duration: .init(label: "유지 시간", value: $theme.doneDuration,
                                              range: 0.5...20, step: 0.5,
                                              persistent: $theme.donePersistent))
        case .tool:
            toolPage
        case .typing:
            typingPage
        case .thinking:
            thinkingPage
        case .permission:
            MotionStyleEditor(title: "Permission (권한 요청)", motionKey: "permission", style: theme.binding(for: .permission))
        case .bubble:
            bubblePage
        case .themes:
            themesPage
        case .general:
            generalPage
        case .developer:
            developerPage
        }
    }

    private var toolPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            Toggle("도구별 개별 설정 사용", isOn: $theme.toolPerToolEnabled)
                .toggleStyle(.checkbox)
            Text(theme.toolPerToolEnabled
                 ? "각 도구가 자체 스타일을 사용합니다. 매칭 안 되는 도구는 \"통합\" 스타일이 폴백."
                 : "모든 도구가 \"통합\" 스타일을 사용합니다. 개별 도구별로 다르게 표시하려면 위 토글을 켜세요.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider().padding(.vertical, 2)

            Picker("", selection: $selectedTool) {
                ForEach(ToolSubPage.allCases) { sub in
                    Text(sub.displayName).tag(sub)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if selectedTool != .unified, !theme.toolPerToolEnabled {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill").foregroundStyle(.orange)
                    Text("현재 \"통합\" 모드입니다. 이 도구별 설정을 사용하려면 위 토글을 켜세요.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.08)))
            }

            toolEditorForSelected
        }
    }

    @ViewBuilder
    private var toolEditorForSelected: some View {
        switch selectedTool {
        case .unified:
            MotionStyleEditor(title: "Tool (통합)", motionKey: "tool", style: theme.binding(for: .tool),
                              duration: .init(label: "유지 시간", value: $theme.toolDuration,
                                              range: 0.5...10, step: 0.5,
                                              persistent: $theme.toolPersistent))
        case .bash:
            MotionStyleEditor(title: "Bash", motionKey: "toolBash", style: theme.binding(for: .toolBash))
        case .write:
            MotionStyleEditor(title: "Write", motionKey: "toolWrite", style: theme.binding(for: .toolWrite))
        case .edit:
            MotionStyleEditor(title: "Edit", motionKey: "toolEdit", style: theme.binding(for: .toolEdit))
        case .webFetch:
            MotionStyleEditor(title: "WebFetch", motionKey: "toolWebFetch", style: theme.binding(for: .toolWebFetch))
        case .webSearch:
            MotionStyleEditor(title: "WebSearch", motionKey: "toolWebSearch", style: theme.binding(for: .toolWebSearch))
        }
    }

    private var typingPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            MotionStyleEditor(title: "Typing (타이핑 중)", motionKey: "typing", style: theme.binding(for: .typing),
                              duration: .init(label: "유지 시간", value: $theme.typingDuration,
                                              range: 0.3...5, step: 0.1,
                                              persistent: $theme.typingPersistent))

            Divider().padding(.vertical, 4)

            section("동작 옵션")
            Toggle("터미널 키 입력 감지 (Typing 모션 활성화)", isOn: $theme.keystrokeMonitorEnabled)
                .toggleStyle(.checkbox)
            Text("macOS Accessibility 권한이 필요합니다. 시스템 설정 → 개인정보 보호 및 보안 → 손쉬운 사용에서 ClaudePet을 허용한 뒤 앱 재시작.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle("Waiting 중 Typing 시 응답한 것으로 처리", isOn: $theme.typingOverridesWaiting)
                .toggleStyle(.checkbox)
            Text("켜면 Claude가 응답 대기(waiting) 중일 때 키 입력이 들어오면 사용자가 응답한 것으로 간주하여 waiting을 즉시 해소합니다. Typing 모션이 표시되고 타이핑이 멈추면 idle 상태로 돌아갑니다.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider().padding(.vertical, 4)

            section("동작 방식")
            Text("Typing은 기본적으로 우선순위가 가장 낮은 모션입니다. 다른 모션(permission / done / tool / waiting / thinking)이 활성화돼 있으면 키 입력을 감지해도 펫에 표시되지 않고, 모든 모션이 idle일 때만 표시됩니다. 즉 \"Claude는 쉬는데 너는 뭐 쓰고 있구나\" 알림용. (단, 위 \"Waiting 중에도 Typing 우선 표시\" 옵션을 켜면 waiting보다 우선합니다.)")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider().padding(.vertical, 4)

            section("감지 대상 앱 (Bundle ID)")
            Text("아래 목록에 등록된 앱이 frontmost일 때만 키 입력을 typing 모션으로 인식합니다. 한 줄에 하나씩 bundle ID를 입력. 본인 터미널의 bundle ID는 그 터미널에서 다음 명령으로 확인:")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("osascript -e 'id of app \"<앱이름>\"'")
                .font(.system(size: 11, design: .monospaced))
                .padding(.horizontal, 6).padding(.vertical, 3)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(4)
            BundleIDsEditor(ids: $theme.keystrokeBundleIDs)
        }
    }

    private var thinkingPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            MotionStyleEditor(title: "Thinking (생각 중)", motionKey: "thinking", style: theme.binding(for: .thinking),
                              duration: .init(label: "Verb 간격", value: $theme.thinkingVerbInterval,
                                              range: 0.3...10, step: 0.1))
            Divider().padding(.vertical, 4)
            section("Thinking Verbs")
            Text("Thinking 모션 중 말풍선이 verb를 순환하며 표시합니다. 한 줄에 하나씩.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            ThinkingVerbsEditor(verbs: $theme.thinkingVerbs)
        }
    }

    private var themesPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("외형 프리셋을 선택하면 모든 모션의 색·이모지·이미지·말풍선·verb가 한 번에 바뀝니다. 동작 설정(크기, 자동 시작, 키 감지 등)은 그대로 유지.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            section("빌트인")
            ForEach(ThemeCatalog.builtin) { t in
                ThemeCard(theme: t,
                          isActive: theme.activeThemeId == t.id,
                          isBuiltin: true,
                          onApply: { theme.applyTheme(t) },
                          onUpdate: nil,
                          onDelete: nil)
            }

            Divider().padding(.vertical, 4)

            HStack {
                section("사용자 테마")
                Spacer()
                Button {
                    NSWorkspace.shared.open(ThemeStore.directory)
                } label: {
                    Label("Finder에서 보기", systemImage: "folder")
                }
                .controlSize(.small)
                .help("저장된 테마 폴더를 Finder로 엽니다")
                Button {
                    editingThemeId = nil
                    newThemeName = ""
                    newThemeDescription = ""
                    showingNewThemeSheet = true
                } label: {
                    Label("현재 설정 저장…", systemImage: "plus.circle")
                }
                .controlSize(.small)
            }

            if themeStore.userThemes.isEmpty {
                Text("저장된 사용자 테마가 없습니다. 모션·색·이미지를 원하는대로 꾸민 뒤 \"현재 설정 저장\"으로 만들 수 있습니다.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(themeStore.userThemes) { t in
                    ThemeCard(theme: t,
                              isActive: theme.activeThemeId == t.id,
                              isBuiltin: false,
                              onApply: { theme.applyTheme(t) },
                              onUpdate: {
                                  editingThemeId = t.id
                                  newThemeName = t.name
                                  newThemeDescription = t.themeDescription
                                  showingNewThemeSheet = true
                              },
                              onDelete: { deleteConfirmTheme = t })
                }
            }
        }
        .sheet(isPresented: $showingNewThemeSheet) {
            ThemeNameSheet(
                isEditing: editingThemeId != nil,
                name: $newThemeName,
                description: $newThemeDescription,
                onSave: { saveCurrentAsTheme() },
                onCancel: { showingNewThemeSheet = false }
            )
        }
        .alert("테마 삭제", isPresented: Binding(
            get: { deleteConfirmTheme != nil },
            set: { if !$0 { deleteConfirmTheme = nil } }
        ), presenting: deleteConfirmTheme) { t in
            Button("삭제", role: .destructive) {
                themeStore.delete(id: t.id)
                if theme.activeThemeId == t.id {
                    theme.activeThemeId = nil
                }
                deleteConfirmTheme = nil
            }
            Button("취소", role: .cancel) { deleteConfirmTheme = nil }
        } message: { t in
            Text("\"\(t.name)\" 테마를 영구 삭제합니다. 저장된 이미지 사본도 함께 제거됩니다.")
        }
    }

    private func saveCurrentAsTheme() {
        let name = newThemeName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let desc = newThemeDescription.trimmingCharacters(in: .whitespaces)
        let id = editingThemeId ?? UUID().uuidString
        let newTheme = theme.captureCurrentAsTheme(id: id, name: name, description: desc)
        themeStore.save(newTheme)
        theme.activeThemeId = id
        showingNewThemeSheet = false
    }

    private var bubblePage: some View {
        VStack(alignment: .leading, spacing: 16) {
            Toggle("말풍선 표시 (마스터 스위치)", isOn: $theme.bubbleEnabled)
                .toggleStyle(.checkbox)
            Text("끄면 어떤 모션에서도 말풍선이 나타나지 않습니다. 각 모션별 표시 여부와 문구는 \"모션\" 섹션의 각 모션 페이지에서 설정.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Divider().padding(.vertical, 4)
            section("템플릿 변수")
            VStack(alignment: .leading, spacing: 4) {
                placeholderRow("{emoji}", "모션의 이모지로 치환")
                placeholderRow("{label}", "Waiting: 세션 라벨 (여러 개면 라벨별로 줄바꿈)")
                placeholderRow("{tool}", "Tool: 도구 이름 (Bash, Write, …)")
                placeholderRow("{tool_emoji}", "Tool: 도구별 이모지 (💻/✍️ 등)")
                placeholderRow("{verb}", "Thinking: 현재 verb")
            }
        }
    }

    private func placeholderRow(_ key: String, _ desc: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(key).font(.system(size: 11, design: .monospaced))
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(4)
            Text(desc).font(.system(size: 11)).foregroundStyle(.secondary)
        }
    }

    private var generalPage: some View {
        VStack(alignment: .leading, spacing: 16) {
            section("크기")
            HStack(spacing: 12) {
                Text("펫 크기").frame(width: 80, alignment: .leading)
                Picker("", selection: $theme.petSize) {
                    ForEach(PetSize.allCases) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 240)
            }
            Text("이미지/색상은 비율 유지하면서 함께 스케일됩니다. 패널 자체 크기도 변경됨.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider().padding(.vertical, 4)

            section("시작 옵션")
            Toggle("로그인 시 자동 시작", isOn: $launchAtLogin)
                .toggleStyle(.checkbox)
                .onAppear { launchAtLogin = currentLaunchAtLogin() }
                .onChange(of: launchAtLogin) { _, newValue in
                    setLaunchAtLogin(newValue)
                }
            Text("macOS 로그인 시 ClaudePet이 자동으로 실행됩니다. 시스템 설정 → 일반 → 로그인 항목에서도 같은 설정이 표시됨.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider().padding(.vertical, 4)
            HStack {
                Spacer()
                Button("기본값으로 되돌리기") {
                    theme.resetToDefaults()
                }
            }
        }
    }

    private func currentLaunchAtLogin() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else { return }
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[LaunchAtLogin] failed: \(error)")
        }
    }

    private var developerPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("로그 표시 (체크 시 이후 이벤트 기록)", isOn: $logStore.enabled)
                .toggleStyle(.checkbox)
            Text("PetServer가 받는 모든 요청을 한 줄로 표시합니다. 체크 해제 시 신규 기록이 멈추지만 기존 로그는 유지 (Clear로 비우기). 최대 300개까지 보관.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text("\(logStore.entries.count) entries")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear") { logStore.clear() }
                    .controlSize(.small)
                    .disabled(logStore.entries.isEmpty)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        if logStore.entries.isEmpty {
                            Text(logStore.enabled
                                 ? "(기록 대기 중 — 펫 서버로 이벤트가 들어오면 여기 표시됩니다)"
                                 : "(로그 표시가 꺼져 있습니다)")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .padding(8)
                        } else {
                            ForEach(logStore.entries) { entry in
                                Text(entry.line)
                                    .font(.system(size: 11, design: .monospaced))
                                    .textSelection(.enabled)
                                    .id(entry.id)
                            }
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(Color(.textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .frame(minHeight: 300, maxHeight: .infinity)
                .onChange(of: logStore.entries.count) { _, _ in
                    if let last = logStore.entries.last {
                        withAnimation(.easeOut(duration: 0.15)) {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }
        }
    }

    private func section(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

private struct LabeledRow<Content: View>: View {
    let label: String
    @ViewBuilder var content: () -> Content
    var body: some View {
        HStack {
            Text(label).frame(width: 160, alignment: .leading)
            content()
        }
    }
}

struct MotionDurationConfig {
    let label: String
    let value: Binding<TimeInterval>
    let range: ClosedRange<Double>
    let step: Double
    /// 있으면 슬라이더 옆에 "유지" 체크박스 표시. ON이면 슬라이더 무시하고 다음 이벤트까지 유지
    var persistent: Binding<Bool>? = nil
    /// true면 슬라이더 숨기고 숫자 입력만 표시. (긴 범위에 적합)
    var sliderHidden: Bool = false
}

private struct MotionStyleEditor: View {
    let title: String
    let motionKey: String
    @Binding var style: MotionStyle
    var duration: MotionDurationConfig? = nil

    @State private var isHoveringPreview = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Button(action: pickImage) {
                preview
                    .overlay(
                        Color.black.opacity(isHoveringPreview ? 0.18 : 0)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    )
                    .overlay(
                        Text("바꾸기")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.black.opacity(0.55)))
                            .opacity(isHoveringPreview ? 1 : 0)
                    )
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                isHoveringPreview = hovering
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 12, weight: .semibold))
                if style.imagePath != nil {
                    // 이미지 모드: 색·이모지는 숨김. 이미지 컨트롤만.
                    row(label: "이미지") {
                        HStack(spacing: 6) {
                            Button("변경…") { pickImage() }
                                .controlSize(.small)
                                .accessibilityIdentifier("image-pick-\(motionKey)")
                            Button(action: removeImage) {
                                Image(systemName: "trash")
                            }
                            .controlSize(.small)
                            .accessibilityIdentifier("image-remove-\(motionKey)")
                            Text(URL(fileURLWithPath: style.imagePath ?? "").lastPathComponent)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                } else {
                    // 색·이모지 모드
                    row(label: "이모지") {
                        TextField("", text: $style.emoji).frame(width: 70)
                    }
                    row(label: "상단 색상") {
                        colorPicker(hex: $style.topColorHex)
                    }
                    row(label: "하단 색상") {
                        colorPicker(hex: $style.bottomColorHex)
                    }
                    row(label: "이미지") {
                        Button("이미지 선택…") { pickImage() }
                            .controlSize(.small)
                            .accessibilityIdentifier("image-pick-\(motionKey)")
                    }
                }
                if let d = duration {
                    row(label: d.label) {
                        HStack(spacing: 8) {
                            if !d.sliderHidden {
                                Slider(value: d.value, in: d.range, step: d.step)
                                    .frame(width: 140)
                                    .disabled(d.persistent?.wrappedValue == true)
                            }
                            if d.persistent?.wrappedValue == true {
                                Text("∞")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 60, alignment: .trailing)
                            } else {
                                HStack(spacing: 2) {
                                    TextField("", value: Binding(
                                        get: { d.value.wrappedValue },
                                        set: { newVal in
                                            let clamped = min(max(newVal, d.range.lowerBound), d.range.upperBound)
                                            d.value.wrappedValue = clamped
                                        }
                                    ), format: .number.precision(.fractionLength(0...1)))
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: d.sliderHidden ? 80 : 56)
                                        .multilineTextAlignment(.trailing)
                                    Text("s")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if let p = d.persistent {
                                Toggle("유지", isOn: p)
                                    .toggleStyle(.checkbox)
                                    .help("켜면 다음 이벤트가 올 때까지 모션 유지")
                            }
                        }
                    }
                }
                Divider().padding(.vertical, 2)
                row(label: "말풍선") {
                    Toggle("표시", isOn: $style.bubbleEnabled)
                        .toggleStyle(.checkbox)
                }
                row(label: "텍스트") {
                    TextField("예: {emoji} {tool}", text: $style.bubbleText)
                        .textFieldStyle(.roundedBorder)
                        .disabled(!style.bubbleEnabled)
                }
            }
            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.controlBackgroundColor))
        )
    }

    private func removeImage() {
        ImageStore.delete(path: style.imagePath)
        style.imagePath = nil
    }

    @ViewBuilder
    private func row<C: View>(label: String, @ViewBuilder content: () -> C) -> some View {
        HStack {
            Text(label).frame(width: 70, alignment: .leading).font(.system(size: 12))
            content()
        }
    }

    private func colorPicker(hex: Binding<String>) -> some View {
        HStack(spacing: 8) {
            ColorPicker("", selection: Binding(
                get: { Color(hex: hex.wrappedValue) },
                set: { hex.wrappedValue = $0.hexString }
            ))
            .labelsHidden()
            Text(hex.wrappedValue)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }

    private func pickImage() {
        // LSUIElement 앱은 NSOpenPanel이 포커스를 못 받아서 안 보이는 경우가 있음.
        // 명시적으로 앱 활성화 후 패널을 띄움.
        NSApp.activate(ignoringOtherApps: true)
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.level = .modalPanel
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            ImageStore.delete(path: style.imagePath)
            let savedPath = try ImageStore.copy(from: url, motionKey: motionKey)
            style.imagePath = savedPath
        } catch {
            print("[PreferencesView] image copy failed: \(error)")
        }
    }

    @ViewBuilder
    private var preview: some View {
        ZStack {
            if let path = style.imagePath,
               FileManager.default.fileExists(atPath: path) {
                AnimatedImageView(filePath: path)
                    .frame(width: 70, height: 70)
                    .clipped()
            } else {
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: style.topColorHex),
                                     Color(hex: style.bottomColorHex)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 78, height: 66)
                    .shadow(color: Color(hex: style.bottomColorHex).opacity(0.4),
                            radius: 6, x: 0, y: 3)
                Text(style.emoji).font(.system(size: 34))
            }
        }
        .frame(width: 86, height: 78)
    }
}

private struct ThemeCard: View {
    let theme: Theme
    let isActive: Bool
    let isBuiltin: Bool
    let onApply: () -> Void
    let onUpdate: (() -> Void)?
    let onDelete: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isActive ? Color.green : Color.secondary)
                .font(.system(size: 20))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(theme.name).font(.system(size: 13, weight: .semibold))
                    if isBuiltin {
                        Text("BUILT-IN")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.18))
                            .cornerRadius(4)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(theme.themeDescription)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            HStack(spacing: 6) {
                Button(isActive ? "재적용" : "적용") { onApply() }
                    .controlSize(.small)
                if let onUpdate {
                    Button("수정") { onUpdate() }
                        .controlSize(.small)
                        .help("현재 설정으로 덮어쓰기")
                }
                if let onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                    }
                    .controlSize(.small)
                    .help("이 테마 삭제")
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.controlBackgroundColor))
        )
    }
}

private struct ThemeNameSheet: View {
    let isEditing: Bool
    @Binding var name: String
    @Binding var description: String
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(isEditing ? "테마 수정" : "현재 설정을 새 테마로 저장")
                .font(.system(size: 14, weight: .bold))
            Text(isEditing
                 ? "현재 설정으로 이 테마의 색·이모지·이미지·말풍선·verb를 덮어씁니다."
                 : "현재 설정의 색·이모지·이미지·말풍선·verb를 새 사용자 테마로 저장합니다.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 6) {
                Text("이름").font(.system(size: 11)).foregroundStyle(.secondary)
                TextField("예: My Theme", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("설명 (선택)").font(.system(size: 11)).foregroundStyle(.secondary)
                TextField("짧은 설명", text: $description)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer()
                Button("취소") { onCancel() }
                    .keyboardShortcut(.cancelAction)
                Button(isEditing ? "덮어쓰기" : "저장") { onSave() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 380)
    }
}

private struct BundleIDsEditor: View {
    @Binding var ids: [String]
    @State private var text: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextEditor(text: $text)
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 110, maxHeight: 180)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .onAppear { text = ids.joined(separator: "\n") }
                .onChange(of: text) { _, newValue in
                    ids = newValue
                        .split(separator: "\n", omittingEmptySubsequences: false)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                }
            HStack {
                Spacer()
                Text("\(ids.count) bundle IDs")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct ThinkingVerbsEditor: View {
    @Binding var verbs: [String]
    @State private var text: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextEditor(text: $text)
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 140, maxHeight: 200)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                )
                .onAppear { text = verbs.joined(separator: "\n") }
                .onChange(of: text) { _, newValue in
                    verbs = newValue
                        .split(separator: "\n", omittingEmptySubsequences: false)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                }
            HStack {
                Spacer()
                Text("\(verbs.count) verbs")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
