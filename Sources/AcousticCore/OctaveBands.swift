import Foundation

/// The octave bands in which absorption and air attenuation are specified.
///
/// Centres are exact powers of two times 1 kHz (nominally 63 Hz to 8 kHz). The lowest band extends
/// to 0 Hz and the highest to the Nyquist frequency.
public enum OctaveBands {
    public static let centres: [Double] = (-4...3).map { 1000 * pow(2, Double($0)) }
    public static let nominalCentres = [63, 125, 250, 500, 1000, 2000, 4000, 8000]
    public static var count: Int { centres.count }

    /// Boundaries between adjacent bands, at the geometric mean of their centres.
    public static let crossovers: [Double] = zip(centres, centres.dropFirst()).map { sqrt($0 * $1) }

    /// Each crossover blends over ±0.5 octave; neighbouring transitions meet but do not overlap.
    static let transitionHalfWidth = 0.5

    /// Weight of `band` at `frequency`. Weights are non-negative and sum to exactly 1 at every
    /// frequency, so bands with equal gains reconstruct a flat response.
    public static func weight(band: Int, frequency: Double) -> Double {
        let below = band == 0 ? 1 : rise(frequency, crossover: crossovers[band - 1])
        let above = band == count - 1 ? 1 : 1 - rise(frequency, crossover: crossovers[band])
        return below * above
    }

    /// Weight of `band` at `frequency` for measuring a response in octave bands, as ISO 3382-1 does with
    /// octave filters. It is `weight`, except that the lowest and highest bands, which `weight` leaves open
    /// down to 0 Hz and up to the Nyquist frequency so that the bands sum to one, are closed an octave
    /// beyond their inner crossover by the same half cosine. Every band then has the same shape, and the
    /// 63 Hz and 8 kHz bands don't take in what a source radiates below 31 Hz or above 16 kHz.
    public static func measurementWeight(band: Int, frequency: Double) -> Double {
        var w = weight(band: band, frequency: frequency)
        if band == 0 { w *= rise(frequency, crossover: centres[0] / 2.squareRoot()) }
        if band == count - 1 { w *= 1 - rise(frequency, crossover: centres[count - 1] * 2.squareRoot()) }
        return w
    }

    /// Smooth step from 0 below a crossover to 1 above it, as a half cosine in log frequency.
    static func rise(_ frequency: Double, crossover: Double) -> Double {
        guard frequency > 0 else { return 0 }
        let x = log2(frequency / crossover)
        let w = transitionHalfWidth
        if x <= -w { return 0 }
        if x >= w { return 1 }
        return 0.5 - 0.5 * cos(Double.pi * (x + w) / (2 * w))
    }
}
