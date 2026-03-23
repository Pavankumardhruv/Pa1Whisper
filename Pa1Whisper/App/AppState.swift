import SwiftUI
import Observation
import AVFoundation
import ApplicationServices
import ServiceManagement

@Observable
@MainActor
final class AppState {

    static let shared = AppState()

    // MARK: - Recording State

    enum RecordingState: Sendable {
        case idle, recording, transcribing
        case voiceRecording, voiceThinking, voiceSpeaking
    }

    var recordingState: RecordingState = .idle

    // MARK: - Settings (persisted via UserDefaults)

    var whisperModel: String {
        didSet { UserDefaults.standard.set(whisperModel, forKey: "whisperModel") }
    }
    var language: String {
        didSet { UserDefaults.standard.set(language, forKey: "language") }
    }
    var llmCleanupEnabled: Bool {
        didSet { UserDefaults.standard.set(llmCleanupEnabled, forKey: "llmCleanupEnabled") }
    }
    var flowBarEnabled: Bool {
        didSet { UserDefaults.standard.set(flowBarEnabled, forKey: "flowBarEnabled") }
    }
    var autoPasteEnabled: Bool {
        didSet { UserDefaults.standard.set(autoPasteEnabled, forKey: "autoPasteEnabled") }
    }
    var voiceAssistantEnabled: Bool {
        didSet { UserDefaults.standard.set(voiceAssistantEnabled, forKey: "voiceAssistantEnabled") }
    }
    var launchAtLogin: Bool {
        didSet {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                owLog("[Pa1Whisper] Launch at login error: \(error)")
            }
        }
    }

    // MARK: - Runtime State

    var audioLevel: Float = 0.0
    var recordingDuration: TimeInterval = 0.0
    var ollamaAvailable: Bool = false
    var modelLoaded: Bool = false
    var modelLoading: Bool = false
    var modelLoadProgress: Double = 0.0
    var lastTranscription: String = ""
    var lastAssistantResponse: String = ""
    var lastError: String?
    var accessibilityGranted: Bool = false
    var microphoneGranted: Bool = false

    // MARK: - Components

    private var audioEngine: AudioEngine?
    private var transcriber: WhisperTranscriber?
    private var llmCleanup: LLMCleanup?
    private var textInjector: TextInjector?
    private var voiceAssistant: VoiceAssistant?
    private var hotkey: GlobalHotkey?
    private var flowBarController: FlowBarController?
    private var recordingTimer: Timer?
    private var targetApp: NSRunningApplication?

    // MARK: - Computed

    var menuBarIcon: String {
        switch recordingState {
        case .idle: "mic.fill"
        case .recording: "record.circle.fill"
        case .transcribing: "ellipsis.circle.fill"
        case .voiceRecording: "record.circle.fill"
        case .voiceThinking: "brain.head.profile"
        case .voiceSpeaking: "speaker.wave.2.fill"
        }
    }

    var menuBarIconColor: Color {
        switch recordingState {
        case .idle: .gray
        case .recording: .red
        case .transcribing: .orange
        case .voiceRecording: .purple
        case .voiceThinking: .purple
        case .voiceSpeaking: .purple
        }
    }

    // MARK: - Init

    init() {
        let defaults = UserDefaults.standard
        whisperModel = defaults.string(forKey: "whisperModel") ?? "base"
        language = defaults.string(forKey: "language") ?? "en"
        llmCleanupEnabled = defaults.object(forKey: "llmCleanupEnabled") as? Bool ?? true
        voiceAssistantEnabled = defaults.object(forKey: "voiceAssistantEnabled") as? Bool ?? true
        flowBarEnabled = defaults.object(forKey: "flowBarEnabled") as? Bool ?? true
        autoPasteEnabled = defaults.object(forKey: "autoPasteEnabled") as? Bool ?? true
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    // MARK: - Setup

    func setup() async {
        owLog("[Pa1Whisper] Setting up...")
        audioEngine = AudioEngine()
        transcriber = WhisperTranscriber()
        llmCleanup = LLMCleanup()
        textInjector = TextInjector()
        voiceAssistant = VoiceAssistant { [weak self] in
            Task { @MainActor in
                self?.recordingState = .idle
                owLog("[Pa1Whisper] Voice assistant finished speaking")
            }
        }
        flowBarController = FlowBarController(appState: self)

        // Show flow bar immediately (always visible like Wispr Flow)
        if flowBarEnabled {
            owLog("[Pa1Whisper] Showing flow bar...")
            flowBarController?.show()
            owLog("[Pa1Whisper] Flow bar shown")
        }

        // Request mic permission
        microphoneGranted = await audioEngine?.requestPermission() ?? false
        owLog("[Pa1Whisper] Microphone permission: \(microphoneGranted)")

        // Check accessibility
        accessibilityGranted = GlobalHotkey.checkAccessibility(prompt: true)
        owLog("[Pa1Whisper] Accessibility: \(accessibilityGranted)")

        // Register global hotkeys
        hotkey = GlobalHotkey(
            onRightPress: { [weak self] in
                Task { @MainActor in self?.startRecording() }
            },
            onRightRelease: { [weak self] in
                Task { @MainActor in self?.stopRecording() }
            },
            onLeftPress: { [weak self] in
                Task { @MainActor in self?.startVoiceRecording() }
            },
            onLeftRelease: { [weak self] in
                Task { @MainActor in self?.stopVoiceRecording() }
            }
        )
        hotkey?.register()
        owLog("[Pa1Whisper] Hotkeys registered (Right ⌥ dictation, Left ⌥ voice chat)")

        // Load Whisper model
        owLog("[Pa1Whisper] Loading model: \(whisperModel)...")
        await loadModel()
        owLog("[Pa1Whisper] Model loaded: \(modelLoaded)")

        // Check Ollama availability
        ollamaAvailable = await LLMCleanup.checkAvailability()
        owLog("[Pa1Whisper] Ollama available: \(ollamaAvailable)")
        owLog("[Pa1Whisper] Ready!")
    }

    func loadModel() async {
        modelLoaded = false
        modelLoading = true
        modelLoadProgress = 0
        owLog("[Pa1Whisper] Loading model: \(whisperModel)...")
        do {
            try await transcriber?.loadModel(name: whisperModel) { [weak self] progress in
                Task { @MainActor in
                    self?.modelLoadProgress = progress
                }
            }
            modelLoaded = true
            modelLoading = false
            owLog("[Pa1Whisper] Model loaded: \(modelLoaded)")
        } catch {
            modelLoading = false
            lastError = "Failed to load model: \(error.localizedDescription)"
            owLog("[Pa1Whisper] Model load failed: \(error)")
        }
    }

    // MARK: - Recording Flow

    func startRecording() {
        guard recordingState == .idle else { return }
        guard modelLoaded else {
            owLog("[Pa1Whisper] Cannot record — model not loaded yet")
            return
        }

        // Save the currently focused app BEFORE we start recording,
        // so we can re-activate it when pasting the transcription
        targetApp = NSWorkspace.shared.frontmostApplication
        owLog("[Pa1Whisper] Target app: \(targetApp?.localizedName ?? "unknown")")

        recordingState = .recording
        recordingDuration = 0
        audioLevel = 0
        lastError = nil

        audioEngine?.startRecording { [weak self] level in
            Task { @MainActor in
                self?.audioLevel = level
            }
        }

        // Start duration timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingDuration += 0.1
            }
        }

    }

    func stopRecording() {
        guard recordingState == .recording else { return }
        recordingState = .transcribing
        owLog("[Pa1Whisper] Transcribing...")

        recordingTimer?.invalidate()
        recordingTimer = nil

        guard let audioData = audioEngine?.stopRecording() else {
            owLog("[Pa1Whisper] No audio captured")
            recordingState = .idle
            return
        }

        guard audioData.count > 4800 else {
            owLog("[Pa1Whisper] Audio too short (\(audioData.count) samples)")
            recordingState = .idle
            return
        }

        Task {
            do {
                var text = try await transcriber?.transcribe(
                    audioData: audioData,
                    language: language
                ) ?? ""

                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty,
                      !trimmed.hasPrefix("[BLANK"),
                      !trimmed.hasPrefix("(BLANK") else {
                    owLog("[Pa1Whisper] Empty/blank transcription, skipping")
                    recordingState = .idle
                    return
                }

                owLog("[Pa1Whisper] Raw: \(text)")

                if llmCleanupEnabled && ollamaAvailable {
                    text = await llmCleanup?.cleanup(text: text) ?? text
                    owLog("[Pa1Whisper] Cleaned: \(text)")
                }

                lastTranscription = text

                if autoPasteEnabled {
                    textInjector?.pasteText(text, targetApp: targetApp)
                } else {
                    textInjector?.copyToClipboard(text)
                }
            } catch {
                owLog("[Pa1Whisper] Error: \(error)")
                lastError = error.localizedDescription
            }

            recordingState = .idle
        }
    }

    // MARK: - Voice Assistant Flow

    func startVoiceRecording() {
        guard recordingState == .idle else { return }
        guard voiceAssistantEnabled else { return }
        guard modelLoaded else {
            owLog("[Pa1Whisper] Cannot voice chat — model not loaded yet")
            return
        }
        guard ollamaAvailable else {
            owLog("[Pa1Whisper] Cannot voice chat — Ollama not available")
            lastError = "Voice chat requires Ollama"
            return
        }

        owLog("[Pa1Whisper] Voice recording started")
        recordingState = .voiceRecording
        recordingDuration = 0
        audioLevel = 0
        lastError = nil
        lastAssistantResponse = ""

        audioEngine?.startRecording { [weak self] level in
            Task { @MainActor in
                self?.audioLevel = level
            }
        }

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.recordingDuration += 0.1
            }
        }
    }

    func stopVoiceRecording() {
        guard recordingState == .voiceRecording else { return }
        recordingState = .voiceThinking
        owLog("[Pa1Whisper] Voice thinking...")

        recordingTimer?.invalidate()
        recordingTimer = nil

        guard let audioData = audioEngine?.stopRecording() else {
            owLog("[Pa1Whisper] No audio captured for voice chat")
            recordingState = .idle
            return
        }

        guard audioData.count > 4800 else {
            owLog("[Pa1Whisper] Voice audio too short")
            recordingState = .idle
            return
        }

        Task {
            do {
                let question = try await transcriber?.transcribe(
                    audioData: audioData,
                    language: language
                ) ?? ""

                let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty,
                      !trimmed.hasPrefix("[BLANK"),
                      !trimmed.hasPrefix("(BLANK") else {
                    owLog("[Pa1Whisper] Empty voice question, skipping")
                    recordingState = .idle
                    return
                }

                owLog("[Pa1Whisper] Voice question: \(question)")

                let response = await voiceAssistant?.ask(question: trimmed) ?? "Sorry, no response."
                owLog("[Pa1Whisper] Voice response: \(response)")

                lastAssistantResponse = response
                recordingState = .voiceSpeaking
                voiceAssistant?.speak(text: response)
                // State goes back to .idle via onSpeechFinished callback
            } catch {
                owLog("[Pa1Whisper] Voice chat error: \(error)")
                lastError = error.localizedDescription
                recordingState = .idle
            }
        }
    }

    // MARK: - Refresh

    func refreshPermissions() {
        accessibilityGranted = GlobalHotkey.checkAccessibility(prompt: false)
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        microphoneGranted = (status == .authorized)
    }

    func refreshOllamaStatus() async {
        ollamaAvailable = await LLMCleanup.checkAvailability()
    }
}
