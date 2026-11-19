import AppKit
import AVFoundation

@MainActor
@Observable
final class RecordingController {
    enum Phase { case idle, preparing, recording }

    var options = RecordingOptions()
    private(set) var phase = Phase.idle

    @ObservationIgnored private let camera = Camera()
    @ObservationIgnored private let picker = WindowPicker()
    @ObservationIgnored private let bubble = BubbleWindow()
    @ObservationIgnored private var session: RecordingSession?

    func start() {
        phase = .preparing
        let options = options
        Task {
            do {
                if options.microphone, !(await AVCaptureDevice.requestAccess(for: .audio)) {
                    throw RecorderError("Microphone access denied. Allow it in System Settings › Privacy & Security › Microphone.")
                }
                if options.camera {
                    try await camera.start()
                    bubble.show(session: camera.session, options: options)
                }
                guard let filter = try await picker.pick() else { return await tearDown() }
                await runCountdown()

                let session = try RecordingSession(filter: filter, options: options, url: newRecordingURL())
                session.onUnexpectedStop = { [weak self] in Task { @MainActor in self?.stop() } }
                if options.camera { camera.onFrame = session.cameraFrame }
                try await session.start()
                self.session = session
                phase = .recording
            } catch {
                await tearDown()
                present(error)
            }
        }
    }

    func stop() {
        guard let session else { return }
        self.session = nil
        Task {
            let result = await session.stop()
            await tearDown()
            switch result {
            case .success(let url): NSWorkspace.shared.activateFileViewerSelecting([url])
            case .failure(let error): present(error)
            }
        }
    }

    private func tearDown() async {
        camera.onFrame = nil
        await camera.stop()
        bubble.hide()
        phase = .idle
    }

    private func present(_ error: Error) {
        NSApp.activate()
        NSAlert(error: error).runModal()
    }
}
