import AppKit

func drawIcon(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let context = NSGraphicsContext.current!.cgContext
    context.scaleBy(x: size / 1024, y: size / 1024)

    func roundedRect(_ rect: CGRect, _ radius: CGFloat) -> NSBezierPath {
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    }
    func color(_ hex: Int, _ alpha: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: CGFloat(hex >> 16 & 0xFF) / 255, green: CGFloat(hex >> 8 & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
    }

    let body = roundedRect(CGRect(x: 100, y: 100, width: 824, height: 824), 185)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = .black.withAlphaComponent(0.3)
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.shadowBlurRadius = 24
    shadow.set()
    color(0x4F46E5).setFill()
    body.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: color(0x8B5CF6), ending: color(0x4338CA))!.draw(in: body, angle: -90)

    let window = CGRect(x: 230, y: 330, width: 594, height: 430)
    color(0xF8F7FF).setFill()
    roundedRect(window, 44).fill()
    color(0xE0E7FF).setFill()
    roundedRect(CGRect(x: window.minX, y: window.maxY - 70, width: window.width, height: 70), 44).fill()
    color(0xF8F7FF).setFill()
    NSBezierPath(rect: CGRect(x: window.minX, y: window.maxY - 70, width: window.width, height: 30)).fill()
    for (index, hex) in [0xF87171, 0xFBBF24, 0x34D399].enumerated() {
        color(hex).setFill()
        NSBezierPath(ovalIn: CGRect(x: window.minX + 32 + CGFloat(index) * 44, y: window.maxY - 50, width: 28, height: 28)).fill()
    }

    color(0xFF3B30).setFill()
    NSBezierPath(ovalIn: CGRect(x: 610, y: 450, width: 130, height: 130)).fill()

    let bubble = CGRect(x: 160, y: 160, width: 320, height: 320)
    color(0xFFFFFF).setFill()
    roundedRect(bubble, 80).fill()
    let bubbleInner = bubble.insetBy(dx: 18, dy: 18)
    NSGradient(starting: color(0x312E81), ending: color(0x1E1B4B))!.draw(in: roundedRect(bubbleInner, 64), angle: -90)
    NSGraphicsContext.saveGraphicsState()
    roundedRect(bubbleInner, 64).addClip()
    color(0xC4B5FD).setFill()
    NSBezierPath(ovalIn: CGRect(x: bubble.midX - 58, y: bubble.midY - 10, width: 116, height: 116)).fill()
    NSBezierPath(ovalIn: CGRect(x: bubble.midX - 120, y: bubble.minY - 70, width: 240, height: 200)).fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.current = nil
    return rep
}

let iconset = URL(filePath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        let png = drawIcon(size: CGFloat(points * scale)).representation(using: .png, properties: [:])!
        try png.write(to: iconset.appending(path: name))
    }
}
