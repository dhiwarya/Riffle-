import AVFoundation

/// Captures mono audio from the microphone and hands each block to a handler on the audio thread.
/// On iOS it uses measurement mode (no automatic gain or voice processing) and prefers the
/// built-in mic, even with headphones connected (D4).
public final class MicrophoneCapture: @unchecked Sendable {
    public typealias Handler = @Sendable (_ samples: [Float], _ sampleRate: Double) -> Void

    public enum CaptureError: Error { case noInput }

    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var running = false

    public init() {}

    public static func requestPermission() async -> Bool {
        #if os(iOS)
        await AVAudioApplication.requestRecordPermission()
        #else
        await AVCaptureDevice.requestAccess(for: .audio)
        #endif
    }

    public func start(handler: @escaping Handler) throws {
        try lock.withLock {
            guard !running else { return }
            #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker, .allowBluetoothA2DP])
            try session.setPreferredSampleRate(48_000)
            try session.setPreferredIOBufferDuration(0.01)
            try session.setActive(true)
            if let builtIn = session.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                try? session.setPreferredInput(builtIn)
            }
            #endif
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            guard format.sampleRate > 0, format.channelCount > 0 else { throw CaptureError.noInput }
            let sampleRate = format.sampleRate
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                guard let data = buffer.floatChannelData else { return }
                handler(Array(UnsafeBufferPointer(start: data[0], count: Int(buffer.frameLength))), sampleRate)
            }
            engine.prepare()
            do {
                try engine.start()
            } catch {
                input.removeTap(onBus: 0)
                throw error
            }
            running = true
        }
    }

    public func stop() {
        lock.withLock {
            guard running else { return }
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            running = false
            #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            #endif
        }
    }

    /// True when input comes from a Bluetooth headset mic (low quality; the UI should warn).
    public var isUsingBluetoothMic: Bool {
        #if os(iOS)
        AVAudioSession.sharedInstance().currentRoute.inputs.contains { $0.portType == .bluetoothHFP }
        #else
        false
        #endif
    }
}
