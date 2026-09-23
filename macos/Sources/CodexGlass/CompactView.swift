import AppKit
import QuartzCore
import CodexGlassCore

@MainActor
final class CompactView: NSView {
    private weak var controller: AppCoordinator?
    private var tracking: NSTrackingArea?
    private let captions = CALayer()
    private let percentage = CATextLayer()
    private let period = CATextLayer()
    private var revealed = false
    private var mouseDownPoint: NSPoint?
    private var windowDownOrigin: NSPoint?
    private var dragged = false
    private let logo = LogoPath.make()

    init(controller: AppCoordinator) {
        self.controller = controller
        super.init(frame: NSRect(x: 0, y: 0, width: 92, height: 126))
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        captions.frame = bounds
        captions.opacity = 0
        captions.masksToBounds = true
        for text in [percentage, period] {
            text.alignmentMode = .center
            text.truncationMode = .end
            text.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
            captions.addSublayer(text)
        }
        percentage.frame = NSRect(x: 0, y: 80, width: 92, height: 28)
        period.frame = NSRect(x: 0, y: 108, width: 92, height: 15)
        layer?.addSublayer(captions)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        update()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var isOpaque: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        update()
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        if let tracking { addTrackingArea(tracking) }
        window?.acceptsMouseMovedEvents = true
    }

    override func resetCursorRects() { addCursorRect(NSRect(x: 8, y: 4, width: 76, height: 76), cursor: .openHand) }

    private func circleContains(_ point: NSPoint) -> Bool { hypot(point.x - 46, point.y - 42) <= 38 }

    override func hitTest(_ point: NSPoint) -> NSView? {
        circleContains(convert(point, from: superview)) ? self : nil
    }

    func update() {
        guard let controller else { return }
        let quota = controller.selected
        let value = quota.map { "\(Int(floor($0.remaining)))%" } ?? "—"
        let label = (controller.store.status == "stale" ? "◷ " : "") + Copy.period(quota, controller.language)
        let outline = NSColor(glassHex: "#243247")
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        percentage.string = NSAttributedString(string: value, attributes: [.font: NSFont.systemFont(ofSize: 23, weight: .semibold), .foregroundColor: NSColor.white, .strokeColor: outline, .strokeWidth: -4])
        period.string = NSAttributedString(string: label, attributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: NSColor.white, .strokeColor: outline, .strokeWidth: -4])
        for text in [percentage, period] { text.contentsScale = window?.backingScaleFactor ?? 2 }
        CATransaction.commit()
        let accessible = "Codex Glass, \(value) \(label)"
        setAccessibilityLabel(accessible)
        setAccessibilityHelp(controller.t("ringHelp"))
        toolTip = quota.map { Copy.countdown($0, now: controller.now, language: controller.language) } ?? controller.t("compactEmpty")
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext, let controller else { return }
        context.clear(bounds)
        let center = CGPoint(x: 46, y: 42)
        context.setFillColor(NSColor(glassHex: "#243950").cgColor)
        context.fillEllipse(in: CGRect(x: center.x - 27.5, y: center.y - 27.5, width: 55, height: 55))
        context.setStrokeColor(NSColor(glassHex: "#57687A").withAlphaComponent(82.0 / 255).cgColor)
        context.setLineWidth(5)
        context.strokeEllipse(in: CGRect(x: center.x - 30, y: center.y - 30, width: 60, height: 60))
        if let selected = controller.selected {
            let color = controller.store.status == "stale" ? NSColor(glassHex: "#98A5B6") :
                selected.remaining <= 10 ? NSColor(glassHex: "#EF5B58") : selected.remaining <= 25 ? NSColor(glassHex: "#F5A33C") : controller.store.settings.ringAccent
            arc(context, center: center, radius: 30, fraction: selected.remaining / 100, width: 5, color: color)
            if controller.store.settings.elapsedArc, let elapsed = UsageMath.elapsed(window: selected, now: controller.now) {
                arc(context, center: center, radius: 36, fraction: elapsed, width: 2, color: NSColor(glassHex: controller.store.settings.accentColor ?? "#4F8DF7"))
            }
        }
        context.saveGState()
        context.translateBy(x: 29, y: 25)
        context.scaleBy(x: 34 / 24, y: 34 / 24)
        context.addPath(logo)
        context.setFillColor(NSColor.white.cgColor)
        context.fillPath(using: .evenOdd)
        context.restoreGState()
    }

    private func arc(_ context: CGContext, center: CGPoint, radius: CGFloat, fraction: Double, width: CGFloat, color: NSColor) {
        guard fraction > 0 else { return }
        context.beginPath()
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        context.setLineCap(.round)
        context.addArc(center: center, radius: radius, startAngle: -.pi / 2, endAngle: -.pi / 2 + CGFloat(min(1, fraction)) * 2 * .pi, clockwise: false)
        context.strokePath()
    }

    func setRevealed(_ show: Bool, animate: Bool = true) {
        guard revealed != show || !animate else { return }
        revealed = show
        let shouldAnimate = animate && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let startOpacity = captions.presentation()?.opacity ?? captions.opacity
        let startTransform = captions.presentation()?.transform ?? captions.transform
        let endTransform = CATransform3DMakeTranslation(0, show ? 0 : -8, 0)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        captions.opacity = show ? 1 : 0
        captions.transform = endTransform
        captions.removeAllAnimations()
        if shouldAnimate {
            let opacity = CABasicAnimation(keyPath: "opacity")
            opacity.fromValue = startOpacity
            opacity.toValue = show ? 1 : 0
            let transform = CABasicAnimation(keyPath: "transform")
            transform.fromValue = NSValue(caTransform3D: startTransform)
            transform.toValue = NSValue(caTransform3D: endTransform)
            let group = CAAnimationGroup()
            group.animations = [opacity, transform]
            group.duration = show ? 0.18 : 0.14
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)
            captions.add(group, forKey: "reveal")
        }
        CATransaction.commit()
    }

    override func mouseEntered(with event: NSEvent) { mouseMoved(with: event) }
    override func mouseMoved(with event: NSEvent) { setRevealed(circleContains(convert(event.locationInWindow, from: nil))) }
    override func mouseExited(with event: NSEvent) { setRevealed(false) }
    override func mouseDown(with event: NSEvent) {
        guard circleContains(convert(event.locationInWindow, from: nil)) else { return }
        mouseDownPoint = NSEvent.mouseLocation
        windowDownOrigin = window?.frame.origin
        dragged = false
        NSCursor.closedHand.push()
    }
    override func mouseDragged(with event: NSEvent) {
        guard let start = mouseDownPoint, let origin = windowDownOrigin else { return }
        let cursor = NSEvent.mouseLocation
        let dx = cursor.x - start.x, dy = cursor.y - start.y
        if hypot(dx, dy) >= 4 { dragged = true }
        if dragged { window?.setFrameOrigin(NSPoint(x: origin.x + dx, y: origin.y + dy)) }
    }
    override func mouseUp(with event: NSEvent) {
        guard mouseDownPoint != nil else { return }
        NSCursor.pop()
        mouseDownPoint = nil
        windowDownOrigin = nil
        window?.saveFrame(usingName: controller?.demo == true ? "CodexGlassDemoMini" : "CodexGlassMini")
        if !dragged { controller?.showMain() }
    }
    override func rightMouseDown(with event: NSEvent) {
        guard let controller else { return }
        NSMenu.popUpContextMenu(controller.menu(), with: event, for: self)
    }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 36 || event.keyCode == 49 { controller?.showMain() }
        else { super.keyDown(with: event) }
    }
    override func becomeFirstResponder() -> Bool { setRevealed(true); return true }
    override func resignFirstResponder() -> Bool { setRevealed(false); return true }
    override func accessibilityPerformPress() -> Bool { controller?.showMain(); return true }
}
