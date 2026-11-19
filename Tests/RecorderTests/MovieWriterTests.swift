import Testing
import AVFoundation
@testable import Recorder

@Test func interruptedRecordingIsStillPlayable() async throws {
    let url = FileManager.default.temporaryDirectory.appending(path: "interrupted-\(UUID()).mp4")
    defer { try? FileManager.default.removeItem(at: url) }
    let writer = try MovieWriter(url: url, size: CGSize(width: 64, height: 64), microphone: false, appAudio: false)
    try writer.start()
    for frame in 0..<150 {
        writer.appendVideo(at: CMTime(value: CMTimeValue(frame), timescale: 30)) { _ in }
        try await Task.sleep(for: .milliseconds(5))
    }
    try await Task.sleep(for: .seconds(1))

    let asset = AVURLAsset(url: url)
    let duration = try await asset.load(.duration)
    #expect(duration.seconds > 1)
}
