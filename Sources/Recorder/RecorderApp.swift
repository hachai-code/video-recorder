import SwiftUI

@main
struct RecorderApp: App {
    @State private var controller = RecordingController()

    var body: some Scene {
        Window("Recorder", id: "main") {
            Form { MenuContent(controller: controller) }
                .formStyle(.grouped)
                .frame(width: 320)
        }
        .windowResizability(.contentSize)

        MenuBarExtra("Recorder", systemImage: controller.phase == .recording ? "record.circle.fill" : "record.circle") {
            MenuContent(controller: controller)
        }
    }
}

struct MenuContent: View {
    @Bindable var controller: RecordingController

    var body: some View {
        switch controller.phase {
        case .idle: Button("Start Recording…") { controller.start() }
        case .preparing: Button("Starting…") {}.disabled(true)
        case .recording: Button("Stop Recording") { controller.stop() }
        }
        Divider()
        Group {
            Toggle("Camera", isOn: $controller.options.camera)
            Toggle("Microphone", isOn: $controller.options.microphone)
            Toggle("App Audio", isOn: $controller.options.appAudio)
            Picker("Bubble Corner", selection: $controller.options.corner) {
                ForEach(Corner.allCases, id: \.self) { Text($0.rawValue) }
            }
            Picker("Bubble Size", selection: $controller.options.size) {
                ForEach(BubbleSize.allCases, id: \.self) { Text($0.rawValue) }
            }
        }
        .disabled(controller.phase != .idle)
        Divider()
        Button("Quit") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
    }
}
