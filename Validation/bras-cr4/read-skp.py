#!/usr/bin/env python3
"""Read the room's faces from BRAS's model CR4_RIR_Dodecahedron.skp, for checking make-scene.py against it.

A SketchUp 2015 file is an MFC archive: each object is written once, with a two-byte tag for its class
(0x8000 | class index) or a reference to an object already written (its index, or 0x7fff and a four-byte
index). This reads only the room's surfaces, which the model keeps at its top level after the source and
receiver meshes: each face with its plane, its loops of edge uses, their edges and vertices, and its
material. It does not parse the rest of the format. Each face is read on its own, and the indices of the
objects it creates are found from the edge uses' references back to their loop, so a face it cannot read
costs only that face. Faces carrying RAVEN attributes (the head and loudspeaker meshes) are skipped.

The material references were matched to BRAS's names by their order in the file, and they reproduce the
areas in BRAS's mat_CR4.txt: 1,826 faces, 5,783 m² against 5,851 m². The faces it cannot read, about
70 m², are mostly concrete.

Usage: python3 RoomCAD/Validation/bras-cr4/read-skp.py [--faces OUT.json]
"""

import json
import pathlib
import re
import struct
import sys

HERE = pathlib.Path(__file__).resolve().parent
MODEL = HERE.parent.parent / ".cache" / "bras-cr4" / "scene" / "CR4_RIR_Dodecahedron.skp"
INCH = 0.0254
FACE, LOOP, EDGE_USE, EDGE, VERTEX, ATTRIBUTES = 0xBA, 0xBC, 0xBE, 0x3D, 0x3F, 0x05
MATERIALS = {0x10: "linoleum", 0x14: "brickwall", 0x18: "parquet", 0x1C: "whitePanels", 0x1F: "seating",
             0x23: "woodPanels", 0x25: "concrete", 0x29: "windows"}
BRAS_AREAS = {"linoleum": 637.99, "concrete": 1773.89, "seating": 557.42, "brickwall": 698.50,
              "woodPanels": 326.18, "whitePanels": 1655.39, "parquet": 193.48, "windows": 8.50}
TOP_LEVEL = 18_400_000  # where the room's surfaces start, after the meshes of the heads and sources
FLAGS = b"\x00\x01\x01\x00\x00\x00\x00\x00"


class Unreadable(Exception):
    pass


class Reader:
    def __init__(self, data, position, created=0):
        self.data = data
        self.p = position
        self.created = created

    def take(self, form):
        value = struct.unpack_from(form, self.data, self.p)
        self.p += struct.calcsize(form)
        return value

    def object(self):
        """("null",), ("ref", index) or ("new", class index, index counted from where reading began)."""
        (tag,) = self.take("<H")
        if tag == 0:
            return ("null",)
        if tag == 0xFFFF:
            raise Unreadable("a class defined here")
        if tag == 0x7FFF:
            (big,) = self.take("<I")
            if not big & 0x80000000:
                return ("ref", big)
            tag, big = None, big & 0x7FFFFFFF
        if tag is None or tag & 0x8000:
            self.created += 1
            return ("new", big if tag is None else tag & 0x7FFF, self.created - 1)
        return ("ref", tag)

    def skip_textured_header(self):
        """An attribute container holding texture coordinates: skip to the flags that end the header."""
        if self.data[self.p:self.p + 4] != b"\x00\x00\xff\x7f":
            raise Unreadable("attributes")
        end = self.data.find(FLAGS, self.p, self.p + 800)
        if end < 0:
            raise Unreadable("header")
        self.created += 1  # the texture coordinates
        material = struct.unpack_from("<H", self.data, end - 2)[0]
        self.p = end + 8
        return material

    def edge(self, vertices):
        """An edge's body: its header, two vertices (new or referenced) and no curve."""
        attributes = self.object()
        if attributes[0] == "new" and attributes[1] == ATTRIBUTES:
            self.skip_textured_header()
        elif attributes[0] == "null":
            self.object()
            self.p += 8
        else:
            raise Unreadable("edge attributes")
        ends = []
        for _ in range(2):
            v = self.object()
            if v[0] == "new" and v[1] == VERTEX:
                if self.object()[0] != "null":
                    raise Unreadable("vertex attributes")
                vertices[("new", v[2])] = self.take("<3d")
                ends.append(("new", v[2]))
            elif v[0] == "ref":
                ends.append(v)
            else:
                raise Unreadable("vertex")
        if self.object()[0] == "new":
            raise Unreadable("curve")
        return tuple(ends)


def read_face(data, position):
    r = Reader(data, position)
    tag = r.object()
    if tag[:2] != ("new", FACE):
        raise Unreadable("not a face")
    attributes = r.object()
    if attributes[0] == "new":
        if data[r.p:r.p + 4] == b"\x00\x00\x07\x80":
            raise Unreadable("RAVEN attributes")
        # The plane follows the header, then the loop count and the first loop's tag.
        for q in range(r.p, r.p + 800):
            if data[q + 36:q + 38] == b"\xbc\x80" and 1 <= struct.unpack_from("<I", data, q + 32)[0] <= 50:
                n = struct.unpack_from("<4d", data, q)
                if abs(n[0] ** 2 + n[1] ** 2 + n[2] ** 2 - 1) < 1e-9:
                    break
        else:
            raise Unreadable("plane")
        material = struct.unpack_from("<H", data, q - 10)[0]
        r.p = q
    else:
        m = r.object()
        material = m[1] if m[0] == "ref" else None
        r.p += 8
    normal = r.take("<3d")
    (offset,) = r.take("<d")
    if abs(sum(c * c for c in normal) - 1) > 1e-6:
        raise Unreadable("normal")
    (count,) = r.take("<I")
    vertices, edges, loops, backs = {}, {}, [], set()
    for _ in range(count):
        loop = r.object()
        if loop[:2] != ("new", LOOP) or r.object()[0] != "null":
            raise Unreadable("loop")
        r.p += 2
        uses = []
        while True:
            use = r.object()
            if use[0] == "null":
                break
            if use[:2] != ("new", EDGE_USE) or r.object()[0] != "null":
                raise Unreadable("edge use")
            e = r.object()
            if e[0] == "new" and e[1] == EDGE:
                edges[("new", e[2])] = r.edge(vertices)
                key = ("new", e[2])
            elif e[0] == "ref":
                key = e
            else:
                raise Unreadable("edge")
            reverse = data[r.p]
            r.p += 1
            back = r.object()
            if reverse not in (0, 1) or back[0] != "ref":
                raise Unreadable("edge use end")
            backs.add(back[1] - loop[2])
            uses.append((key, reverse))
        loops.append(uses)
    if len(backs) != 1:
        raise Unreadable("indices")
    base = backs.pop()
    return dict(position=position, end=r.p, base=base, created=r.created, material=MATERIALS.get(material),
                normal=normal, offset=offset * INCH, loops=loops, vertices=vertices, edges=edges)


def standalone_edges(data, start, end, base):
    """Edges written between faces, with the vertices they create."""
    r = Reader(data, start, base)
    vertices, edges = {}, {}
    try:
        while r.p < end:
            o = r.object()
            if o[0] == "new":
                if o[1] != EDGE:
                    break
                edges[o[2]] = r.edge(vertices)
    except (Unreadable, struct.error):
        pass
    return vertices, edges


def faces(data):
    found = []
    for m in re.finditer(rb"\xba\x80", data[TOP_LEVEL:]):
        try:
            found.append(read_face(data, TOP_LEVEL + m.start()))
        except (Unreadable, struct.error):
            pass
    found.sort(key=lambda f: f["position"])

    def absolute(face, key):
        return face["base"] + key[1] if key[0] == "new" else key[1]

    V, E = {}, {}
    for f in found:
        V.update({absolute(f, k): v for k, v in f["vertices"].items()})
        E.update({absolute(f, k): tuple(absolute(f, e) for e in ends) for k, ends in f["edges"].items()})
    for a, b in zip(found, found[1:]):
        v, e = standalone_edges(data, a["end"], b["position"], a["base"] + a["created"])
        # Counted from the face before, these indices are absolute already.
        V.update({k[1]: p for k, p in v.items()})
        E.update({k: tuple(i[1] for i in ends) for k, ends in e.items()})
    out = []
    for f in found:
        rings = []
        for uses in f["loops"]:
            ends = []
            for key, reverse in uses:
                s, t = E.get(absolute(f, key), (None, None))
                ends.append((t, s) if reverse else (s, t))
            # An edge that could not be read is bridged by its neighbour's end.
            ring = [V[s if s in V else ends[i - 1][1]] for i, (s, _) in enumerate(ends)
                    if s in V or ends[i - 1][1] in V]
            if len(ring) < max(3, len(uses) - 2):
                break
            rings.append([[c * INCH for c in p] for p in ring])
        else:
            out.append(dict(material=f["material"], normal=f["normal"], rings=rings))
    return out


def area(ring, n):
    s = [0.0, 0.0, 0.0]
    for a, b in zip(ring, ring[1:] + ring[:1]):
        s[0] += a[1] * b[2] - a[2] * b[1]
        s[1] += a[2] * b[0] - a[0] * b[2]
        s[2] += a[0] * b[1] - a[1] * b[0]
    return abs(sum(s[i] * n[i] for i in range(3))) / 2


def main():
    result = faces(MODEL.read_bytes())
    totals = {}
    for f in result:
        f["area"] = area(f["rings"][0], f["normal"]) - sum(area(r, f["normal"]) for r in f["rings"][1:])
        totals[f["material"]] = totals.get(f["material"], 0) + f["area"]
    print(f"{len(result)} faces, {sum(totals.values()):,.0f} m²")
    print("| Material | Read (m²) | BRAS (m²) |\n|---|---|---|")
    for name, bras in BRAS_AREAS.items():
        print(f"| {name} | {totals.get(name, 0):,.1f} | {bras:,.2f} |")
    if "--faces" in sys.argv:
        path = pathlib.Path(sys.argv[sys.argv.index("--faces") + 1])
        path.write_text(json.dumps(result))
        print(f"Wrote {path}")


if __name__ == "__main__":
    sys.exit(main())
