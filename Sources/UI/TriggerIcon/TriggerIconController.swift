import AppKit
import Defaults

// MARK: - TriggerTrackingView

/// A circular icon view with mouse tracking for hover and click detection.
/// Used when no user-defined actions exist — keeps the original single-button UX.
@MainActor
final class TriggerTrackingView: NSView {
    var onMouseEntered: (() -> Void)?
    var onMouseExited: (() -> Void)?
    var onMouseDown: (() -> Void)?

    private var trackingArea: NSTrackingArea?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let rect = bounds.insetBy(dx: 1, dy: 1)

        // Circle background
        ctx.setFillColor(NSColor.controlBackgroundColor.cgColor)
        ctx.fillEllipse(in: rect)

        // Border
        ctx.setStrokeColor(NSColor.separatorColor.cgColor)
        ctx.setLineWidth(0.5)
        ctx.strokeEllipse(in: rect)

        // SF Symbol icon
        let sizeConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let colorConfig = NSImage.SymbolConfiguration(hierarchicalColor: .labelColor)
        if let image = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "Translate")?
            .withSymbolConfiguration(sizeConfig.applying(colorConfig))
        {
            let imageSize = image.size
            let imageRect = NSRect(
                x: (bounds.width - imageSize.width) / 2,
                y: (bounds.height - imageSize.height) / 2,
                width: imageSize.width,
                height: imageSize.height
            )
            image.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        onMouseEntered?()
    }

    override func mouseExited(with event: NSEvent) {
        onMouseExited?()
    }

    override func mouseDown(with event: NSEvent) {
        onMouseDown?()
    }
}

// MARK: - ActionBarCell

/// A single cell inside the action bar — either the Translate icon or an action label.
@MainActor
final class ActionBarCell: NSView {
    enum Kind {
        case translate
        case action(UserDefinedAction)
    }

    let kind: Kind
    var onClick: (() -> Void)?

    private var isHovered = false
    private var trackingArea: NSTrackingArea?

    private static let font = NSFont.systemFont(ofSize: 12, weight: .medium)
    private static let translateCellWidth: CGFloat = 36
    private static let actionCellMinWidth: CGFloat = 44
    private static let actionCellHorizontalPadding: CGFloat = 10
    private static let actionCellMaxWidth: CGFloat = 140

    init(kind: Kind) {
        self.kind = kind
        super.init(frame: .zero)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    var intrinsicWidth: CGFloat {
        switch kind {
        case .translate:
            return Self.translateCellWidth
        case let .action(action):
            let textSize = (action.name as NSString).size(withAttributes: [.font: Self.font])
            return min(
                Self.actionCellMaxWidth,
                max(Self.actionCellMinWidth, ceil(textSize.width) + Self.actionCellHorizontalPadding * 2)
            )
        }
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        if isHovered {
            ctx.setFillColor(NSColor.labelColor.withAlphaComponent(0.08).cgColor)
            ctx.fill(bounds)
        }

        switch kind {
        case .translate:
            let sizeConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            let colorConfig = NSImage.SymbolConfiguration(hierarchicalColor: .labelColor)
            if let image = NSImage(systemSymbolName: "character.bubble", accessibilityDescription: "Translate")?
                .withSymbolConfiguration(sizeConfig.applying(colorConfig))
            {
                let imageSize = image.size
                let imageRect = NSRect(
                    x: (bounds.width - imageSize.width) / 2,
                    y: (bounds.height - imageSize.height) / 2,
                    width: imageSize.width,
                    height: imageSize.height
                )
                image.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1.0)
            }

        case let .action(action):
            let attrs: [NSAttributedString.Key: Any] = [
                .font: Self.font,
                .foregroundColor: NSColor.labelColor,
            ]
            let nsString = action.name as NSString
            let textSize = nsString.size(withAttributes: attrs)
            let maxTextWidth = bounds.width - Self.actionCellHorizontalPadding * 2
            // Clip if the label overflows the max cell width.
            let clipWidth = min(textSize.width, maxTextWidth)
            let textRect = NSRect(
                x: (bounds.width - clipWidth) / 2,
                y: (bounds.height - textSize.height) / 2,
                width: clipWidth,
                height: textSize.height
            )
            nsString.draw(in: textRect, withAttributes: attrs)
        }
    }

    override func mouseEntered(with _: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with _: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    override func mouseDown(with _: NSEvent) {
        onClick?()
    }
}

// MARK: - ActionBarView

/// A horizontal bar containing the Translate button and one button per user-defined action.
@MainActor
final class ActionBarView: NSView {
    var onTranslate: (() -> Void)?
    var onAction: ((UserDefinedAction) -> Void)?

    static let height: CGFloat = 32

    private(set) var cells: [ActionBarCell] = []

    init(actions: [UserDefinedAction]) {
        super.init(frame: .zero)
        wantsLayer = true
        buildCells(actions: actions)
        frame = NSRect(origin: .zero, size: intrinsicBarSize)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    var intrinsicBarSize: NSSize {
        let totalWidth = cells.reduce(0) { $0 + $1.intrinsicWidth }
        return NSSize(width: totalWidth, height: Self.height)
    }

    private func buildCells(actions: [UserDefinedAction]) {
        let translateCell = ActionBarCell(kind: .translate)
        translateCell.onClick = { [weak self] in self?.onTranslate?() }
        addSubview(translateCell)
        cells.append(translateCell)

        for action in actions {
            let cell = ActionBarCell(kind: .action(action))
            cell.onClick = { [weak self] in self?.onAction?(action) }
            addSubview(cell)
            cells.append(cell)
        }
    }

    override func layout() {
        super.layout()
        var x: CGFloat = 0
        for cell in cells {
            let width = cell.intrinsicWidth
            cell.frame = NSRect(x: x, y: 0, width: width, height: bounds.height)
            x += width
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let path = NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8)

        ctx.setFillColor(NSColor.controlBackgroundColor.cgColor)
        path.fill()

        ctx.setStrokeColor(NSColor.separatorColor.cgColor)
        ctx.setLineWidth(0.5)
        path.stroke()

        // Separators between cells
        var x: CGFloat = 0
        for i in 0..<cells.count {
            x += cells[i].intrinsicWidth
            if i < cells.count - 1 {
                ctx.setStrokeColor(NSColor.separatorColor.withAlphaComponent(0.5).cgColor)
                ctx.setLineWidth(0.5)
                ctx.move(to: CGPoint(x: x, y: 4))
                ctx.addLine(to: CGPoint(x: x, y: bounds.height - 4))
                ctx.strokePath()
            }
        }
    }
}

// MARK: - TriggerIconController

/// Manages the trigger icon lifecycle: show near cursor, hover/click to translate, auto-dismiss.
/// When user-defined actions exist, renders a horizontal bar instead of a single circle.
@MainActor
final class TriggerIconController {
    var onTranslateRequested: ((String) -> Void)?
    var onActionRequested: ((String, UserDefinedAction) -> Void)?
    var onDismissed: (() -> Void)?

    private var panel: TriggerIconPanel?
    private var contentView: NSView?
    private var currentText: String = ""
    private var hoverTimer: Timer?
    private var autoDismissTimer: Timer?

    /// Show the trigger icon near the given screen point.
    /// If already visible, silently replace without triggering suppress.
    func show(text: String, near point: CGPoint) {
        // Silently close any existing icon (no dismiss callback)
        dismissSilently()

        currentText = text

        let panel = TriggerIconPanel()
        let actions = Defaults[.userDefinedActions]
        let view: NSView
        let size: NSSize

        if actions.isEmpty {
            let tracking = TriggerTrackingView(
                frame: NSRect(x: 0, y: 0, width: TriggerIconPanel.size, height: TriggerIconPanel.size)
            )
            tracking.onMouseEntered = { [weak self] in
                self?.startHoverTimer()
            }
            tracking.onMouseExited = { [weak self] in
                self?.cancelHoverTimer()
            }
            tracking.onMouseDown = { [weak self] in
                self?.triggerTranslation()
            }
            view = tracking
            size = NSSize(width: TriggerIconPanel.size, height: TriggerIconPanel.size)
        } else {
            let bar = ActionBarView(actions: actions)
            bar.onTranslate = { [weak self] in
                self?.triggerTranslation()
            }
            bar.onAction = { [weak self] action in
                self?.triggerAction(action)
            }
            view = bar
            size = bar.intrinsicBarSize
        }

        panel.contentView = view

        // Position: offset to the right and below the cursor
        let offset: CGFloat = 8
        var x = point.x + offset
        var y = point.y - offset - size.height

        // Adjust for screen bounds
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) ?? NSScreen.main {
            let visibleFrame = screen.visibleFrame
            if x + size.width > visibleFrame.maxX { x = point.x - size.width - offset }
            if y + size.height > visibleFrame.maxY { y = point.y - size.height - offset }
            if x < visibleFrame.minX { x = visibleFrame.minX }
            if y < visibleFrame.minY { y = visibleFrame.minY }
        }

        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        panel.alphaValue = 0
        panel.orderFront(nil)

        // Fade in
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 1
        }

        self.panel = panel
        self.contentView = view

        startAutoDismissTimer()
    }

    /// Dismiss the icon with fade-out and notify via onDismissed.
    func dismiss() {
        guard let panel else { return }
        cancelAllTimers()

        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                panel.contentView = nil
                panel.close()
                self?.cleanup()
                self?.onDismissed?()
            }
        })
    }

    /// Dismiss silently — used when replacing with a new icon. Does NOT trigger onDismissed.
    func dismissSilently() {
        guard let panel else { return }
        cancelAllTimers()
        panel.contentView = nil
        panel.close()
        cleanup()
    }

    private func cleanup() {
        panel = nil
        contentView = nil
        currentText = ""
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    // MARK: - Timers

    private func startHoverTimer() {
        cancelHoverTimer()
        cancelAutoDismissTimer()
        hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.triggerTranslation()
            }
        }
    }

    private func cancelHoverTimer() {
        hoverTimer?.invalidate()
        hoverTimer = nil
    }

    private func startAutoDismissTimer() {
        cancelAutoDismissTimer()
        autoDismissTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.dismiss()
            }
        }
    }

    private func cancelAutoDismissTimer() {
        autoDismissTimer?.invalidate()
        autoDismissTimer = nil
    }

    private func cancelAllTimers() {
        cancelHoverTimer()
        cancelAutoDismissTimer()
    }

    private func triggerTranslation() {
        let text = currentText
        cancelAllTimers()

        guard let panel else { return }
        // Immediately hide the icon
        panel.contentView = nil
        panel.close()
        cleanup()

        onTranslateRequested?(text)
    }

    private func triggerAction(_ action: UserDefinedAction) {
        let text = currentText
        cancelAllTimers()

        guard let panel else { return }
        panel.contentView = nil
        panel.close()
        cleanup()

        onActionRequested?(text, action)
    }
}
