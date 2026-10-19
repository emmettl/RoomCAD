// swift-format-ignore-file: AlwaysUseLowerCamelCase, TypeNamesShouldBeCapitalized

// Linux-only vector compatibility adapted from BombCAD's MIT-licensed LinuxSIMD.swift.
// See docs/PORTABILITY.md for the source revision and arithmetic limitations.
// Apple builds always use the SDK's simd implementation.
#if !canImport(Darwin)
    import Glibc
    import simd

    /// Whether Apple's simd headers fuse `a*b - c*d` where they do not ask for it: in
    /// `simd_cross` and `simd_determinant`, which are written as single expressions and compiled
    /// with clang's default floating-point contraction. They do: on the Mac Studio (macOS 27 SDK,
    /// arm64) on 19 October 2026, LinuxSIMDParityTests found Apple's cross products, float and
    /// double, and the 3 × 3 determinant fused, and this shim, run there with this set, matched
    /// all three bit for bit.
    @usableFromInline let appleFusesCross = true

    // MARK: Lanes

    /// FMINNM: the lesser, a NaN losing to a number, -0 below +0.
    @inlinable func laneMin<T: BinaryFloatingPoint>(_ a: T, _ b: T) -> T {
        if a.isNaN { return b.isNaN ? a : b }
        if b.isNaN { return a }
        if a == b { return a.sign == .minus ? a : b }
        return a < b ? a : b
    }

    /// FMAXNM: the greater, a NaN losing to a number, +0 above -0.
    @inlinable func laneMax<T: BinaryFloatingPoint>(_ a: T, _ b: T) -> T {
        if a.isNaN { return b.isNaN ? a : b }
        if b.isNaN { return a }
        if a == b { return a.sign == .minus ? b : a }
        return a > b ? a : b
    }

    /// `simd_reduce_add`: x + y for two lanes, (x + y) + z for three, (x + z) + (y + w) for four.
    @inlinable func reduceAdd<V: SIMD>(_ v: V) -> V.Scalar where V.Scalar: BinaryFloatingPoint {
        switch v.scalarCount {
        case 2: return v[0] + v[1]
        case 3: return v[0] + v[1] + v[2]
        case 4: return (v[0] + v[2]) + (v[1] + v[3])
        default:
            var sum = V.Scalar.zero
            for i in v.indices { sum += v[i] }
            return sum
        }
    }

    /// Arm's reciprocal square root estimate, FRSQRTE, for a float: 8 bits.
    @usableFromInline func reciprocalSquareRootEstimate(_ x: Float) -> Float {
        if x.isNaN { return x + x }
        if x == 0 { return x.sign == .minus ? -.infinity : .infinity }
        if x < 0 { return .nan }
        if x == .infinity { return 0 }
        let bits = x.bitPattern
        var exponent = Int((bits >> 23) & 0xff)
        var fraction = UInt64(bits & 0x7f_ffff) << 29  // 52 bits, as the pseudocode has it
        if exponent == 0 {
            while fraction & (1 << 51) == 0 {
                fraction <<= 1
                exponent -= 1
            }
            fraction = (fraction << 1) & ((1 << 52) - 1)
        }
        var a =
            exponent & 1 == 0
            ? 0x100 | Int((fraction >> 44) & 0xff) : 0x80 | Int((fraction >> 45) & 0x7f)
        // RecipSqrtEstimate
        if a < 256 {
            a = a * 2 + 1
        } else {
            a = (a >> 1) << 1
            a = (a + 1) * 2
        }
        var b = 512
        while a * (b + 1) * (b + 1) < 1 << 28 { b += 1 }
        let estimate = (b + 1) / 2
        let resultExponent = (380 - exponent) / 2
        return Float(bitPattern: UInt32(resultExponent & 0xff) << 23 | UInt32(estimate & 0xff) << 15)
    }

    /// Arm's reciprocal square root step, FRSQRTS: (3 - a b) / 2, rounded once.
    @usableFromInline func reciprocalSquareRootStep(_ a: Float, _ b: Float) -> Float {
        if (a.isInfinite && b == 0) || (a == 0 && b.isInfinite) { return 1.5 }
        return Float(3).addingProduct(-a, b) / 2
    }

    /// `simd_precise_rsqrt` for a float on arm64: the estimate and two Newton steps.
    @usableFromInline func preciseReciprocalSquareRoot(_ x: Float) -> Float {
        var r = reciprocalSquareRootEstimate(x)
        r = r * reciprocalSquareRootStep(x, r * r)
        return r * reciprocalSquareRootStep(x, r * r)
    }

    /// `simd_precise_rsqrt` for a double: 1 / sqrt(x).
    @inlinable func preciseReciprocalSquareRoot(_ x: Double) -> Double { 1 / x.squareRoot() }

    @inlinable func reciprocalSquareRoot<T: BinaryFloatingPoint>(_ x: T) -> T {
        if T.self == Float.self { return T(preciseReciprocalSquareRoot(Float(x))) }
        return 1 / x.squareRoot()
    }

    // MARK: Vectors

    @inlinable public func simd_dot<V: SIMD>(_ a: V, _ b: V) -> V.Scalar
    where V.Scalar: BinaryFloatingPoint { reduceAdd(a * b) }

    // SIMD3 overloads for Float and Double, which rank above the stand-in's generic ones in any
    // module that sees both.
    @inlinable public func simd_dot(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float { reduceAdd(a * b) }

    @inlinable public func simd_dot(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double { reduceAdd(a * b) }

    @inlinable public func simd_length_squared<V: SIMD>(_ v: V) -> V.Scalar
    where V.Scalar: BinaryFloatingPoint { simd_dot(v, v) }

    @inlinable public func simd_length_squared(_ v: SIMD3<Float>) -> Float { simd_dot(v, v) }

    @inlinable public func simd_length_squared(_ v: SIMD3<Double>) -> Double { simd_dot(v, v) }

    @inlinable public func simd_length<V: SIMD>(_ v: V) -> V.Scalar
    where V.Scalar: BinaryFloatingPoint { simd_length_squared(v).squareRoot() }

    @inlinable public func simd_length(_ v: SIMD3<Float>) -> Float { simd_length_squared(v).squareRoot() }

    @inlinable public func simd_length(_ v: SIMD3<Double>) -> Double { simd_length_squared(v).squareRoot() }

    @inlinable public func simd_distance<V: SIMD>(_ a: V, _ b: V) -> V.Scalar
    where V.Scalar: BinaryFloatingPoint { simd_length(a - b) }

    @inlinable public func simd_distance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float { simd_length(a - b) }

    @inlinable public func simd_distance(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> Double {
        simd_length(a - b)
    }

    @inlinable public func simd_distance_squared<V: SIMD>(_ a: V, _ b: V) -> V.Scalar
    where V.Scalar: BinaryFloatingPoint { simd_length_squared(a - b) }

    /// x times the reciprocal square root of its squared length, as Apple's is; not x / |x|.
    @inlinable public func simd_normalize<V: SIMD>(_ v: V) -> V where V.Scalar: BinaryFloatingPoint {
        v * reciprocalSquareRoot(simd_length_squared(v))
    }

    @inlinable public func simd_normalize(_ v: SIMD3<Float>) -> SIMD3<Float> {
        v * preciseReciprocalSquareRoot(simd_length_squared(v))
    }

    @inlinable public func simd_normalize(_ v: SIMD3<Double>) -> SIMD3<Double> {
        v * preciseReciprocalSquareRoot(simd_length_squared(v))
    }

    @inlinable public func simd_cross(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> { cross3(a, b) }

    @inlinable public func simd_cross(_ a: SIMD3<Double>, _ b: SIMD3<Double>) -> SIMD3<Double> {
        cross3(a, b)
    }

    /// `(x.zxy * y - x * y.zxy).zxy`.
    @inlinable func cross3<T: BinaryFloatingPoint & SIMDScalar>(_ a: SIMD3<T>, _ b: SIMD3<T>) -> SIMD3<T> {
        if appleFusesCross {
            // Contracted, each lane is fma(first product, -(second product, rounded)).
            return SIMD3(
                (-(a.z * b.y)).addingProduct(a.y, b.z), (-(a.x * b.z)).addingProduct(a.z, b.x),
                (-(a.y * b.x)).addingProduct(a.x, b.y))
        }
        return SIMD3(a.y * b.z - a.z * b.y, a.z * b.x - a.x * b.z, a.x * b.y - a.y * b.x)
    }

    /// The simd overlay's `cross` and `dot`, which call `simd_cross` and `simd_dot`.
    @inlinable public func cross<T: BinaryFloatingPoint & SIMDScalar>(_ a: SIMD3<T>, _ b: SIMD3<T>) -> SIMD3<
        T
    > {
        cross3(a, b)
    }

    @inlinable public func dot<V: SIMD>(_ a: V, _ b: V) -> V.Scalar where V.Scalar: BinaryFloatingPoint {
        simd_dot(a, b)
    }

    @inlinable public func simd_min<V: SIMD>(_ a: V, _ b: V) -> V where V.Scalar: BinaryFloatingPoint {
        var r = a
        for i in r.indices { r[i] = laneMin(a[i], b[i]) }
        return r
    }

    @inlinable public func simd_max<V: SIMD>(_ a: V, _ b: V) -> V where V.Scalar: BinaryFloatingPoint {
        var r = a
        for i in r.indices { r[i] = laneMax(a[i], b[i]) }
        return r
    }

    @inlinable public func simd_min<V: SIMD>(_ a: V, _ b: V) -> V where V.Scalar: FixedWidthInteger {
        pointwiseMin(a, b)
    }

    @inlinable public func simd_max<V: SIMD>(_ a: V, _ b: V) -> V where V.Scalar: FixedWidthInteger {
        pointwiseMax(a, b)
    }

    @inlinable public func simd_min<T: BinaryFloatingPoint>(_ a: T, _ b: T) -> T { laneMin(a, b) }

    @inlinable public func simd_max<T: BinaryFloatingPoint>(_ a: T, _ b: T) -> T { laneMax(a, b) }

    /// `simd_min(simd_max(x, low), high)`.
    @inlinable public func simd_clamp<V: SIMD>(_ x: V, _ low: V, _ high: V) -> V
    where V.Scalar: BinaryFloatingPoint { simd_min(simd_max(x, low), high) }

    @inlinable public func simd_clamp<V: SIMD>(_ x: V, _ low: V, _ high: V) -> V
    where V.Scalar: FixedWidthInteger { pointwiseMin(pointwiseMax(x, low), high) }

    @inlinable public func simd_clamp<T: BinaryFloatingPoint>(_ x: T, _ low: T, _ high: T) -> T {
        laneMin(laneMax(x, low), high)
    }

    @inlinable public func simd_abs<V: SIMD>(_ v: V) -> V where V.Scalar: BinaryFloatingPoint {
        var r = v
        for i in r.indices { r[i] = v[i].magnitude }
        return r
    }

    /// The simd overlay's `abs` of a vector: each lane's magnitude (its sign bit cleared).
    @inlinable public func abs<V: SIMD>(_ v: V) -> V where V.Scalar: BinaryFloatingPoint { simd_abs(v) }

    /// The simd overlay's elementwise floor, ceil, trunc and sqrt: exact or correctly rounded,
    /// lane by lane, as Apple's arm64 instructions (FRINTM, FRINTP, FRINTZ, FSQRT) are.
    @inlinable public func floor<V: SIMD>(_ v: V) -> V where V.Scalar: BinaryFloatingPoint {
        var r = v
        for i in r.indices { r[i] = v[i].rounded(.down) }
        return r
    }

    @inlinable public func ceil<V: SIMD>(_ v: V) -> V where V.Scalar: BinaryFloatingPoint {
        var r = v
        for i in r.indices { r[i] = v[i].rounded(.up) }
        return r
    }

    @inlinable public func trunc<V: SIMD>(_ v: V) -> V where V.Scalar: BinaryFloatingPoint {
        var r = v
        for i in r.indices { r[i] = v[i].rounded(.towardZero) }
        return r
    }

    @inlinable public func sqrt<V: SIMD>(_ v: V) -> V where V.Scalar: BinaryFloatingPoint {
        var r = v
        for i in r.indices { r[i] = v[i].squareRoot() }
        return r
    }

    /// For three lanes, min(min(x, z), y), as Apple's is.
    @inlinable public func simd_reduce_min<V: SIMD>(_ v: V) -> V.Scalar where V.Scalar: BinaryFloatingPoint {
        switch v.scalarCount {
        case 2: return laneMin(v[0], v[1])
        case 3: return laneMin(laneMin(v[0], v[2]), v[1])
        case 4: return laneMin(laneMin(v[0], v[2]), laneMin(v[1], v[3]))
        default: return v.indices.dropFirst().reduce(v[0]) { laneMin($0, v[$1]) }
        }
    }

    @inlinable public func simd_reduce_max<V: SIMD>(_ v: V) -> V.Scalar where V.Scalar: BinaryFloatingPoint {
        switch v.scalarCount {
        case 2: return laneMax(v[0], v[1])
        case 3: return laneMax(laneMax(v[0], v[2]), v[1])
        case 4: return laneMax(laneMax(v[0], v[2]), laneMax(v[1], v[3]))
        default: return v.indices.dropFirst().reduce(v[0]) { laneMax($0, v[$1]) }
        }
    }

    // MARK: Matrices

    /// `simd_mul(matrix, vector)`: c0 y0, then two fused multiply-adds (`simd_muladd`).
    @inlinable func multiply<T: BinaryFloatingPoint & SIMDScalar>(
        _ c0: SIMD3<T>, _ c1: SIMD3<T>, _ c2: SIMD3<T>, _ v: SIMD3<T>
    ) -> SIMD3<T> {
        var r = c0 * v.x
        for i in 0..<3 { r[i] = r[i].addingProduct(c1[i], v.y) }
        for i in 0..<3 { r[i] = r[i].addingProduct(c2[i], v.z) }
        return r
    }

    /// `simd_reduce_add(c0 * (rotate1(c1) * rotate2(c2) - rotate2(c1) * rotate1(c2)))`.
    @inlinable func matrixDeterminant<T: BinaryFloatingPoint & SIMDScalar>(
        _ c0: SIMD3<T>, _ c1: SIMD3<T>, _ c2: SIMD3<T>
    ) -> T {
        let p = SIMD3(c1.y, c1.z, c1.x)
        let q = SIMD3(c2.z, c2.x, c2.y)
        let s = SIMD3(c1.z, c1.x, c1.y)
        let t = SIMD3(c2.y, c2.z, c2.x)
        var d = SIMD3<T>()
        for i in 0..<3 {
            d[i] = appleFusesCross ? (-(s[i] * t[i])).addingProduct(p[i], q[i]) : p[i] * q[i] - s[i] * t[i]
        }
        return reduceAdd(c0 * d)
    }

    extension simd_double3x3 {
        @_disfavoredOverload
        public static func * (a: simd_double3x3, v: SIMD3<Double>) -> SIMD3<Double> {
            multiply(a.columns.0, a.columns.1, a.columns.2, v)
        }

    }

    public func all<Storage>(_ mask: SIMDMask<Storage>) -> Bool { mask == SIMDMask(repeating: true) }
#endif
