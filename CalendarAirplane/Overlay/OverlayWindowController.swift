import AppKit
import SwiftUI

@MainActor
final class OverlayWindowController {
    static let shared = OverlayWindowController()

    private var panel: NSPanel?
    private var hostingView: NSHostingView<AirplaneBannerView>?

    private init() {}

    func playFlight(
        meetingTitle: String,
        subtitle: String? = nil,
        timeRange: String? = nil,
        completion: @escaping () -> Void
    ) {
        guard let screen = NSScreen.main else {
            completion()
            return
        }

        let height: CGFloat = 140
        let frame = NSRect(
            x: screen.frame.minX,
            y: screen.frame.maxY - height - 80,
            width: screen.frame.width,
            height: height
        )

        let panel = self.panel ?? makePanel(frame: frame)
        panel.setFrame(frame, display: true)
        self.panel = panel

        let view = AirplaneBannerView(meetingTitle: meetingTitle, subtitle: subtitle, timeRange: timeRange) {
            panel.orderOut(nil)
            completion()
        }
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: frame.size)
        panel.contentView = hosting
        hostingView = hosting

        panel.orderFrontRegardless()
    }

    private func makePanel(frame: NSRect) -> NSPanel {
        let panel = NSPanel(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        return panel
    }
}
