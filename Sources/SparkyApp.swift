import AppKit
import AVFoundation
import SwiftUI

// MARK: - Entry point

@main
struct SparkyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(vm: delegate.vm)
        } label: {
            Image(systemName: stateIcon(delegate.vm.state))
                .symbolRenderingMode(.palette)
                .foregroundStyle(delegate.vm.state.color, .white)
        }
        .menuBarExtraStyle(.menu)
    }

    private func stateIcon(_ s: SparkyState) -> String {
        switch s {
        case .idle:      return "waveform.circle"
        case .listening: return "mic.fill"
        case .thinking:  return "brain"
        case .executing: return "bolt.fill"
        case .speaking:  return "speaker.wave.2.fill"
        }
    }
}

// MARK: - AppDelegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var vm = SparkyViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Belt + suspenders: hide dock icon
        NSApp.setActivationPolicy(.accessory)

        OverlayWindowController.shared.configure(vm: vm)
        OverlayWindowController.shared.show()

        // Request mic + speech permissions then start engine
        Task {
            let speechGranted = await StreamingSpeechRecognizer.requestAuthorization()
            let micGranted    = await requestMicPermission()
            if speechGranted && micGranted {
                vm.start()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        vm.stop()
    }

    // MARK: - Private

    private func requestMicPermission() async -> Bool {
        await withCheckedContinuation { cont in
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                cont.resume(returning: true)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .audio) { granted in
                    cont.resume(returning: granted)
                }
            default:
                cont.resume(returning: false)
            }
        }
    }
}

// MARK: - MenuBar menu content

struct MenuBarContentView: View {
    @ObservedObject var vm: SparkyViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Sparky \(vm.state.label)")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            Button("Show Overlay") {
                OverlayWindowController.shared.show()
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Toggle("Launch at Login", isOn: Binding(
                get: { vm.launchAtLogin },
                set: { _ in vm.toggleLaunchAtLogin() }
            ))

            Divider()

            Button("Quit Sparky") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .frame(minWidth: 180)
    }
}
