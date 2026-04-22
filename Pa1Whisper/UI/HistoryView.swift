import SwiftUI

struct HistoryView: View {
    @Environment(TranscriptionHistory.self) var history

    @State private var selectedEntry: TranscriptionEntry?
    @State private var showClearConfirm = false
    @State private var copiedId: UUID?

    var body: some View {
        @Bindable var history = history

        VStack(spacing: 0) {
            headerBar
            Divider()

            if history.entries.isEmpty {
                emptyState
            } else {
                searchAndList
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .alert("Clear All History?", isPresented: $showClearConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Clear All", role: .destructive) {
                history.clearAll()
            }
        } message: {
            Text("This will permanently delete \(history.entries.count) transcriptions.")
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Image(systemName: "clock.arrow.circlepath")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Transcription History")
                .font(.headline)
            Spacer()
            statsView
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var statsView: some View {
        HStack(spacing: 12) {
            Label("\(history.entries.count)", systemImage: "text.bubble")
                .font(.caption)
                .foregroundStyle(.secondary)
            Label("\(history.totalWords) words", systemImage: "character.cursor.ibeam")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "text.bubble")
                .font(.system(size: 40))
                .foregroundStyle(.quaternary)
            Text("No transcriptions yet")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Hold Right ⌥ and speak to start")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Search + List

    private var searchAndList: some View {
        @Bindable var history = history

        return VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search transcriptions...", text: $history.searchQuery)
                    .textFieldStyle(.plain)
                if !history.searchQuery.isEmpty {
                    Button {
                        history.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button {
                    showClearConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Clear all history")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(history.filteredEntries) { entry in
                        entryRow(entry)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Entry Row

    private func entryRow(_ entry: TranscriptionEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.text)
                .font(.body)
                .lineLimit(selectedEntry?.id == entry.id ? nil : 3)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 8) {
                Label(entry.formattedDate, systemImage: "clock")
                Label(String(format: "%.1fs", entry.duration), systemImage: "waveform")
                if let app = entry.targetApp {
                    Label(app, systemImage: "app")
                }
                if entry.wasCleanedByLLM {
                    Label("Cleaned", systemImage: "sparkles")
                        .foregroundStyle(.purple)
                }

                Spacer()

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(entry.text, forType: .string)
                    copiedId = entry.id
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        if copiedId == entry.id { copiedId = nil }
                    }
                } label: {
                    Image(systemName: copiedId == entry.id ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(copiedId == entry.id ? .green : .secondary)
                }
                .buttonStyle(.plain)
                .help("Copy to clipboard")

                Button {
                    history.delete(entry)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("Delete")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(selectedEntry?.id == entry.id ? Color.accentColor.opacity(0.05) : .clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedEntry = selectedEntry?.id == entry.id ? nil : entry
            }
        }
    }
}
