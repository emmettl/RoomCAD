#!/usr/bin/env python3
"""Write scene.json: BRAS scene CR4, the Auditorium Maximum of TU Berlin, simplified for RoomCAD.

The dimensions are read from the faces of BRAS's model CR4_RIR_Dodecahedron.skp (see README.md and
read-skp.py), in metres in BRAS's coordinates: x runs from the stage to the back of the hall, y across it,
and z up from the stage floor, which lies 0.8 m above the front of the stalls. The room is built from pieces
of air: a long section with the stage, the raked stalls and the sloping ceiling, extruded across the hall,
with the rear balcony, the side galleries, the reflector over the stage, the ceiling panels and the seating
cut out of it, and the fan-shaped side walls and curved back wall cut away. The material rows come from
BRAS's CSV files in the cache that RoomCAD/Scripts/fetch-bras.py fills.

Usage: python3 RoomCAD/Validation/bras-cr4/make-scene.py
"""

import csv
import json
import pathlib

HERE = pathlib.Path(__file__).resolve().parent
CACHE = HERE.parent.parent / ".cache" / "bras-cr4"
NAMES = ["brickwall", "concrete", "linoleum", "parquet", "seating", "whitePanels", "windows", "woodPanels"]
WIDE = 17.5  # beyond the side walls, which the cuts below make


def material(kind, name):
    rows = [[float(x) for x in row] for row in csv.reader(open(CACHE / kind / f"mat_CR4_{name}.csv")) if row]
    return {"absorption": rows[1], "scattering": rows[2]}, rows[0]


def box(name, low, high, materials, operation="union"):
    return {"operation": operation, "name": name, "box": [low, high], "materials": materials}


def extrusion(name, points, axis, low, high, sides, ends, operation="subtract"):
    return {"operation": operation, "name": name,
            "extrusion": {"points": points, "axis": axis, "from": low, "to": high, "sides": sides, "ends": ends}}


def mirrored_box(name, low, high, materials, operation="union"):
    """A box and its mirror image across y = 0, its -y and +y materials swapped."""
    m = materials
    return [
        box(name, low, high, m, operation),
        box(name + " (other side)", [low[0], -high[1], low[2]], [high[0], -low[1], high[2]],
            [m[0], m[1], m[3], m[2], m[4], m[5]], operation),
    ]


def wall_y(x):
    """The brick side walls, splayed 8.9 degrees: through (-7.53, 11.53) and (24.78, 16.56)."""
    return 11.53 + (16.56 - 11.53) / (24.78 + 7.53) * (x + 7.53)


def gallery_edge(x):
    """The front of the side galleries, parallel to the walls: through (1.11, 10.57) and (12.49, 12.38)."""
    return 10.57 + (12.38 - 10.57) / (12.49 - 1.11) * (x - 1.11)


def stalls_floor(x):
    """The raked stalls, rising 1.8 m from x = 1.97 to 19.75."""
    return -0.80 + (1.00 + 0.80) / (19.75 - 1.97) * (x - 1.97)


def gallery_floor(x):
    """The galleries' thirteen steps, as a slope from 1.75 m at x = 0.46 to 4.51 m at x = 12.3."""
    return 1.75 + (4.51 - 1.75) / (12.3 - 0.46) * (x - 0.46)


B, C, L, P, S, W, WOOD = "brickwall", "concrete", "linoleum", "parquet", "seating", "whitePanels", "woodPanels"

# The long section, extruded across the hall: the stage at z = 0 from its back wall, which leans 0.8 m
# towards the hall over its 10 m height, to its front edge (0.31-1.08 m, here 0.85 m) 0.8 m above the
# front of the stalls; the raked stalls; the level floor behind them, under the rear balcony; the back
# wall, whose upper part leans 0.5 m towards the hall; and the ceiling slab, rising from 10.0 m over the
# stage to 13.0 m at the back.
section = [(-6.82, 0.0), (0.85, 0.0), (0.85, -0.80), (1.97, -0.80), (19.75, 1.00), (23.15, 1.00),
           (23.15, 6.74), (22.65, 13.02), (-5.99, 10.0)]
pieces = [extrusion("hall", [list(p) for p in section], 1, -WIDE, WIDE, [P, P, L, L, L, WOOD, WOOD, C, W],
                    [B, B], "union")]
# Beside the stage the floor drops to 1.25 m below it, with steps down from the stage and up to the stalls.
pieces += mirrored_box("floor beside the stage", [-2.35, 9.27, -1.25], [0.94, WIDE, 0.0], [P, L, L, B, L, P])

# The rear balcony, across the hall: its soffit at 4.0-4.26 m, its front parapet at x = 14.5 m up to
# 5.31 m (the front curves, from 14.0 to 14.7 m), a landing at 4.51 m, four rows of seats 0.9 m deep and
# 0.445 m high, and a level floor at 6.74 m to the back wall.
balcony = [(14.5, 4.24), (19.47, 4.06), (21.1, 3.98), (21.1, 4.26), (23.6, 4.26), (23.6, 6.74), (19.1, 6.74),
           (19.1, 6.29), (18.2, 6.29), (18.2, 5.85), (17.3, 5.85), (17.3, 5.40), (16.4, 5.40), (16.4, 4.96),
           (15.5, 4.96), (15.5, 4.51), (14.62, 4.51), (14.62, 5.31), (14.5, 5.31)]
pieces.append(extrusion("rear balcony", [list(p) for p in balcony], 1, -WIDE, WIDE,
                        [C, C, C, C, WOOD, L, S, S, S, S, S, S, S, S, S, L, W, W, W], [B, B]))

# The side galleries along the walls, from the stairs beside the stage (x = -2.52 m) to the rear balcony:
# a slab whose soffit rises from 1.52 to 4.24 m and whose stepped floor, with two seats a row, rises from
# 1.75 to 4.51 m. It is cut as a section from y = 9.6 m to the wall, and the air in front of its splayed
# front edge is put back.
gallery = [(-2.52, 1.52), (0.95, 1.52), (12.49, 4.24), (14.5, 4.24), (14.5, 4.51), (12.3, 4.51), (0.46, 1.75),
           (-2.52, 1.75)]
gallery_sides = [C, C, C, W, L, S, L, W]
for sign in (1, -1):
    other = " (other side)" if sign < 0 else ""
    low, high = sorted([9.6 * sign, WIDE * sign])
    pieces.append(extrusion("side gallery" + other, [list(p) for p in gallery], 1, low, high, gallery_sides,
                            [W, B] if sign > 0 else [B, W]))
    front = [(-2.52, 9.6), (14.5, 9.6), (14.5, gallery_edge(14.5)), (-2.52, gallery_edge(-2.52))]
    pieces.append(extrusion("air in front of the side gallery" + other,
                            [[x, round(y * sign, 3)] for x, y in front], 2, 1.4, 4.7, [W, W, W, W], [W, W],
                            "union"))

# The reflector over the front of the stage, 0.2 m thick: a level part at 6.46 m and a part rising from
# 6.46 m at x = -3.57 m to 9.15 m over the stage's front edge.
pieces.append(box("stage reflector, level part", [-5.0, -7.0, 6.46], [-3.57, 7.0, 6.66], [W] * 6, "subtract"))
pieces.append(extrusion("stage reflector", [[-3.57, 6.46], [-0.03, 9.15], [-0.03, 9.35], [-3.57, 6.66]], 1,
                        -8.9, 8.9, [W] * 4, [W, W]))

# The ceiling panels hung below the slab: seven rows of five, each 4 cm thick, from the front of each row
# to its back with its lower surface's height there. The last row is tilted 22 degrees.
rows = [
    ((-6.0, 9.82), (-1.75, 9.82), [(-9.89, -6.38), (-5.85, -2.41), (-1.72, 1.72), (2.41, 5.85), (6.38, 9.89)]),
    ((-2.1, 10.18), (1.95, 10.16), [(-10.39, -6.63), (-6.15, -2.38), (-1.89, 1.89), (2.38, 6.15), (6.63, 10.39)]),
    ((1.75, 10.63), (5.8, 10.45), [(-10.82, -6.94), (-6.42, -2.52), (-1.95, 1.95), (2.52, 6.42), (6.94, 10.82)]),
    ((5.62, 11.03), (9.7, 10.77), [(-11.36, -7.48), (-6.68, -2.78), (-1.95, 1.95), (2.78, 6.68), (7.48, 11.36)]),
    ((9.5, 11.44), (13.6, 11.06), [(-11.86, -7.82), (-6.96, -2.91), (-2.03, 2.03), (2.91, 6.96), (7.82, 11.86)]),
    ((13.35, 11.85), (17.45, 11.37), [(-12.35, -8.16), (-7.24, -3.03), (-2.11, 2.11), (3.03, 7.24), (8.16, 12.35)]),
    ((17.45, 12.27), (20.8, 10.97), [(-12.7, -8.53), (-7.41, -3.21), (-2.1, 2.1), (3.21, 7.41), (8.53, 12.7)]),
]
for r, ((x0, z0), (x1, z1), spans) in enumerate(rows):
    for p, (y0, y1) in enumerate(spans):
        pieces.append(extrusion(f"ceiling panel {r + 1}.{p + 1}", [[x0, z0], [x1, z1], [x1, z1 + 0.04], [x0, z0 + 0.04]],
                                1, y0, y1, [W] * 4, [W, W]))

# Seating, as in BRAS: a material on the floor, here 1 cm thick. In the stalls, two blocks either side of
# the central aisle on the rake, and a level row between the pillars under the rear balcony.
for sign in (1, -1):
    other = " (other side)" if sign < 0 else ""
    low, high = sorted([1.25 * sign, 12.2 * sign])
    x0 = 3.0
    pieces.append(extrusion("seating, stalls" + other,
                            [[x0, round(stalls_floor(x0) - 0.01, 4)], [19.75, 0.99], [19.75, 1.01],
                             [x0, round(stalls_floor(x0) + 0.01, 4)]], 1, low, high, [L, L, S, L], [L, L]))
pieces += mirrored_box("seating, last row", [19.75, 2.31, 0.99], [21.3, 12.9, 1.01], [L, L, L, L, L, S],
                       "subtract")

# The chairs themselves, which BRAS leaves out, as fitted zones 0.9 m high over the seating. BRAS's
# CR4_ModelSimplifications.pdf counts them: in each half of the stalls 418 in 21 rows on the rake and 12 in
# the last row, between the pillars; 26 on each side gallery; and 260 on the rear balcony. Each chair's
# surface area, 1.5 m², is an estimate, as for CR3. Their absorption stays with the seating material. The
# zones over the rake and the galleries are cut into lengths, each set at its middle's floor height.
CHAIR_AREA = 1.5
CHAIRS = "Chairs counted in BRAS's CR4_ModelSimplifications.pdf; 1.5 m² of surface each, estimated."


def zone(name, low, high, count):
    return {"name": name, "box": [[round(v, 3) for v in low], [round(v, 3) for v in high]],
            "count": count, "area": CHAIR_AREA, "reference": CHAIRS}


fittings = []
for sign in (1, -1):
    other = " (other side)" if sign < 0 else ""
    y0, y1 = sorted([1.25 * sign, 12.2 * sign])
    segments = 8
    for k in range(segments):
        a = 3.0 + (19.75 - 3.0) * k / segments
        b = 3.0 + (19.75 - 3.0) * (k + 1) / segments
        floor = stalls_floor((a + b) / 2)
        fittings.append(zone(f"chairs, stalls {k + 1}{other}", [a, y0, floor + 0.01], [b, y1, floor + 0.9],
                             418 / segments))
    y0, y1 = sorted([2.31 * sign, 12.9 * sign])
    fittings.append(zone("chairs, last row" + other, [19.75, y0, 1.01], [21.3, y1, 1.9], 12))
    segments = 6
    for k in range(segments):
        a = 0.46 + (12.3 - 0.46) * k / segments
        b = 0.46 + (12.3 - 0.46) * (k + 1) / segments
        edge = gallery_edge((a + b) / 2)
        floor = gallery_floor((a + b) / 2)
        y0, y1 = sorted([(edge + 0.15) * sign, (edge + 1.25) * sign])
        fittings.append(zone(f"chairs, side gallery {k + 1}{other}", [a, y0, floor + 0.01], [b, y1, floor + 0.9],
                             26 / segments))
for k, (a, b, z) in enumerate([(15.5, 16.4, 4.96), (16.4, 17.3, 5.40), (17.3, 18.2, 5.85), (18.2, 19.1, 6.29)]):
    fittings.append(zone(f"chairs, rear balcony row {k + 1}", [a, -13.1, z + 0.01], [b, 13.1, z + 0.9], 260 / 4))

# Last, the splayed brick side walls and the curved back wall cut away everything beyond them.
for sign in (1, -1):
    other = " (other side)" if sign < 0 else ""
    outside = [(-9.0, wall_y(-9.0)), (26.0, wall_y(26.0)), (26.0, 18.0), (-9.0, 18.0)]
    pieces.append(extrusion("side wall" + other, [[x, round(y * sign, 4)] for x, y in outside], 2, -2.0, 14.0,
                            [B] * 4, [B, B]))
back = [(23.15, 0.0), (23.05, 5.0), (22.85, 8.0), (22.6, 10.8), (22.0, 13.5), (21.4, 16.4), (21.4, 18.0)]
outline = back + [(26.0, 18.0), (26.0, -18.0)] + [(x, -y) for x, y in reversed(back[1:])]
pieces.append(extrusion("back wall", [list(p) for p in outline], 2, -2.0, 14.0, [WOOD] * len(outline),
                        [WOOD, WOOD]))

initial = {}
fitted = {}
for name in NAMES:
    initial[name], frequencies = material("initial", name)
    fitted[name], _ = material("fitted", name)

scene = {
    "description": "BRAS scene CR4, the Auditorium Maximum of TU Berlin, simplified for RoomCAD. Derived from "
    "the BRAS database (Aspöck, Vorländer, Brinkmann, Ackermann and Weinzierl, TU Berlin and RWTH Aachen), "
    "CC BY-SA 4.0, https://depositonce.tu-berlin.de/items/38410727-febb-4769-8002-9c710ba393c4. See README.md "
    "for what was derived and how.",
    "frequencies": frequencies,
    "temperatureCelsius": 20.9,
    "relativeHumidity": 37.5,
    "geometry": {"pieces": pieces},
    "fittings": fittings,
    "materials": {"initial": initial, "fitted": fitted},
    "sources": {
        "LS1": {"position": [0.0, 4.5], "drivers": [1.117, 1.38, 1.68]},
        "LS2": {"position": [-2.8, -4.5], "drivers": [1.117, 1.38, 1.68]},
    },
    "driverCrossovers": [177, 1420],
    "receivers": {
        "MP1": [8.5, 0.0, 1.09], "MP2": [3.33, -7.95, 0.57], "MP3": [9.33, -6.96, 1.18],
        "MP4": [5.91, 6.34, 0.83], "MP5": [11.83, 8.43, 1.43],
    },
}
(HERE / "scene.json").write_text(json.dumps(scene, indent=1, ensure_ascii=False) + "\n")
print(f"Wrote {HERE / 'scene.json'} with {len(pieces)} pieces and {len(fittings)} fitted zones.")
