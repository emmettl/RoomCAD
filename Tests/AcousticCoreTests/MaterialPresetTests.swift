import Testing

@testable import AcousticCore

@Suite("Material presets")
struct MaterialPresetTests {
    private func preset(_ id: String, in presets: [MaterialPreset] = MaterialPresets.absorption) throws
        -> MaterialPreset
    {
        try #require(presets.first { $0.id == id })
    }

    @Test("Every published preset gives a valid material")
    func allValid() throws {
        #expect(MaterialPresets.absorption.count == 90)
        #expect(MaterialPresets.scattering.count == 7)
        #expect(MaterialPresets.categories(of: MaterialPresets.absorption).count == 11)
        #expect(Set(MaterialPresets.absorption.map(\.id)).count == 90)
        let base = SurfaceMaterial.uniform(0.2, scattering: 0.3, name: "Base")
        for preset in MaterialPresets.absorption {
            #expect((5...7).contains(preset.published.count), "\(preset.id)")
            try base.applying(absorption: preset).validate()
        }
        for preset in MaterialPresets.scattering {
            try base.applying(scattering: preset).validate()
        }
    }

    @Test("Values match the source, with 63 Hz and missing high bands taken from the nearest published band")
    func values() throws {
        let carpet = try preset("carpet_cotton")
        #expect(carpet.name == "Cotton carpet")
        #expect(carpet.coefficients == [0.07, 0.07, 0.31, 0.49, 0.81, 0.66, 0.54, 0.48])
        #expect(carpet.extendedBands == [63])

        let lead = try preset("lead_glazing")
        #expect(lead.published == [0.3, 0.2, 0.14, 0.1, 0.05, 0.05])
        #expect(lead.coefficients == [0.3, 0.3, 0.2, 0.14, 0.1, 0.05, 0.05, 0.05])
        #expect(lead.extendedBands == [63, 8000])
        #expect(lead.reference.contains("63 Hz and 8 kHz extended"))

        #expect(try preset("rough_concrete").coefficients[6] == 0.07)
        let skyline = try preset("rpg_skyline", in: MaterialPresets.scattering)
        #expect(skyline.coefficients == [0.01, 0.01, 0.08, 0.45, 0.82, 1.0, 1.0, 1.0])
    }

    @Test("Absorption presets keep a surface's scattering, and scattering presets its absorption")
    func independent() throws {
        let base = SurfaceMaterial.uniform(0.2, scattering: 0.3, name: "Base")
        let carpeted = base.applying(absorption: try preset("carpet_cotton"))
        #expect(carpeted.name == "Cotton carpet")
        #expect(carpeted.scattering == base.scattering)
        #expect(carpeted.reference.hasPrefix("Absorption: Vorländer"))

        let audience = try preset("theatre_audience", in: MaterialPresets.scattering)
        let scattered = carpeted.applying(scattering: audience)
        #expect(scattered.absorption == carpeted.absorption)
        #expect(scattered.name == "Cotton carpet")
        #expect(scattered.scattering == audience.coefficients)
        // Choosing again replaces the scattering note rather than adding another.
        let again = scattered.applying(
            scattering: try preset("classroom_tables", in: MaterialPresets.scattering))
        #expect(again.reference.components(separatedBy: "Scattering:").count == 2)
        #expect(again.reference.contains("classroom tables"))
    }

    @Test(
        "Areas of seated audience take the published theatre audience scattering, labelled as a category rule"
    )
    func assignedScattering() throws {
        let scattered = MaterialPresets.absorption.filter { $0.scattering != nil }
        #expect(scattered.count == 9)
        #expect(scattered.allSatisfy { $0.category.hasPrefix("Audience") })
        #expect(try preset("orchestra_1.5_m2").scattering == nil)
        #expect(
            MaterialPresets.absorption.filter { $0.category.hasPrefix("Seating") && $0.scattering != nil }
                .isEmpty)

        let audience = try preset("theatre_audience", in: MaterialPresets.scattering)
        let base = SurfaceMaterial.uniform(0.2, scattering: 0.3, name: "Base")
        for preset in scattered {
            let scattering = try #require(preset.scattering)
            #expect(scattering.coefficients.allSatisfy { (0...1).contains($0) }, "\(preset.id)")
            let material = base.applying(absorption: preset)
            try material.validate()
            #expect(material.absorption == preset.coefficients)
            #expect(material.scattering == audience.coefficients, "\(preset.id)")
            #expect(material.reference.hasPrefix("Absorption: Vorländer"), "\(preset.id)")
            #expect(material.reference.contains("Scattering: Vorländer, Auralization"), "\(preset.id)")
            #expect(material.reference.contains("Theatre Audience. 63 Hz extended"), "\(preset.id)")
            #expect(material.reference.contains("Assigned by category"), "\(preset.id)")
            // A scattering preset chosen afterwards replaces the note rather than adding another.
            let chosen = material.applying(
                scattering: try self.preset("classroom_tables", in: MaterialPresets.scattering))
            #expect(chosen.reference.components(separatedBy: "Scattering:").count == 2)
            #expect(!chosen.reference.contains("Assigned by category"))
        }

        // The rest keep the surface's scattering.
        for preset in MaterialPresets.absorption where preset.scattering == nil {
            #expect(preset.scatteringReference == nil)
            let material = base.applying(absorption: preset)
            #expect(material.scattering == base.scattering, "\(preset.id)")
            #expect(!material.reference.contains("Scattering:"), "\(preset.id)")
        }
    }

    @Test("Whole-room presets keep their own scattering and a single scattering note")
    func roomPresetsUnchanged() throws {
        // The halls' seating chooses theatre audience itself, which replaces the assigned note.
        let audience = try preset("theatre_audience", in: MaterialPresets.scattering)
        let chairs = try preset("audience_upholstered_chairs_1")
        let seats = SurfaceMaterial.uniform(0, name: "").applying(absorption: chairs)
        let chosen = seats.applying(scattering: audience)
        #expect(chosen.scattering == seats.scattering)
        #expect(chosen.reference == "Absorption: \(chairs.reference) Scattering: \(audience.reference)")

        let settings = RoomResponseSettings(
            room: ShoeboxRoom(size: [5, 4, 3], material: .rigid),
            source: RoomPoint(name: "Speaker", position: [1, 1, 1]),
            receivers: [RoomPoint(name: "Mic", position: [3, 2, 1])])
        for room in RoomPresets.all {
            for (_, material) in room.applied(to: settings).room.boundaries {
                #expect(
                    material.reference.components(separatedBy: "Scattering:").count == 2,
                    "\(room.id) \(material.name)")
            }
        }
    }
}
