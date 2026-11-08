#!/usr/bin/env python3
"""Gera a estampa do chão da mata (folhiço): folhas secas caídas umas por cima
das outras, gravetos e terra escura nos vãos. Repete sem emenda.

Uso: python3 tools/gen_folhico.py   (escreve em assets/textures/folhico/)
Sem Python instalado, dá para rodar no Python do Blender (que já tem numpy):
  import runpy; runpy.run_path(r"<projeto>/tools/gen_folhico.py", run_name="__main__")
Saída (1024 px):
  cor.png    = cor (RGB) + altura (A)
  relevo.png = normal map (verde para cima)
"""
import os
import struct
import zlib

import numpy as np

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "textures", "folhico")
SIZE = 1024
rng = np.random.default_rng(41)


def write_png(path, img):
    h, w, c = img.shape
    raw = b"".join(b"\x00" + img[y].astype(np.uint8).tobytes() for y in range(h))
    def chunk(tag, data):
        out = struct.pack(">I", len(data)) + tag + data
        return out + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    color_type = 6 if c == 4 else 2
    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, color_type, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9))
    png += chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def tile_noise(size, cells, octaves, seed):
    """Ruído suave que repete sem emenda (soma de senos em direções inteiras)."""
    r = np.random.default_rng(seed)
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32) / size
    out = np.zeros((size, size), np.float32)
    amp = 1.0
    total = 0.0
    for o in range(octaves):
        f = cells * (2 ** o)
        for _ in range(6):
            kx, ky = r.integers(-f, f + 1, 2)
            if kx == 0 and ky == 0:
                kx = f
            ph = r.uniform(0, np.pi * 2)
            out += amp * np.sin(2 * np.pi * (kx * xx + ky * yy) + ph)
            total += amp
        amp *= 0.55
    return out / total * 0.5 + 0.5


col = np.zeros((SIZE, SIZE, 3), np.float32)
height = np.zeros((SIZE, SIZE), np.float32)

# Fundo: terra escura e úmida, com um pouco de variação.
n1 = tile_noise(SIZE, 3, 4, 1)
n2 = tile_noise(SIZE, 24, 2, 2)
soil = np.array([0.20, 0.14, 0.09])
col[:] = soil * (0.75 + 0.5 * n1[..., None]) * (0.85 + 0.3 * n2[..., None])
height[:] = 0.05 * n1 + 0.03 * n2


def stamp(cx, cy, half_w, half_h, fn):
    """Chama fn(px, py) (em pixels, relativos ao centro) nas cópias que caem
    dentro da imagem (para repetir sem emenda)."""
    for ox in (-SIZE, 0, SIZE):
        for oy in (-SIZE, 0, SIZE):
            x0 = int(cx + ox - half_w)
            x1 = int(cx + ox + half_w) + 1
            y0 = int(cy + oy - half_h)
            y1 = int(cy + oy + half_h) + 1
            if x1 <= 0 or y1 <= 0 or x0 >= SIZE or y0 >= SIZE:
                continue
            xs = slice(max(x0, 0), min(x1, SIZE))
            ys = slice(max(y0, 0), min(y1, SIZE))
            yy, xx = np.mgrid[ys, xs].astype(np.float32)
            fn(ys, xs, xx - (cx + ox), yy - (cy + oy))


# Cores das folhas secas: marrom escuro, castanho, ocre, avermelhado e
# algumas ainda meio amarelo-esverdeadas (caíram há pouco).
PALETTE = np.array([
    [0.30, 0.19, 0.11],
    [0.42, 0.27, 0.15],
    [0.55, 0.38, 0.20],
    [0.62, 0.46, 0.25],
    [0.50, 0.26, 0.14],
    [0.52, 0.48, 0.24],
])
WEIGHTS = np.array([0.22, 0.26, 0.2, 0.14, 0.1, 0.08])


def twig(cx, cy, ang, length, width, layer):
    d = np.array([np.cos(ang), np.sin(ang)])
    c = np.array([0.33, 0.22, 0.13]) * rng.uniform(0.7, 1.15)
    def fn(ys, xs, px, py):
        u = px * d[0] + py * d[1]
        v = -px * d[1] + py * d[0]
        inside = np.clip((width - np.abs(v)) * 1.5, 0, 1) * (np.abs(u) < length * 0.5)
        h = layer + 0.04 * np.sqrt(np.clip(1 - (v / width) ** 2, 0, 1))
        sel = inside > 0.01
        k = inside[..., None]
        shade = 0.75 + 0.35 * np.clip(-v / width, -1, 1)
        newc = c * shade[..., None]
        cur = col[ys, xs]
        col[ys, xs] = np.where(sel[..., None], cur * (1 - k) + newc * k, cur)
        height[ys, xs] = np.where(sel, np.maximum(height[ys, xs], h * inside), height[ys, xs])
    r = length * 0.5 + width
    stamp(cx, cy, r, r, fn)


def leaf(cx, cy, ang, length, width, base_col, layer, shape):
    d = np.array([np.cos(ang), np.sin(ang)])
    curl = rng.uniform(0.0, 0.08)
    holes = rng.random() < 0.0
    hole_seed = rng.uniform(0, 100)
    def fn(ys, xs, px, py):
        u = (px * d[0] + py * d[1]) / length + 0.5
        v = (-px * d[1] + py * d[0]) / length
        uc = np.clip(u, 0, 1)
        oval = np.sqrt(np.clip(1 - ((uc - 0.45) / 0.55) ** 2, 0, 1))
        lance = np.clip(np.sin(np.pi * uc), 0, 1) ** 0.8
        half = width * (oval * shape + lance * (1 - shape))
        half = half * np.clip(uc / 0.06, 0.2, 1)
        inside = np.clip((half - np.abs(v)) * length * 1.2, 0, 1) * (u > 0) * (u < 1)
        if holes:
            hn = np.sin(px * 0.31 + hole_seed) * np.sin(py * 0.27 - hole_seed)
            inside = inside * np.clip((0.93 - hn) * 8, 0, 1)
        rel = np.abs(v) / np.maximum(half, 1e-4)
        # Folha seca enrolada: as bordas sobem.
        h = layer + curl * rel ** 2 + 0.015
        shade = 0.82 + 0.18 * np.sign(v) * rel * 0.6 + 0.25 * curl * rel
        mid = np.exp(-(v * length / 1.0) ** 2) * 0.18
        lat = np.clip(np.cos((u * 8.0 - rel * 1.6) * np.pi), 0, 1) ** 10 * 0.06 * (rel < 0.85)
        shade = shade - mid - lat
        # Mancha mais escura, de apodrecer, em parte das folhas.
        spot = np.clip(np.sin(px * 0.05 + cx) * np.sin(py * 0.06 + cy), 0, 1) * 0.25
        newc = base_col * (shade - spot)[..., None]
        sel = inside > 0.01
        k = inside[..., None]
        cur = col[ys, xs]
        col[ys, xs] = np.where(sel[..., None], cur * (1 - k) + newc * k, cur)
        height[ys, xs] = np.where(sel, height[ys, xs] * (1 - inside) + h * inside, height[ys, xs])
    r = length * 0.6
    stamp(cx, cy, r, r, fn)


# Camadas: as de baixo mais escuras (mais velhas, úmidas), as de cima mais claras.
LAYERS = 5
COUNT = 820
for i in range(COUNT):
    layer_t = i / COUNT
    layer = 0.1 + 0.8 * layer_t
    if rng.random() < 0.05:
        twig(rng.uniform(0, SIZE), rng.uniform(0, SIZE), rng.uniform(0, np.pi),
             rng.uniform(60, 180), rng.uniform(2.0, 4.0), layer + 0.05)
        continue
    pi = rng.choice(len(PALETTE), p=WEIGHTS)
    base = PALETTE[pi] * rng.uniform(0.85, 1.12)
    base = base * (0.6 + 0.4 * layer_t)
    big = rng.random() < 0.3
    length = rng.uniform(70, 120) if big else rng.uniform(35, 70)
    shape = rng.uniform(0.4, 1.0)
    leaf(rng.uniform(0, SIZE), rng.uniform(0, SIZE), rng.uniform(0, np.pi * 2),
         length, rng.uniform(0.22, 0.34), base, layer, shape)

# Normal map a partir da altura (com repetição nas bordas).
hs = height * 6.0
dx = (np.roll(hs, -1, axis=1) - np.roll(hs, 1, axis=1)) * 0.5
dy = (np.roll(hs, -1, axis=0) - np.roll(hs, 1, axis=0)) * 0.5
nz = np.ones_like(dx)
nrm = np.stack([-dx, dy, nz], axis=-1)
nrm /= np.linalg.norm(nrm, axis=-1, keepdims=True)
normal_img = (nrm * 0.5 + 0.5) * 255

# Sombra de contato: vãos entre as folhas mais escuros.
blur = height.copy()
for _ in range(4):
    blur = (blur + np.roll(blur, 3, 0) + np.roll(blur, -3, 0) + np.roll(blur, 3, 1) + np.roll(blur, -3, 1)) / 5
ao = np.clip(1.0 - (blur - height) * 2.5, 0.55, 1.0)
col *= ao[..., None]

hmin, hmax = height.min(), height.max()
hn = (height - hmin) / max(hmax - hmin, 1e-5)
rgba = np.concatenate([np.clip(col, 0, 1) * 255, hn[..., None] * 255], axis=-1)

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    write_png(os.path.join(OUT, "cor.png"), np.clip(rgba + 0.5, 0, 255))
    write_png(os.path.join(OUT, "relevo.png"), np.clip(normal_img + 0.5, 0, 255))
    print("média da cor:", col.reshape(-1, 3).mean(axis=0))
    print("texturas geradas em", os.path.abspath(OUT))
