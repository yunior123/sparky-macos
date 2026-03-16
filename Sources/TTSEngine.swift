import AVFoundation
import Foundation

// MARK: - TTSEngine

final class TTSEngine: NSObject, @unchecked Sendable {
    private let elevenLabsKey  = "sk_1f8e425ea8f5514cdc70461372bdcaf5553278665e224dc2"
    private let danielVoiceID  = "onwK4e9ZLuTAKqWW03F9"
    private var player: AVAudioPlayer?
    private let synth = AVSpeechSynthesizer()
    private let tmpPath = "/tmp/sparky_tts.mp3"

    func speak(_ text: String) async {
        if await speakElevenLabs(text) { return }
        speakFallback(text)
    }

    // MARK: - Private

    private func speakElevenLabs(_ text: String) async -> Bool {
        guard let url = URL(string: "https://api.elevenlabs.io/v1/text-to-speech/\(danielVoiceID)") else { return false }

        let body: [String: Any] = [
            "text": text,
            "model_id": "eleven_turbo_v2_5",
            "voice_settings": ["stability": 0.5, "similarity_boost": 0.8]
        ]
        guard let payload = try? JSONSerialization.data(withJSONObject: body) else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(elevenLabsKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = payload
        request.timeoutInterval = 10

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200 else { return false }

        try? data.write(to: URL(fileURLWithPath: tmpPath))
        return await playFile(at: tmpPath)
    }

    @discardableResult
    private func playFile(at path: String) async -> Bool {
        guard let p = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: path)) else { return false }
        player = p
        p.play()
        // Wait for completion
        while p.isPlaying {
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return true
    }

    private func speakFallback(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = 0.5
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        synth.speak(utterance)
    }
}
