import Foundation
import RiffleTheory

/// Runs the detectors over recorded clips and scores them against the shot list (plan §5.4 and §6.6).
public struct CorpusEvaluator {
    public struct PitchResult: Sendable {
        public let shot: CorpusShot
        /// Measured offset from the expected note, nil if nothing confident was detected.
        public let measuredCents: Double?
        public let expectedCents: Double
        public let tolerance: Double

        public var error: Double? { measuredCents.map { $0 - expectedCents } }
        public var passed: Bool { error.map { abs($0) <= tolerance } ?? false }
    }

    public struct ChordResult: Sendable {
        public let shot: CorpusShot
        public let target: String
        public let shouldPass: Bool
        public let evidence: ChordEvidence
        /// True when this row is a confusion check (a correct clip of one chord tested against another).
        public let isConfusion: Bool

        public var didPass: Bool { evidence.verdict == .passed }
        public var correct: Bool { didPass == shouldPass }
    }

    public struct Report: Sendable {
        public var pitch: [PitchResult] = []
        public var chords: [ChordResult] = []
        public var missingFiles: [String] = []

        /// Correct chord clips that passed (target ≥ 95 %).
        public var truePositiveRate: Double {
            let rows = chords.filter { $0.shouldPass }
            return rows.isEmpty ? 1 : Double(rows.filter(\.didPass).count) / Double(rows.count)
        }

        /// Wrong chords, confusions and noise that passed anyway (target ≤ 5 %).
        public var falsePositiveRate: Double {
            let rows = chords.filter { !$0.shouldPass }
            return rows.isEmpty ? 0 : Double(rows.filter(\.didPass).count) / Double(rows.count)
        }

        /// Median absolute tuner error in cents over in-tune open strings (target < 2 ¢).
        public var medianInTuneError: Double? {
            let errors = pitch.filter { $0.expectedCents == 0 && $0.shot.id.hasSuffix("-0") }.compactMap(\.error).map(abs).sorted()
            return errors.isEmpty ? nil : errors[errors.count / 2]
        }
    }

    /// Pairs checked on correct clips: the clip's chord must not pass as the confusable one.
    public static let confusions: [String: [String]] = [
        "A": ["Am"], "Am": ["A"], "E": ["Em", "E7"], "Em": ["E"], "D": ["Dm"], "Dm": ["D"],
        "C": ["Cmaj7", "Cm"], "G": ["G7"], "E7": ["E"], "Cmaj7": ["C"], "G7": ["G"],
    ]

    public var a4 = 440.0

    public init() {}

    public func evaluate(folder: URL, shots: [CorpusShot] = CorpusShotList.all) -> Report {
        var report = Report()
        for shot in shots {
            let url = folder.appendingPathComponent(shot.fileName)
            guard let clip = try? AudioClip.load(from: url) else {
                report.missingFiles.append(shot.id)
                continue
            }
            switch shot.expectation {
            case let .pitch(midi, cents, tolerance):
                report.pitch.append(PitchResult(shot: shot, measuredCents: measuredCents(clip, near: midi),
                                                expectedCents: cents, tolerance: tolerance))
            case let .chord(target, _, shouldPass, _, _):
                report.chords.append(chordResult(clip, shot: shot, target: target, shouldPass: shouldPass, isConfusion: false))
                if shouldPass {
                    for other in Self.confusions[target] ?? [] {
                        report.chords.append(chordResult(clip, shot: shot, target: other, shouldPass: false, isConfusion: true))
                    }
                }
            case .noChord:
                for target in ["Am", "E", "A"] {
                    report.chords.append(chordResult(clip, shot: shot, target: target, shouldPass: false, isConfusion: false))
                }
            case .explore:
                continue
            }
        }
        return report
    }

    /// Median of confident readings in the sustain (0.15–2.5 s after the first reading), in cents from `midi`.
    public func measuredCents(_ clip: AudioClip, near midi: Int) -> Double? {
        let tracker = PitchTracker(sampleRate: clip.sampleRate)
        let readings = tracker.process(clip.samples)
        guard let first = readings.first?.time else { return nil }
        let note = Note(midi: midi)
        let sustain = readings.filter { $0.time >= first + 0.15 && $0.time <= first + 2.5 }
            .map { note.cents(of: $0.frequency, a4: a4) }
            .sorted()
        return sustain.isEmpty ? nil : sustain[sustain.count / 2]
    }

    private func chordResult(_ clip: AudioClip, shot: CorpusShot, target: String, shouldPass: Bool, isConfusion: Bool) -> ChordResult {
        let verifier = ChordVerifier(target: Chord(symbol: target)!, sampleRate: clip.sampleRate, a4: a4)
        return ChordResult(shot: shot, target: target, shouldPass: shouldPass, evidence: verifier.evaluate(clip.samples),
                           isConfusion: isConfusion)
    }
}

extension CorpusEvaluator.Report {
    /// Markdown summary for `Corpus/last-report.md`.
    public var markdown: String {
        func percent(_ value: Double) -> String { String(format: "%.1f %%", value * 100) }
        var lines = ["# Corpus report", ""]
        lines.append("| Metric | Result | Target |")
        lines.append("|---|---|---|")
        lines.append("| Correct chords passed | \(percent(truePositiveRate)) | ≥ 95 % |")
        lines.append("| Wrong chords / confusions / noise passed | \(percent(falsePositiveRate)) | ≤ 5 % |")
        lines.append("| Tuner median error, in-tune strings | \(medianInTuneError.map { String(format: "%.2f ¢", $0) } ?? "–") | < 2 ¢ |")
        lines.append("| Tuner clips within tolerance | \(pitch.filter(\.passed).count) / \(pitch.count) | all |")
        if !missingFiles.isEmpty { lines += ["", "Missing clips: \(missingFiles.count)"] }

        let wrongChords = chords.filter { !$0.correct }
        if !wrongChords.isEmpty {
            lines += ["", "## Chord checks that went wrong", "", "| Clip | Target | Expected | Got | Heard | Missing | Extra |", "|---|---|---|---|---|---|---|"]
            for row in wrongChords {
                let e = row.evidence
                func list(_ s: Set<PitchClass>) -> String { s.map(\.description).sorted().joined(separator: " ") }
                lines.append("| \(row.shot.id) | \(row.target) | \(row.shouldPass ? "pass" : "fail") | \(e.verdict) | \(list(e.heard)) | \(list(e.missing)) | \(list(e.extra)) |")
            }
        }
        let wrongPitch = pitch.filter { !$0.passed }
        if !wrongPitch.isEmpty {
            lines += ["", "## Tuner clips outside tolerance", "", "| Clip | Expected ¢ | Measured ¢ | Tolerance |", "|---|---|---|---|"]
            for row in wrongPitch {
                lines.append("| \(row.shot.id) | \(row.expectedCents) | \(row.measuredCents.map { String(format: "%.1f", $0) } ?? "nothing") | ±\(row.tolerance) |")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
