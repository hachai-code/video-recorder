import AppKit
import AVFoundation
import SwiftUI

private func makeOverlayPanel(frame: NSRect) -> NSPanel {
    let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.level = .floating
    panel.isOpaque = false
    panel.backgroundColor = .clear
    panel.isReleasedWhenClosed = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    return panel
}

/// The on-screen camera preview, so you can see yourself while recording.
@MainActor
final class BubbleWindow {
    private var panel: NSPanel?

    func show(session: AVCaptureSession, options: RecordingOptions) {
        guard let screen = NSScreen.main else { return }
        let side = options.size.screenPoints
        let panel = makeOverlayPanel(frame: bubbleRect(side: side, corner: options.corner, in: screen.visibleFrame, margin: 24))
        panel.hasShadow = true

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.connection?.automaticallyAdjustsVideoMirroring = false
        preview.connection?.isVideoMirrored = true

        let view = NSView()
        view.layer = preview
        view.wantsLayer = true
        preview.cornerRadius = side * 0.22
        preview.masksToBounds = true
        panel.contentView = view
        panel.orderFrontRegardless()
        self.panel = panel
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}

@MainActor
func runCountdown(from start: Int = 3) async {
    guard let screen = NSScreen.main else { return }
    let side: CGFloat = 160
    let panel = makeOverlayPanel(frame: NSRect(x: screen.frame.midX - side / 2, y: screen.frame.midY - side / 2, width: side, height: side))
    panel.ignoresMouseEvents = true
    for number in stride(from: start, to: 0, by: -1) {
        panel.contentView = NSHostingView(rootView: Text("\(number)")
            .font(.system(size: 96, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: side, height: side)
            .background(.black.opacity(0.6), in: .rect(cornerRadius: 32)))
        panel.orderFrontRegardless()
        try? await Task.sleep(for: .seconds(1))
    }
    panel.orderOut(nil)
}
