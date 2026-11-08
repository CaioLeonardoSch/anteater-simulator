#!/usr/bin/env python3
"""Gera as texturas de folhagem usadas nas copas e arbustos (e as flores de ipê).

Uso: python3 tools/gen_textures.py            (folhas das copas e dos arbustos)
     python3 tools/gen_textures.py --flores   (também as flores de ipê)
Sem Python instalado, dá para rodar no Python do Blender (que já tem numpy).
Requer apenas numpy. As imagens são PNG RGBA:
  R = sombreamento (nervuras, dobra no meio da folha, base mais escura),
  G = tom de cada folha (0..1, o shader puxa para o amarelado ou o azulado),
  B = folha seca (1 = seca; os raminhos também), A = recorte.
"""
import os
import struct
import sys
import zlib

import numpy as np

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "textures")


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


class Canvas:
    def __init__(self, size):
        self.size = size
        yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
        self.xx = (xx + 0.5) / size
        self.yy = (yy + 0.5) / size
        self.shade = np.zeros((size, size), np.float32)
        self.tone = np.zeros((size, size), np.float32)
        self.dry = np.zeros((size, size), np.float32)
        self.alpha = np.zeros((size, size), np.float32)

    def _box(self, p0, p1, pad):
        s = self.size
        x0 = max(int((min(p0[0], p1[0]) - pad) * s), 0)
        x1 = min(int((max(p0[0], p1[0]) + pad) * s) + 1, s)
        y0 = max(int((min(p0[1], p1[1]) - pad) * s), 0)
        y1 = min(int((max(p0[1], p1[1]) + pad) * s) + 1, s)
        return slice(y0, y1), slice(x0, x1)

    def put(self, sl, cov, shade, tone, dry):
        # A folha nova fica por cima; a borda dela se mistura com o que já há.
        k = np.where(cov > 0.02, cov, 0.0)
        self.shade[sl] = self.shade[sl] * (1 - k) + shade * k
        self.tone[sl] = self.tone[sl] * (1 - k) + tone * k
        self.dry[sl] = self.dry[sl] * (1 - k) + dry * k
        self.alpha[sl] = np.maximum(self.alpha[sl], cov)

    def twig(self, p0, p1, width):
        """Raminho reto de p0 a p1 (afina na ponta)."""
        p0 = np.array(p0)
        p1 = np.array(p1)
        sl = self._box(p0, p1, width * 2)
        px = self.xx[sl] - p0[0]
        py = self.yy[sl] - p0[1]
        d = p1 - p0
        ln = max(float(np.hypot(*d)), 1e-5)
        d = d / ln
        u = np.clip((px * d[0] + py * d[1]) / ln, 0, 1)
        v = px * -d[1] + py * d[0]
        dist = np.hypot(px - u * ln * d[0], py - u * ln * d[1])
        w = width * (1.0 - 0.6 * u)
        cov = np.clip((w - dist) * self.size * 1.2, 0, 1)
        shade = 0.35 + 0.25 * np.clip(v / np.maximum(w, 1e-5), -1, 1)
        self.put(sl, cov, shade, 0.5, 1.0)

    def leaf(self, base, angle, length, width, tone, dry, tip_round, light_side):
        """Folha simples a partir de base, na direção angle.

        tip_round: 0 = ponta fina (lanceolada), 1 = ponta arredondada (oval).
        light_side: qual metade da folha pega mais luz (+1 / -1), como uma folha
        dobrada na nervura do meio.
        """
        d = np.array([np.cos(angle), np.sin(angle)])
        n = np.array([-d[1], d[0]])
        tip = np.array(base) + d * length
        sl = self._box(base, tip, width * length * 1.2)
        px = self.xx[sl] - base[0]
        py = self.yy[sl] - base[1]
        u = (px * d[0] + py * d[1]) / length
        v = (px * n[0] + py * n[1]) / length
        uc = np.clip(u, 0, 1)
        # Contorno: oval (mais larga um pouco antes do meio) até lanceolada.
        oval = np.sqrt(np.clip(1 - ((uc - 0.45) / 0.55) ** 2, 0, 1))
        lance = np.clip(np.sin(np.pi * uc), 0, 1) ** 0.8 * (1 - 0.35 * uc)
        half = width * (oval * tip_round + lance * (1 - tip_round))
        # Pecíolo: o comecinho da folha é fino.
        half = half * np.clip(uc / 0.08, 0.15, 1)
        cov = np.clip((half - np.abs(v)) * length * self.size * 1.1, 0, 1) * (u > 0) * (u < 1)
        rel = np.abs(v) / np.maximum(half, 1e-4)
        s = 0.66 + 0.18 * np.sign(v) * light_side * (0.3 + 0.7 * rel)
        s = s * (0.8 + 0.25 * uc)
        # Borda um pouco mais clara (luz pegando na borda curvada).
        s = s + 0.4 * np.clip(rel - 0.8, 0, 0.2)
        # Nervura do meio e laterais, finas.
        px_w = length * self.size
        mid = np.exp(-(v * px_w / 1.1) ** 2) * 0.22
        lat_phase = (u * 9.0 - np.abs(v) / max(width, 1e-4) * 2.2) * np.pi
        lat = np.clip(np.cos(lat_phase), 0, 1) ** 12 * 0.06 * (rel < 0.85)
        s = np.clip(s - mid + lat, 0, 1)
        self.put(sl, cov, s, tone, dry)

    def trumpet(self, base, angle, length, width, tone, light_side):
        """Flor de ipê vista de lado: cálice no raminho, tubo fino que abre numa
        boca de 5 lobos franzidos."""
        d = np.array([np.cos(angle), np.sin(angle)])
        n = np.array([-d[1], d[0]])
        tip = np.array(base) + d * length
        sl = self._box(base, tip, width)
        px = self.xx[sl] - base[0]
        py = self.yy[sl] - base[1]
        u = (px * d[0] + py * d[1]) / length
        v = px * n[0] + py * n[1]
        uc = np.clip(u, 0, 1)
        half = width * 0.5 * (0.14 + 0.86 * np.clip((uc - 0.05) / 0.95, 0, 1) ** 1.4)
        rel = np.clip(np.abs(v) / np.maximum(half, 1e-5), 0, 1)
        # Boca recortada em lobos (a borda da trombeta não é reta).
        u_end = 1.0 - 0.09 * (0.5 + 0.5 * np.cos(v / (width * 0.5) * np.pi * 2.5))
        cov = (np.clip((half - np.abs(v)) * self.size * 1.2, 0, 1)
               * np.clip((u_end - u) * length * self.size * 1.2, 0, 1) * (u > 0))
        s = 0.58 + 0.3 * uc + 0.14 * np.sign(v) * light_side * rel
        # Dobras ao longo do tubo e a beira da boca mais clara.
        fold = np.clip(np.cos(rel * np.pi * 2.5), 0, 1) ** 6 * (uc < 0.8)
        s = s - 0.12 * fold + 0.1 * np.clip((uc - 0.78) / 0.1, 0, 1)
        dry = np.clip((0.17 - uc) / 0.05, 0, 1)
        self.put(sl, cov, np.clip(s, 0, 1), tone, dry)

    def bloom(self, c, r, rot, tone):
        """Flor de ipê vista de frente: 5 lobos franzidos, garganta escura com
        riscos (os guias de néctar)."""
        sl = self._box(c, c, r * 1.2)
        px = self.xx[sl] - c[0]
        py = self.yy[sl] - c[1]
        dist = np.hypot(px, py)
        th = np.arctan2(py, px) + rot
        lobe = np.abs(np.cos(2.5 * th))
        rr = r * (0.72 + 0.28 * lobe ** 0.7) + r * 0.04 * np.sin(14 * th + rot * 3)
        cov = np.clip((rr - dist) * self.size * 1.2, 0, 1)
        rho = np.clip(dist / np.maximum(rr, 1e-5), 0, 1)
        s = 0.5 + 0.45 * np.clip((rho - 0.15) / 0.6, 0, 1)
        s = np.where(rho < 0.2, 0.46 + 0.6 * rho, s)
        guide = np.clip(np.cos(th * 15), 0, 1) ** 8 * (rho > 0.15) * (rho < 0.6)
        crease = (1 - lobe) ** 4 * (rho > 0.3)
        s = s - 0.12 * guide - 0.08 * crease + 0.08 * np.clip((rho - 0.85) / 0.15, 0, 1)
        self.put(sl, cov, np.clip(s, 0, 1), tone, 0.0)

    def rgba(self):
        out = np.zeros((self.size, self.size, 4), np.float32)
        out[..., 0] = self.shade
        out[..., 1] = self.tone
        out[..., 2] = self.dry
        out[..., 3] = self.alpha
        return (np.clip(out, 0, 1) * 255 + 0.5).astype(np.uint8)


def sprig_cluster(rng, size, sprigs, leaves_per, leaf_len, leaf_w, tip_round,
                  dry_chance, spread, droop):
    """Leque de raminhos saindo da base do cartão (embaixo, no meio), cada um
    com folhas alternadas dos dois lados e uma na ponta."""
    cv = Canvas(size)
    base = np.array([0.5, 0.97])
    for i in range(sprigs):
        a = -np.pi / 2 + (i - (sprigs - 1) / 2) * spread / max(sprigs - 1, 1) + rng.normal(0, 0.1)
        ln = rng.uniform(0.6, 0.82) * (1.0 - 0.3 * abs(np.cos(a)))
        # Raminho levemente curvo: dois segmentos.
        bend = rng.normal(0, 0.18)
        mid = base + np.array([np.cos(a), np.sin(a)]) * ln * 0.5
        a2 = a + bend
        end = mid + np.array([np.cos(a2), np.sin(a2)]) * ln * 0.5
        pts = [base, mid, end]
        twig_tone = rng.uniform(0, 1)
        leaves = []
        for j in range(leaves_per):
            t = 0.2 + 0.8 * (j + rng.uniform(-0.25, 0.25)) / leaves_per
            seg = 0 if t < 0.5 else 1
            tt = (t - 0.5 * seg) / 0.5
            p = pts[seg] + (pts[seg + 1] - pts[seg]) * tt
            ang = a if seg == 0 else a2
            side = 1 if j % 2 == 0 else -1
            la = ang + side * (rng.uniform(0.55, 1.0) + droop * 0.3)
            leaves.append((p, la, side))
        leaves.append((end, a2 + rng.normal(0, 0.15), 1))
        cv.twig(base, mid, 0.006)
        cv.twig(mid, end, 0.005)
        for p, la, side in leaves:
            ll = leaf_len * rng.uniform(0.8, 1.2)
            lw = leaf_w * rng.uniform(0.85, 1.15)
            tone = float(np.clip(twig_tone * 0.6 + rng.uniform(0, 0.4), 0, 1))
            dry = 1.0 if rng.random() < dry_chance else 0.0
            # Folha que passaria da borda do cartão ficaria cortada reta: fica de fora.
            dd = np.array([np.cos(la), np.sin(la)])
            nn = np.array([-dd[1], dd[0]])
            corners = [p + dd * ll, p + dd * ll * 0.45 + nn * lw * ll, p + dd * ll * 0.45 - nn * lw * ll]
            if any(c.min() < 0.015 or c.max() > 0.985 for c in corners):
                continue
            cv.leaf((float(p[0]), float(p[1])), la, ll, lw,
                    tone, dry, tip_round, side)
    return cv.rgba()


def leaf_cluster():
    # Copas das árvores do cerrado: folhas ovais, largas, de couro.
    rng = np.random.default_rng(11)
    return sprig_cluster(rng, 512, sprigs=7, leaves_per=6, leaf_len=0.2, leaf_w=0.3,
                         tip_round=0.8, dry_chance=0.06, spread=2.3, droop=0.0)


def shrub_cluster():
    # Arbustos: folhas mais finas e pontudas, mais raminhos, mais folhas secas.
    rng = np.random.default_rng(29)
    return sprig_cluster(rng, 512, sprigs=11, leaves_per=10, leaf_len=0.17, leaf_w=0.24,
                         tip_round=0.3, dry_chance=0.1, spread=2.6, droop=0.4)


def flower_cluster():
    # Flores de ipê: cachos de flores em trombeta na ponta de raminhos. Umas de
    # lado (tubo que abre numa boca de 5 lobos franzidos), outras de frente
    # (boca aberta com a garganta escura e riscadinha). Canais como nas folhas:
    # R = sombreamento (garganta escura), G = tom de cada flor, B = raminho e cálice.
    size = 512
    rng = np.random.default_rng(7)
    cv = Canvas(size)
    for _ in range(11):
        cx = rng.uniform(0.2, 0.8)
        cy = rng.uniform(0.16, 0.72)
        # Raminho chegando no cacho, vindo de baixo (a base do cartão).
        bx = cx + rng.uniform(-0.06, 0.06)
        cv.twig((bx, min(cy + rng.uniform(0.1, 0.16), 0.97)), (cx, cy), 0.006)
        n = rng.integers(6, 10)
        base_ang = rng.uniform(0, np.pi * 2)
        for k in range(n):
            a = base_ang + np.pi * 2 * k / n + rng.uniform(-0.35, 0.35)
            tone = rng.uniform(0.15, 0.85)
            if rng.random() < 0.62:
                ln = rng.uniform(0.12, 0.16)
                cv.trumpet((cx, cy), a, ln, ln * rng.uniform(0.62, 0.78), tone, rng.integers(0, 2) * 2 - 1)
            else:
                r = rng.uniform(0.06, 0.08)
                off = rng.uniform(0.05, 0.09)
                c = (cx + np.cos(a) * off, cy + np.sin(a) * off)
                if min(c) - r < 0.02 or max(c) + r > 0.98:
                    continue
                cv.bloom(c, r, rng.uniform(0, np.pi * 2), tone)
    return cv.rgba()


def main(argv):
    os.makedirs(OUT, exist_ok=True)
    write_png(os.path.join(OUT, "leaf_cluster.png"), leaf_cluster())
    write_png(os.path.join(OUT, "shrub_cluster.png"), shrub_cluster())
    if "--flores" in argv:
        write_png(os.path.join(OUT, "flower_cluster.png"), flower_cluster())
    print("texturas geradas em", os.path.abspath(OUT))


if __name__ == "__main__":
    main(sys.argv)
