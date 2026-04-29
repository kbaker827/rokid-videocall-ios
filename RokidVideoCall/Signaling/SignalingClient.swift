import Foundation

struct SignalingMessage: Codable {
    let type: String
    let data: [String: AnyCodable]
}

// Simple type-erased Codable wrapper
struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) { self.value = value }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { value = v }
        else if let v = try? container.decode(Int.self) { value = v }
        else if let v = try? container.decode(Double.self) { value = v }
        else if let v = try? container.decode(String.self) { value = v }
        else { value = "" }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as Bool:   try container.encode(v)
        case let v as Int:    try container.encode(v)
        case let v as Double: try container.encode(v)
        case let v as String: try container.encode(v)
        default: try container.encode("")
        }
    }
}

protocol SignalingDelegate: AnyObject {
    func signalingDidConnect()
    func signalingDidDisconnect()
    func signalingDidReceive(type: String, data: [String: Any])
    func signalingDidError(_ error: String)
}

final class SignalingClient {
    private var webSocketTask: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private var pingTimer: Timer?
    private var reconnectTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var serverUrl: String

    weak var delegate: SignalingDelegate?
    private(set) var isConnected = false

    init(serverUrl: String) {
        self.serverUrl = serverUrl
    }

    func updateServerUrl(_ url: String) {
        serverUrl = url
    }

    func connect() {
        guard !isConnected else { return }
        guard let url = URL(string: serverUrl) else {
            delegate?.signalingDidError("Invalid signaling server URL")
            return
        }
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        receive()
        startPing()
        delegate?.signalingDidConnect()
    }

    func disconnect() {
        stopPing()
        reconnectTimer?.invalidate()
        reconnectAttempts = 0
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
        delegate?.signalingDidDisconnect()
    }

    func send(type: String, data: [String: Any]) {
        guard isConnected else { return }
        var payload: [String: Any] = ["type": type, "data": data]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload),
              let jsonStr = String(data: jsonData, encoding: .utf8) else { return }
        webSocketTask?.send(.string(jsonStr)) { _ in }
    }

    private func receive() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let message):
                if case .string(let text) = message {
                    self.handleMessage(text)
                }
                self.receive()
            case .failure(let error):
                self.isConnected = false
                self.delegate?.signalingDidError(error.localizedDescription)
                self.scheduleReconnect()
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String,
              let msgData = json["data"] as? [String: Any] else { return }
        DispatchQueue.main.async { self.delegate?.signalingDidReceive(type: type, data: msgData) }
    }

    private func startPing() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.webSocketTask?.sendPing { _ in }
        }
    }

    private func stopPing() {
        pingTimer?.invalidate()
        pingTimer = nil
    }

    private func scheduleReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else { return }
        reconnectAttempts += 1
        reconnectTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in
            self?.connect()
        }
    }
}
