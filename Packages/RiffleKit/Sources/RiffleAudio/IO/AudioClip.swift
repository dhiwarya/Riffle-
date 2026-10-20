import AVFoundation

/// Mono audio in memory: what the recorder saves and the corpus tests load.
public struct AudioClip: Sendable {
    public var samples: [Float]
    public var sampleRate: Double

    public init(samples: [Float], sampleRate: Double) {
        self.samples = samples
        self.sampleRate = sampleRate
    }

    public var duration: Double { Double(samples.count) / sampleRate }

    /// Loads any file AVFoundation reads (WAV, CAF, M4A); multi-channel audio is averaged to mono.
    public static func load(from url: URL) throws -> AudioClip {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try file.read(into: buffer)
        guard let channels = buffer.floatChannelData else { throw CocoaError(.fileReadCorruptFile) }
        let frames = Int(buffer.frameLength)
        let channelCount = Int(format.channelCount)
        var mono = [Float](repeating: 0, count: frames)
        for channel in 0..<channelCount {
            let data = channels[channel]
            for i in 0..<frames { mono[i] += data[i] / Float(channelCount) }
        }
        return AudioClip(samples: mono, sampleRate: format.sampleRate)
    }

    /// Writes 16-bit mono WAV.
    public func writeWAV(to url: URL) throws {
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else {
            throw CocoaError(.fileWriteUnknown)
        }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { buffer.floatChannelData![0].update(from: $0.baseAddress!, count: samples.count) }
        try file.write(from: buffer)
    }
}
