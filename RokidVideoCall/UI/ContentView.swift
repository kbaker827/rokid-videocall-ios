import SwiftUI

struct ContentView: View {
    @StateObject private var settingsStore = SettingsStore()
    @StateObject private var vm: CallViewModel
    @State private var showSettings = false

    init() {
        let ss = SettingsStore()
        _settingsStore = StateObject(wrappedValue: ss)
        _vm = StateObject(wrappedValue: CallViewModel(settingsStore: ss))
    }

    var body: some View {
        ZStack {
            CallView(vm: vm)

            VStack {
                HStack {
                    Spacer()
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.white)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .padding(.top, 56)
                    .padding(.trailing)
                }
                Spacer()
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showSettings) {
            SettingsView(store: settingsStore, onApply: vm.applySettings)
        }
        .onAppear { vm.connectSignaling() }
        .onDisappear { vm.disconnectSignaling() }
    }
}
