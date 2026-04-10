import AppKit
import Defaults
import KeyboardShortcuts
import SwiftUI

/// Content for the menu bar dropdown.
struct MenuItemView: View {
    let appDelegate: AppDelegate
    @Default(.isAutoDetectEnabled) private var isAutoDetectEnabled

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
    }

    var body: some View {
        Text("MoePeek \(appVersion)")
            .font(.headline)

        Divider()

        Button("Manual Translation") {
            guard let coordinator = appDelegate.coordinator,
                  let panelController = appDelegate.panelController else { return }
            coordinator.prepareInputMode()
            panelController.showAtScreenCenter()
        }
        .globalKeyboardShortcut(.inputTranslation)

        Button("Selection Translation") {
            guard let coordinator = appDelegate.coordinator,
                  let panelController = appDelegate.panelController else { return }
            Task {
                await coordinator.translateSelection()
                panelController.showAtCursor()
            }
        }
        .globalKeyboardShortcut(.translateSelection)

        Button("Clipboard Translation") {
            guard let coordinator = appDelegate.coordinator,
                  let panelController = appDelegate.panelController else { return }
            coordinator.translateClipboard()
            panelController.showAtCursor()
        }
        .globalKeyboardShortcut(.clipboardTranslation)

        Divider()

        Toggle("Text Selection Icon", isOn: $isAutoDetectEnabled)

        Divider()

        Button("Onboarding Guide...") {
            appDelegate.onboardingController.showWindow()
        }

        Button("Settings...") {
            appDelegate.settingsController.showWindow()
        }
        .keyboardShortcut(",")

        Divider()

        Button("Quit MoePeek") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
