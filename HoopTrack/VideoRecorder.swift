@preconcurrency import AVFoundation
import UIKit

enum VideoQuality: String, CaseIterable, Identifiable {
    case hd720
    case hd1080
    case uhd4K

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .hd720: "720p"
        case .hd1080: "1080p"
        case .uhd4K: "4K"
        }
    }

    var preset: AVCaptureSession.Preset {
        switch self {
        case .hd720: .hd1280x720
        case .hd1080: .hd1920x1080
        case .uhd4K: .hd4K3840x2160
        }
    }
}

/// Records the back camera to a file during a workout. Video only, no audio.
@MainActor
final class VideoRecorder: NSObject, ObservableObject {
    static let shared = VideoRecorder()

    enum State: Equatable {
        case idle
        case starting
        case recording
        case failed(String)
    }

    /// The pre-workout toggle: record the next workout or not.
    @Published var isEnabled = false
    @Published var quality: VideoQuality {
        didSet { UserDefaults.standard.set(quality.rawValue, forKey: Self.qualityKey) }
    }
    @Published private(set) var state = State.idle

    /// Hand this to `CameraPreview` to show what the camera sees.
    let previewLayer: AVCaptureVideoPreviewLayer

    private nonisolated let captureSession = AVCaptureSession()

    var isCameraAvailable: Bool { camera != nil }

    private static let qualityKey = "video.quality"
    private nonisolated let output = AVCaptureMovieFileOutput()
    private let queue = DispatchQueue(label: "com.arturhi.HoopTrack.capture")
    private let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    private var isConfigured = false
    /// The workout being recorded; nil once it has ended.
    private var activeWorkoutID: UUID?
    private var current: RecordedVideo?

    private override init() {
        quality = UserDefaults.standard.string(forKey: Self.qualityKey).flatMap(VideoQuality.init) ?? .hd1080
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspect
        super.init()
    }

    /// Asks for camera access if needed and starts the camera so the preview
    /// shows a picture. Returns false if the camera can't be used.
    @discardableResult
    func prepare() async -> Bool {
        guard let camera else {
            state = .failed("No camera available")
            return false
        }
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            state = .failed("Camera access denied")
            return false
        }

        let session = captureSession
        let output = output
        let preset = quality.preset
        let needsSetup = !isConfigured
        let ready = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            queue.async {
                var ok = true
                session.beginConfiguration()
                if needsSetup {
                    if let input = try? AVCaptureDeviceInput(device: camera),
                       session.canAddInput(input), session.canAddOutput(output) {
                        session.addInput(input)
                        session.addOutput(output)
                    } else {
                        ok = false
                    }
                }
                if ok, session.canSetSessionPreset(preset) { session.sessionPreset = preset }
                session.commitConfiguration()
                if ok, !session.isRunning { session.startRunning() }
                continuation.resume(returning: ok)
            }
        }

        guard ready else {
            state = .failed("Could not set up the camera")
            return false
        }
        isConfigured = true
        if case .failed = state { state = .idle }
        return true
    }

    func startRecording(workoutID: UUID) async {
        guard state != .starting, state != .recording else { return }
        activeWorkoutID = workoutID
        state = .starting
        guard await prepare(), activeWorkoutID == workoutID, let camera else {
            if activeWorkoutID == workoutID, state == .starting { state = .idle }
            return
        }

        // Keep the horizon level however the phone is propped up.
        let angle = AVCaptureDevice.RotationCoordinator(device: camera, previewLayer: nil)
            .videoRotationAngleForHorizonLevelCapture
        if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(angle) {
            connection.videoRotationAngle = angle
        }

        let url = VideoStore.newURL(for: workoutID)
        VideoStore.discard(url)
        UIApplication.shared.isIdleTimerDisabled = true
        let output = output
        queue.async {
            output.startRecording(to: url, recordingDelegate: self)
        }
    }

    /// Ends the recording and returns it, or nil if nothing was recorded.
    /// The file finishes writing a moment after this returns.
    @discardableResult
    func stopRecording() -> RecordedVideo? {
        let video = current
        current = nil
        activeWorkoutID = nil
        shutDown()
        return video
    }

    /// Stops the camera. Call when the preview is no longer on screen and no workout is recording.
    func shutDown() {
        guard activeWorkoutID == nil else { return }
        UIApplication.shared.isIdleTimerDisabled = false
        let session = captureSession
        let output = output
        queue.async {
            if output.isRecording {
                // The camera is stopped once the file has finished writing.
                output.stopRecording()
            } else if session.isRunning {
                session.stopRunning()
            }
        }
        if state == .starting || state == .recording { state = .idle }
    }
}

extension VideoRecorder: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        let startDate = Date()
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                guard self.activeWorkoutID != nil else {
                    // The workout ended before the camera got going.
                    self.queue.async { output.stopRecording() }
                    return
                }
                self.current = RecordedVideo(url: fileURL, startDate: startDate)
                self.state = .recording
            }
        }
    }

    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        // AVFoundation reports some normal endings as errors but still finishes the file.
        let finished = (error as NSError?)?.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool ?? (error == nil)
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                if !finished {
                    VideoStore.discard(outputFileURL)
                    if self.current?.url == outputFileURL { self.current = nil }
                }
                if self.activeWorkoutID != nil {
                    // Ended while the workout is still going: say so instead of showing "recording".
                    self.state = .failed(finished ? "Recording stopped early" : "Recording stopped unexpectedly")
                    UIApplication.shared.isIdleTimerDisabled = false
                } else {
                    let session = self.captureSession
                    self.queue.async {
                        if session.isRunning, !output.isRecording { session.stopRunning() }
                    }
                }
            }
        }
    }
}
