"""Procedural black wolf -> wolf.glb (numpy + scipy only).

Run:  python build_wolf.py [output_dir]
Model faces +Z (glTF forward), +Y up, ground at y = 0. Units: 1 unit ~ 1 Roblox stud
(shoulder height ~2 studs, nose-to-tail ~4.9 studs).
Each part is its own mesh and stays under Roblox's 21,844-triangle-per-mesh limit.
"""
import json
import os
import struct
import sys

import numpy as np
from scipy.interpolate import CubicSpline, PchipInterpolator

rng = np.random.default_rng(7)
ROBLOX_MAX_TRIS = 21844


# ---------------------------------------------------------------- basics
def normalize(v, eps=1e-9):
    n = np.linalg.norm(v, axis=-1, keepdims=True)
    return v / np.maximum(n, eps)


class Mesh:
    def __init__(self, V=None, F=None, nring=None):
        self.V = np.zeros((0, 3)) if V is None else np.asarray(V, float)
        self.F = np.zeros((0, 3), dtype=np.int64) if F is None else np.asarray(F, np.int64)
        self.nring = nring  # number of surface vertices (excludes cap centres)

    def add(self, other):
        off = len(self.V)
        self.V = np.vstack([self.V, other.V])
        self.F = np.vstack([self.F, other.F + off])
        return self


def vnormals(V, F):
    n = np.zeros_like(V)
    fn = np.cross(V[F[:, 1]] - V[F[:, 0]], V[F[:, 2]] - V[F[:, 0]])
    for k in range(3):
        np.add.at(n, F[:, k], fn)
    return normalize(n)


def signed_volume(V, F):
    return np.einsum("ij,ij->i", V[F[:, 0]], np.cross(V[F[:, 1]], V[F[:, 2]])).sum() / 6.0


def outward(m):
    if signed_volume(m.V, m.F) < 0:
        m.F = m.F[:, ::-1].copy()
    return m


# ---------------------------------------------------------------- primitives
def resample(points, vals, n):
    pts = np.asarray(points, float)
    d = np.r_[0, np.cumsum(np.linalg.norm(np.diff(pts, axis=0), axis=1))]
    t = d / d[-1]
    tt = np.linspace(0, 1, n)
    if len(pts) > 2:
        P = CubicSpline(t, pts, bc_type="natural")(tt)
    else:
        P = np.array([np.interp(tt, t, pts[:, k]) for k in range(3)]).T
    outs = [PchipInterpolator(t, np.asarray(v, float))(tt) for v in vals]
    return P, outs


def tube(points, rx, ry, stations=60, seg=40, up=(0, 1, 0), noise=0.0):
    P, (RX, RY) = resample(points, [rx, ry], stations)
    T = normalize(np.gradient(P, axis=0))
    up = np.asarray(up, float)
    N0 = np.cross(T[0], up)
    if np.linalg.norm(N0) < 1e-6:
        N0 = np.cross(T[0], [1.0, 0.0, 0.0])
    Ns = [normalize(N0)]
    for i in range(1, len(P)):
        prev = Ns[-1]
        Ns.append(normalize(prev - T[i] * np.dot(prev, T[i])))
    Ns = np.array(Ns)
    Bs = np.cross(T, Ns)
    ang = np.linspace(0, 2 * np.pi, seg, endpoint=False)
    ring = (
        P[:, None, :]
        + (RX[:, None] * np.cos(ang)[None, :])[:, :, None] * Ns[:, None, :]
        + (RY[:, None] * np.sin(ang)[None, :])[:, :, None] * Bs[:, None, :]
    )
    V = ring.reshape(-1, 3)
    if noise:
        x, y, z = V[:, 0], V[:, 1], V[:, 2]
        V = V + normalize(V - np.repeat(P, seg, axis=0)) * (
            noise * np.sin(11 * x + 4 * y + 2 * z) * np.sin(9 * z + 3 * x - 2 * y)
        )[:, None]
    M = len(P)
    F = []
    for i in range(M - 1):
        a = i * seg + np.arange(seg)
        b = (i + 1) * seg + np.arange(seg)
        c = (i + 1) * seg + (np.arange(seg) + 1) % seg
        d = i * seg + (np.arange(seg) + 1) % seg
        F.append(np.stack([a, b, c], 1))
        F.append(np.stack([a, c, d], 1))
    nring = len(V)
    c0, c1 = nring, nring + 1
    V = np.vstack([V, P[0], P[-1]])
    j = np.arange(seg)
    F.append(np.stack([np.full(seg, c0), j, (j + 1) % seg], 1))
    last = (M - 1) * seg
    F.append(np.stack([np.full(seg, c1), last + (j + 1) % seg, last + j], 1))
    return outward(Mesh(V, np.vstack(F), nring=nring))


def ellipsoid(center, radii, lat=36, lon=56, rot=None):
    th = np.linspace(0, np.pi, lat + 1)
    ph = np.linspace(0, 2 * np.pi, lon, endpoint=False)
    TH, PH = np.meshgrid(th, ph, indexing="ij")
    U = np.stack([np.sin(TH) * np.cos(PH), np.cos(TH), np.sin(TH) * np.sin(PH)], -1).reshape(-1, 3)
    U = U * np.asarray(radii, float)
    if rot is not None:
        U = U @ np.asarray(rot, float).T
    V = U + np.asarray(center, float)
    F = []
    for i in range(lat):
        for j in range(lon):
            a = i * lon + j
            b = i * lon + (j + 1) % lon
            c = (i + 1) * lon + (j + 1) % lon
            d = (i + 1) * lon + j
            if i != 0:
                F.append([a, b, c])
            if i != lat - 1:
                F.append([a, c, d])
    return outward(Mesh(V, np.array(F), nring=len(V)))


def tufts(pos, dirs, length, base, seg=5):
    n = len(pos)
    d = normalize(dirs)
    ref = np.where(np.abs(d[:, 1:2]) < 0.9, np.array([[0.0, 1.0, 0.0]]), np.array([[1.0, 0.0, 0.0]]))
    u = normalize(np.cross(d, ref))
    w = np.cross(d, u)
    ang = np.linspace(0, 2 * np.pi, seg, endpoint=False)
    ring = pos[:, None, :] + base[:, None, None] * (
        np.cos(ang)[None, :, None] * u[:, None, :] + np.sin(ang)[None, :, None] * w[:, None, :]
    )
    apex = pos + d * length[:, None]
    V = np.concatenate([ring, apex[:, None, :]], axis=1).reshape(-1, 3)
    per = seg + 1
    F = []
    for j in range(seg):
        F.append(np.stack([np.arange(n) * per + j, np.arange(n) * per + (j + 1) % seg, np.arange(n) * per + seg], 1))
    return Mesh(V, np.vstack(F))


def fur(src, n, flow, length, base, select=None):
    N = vnormals(src.V, src.F)
    idx = np.arange(src.nring)
    if select is not None:
        idx = idx[select(src.V[: src.nring], N[: src.nring])]
    pick = rng.choice(idx, size=n, replace=len(idx) < n)
    pos = src.V[pick] - N[pick] * 0.012
    d = normalize(N[pick] * 0.32 + np.asarray(flow, float) * 1.1 + rng.normal(0, 0.07, (n, 3)))
    return tufts(pos, d, rng.uniform(*length, n), rng.uniform(*base, n))


# ---------------------------------------------------------------- the wolf
def build():
    parts = []  # (name, mesh, material_name)

    # torso: elliptical cross-section, deep chest, tucked waist
    torso = tube(
        [(0, 1.36, -1.45), (0, 1.38, -1.3), (0, 1.43, -0.9), (0, 1.45, -0.2), (0, 1.47, 0.4), (0, 1.5, 0.85), (0, 1.52, 1.1), (0, 1.54, 1.2)],
        rx=[0.12, 0.26, 0.31, 0.30, 0.34, 0.33, 0.25, 0.15],
        ry=[0.14, 0.30, 0.38, 0.37, 0.50, 0.50, 0.40, 0.25],
        stations=84, seg=44, noise=0.012,
    )
    torso.add(fur(torso, 1250, (0, -0.15, -0.95), (0.13, 0.26), (0.03, 0.05)))
    parts.append(("Torso", torso, "Fur"))

    # neck with a heavy ruff
    neck = tube(
        [(0, 1.62, 0.9), (0, 1.72, 1.22), (0, 1.85, 1.55)],
        rx=[0.25, 0.22, 0.17], ry=[0.31, 0.26, 0.19], stations=40, seg=36, noise=0.01,
    )
    neck.add(fur(neck, 850, (0, -0.3, -0.9), (0.18, 0.34), (0.035, 0.06)))
    parts.append(("Neck", neck, "Fur"))

    # head: skull + snout + lower jaw
    tilt = np.array([[1, 0, 0], [0, np.cos(-0.12), -np.sin(-0.12)], [0, np.sin(-0.12), np.cos(-0.12)]])
    head = ellipsoid((0, 1.9, 1.78), (0.225, 0.205, 0.32), lat=34, lon=52, rot=tilt)
    head.add(tube([(0, 1.85, 1.93), (0, 1.8, 2.2), (0, 1.77, 2.47)], rx=[0.15, 0.108, 0.07], ry=[0.14, 0.105, 0.072], stations=30, seg=30))
    head.add(tube([(0, 1.76, 1.9), (0, 1.72, 2.15), (0, 1.7, 2.4)], rx=[0.125, 0.09, 0.055], ry=[0.07, 0.058, 0.038], stations=26, seg=24))
    head.nring = len(head.V)
    cheek = fur(head, 240, (0, -0.25, -0.9), (0.08, 0.16), (0.02, 0.035), select=lambda V, N: V[:, 2] < 1.95)
    head.add(cheek)
    parts.append(("Head", head, "Fur"))

    # ears
    for side, nm in ((1, "Ear_L"), (-1, "Ear_R")):
        ear = tube(
            [(side * 0.11, 2.03, 1.72), (side * 0.13, 2.2, 1.68), (side * 0.15, 2.4, 1.62)],
            rx=[0.035, 0.03, 0.008], ry=[0.085, 0.07, 0.01], stations=22, seg=18, up=(1, 0, 0),
        )
        parts.append((nm, ear, "Fur"))

    # tail
    tail = tube(
        [(0, 1.45, -1.35), (0, 1.36, -1.75), (0, 1.08, -2.1), (0, 0.68, -2.3), (0, 0.36, -2.36)],
        rx=[0.07, 0.13, 0.16, 0.12, 0.03], ry=[0.07, 0.13, 0.16, 0.12, 0.03], stations=64, seg=30, noise=0.012,
    )
    tail.add(fur(tail, 950, (0, -0.6, -0.8), (0.14, 0.3), (0.03, 0.055)))
    parts.append(("Tail", tail, "Fur"))

    # legs
    legs = {
        "FrontLeg_L": ([(0.22, 1.32, 0.85), (0.2, 0.95, 0.8), (0.2, 0.5, 0.86), (0.2, 0.13, 0.93)], [0.17, 0.12, 0.08, 0.08], 1),
        "FrontLeg_R": ([(-0.22, 1.32, 0.85), (-0.2, 0.95, 0.8), (-0.2, 0.5, 0.86), (-0.2, 0.13, 0.93)], [0.17, 0.12, 0.08, 0.08], -1),
        "HindLeg_L": ([(0.27, 1.3, -1.05), (0.27, 0.9, -0.8), (0.25, 0.55, -1.25), (0.22, 0.14, -1.12)], [0.21, 0.14, 0.085, 0.078], 1),
        "HindLeg_R": ([(-0.27, 1.3, -1.05), (-0.27, 0.9, -0.8), (-0.25, 0.55, -1.25), (-0.22, 0.14, -1.12)], [-0.21, 0.14, 0.085, 0.078], -1),
    }
    for nm, (pts, rad, sgn) in legs.items():
        rad = [abs(r) for r in rad]
        leg = tube(pts, rx=rad, ry=rad, stations=46, seg=26, noise=0.008)
        leg.add(fur(leg, 230, (0, -1.0, -0.25), (0.08, 0.17), (0.022, 0.04)))
        px, pz = pts[-1][0], pts[-1][2] + 0.09
        paw = ellipsoid((px, 0.07, pz), (0.095, 0.07, 0.15), lat=18, lon=26)
        paw.nring = len(paw.V)
        leg.add(paw)
        parts.append((nm, leg, "Fur"))

    # eyes + nose
    for side, nm in ((1, "Eye_L"), (-1, "Eye_R")):
        parts.append((nm, ellipsoid((side * 0.135, 1.97, 2.02), (0.045, 0.034, 0.045), lat=12, lon=16), "Eye"))
    parts.append(("Nose", ellipsoid((0, 1.795, 2.5), (0.06, 0.05, 0.055), lat=14, lon=18), "Nose"))
    return parts


MATERIALS = {
    "Fur": dict(baseColor=[0.02, 0.02, 0.024, 1.0], metallic=0.0, roughness=0.9),
    "Eye": dict(baseColor=[1.0, 0.72, 0.08, 1.0], metallic=0.0, roughness=0.3, emissive=[1.0, 0.6, 0.05]),
    "Nose": dict(baseColor=[0.035, 0.035, 0.04, 1.0], metallic=0.0, roughness=0.35),
}


# ---------------------------------------------------------------- glb writer
def write_glb(path, parts, root_name="BlackWolf"):
    mat_names = list(MATERIALS)
    materials = []
    for k in mat_names:
        m = MATERIALS[k]
        d = {
            "name": k,
            "pbrMetallicRoughness": {"baseColorFactor": m["baseColor"], "metallicFactor": m["metallic"], "roughnessFactor": m["roughness"]},
        }
        if "emissive" in m:
            d["emissiveFactor"] = m["emissive"]
        materials.append(d)

    blob = bytearray()
    views, accessors, meshes, nodes = [], [], [], []

    def view(data, target):
        blob.extend(b"\0" * ((-len(blob)) % 4))
        off = len(blob)
        blob.extend(data)
        views.append({"buffer": 0, "byteOffset": off, "byteLength": len(data), "target": target})
        return len(views) - 1

    for name, m, mat in parts:
        V = m.V.astype("<f4")
        N = vnormals(m.V, m.F).astype("<f4")
        I = m.F.astype("<u4").reshape(-1)
        vp, vn, vi = view(V.tobytes(), 34962), view(N.tobytes(), 34962), view(I.tobytes(), 34963)
        a0 = len(accessors)
        accessors.append({"bufferView": vp, "componentType": 5126, "count": len(V), "type": "VEC3", "min": V.min(0).tolist(), "max": V.max(0).tolist()})
        accessors.append({"bufferView": vn, "componentType": 5126, "count": len(N), "type": "VEC3"})
        accessors.append({"bufferView": vi, "componentType": 5125, "count": len(I), "type": "SCALAR"})
        meshes.append({"name": name, "primitives": [{"attributes": {"POSITION": a0, "NORMAL": a0 + 1}, "indices": a0 + 2, "material": mat_names.index(mat)}]})
        nodes.append({"name": name, "mesh": len(meshes) - 1})

    nodes.append({"name": root_name, "children": list(range(len(parts)))})
    gltf = {
        "asset": {"version": "2.0", "generator": "madlands wolf builder"},
        "scene": 0,
        "scenes": [{"nodes": [len(nodes) - 1]}],
        "nodes": nodes, "meshes": meshes, "materials": materials,
        "accessors": accessors, "bufferViews": views,
        "buffers": [{"byteLength": len(blob)}],
    }
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
    size = write_glb(os.path.join(out, "wolf.glb"), parts)
    total = 0
    worst = 0
    for name, m, _ in parts:
        t = len(m.F)
        total += t
        worst = max(worst, t)
        flag = "  <-- OVER ROBLOX LIMIT" if t > ROBLOX_MAX_TRIS else ""
        print(f"{name:12s} {t:6d} tris{flag}")
    print(f"TOTAL {total} tris in {len(parts)} meshes, largest {worst}, file {size/1024:.0f} KB")
    np.savez(os.path.join(out, "_parts.npz"), **{f"{n}__{mat}__V": m.V for n, m, mat in parts}, **{f"{n}__{mat}__F": m.F for n, m, mat in parts})
