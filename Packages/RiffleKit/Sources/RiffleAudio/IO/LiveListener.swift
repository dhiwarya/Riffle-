import Foundation
import RiffleTheory

/// What the live listener reports, roughly 20 times a second.
public struct LiveSnapshot: Sendable, Equatable {
    public var levelDB: Double = -160
    public var pitch: PitchReading?
    /// Every pitch reading since the previous snapshot, oldest first (for the tuner's timing).
    public var newPitchReadings: [PitchReading] = []
    public var chord: ChordEvidence?
    public var isRecording = false
    public var recordedSeconds = 0.0
    /// Seconds of audio consumed since the analysis was (re)configured; same clock as `PitchReading.time`.
    public var streamTime = 0.0

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
    private var samplesSinceConfigure = 0
    private var recording: [Float]?
    private var recordingLimit = 0
    private var onSnapshot: (@Sendable (LiveSnapshot) -> Void)?
    private var onRecordingFinished: (@Sendable (AudioClip) -> Void)?
    private var simulation: DispatchSourceTimer?

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

    /// Plays `clip` through the same pipeline in real time instead of the microphone, looping.
    /// For simulator demos and UI checks where no guitar is at hand.
    public func startSimulated(_ clip: AudioClip, analysis: Analysis, onSnapshot: @escaping @Sendable (LiveSnapshot) -> Void) {
        let block = 1024
        queue.sync {
            self.onSnapshot = onSnapshot
            self.sampleRate = clip.sampleRate
            self.configure(analysis)
            var position = 0
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now(), repeating: Double(block) / clip.sampleRate)
            timer.setEventHandler { [weak self] in
                guard let self, !clip.samples.isEmpty else { return }
                var chunk = Array(clip.samples[position..<min(position + block, clip.samples.count)])
                position += block
                if position >= clip.samples.count {
                    position = 0
                    chunk += [Float](repeating: 0, count: block - chunk.count)
                }
                self.consume(chunk, sampleRate: clip.sampleRate)
            }
            simulation = timer
            timer.resume()
        }
    }

    public func stop() {
        capture.stop()
        queue.sync {
            simulation?.cancel()
            simulation = nil
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
        snapshot.newPitchReadings = []
        snapshot.chord = nil
        samplesSinceConfigure = 0
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
        samplesSinceConfigure += samples.count
        snapshot.streamTime = Double(samplesSinceConfigure) / sampleRate

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

        if let tracker {
            let readings = tracker.process(samples)
            snapshot.newPitchReadings += readings
            if let latest = readings.last { snapshot.pitch = latest }
        }
        if let verifier { snapshot.chord = verifier.process(samples) }

        blocksSinceSnapshot += 1
        if blocksSinceSnapshot >= 2 {
            blocksSinceSnapshot = 0
            onSnapshot?(snapshot)
            snapshot.newPitchReadings.removeAll(keepingCapacity: true)
        }
    }
}
