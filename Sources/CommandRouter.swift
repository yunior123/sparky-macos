import Foundation

// MARK: - CommandRouter

enum CommandRouter {
    /// Returns a spoken response string (for TTS), or nil if the command was a terminal injection.
    @MainActor
    static func route(_ command: String) async -> String? {
        let cmd = command.lowercased().trimmingCharacters(in: .whitespaces)

        // open <project> → opens Terminal with claude in that dir
        if cmd.hasPrefix("open ") {
            let project = String(command.dropFirst(5))
                .trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: " ", with: "_")
            openProject(project)
            return "Opening \(project)"
        }

        // run <command> → inject into Terminal
        if cmd.hasPrefix("run ") {
            let shell = String(command.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            injectToTerminal(shell)
            return nil
        }

        // weather
        if cmd.contains("weather") {
            return await fetchWeather()
        }

        // git status
        if cmd.contains("status") {
            injectToTerminal("git status")
            return nil
        }

        // flutter analyze
        if cmd.contains("analyze") {
            injectToTerminal("flutter analyze --no-fatal-infos")
            return nil
        }

        // deploy
        if cmd.contains("deploy") {
            injectToTerminal("./scripts/deploy_web.sh")
            return nil
        }

        // fallback → inject as Claude Code prompt
        injectToTerminal(command)
        return nil
    }

    // MARK: - Terminal helpers

    private static func openProject(_ name: String) {
        let script = """
        tell application "Terminal" to do script "cd ~/Documents/GitHub/\(name) && claude"
        """
        runAppleScript(script)
    }

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
    private static func runAppleScript(_ script: String) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    // MARK: - Weather

    private static func fetchWeather() async -> String {
        guard let url = URL(string: "https://wttr.in/Toronto?format=3") else {
            return "Weather unavailable."
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return text.isEmpty ? "Weather unavailable." : text
        } catch {
            return "Weather unavailable: \(error.localizedDescription)"
        }
    }
}
