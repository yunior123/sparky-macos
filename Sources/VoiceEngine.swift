import AVFoundation
import Speech

protocol VoiceEngineDelegate: AnyObject, Sendable {
    func voiceEngine(_ engine: VoiceEngine, didChangeState newState: SparkyState)
    func voiceEngine(_ engine: VoiceEngine, didTranscribe text: String)
    func voiceEngine(_ engine: VoiceEngine, didRecognizeCommand command: String)
}

private let kVADThreshold: Float = 0.015  // calibrated from mic data
private let kSilenceLimit: Int   = 14
private let kMinChunks: Int      = 6     // need ~600ms of real speech
private let kMaxChunks: Int      = 300
private let kWakeWords = ["hey sparky", "sparky", "hey sparki", "hey sparkey"]

private func sparkyLog(_ msg: String) {
    let line = msg + "\n"
    guard let data = line.data(using: .utf8) else { return }
    if !FileManager.default.fileExists(atPath: "/tmp/sparky_debug.log") {
        FileManager.default.createFile(atPath: "/tmp/sparky_debug.log", contents: nil)
    }
    if let fh = FileHandle(forWritingAtPath: "/tmp/sparky_debug.log") {
        fh.seekToEndOfFile(); fh.write(data); fh.closeFile()
    }
}

private final class TapBridge: @unchecked Sendable {
    var rmsCont: AsyncStream<Float>.Continuation?
    var srCont:  AsyncStream<(String, Bool)>.Continuation?
    var request: SFSpeechAudioBufferRecognitionRequest?
}

actor VoiceEngine {
    private weak var delegate: (any VoiceEngineDelegate)?
    private let audioEngine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private let bridge = TapBridge()
    private var srTask: SFSpeechRecognitionTask?
    private var srStream: AsyncStream<(String, Bool)>.Continuation?

    private var listening = false
    private var silenceCount = 0
    private var speechCount  = 0
    private var latestText   = ""
    private var finalDone    = false

    func setDelegate(_ d: any VoiceEngineDelegate) { delegate = d }

    func start() throws {
        recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        guard recognizer?.isAvailable == true else { sparkyLog("[Sparky] SR unavailable"); return }

        let (rmsStream, rmsCont) = AsyncStream.makeStream(of: Float.self)
        bridge.rmsCont = rmsCont

        let b = bridge
        let input = audioEngine.inputNode
        let format = input.outputFormat(forBus: 0)

        input.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            b.request?.append(buffer)   // always feed — request is created before audio starts
            guard let ch = buffer.floatChannelData?[0] else { return }
            let n = Int(buffer.frameLength); guard n > 0 else { return }
            var s: Float = 0; for i in 0..<n { s += ch[i]*ch[i] }
            b.rmsCont?.yield(sqrt(s / Float(n)))
        }

        // Create the first SR request BEFORE starting the engine
        openNewRequest()
        try audioEngine.start()
        sparkyLog("[Sparky] Engine started. Always listening...")
        Task { await self.runVAD(rmsStream) }
    }

    func stop() {
        bridge.rmsCont?.finish()
        bridge.request?.endAudio()
        bridge.request = nil
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        srTask?.cancel()
    }

    // MARK: - Always-open SR request

    private func openNewRequest() {
        let req = SFSpeechAudioBufferRecognitionRequest()
        req.shouldReportPartialResults = true
        bridge.request = req
        finalDone = false
        latestText = ""

        let (stream, cont) = AsyncStream.makeStream(of: (String, Bool).self)
        srStream = cont
        bridge.srCont = cont
        let b = bridge

        srTask = recognizer?.recognitionTask(with: req) { result, error in
            if let result {
                b.srCont?.yield((result.bestTranscription.formattedString, result.isFinal))
            }
            if let error { sparkyLog("[Sparky] SR: \(error.localizedDescription)") }
        }
        Task { await self.consumeSR(stream) }
    }

    private func consumeSR(_ stream: AsyncStream<(String, Bool)>) async {
        for await (text, isFinal) in stream {
            latestText = text
            delegate?.voiceEngine(self, didTranscribe: text)
            if isFinal {
                sparkyLog("[Sparky] Final: \"\(text)\"")
                finalDone = true
                srTask = nil; bridge.request = nil
                processWakeWord(in: text)
                return
            }
        }
    }

    // MARK: - VAD

    private var logCounter = 0
    private func runVAD(_ stream: AsyncStream<Float>) async {
        for await rms in stream {
            // Log peak RMS every ~200 chunks to calibrate threshold
            logCounter += 1
            if logCounter % 200 == 0 { sparkyLog("[Sparky] rms=\(String(format:"%.4f",rms))") }
            tick(rms: rms)
        }
    }

    private func tick(rms: Float) {
        if rms > kVADThreshold {
            silenceCount = 0; speechCount += 1
            if !listening {
                listening = true
                sparkyLog("[Sparky] Speech rms=\(String(format:"%.4f",rms))")
                setState(.listening)
            }
            if speechCount >= kMaxChunks { Task { await self.finalize() } }
        } else if listening {
            silenceCount += 1
            if silenceCount >= kSilenceLimit { Task { await self.finalize() } }
        }
    }

    private func finalize() async {
        guard listening else { return }
        listening = false; silenceCount = 0
        let chunks = speechCount; speechCount = 0

        if chunks < kMinChunks {
            srStream?.finish(); srTask?.cancel(); srTask = nil
            bridge.request?.endAudio(); bridge.request = nil
            setState(.idle)
            openNewRequest()   // ready for next utterance
            return
        }

        setState(.thinking)
        srStream?.finish()     // signal end of results stream
        bridge.request?.endAudio()  // signal end of audio → triggers isFinal

        // Timeout fallback
        let snap = latestText
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await self?.timeout(snapshot: snap)
        }
    }

    private func timeout(snapshot: String) async {
        guard !finalDone else { openNewRequest(); return }
        finalDone = true; srTask?.cancel(); srTask = nil; bridge.request = nil
        sparkyLog("[Sparky] Timeout: \"\(snapshot)\"")
        if snapshot.isEmpty { setState(.idle) } else { processWakeWord(in: snapshot) }
        openNewRequest()
    }

    // MARK: - Wake word

    private func processWakeWord(in text: String) {
        let norm = text.lowercased()
            .replacingOccurrences(of: "[^\\w\\s]", with: "", options: .regularExpression)
        for wake in kWakeWords {
            if let r = norm.range(of: wake) {
                let off = norm.distance(from: norm.startIndex, to: r.upperBound)
                let cmd = String(text.dropFirst(off))
                    .trimmingCharacters(in: CharacterSet(charactersIn: " ,.\n"))
                let final = cmd.isEmpty ? "yes?" : cmd
                sparkyLog("[Sparky] → \"\(final)\"")
                delegate?.voiceEngine(self, didRecognizeCommand: final)
                setState(.idle)
                openNewRequest()
                return
            }
        }
        sparkyLog("[Sparky] No wake word: \"\(norm)\"")
        setState(.idle)
        openNewRequest()
    }

    private func setState(_ s: SparkyState) {
        delegate?.voiceEngine(self, didChangeState: s)
    }
}

