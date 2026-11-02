#!/usr/bin/env python3
"""Sintetiza todos os sons da demo (sem arquivos externos).

Uso: python3 tools/gen_audio.py      (escreve .wav em assets/audio/)
Requer apenas numpy. Mono, 16 bits.
"""
import os
import wave

import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(1234)


def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env_ad(n, attack=0.005, decay=0.1, sustain_curve=4.0):
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    d = np.exp(-np.maximum(t - attack, 0) / max(decay, 1e-4))
    return a * d


def fast_lowpass(x, cutoff):
    # Versão vetorizada aproximada (média móvel) para sinais longos.
    k = max(1, int(SR / max(cutoff, 1.0) / 2))
    kernel = np.ones(k) / k
    return np.convolve(np.convolve(x, kernel, mode="same"), kernel, mode="same")


def highpass(x, cutoff):
    return x - fast_lowpass(x, cutoff)


def bandpass(x, lo, hi):
    return fast_lowpass(highpass(x, lo), hi)


def noise(n):
    return rng.uniform(-1, 1, n)


def sweep(f0, f1, dur, shape="exp"):
    t = t_axis(dur)
    if shape == "exp":
        f = f0 * (f1 / f0) ** (t / dur)
    else:
        f = f0 + (f1 - f0) * t / dur
    phase = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(phase)


def tone(freq, dur, partials=((1, 1.0),), decay=0.5, attack=0.004):
    t = t_axis(dur)
    s = np.zeros_like(t)
    for mult, amp in partials:
        s += amp * np.sin(2 * np.pi * freq * mult * t)
    return s * env_ad(len(t), attack, decay)


def place(dst, src, at):
    i = int(at * SR)
    end = min(len(dst), i + len(src))
    dst[i:end] += src[: end - i]


def normalize(x, peak=0.85):
    m = np.max(np.abs(x))
    return x if m < 1e-9 else x / m * peak


def fade(x, fin=0.003, fout=0.02):
    n = len(x)
    a = min(n, int(fin * SR))
    b = min(n, int(fout * SR))
    if a > 0:
        x[:a] *= np.linspace(0, 1, a)
    if b > 0:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def save(name, x, peak=0.85, loop=False):
    x = normalize(np.asarray(x, dtype=np.float64), peak)
    if not loop:
        x = fade(x)
    data = (np.clip(x, -1, 1) * 32767).astype(np.int16)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


# ------------------------------------------------------------------ Efeitos

def sfx_tongue():
    d = 0.13
    s = sweep(500, 1700, d) * env_ad(int(SR * d), 0.002, 0.05)
    n = highpass(noise(int(SR * d)), 1500) * env_ad(int(SR * d), 0.001, 0.03) * 0.6
    return s * 0.7 + n


def sfx_slurp():
    d = 0.3
    t = t_axis(d)
    n = noise(len(t))
    wob = 0.5 + 0.5 * np.sin(2 * np.pi * 28 * t)
    body = bandpass(n, 500, 1600) * wob
    s = sweep(700, 260, d) * 0.4
    return (body + s) * env_ad(len(t), 0.01, 0.12)


def sfx_munch(seed):
    r = np.random.default_rng(seed)
    out = np.zeros(int(SR * 0.36))
    for k in range(3):
        n = int(SR * 0.05)
        burst = bandpass(r.uniform(-1, 1, n), 300, 2600 + r.uniform(-500, 800))
        burst *= env_ad(n, 0.001, 0.012)
        thump = tone(110 + r.uniform(-15, 25), 0.06, ((1, 1.0),), 0.02) * 0.5
        place(out, burst, k * 0.1 + r.uniform(0, 0.02))
        place(out, thump, k * 0.1)
    return out


def sfx_knock():
    a = tone(320, 0.18, ((1, 1.0), (2.3, 0.4)), 0.035)
    n = bandpass(noise(len(a)), 800, 4000) * env_ad(len(a), 0.0005, 0.008) * 0.6
    return a + n


def sfx_frenzy():
    d = 0.9
    t = t_axis(d)
    n = bandpass(noise(len(t)), 800, 5000) * np.linspace(0.2, 1.0, len(t)) * env_ad(len(t), 0.5, 0.4)
    chord = sum(sweep(f, f * 2, d) for f in (330, 415, 494)) * 0.25 * np.linspace(0.1, 1, len(t)) * np.exp(-t * 1.5)
    return n * 0.6 + chord


def sfx_sniff():
    out = np.zeros(int(SR * 0.55))
    for k, at in enumerate((0.0, 0.16, 0.3)):
        n = int(SR * 0.09)
        b = bandpass(noise(n), 900, 4500) * np.sin(np.linspace(0, np.pi, n)) ** 2
        place(out, b * (1.0 - k * 0.15), at)
    return out


def sfx_dig():
    d = 0.16
    n = int(SR * d)
    grit = bandpass(noise(n), 200, 2200) * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 45 * t_axis(d))))
    return grit * env_ad(n, 0.004, 0.06)


def sfx_burst():
    d = 0.9
    out = np.zeros(int(SR * d))
    place(out, tone(70, 0.4, ((1, 1.0), (2, 0.3)), 0.12) * 1.2, 0.0)
    spray = bandpass(noise(int(SR * 0.8)), 400, 5000) * env_ad(int(SR * 0.8), 0.01, 0.25)
    place(out, spray * 0.7, 0.02)
    for k in range(6):
        place(out, tone(1800 + k * 140, 0.05, ((1, 1),), 0.015) * 0.15, 0.1 + k * 0.07)
    return out


def sfx_tremor():
    d = 1.4
    t = t_axis(d)
    boom = sweep(70, 32, d) * np.exp(-t * 2.2)
    rumble = fast_lowpass(noise(len(t)), 180) * np.exp(-t * 1.6) * 3.0
    crack = bandpass(noise(len(t)), 500, 3000) * env_ad(len(t), 0.001, 0.05) * 0.5
    return boom + rumble + crack


def sfx_step(seed):
    r = np.random.default_rng(seed)
    d = 0.14
    n = int(SR * d)
    rustle = highpass(r.uniform(-1, 1, n), 1800) * env_ad(n, 0.008, 0.04)
    thump = tone(90 + r.uniform(-10, 10), d, ((1, 1),), 0.03) * 0.5
    return rustle * 0.7 + thump


def bell(freq, dur, decay):
    return tone(freq, dur, ((1, 1.0), (2.0, 0.35), (3.01, 0.15), (4.2, 0.06)), decay, 0.003)


def sfx_point():
    out = np.zeros(int(SR * 1.3))
    for k, f in enumerate((523.25, 659.25, 783.99, 1046.5)):
        place(out, bell(f, 0.9, 0.35), k * 0.09)
    place(out, bell(1318.5, 1.0, 0.5) * 0.6, 0.38)
    return out


def sfx_upgrade():
    out = np.zeros(int(SR * 1.2))
    for f in (392.0, 493.88, 587.33, 783.99):
        place(out, bell(f, 1.1, 0.5) * 0.7, 0.0)
    for k in range(5):
        place(out, bell(1567.98 * (1 + k * 0.12), 0.3, 0.1) * 0.25, 0.15 + k * 0.05)
    return out


def sfx_deny():
    a = tone(220, 0.12, ((1, 1), (3, 0.3)), 0.06)
    b = tone(165, 0.14, ((1, 1), (3, 0.3)), 0.07)
    out = np.zeros(int(SR * 0.28))
    place(out, a, 0)
    place(out, b, 0.11)
    return out


def drum(freq, dur=0.35):
    t = t_axis(dur)
    body = np.sin(2 * np.pi * np.cumsum(freq * (1 + 1.5 * np.exp(-t * 30))) / SR) * np.exp(-t * 9)
    skin = bandpass(noise(len(t)), 300, 3000) * np.exp(-t * 40) * 0.4
    return body + skin


def shaker(dur):
    n = int(SR * dur)
    return highpass(noise(n), 3500) * env_ad(n, 0.01, dur * 0.4)


def sfx_wave():
    out = np.zeros(int(SR * 1.5))
    for k, (at, f) in enumerate(((0.0, 110), (0.22, 110), (0.44, 82), (0.8, 98))):
        place(out, drum(f) * (1.0 if k != 2 else 1.2), at)
    for k in range(8):
        place(out, shaker(0.08) * 0.35, 0.05 + k * 0.11)
    return out


def sfx_complete():
    out = np.zeros(int(SR * 3.0))
    notes = (392.0, 493.88, 587.33, 783.99, 987.77)
    for k, f in enumerate(notes):
        place(out, pluck(f, 1.6) * 0.6, k * 0.12)
    for f in (523.25, 659.25, 783.99, 1046.5):
        place(out, bell(f, 2.0, 0.9) * 0.5, 0.7)
    place(out, drum(98, 0.5), 0.7)
    return out


def sfx_ui_hover():
    return tone(1700, 0.05, ((1, 1),), 0.012)


def sfx_ui_click():
    out = tone(900, 0.09, ((1, 1), (2, 0.3)), 0.02)
    place(out, tone(1350, 0.06, ((1, 1),), 0.01) * 0.5, 0.0)
    return out


def sfx_ui_open():
    d = 0.35
    n = bandpass(noise(int(SR * d)), 600, 3000) * np.sin(np.linspace(0, np.pi, int(SR * d)))
    return n * 0.6 + bell(880, d, 0.12) * 0.3


# ------------------------------------------------------------- Violão (KS)

def pluck(freq, dur, bright=0.5, decay=0.996):
    """Corda dedilhada (Karplus-Strong), vetorizada por blocos."""
    n = int(SR * dur)
    period = int(round(SR / freq))
    if period < 2:
        period = 2
    out = np.zeros(n + period)
    seed = rng.uniform(-1, 1, period)
    # Suaviza o ataque (dedo, não palheta).
    for _ in range(int((1 - bright) * 4) + 1):
        seed = 0.5 * (seed + np.roll(seed, 1))
    out[:period] = seed
    k = period
    while k < n + period:
        prev = out[k - period:k]
        nxt = 0.5 * (prev + np.concatenate(([out[k - period - 1] if k - period - 1 >= 0 else 0.0], prev[:-1])))
        m = min(period, n + period - k)
        out[k:k + m] = nxt[:m] * decay
        k += period
    res = out[period:period + n]
    return res * env_ad(n, 0.002, dur * 0.6)


def music_violao():
    bpm = 84
    beat = 60.0 / bpm
    bars = 8
    total = bars * 4 * beat
    out = np.zeros(int(SR * (total + 2.0)))
    # Cmaj7 - Am7 - Dm7 - G7 (2x), voicings em região média.
    prog = [
        (130.81, (329.63, 392.0, 493.88, 659.25)),
        (110.0, (329.63, 392.0, 523.25, 659.25)),
        (146.83, (349.23, 440.0, 523.25, 698.46)),
        (98.0, (349.23, 392.0, 493.88, 587.33)),
    ] * 2
    for bar, (bass, chord) in enumerate(prog):
        t0 = bar * 4 * beat
        # Baixo da bossa: 1 e 3 (com antecipação).
        place(out, pluck(bass, 1.6, 0.3, 0.997) * 0.9, t0)
        place(out, pluck(bass * 1.5, 1.2, 0.3, 0.997) * 0.6, t0 + 2 * beat)
        # Acordes sincopados.
        for off in (0.5, 1.5, 2.5, 3.0 + 0.5):
            for j, f in enumerate(chord):
                place(out, pluck(f, 1.0, 0.45, 0.994) * 0.32, t0 + off * beat + j * 0.012)
        # Melodia simples nas notas do acorde, de vez em quando.
        if bar % 2 == 1:
            place(out, pluck(chord[-1] * 2, 1.4, 0.7, 0.996) * 0.25, t0 + 3.25 * beat)
        # Ganzá suave.
        for k in range(8):
            place(out, shaker(0.07) * (0.05 if k % 2 else 0.08), t0 + k * 0.5 * beat)
    # Loop sem emenda: soma a cauda no começo.
    n = int(SR * total)
    tail = out[n:]
    out = out[:n].copy()
    out[: len(tail)] += tail
    return fast_lowpass(out, 6000)


# --------------------------------------------------------------- Ambiente

def amb_cerrado():
    dur = 24.0
    n = int(SR * dur)
    t = np.arange(n) / SR
    out = np.zeros(n)
    # Vento: ruído grave com rajadas lentas.
    wind = fast_lowpass(noise(n), 400)
    gust = 0.55 + 0.45 * np.sin(2 * np.pi * t / dur * 2) * np.sin(2 * np.pi * t / dur * 3 + 1.0)
    out += wind * gust * 0.9
    # Cigarras: zumbido modulado que cresce e some.
    for start, length, carrier in ((1.0, 9.0, 4800), (11.0, 10.0, 5600)):
        seg = int(SR * length)
        tt = np.arange(seg) / SR
        buzz = bandpass(noise(seg), carrier - 900, carrier + 900)
        am = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 95 * tt))
        swell = np.sin(np.pi * tt / length) ** 1.5
        place(out, buzz * am * swell * 0.28, start)
    # Grilos: trios de cricri.
    for k in range(int(dur / 0.9)):
        at = k * 0.9 + rng.uniform(0, 0.2)
        for j in range(3):
            place(out, tone(4300 + rng.uniform(-80, 80), 0.035, ((1, 1),), 0.012) * 0.12, at + j * 0.06)
    # Pássaros ao longe (assobios descendentes).
    for at in (3.5, 8.2, 15.7, 20.3):
        place(out, sweep(2600, 1500, 0.35) * env_ad(int(SR * 0.35), 0.03, 0.15) * 0.18, at)
        place(out, sweep(2900, 1700, 0.3) * env_ad(int(SR * 0.3), 0.03, 0.12) * 0.14, at + 0.45)
    # Emenda suave do loop.
    x = int(SR * 2.0)
    head = out[:x].copy()
    out[:x] = head * np.linspace(0, 1, x) + out[-x:] * np.linspace(1, 0, x)
    return out[:-x]


def main():
    os.makedirs(OUT, exist_ok=True)
    save("tongue", sfx_tongue())
    save("slurp", sfx_slurp())
    for i in range(1, 4):
        save("munch_%d" % i, sfx_munch(10 + i))
    save("knock", sfx_knock())
    save("frenzy", sfx_frenzy())
    save("sniff", sfx_sniff())
    save("dig", sfx_dig())
    save("burst", sfx_burst())
    save("tremor", sfx_tremor())
    for i in range(1, 5):
        save("step_%d" % i, sfx_step(40 + i), 0.6)
    save("point", sfx_point())
    save("upgrade", sfx_upgrade())
    save("deny", sfx_deny(), 0.6)
    save("wave", sfx_wave())
    save("complete", sfx_complete())
    save("ui_hover", sfx_ui_hover(), 0.4)
    save("ui_click", sfx_ui_click(), 0.6)
    save("ui_open", sfx_ui_open(), 0.6)
    save("amb_cerrado", amb_cerrado(), 0.7, loop=True)
    save("music_violao", music_violao(), 0.75, loop=True)
    print("sons gerados em", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
