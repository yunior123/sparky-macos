import SwiftUI
import Combine

enum SparkyState: String, Sendable {
    case idle
    case listening
    case thinking
    case executing
    case speaking

    var color: Color {
        switch self {
        case .idle:      return AppTheme.idle
        case .listening: return AppTheme.listening
        case .thinking:  return AppTheme.thinking
        case .executing: return AppTheme.thinking
        case .speaking:  return AppTheme.speaking
        }
    }

    var label: String {
        switch self {
        case .idle:      return "Sparky"
        case .listening: return "Listening..."
        case .thinking:  return "Thinking..."
        case .executing: return "Executing..."
        case .speaking:  return "Speaking..."
        }
    }
}

@MainActor
final class SparkyViewModel: ObservableObject {
    @Published var state: SparkyState = .idle
    @Published var transcript: String = ""
    @Published var response: String = ""
    @Published var launchAtLogin: Bool = false

    private let voiceEngine = VoiceEngine()
    private let ttsEngine = TTSEngine()

    func start() {
        Task {
            await voiceEngine.setDelegate(self)
            do {
                try await voiceEngine.start()
            } catch {
                response = "Mic error: \(error.localizedDescription)"
            }
        }
    }

    func stop() {
        Task { await voiceEngine.stop() }
    }

    func toggleLaunchAtLogin() {
        launchAtLogin.toggle()
        LaunchAtLoginManager.setEnabled(launchAtLogin)
    }
}

// MARK: - VoiceEngineDelegate
extension SparkyViewModel: VoiceEngineDelegate {
    nonisolated func voiceEngine(_ engine: VoiceEngine, didChangeState newState: SparkyState) {
        Task { @MainActor in
            self.state = newState
            StateFile.write(newState.rawValue)
        }
    }

    nonisolated func voiceEngine(_ engine: VoiceEngine, didTranscribe text: String) {
        Task { @MainActor in
            self.transcript = text
        }
    }

    nonisolated func voiceEngine(_ engine: VoiceEngine, didRecognizeCommand command: String) {
        Task { @MainActor in
            self.state = .executing
            self.transcript = command
            StateFile.write("executing")
            // Inject into active Claude Code terminal — Claude handles the intelligence
            await CommandRouter.route(command)
            self.state = .idle
            StateFile.write("idle")
        }
    }
}

// MARK: - State IPC file
enum StateFile {
    static let path = "/tmp/sparky_state"
    static func write(_ s: String) {
        try? s.write(toFile: path, atomically: true, encoding: .utf8)
    }
}
