import AVFoundation
import Observation

@Observable
@MainActor
final class TTSManager: NSObject, AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()

    var text: String = ""
    var selectedVoiceIdentifier: String = ""
    var rate: Float = AVSpeechUtteranceDefaultSpeechRate
    var isSpeaking: Bool = false

    let voices: [AVSpeechSynthesisVoice]

    override init() {
        let allVoices = AVSpeechSynthesisVoice.speechVoices()
        voices = allVoices.filter { $0.language.hasPrefix("en") }.sorted { $0.name < $1.name }
        selectedVoiceIdentifier = AVSpeechSynthesisVoice(language: "en-US")?.identifier
            ?? allVoices.first?.identifier ?? ""
        super.init()
        synthesizer.delegate = self
    }

    var selectedVoice: AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice.speechVoices().first { $0.identifier == selectedVoiceIdentifier }
    }

    func speak() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = selectedVoice
        utterance.rate = rate
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = true }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}
