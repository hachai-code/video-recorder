import Testing
import AVFoundation
@testable import Recorder

/// Writes `minutes` of media through MovieWriter as fast as the encoder allows, with camera-like
/// timestamp jitter on the host clock, interleaved microphone audio and per-frame noise.
private func record(minutes: Int, size: CGSize, microphone: Bool = true) async throws -> (Result<URL, Error>, URL) {
    let url = FileManager.default.temporaryDirectory.appending(path: "long-\(UUID()).mp4")
    let writer = try MovieWriter(url: url, size: size, microphone: microphone, appAudio: false)
    try writer.start()

    let noise = (0..<(Int(size.width * size.height) * 8)).map { _ in UInt8.random(in: 0...255) }
    let base = CMClockGetTime(CMClockGetHostTimeClock()).convertScale(1_000_000_000, method: .default).value
    let audioFormat = try silentMonoFormat()
    var audioTime: Int64 = 0
    let audioStep: Int64 = 1024 * 1_000_000_000 / 48_000

    for frame in 0..<Int64(minutes * 60 * 30) {
        let videoTime = frame * 33_333_333 + Int64.random(in: -2_000_000...2_000_000)
        writer.appendVideo(at: CMTime(value: base + videoTime, timescale: 1_000_000_000)) { buffer in
            CVPixelBufferLockBaseAddress(buffer, [])
            let length = CVPixelBufferGetDataSize(buffer)
            noise.withUnsafeBytes { bytes in
                CVPixelBufferGetBaseAddress(buffer)!.copyMemory(from: bytes.baseAddress! + Int.random(in: 0..<(noise.count - length)), byteCount: length)
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
        }
        while microphone, audioTime <= videoTime {
            writer.appendMicrophone(try silentAudio(format: audioFormat, at: CMTime(value: base + audioTime, timescale: 1_000_000_000)))
            audioTime += audioStep
        }
        try await Task.sleep(for: .microseconds(300))
    }
    let result = await withCheckedContinuation { continuation in writer.finish { continuation.resume(returning: $0) } }
    return (result, url)
}

private func silentMonoFormat() throws -> CMAudioFormatDescription {
    var description = AudioStreamBasicDescription(mSampleRate: 48_000, mFormatID: kAudioFormatLinearPCM,
                                                  mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked,
                                                  mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4,
                                                  mChannelsPerFrame: 1, mBitsPerChannel: 32, mReserved: 0)
    var format: CMAudioFormatDescription?
    CMAudioFormatDescriptionCreate(allocator: nil, asbd: &description, layoutSize: 0, layout: nil, magicCookieSize: 0,
                                   magicCookie: nil, extensions: nil, formatDescriptionOut: &format)
    return try #require(format)
}

private func silentAudio(format: CMAudioFormatDescription, at time: CMTime) throws -> CMSampleBuffer {
    let length = 1024 * 4
    var block: CMBlockBuffer?
    CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: length, blockAllocator: nil,
                                       customBlockSource: nil, offsetToData: 0, dataLength: length,
                                       flags: kCMBlockBufferAssureMemoryNowFlag, blockBufferOut: &block)
    let dataBuffer = try #require(block)
    CMBlockBufferFillDataBytes(with: 0, blockBuffer: dataBuffer, offsetIntoDestination: 0, dataLength: length)
    var sample: CMSampleBuffer?
    CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: nil, dataBuffer: dataBuffer, formatDescription: format,
                                                         sampleCount: 1024, presentationTimeStamp: time,
                                                         packetDescriptions: nil, sampleBufferOut: &sample)
    return try #require(sample)
}

private func expectPlayable(_ result: Result<URL, Error>, url: URL, minutes: Int) async throws {
    if case .failure(let error) = result { Issue.record("\(error)") }
    let duration = try await AVURLAsset(url: url).load(.duration)
    #expect(duration.seconds > Double(minutes * 60) - 2)
}

@Test func jitteryTimestampsDontBreakFragments() async throws {
    for _ in 0..<4 {
        let (result, url) = try await record(minutes: 2, size: CGSize(width: 64, height: 64), microphone: false)
        defer { try? FileManager.default.removeItem(at: url) }
        try await expectPlayable(result, url: url, minutes: 2)
    }
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["LONG_TESTS"] != nil))
func hourLongRecordingPastFourGigabytes() async throws {
    let (result, url) = try await record(minutes: 60, size: CGSize(width: 2560, height: 1440))
    defer { try? FileManager.default.removeItem(at: url) }
    let bytes = try #require(try FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int)
    print("60-minute file: \(bytes / 1_000_000) MB")
    #expect(bytes > 4_294_967_296)
    try await expectPlayable(result, url: url, minutes: 60)
}
