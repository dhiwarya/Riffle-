import AVFoundation
import RiffleTheory

/// Plays phrases (notes, chords, cadences) with the synthesised guitar or piano. Each phrase is
/// mixed into one buffer, so timing is sample-exact; starting a new phrase replaces the current one.
public final class ToneEngine: @unchecked Sendable {
    public static let sampleRate = 48_000.0

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: ToneEngine.sampleRate, channels: 1)!
    private let renderQueue = DispatchQueue(label: "app.riffle.tones", qos: .userInitiated)
    private let lock = NSLock()
    private var cache: [String: [Float]] = [:]
    private var configured = false

    public init() {}

    /// Renders and caches notes ahead of time so the first play has no delay.
    public func prepare(_ phrases: [Phrase], instrument: Instrument) {
        renderQueue.async {
            for phrase in phrases { _ = self.mix(phrase, instrument: instrument) }
        }
    }

    /// Mixes `phrase` offline (pure function of the inputs; used by `play` and by tests).
    public func mix(_ phrase: Phrase, instrument: Instrument) -> [Float] {
        let total = Int((phrase.duration + 0.05) * Self.sampleRate)
        var output = [Float](repeating: 0, count: max(total, 1))
        for note in phrase.notes {
            let samples = rendered(note, instrument: instrument)
            let start = Int(note.offset * Self.sampleRate)
            for i in 0..<min(samples.count, output.count - start) where start + i >= 0 {
                output[start + i] += samples[i]
            }
        }
        // Soft limit so dense chords never clip.
        return output.map { Float(tanh(Double($0) * 1.1) / 1.1) }
    }

    /// Plays `phrase` now, replacing whatever is playing. Returns its length in seconds.
    @discardableResult
    public func play(_ phrase: Phrase, instrument: Instrument) -> Double {
        renderQueue.async { [self] in
            let samples = mix(phrase, instrument: instrument)
            guard (try? startIfNeeded()) != nil,
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else { return }
            buffer.frameLength = AVAudioFrameCount(samples.count)
            samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
            player.scheduleBuffer(buffer, at: nil, options: .interrupts)
            if !player.isPlaying { player.play() }
        }
        return phrase.duration
    }

    public func stop() {
        renderQueue.async { [self] in
            player.stop()
            engine.stop()
        }
    }

    private func rendered(_ note: PlaybackNote, instrument: Instrument) -> [Float] {
        let velocityStep = Int((note.velocity * 10).rounded())
        let key = "\(instrument.rawValue)-\(note.midi)-\(velocityStep)-\(Int(note.duration * 100))"
        if let hit = lock.withLock({ cache[key] }) { return hit }
        let frequency = PitchMath.frequency(midi: Double(note.midi))
        let samples = instrument.render(frequency: frequency, duration: note.duration,
                                        velocity: Double(velocityStep) / 10, sampleRate: Self.sampleRate)
        lock.withLock { cache[key] = samples }
        return samples
    }

    private func startIfNeeded() throws {
        if !configured {
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            configured = true
        }
        guard !engine.isRunning else { return }
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        if session.category != .playAndRecord {
            // Plain playback: full speaker volume, plays even with the silent switch on.
            try session.setCategory(.playback, mode: .default)
        }
        try session.setActive(true)
        #endif
        engine.prepare()
        try engine.start()
    }
}
