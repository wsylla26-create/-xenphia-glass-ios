import Foundation
import Combine
@preconcurrency import AVFoundation
@preconcurrency import Speech

@MainActor
final class VoiceController: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var isSpeaking = false
    @Published private(set) var isListening = false
    @Published private(set) var authorizing = false
    @Published var transcript = ""
    @Published var status = ""
    @Published var enabled = UserDefaults.standard.object(forKey: "voiceEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(enabled, forKey: "voiceEnabled"); if !enabled { stopSpeech() } }
    }
    @Published var language = UserDefaults.standard.string(forKey: "voice.language") ?? "en-US" {
        didSet { UserDefaults.standard.set(language, forKey: "voice.language"); stopAll() }
    }
    var selectedLanguage: VoiceLanguage { VoiceLanguage(rawValue: language) ?? .english }
    // No audio framework objects are created merely by opening the app.
    private var synthesizer: AVSpeechSynthesizer?
    private var engine: AVAudioEngine?
    private var sessionActive = false
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var recognition: SFSpeechRecognitionTask?
    private var currentUtterance: AVSpeechUtterance?
    private var generation = UUID()
    private var hasTap = false
    private var timeout: Task<Void, Never>?
    private var foreground = true
    private var silenceTask: Task<Void, Never>?
    var onVoiceRequest: ((String) -> Void)?
    override init() { super.init() }

    func setForeground(_ value: Bool) { foreground = value; if !value { stopAll() } }
    func speak(_ text: String) {
        guard enabled, foreground else { return }
        print("[XENPHIA Glass 0.5.0] Speech requested by user action")
        stopListening(); stopSpeech()
        do {
            if synthesizer == nil {
                let speaker = AVSpeechSynthesizer(); speaker.delegate = self; synthesizer = speaker
            }
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true); sessionActive = true
            let utterance = AVSpeechUtterance(string: text)
            utterance.voice = AVSpeechSynthesisVoice.speechVoices().first { $0.language == selectedLanguage.rawValue && $0.gender == .female } ?? AVSpeechSynthesisVoice(language: selectedLanguage.rawValue)
            guard utterance.voice != nil else { deactivateAudio(); status = "Install a voice for the selected language in iPad Settings. Typed requests still work."; return }
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.94
            currentUtterance = utterance
            synthesizer?.speak(utterance)
        } catch { deactivateAudio(); status = "Audio is unavailable. You can still type a request." }
    }
    func stopSpeech() {
        currentUtterance = nil; isSpeaking = false
        synthesizer?.stopSpeaking(at: .immediate)
        if !isListening { deactivateAudio() }
    }
    func startListening() async {
        guard foreground, !isListening, !authorizing else { return }
        stopSpeech(); authorizing = true
        let token = UUID(); generation = token
        defer { if generation == token { authorizing = false } }
        let speechAllowed: Bool = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        guard generation == token else { return }
        guard speechAllowed else { status = "Speech recognition permission was not granted. Please type your request."; return }
        let micAllowed: Bool = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard generation == token, foreground else { return }
        guard micAllowed else { status = "Microphone permission was not granted. Please type your request."; return }
        print("[XENPHIA Glass 0.5.0] Creating speech recognizer after permission")
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: selectedLanguage.rawValue)), recognizer.isAvailable else { status = "Speech recognition is unavailable. Please type your request."; return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [])
            try session.setActive(true); sessionActive = true
            let audioRequest = SFSpeechAudioBufferRecognitionRequest()
            audioRequest.shouldReportPartialResults = true
            audioRequest.requiresOnDeviceRecognition = recognizer.supportsOnDeviceRecognition
            request = audioRequest
            print("[XENPHIA Glass 0.5.0] Creating microphone engine after permission")
            let engine = AVAudioEngine(); self.engine = engine
            let node = engine.inputNode
            let format = node.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw NSError(domain: "XenphiaAudio", code: 1) }
            node.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in audioRequest.append(buffer) }
            hasTap = true; transcript = ""
            recognition = recognizer.recognitionTask(with: audioRequest) { [weak self] result, error in
                DispatchQueue.main.async {
                    guard let self, self.generation == token else { return }
                    if let result {
                        self.transcript = result.bestTranscription.formattedString
                        self.silenceTask?.cancel()
                        if result.isFinal {
                            self.submitVoiceRequest(token: token)
                        } else if !self.transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            self.silenceTask = Task { [weak self] in
                                try? await Task.sleep(nanoseconds: 2_000_000_000)
                                guard !Task.isCancelled else { return }
                                self?.submitVoiceRequest(token: token)
                            }
                        }
                    }
                    if error != nil && self.generation == token {
                        self.stopListening()
                        self.status = self.transcript.isEmpty ? "No speech captured. Tap Speak to try again." : "Recognition interrupted. Tap Speak to try again, or type your request and press Go."
                    }
                }
            }
            engine.prepare(); try engine.start(); isListening = true
            status = "Listening. Say your request, then pause for two seconds to open it automatically."
            timeout = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled, let self, self.generation == token else { return }
                self.stopListening(); self.status = "Microphone off. Tap Speak to try again, or type your request and press Go."
            }
        } catch { stopListening(); status = "Microphone input is unavailable. Please type your request." }
    }
    private func submitVoiceRequest(token: UUID) {
        guard generation == token, foreground, isListening else { return }
        let captured = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !captured.isEmpty else { return }
        stopListening()
        status = "Microphone off. Opening your spoken request…"
        onVoiceRequest?(captured)
    }
    func stopListening() {
        silenceTask?.cancel(); silenceTask = nil
        let wasListening = isListening
        generation = UUID(); authorizing = false; timeout?.cancel(); timeout = nil
        if engine?.isRunning == true { engine?.stop() }
        if hasTap { engine?.inputNode.removeTap(onBus: 0); hasTap = false }
        engine = nil
        request?.endAudio(); recognition?.cancel(); request = nil; recognition = nil; isListening = false
        if !isSpeaking { deactivateAudio() }
        if wasListening { status = transcript.isEmpty ? "No speech captured. Try again or type instead." : "Microphone off. Type your request and press Go, or tap Speak to try again." }
    }
    private func deactivateAudio() {
        guard sessionActive else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        sessionActive = false
    }
    func stopAll() { stopListening(); stopSpeech() }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.foreground, self.currentUtterance === utterance else { return }; self.isSpeaking = true
        }
    }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { finish(utterance) }
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) { finish(utterance) }
    nonisolated private func finish(_ utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.currentUtterance === utterance else { return }
            self.currentUtterance = nil; self.isSpeaking = false
            if !self.isListening { self.deactivateAudio() }
        }
    }
}
