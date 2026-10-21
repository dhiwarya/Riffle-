import AVFoundation
import Observation
import RiffleAudio
import RiffleStore
import RiffleTheory
import UIKit

/// Microphone → pitch tracker → tuner engine, published for the tuner screen.
@MainActor
@Observable
final class TunerModel {
    enum Availability: Equatable {
        case idle
        case listening
        case denied
        case failed(String)
    }

    private(set) var state = TunerState()
    private(set) var availability: Availability = .idle
    private(set) var isUsingBluetoothMic = false
    private(set) var tuning: Tuning = .standard
    private(set) var a4 = 440.0
    var mode: TunerEngine.Mode = .auto {
        didSet {
            engine.mode = mode
            state = engine.state
        }
    }

    private let engine = TunerEngine()
    private let listener = LiveListener()
    private var lastAnnouncement = Date.distantPast

    func configure(tuning: Tuning, a4: Double) {
        self.tuning = tuning
        self.a4 = a4
        engine.tuning = tuning
        engine.a4 = a4
        state = engine.state
    }

    func select(string index: Int) {
        engine.select(string: index)
        state = engine.state
    }

    func start() async {
        guard availability != .listening else { return }
        guard await MicrophoneCapture.requestPermission() else {
            availability = .denied
            return
        }
        engine.clearSignal()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-tunerDemo") {
            listener.startSimulated(Self.demoClip(), analysis: .pitch) { [weak self] snapshot in
                Task { @MainActor in self?.handle(snapshot) }
            }
            availability = .listening
            return
        }
        #endif
        do {
            try listener.start(analysis: .pitch) { [weak self] snapshot in
                Task { @MainActor in self?.handle(snapshot) }
            }
            availability = .listening
            isUsingBluetoothMic = listener.isUsingBluetoothMic
        } catch {
            availability = .failed(error.localizedDescription)
        }
    }

    func stop() {
        guard availability == .listening else { return }
        listener.stop()
        engine.clearSignal()
        state = engine.state
        availability = .idle
    }

    #if DEBUG
    /// Launch with `-tunerDemo` to drive the tuner with synthetic plucks instead of the mic:
    /// low E flat → closer → in tune, a pause (auto-advance), then A sharp → in tune.
    private static func demoClip() -> AudioClip {
        let sampleRate = 48_000.0
        let plucks: [(midi: Int, cents: Double, at: Double)] = [
            (40, -22, 0.5), (40, -6, 3.0), (40, 0.5, 5.0), (45, 15, 9.0), (45, -0.5, 11.5),
        ]
        var samples: [Float] = []
        for pluck in plucks {
            var tone = GuitarSynth.Pluck(frequency: Note(midi: pluck.midi).frequency() * pow(2, pluck.cents / 1200))
            tone.amplitude = 0.3
            tone.decay = 2.5
            GuitarSynth.render(tone, duration: pluck.at + 2.4, sampleRate: sampleRate, startAt: pluck.at, into: &samples)
        }
        samples += [Float](repeating: 0, count: Int(sampleRate * 1.5))
        return AudioClip(samples: samples, sampleRate: sampleRate)
    }
    #endif

    private func handle(_ snapshot: LiveSnapshot) {
        guard availability == .listening else { return }
        for reading in snapshot.newPitchReadings { engine.process(reading) }
        engine.tick(time: snapshot.streamTime)
        if engine.state != state { state = engine.state }
        announceIfNeeded()
    }

    /// VoiceOver: the note and offset at most every 1.5 s, never every frame (plan §11).
    private func announceIfNeeded() {
        guard UIAccessibility.isVoiceOverRunning, let cents = state.cents,
              Date.now.timeIntervalSince(lastAnnouncement) > 1.5 else { return }
        lastAnnouncement = .now
        let note = tuning.strings[state.selectedString].name.description
        let rounded = Int(abs(cents).rounded())
        let message = state.isInTune ? "\(note), in tune" : "\(note), \(rounded) cents \(cents < 0 ? "flat" : "sharp")"
        UIAccessibility.post(notification: .announcement, argument: message)
    }
}

extension Tuning {
    /// The tuning for a stored id: a preset, one of the user's custom tunings, or standard.
    static func resolve(id: String, custom: [CustomTuning]) -> Tuning {
        preset(id: id) ?? custom.first { $0.id == id }?.tuning ?? .standard
    }
}
