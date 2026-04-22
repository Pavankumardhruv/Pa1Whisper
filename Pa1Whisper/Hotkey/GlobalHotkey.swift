import Cocoa
import ApplicationServices

final class GlobalHotkey {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var rightActive = false
    private var leftActive = false
    private var isRightPressed = false
    private var isLeftPressed = false

    // Right Option = keyCode 61, Left Option = keyCode 58
    private let rightOptionKeyCode: UInt16 = 61
    private let leftOptionKeyCode: UInt16 = 58

    private let onRightPress: () -> Void
    private let onRightRelease: () -> Void
    private let onLeftPress: () -> Void
    private let onLeftRelease: () -> Void

    init(
        onRightPress: @escaping () -> Void,
        onRightRelease: @escaping () -> Void,
        onLeftPress: @escaping () -> Void,
        onLeftRelease: @escaping () -> Void
    ) {
        self.onRightPress = onRightPress
        self.onRightRelease = onRightRelease
        self.onLeftPress = onLeftPress
        self.onLeftRelease = onLeftRelease
    }

    /// Check and optionally prompt for Accessibility permissions.
    /// Uses a real functional test (AXUIElement) instead of trusting AXIsProcessTrusted(),
    /// which can return stale results with ad-hoc or self-signed binaries.
    static func checkAccessibility(prompt: Bool) -> Bool {
        // Real test: try to get the focused element via AXUIElement API.
        // This only works if Accessibility is truly granted.
        let systemWide = AXUIElementCreateSystemWide()
        var focusedRef: AnyObject?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        )
        // .success or .noValue both mean we have access
        // .apiDisabled or .cannotComplete means no access
        if result == .success || result == .noValue {
            owLog("[GlobalHotkey] Accessibility real test: PASS (AXUIElement result=\(result.rawValue))")
            return true
        }

        // Also check the official API
        if AXIsProcessTrusted() {
            owLog("[GlobalHotkey] AXIsProcessTrusted=true (but AXUIElement failed with \(result.rawValue))")
            return true
        }

        owLog("[GlobalHotkey] Accessibility NOT granted (AXUIElement=\(result.rawValue), AXIsProcessTrusted=false)")

        // Not granted — show prompt if requested
        if prompt {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        return false
    }

    /// Register global and local key monitors for Right Option hold-to-talk
    func register() {
        // Monitor events in other applications
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
        }

        // Monitor events in our own app
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlagsChanged(event)
            return event
        }
    }

    func resetToggleState() {
        rightActive = false
        leftActive = false
    }

    func unregister() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        let optionPressed = event.modifierFlags.contains(.option)

        // Tap-to-toggle: action fires on key-up (tap completed)
        if event.keyCode == rightOptionKeyCode {
            if optionPressed && !isRightPressed {
                isRightPressed = true
            } else if !optionPressed && isRightPressed {
                isRightPressed = false
                if !rightActive {
                    rightActive = true
                    onRightPress()
                } else {
                    rightActive = false
                    onRightRelease()
                }
            }
        } else if event.keyCode == leftOptionKeyCode {
            if optionPressed && !isLeftPressed {
                isLeftPressed = true
            } else if !optionPressed && isLeftPressed {
                isLeftPressed = false
                if !leftActive {
                    leftActive = true
                    onLeftPress()
                } else {
                    leftActive = false
                    onLeftRelease()
                }
            }
        }
    }

    deinit {
        unregister()
    }
}
