import Foundation

// MARK: - CommandRouter
// Sparky is just a voice-to-terminal bridge.
// "Hey Sparky" is the ONLY hardcoded thing — everything else is injected
// directly into the active Claude Code terminal session.

enum CommandRouter {
    /// Injects the command into the active Terminal and returns nil (no TTS needed).
    /// Claude Code handles all intelligence.
    @MainActor
    static func route(_ command: String) async -> String? {
        injectToTerminal(command)
        return nil
    }

    // MARK: - Terminal injection

    static func injectToTerminal(_ text: String) {
        let safe = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Terminal"
            activate
        end tell
        tell application "System Events"
            tell process "Terminal"
                keystroke "\(safe)"
                key code 36
            end tell
        end tell
        """
        runAppleScript(script)
    }

    @discardableResult
    static func runAppleScript(_ script: String) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }
}
