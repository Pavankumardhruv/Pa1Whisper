import AppKit
import SwiftUI

@MainActor
final class TTSWindowController {
    private var window: NSWindow?
    private let ttsManager: TTSManager

    init(ttsManager: TTSManager) {
        self.ttsManager = ttsManager
    }

    func show() {
        if window == nil {
            createWindow()
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func createWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 400),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Pa1Whisper — Text to Speech"
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 480, height: 340)

        let view = TTSPanelView().environment(ttsManager)
        window.contentView = NSHostingView(rootView: view)

        self.window = window
    }
}
