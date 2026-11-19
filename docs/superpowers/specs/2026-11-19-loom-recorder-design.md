# Window recorder with camera bubble — design

## Intent
A personal Loom-style recorder for macOS. Pick one app or window, record it with a rounded-square webcam bubble baked into the video, save an .mp4 locally. No sharing, no hosting.

## Goals
- System window/app picker (the one FaceTime/Zoom use).
- Rounded-square camera bubble composited into every frame, mirrored like a selfie view.
- Floating on-screen bubble so you see yourself, in the corner chosen from the menu. The video uses the same corner.
- Bubble size small / medium / large.
- Mic audio on by default; captured app's audio as a toggle; camera on/off toggle.
- Menu-bar icon (no Dock icon) with Start / Stop and settings; 3-2-1 countdown before recording.
- Saves to `~/Movies/Recordings/Recording YYYY-MM-DD at HH.MM.SS.mp4`, then reveals it in Finder.

## Non-goals
Upload/share links, editing/trimming, pause/resume, full-display or region capture, drawing tools, Windows/Linux.

## Anti-goals
- Camera freezing in the video while the captured window is idle.
- Bubble missing from the recording because it isn't part of the captured window.

## Constraints
- macOS 26.5, Xcode 26.6, Swift 6.3, Apple Silicon. Target macOS 15+.
- No Apple signing identity on this Mac → ad-hoc signed. Camera/mic permission may be re-asked after each rebuild.
- No Xcode project generator installed → Swift Package + a small `build.sh` that assembles and ad-hoc signs the `.app` with its Info.plist (camera/mic usage strings, `LSUIElement`).

## Approaches
1. **Native Swift/SwiftUI + ScreenCaptureKit + AVFoundation** — chosen. System picker, hardware H.264, small app, low CPU.
2. Electron (desktopCapturer + canvas + MediaRecorder) — cross-platform but ~150 MB, custom picker, .webm-first. Rejected: Mac-only use.
3. Tauri — weak window capture on macOS. Rejected.

## How it works
- **Picker:** `SCContentSharingPicker` returns an `SCContentFilter` for the chosen window/app.
- **Screen:** `SCStream` with that filter, output sized to the window's pixel size, 60 fps cap; app audio enabled when toggled.
- **Camera:** `AVCaptureSession` on the default camera, 30 fps.
- **Compositor:** Core Image draws the latest screen frame plus the masked, mirrored camera frame in the chosen corner. Output ticks on each camera frame, so the bubble keeps moving when the window is static. With the camera off, it ticks on screen frames.
- **Writer:** `AVAssetWriter` → .mp4, H.264 video, AAC mic track, plus a second AAC track for app audio when on. Session starts at the first composited frame (host clock).
- **UI:** `MenuBarExtra` menu, a borderless floating panel for the bubble, a transient countdown overlay.
- Recording stops on Stop or if the captured window closes (stream error), and the file is still finalized.

## Builder's calls
- **App audio as a separate track.** QuickTime plays both, but some players and browsers only play the first (mic). Upgrade path is mixing the PCM into one track.
- **Camera device.** System default camera, no device picker.
- **Window resize mid-recording.** Output size is fixed at start, so ScreenCaptureKit scales the content to fit.
- File layout, naming, and error-alert wording.
