import AVFoundation
import Foundation

// MARK: - Delegate protocol

protocol VoiceEngineDelegate: AnyObject, Sendable {
    func voiceEngine(_ engine: VoiceEngine, didChangeState newState: SparkyState)
    func voiceEngine(_ engine: VoiceEngine, didTranscribe text: String)
    func voiceEngine(_ engine: VoiceEngine, didRecognizeCommand command: String)
}

// MARK: - Constants

private let kVADThreshold: Float = 0.015  // RMS energy threshold (matches voice_daemon.py)
private let kSilenceChunks: Int  = 12     // ~1.2s at ~100ms chunks
private let kMinSpeechChunks: Int = 5     // ~500ms minimum utterance
private let kMaxSpeechChunks: Int = 300   // 30s safety cap
private let kWakeWords = ["hey sparky", "sparky", "hey sparki", "hey sparkey"]

// MARK: - VoiceEngine actor

actor VoiceEngine {
    private weak var delegate: (any VoiceEngineDelegate)?
    private let recognizer = StreamingSpeechRecognizer(locale: Locale(identifier: "en-US"))

    private var latestTranscript: String = ""
    private var listeningForUtterance = false
    private var silenceCount = 0
    private var speechChunkCount = 0

    private var audioEngine: AVAudioEngine?
    private var rmsStream: AsyncStream<Float>?
    private var rmsContinuation: AsyncStream<Float>.Continuation?

    func setDelegate(_ d: any VoiceEngineDelegate) {
        delegate = d
    }

    func start() throws {
        let engine = AVAudioEngine()
        audioEngine = engine
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        let (stream, cont) = AsyncStream.makeStream(of: Float.self)
        rmsStream = stream
        rmsContinuation = cont

        // Capture cont as value (it's a struct wrapping a reference — safe to copy)
        let capturedCont = cont
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let count = Int(buffer.frameLength)
            var sumSq: Float = 0
            for i in 0..<count { sumSq += channelData[i] * channelData[i] }
            let rms = sqrt(sumSq / Float(count))
            capturedCont.yield(rms)
        }

        try engine.start()

        recognizer.onResult = { [weak self] (text: String) in
            guard let self else { return }
            Task { await self.handlePartialTranscript(text) }
        }
        recognizer.onFinalResult = { [weak self] (text: String) in
            guard let self else { return }
            Task { await self.handleFinalTranscript(text) }
        }
        recognizer.onError = { (_: Error) in }

        Task { await processRMSStream(stream) }
    }

    func stop() {
        rmsContinuation?.finish()
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        recognizer.stopRecognition()
    }

    // MARK: - Private

    private func processRMSStream(_ stream: AsyncStream<Float>) async {
        for await rms in stream {
            await tick(rms: rms)
        }
    }

    private func tick(rms: Float) async {
        let isSpeech = rms > kVADThreshold

        if isSpeech {
            silenceCount = 0
            if !listeningForUtterance {
                listeningForUtterance = true
                speechChunkCount = 0
                setState(.listening)
                try? recognizer.startRecognition()
            }
            speechChunkCount += 1
            if speechChunkCount >= kMaxSpeechChunks {
                await finalizeUtterance()
            }
        } else if listeningForUtterance {
            silenceCount += 1
            if silenceCount >= kSilenceChunks {
                await finalizeUtterance()
            }
        }
    }

    private func finalizeUtterance() async {
        listeningForUtterance = false
        silenceCount = 0

        if speechChunkCount < kMinSpeechChunks {
            speechChunkCount = 0
            recognizer.stopRecognition()
            setState(.idle)
            return
        }
        speechChunkCount = 0
        setState(.thinking)
        recognizer.stopRecognition()

        // Brief window for final SR result to arrive
        try? await Task.sleep(nanoseconds: 500_000_000)
        await handleFinalTranscript(latestTranscript)
    }

    private func handlePartialTranscript(_ text: String) async {
        latestTranscript = text
        delegate?.voiceEngine(self, didTranscribe: text)
    }

    private func handleFinalTranscript(_ text: String) async {
        guard !text.isEmpty else {
            setState(.idle)
            return
        }
        latestTranscript = ""

        let normalized = text.lowercased()
            .replacingOccurrences(of: "[^\\w\\s]", with: "", options: .regularExpression)

        var command: String?
        for wake in kWakeWords {
            if let range = normalized.range(of: wake) {
                let offset = normalized.distance(from: normalized.startIndex, to: range.upperBound)
                let rest = String(text.dropFirst(offset))
                    .trimmingCharacters(in: CharacterSet(charactersIn: " ,.\n"))
                command = rest
                break
            }
        }

        guard let cmd = command else {
            setState(.idle)
            return
        }

        let finalCmd = cmd.isEmpty ? "yes?" : cmd
        delegate?.voiceEngine(self, didRecognizeCommand: finalCmd)
        setState(.idle)
    }

    private func setState(_ s: SparkyState) {
        delegate?.voiceEngine(self, didChangeState: s)
    }
}
