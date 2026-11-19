import ScreenCaptureKit

final class WindowPicker: NSObject, SCContentSharingPickerObserver {
    private var continuation: CheckedContinuation<SCContentFilter?, Error>?

    /// Returns nil when the user cancels.
    func pick() async throws -> SCContentFilter? {
        let picker = SCContentSharingPicker.shared
        var configuration = SCContentSharingPickerConfiguration()
        configuration.allowedPickerModes = [.singleWindow, .singleApplication]
        picker.defaultConfiguration = configuration
        picker.add(self)
        picker.isActive = true
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            picker.present()
        }
    }

    private func finish(_ result: Result<SCContentFilter?, Error>) {
        let picker = SCContentSharingPicker.shared
        picker.isActive = false
        picker.remove(self)
        continuation?.resume(with: result)
        continuation = nil
    }

    func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        finish(.success(nil))
    }

    func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        finish(.success(filter))
    }

    func contentSharingPickerStartDidFailWithError(_ error: Error) {
        finish(.failure(error))
    }
}
