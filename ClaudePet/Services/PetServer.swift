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

    /// 요청 본문 최대 크기 (악의적 Content-Length로 인한 메모리 폭주 방어)
    private static let maxBodyBytes = 64 * 1024
    /// 헤더 최대 크기 (\r\n\r\n 안 보내고 계속 부분 데이터만 보내는 공격 방어)
    private static let maxHeaderBytes = 8 * 1024

    init(port: UInt16, state: PetState, logStore: LogStore? = nil) throws {
        guard let p = NWEndpoint.Port(rawValue: port) else {
            throw NSError(domain: "ClaudePet", code: 1)
        }
        self.port = p
        self.state = state
        self.logStore = logStore

        let params = NWParameters.tcp
        // localhost only — 동일 머신 외부에서의 접근 차단
        params.acceptLocalOnly = true
        params.allowLocalEndpointReuse = true
        self.listener = try NWListener(using: params, on: p)
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

            // 전체 buffer 크기 상한 — 헤더+바디 합쳐 maxHeaderBytes + maxBodyBytes 초과면 reject
            if buffer.count > Self.maxHeaderBytes + Self.maxBodyBytes {
                self.send(connection: connection, status: 413, body: "payload too large")
                return
            }

            // 헤더가 다 도착했는지 확인
            if let headerEnd = buffer.range(of: Data("\r\n\r\n".utf8)) {
                // 헤더 자체 크기 제한
                if headerEnd.lowerBound > Self.maxHeaderBytes {
                    self.send(connection: connection, status: 431, body: "request header fields too large")
                    return
                }
                let headerData = buffer.subdata(in: 0..<headerEnd.lowerBound)
                let bodyStart = headerEnd.upperBound
                let header = String(data: headerData, encoding: .utf8) ?? ""

                // Content-Length 검증 (음수/과대값 거부)
                let parsedLen = self.contentLength(from: header)
                guard let contentLength = parsedLen else {
                    self.send(connection: connection, status: 400, body: "invalid content-length")
                    return
                }
                let received = buffer.count - bodyStart
                if received >= contentLength {
                    // 산술 overflow 방어
                    let (sum, overflow) = bodyStart.addingReportingOverflow(contentLength)
                    guard !overflow, sum <= buffer.count else {
                        self.send(connection: connection, status: 400, body: "bad length")
                        return
                    }
                    let body = buffer.subdata(in: bodyStart..<sum)
                    self.respond(to: header, body: body, on: connection)
                    return
                }
            } else {
                // 헤더 완성 전인데 이미 maxHeaderBytes 초과면 reject
                if buffer.count > Self.maxHeaderBytes {
                    self.send(connection: connection, status: 431, body: "request header fields too large")
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

    /// 헤더에서 Content-Length를 파싱. 음수/상한 초과/비숫자 → nil (호출자가 400 응답).
    /// 헤더 없으면 0 반환 (body 없는 정상 요청).
    private func contentLength(from header: String) -> Int? {
        for line in header.components(separatedBy: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 && parts[0].lowercased() == "content-length" {
                guard let n = Int(parts[1]), n >= 0, n <= Self.maxBodyBytes else { return nil }
                return n
            }
        }
        return 0
    }

    /// Origin 헤더로 CSRF 방어. localhost 외 origin → reject.
    private func isOriginAllowed(_ header: String) -> Bool {
        for line in header.components(separatedBy: "\r\n") {
            let parts = line.split(separator: ":", maxSplits: 1)
                .map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 && parts[0].lowercased() == "origin" {
                // curl/jq 같은 클라이언트는 Origin 헤더를 안 붙임 → ok
                // 브라우저가 fetch/form submit으로 보내면 Origin이 자동으로 붙음 → 검증 필요
                let origin = parts[1].lowercased()
                let allowed = ["http://127.0.0.1", "http://localhost", "null"]
                return allowed.contains(where: { origin.hasPrefix($0) })
            }
        }
        // Origin 헤더 없음 → 비브라우저 요청 (curl 등). 허용.
        return true
    }

    private func respond(to header: String, body: Data, on connection: NWConnection) {
        // CSRF 방어: 브라우저 cross-origin POST를 reject
        guard isOriginAllowed(header) else {
            send(connection: connection, status: 403, body: "forbidden origin")
            return
        }

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
                let json = self.encodeStatusJSON(motion: motion, waiting: labels)
                self.send(connection: connection, status: 200, body: json, contentType: "application/json")
            }
            return
        }

        send(connection: connection, status: 404, body: "not found")
    }

    /// /status 응답 JSON. Foundation의 JSONSerialization 사용으로 control char escape 등 자동 처리.
    private func encodeStatusJSON(motion: String, waiting: [String]) -> String {
        let obj: [String: Any] = ["motion": motion, "waiting": waiting]
        guard let data = try? JSONSerialization.data(withJSONObject: obj, options: []),
              let str = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return str
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
            case 403: return "Forbidden"
            case 404: return "Not Found"
            case 413: return "Payload Too Large"
            case 431: return "Request Header Fields Too Large"
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
