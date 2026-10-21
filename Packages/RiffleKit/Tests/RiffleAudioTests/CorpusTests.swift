import Foundation
import RiffleTheory
import Testing
@testable import RiffleAudio

/// Runs the detectors on real recordings in `Corpus/recordings` (not in git). Skipped when the folder
/// is empty. Writes `Corpus/last-report.md` with every miss, for tuning thresholds.
struct CorpusTests {
    static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent()
    static let recordings = repoRoot.appendingPathComponent("Corpus/recordings")
    static var hasRecordings: Bool {
        (try? FileManager.default.contentsOfDirectory(atPath: recordings.path))?.contains { $0.hasSuffix(".wav") } ?? false
    }

    @Test(.enabled(if: hasRecordings, "No clips in Corpus/recordings yet"))
    func recordedCorpusMeetsTargets() throws {
        let report = CorpusEvaluator().evaluate(folder: Self.recordings)
        try report.markdown.write(to: Self.repoRoot.appendingPathComponent("Corpus/last-report.md"), atomically: true, encoding: .utf8)

        #expect(report.truePositiveRate >= 0.95, "correct chords passed: \(report.truePositiveRate)")
        #expect(report.falsePositiveRate <= 0.05, "wrong chords passed: \(report.falsePositiveRate)")
        if let median = report.medianInTuneError { #expect(median < 2, "tuner median error \(median)¢") }
        let outOfTolerance = report.pitch.filter { !$0.passed }.map(\.shot.id)
        #expect(outOfTolerance.isEmpty, "tuner clips outside tolerance: \(outOfTolerance)")
    }

    /// `RIFFLE_WRITE_SHOTLIST=1 swift test --filter writeShotList` regenerates Corpus/SHOTLIST.md.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["RIFFLE_WRITE_SHOTLIST"] == "1"))
    func writeShotList() throws {
        var lines = ["# Shot list", "",
                     "Generated from `CorpusShotList.swift` — don't edit by hand. \(CorpusShotList.all.count) clips.", ""]
        for group in CorpusShot.Group.allCases {
            let shots = CorpusShotList.shots(in: group)
            lines += ["## \(group.title) (\(shots.count))", "", group.setup, "", "| # | Clip | What to do | Seconds |", "|---|---|---|---|"]
            for (index, shot) in shots.enumerated() {
                lines.append("| \(index + 1) | **\(shot.title)** `\(shot.id)` | \(shot.instruction) | \(Int(shot.seconds)) |")
            }
            lines.append("")
        }
        try lines.joined(separator: "\n").write(to: Self.repoRoot.appendingPathComponent("Corpus/SHOTLIST.md"),
                                                atomically: true, encoding: .utf8)
    }
}

/// The evaluator itself, on synthetic clips written to disk and read back.
struct CorpusEvaluatorTests {
    @Test func scoresSyntheticClips() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("riffle-corpus-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }

        let sampleRate = 48_000.0
        let am = CorpusShotList.shot(id: "chord-am-a")!
        let a4 = 440.0
        let notes = [45, 52, 57, 60, 64].map { a4 * pow(2, Double($0 - 69) / 12) }
        try AudioClip(samples: GuitarSynth.strum(notes, duration: 3, sampleRate: sampleRate), sampleRate: sampleRate)
            .writeWAV(to: folder.appendingPathComponent(am.fileName))

        let flatA = CorpusShotList.shot(id: "tuner-s5-m10")!
        var pluck = GuitarSynth.Pluck(frequency: 110 * pow(2, -10.0 / 1200))
        pluck.amplitude = 0.3
        try AudioClip(samples: GuitarSynth.tone(pluck, duration: 3, sampleRate: sampleRate, startAt: 0.4), sampleRate: sampleRate)
            .writeWAV(to: folder.appendingPathComponent(flatA.fileName))

        let report = CorpusEvaluator().evaluate(folder: folder, shots: [am, flatA])
        #expect(report.missingFiles.isEmpty)
        #expect(report.chords.first { !$0.isConfusion }?.didPass == true)
        let confusionsPassed = report.chords.filter { $0.isConfusion && $0.didPass }
        #expect(confusionsPassed.isEmpty)
        #expect(report.pitch.first?.passed == true, "\(String(describing: report.pitch.first?.measuredCents))")
        #expect(report.markdown.contains("Correct chords passed | 100.0 %"))
    }
}

/// Dev aid: `RIFFLE_ANALYZE=/path/clip.wav swift test --filter analyzeFile` prints what the tuner hears.
struct AnalyzeFileTool {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["RIFFLE_ANALYZE"] != nil))
    func analyzeFile() throws {
        let url = URL(fileURLWithPath: ProcessInfo.processInfo.environment["RIFFLE_ANALYZE"]!)
        let clip = try AudioClip.load(from: url)
        let tracker = PitchTracker(sampleRate: clip.sampleRate)
        let engine = TunerEngine()
        for reading in tracker.process(clip.samples) {
            let state = engine.process(reading)
            let note = Note.nearest(to: reading.frequency)
            print(String(format: "%.2fs  %7.2f Hz  %@ %+.1f¢  clarity %.2f  level %.0f dB  → string %d %@",
                         reading.time, reading.frequency, note.note.spelled().description, note.cents, reading.clarity,
                         reading.levelDB, Tuning.stringNumber(forIndex: state.selectedString),
                         state.cents.map { String(format: "%+.1f¢", $0) } ?? "–"))
        }
    }
}

extension AnalyzeFileTool {
    /// `RIFFLE_PEAKS=/path/clip.wav swift test --filter printPeaks` prints the strongest spectral peaks every 0.5 s.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["RIFFLE_PEAKS"] != nil))
    func printPeaks() throws {
        let clip = try AudioClip.load(from: URL(fileURLWithPath: ProcessInfo.processInfo.environment["RIFFLE_PEAKS"]!))
        let estimator = NoteEstimator(sampleRate: clip.sampleRate)
        var start = 0
        while start + estimator.windowSize <= clip.samples.count {
            let window = Array(clip.samples[start..<start + estimator.windowSize])
            let peaks = window.withUnsafeBufferPointer { estimator.peaks(in: $0) }
            let top = peaks.sorted { $0.magnitude > $1.magnitude }.prefix(6)
            let loudest = top.first?.magnitude ?? 1
            let text = top.map { String(format: "%.0fHz(%.0fdB)", $0.frequency, 20 * log10($0.magnitude / loudest)) }.joined(separator: " ")
            print(String(format: "%.1fs ", Double(start) / clip.sampleRate) + text)
            start += Int(clip.sampleRate / 2)
        }
    }
}
