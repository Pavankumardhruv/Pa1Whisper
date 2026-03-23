import AppKit
import CoreGraphics
import ApplicationServices

final class TextInjector: @unchecked Sendable {

    /// Copy text to the system clipboard
    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Type text directly into the target app by simulating keystrokes
    func pasteText(_ text: String, targetApp: NSRunningApplication? = nil) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty || cleaned.hasPrefix("[BLANK") {
            owLog("[TextInjector] Skipping empty/junk text: \(cleaned)")
            return
        }

        owLog("[TextInjector] Starting type (\(cleaned.count) chars)")

        // Activate the target app
        if let app = targetApp {
            owLog("[TextInjector] Activating: \(app.localizedName ?? "?") (pid \(app.processIdentifier))")
            app.activate()
        }

        // Wait for app activation, then type characters directly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.typeText(cleaned)
        }
    }

    /// Type text character by character using CGEvent key simulation
    private func typeText(_ text: String) {
        let src = CGEventSource(stateID: .combinedSessionState)

        for char in text {
            var utf16 = Array(String(char).utf16)
            guard let event = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: true) else { continue }
            event.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: &utf16)
            event.post(tap: .cghidEventTap)

            let up = CGEvent(keyboardEventSource: src, virtualKey: 0, keyDown: false)
            up?.post(tap: .cghidEventTap)

            usleep(3_000) // 3ms between keystrokes for reliability
        }
        owLog("[TextInjector] Typed \(text.count) chars directly")
    }

}
