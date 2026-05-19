// PetServer.swift
//
// 로컬호스트 전용 초경량 HTTP 서버.
// POST /event  (form-encoded: type, session, label) → 상태 갱신
// GET  /status → 현재 상태 JSON
import Foundation
import Network

final class PetServer {
    private let port: NWEndpoint.Port
    private let listener: NWListener
    private weak var state: PetState?
    private weak var logStore: LogStore?
    private let queue = DispatchQueue(label: "ClaudePet.server")

    init(port: UInt16, state: PetState, logStore: LogStore? = nil) throws {
        guard let p = NWEndpoint.Port(rawValue: port) else {
            throw NSError(domain: "ClaudePet", code: 1)
        }
        self.port = p
        self.state = state
        self.logStore = logStore

        let params = NWParameters.tcp
        // localhost로 제한. 포트는 endpoint 안에 있으므로 NWListener init에는 port 안 넘김
        params.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: p)
        self.listener = try NWListener(using: params)
    }

    func start() throws {
        listener.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("[PetServer] ready on 127.0.0.1:\(9876)")
            case .failed(let error):
                print("[PetServer] failed: \(error)")
            case .waiting(let error):
                print("[PetServer] waiting: \(error)")
            case .cancelled:
                print("[PetServer] cancelled")
            default:
                print("[PetServer] state: \(state)")
            }
        }
        listener.newConnectionHandler = { [weak self] conn in
            self?.handle(connection: conn)
        }
        listener.start(queue: queue)
    }

    func stop() {
        listener.cancel()
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        receive(connection: connection, accumulated: Data())
    }

    private func receive(connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16 * 1024) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            var buffer = accumulated
            if let data { buffer.append(data) }

            // 헤더가 다 도착했는지 확인
            if let headerEnd = buffer.range(of: Data("\r\n\r\n".utf8)) {
                let headerData = buffer.subdata(in: 0..<headerEnd.lowerBound)
                let bodyStart = headerEnd.upperBound
                let header = String(data: headerData, encoding: .utf8) ?? ""

                let contentLength = self.contentLength(from: header)
                let received = buffer.count - bodyStart
                if received >= contentLength {
                    let body = buffer.subdata(in: bodyStart..<(bodyStart + contentLength))
                    self.respond(to: header, body: body, on: connection)
                    return
                }
            }

            if isComplete || error != nil {
                connection.cancel()
                return
            }
            self.receive(connection: connection, accumulated: buffer)
        }
    }

    private func contentLength(from header: String) -> Int {
        for line in header.components(separatedBy: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 && parts[0].lowercased() == "content-length" {
                return Int(parts[1]) ?? 0
            }
        }
        return 0
    }

    private func respond(to header: String, body: Data, on connection: NWConnection) {
        let requestLine = header.components(separatedBy: "\r\n").first ?? ""
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else {
            send(connection: connection, status: 400, body: "bad request")
            return
        }
        let method = String(parts[0])
        let path = String(parts[1])

        if method == "POST", path.hasPrefix("/event") {
            let form = parseForm(body: body)
            let type = form["type"] ?? ""
            let session = form["session"] ?? ""
            let label = form["label"]
            logEvent(method: method, path: path, body: body, form: form)
            Task { @MainActor in
                self.state?.apply(event: type, sessionId: session, label: label)
            }
            send(connection: connection, status: 200, body: "ok")
            return
        }

        if method == "GET", path == "/status" {
            // 응답은 메인 액터에서 상태 읽고 보내기
            Task { @MainActor in
                let labels = self.state?.waitingLabels ?? []
                let motion = self.state?.motion.rawValue ?? "idle"
                let json = #"{"motion":"\#(motion)","waiting":\#(jsonStringArray(labels))}"#
                self.send(connection: connection, status: 200, body: json, contentType: "application/json")
            }
            return
        }

        send(connection: connection, status: 404, body: "not found")
    }

    private func logEvent(method: String, path: String, body: Data, form: [String: String]) {
        // Xcode 콘솔 박스 로그는 노이즈가 많아 기본 비활성. 디버깅 시 주석 해제.
        // let ts = Self.timestampFormatter.string(from: Date())
        // let bodyStr = String(data: body, encoding: .utf8) ?? "<binary \(body.count) bytes>"
        // let formStr = form.isEmpty
        //     ? "(empty)"
        //     : form.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: ", ")
        // print("""
        // ┌─ [\(ts)] \(method) \(path)
        // │  raw  : \(bodyStr)
        // │  form : \(formStr)
        // └─
        // """)
        // Preferences "개발자" 페이지에서 보기 위해 LogStore에는 계속 push (enabled일 때만 수집)
        let m = method, p = path, f = form
        Task { @MainActor in
            self.logStore?.append(method: m, path: p, form: f)
        }
    }

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()

    private func send(connection: NWConnection, status: Int, body: String, contentType: String = "text/plain; charset=utf-8") {
        let bodyData = body.data(using: .utf8) ?? Data()
        let statusText: String = {
            switch status {
            case 200: return "OK"
            case 400: return "Bad Request"
            case 404: return "Not Found"
            default: return "Error"
            }
        }()
        let header = """
        HTTP/1.1 \(status) \(statusText)\r
        Content-Type: \(contentType)\r
        Content-Length: \(bodyData.count)\r
        Connection: close\r
        \r

        """
        var response = header.data(using: .utf8) ?? Data()
        response.append(bodyData)
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
}

// MARK: - 유틸

private func parseForm(body: Data) -> [String: String] {
    guard let s = String(data: body, encoding: .utf8) else { return [:] }
    var result: [String: String] = [:]
    for pair in s.split(separator: "&") {
        let parts = pair.split(separator: "=", maxSplits: 1)
        guard parts.count == 2 else { continue }
        let key = urlDecode(String(parts[0]))
        let value = urlDecode(String(parts[1]))
        result[key] = value
    }
    return result
}

private func urlDecode(_ s: String) -> String {
    s.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? s
}

private func jsonStringArray(_ array: [String]) -> String {
    let escaped = array.map { item -> String in
        let escapedItem = item
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escapedItem)\""
    }
    return "[\(escaped.joined(separator: ","))]"
}

