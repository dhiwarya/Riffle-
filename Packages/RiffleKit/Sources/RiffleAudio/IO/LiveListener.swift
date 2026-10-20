import Foundation
import RiffleTheory

/// What the live listener reports, roughly 20 times a second.
public struct LiveSnapshot: Sendable, Equatable {
    public var levelDB: Double = -160
    public var pitch: PitchReading?
    public var chord: ChordEvidence?
    public var isRecording = false
    public var recordedSeconds = 0.0

    public init() {}
}

/// Microphone → (optional recording) → pitch tracker or chord verifier, all off the main thread.
/// The tuner (M2), chord quiz (M4) and the clip recorder build on this.
public final class LiveListener: @unchecked Sendable {
    public enum Analysis: Sendable, Equatable {
        case none
        case pitch
        case chord(Chord)
    }

    private let capture = MicrophoneCapture()
    private let queue = DispatchQueue(label: "app.riffle.listener", qos: .userInteractive)

    // Everything below is only touched on `queue`.
    private var analysis: Analysis = .none
    private var tracker: PitchTracker?
    private var verifier: ChordVerifier?
    private var sampleRate = 48_000.0
    private var snapshot = LiveSnapshot()
    private var blocksSinceSnapshot = 0
    private var recording: [Float]?
    private var recordingLimit = 0
    private var onSnapshot: (@Sendable (LiveSnapshot) -> Void)?
    private var onRecordingFinished: (@Sendable (AudioClip) -> Void)?

    public init() {}

    public var isUsingBluetoothMic: Bool { capture.isUsingBluetoothMic }

    public func start(analysis: Analysis, onSnapshot: @escaping @Sendable (LiveSnapshot) -> Void) throws {
        queue.sync {
            self.onSnapshot = onSnapshot
            self.configure(analysis)
        }
        try capture.start { [weak self] samples, sampleRate in
            guard let self else { return }
            self.queue.async { self.consume(samples, sampleRate: sampleRate) }
        }
    }

    public func stop() {
        capture.stop()
        queue.sync {
            recording = nil
            onRecordingFinished = nil
            onSnapshot = nil
        }
    }

    /// Switches what is analysed and starts it fresh (a new chord target, or pitch).
    public func setAnalysis(_ analysis: Analysis) {
        queue.async { self.configure(analysis) }
    }

    /// Records the next `seconds` of audio; the analysis restarts so the readout matches the take.
    public func startRecording(seconds: Double, onFinished: @escaping @Sendable (AudioClip) -> Void) {
        queue.async {
            self.configure(self.analysis)
            self.recording = []
            self.recordingLimit = Int(seconds * self.sampleRate)
            self.onRecordingFinished = onFinished
        }
    }

    public func cancelRecording() {
        queue.async {
            self.recording = nil
            self.onRecordingFinished = nil
        }
    }

    private func configure(_ analysis: Analysis) {
        self.analysis = analysis
        tracker = nil
        verifier = nil
        snapshot.pitch = nil
        snapshot.chord = nil
        switch analysis {
        case .none: break
        case .pitch: tracker = PitchTracker(sampleRate: sampleRate)
        case .chord(let chord): verifier = ChordVerifier(target: chord, sampleRate: sampleRate)
        }
    }

    private func consume(_ samples: [Float], sampleRate: Double) {
        if sampleRate != self.sampleRate {
            self.sampleRate = sampleRate
            configure(analysis)
        }
        snapshot.levelDB = samples.withUnsafeBufferPointer(rmsDecibels)

        if var taken = recording {
            taken += samples
            if taken.count >= recordingLimit {
                let clip = AudioClip(samples: Array(taken.prefix(recordingLimit)), sampleRate: sampleRate)
                recording = nil
                let finished = onRecordingFinished
                onRecordingFinished = nil
                finished?(clip)
            } else {
                recording = taken
            }
        }
        snapshot.isRecording = recording != nil
        snapshot.recordedSeconds = Double(recording?.count ?? 0) / sampleRate

        if let tracker, let reading = tracker.process(samples).last { snapshot.pitch = reading }
        if let verifier { snapshot.chord = verifier.process(samples) }

        blocksSinceSnapshot += 1
        if blocksSinceSnapshot >= 2 {
            blocksSinceSnapshot = 0
            onSnapshot?(snapshot)
        }
    }
}
