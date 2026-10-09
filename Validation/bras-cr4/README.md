# BRAS scene CR4, the auditorium

These files describe a measured room for comparison with RoomCAD (see
[RoomCAD against measured rooms](../../../docs/roomcad-validation.md)). The room is the Auditorium
Maximum of TU Berlin, a lecture hall for about 1,200 people. The files are derived from the Benchmark
for Room Acoustical Simulation (BRAS):

> L. Aspöck, M. Vorländer, F. Brinkmann, D. Ackermann and S. Weinzierl, *Benchmark for Room
> Acoustical Simulation (BRAS)*, TU Berlin and RWTH Aachen, 2020, DOI 10.14279/depositonce-6726.3,
> https://depositonce.tu-berlin.de/items/38410727-febb-4769-8002-9c710ba393c4

BRAS is licensed under the Creative Commons Attribution-ShareAlike 4.0 International licence
(https://creativecommons.org/licenses/by-sa/4.0/), as the repository's record states. These derived
files are distributed under the same licence. They contain neither BRAS's impulse responses nor its
models. `RoomCAD/Scripts/fetch-bras.py CR4` fetches the source files into `RoomCAD/.cache`, which git
ignores.

## Source files

`fetch-bras.py` reads them, with HTTP range requests, from two of the record's archives:

- `1_scene_descriptions-CR4.zip` (785,106,943 bytes, MD5 `d0e09fbbbe2b9af501cb9d3c86368bd1`), bitstream
  `bad0610b-293c-47cb-9926-c30c32f9b4c8`, folder `1 Scene descriptions/CR4 large room (auditorium)/`;
- `3_surface_descriptions.zip` (235,694,104 bytes, MD5 `c6457c67b4b073bf6cad39fa937ce313`), bitstream
  `b2970524-fb10-482a-ab14-f07da5ad7615`.

The air's temperature and humidity, the volume and the room's name come from the record's
`Documentation.pdf` (MD5 `19fa6422aa13b16592ddd13f0b25c936`), page 28.

The files used, with their SHA-256 checksums:

| File | SHA-256 |
|---|---|
| `Geometry/CR4_RIR_Dodecahedron.skp` | `4c00e290257f27f263e08bfcb0a99ab9ad47259a23bc6c6c86b6cbace40261f7` |
| `Geometry/CR4_RIR_Dodecahedron.png` | `cf8b0a390fff837db1a6bdfea819e693d5739264f478cca6170d463b473a7e8c` |
| `Geometry/CR4_ModelSimplifications.pdf` | `08f0afeb8bf13fb3bca49f6808dd10316ad7af279659cc0c7b74c26d8410304c` |
| `Pictures/Details/0_roomPlan.pdf` | `86913b4442b366147bc537a203673e4685ed1c32b839bf9efe666df07e0e51be` |
| `Pictures/CR4_Overview1.jpg` | `f0e496cedade2c6c256796db61e0ed5e1cd831d2b2b80eacb5b7497b14ade44d` |
| `Pictures/CR4_Overview2.jpg` | `9ec9c338c6d6cfd75b9ace0ce17b662d6856643e7d203ecd0fd96cfbe4b6e0a2` |
| `RIRs/wav/CR4_RIR_LS1_MP1_Dodecahedron.wav` | `2f7a71f412513fd4fb1b665274c5ba4fe713e95b40f6a0bfd13083ad93009c1d` |
| `RIRs/wav/CR4_RIR_LS1_MP2_Dodecahedron.wav` | `a4adf3f952a017fa7b03a02696f3df32b522e76d0ae03bf638f892cb80fd991e` |
| `RIRs/wav/CR4_RIR_LS1_MP3_Dodecahedron.wav` | `27a6696e0400a9f8dba28aea53528f05776c522a146a255926454525a7a4b270` |
| `RIRs/wav/CR4_RIR_LS1_MP4_Dodecahedron.wav` | `b97144d51a876507250d93228e6c67c6e065e9898818687ca968c38ccb73e27d` |
| `RIRs/wav/CR4_RIR_LS1_MP5_Dodecahedron.wav` | `a129a50ef029678ea7d7a36063ecccbc4cef19b24ead0ca0f1797e64009dfe36` |
| `RIRs/wav/CR4_RIR_LS2_MP1_Dodecahedron.wav` | `6890c2ead99dd048283da7d5479d57659731cfad4e4cdbbc2bd104424c5c9052` |
| `RIRs/wav/CR4_RIR_LS2_MP2_Dodecahedron.wav` | `425725841784e08b1fabf3cb670e594c8999a1466e9b7608bf9cfaa1baac1e96` |
| `RIRs/wav/CR4_RIR_LS2_MP3_Dodecahedron.wav` | `289c9dcc1b773ce7ca0fc38277aad19be0e135e34beef3d44ff347c01c50a733` |
| `RIRs/wav/CR4_RIR_LS2_MP4_Dodecahedron.wav` | `dd7d1a3d2e7bc45021b9755f4f6eccd79fe1845fe980683db01a2171dda48889` |
| `RIRs/wav/CR4_RIR_LS2_MP5_Dodecahedron.wav` | `7451c2b6fa514be67cc13c0c54cfbe80a502e39bfb4af730e629f39c6948a747` |
| `3 Surface descriptions/_descr/mat_CR4.txt` | `0aed5b8ed016e2d0fafcf1511569464761af57b4ff55c57ac16ca936439d901a` |
| `_csv/initial_estimates/mat_CR4_brickwall.csv` | `efdb0cf8dd7097a6f6073afd3c76645c580fd03cd2ab81f6106fbcebf595c1c9` |
| `_csv/initial_estimates/mat_CR4_concrete.csv` | `15ac51c6d86c9fe5a8bb39b7a348dd0ecbedc273d5a7a0295d48e930f79f2f7f` |
| `_csv/initial_estimates/mat_CR4_linoleum.csv` | `a2afc5f170c34f245a4083eeca404b66a84a6d8597e9baa5f30f0fa20664b0db` |
| `_csv/initial_estimates/mat_CR4_parquet.csv` | `bbc4414e4f6bbcbe97a98ef340b8619a72fcecb2a5674ce2864bb591398bce86` |
| `_csv/initial_estimates/mat_CR4_seating.csv` | `fdf886b911c557747d7699e076cad943143dedd98cc88fd12c9a46ca2118fea3` |
| `_csv/initial_estimates/mat_CR4_whitePanels.csv` | `b7dacf5e72f5ac5a6695113ab860f38c04de84a241dc466a6dd44143c8922d1f` |
| `_csv/initial_estimates/mat_CR4_windows.csv` | `cbcb397f63a4933a177509204db488084ee3c373083107c7d34ca4106757e80e` |
| `_csv/initial_estimates/mat_CR4_woodPanels.csv` | `a465c886a6459f0d147cc71b51e2071fbf7fc48a73840aeb12fb47d459ccc909` |
| `_csv/fitted_estimates/mat_CR4_brickwall.csv` | `b1cc869677ab1599229a996072206a554ec1e83c8ec7728897c1fe82e12c61d8` |
| `_csv/fitted_estimates/mat_CR4_concrete.csv` | `954d4d20bcb717657cb0bc497339f302f33ab03e2203b46b5524b1b3f7697889` |
| `_csv/fitted_estimates/mat_CR4_linoleum.csv` | `69abf8b8344babbf7a241dda98c595c713aba44e4ec63f1e014d6250cc4f41ee` |
| `_csv/fitted_estimates/mat_CR4_parquet.csv` | `f277e302468b7ac1bf90aca1192649cbdbc673168cc505fd07780e706e3e1593` |
| `_csv/fitted_estimates/mat_CR4_seating.csv` | `5bc5abf6bd3c990a570397afb4d6f5cae07515f2b593873be9a405e8922a22b4` |
| `_csv/fitted_estimates/mat_CR4_whitePanels.csv` | `4c6469d22744778ea24d5d2882523b6d9300d66559bf3715d65f95e03a040140` |
| `_csv/fitted_estimates/mat_CR4_windows.csv` | `961774e976a511e3c3430e2ff605c4acaad56e59794dd5f3f8ce7dcf0eae910a` |
| `_csv/fitted_estimates/mat_CR4_woodPanels.csv` | `60cf70c32cc32998ef974d262655a233a59b38259fc11a053f2d361aff0824d7` |

## `scene.json`

`make-scene.py` writes this file. As for CR3, it describes the room as pieces of air: extrusions and
boxes that are joined or cut away. RoomCAD builds a closed mesh from them with `Solid`; it has
1,343 faces.

### Geometry

The dimensions are read from the faces of `CR4_RIR_Dodecahedron.skp`, in metres, in BRAS's
coordinates:

- **x** runs from the stage to the back of the hall;
- **y** runs across it;
- **z** runs up from the stage floor.

The model is a SketchUp 2015 file. `read-skp.py` reads its 1,826 room faces with their materials, and
their areas match BRAS's own list in `mat_CR4.txt` (5,783 m² of 5,851 m²). Sections and plans cut
through those faces gave the dimensions below. The pieces are:

- **The long section.** The stage floor is at 0 m, from its back wall to a front edge at x = 0.85 m
  (the real edge runs from 0.31 to 1.08 m). The back wall is white panels between concrete pillars and
  leans 0.8 m towards the hall over its 10 m. The stalls start 0.8 m below the stage and rise 1.8 m over
  17.8 m, in 22 rows. Behind them, under the rear balcony, the floor is level at 1.0 m. The back wall,
  of wood panels, is at x = 23.15 m on the axis, and its upper part leans 0.5 m towards the hall. The
  ceiling slab rises from 10.0 m over the stage to 13.0 m at the back. The section is extruded across
  the hall.
- **The floor beside the stage.** It drops to 1.25 m below the stage on each side, between the stage
  and the walls.
- **The rear balcony.** It runs across the hall. Its soffit is at 4.0–4.26 m, and its front parapet,
  at x = 14.5 m, rises to 5.31 m. Behind a landing at 4.51 m there are four rows of seats, 0.9 m deep
  and 0.445 m high, and then a level floor at 6.74 m reaching to the back wall.
- **The side galleries.** They run along the walls from beside the stage to the rear balcony. The
  soffit rises from 1.52 to 4.24 m, and the floor from 1.75 to 4.51 m. They are cut as a section from
  y = ±9.6 m to the walls, and the air in front of their splayed front edge is put back.
- **The stage reflector.** It is 0.2 m thick, with a level part at 6.46 m and a part rising to 9.15 m
  over the stage's front edge.
- **The ceiling panels.** There are seven rows of five, each 4 cm thick, below the slab at 9.8–12.3 m.
  Each panel keeps its own position, size and tilt.
- **The side walls.** These are brick, splayed at 8.9° from the axis, 23.3 m apart at the stage's back
  wall and 32.1 m apart at the back. Everything beyond them is cut away.
- **The back wall.** It curves forward towards the sides, from x = 23.15 m on the axis to 21.4 m at the
  walls.
- **Seating.** As in BRAS, seating is a material on the floor. In the stalls it is a 1 cm layer on the
  rake either side of the central aisle, and in a level row under the rear balcony. On the galleries and
  the rear balcony it covers the stepped floors.

The volume is 8,727 m³, against 8,650 m³ in BRAS's documentation. The surface area is 4,963 m², against
5,851 m² in BRAS's model.

### What is left out

- The folds of the concrete ceiling above the panels. The model has a flat slab, so it is slightly too
  high on average, by about 0.3 m.
- The pillars under the rear balcony and between the white panels behind the stage.
- The two lobbies in the back corners under the balcony, which are about 110 m³ in all.
- The stairs, the steps of the gallery floors (which are a slope here), the control booth in the rear
  balcony and the parapets of the side galleries.
- The four small windows in the back wall.
- The chairs, which are modelled as a flat layer.

Most of the missing area is concrete, from the folded ceiling and the pillars, and linoleum, from the
stairs and lobbies.

### Material areas

| Material | Here (m²) | BRAS (m²) |
|---|---|---|
| Linoleum | 432 | 638 |
| Concrete | 1,142 | 1,774 |
| Seating | 637 | 557 |
| Brick wall | 613 | 699 |
| Wood panels | 308 | 326 |
| White panels | 1,642 | 1,655 |
| Parquet | 189 | 193 |
| Windows | 0 | 8.5 |

Here, the seating also covers the ends of the rows on the rear balcony and the galleries, beside the
aisles.

### Materials, positions and air

- **Material data.** The absorption and scattering rows are copied from BRAS's
  `3 Surface descriptions/_csv/{initial,fitted}_estimates/mat_CR4_*.csv`, in third octaves.
- **Positions.**
  - The sources and receivers are read from the labels in `CR4_RIR_Dodecahedron.png` and the model.
  - Each source is a dodecahedron with three drivers, at 1.117, 1.38 and 1.68 m above the stage.
  - The crossovers between drivers, at 177 Hz and 1.42 kHz, come from BRAS's documentation.
  - The receivers are 1.23 m above the raked floor.
- **Air.** The temperature (20.9 °C) and humidity (37.5%) are BRAS's measurement conditions.
- **Chairs.** `CR4_ModelSimplifications.pdf` counts the chairs:
  - in each half of the stalls, 418 in 21 rows on the rake and 12 in the last row, between the pillars;
  - 26 on each side gallery;
  - 260 on the rear balcony.

  That is 1,172 chairs. `mat_CR4.txt` gives 1,192 seats, and the difference is not explained. The
  chairs are fitted zones 0.9 m high over the seating, each with an estimated 1.5 m² of surface, as for
  CR3. Over the rake and the galleries, the zones are cut into lengths, each set at its middle's floor
  height.

## `measured.json`

`acousticbench --bras-cr4 --update-fixture` derives this file from the ten dodecahedron room impulse
responses `CR4_RIR_LS{1,2}_MP{1–5}_Dodecahedron.wav`, as for CR2 and CR3. For each source and receiver
pair it gives:

- the ISO 3382-1 parameters in each octave band, the 63 Hz and 8 kHz bands closed below about 31 Hz and above
  about 16 kHz like the others, with Lundeby's noise compensation (see the comparison's Method; the file was
  rebuilt in October 2026, when both were corrected);
- the low-frequency spectrum, 30–175 Hz, at 1/24-octave steps;
- the early reflections above 500 Hz, in 1 ms bins.
