#!/usr/bin/env python3
"""Gera as texturas de folhagem (cachos de folhas e flores de ipê) usadas nas copas.

Uso: python3 tools/gen_textures.py   (escreve em assets/textures/)
Requer apenas numpy. As imagens são PNG RGBA: R = sombreamento interno, A = recorte.
"""
import os
import struct
import zlib

import numpy as np

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
SIZE = 256
rng = np.random.default_rng(7)


def write_png(path, rgba):
    h, w, _ = rgba.shape
    raw = b"".join(b"\x00" + rgba[y].astype(np.uint8).tobytes() for y in range(h))
    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


yy, xx = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
xx = (xx + 0.5) / SIZE
yy = (yy + 0.5) / SIZE


def leaf(base, angle, length, width, shade, alpha):
    """Desenha uma folha pontuda a partir de `base` na direção `angle`."""
    d = np.array([np.cos(angle), np.sin(angle)])
    n = np.array([-d[1], d[0]])
    px = xx - base[0]
    py = yy - base[1]
    u = (px * d[0] + py * d[1]) / length
    v = (px * n[0] + py * n[1]) / length
    half = width * np.clip(np.sin(np.pi * np.clip(u, 0, 1)), 0, 1) ** 0.75
    inside = (u > 0) & (u < 1) & (np.abs(v) < half)
    edge = np.clip((half - np.abs(v)) * length * SIZE * 0.9, 0, 1) * inside
    s = 0.62 + 0.38 * (1 - np.abs(v) / np.maximum(half, 1e-4))
    s *= 0.85 + 0.15 * u
    rib = np.exp(-(v * length * SIZE / 1.6) ** 2) * 0.22
    s = np.clip(s - rib, 0, 1)
    upd = edge > alpha
    shade[upd] = s[upd]
    alpha[upd] = edge[upd]


def leaf_cluster():
    shade = np.zeros((SIZE, SIZE), np.float32)
    alpha = np.zeros((SIZE, SIZE), np.float32)
    base = (0.5, 0.92)
    count = 9
    for i in range(count):
        a = -np.pi / 2 + (i - (count - 1) / 2) * 0.33 + rng.normal(0, 0.08)
        ln = 0.42 + rng.uniform(-0.06, 0.08)
        off = np.array([np.cos(a), np.sin(a)]) * rng.uniform(0.0, 0.12)
        leaf((base[0] + off[0], base[1] + off[1]), a, ln, 0.17 + rng.uniform(-0.03, 0.03), shade, alpha)
    rgba = np.zeros((SIZE, SIZE, 4), np.float32)
    rgba[..., 0] = shade
    rgba[..., 1] = shade
    rgba[..., 2] = shade
    rgba[..., 3] = alpha
    return (np.clip(rgba, 0, 1) * 255).astype(np.uint8)


def flower_cluster():
    shade = np.zeros((SIZE, SIZE), np.float32)
    alpha = np.zeros((SIZE, SIZE), np.float32)
    for _ in range(16):
        cx, cy = rng.uniform(0.18, 0.82, 2)
        r = rng.uniform(0.07, 0.12)
        rot = rng.uniform(0, np.pi * 2)
        px = xx - cx
        py = yy - cy
        ang = np.arctan2(py, px) + rot
        dist = np.sqrt(px * px + py * py)
        petal = r * (0.62 + 0.38 * np.abs(np.cos(ang * 2.5)))
        inside = dist < petal
        edge = np.clip((petal - dist) * SIZE * 0.8, 0, 1) * inside
        s = 0.55 + 0.45 * (dist / np.maximum(petal, 1e-4))
        throat = np.exp(-(dist / (r * 0.28)) ** 2) * 0.45
        s = np.clip(s - throat, 0, 1)
        upd = edge > alpha * 0.98
        shade[upd] = s[upd]
        alpha[upd] = np.maximum(alpha[upd], edge[upd])
    rgba = np.zeros((SIZE, SIZE, 4), np.float32)
    rgba[..., 0] = shade
    rgba[..., 1] = shade
    rgba[..., 2] = shade
    rgba[..., 3] = alpha
    return (np.clip(rgba, 0, 1) * 255).astype(np.uint8)


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    write_png(os.path.join(OUT, "leaf_cluster.png"), leaf_cluster())
    write_png(os.path.join(OUT, "flower_cluster.png"), flower_cluster())
    print("texturas geradas em", os.path.abspath(OUT))
