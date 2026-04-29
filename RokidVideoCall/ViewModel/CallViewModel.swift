import Foundation
import AVFoundation

enum CallState {
    case idle, connecting, inCall, incoming(from: String), ended
}

@MainActor
final class CallViewModel: ObservableObject, SignalingDelegate {
    @Published var callState: CallState = .idle
    @Published var statusText = "Ready"
    @Published var isMuted = false
    var useFrontCamera = true
    @Published var glassesConnected = false
    @Published var glassesClientCount = 0
    @Published var signalingConnected = false

    let settingsStore: SettingsStore
    let webRTC = WebRTCCoordinator()
    private let signalingClient: SignalingClient
    private let glassesServer = GlassesServer()

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        self.signalingClient = SignalingClient(serverUrl: settingsStore.settings.signalingServerUrl)
        signalingClient.delegate = self
        setupWebRTCEvents()
        setupGlassesServer()
        glassesServer.start()
    }

    // MARK: - Setup

    private func setupWebRTCEvents() {
        webRTC.onEvent = { [weak self] event in
            Task { @MainActor [weak self] in self?.handleWebRTCEvent(event) }
        }
    }

    private func setupGlassesServer() {
        glassesServer.onClientConnected = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                glassesClientCount = glassesServer.clientCount
                glassesConnected = true
            }
        }
        glassesServer.onClientDisconnected = { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                glassesClientCount = glassesServer.clientCount
                glassesConnected = glassesClientCount > 0
            }
        }
    }

    // MARK: - Signaling

    func connectSignaling() {
        signalingClient.updateServerUrl(settingsStore.settings.signalingServerUrl)
        signalingClient.connect()
        statusText = "Connecting to server..."
    }

    func disconnectSignaling() {
        signalingClient.disconnect()
    }

    func applySettings() {
        signalingClient.updateServerUrl(settingsStore.settings.signalingServerUrl)
    }

    // MARK: - Call flow

    func startCall() {
        requestPermissions { [weak self] granted in
            guard granted else {
                self?.statusText = "Camera/mic permission denied"
                return
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                callState = .connecting
                statusText = "Starting call..."
                glassesServer.broadcastCallState("connecting")
                let s = settingsStore.settings
                webRTC.initWebRTC(stunServer: s.stunServer, turnServer: s.turnServer,
                                  turnUsername: s.turnUsername, turnPassword: s.turnPassword)
                webRTC.startLocalStream(resolution: s.videoResolution)
            }
        }
    }

    func acceptIncomingCall(offerSdp: String, offerType: String) {
        callState = .inCall
        glassesServer.broadcastCallState("inCall")
        webRTC.handleOffer(sdp: offerSdp, type: offerType)
    }

    func hangup() {
        webRTC.hangup()
        signalingClient.send(type: "call_end", data: ["reason": "user_hangup"])
        callState = .ended
        statusText = "Call ended"
        glassesServer.broadcastCallState("ended")
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.callState = .idle
            self?.statusText = "Ready"
        }
    }

    func toggleMic() {
        isMuted.toggle()
        webRTC.toggleMic(muted: isMuted)
    }

    func flipCamera() {
        useFrontCamera.toggle()
        webRTC.toggleCamera(useFront: useFrontCamera)
        signalingClient.send(type: "camera_switched", data: ["camera": useFrontCamera ? "front" : "back"])
    }

    // MARK: - WebRTC events (JS → Swift)

    private func handleWebRTCEvent(_ event: [String: Any]) {
        guard let eventType = event["event"] as? String else { return }
        switch eventType {
        case "localStreamReady":
            webRTC.createOffer()
        case "offer":
            guard let sdp = event["sdp"] as? String, let type = event["type"] as? String else { return }
            signalingClient.send(type: "call_start", data: [
                "sdp": sdp, "type": type,
                "device_id": UIDevice.current.identifierForVendor?.uuidString ?? "ios_device"
            ])
            callState = .inCall
            glassesServer.broadcastCallState("inCall")
        case "answer":
            guard let sdp = event["sdp"] as? String, let type = event["type"] as? String else { return }
            signalingClient.send(type: "call_answer", data: ["sdp": sdp, "type": type])
        case "iceCandidate":
            guard let candidate = event["candidate"] as? [String: Any] else { return }
            signalingClient.send(type: "ice_candidate", data: candidate)
        case "connectionState":
            if let state = event["state"] as? String { statusText = state }
        case "status":
            if let text = event["text"] as? String { statusText = text }
        case "hangup":
            callState = .idle
        case "error":
            statusText = event["message"] as? String ?? "WebRTC error"
        default: break
        }
    }

    // MARK: - SignalingDelegate

    nonisolated func signalingDidConnect() {
        Task { @MainActor in
            signalingConnected = true
            statusText = "Signaling connected"
        }
    }

    nonisolated func signalingDidDisconnect() {
        Task { @MainActor in
            signalingConnected = false
            statusText = "Signaling disconnected"
        }
    }

    nonisolated func signalingDidReceive(type: String, data: [String: Any]) {
        Task { @MainActor in
            switch type {
            case "call_answer":
                if let sdp = data["sdp"] as? String, let t = data["type"] as? String {
                    webRTC.handleAnswer(sdp: sdp, type: t)
                }
            case "ice_candidate":
                webRTC.addIceCandidate(data)
            case "call_start":
                if let sdp = data["sdp"] as? String, let t = data["type"] as? String {
                    callState = .incoming(from: data["operator_id"] as? String ?? "Unknown")
                    glassesServer.broadcastCallState("incoming", remote: data["operator_id"] as? String)
                }
            case "call_end":
                hangup()
            default: break
            }
        }
    }

    nonisolated func signalingDidError(_ error: String) {
        Task { @MainActor in statusText = "Signaling: \(error)" }
    }

    // MARK: - Permissions

    private func requestPermissions(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { video in
            AVCaptureDevice.requestAccess(for: .audio) { audio in
                DispatchQueue.main.async { completion(video && audio) }
            }
        }
    }
}
