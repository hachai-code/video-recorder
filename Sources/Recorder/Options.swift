import Foundation
import CoreGraphics

enum Corner: String, CaseIterable {
    case topLeft = "Top Left", topRight = "Top Right", bottomLeft = "Bottom Left", bottomRight = "Bottom Right"
}

enum BubbleSize: String, CaseIterable {
    case small = "Small", medium = "Medium", large = "Large"

    var screenPoints: CGFloat {
        switch self {
        case .small: 140
        case .medium: 200
        case .large: 280
        }
    }

    var videoFraction: CGFloat {
        switch self {
        case .small: 0.2
        case .medium: 0.28
        case .large: 0.38
        }
    }
}

struct RecordingOptions {
    var camera = true
    var microphone = true
    var appAudio = false
    var corner = Corner.bottomLeft
    var size = BubbleSize.medium
}

struct RecorderError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { errorDescription = message }
}

/// Bottom-left origin, matching both AppKit screen coordinates and Core Image.
func bubbleRect(side: CGFloat, corner: Corner, in bounds: CGRect, margin: CGFloat) -> CGRect {
    let left = corner == .topLeft || corner == .bottomLeft
    let bottom = corner == .bottomLeft || corner == .bottomRight
    return CGRect(
        x: left ? bounds.minX + margin : bounds.maxX - margin - side,
        y: bottom ? bounds.minY + margin : bounds.maxY - margin - side,
        width: side,
        height: side
    )
}

func fittedVideoSize(_ size: CGSize, within limit: CGSize = CGSize(width: 1920, height: 1080)) -> CGSize {
    let scale = min(1, limit.width / size.width, limit.height / size.height)
    func even(_ value: CGFloat) -> CGFloat { CGFloat(Int((value * scale).rounded()) / 2 * 2) }
    return CGSize(width: even(size.width), height: even(size.height))
}
