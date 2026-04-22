import Foundation
import Observation

struct TranscriptionEntry: Codable, Identifiable {
    let id: UUID
    let text: String
    let rawText: String
    let timestamp: Date
    let duration: TimeInterval
    let language: String
    let model: String
    let wasCleanedByLLM: Bool
    let targetApp: String?

    init(
        text: String,
        rawText: String,
        duration: TimeInterval,
        language: String,
        model: String,
        wasCleanedByLLM: Bool,
        targetApp: String? = nil
    ) {
        self.id = UUID()
        self.text = text
        self.rawText = rawText
        self.timestamp = Date()
        self.duration = duration
        self.language = language
        self.model = model
        self.wasCleanedByLLM = wasCleanedByLLM
        self.targetApp = targetApp
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    var wordCount: Int {
        text.split(separator: " ").count
    }
}

@Observable
@MainActor
final class TranscriptionHistory {
    private(set) var entries: [TranscriptionEntry] = []
    var searchQuery: String = ""

    private let storageURL: URL

    var filteredEntries: [TranscriptionEntry] {
        if searchQuery.isEmpty {
            return entries
        }
        let query = searchQuery.lowercased()
        return entries.filter { entry in
            entry.text.lowercased().contains(query) ||
            (entry.targetApp?.lowercased().contains(query) ?? false)
        }
    }

    var totalWords: Int {
        entries.reduce(0) { $0 + $1.wordCount }
    }

    var totalDuration: TimeInterval {
        entries.reduce(0) { $0 + $1.duration }
    }

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("Pa1Whisper", isDirectory: true)
        try? FileManager.default.createDirectory(at: appDir, withIntermediateDirectories: true)
        storageURL = appDir.appendingPathComponent("transcription_history.json")
        load()
    }

    func add(_ entry: TranscriptionEntry) {
        entries.insert(entry, at: 0)
        save()
    }

    func delete(_ entry: TranscriptionEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func clearAll() {
        entries.removeAll()
        save()
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            entries = try JSONDecoder().decode([TranscriptionEntry].self, from: data)
        } catch {
            owLog("[Pa1Whisper] Failed to load history: \(error)")
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            owLog("[Pa1Whisper] Failed to save history: \(error)")
        }
    }
}
