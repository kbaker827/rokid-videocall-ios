import SwiftUI
import WebKit

struct WebRTCView: UIViewRepresentable {
    let coordinator: WebRTCCoordinator

    func makeUIView(context: Context) -> WKWebView {
        coordinator.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

final class WebRTCCoordinator: NSObject, WKScriptMessageHandler {
    let webView: WKWebView
    var onEvent: (([String: Any]) -> Void)?

    override init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let contentController = WKUserContentController()
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        webView = WKWebView(frame: .zero, configuration: config)
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false

        super.init()
        contentController.add(self, name: "webrtc")
        config.userContentController = contentController

        loadHTML()
    }

    private func loadHTML() {
        guard let url = Bundle.main.url(forResource: "webrtc", withExtension: "html") else { return }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    // MARK: - JS → Swift

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any] else { return }
        DispatchQueue.main.async { self.onEvent?(body) }
    }

    // MARK: - Swift → JS

    func initWebRTC(stunServer: String, turnServer: String, turnUsername: String, turnPassword: String) {
        let config: [String: Any] = [
            "stunServer": stunServer,
            "turnServer": turnServer,
            "turnUsername": turnUsername,
            "turnPassword": turnPassword
        ]
        guard let json = try? JSONSerialization.data(withJSONObject: config),
              let str = String(data: json, encoding: .utf8) else { return }
        callJS("initWebRTC(\(str))")
    }

    func startLocalStream(resolution: String) {
        callJS("startLocalStream('\(resolution)')")
    }

    func createOffer() { callJS("createOffer()") }

    func handleOffer(sdp: String, type: String) {
        let escaped = sdp.replacingOccurrences(of: "\\", with: "\\\\")
                         .replacingOccurrences(of: "`", with: "\\`")
        callJS("handleOffer(`\(escaped)`, '\(type)')")
    }

    func handleAnswer(sdp: String, type: String) {
        let escaped = sdp.replacingOccurrences(of: "\\", with: "\\\\")
                         .replacingOccurrences(of: "`", with: "\\`")
        callJS("handleAnswer(`\(escaped)`, '\(type)')")
    }

    func addIceCandidate(_ candidate: [String: Any]) {
        guard let json = try? JSONSerialization.data(withJSONObject: candidate),
              let str = String(data: json, encoding: .utf8) else { return }
        callJS("addIceCandidate(\(str))")
    }

    func toggleCamera(useFront: Bool) { callJS("toggleCamera(\(useFront))") }
    func toggleMic(muted: Bool) { callJS("toggleMic(\(muted))") }
    func hangup() { callJS("hangup()") }

    private func callJS(_ js: String) {
        webView.evaluateJavaScript(js, completionHandler: nil)
    }
}
