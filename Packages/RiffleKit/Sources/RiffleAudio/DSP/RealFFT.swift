import Accelerate

/// Real-input FFT of a fixed power-of-two size (vDSP). Not thread-safe: one instance per analyser.
final class RealFFT {
    let size: Int
    private let log2n: vDSP_Length
    private let setup: FFTSetup
    private var real: [Float]
    private var imag: [Float]
    private var padded: [Float]

    init(size: Int) {
        precondition(size >= 16 && size & (size - 1) == 0, "FFT size must be a power of two")
        self.size = size
        log2n = vDSP_Length(size.trailingZeroBitCount)
        setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
        real = [Float](repeating: 0, count: size / 2)
        imag = [Float](repeating: 0, count: size / 2)
        padded = [Float](repeating: 0, count: size)
    }

    deinit { vDSP_destroy_fftsetup(setup) }

    /// Forward transform of `input` (zero-padded to `size`) into the packed split-complex buffers.
    private func forward(_ input: UnsafeBufferPointer<Float>) {
        let count = min(input.count, size)
        padded.withUnsafeMutableBufferPointer { buffer in
            buffer.baseAddress!.update(from: input.baseAddress!, count: count)
            if count < size { (buffer.baseAddress! + count).update(repeating: 0, count: size - count) }
        }
        real.withUnsafeMutableBufferPointer { rp in
            imag.withUnsafeMutableBufferPointer { ip in
                var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                padded.withUnsafeBufferPointer { pp in
                    pp.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: size / 2) {
                        vDSP_ctoz($0, 2, &split, 1, vDSP_Length(size / 2))
                    }
                }
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
            }
        }
    }

    /// Magnitudes for bins 0…size/2, unnormalised (only relative values matter to callers).
    func magnitudes(of input: UnsafeBufferPointer<Float>, into output: inout [Float]) {
        forward(input)
        let half = size / 2
        if output.count != half + 1 { output = [Float](repeating: 0, count: half + 1) }
        output[0] = abs(real[0])
        output[half] = abs(imag[0])
        for k in 1..<half {
            output[k] = (real[k] * real[k] + imag[k] * imag[k]).squareRoot()
        }
    }

    /// Autocorrelation r(τ) for τ in 0..<input.count, scaled so r(0) = Σx².
    /// `input.count` must be at most size/2 so the circular correlation doesn't wrap.
    func autocorrelation(of input: UnsafeBufferPointer<Float>, into output: inout [Float]) {
        precondition(input.count <= size / 2, "Autocorrelation input must fit in half the FFT")
        forward(input)
        let half = size / 2
        // Power spectrum, keeping zrip's packing: real[0] = DC, imag[0] = Nyquist.
        real[0] = real[0] * real[0]
        imag[0] = imag[0] * imag[0]
        for k in 1..<half {
            real[k] = real[k] * real[k] + imag[k] * imag[k]
            imag[k] = 0
        }
        real.withUnsafeMutableBufferPointer { rp in
            imag.withUnsafeMutableBufferPointer { ip in
                var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_INVERSE))
                padded.withUnsafeMutableBufferPointer { pp in
                    pp.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) {
                        vDSP_ztoc(&split, 1, $0, 2, vDSP_Length(half))
                    }
                }
            }
        }
        var energy: Float = 0
        vDSP_svesq(input.baseAddress!, 1, &energy, vDSP_Length(input.count))
        let scale = padded[0] != 0 ? energy / padded[0] : 0
        if output.count != input.count { output = [Float](repeating: 0, count: input.count) }
        for tau in 0..<input.count { output[tau] = padded[tau] * scale }
    }
}

/// Hann window coefficients.
func hannWindow(_ count: Int) -> [Float] {
    var window = [Float](repeating: 0, count: count)
    vDSP_hann_window(&window, vDSP_Length(count), Int32(vDSP_HANN_NORM))
    return window
}

/// Root-mean-square level in dBFS (−160 for silence).
func rmsDecibels(_ samples: UnsafeBufferPointer<Float>) -> Double {
    guard !samples.isEmpty else { return -160 }
    var rms: Float = 0
    vDSP_rmsqv(samples.baseAddress!, 1, &rms, vDSP_Length(samples.count))
    return rms > 0 ? 20 * log10(Double(rms)) : -160
}
