import ScreenCaptureKit
import CoreImage

let captureQueue = DispatchQueue(label: "recorder.capture", qos: .userInteractive)

/// Everything after `start()` runs on `captureQueue`.
final class RecordingSession: NSObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    var onUnexpectedStop: (() -> Void)?

    private let options: RecordingOptions
    private let writer: MovieWriter
    private let compositor: Compositor
    private var stream: SCStream!
    private var latestScreen: CIImage?
    private var latestCamera: CIImage?

    init(filter: SCContentFilter, options: RecordingOptions, url: URL) throws {
        let scale = CGFloat(filter.pointPixelScale)
        let size = fittedVideoSize(CGSize(width: filter.contentRect.width * scale, height: filter.contentRect.height * scale))
        self.options = options
        writer = try MovieWriter(url: url, size: size, microphone: options.microphone, appAudio: options.appAudio)
        compositor = Compositor(size: size, options: options)
        super.init()

        let configuration = SCStreamConfiguration()
        configuration.width = Int(size.width)
        configuration.height = Int(size.height)
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = true
        configuration.capturesAudio = options.appAudio
        configuration.sampleRate = 48_000
        configuration.channelCount = 2
        configuration.excludesCurrentProcessAudio = true
        configuration.captureMicrophone = options.microphone

        stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: captureQueue)
        if options.appAudio { try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: captureQueue) }
        if options.microphone { try stream.addStreamOutput(self, type: .microphone, sampleHandlerQueue: captureQueue) }
    }

    func start() async throws {
        try writer.start()
        do {
            try await stream.startCapture()
        } catch {
            writer.cancel()
            throw error
        }
    }

    func stop() async -> Result<URL, Error> {
        // ponytail: throws if the stream already died (window closed); the writer result is what gets reported.
        try? await stream.stopCapture()
        return await withCheckedContinuation { continuation in
            captureQueue.async { self.writer.finish { continuation.resume(returning: $0) } }
        }
    }

    func cameraFrame(_ sampleBuffer: CMSampleBuffer) {
        guard let pixels = sampleBuffer.imageBuffer else { return }
        latestCamera = CIImage(cvPixelBuffer: pixels)
        writeFrame(at: sampleBuffer.presentationTimeStamp)
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        switch type {
        case .screen:
            guard isCompleteFrame(sampleBuffer), let pixels = sampleBuffer.imageBuffer else { return }
            latestScreen = CIImage(cvPixelBuffer: pixels)
            if !options.camera { writeFrame(at: sampleBuffer.presentationTimeStamp) }
        case .audio:
            writer.appendAppAudio(sampleBuffer)
        case .microphone:
            writer.appendMicrophone(sampleBuffer)
        @unknown default:
            break
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        onUnexpectedStop?()
    }

    private func writeFrame(at time: CMTime) {
        guard let screen = latestScreen else { return }
        let camera = latestCamera
        writer.appendVideo(at: time) { compositor.render(screen: screen, camera: camera, to: $0) }
    }

    private func isCompleteFrame(_ sampleBuffer: CMSampleBuffer) -> Bool {
        guard let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let rawStatus = attachments.first?[.status] as? Int
        else { return false }
        return SCFrameStatus(rawValue: rawStatus) == .complete
    }
}
