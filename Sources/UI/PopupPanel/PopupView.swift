import Defaults
import SwiftUI

/// The SwiftUI content displayed inside the popup translation panel.
struct PopupView: View {
    let coordinator: TranslationCoordinator
    var onOpenSettings: (() -> Void)?
    @State private var editableText: String = ""
    @State private var expandedProviders: Set<String> = []
    @State private var targetLang: String = Defaults[.targetLanguage]
    @State private var inputHeight: CGFloat = CGFloat(Defaults[.popupInputHeight])
    @Default(.popupFontSize) private var fontSize
    @Environment(\.popupPanel) private var panel

    private let inputMinHeight: CGFloat = 36
    private let contentHorizontalPadding: CGFloat = 14

    private var maxInputHeight: CGFloat {
        let panelHeight = panel?.frame.height ?? 200
        return max(panelHeight - 120, inputMinHeight + 24)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            switch coordinator.phase {
            case .idle:
                EmptyView()

            case .grabbing:
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Grabbing text…")
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, contentHorizontalPadding)
                .padding(.vertical, contentHorizontalPadding)

            case .active:
                activeContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottomTrailing) {
            ResizeGripView()
        }
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onChange(of: coordinator.sourceText) { _, newValue in
            editableText = newValue
        }
        .onChange(of: coordinator.targetLanguage) { _, newValue in
            targetLang = newValue
        }
        .onAppear {
            editableText = coordinator.sourceText
            targetLang = coordinator.targetLanguage
            expandedProviders = Set(coordinator.activeSlots.map(\.id))
        }
        .onChange(of: coordinator.translationGeneration) { _, _ in
            expandedProviders = Set(coordinator.activeSlots.map(\.id))
        }
    }

    // MARK: - Active Content

    @ViewBuilder
    private var activeContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Global error (no providers, permissions, etc.)
            if let message = coordinator.globalError {
                VStack(alignment: .leading, spacing: 8) {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
                .padding(.horizontal, contentHorizontalPadding)
                .padding(.vertical, contentHorizontalPadding)
            } else {
                if coordinator.isInputMode {
                    // Editable source input (manual translation mode)
                    SourceInputView(
                        text: $editableText,
                        sourceLanguage: coordinator.detectedLanguage ?? "auto",
                        onSubmit: {
                            coordinator.translate(editableText)
                        }
                    )
                    .frame(height: inputHeight)
                    .padding(.horizontal, contentHorizontalPadding)
                    .padding(.top, contentHorizontalPadding)
                    .padding(.bottom, 4)

                    DraggableDividerView(
                        inputHeight: $inputHeight,
                        minHeight: inputMinHeight,
                        maxHeight: maxInputHeight,
                        horizontalPadding: contentHorizontalPadding,
                        onDragEnd: { Defaults[.popupInputHeight] = Int(inputHeight) }
                    )
                }

                // Top bar: language picker for translation, action label for actions
                HStack(spacing: 4) {
                    if let action = coordinator.currentAction {
                        Label(action.name, systemImage: "sparkles")
                            .font(.system(size: CGFloat(fontSize - 1), weight: .medium))
                            .foregroundStyle(.secondary)
                    } else {
                        LanguageBarView(targetLanguage: $targetLang)
                    }

                    Spacer()

                    Button {
                        onOpenSettings?()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: CGFloat(fontSize - 2)))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Open Settings")
                    .background { InteractiveMarker() }
                }
                .padding(.horizontal, contentHorizontalPadding)
                .padding(.vertical, 4)
                .onChange(of: targetLang) { _, newValue in
                    Defaults[.targetLanguage] = newValue
                    // Skip retranslation when this change came from coordinator sync,
                    // or when we're in action mode (the picker isn't even shown).
                    guard coordinator.currentAction == nil else { return }
                    guard newValue != coordinator.targetLanguage else { return }
                    if !editableText.isEmpty {
                        coordinator.translate(editableText)
                    }
                }

                Divider()
                    .padding(.horizontal, contentHorizontalPadding)

                // Provider results
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(coordinator.activeSlots, id: \.id) { provider in
                            if let state = coordinator.providerStates[provider.id] {
                                ProviderResultCard(
                                    provider: provider,
                                    state: state,
                                    targetLanguage: targetLang,
                                    isExpanded: expandedBinding(for: provider.id),
                                    onRetry: {
                                        coordinator.retryProvider(provider)
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal, contentHorizontalPadding)
                    .padding(.vertical, 6)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: ResultsContentHeightKey.self, value: geo.size.height)
                        }
                    )
                }
                .onPreferenceChange(ResultsContentHeightKey.self) { height in
                    autoResizePanel(resultsContentHeight: height)
                }

                // Bottom bar with copy button
                if let text = firstCompletedText {
                    HStack {
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(text, forType: .string)
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: CGFloat(fontSize - 2)))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Copy")
                        .background { InteractiveMarker() }
                    }
                    .padding(.horizontal, contentHorizontalPadding)
                    .padding(.top, 4)
                }
            }
        }
        .padding(.bottom, contentHorizontalPadding)
    }

    // MARK: - Helpers

    /// The text from the first completed provider, used for the copy button.
    private var firstCompletedText: String? {
        for provider in coordinator.activeSlots {
            if case let .completed(text) = coordinator.providerStates[provider.id] {
                return text
            }
        }
        return nil
    }

    private func autoResizePanel(resultsContentHeight: CGFloat) {
        guard let panel else { return }
        // Estimate chrome: language bar + paddings + divider + bottom padding
        let chromeHeight: CGFloat = coordinator.isInputMode ? (inputHeight + 70) : 60
        let idealHeight = chromeHeight + resultsContentHeight
        let targetHeight = min(max(idealHeight, panel.minSize.height), panel.maxSize.height)

        let currentFrame = panel.frame
        guard targetHeight > currentFrame.height + 2 else { return }

        // Anchor top edge (maxY in screen coords), grow downward
        var newY = currentFrame.maxY - targetHeight
        if let screen = panel.screen ?? NSScreen.main {
            newY = max(newY, screen.visibleFrame.minY)
        }
        panel.setFrame(
            NSRect(x: currentFrame.origin.x, y: newY, width: currentFrame.width, height: targetHeight),
            display: true
        )
    }

    private func expandedBinding(for id: String) -> Binding<Bool> {
        Binding(
            get: { expandedProviders.contains(id) },
            set: { isExpanded in
                if isExpanded {
                    expandedProviders.insert(id)
                } else {
                    expandedProviders.remove(id)
                }
            }
        )
    }

}

// MARK: - Preference Keys

private struct ResultsContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Resize Grip

/// A draggable grip in the bottom-right corner for resizing the popup panel.
/// Uses SwiftUI DragGesture with NSEvent.mouseLocation (screen coordinates) to avoid
/// EXC_BAD_ACCESS caused by overriding mouse events on NSPanel with NSHostingView.
private struct ResizeGripView: View {
    @Environment(\.popupPanel) private var panel
    @State private var dragStartMouse: NSPoint?
    @State private var dragStartFrame: NSRect?

    var body: some View {
        Canvas { context, size in
            let lineCount = 3
            let spacing: CGFloat = 3
            let lineWidth: CGFloat = 1
            let totalSize = CGFloat(lineCount - 1) * spacing

            for i in 0..<lineCount {
                let offset = CGFloat(i) * spacing
                let start = CGPoint(x: size.width - totalSize + offset, y: size.height)
                let end = CGPoint(x: size.width, y: size.height - totalSize + offset)
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                context.stroke(path, with: .color(.secondary.opacity(0.4)), lineWidth: lineWidth)
            }
        }
        .frame(width: 12, height: 12)
        .padding(4)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { _ in
                    let mouse = NSEvent.mouseLocation
                    if dragStartMouse == nil {
                        dragStartMouse = mouse
                        dragStartFrame = panel?.frame
                    }
                    guard let start = dragStartMouse,
                          let initial = dragStartFrame,
                          let panel else { return }

                    let deltaX = mouse.x - start.x
                    let deltaY = mouse.y - start.y

                    let newW = min(max(initial.width + deltaX, panel.minSize.width), panel.maxSize.width)
                    let newH = min(max(initial.height - deltaY, panel.minSize.height), panel.maxSize.height)

                    // Keep top-left corner fixed
                    let newY = initial.maxY - newH
                    panel.setFrame(
                        NSRect(x: initial.origin.x, y: newY, width: newW, height: newH),
                        display: true
                    )
                }
                .onEnded { _ in
                    if let panel {
                        Defaults[.popupDefaultWidth] = Int(panel.frame.width)
                        Defaults[.popupDefaultHeight] = Int(panel.frame.height)
                    }
                    dragStartMouse = nil
                    dragStartFrame = nil
                }
        )
        .onHover { hovering in
            if hovering {
                if #available(macOS 15.0, *) {
                    NSCursor.frameResize(position: .bottomRight, directions: .all).set()
                } else {
                    NSCursor.crosshair.set()
                }
            } else {
                NSCursor.arrow.set()
            }
        }
        .background { InteractiveMarker() }
    }
}

// MARK: - Draggable Divider

/// A horizontal divider between the source input and translation results that can be
/// dragged vertically to resize the input area.
private struct DraggableDividerView: View {
    @Binding var inputHeight: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let horizontalPadding: CGFloat
    let onDragEnd: () -> Void

    @State private var dragStartMouse: CGFloat?
    @State private var dragStartHeight: CGFloat?
    @State private var isHovering = false

    var body: some View {
        Divider()
            .padding(.horizontal, horizontalPadding)
            .frame(height: 8)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { _ in
                        let mouseY = NSEvent.mouseLocation.y
                        if dragStartMouse == nil {
                            dragStartMouse = mouseY
                            dragStartHeight = inputHeight
                        }
                        guard let startY = dragStartMouse, let startH = dragStartHeight else { return }
                        // Screen Y points up; dragging down decreases mouseY but should increase inputHeight
                        let delta = startY - mouseY
                        let newHeight = startH + delta
                        inputHeight = min(max(newHeight, minHeight), maxHeight)
                    }
                    .onEnded { _ in
                        dragStartMouse = nil
                        dragStartHeight = nil
                        onDragEnd()
                    }
            )
            .onHover { hovering in
                isHovering = hovering
                if hovering {
                    NSCursor.resizeUpDown.push()
                } else {
                    NSCursor.pop()
                }
            }
            .onDisappear {
                if isHovering {
                    NSCursor.pop()
                }
            }
            .background { InteractiveMarker() }
    }
}

// MARK: - Interactive Marker

/// NSView marker placed as `.background()` on SwiftUI gesture views.
/// `PopupPanel.sendEvent` checks for this marker to prevent window dragging
/// over areas that handle their own drag gestures (divider, resize grip).
final class InteractiveMarkerView: NSView {
    override var mouseDownCanMoveWindow: Bool { false }
}

struct InteractiveMarker: NSViewRepresentable {
    func makeNSView(context: Context) -> InteractiveMarkerView { InteractiveMarkerView() }
    func updateNSView(_: InteractiveMarkerView, context: Context) {}
}
