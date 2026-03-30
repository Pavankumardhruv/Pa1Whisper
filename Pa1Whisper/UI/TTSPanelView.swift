import SwiftUI
import AVFoundation

struct TTSPanelView: View {
    @Environment(TTSManager.self) var tts

    var body: some View {
        @Bindable var tts = tts

        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Text to Speech")
                        .font(.headline)
                    Text("Powered by macOS voices")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Text("\(tts.text.count) chars")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            // Text input
            ZStack(alignment: .topLeading) {
                if tts.text.isEmpty {
                    Text("Type or paste text here…")
                        .foregroundStyle(.tertiary)
                        .font(.body)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $tts.text)
                    .font(.body)
                    .padding(.horizontal, 4)
                    .scrollContentBackground(.hidden)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(minHeight: 150)
            .background(Color(nsColor: .textBackgroundColor))

            Divider()

            // Controls bar
            VStack(spacing: 10) {
                // Voice picker
                HStack(spacing: 8) {
                    Image(systemName: "person.wave.2")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                    Text("Voice")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Picker("", selection: $tts.selectedVoiceIdentifier) {
                        ForEach(tts.voices, id: \.identifier) { voice in
                            Text(voice.name).tag(voice.identifier)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 200)
                }

                // Speed slider
                HStack(spacing: 8) {
                    Image(systemName: "gauge.with.dots.needle.33percent")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                    Text("Speed")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Slider(
                        value: $tts.rate,
                        in: AVSpeechUtteranceMinimumSpeechRate...AVSpeechUtteranceMaximumSpeechRate
                    )
                    Text(speedLabel(tts.rate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 42, alignment: .leading)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Divider()

            // Action buttons
            HStack(spacing: 8) {
                Button {
                    tts.text = ""
                } label: {
                    Image(systemName: "xmark.circle")
                    Text("Clear")
                }
                .buttonStyle(.bordered)
                .disabled(tts.text.isEmpty)

                Spacer()

                Button {
                    tts.stop()
                } label: {
                    Image(systemName: "stop.fill")
                    Text("Stop")
                }
                .buttonStyle(.bordered)
                .disabled(!tts.isSpeaking)

                Button {
                    tts.speak()
                } label: {
                    Label(
                        tts.isSpeaking ? "Speaking…" : "Speak",
                        systemImage: tts.isSpeaking ? "speaker.wave.3.fill" : "play.fill"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(tts.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || tts.isSpeaking)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .frame(minWidth: 500, minHeight: 360)
    }

    private func speedLabel(_ rate: Float) -> String {
        let min = AVSpeechUtteranceMinimumSpeechRate
        let max = AVSpeechUtteranceMaximumSpeechRate
        let normalized = (rate - min) / (max - min)
        switch normalized {
        case ..<0.35: return "Slow"
        case ..<0.55: return "Normal"
        case ..<0.75: return "Fast"
        default:      return "Max"
        }
    }
}
