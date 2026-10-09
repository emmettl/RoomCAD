import Foundation

/// Published octave-band coefficients for common surfaces, to fill in a `SurfaceMaterial`.
public struct MaterialPreset: Identifiable, Equatable, Sendable {
    public var id: String
    public var category: String
    public var name: String
    /// As published, from 125 Hz upwards: six bands to 4 kHz or seven to 8 kHz (fewer for some
    /// scattering data).
    public var published: [Double]
    /// For an absorption preset, the ID of a published scattering preset for the same kind of surface,
    /// since the absorption data has no scattering; nil where none fits.
    public var scatteringID: String? = nil
    /// The category rule that assigns that scattering, for the material's reference.
    public var scatteringRule: String? = nil

    /// One value per band of `OctaveBands`. The 63 Hz band, which the data does not cover, takes the
    /// 125 Hz value, and bands above the last published one take its value.
    public var coefficients: [Double] {
        (0..<OctaveBands.count).map { band in
            band == 0 ? published[0] : published[min(band - 1, published.count - 1)]
        }
    }

    /// Bands whose values are extended rather than published, as nominal frequencies.
    public var extendedBands: [Int] {
        [OctaveBands.nominalCentres[0]] + OctaveBands.nominalCentres.dropFirst(published.count + 1)
    }

    /// How the coefficients were obtained, for a material's reference.
    public var reference: String {
        let extended = extendedBands.map { $0 >= 1000 ? "\($0 / 1000) kHz" : "\($0) Hz" }
        return "Vorländer, Auralization (Springer, 2008), annex, via pyroomacoustics: \(name). "
            + "\(extended.joined(separator: " and ")) extended from the nearest published band."
    }

    /// For an absorption preset, the published scattering assigned to it by category, if any.
    public var scattering: MaterialPreset? {
        scatteringID.flatMap { id in MaterialPresets.scattering.first { $0.id == id } }
    }

    /// How that scattering was obtained, for a material's reference.
    public var scatteringReference: String? {
        guard let scattering, let scatteringRule else { return nil }
        return "\(scattering.reference) Assigned by category: \(scatteringRule)"
    }
}

public enum MaterialPresets {
    /// Absorption coefficients for 90 surfaces, in 11 categories.
    public static let absorption: [MaterialPreset] = absorptionTable.map { row in
        let rule = scatteringRules.first { $0.absorption.contains(row.id) }
        return MaterialPreset(
            id: row.id, category: row.category, name: row.name, published: row.coefficients,
            scatteringID: rule?.scattering, scatteringRule: rule?.rule)
    }

    /// Scattering coefficients for diffusers, seating and audience, and studio wall and ceiling boxes.
    public static let scattering: [MaterialPreset] = scatteringTable.map {
        MaterialPreset(id: $0.id, category: $0.category, name: $0.name, published: $0.coefficients)
    }

    /// Scattering for absorption presets, by category. An absorption preset takes a published scattering
    /// preset only where that preset measured the same kind of surface, and its reference says so. No
    /// other source with a licence that allows bundling gives scattering for the remaining surfaces, so
    /// they have none.
    ///
    /// The annex's theatre audience goes to every area of seated audience, but not to an orchestra on
    /// its podium or to empty seats, which it does not describe.
    static let scatteringRules: [(scattering: String, rule: String, absorption: [String])] = [
        (
            "theatre_audience",
            "the annex gives scattering for theatre audience, not for this entry, and it is used here for "
                + "every area of seated audience.",
            [
                "audience_orchestra_choir", "audience_wooden_chairs_1_m2", "audience_wooden_chairs_2_m2",
                "audience_0.72_m2", "audience_1_m2", "audience_1.5_m2", "audience_2_m2",
                "audience_upholstered_chairs_1", "audience_upholstered_chairs_2",
            ]
        )
    ]

    /// Category names in their published order.
    public static func categories(of presets: [MaterialPreset]) -> [String] {
        var seen: [String] = []
        for preset in presets where !seen.contains(preset.category) { seen.append(preset.category) }
        return seen
    }
}

extension SurfaceMaterial {
    /// This material with a preset's absorption and name. Where published scattering is assigned to the
    /// preset by category, it takes that too; otherwise its scattering is kept, because the absorption
    /// data does not include scattering.
    public func applying(absorption preset: MaterialPreset) -> SurfaceMaterial {
        var material = self
        material.name = preset.name
        material.absorption = preset.coefficients
        material.reference = "Absorption: \(preset.reference)"
        if let scattering = preset.scattering, let note = preset.scatteringReference {
            material.scattering = scattering.coefficients
            material.reference += " Scattering: \(note)"
        }
        return material
    }

    /// This material with a preset's scattering; its absorption and name are kept.
    public func applying(scattering preset: MaterialPreset) -> SurfaceMaterial {
        var material = self
        material.scattering = preset.coefficients
        let absorption =
            material.reference.components(separatedBy: " Scattering: ").first ?? material.reference
        material.reference = "\(absorption) Scattering: \(preset.reference)"
        return material
    }
}
