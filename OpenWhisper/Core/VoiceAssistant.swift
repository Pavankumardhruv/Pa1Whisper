import AVFoundation

@MainActor
final class VoiceAssistant: NSObject, AVSpeechSynthesizerDelegate {
    private let baseURL = "http://localhost:11434"
    private let model = "qwen2.5:3b"
    private let synthesizer = AVSpeechSynthesizer()
    private let onSpeechFinished: () -> Void

    private let systemPrompt = """
        You are a helpful voice assistant running locally on a Mac. Rules:
        - Keep answers concise (1-3 sentences) since they will be spoken aloud
        - Be direct and helpful — no filler
        - If asked about code, give a brief explanation
        - If the question is unclear, give your best interpretation
        - Output ONLY your response, nothing else
        """

    init(onSpeechFinished: @escaping () -> Void) {
        self.onSpeechFinished = onSpeechFinished
        super.init()
        synthesizer.delegate = self
    }

    /// Send a question to Ollama and get a conversational response
    nonisolated func ask(question: String) async -> String {
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            return "Sorry, I couldn't process that."
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": model,
            "prompt": "\(systemPrompt)\n\nUser: \(question)",
            "stream": false,
            "options": [
                "temperature": 0.7,
                "num_predict": 150
            ]
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, response) = try await URLSession.shared.data(for: request)

            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                return "Sorry, Ollama didn't respond."
            }

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let responseText = json["response"] as? String {
                let cleaned = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty {
                    return cleaned
                }
            }
        } catch {
            owLog("[VoiceAssistant] Ollama error: \(error)")
        }

        return "Sorry, I couldn't get a response."
    }

    /// Speak the response text using macOS TTS
    func speak(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 0.9
        synthesizer.speak(utterance)
    }

    /// Stop speaking immediately
    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            onSpeechFinished()
        }
    }
}
