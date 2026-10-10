import SpectralTransforms

/// Application compatibility boundary for the checked shared real transform.
/// Existing callers use finite signals and compatible packed arrays. Unsupported
/// requests retain a failing precondition instead of choosing a fallback response.
final class RealFFT {
    private let transform: SpectralTransforms.RealFFT
    var length: Int { transform.length }

    init(length: Int) {
        transform = requiredFFT { try SpectralTransforms.RealFFT(length: length) }
    }

    func forward(_ signal: [Double]) -> (real: [Double], imag: [Double]) {
        requiredFFT { try transform.forward(signal) }
    }

    func inverse(real: [Double], imag: [Double]) -> [Double] {
        requiredFFT { try transform.inverse(real: real, imag: imag) }
    }

    static func accumulate(
        _ spectrum: (real: [Double], imag: [Double]), into sum: inout (real: [Double], imag: [Double]),
        sampleRate: Double, response: (Double) -> Double
    ) {
        requiredFFT {
            try SpectralTransforms.RealFFT.accumulate(
                spectrum, into: &sum, sampleRate: sampleRate, response: response)
        }
    }

    /// Right-padded sampled circular filtering, retaining the original prefix.
    static func zeroPhaseFilter(
        _ signal: [Float], sampleRate: Double, padding: Int = 1 << 14, response: (Double) -> Double
    ) -> [Float] {
        requiredFFT {
            try SpectralTransforms.RealFFT.zeroPhaseFilter(
                signal, sampleRate: sampleRate, padding: padding, response: response)
        }
    }
}

/// Full linear convolution, using the released shared Double FFT primitive.
public enum Convolution {
    public static func convolve(_ signal: [Float], _ response: [Float]) -> [Float] {
        requiredFFT { try SpectralTransforms.Convolution.convolve(signal, response) }
    }
}

/// Error policy for the existing nonthrowing application API. The shared product
/// exposes checked failures directly; changing application recovery is separate.
private func requiredFFT<Value>(_ operation: () throws -> Value) -> Value {
    do { return try operation() } catch { preconditionFailure("Unsupported FFT request: \(error)") }
}
