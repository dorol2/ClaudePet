// LogStore.swift
//
// PetServer에 들어오는 요청을 메모리에 한 줄씩 기록.
// enabled=true일 때만 수집. 최대 300개 (오래된 항목부터 폐기).
import Foundation

@MainActor
final class LogStore: ObservableObject {
    struct Entry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let method: String
        let path: String
        let form: [String: String]

        var line: String {
            let ts = LogStore.timeFormatter.string(from: timestamp)
            let formStr = form.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " ")
            return "\(ts) \(method) \(path)  \(formStr)"
        }
    }

    @Published var enabled: Bool = false
    @Published private(set) var entries: [Entry] = []

    private let maxEntries = 300
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    func append(method: String, path: String, form: [String: String]) {
        guard enabled else { return }
        entries.append(Entry(timestamp: Date(), method: method, path: path, form: form))
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }
    }

    func clear() {
        entries.removeAll()
    }
}
