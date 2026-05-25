// PetState.swift
import SwiftUI
import Combine

enum Motion: String {
    case idle, waiting, done, tool, typing, thinking, permission
}

struct Session: Identifiable {
    let id: String
    var state: String       // "waiting" | "idle"
    var label: String?
    var updatedAt: Date
}

@MainActor
final class PetState: ObservableObject {
    @Published private(set) var sessions: [String: Session] = [:]
    @Published private(set) var motion: Motion = .idle
    @Published private(set) var currentToolName: String?
    @Published private(set) var isThinking: Bool = false
    @Published private(set) var thinkingVerbIndex: Int = 0
    /// PetView가 SwiftUI PreferenceKey로 보고하는 현재 말풍선 자연 크기(꼬리 포함).
    /// AppDelegate가 이 값으로 NSPanel 폭/높이를 동적으로 확장한다.
    @Published var measuredBubbleSize: CGSize = .zero

    // 모션 활성 플래그 (timer.isValid 대체)
    @Published private(set) var isDoneActive: Bool = false
    @Published private(set) var isToolActive: Bool = false
    @Published private(set) var isTypingActive: Bool = false
    @Published private(set) var isPermissionActive: Bool = false

    private var doneTimer: Timer?
    private var toolTimer: Timer?
    private var typingTimer: Timer?
    private var thinkingVerbTimer: Timer?
    /// 세션별 waiting 진입 지연 타이머. 발화 전에 다른 이벤트 오면 취소.
    private var pendingWaitingTimers: [String: Timer] = [:]
    /// 세션별 마지막 cancel 시각. 이 시각 + recentCancelWindow 이내에 done이 오면
    /// 축하 모션을 스킵 (권한 거부 등 사용자 의도로 중단된 흐름의 마무리 Stop을 무시).
    private var lastCancelAt: [String: Date] = [:]
    private let recentCancelWindow: TimeInterval = 2.0

    // AppDelegate가 PetTheme의 값을 여기로 동기화함
    var doneDuration: TimeInterval = 4.0
    var toolDuration: TimeInterval = 2.0
    var typingDuration: TimeInterval = 1.5
    var thinkingVerbInterval: TimeInterval = 1.5
    var waitingDelay: TimeInterval = 0
    var waitingEnabled: Bool = true
    /// true면 타이머 무시. 다음 apply() 호출(=다음 HTTP 이벤트)이 올 때까지 유지
    var donePersistent: Bool = false
    var toolPersistent: Bool = false
    var typingPersistent: Bool = false
    var typingOverridesWaiting: Bool = false

    var waitingLabels: [String] {
        sessions.values
            .filter { $0.state == "waiting" }
            .map { $0.label ?? String($0.id.prefix(8)) }
            .sorted()
    }

    func apply(event: String, sessionId: String, label: String?) {
        let id = sessionId.isEmpty ? "unknown" : sessionId

        // waiting 비활성화 시 waiting 이벤트는 완전 무시 (다른 상태도 안 건드림)
        if event == "waiting" && !waitingEnabled { return }

        // 권한 관련 이벤트는 다른 상태를 건드리지 않는 오버레이.
        // 응답(승인/거부) 후 직전 모션으로 자연 복귀하기 위함.
        if event == "permission" {
            isPermissionActive = true
            recomputeMotion()
            return
        }
        if event == "permission_resolved" {
            isPermissionActive = false
            recomputeMotion()
            return
        }

        // 그 외 이벤트는 transient(persistent 포함) 정리 후 처리.
        // permission도 같이 클리어 — 다른 이벤트가 일어났다 = Claude가 진행 중
        clearAllTransientFlags()

        switch event {
        case "waiting":
            scheduleWaitingEntry(id: id, label: label)
        case "done":
            cancelPendingWaiting(id: id)
            sessions[id] = Session(id: id, state: "idle", label: label, updatedAt: Date())
            clearThinking()
            // 직전에 같은 세션에서 cancel(권한 거부 등) 발생 시 축하 스킵
            if !wasRecentlyCancelled(id: id) {
                triggerDone()
            }
        case "clear":
            cancelPendingWaiting(id: id)
            sessions.removeValue(forKey: id)
            clearThinking()
        case "cancel":
            // 권한 거부/중단 등 명시적 취소 신호. clear와 같은 정리를 하면서
            // lastCancelAt 기록 → 직후 들어올 done 축하를 억제.
            cancelPendingWaiting(id: id)
            sessions.removeValue(forKey: id)
            clearThinking()
            lastCancelAt[id] = Date()
            pruneOldCancelTimestamps()
        case "tool":
            triggerTool(toolName: label)
        case "thinking":
            cancelPendingWaiting(id: id)
            sessions.removeValue(forKey: id)
            triggerThinking()
        default:
            break
        }
        recomputeMotion()
    }

    private func clearAllTransientFlags() {
        isDoneActive = false
        doneTimer?.invalidate(); doneTimer = nil
        isToolActive = false
        currentToolName = nil
        toolTimer?.invalidate(); toolTimer = nil
        isTypingActive = false
        typingTimer?.invalidate(); typingTimer = nil
        isPermissionActive = false
    }

    /// waiting 진입을 즉시 또는 지연 후 적용. waitingDelay가 0이면 즉시 sessions에 등록.
    private func scheduleWaitingEntry(id: String, label: String?) {
        cancelPendingWaiting(id: id)
        let entry = Session(id: id, state: "waiting", label: label, updatedAt: Date())
        guard waitingDelay > 0 else {
            sessions[id] = entry
            return
        }
        pendingWaitingTimers[id] = Timer.scheduledTimer(withTimeInterval: waitingDelay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.pendingWaitingTimers.removeValue(forKey: id)
                self.sessions[id] = entry
                self.recomputeMotion()
            }
        }
    }

    private func cancelPendingWaiting(id: String) {
        pendingWaitingTimers[id]?.invalidate()
        pendingWaitingTimers.removeValue(forKey: id)
    }

    private func wasRecentlyCancelled(id: String) -> Bool {
        guard let t = lastCancelAt[id] else { return false }
        return Date().timeIntervalSince(t) < recentCancelWindow
    }

    /// lastCancelAt 사전이 무한히 자라지 않도록 window의 4배 이상 지난 entry 제거
    private func pruneOldCancelTimestamps() {
        let cutoff = Date().addingTimeInterval(-recentCancelWindow * 4)
        lastCancelAt = lastCancelAt.filter { $0.value > cutoff }
    }

    private func triggerDone() {
        isDoneActive = true
        doneTimer?.invalidate(); doneTimer = nil
        guard !donePersistent else { return }
        doneTimer = Timer.scheduledTimer(withTimeInterval: doneDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.isDoneActive = false
                self?.recomputeMotion()
            }
        }
    }

    private func triggerTool(toolName: String?) {
        isToolActive = true
        currentToolName = toolName
        toolTimer?.invalidate(); toolTimer = nil
        guard !toolPersistent else { return }
        toolTimer = Timer.scheduledTimer(withTimeInterval: toolDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.isToolActive = false
                self?.currentToolName = nil
                self?.recomputeMotion()
            }
        }
    }

    /// 사용자가 터미널에서 키 입력 시 호출 (KeystrokeMonitor 등 외부에서)
    func triggerTyping() {
        isTypingActive = true
        typingTimer?.invalidate(); typingTimer = nil

        // typingOverridesWaiting=true면 typing이 들어오는 순간 waiting을 해소
        // (= 사용자가 응답한 것으로 간주). typing 종료 후 waiting으로 돌아가지 않고 idle.
        if typingOverridesWaiting {
            for (id, session) in sessions where session.state == "waiting" {
                sessions[id] = Session(id: id, state: "idle", label: session.label, updatedAt: Date())
                cancelPendingWaiting(id: id)
            }
        }

        if !typingPersistent {
            typingTimer = Timer.scheduledTimer(withTimeInterval: typingDuration, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.isTypingActive = false
                    self?.recomputeMotion()
                }
            }
        }
        recomputeMotion()
    }

    private func triggerThinking() {
        guard !isThinking else { return }
        isThinking = true
        thinkingVerbIndex = 0
        thinkingVerbTimer?.invalidate()
        thinkingVerbTimer = Timer.scheduledTimer(withTimeInterval: thinkingVerbInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.thinkingVerbIndex &+= 1 }
        }
    }

    private func clearThinking() {
        isThinking = false
        thinkingVerbTimer?.invalidate()
        thinkingVerbTimer = nil
    }

    private func recomputeMotion() {
        // 우선순위: permission > done > tool > waiting > thinking > typing > idle
        // typingOverridesWaiting=true일 때는 triggerTyping()에서 waiting을 미리
        // 해소시키므로, 여기 로직은 단순한 우선순위만 유지.
        if isPermissionActive { motion = .permission; return }
        if isDoneActive { motion = .done; return }
        if isToolActive { motion = .tool; return }
        if sessions.values.contains(where: { $0.state == "waiting" }) {
            motion = .waiting
            return
        }
        if isThinking { motion = .thinking; return }
        if isTypingActive { motion = .typing; return }
        motion = .idle
    }
}
