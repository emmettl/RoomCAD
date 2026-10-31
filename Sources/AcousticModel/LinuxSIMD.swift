// Linux-only vector compatibility adapted from BombCAD's MIT-licensed LinuxSIMD.swift.
// ContinuumKit's `simd` stand-in supplies the vector, matrix and quaternion arithmetic;
// only the mask reduction it lacks remains here. See docs/PORTABILITY.md.
// Apple builds always use the SDK's simd implementation.
#if !canImport(Darwin)
    import simd

    public func all<Storage>(_ mask: SIMDMask<Storage>) -> Bool { mask == SIMDMask(repeating: true) }
#endif
