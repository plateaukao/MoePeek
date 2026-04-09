import AppKit

// "AXTrustedCheckOptionPrompt" — same value as kAXTrustedCheckOptionPrompt,
// but using a string literal avoids the concurrency warning on the Unmanaged global var.
nonisolated(unsafe) private let axTrustedPromptKey = "AXTrustedCheckOptionPrompt" as CFString

/// Manages Accessibility permission state with polling.
@MainActor
@Observable
final class PermissionManager {
    private(set) var isAccessibilityGranted = false
    private var pollTimer: Timer?

    var allPermissionsGranted: Bool {
        isAccessibilityGranted
    }

    init() {
        isAccessibilityGranted = AXIsProcessTrusted()
    }

    /// Prompt the system accessibility permission dialog.
    func requestAccessibility() {
        let options = [axTrustedPromptKey: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        startPolling()
    }

    /// Open System Settings > Accessibility.
    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        startPolling()
    }

    /// Start polling permissions every 1.5 seconds.
    func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let accessibility = AXIsProcessTrusted()
                if accessibility != self.isAccessibilityGranted {
                    self.isAccessibilityGranted = accessibility
                }
                if self.allPermissionsGranted {
                    self.stopPolling()
                }
            }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
