import AVFoundation

func newRecordingURL() throws -> URL {
    let folder = URL.moviesDirectory.appending(path: "Recordings", directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd 'at' HH.mm.ss"
    return folder.appending(path: "Recording \(formatter.string(from: .now)).mp4")
}

/// Not thread-safe; call everything after `start()` from one serial queue.
final class MovieWriter {
    private let url: URL
    private let writer: AVAssetWriter
    private let video: AVAssetWriterInput
    private let adaptor: AVAssetWriterInputPixelBufferAdaptor
    private let microphone: AVAssetWriterInput?
    private let appAudio: AVAssetWriterInput?
    private var startTime: CMTime?
    private var lastVideoTime = CMTime.negativeInfinity
    private var finished = false

    init(url: URL, size: CGSize, microphone: Bool, appAudio: Bool) throws {
        self.url = url
        writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        writer.movieFragmentInterval = CMTime(seconds: 2, preferredTimescale: 600)
        video = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAllowFrameReorderingKey: false,
                AVVideoAverageBitRateKey: Int(size.width * size.height) * 4,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC,
                AVVideoMaxKeyFrameIntervalDurationKey: 2,
            ],
            AVVideoColorPropertiesKey: [
                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
            ],
        ])
        video.expectsMediaDataInRealTime = true
        adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
        ])
        self.microphone = microphone ? Self.audioInput(channels: 1) : nil
        self.appAudio = appAudio ? Self.audioInput(channels: 2) : nil
        for input in [video, self.microphone, self.appAudio].compactMap({ $0 }) {
            writer.add(input)
        }
    }

    private static func audioInput(channels: Int) -> AVAssetWriterInput {
        let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: channels,
            AVEncoderBitRateKey: 128_000,
        ])
        input.expectsMediaDataInRealTime = true
        return input
    }

    func start() throws {
        guard writer.startWriting() else { throw writer.error ?? RecorderError("Couldn't start writing the recording.") }
    }

    func appendVideo(at time: CMTime, render: (CVPixelBuffer) -> Void) {
        guard !finished, time > lastVideoTime, video.isReadyForMoreMediaData, let pool = adaptor.pixelBufferPool else { return }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        guard let buffer else { return }
        if startTime == nil {
            writer.startSession(atSourceTime: time)
            startTime = time
        }
        render(buffer)
        adaptor.append(buffer, withPresentationTime: time)
        lastVideoTime = time
    }

    func appendMicrophone(_ sampleBuffer: CMSampleBuffer) { append(sampleBuffer, to: microphone) }
    func appendAppAudio(_ sampleBuffer: CMSampleBuffer) { append(sampleBuffer, to: appAudio) }

    private func append(_ sampleBuffer: CMSampleBuffer, to input: AVAssetWriterInput?) {
        guard !finished, let input, let startTime, sampleBuffer.presentationTimeStamp >= startTime, input.isReadyForMoreMediaData else { return }
        input.append(sampleBuffer)
    }

    func finish(completion: @escaping (Result<URL, Error>) -> Void) {
        finished = true
        guard startTime != nil else {
            writer.cancelWriting()
            return completion(.failure(RecorderError("Nothing was recorded.")))
        }
        writer.finishWriting { [writer, url] in
            completion(writer.status == .completed ? .success(url) : .failure(writer.error ?? RecorderError("Recording failed.")))
        }
    }

    func cancel() {
        finished = true
        writer.cancelWriting()
    }
}
