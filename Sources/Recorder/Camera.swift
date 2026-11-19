import AVFoundation

final class Camera: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    let session = AVCaptureSession()
    var onFrame: ((CMSampleBuffer) -> Void)?

    func start() async throws {
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            throw RecorderError("Camera access denied. Allow it in System Settings › Privacy & Security › Camera.")
        }
        if session.inputs.isEmpty {
            guard let device = AVCaptureDevice.default(for: .video) else { throw RecorderError("No camera found.") }
            session.beginConfiguration()
            session.sessionPreset = .high
            session.addInput(try AVCaptureDeviceInput(device: device))
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
            output.setSampleBufferDelegate(self, queue: captureQueue)
            session.addOutput(output)
            session.commitConfiguration()
        }
        let session = session
        await Task.detached { session.startRunning() }.value
    }

    func stop() async {
        let session = session
        await Task.detached { session.stopRunning() }.value
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        onFrame?(sampleBuffer)
    }
}
