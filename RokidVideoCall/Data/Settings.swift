import Foundation

struct CallSettings: Codable {
    var signalingServerUrl: String = "ws://192.168.1.100:3000/ws"
    var stunServer: String = "stun:stun.l.google.com:19302"
    var turnServer: String = ""
    var turnUsername: String = ""
    var turnPassword: String = ""
    var videoResolution: String = "720p"
    var videoFps: Int = 30
    var videoBitrateKbps: Int = 2000
}

final class SettingsStore: ObservableObject {
    @Published var settings: CallSettings {
        didSet { save() }
    }

    init() {
        if let data = UserDefaults.standard.data(forKey: "call_settings"),
           let decoded = try? JSONDecoder().decode(CallSettings.self, from: data) {
            settings = decoded
        } else {
            settings = CallSettings()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: "call_settings")
        }
    }
}
