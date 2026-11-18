"""Procedural sword -> sword.glb (numpy + scipy only; reuses helpers from build_wolf.py).

Run:  python build_sword.py [output_dir]
Blade points along +Y, origin at the middle of the grip, ground-up like a held tool.
Units ~ Roblox studs: about 4 studs from pommel to tip.
Parts are separate meshes (Blade, Guard, Grip, Pommel, Gem) so each can get its own Color/Material in Studio.
"""
import json
import os
import struct
import sys

import numpy as np

from build_wolf import Mesh, ellipsoid, normalize, outward, tube, vnormals, ROBLOX_MAX_TRIS


def loft(rings):
    """Closed polygon rings (M,K,3) -> watertight mesh with fan caps at both ends."""
    M, K, _ = rings.shape
    V = rings.reshape(-1, 3)
    F = []
    j = np.arange(K)
    for i in range(M - 1):
        a, b = i * K + j, (i + 1) * K + j
        c, d = (i + 1) * K + (j + 1) % K, i * K + (j + 1) % K
        F += [np.stack([a, b, c], 1), np.stack([a, c, d], 1)]
    n = len(V)
    V = np.vstack([V, rings[0].mean(0), rings[-1].mean(0)])
    F.append(np.stack([np.full(K, n), j, (j + 1) % K], 1))
    last = (M - 1) * K
    F.append(np.stack([np.full(K, n + 1), last + (j + 1) % K, last + j], 1))
    return outward(Mesh(V, np.vstack(F), nring=n))


def smoothstep(a, b, x):
    t = np.clip((x - a) / (b - a), 0, 1)
    return t * t * (3 - 2 * t)


def blade():
    y0, y1 = 0.5, 3.5  # starts inside the guard
    ys = np.concatenate([np.linspace(y0, 2.6, 40), np.linspace(2.6, y1, 40)[1:] ** 1.0])
    rings = []
    for y in ys:
        s = np.clip((y - 2.7) / (y1 - 2.7), 0, 1)
        w = 0.15 - 0.02 * smoothstep(0.8, 2.7, y)
        w = w * (1 - s ** 1.7) + 0.012
        t = (0.05 - 0.015 * smoothstep(0.8, 2.7, y)) * (1 - s ** 1.3) + 0.006
        g = smoothstep(0.85, 1.05, y) * (1 - smoothstep(2.9, 3.2, y))  # fuller groove depth
        d = t * (1 - 0.55 * g)
        pts = [
            (w, 0), (0.62 * w, t), (0.24 * w, t), (0.2 * w, d), (-0.2 * w, d), (-0.24 * w, t), (-0.62 * w, t),
            (-w, 0), (-0.62 * w, -t), (-0.24 * w, -t), (-0.2 * w, -d), (0.2 * w, -d), (0.24 * w, -t), (0.62 * w, -t),
        ]
        rings.append([(px, y, pz) for px, pz in pts])
    return loft(np.array(rings, float))


def guard():
    xs = np.linspace(-0.62, 0.62, 9)
    path = [(x, 0.5 + 0.17 * (x / 0.62) ** 2, 0) for x in xs]
    r = [0.05, 0.062, 0.07, 0.076, 0.082, 0.076, 0.07, 0.062, 0.05]
    g = tube(path, rx=r, ry=r, stations=60, seg=32, up=(0, 0, 1))
    for sx in (-1, 1):  # round finials
        g.add(ellipsoid((sx * 0.64, 0.5 + 0.17, 0), (0.075, 0.075, 0.075), lat=18, lon=26))
    g.add(ellipsoid((0, 0.5, 0), (0.13, 0.11, 0.1), lat=20, lon=30))  # centre boss
    g.nring = len(g.V)
    return g


def grip():
    ys = np.linspace(-0.4, 0.45, 120)
    seg = 48
    th = np.linspace(0, 2 * np.pi, seg, endpoint=False)
    rings = []
    for y in ys:
        swell = 1 + 0.12 * np.sin(np.pi * (y + 0.4) / 0.85)
        r = (0.058 + 0.009 * np.sin(6 * th - 22 * y)) * swell  # helical leather wrap
        rings.append(np.stack([r * np.cos(th), np.full(seg, y), r * np.sin(th)], 1))
    return loft(np.array(rings))


def pommel():
    p = ellipsoid((0, -0.52, 0), (0.12, 0.1, 0.12), lat=24, lon=40)
    p.add(tube([(0, -0.43, 0), (0, -0.38, 0)], rx=[0.085, 0.085], ry=[0.085, 0.085], stations=4, seg=28))
    p.add(ellipsoid((0, -0.63, 0), (0.04, 0.035, 0.04), lat=10, lon=14))
    p.nring = len(p.V)
    return p


def build():
    parts = [
        ("Blade", blade(), "Steel", True),
        ("Guard", guard(), "Brass", False),
        ("Grip", grip(), "Leather", False),
        ("Pommel", pommel(), "Brass", False),
        ("Gem_Front", ellipsoid((0, 0.5, 0.085), (0.055, 0.07, 0.035), lat=14, lon=20), "Ruby", False),
        ("Gem_Back", ellipsoid((0, 0.5, -0.085), (0.055, 0.07, 0.035), lat=14, lon=20), "Ruby", False),
    ]
    return parts


MATERIALS = {
    "Steel": dict(baseColor=[0.72, 0.75, 0.8, 1.0], metallic=0.9, roughness=0.25),
    "Brass": dict(baseColor=[0.78, 0.6, 0.2, 1.0], metallic=1.0, roughness=0.35),
    "Leather": dict(baseColor=[0.27, 0.17, 0.1, 1.0], metallic=0.0, roughness=0.85),
    "Ruby": dict(baseColor=[0.8, 0.05, 0.08, 1.0], metallic=0.0, roughness=0.15, emissive=[0.6, 0.02, 0.04]),
}


def write_glb(path, parts, root_name="Sword"):
    mat_names = list(MATERIALS)
    materials = []
    for k in mat_names:
        m = MATERIALS[k]
        d = {"name": k, "pbrMetallicRoughness": {"baseColorFactor": m["baseColor"], "metallicFactor": m["metallic"], "roughnessFactor": m["roughness"]}}
        if "emissive" in m:
            d["emissiveFactor"] = m["emissive"]
        materials.append(d)
    blob, views, accessors, meshes, nodes = bytearray(), [], [], [], []

    def view(data, target):
        blob.extend(b"\0" * ((-len(blob)) % 4))
        off = len(blob)
        blob.extend(data)
        views.append({"buffer": 0, "byteOffset": off, "byteLength": len(data), "target": target})
        return len(views) - 1

    for name, m, mat, flat in parts:
        if flat:  # unweld so every face keeps a crisp edge
            Vf = m.V[m.F].reshape(-1, 3)
            Ff = np.arange(len(Vf)).reshape(-1, 3)
            fn = normalize(np.cross(Vf[Ff[:, 1]] - Vf[Ff[:, 0]], Vf[Ff[:, 2]] - Vf[Ff[:, 0]]))
            Nf = np.repeat(fn, 3, axis=0)
        else:
            Vf, Ff, Nf = m.V, m.F, vnormals(m.V, m.F)
        V, N, I = Vf.astype("<f4"), Nf.astype("<f4"), Ff.astype("<u4").reshape(-1)
        vp, vn, vi = view(V.tobytes(), 34962), view(N.tobytes(), 34962), view(I.tobytes(), 34963)
        a0 = len(accessors)
        accessors.append({"bufferView": vp, "componentType": 5126, "count": len(V), "type": "VEC3", "min": V.min(0).tolist(), "max": V.max(0).tolist()})
        accessors.append({"bufferView": vn, "componentType": 5126, "count": len(N), "type": "VEC3"})
        accessors.append({"bufferView": vi, "componentType": 5125, "count": len(I), "type": "SCALAR"})
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": a0, "NORMAL": a0 + 1}, "indices": a0 + 2, "material": mat_names.index(mat)}]})
        nodes.append({"name": name, "mesh": len(meshes) - 1})
    nodes.append({"name": root_name, "children": list(range(len(parts)))})
    gltf = {"asset": {"version": "2.0", "generator": "madlands sword builder"}, "scene": 0, "scenes": [{"nodes": [len(nodes) - 1]}],
            "nodes": nodes, "meshes": meshes, "materials": materials, "accessors": accessors, "bufferViews": views, "buffers": [{"byteLength": len(blob)}]}
    js = json.dumps(gltf, separators=(",", ":")).encode()
    js += b" " * ((-len(js)) % 4)
    blob.extend(b"\0" * ((-len(blob)) % 4))
    total = 12 + 8 + len(js) + 8 + len(blob)
    with open(path, "wb") as f:
        f.write(struct.pack("<4sII", b"glTF", 2, total))
        f.write(struct.pack("<I4s", len(js), b"JSON"))
        f.write(js)
        f.write(struct.pack("<I4s", len(blob), b"BIN\0"))
        f.write(bytes(blob))
    return total


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(out, exist_ok=True)
    parts = build()
    size = write_glb(os.path.join(out, "sword.glb"), parts)
    total = 0
    for name, m, _, _ in parts:
        t = len(m.F)
        total += t
        print(f"{name:10s} {t:6d} tris" + ("  <-- OVER ROBLOX LIMIT" if t > ROBLOX_MAX_TRIS else ""))
    print(f"TOTAL {total} tris in {len(parts)} meshes, file {size/1024:.0f} KB")
    np.savez(os.path.join(out, "_sword_parts.npz"), **{f"{n}__{mat}__V": m.V for n, m, mat, _ in parts}, **{f"{n}__{mat}__F": m.F for n, m, mat, _ in parts})
