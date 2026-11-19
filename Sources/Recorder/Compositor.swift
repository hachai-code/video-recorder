import CoreImage
import CoreImage.CIFilterBuiltins

struct Compositor {
    let size: CGSize
    private let bubble: CGRect?
    private let mask: CIImage?
    private let background: CIImage
    private let context = CIContext()
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    init(size: CGSize, options: RecordingOptions) {
        self.size = size
        background = CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: size))
        guard options.camera else {
            bubble = nil
            mask = nil
            return
        }
        let side = (min(size.width, size.height) * options.size.videoFraction).rounded()
        let rect = bubbleRect(side: side, corner: options.corner, in: CGRect(origin: .zero, size: size), margin: (side * 0.12).rounded())
        let generator = CIFilter.roundedRectangleGenerator()
        generator.extent = rect
        generator.radius = Float(side * 0.22)
        generator.color = .white
        bubble = rect
        mask = generator.outputImage
    }

    func render(screen: CIImage, camera: CIImage?, to buffer: CVPixelBuffer) {
        var image = screen.composited(over: background)
        if let camera, let bubble, let mask {
            image = mirroredSquare(camera, in: bubble).applyingFilter("CIBlendWithMask", parameters: [
                kCIInputBackgroundImageKey: image,
                kCIInputMaskImageKey: mask,
            ])
        }
        context.render(image, to: buffer, bounds: CGRect(origin: .zero, size: size), colorSpace: colorSpace)
    }

    /// Center-crops the camera to a square, mirrors it like a selfie view, and scales it into `rect`.
    private func mirroredSquare(_ camera: CIImage, in rect: CGRect) -> CIImage {
        let extent = camera.extent
        let side = min(extent.width, extent.height)
        let square = camera.cropped(to: CGRect(x: extent.midX - side / 2, y: extent.midY - side / 2, width: side, height: side))
        let scale = rect.width / side
        return square
            .transformed(by: CGAffineTransform(translationX: -square.extent.minX, y: -square.extent.minY))
            .transformed(by: CGAffineTransform(a: -scale, b: 0, c: 0, d: scale, tx: rect.maxX, ty: rect.minY))
            .cropped(to: rect)
    }
}
