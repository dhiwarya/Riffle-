import AVFoundation
import Foundation
import Observation
import RiffleAudio
import RiffleTheory

/// Records the M1 test corpus on a real iPhone: guided shots, live detector readout,
/// WAV files plus a manifest in Documents/Corpus (visible in the Files app).
@MainActor
@Observable
final class ClipRecorderModel {
    enum Phase: Equatable {
        case idle
        case countIn(Int)
        case recording
        case review
    }

    let shots = CorpusShotList.all
    let folder: URL
    private(set) var recorded: Set<String> = []
    private(set) var phase: Phase = .idle
    private(set) var snapshot = LiveSnapshot()
    private(set) var lastClip: AudioClip?
    private(set) var problem: String?
    private(set) var exportURL: URL?
    private(set) var isUsingBluetoothMic = false
    var guitar: String {
        didSet { UserDefaults.standard.set(guitar, forKey: "dev.corpus.guitar") }
    }

    private let listener = LiveListener()
    private var listening = false
    private var countIn: Task<Void, Never>?
    private var player: AVAudioPlayer?

    init() {
        folder = URL.documentsDirectory.appendingPathComponent("Corpus", isDirectory: true)
        guitar = UserDefaults.standard.string(forKey: "dev.corpus.guitar") ?? ""
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        refreshRecorded()
    }

    func shot(id: String) -> CorpusShot? { shots.first { $0.id == id } }

    func nextUnrecorded(after shot: CorpusShot) -> CorpusShot? {
        guard let index = shots.firstIndex(of: shot) else { return nil }
        return shots[(index + 1)...].first { !recorded.contains($0.id) } ?? shots.first { !recorded.contains($0.id) && $0 != shot }
    }

    // MARK: Listening

    func startListening(for shot: CorpusShot) async {
        problem = nil
        phase = .idle
        lastClip = nil
        guard await MicrophoneCapture.requestPermission() else {
            problem = "Microphone access is off. Turn it on in Settings › Riffle."
            return
        }
        let analysis = Self.analysis(for: shot)
        if listening {
            listener.setAnalysis(analysis)
        } else {
            do {
                try listener.start(analysis: analysis) { [weak self] snapshot in
                    Task { @MainActor in self?.snapshot = snapshot }
                }
                listening = true
            } catch {
                problem = "Couldn't start the microphone: \(error.localizedDescription)"
            }
        }
        isUsingBluetoothMic = listener.isUsingBluetoothMic
    }

    func stopListening() {
        countIn?.cancel()
        listener.stop()
        listening = false
        player?.stop()
        phase = .idle
    }

    private static func analysis(for shot: CorpusShot) -> LiveListener.Analysis {
        if case .pitch = shot.expectation { return .pitch }
        if let chord = shot.targetChord { return .chord(chord) }
        return .chord(Chord(.A, .minor)) // noise shots: show whether anything would pass as Am
    }

    // MARK: Recording

    func record(_ shot: CorpusShot) {
        player?.stop()
        lastClip = nil
        countIn?.cancel()
        countIn = Task { [weak self] in
            for n in stride(from: 3, through: 1, by: -1) {
                self?.phase = .countIn(n)
                try? await Task.sleep(for: .seconds(0.8))
                if Task.isCancelled { return }
            }
            guard let self else { return }
            self.phase = .recording
            self.listener.startRecording(seconds: shot.seconds) { [weak self] clip in
                Task { @MainActor in
                    self?.lastClip = clip
                    self?.phase = .review
                }
            }
        }
    }

    func retake(_ shot: CorpusShot) {
        player?.stop()
        lastClip = nil
        phase = .idle
        listener.setAnalysis(Self.analysis(for: shot))
    }

    func keep(_ shot: CorpusShot) {
        guard let clip = lastClip else { return }
        do {
            try clip.writeWAV(to: folder.appendingPathComponent(shot.fileName))
            try updateManifest(adding: shot, clip: clip)
            recorded.insert(shot.id)
            exportURL = nil
            lastClip = nil
            phase = .idle
        } catch {
            problem = "Couldn't save the clip: \(error.localizedDescription)"
        }
    }

    func playBack() {
        guard let clip = lastClip else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("riffle-preview.wav")
        do {
            try clip.writeWAV(to: url)
            player = try AVAudioPlayer(contentsOf: url)
            player?.volume = 1
            player?.play()
        } catch {
            problem = "Couldn't play the clip back: \(error.localizedDescription)"
        }
    }

    // MARK: Files

    func refreshRecorded() {
        let files = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        recorded = Set(shots.filter { files.contains($0.fileName) }.map(\.id))
    }

    /// Zips Documents/Corpus for AirDrop / Files (NSFileCoordinator makes the zip for us).
    func prepareExport() {
        var coordinatorError: NSError?
        var zipped: URL?
        NSFileCoordinator().coordinate(readingItemAt: folder, options: .forUploading, error: &coordinatorError) { zipURL in
            let target = FileManager.default.temporaryDirectory.appendingPathComponent("Riffle-Corpus.zip")
            try? FileManager.default.removeItem(at: target)
            if (try? FileManager.default.copyItem(at: zipURL, to: target)) != nil { zipped = target }
        }
        exportURL = zipped
        if zipped == nil { problem = "Couldn't make the zip: \(coordinatorError?.localizedDescription ?? "unknown error")" }
    }

    private struct Manifest: Codable {
        struct Clip: Codable {
            var recordedAt: Date
            var sampleRate: Double
            var seconds: Double
        }

        var device = ""
        var system = ""
        var appVersion = ""
        var guitar = ""
        var a4 = 440.0
        var clips: [String: Clip] = [:]
    }

    private func updateManifest(adding shot: CorpusShot, clip: AudioClip) throws {
        let url = folder.appendingPathComponent("manifest.json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        var manifest = (try? Data(contentsOf: url)).flatMap { try? decoder.decode(Manifest.self, from: $0) } ?? Manifest()
        manifest.device = Self.deviceModel
        manifest.system = ProcessInfo.processInfo.operatingSystemVersionString
        manifest.appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        manifest.guitar = guitar
        manifest.clips[shot.id] = .init(recordedAt: .now, sampleRate: clip.sampleRate, seconds: clip.duration)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(manifest).write(to: url)
    }

    private static var deviceModel: String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { String(decoding: $0.prefix { $0 != 0 }, as: UTF8.self) }
    }
}
