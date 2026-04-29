import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    var onApply: () -> Void = {}
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Signaling Server") {
                    TextField("WebSocket URL", text: $store.settings.signalingServerUrl)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                    Text("e.g. ws://192.168.1.100:3000/ws")
                        .font(.caption).foregroundColor(.secondary)
                }
                Section("STUN / TURN") {
                    TextField("STUN server", text: $store.settings.stunServer)
                        .autocapitalization(.none)
                    TextField("TURN server (optional)", text: $store.settings.turnServer)
                        .autocapitalization(.none)
                    TextField("TURN username", text: $store.settings.turnUsername)
                        .autocapitalization(.none)
                    SecureField("TURN password", text: $store.settings.turnPassword)
                }
                Section("Video") {
                    Picker("Resolution", selection: $store.settings.videoResolution) {
                        Text("720p").tag("720p")
                        Text("1080p").tag("1080p")
                    }
                    Stepper("FPS: \(store.settings.videoFps)", value: $store.settings.videoFps, in: 15...60, step: 5)
                    Stepper("Bitrate: \(store.settings.videoBitrateKbps) kbps",
                            value: $store.settings.videoBitrateKbps, in: 500...8000, step: 500)
                }
                Section("Glasses (TCP :8087)") {
                    Text("Connect Rokid glasses to port 8087 to receive call state events.")
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onApply(); dismiss() }
                }
            }
        }
    }
}
