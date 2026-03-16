import AppKit
import SwiftUI

// MARK: - OverlayWindowController

@MainActor
final class OverlayWindowController: NSObject {
    static let shared = OverlayWindowController()

    private var panel: NSPanel?
    private var vm: SparkyViewModel?

    func configure(vm: SparkyViewModel) {
        self.vm = vm
    }

    func show() {
        guard let vm else { return }
        if panel == nil { buildPanel(vm: vm) }
        panel?.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func toggle() {
        guard let p = panel else { show(); return }
        if p.isVisible { hide() } else { show() }
    }

    /// Move the underlying window by the given translation (used after a drag gesture).
    func translate(by size: CGSize) {
        guard let p = panel else { return }
        var origin = p.frame.origin
        origin.x += size.width
        origin.y -= size.height  // AppKit y-axis is inverted
        p.setFrameOrigin(origin)
    }

    // MARK: - Private

    private func buildPanel(vm: SparkyViewModel) {
        let w = AppTheme.overlayWidth
        let h = AppTheme.overlayHeight

        // Position: bottom-right, 20px margins
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let visibleRect = screen.visibleFrame
        let origin = NSPoint(
            x: visibleRect.maxX - w - 20,
            y: visibleRect.minY + 20
        )

        let p = NSPanel(
            contentRect: NSRect(origin: origin, size: CGSize(width: w, height: h)),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.isFloatingPanel    = true
        p.level              = .floating
        p.isOpaque           = false
        p.backgroundColor    = .clear
        p.hasShadow          = false
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let rootView = OverlayView(vm: vm)
        let host = NSHostingView(rootView: rootView)
        host.frame = NSRect(origin: .zero, size: CGSize(width: w, height: h))
        p.contentView = host

        panel = p
    }
}
