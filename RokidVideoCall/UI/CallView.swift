import SwiftUI

struct CallView: View {
    @ObservedObject var vm: CallViewModel

    var body: some View {
        ZStack {
            WebRTCView(coordinator: vm.webRTC)
                .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                bottomControls
            }

            if case .incoming(let from) = vm.callState {
                incomingCallOverlay(from: from)
            }
        }
    }

    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(vm.statusText)
                    .font(.caption)
                    .foregroundColor(.white)
                if case .inCall = vm.callState {
                    Text("In call")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            .padding(8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Spacer()

            glassesIndicator
        }
        .padding()
    }

    private var bottomControls: some View {
        HStack(spacing: 32) {
            if case .inCall = vm.callState {
                controlButton(icon: vm.isMuted ? "mic.slash.fill" : "mic.fill",
                              color: vm.isMuted ? .red : .white, action: vm.toggleMic)
                controlButton(icon: "phone.down.fill", color: .red, size: 28, action: vm.hangup)
                controlButton(icon: "arrow.triangle.2.circlepath.camera.fill",
                              color: .white, action: vm.flipCamera)
            } else if case .connecting = vm.callState {
                controlButton(icon: "phone.down.fill", color: .red, size: 28, action: vm.hangup)
            } else {
                controlButton(icon: "phone.fill", color: .green, size: 28, action: vm.startCall)
            }
        }
        .padding(.bottom, 40)
        .padding(.horizontal, 40)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.bottom, 20)
    }

    private func controlButton(icon: String, color: Color, size: CGFloat = 22, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 56, height: 56)
                .background(Color.white.opacity(0.15))
                .clipShape(Circle())
        }
    }

    private func incomingCallOverlay(from: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                Text("Incoming call")
                    .font(.headline)
                    .foregroundColor(.white)
                Text(from)
                    .font(.title2.bold())
                    .foregroundColor(.white)
            }
            HStack(spacing: 60) {
                Button {
                    vm.hangup()
                } label: {
                    Image(systemName: "phone.down.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                        .frame(width: 70, height: 70)
                        .background(Color.red)
                        .clipShape(Circle())
                }
                Button {
                    vm.startCall()
                } label: {
                    Image(systemName: "phone.fill")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                        .frame(width: 70, height: 70)
                        .background(Color.green)
                        .clipShape(Circle())
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.7))
    }

    private var glassesIndicator: some View {
        HStack(spacing: 4) {
            Circle().fill(vm.glassesConnected ? Color.green : Color.gray).frame(width: 8, height: 8)
            Text(vm.glassesConnected ? "\(vm.glassesClientCount) glasses" : "No glasses")
                .font(.caption).foregroundColor(.white)
        }
        .padding(8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}
