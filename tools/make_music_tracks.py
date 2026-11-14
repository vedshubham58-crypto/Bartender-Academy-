"""Makes three more bar music tracks, all synthesised here so the game owns its music:

  music_tropical.ogg  tropical house, 104 BPM: soft kick, shaker, snaps, marimba hook, pan flute
  music_disco.ogg     nu-disco, 118 BPM: octave bass, funky muted guitar, string swells, claps
  music_lounge.ogg    jazzy lounge house, 100 BPM swing: Rhodes chords, walking bass, ride, vibes

Each loops seamlessly (32 bars). Needs numpy and ffmpeg.

    python3 tools/make_music_tracks.py
"""
import os
import subprocess
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "godot", "audio")


def hz(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def saw(f, t, harm=12):
    s = np.zeros_like(t)
    for k in range(1, harm + 1):
        if f * k > 12000:
            break
        s += ((-1) ** (k + 1)) * np.sin(2 * np.pi * f * k * t) / k
    return s * 0.6


class Track:
    def __init__(self, bpm, bars, seed):
        self.bpm = bpm
        self.beat = 60 / bpm
        self.bar = self.beat * 4
        self.n = int(SR * self.bar * bars)
        self.L = np.zeros(self.n)
        self.R = np.zeros(self.n)
        self.mL = np.zeros(self.n)  # melodic parts, pumped by the kick
        self.mR = np.zeros(self.n)
        self.rng = np.random.default_rng(seed)

    def add(self, sig, t0, pan=0.0, gain=1.0, duck=False):
        i = int(t0 * SR) % self.n
        idx = (np.arange(len(sig)) + i) % self.n
        gl = gain * np.cos((pan + 1) * np.pi / 4)
        gr = gain * np.sin((pan + 1) * np.pi / 4)
        tl, tr = (self.mL, self.mR) if duck else (self.L, self.R)
        np.add.at(tl, idx, sig * gl)
        np.add.at(tr, idx, sig * gr)

    # ---- drums
    def kick(self, vel=1.0, tone=48, decay=0.18):
        n = int(SR * 0.4)
        t = np.arange(n) / SR
        f = tone + 110 * np.exp(-t / 0.03)
        ph = 2 * np.pi * np.cumsum(f) / SR
        click = self.rng.standard_normal(n) * np.exp(-t / 0.002) * 0.25
        return vel * (np.sin(ph) * np.exp(-t / decay) + click)

    def noise(self, dur, decay, hp=1, vel=0.3):
        n = int(SR * dur)
        s = self.rng.standard_normal(n)
        if hp > 1:
            s = s - np.convolve(s, np.ones(hp) / hp, mode="same")
        t = np.arange(n) / SR
        return vel * s * np.exp(-t / decay)

    def clap(self, vel=0.5):
        out = np.zeros(int(SR * 0.3))
        for k, d in enumerate([0, 0.011, 0.022]):
            b = self.noise(0.25, 0.012 if k < 2 else 0.07, hp=6, vel=vel)
            i = int(d * SR)
            out[i:i + len(b)] += b[: len(out) - i]
        return out

    def ride(self, vel=0.08):
        n = int(SR * 0.5)
        t = np.arange(n) / SR
        s = sum(np.sin(2 * np.pi * f * t) for f in (3150, 4270, 5510, 6820)) / 4
        return vel * (s + 0.4 * self.rng.standard_normal(n)) * np.exp(-t / 0.22)

    # ---- tones
    def env(self, t, a, d, dur):
        return np.minimum(1, t / a) * np.exp(-t / d) * np.clip((dur + 0.04 - t) / 0.04, 0, 1)

    def sub(self, m, dur, vel=0.5, grit=0.4):
        n = int(SR * (dur + 0.05))
        t = np.arange(n) / SR
        f = hz(m)
        s = np.sin(2 * np.pi * f * t) + grit * saw(f, t, 6) * np.exp(-t / 0.05)
        return vel * s * self.env(t, 0.003, 0.3, dur)

    def marimba(self, m, vel=0.25):
        n = int(SR * 0.7)
        t = np.arange(n) / SR
        f = hz(m)
        s = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * f * 4 * t) * np.exp(-t / 0.03)
        return vel * s * np.exp(-t / 0.22)

    def flute(self, m, dur, vel=0.16):
        n = int(SR * (dur + 0.1))
        t = np.arange(n) / SR
        f = hz(m) * (1 + 0.006 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t / 0.3))
        ph = 2 * np.pi * np.cumsum(f) / SR
        s = np.sin(ph) + 0.15 * np.sin(2 * ph) + 0.05 * self.rng.standard_normal(n) * np.exp(-t / 0.05)
        e = np.minimum(1, t / 0.05) * np.clip((dur + 0.1 - t) / 0.1, 0, 1)
        return vel * s * e

    def pad(self, notes, dur, vel=0.1, bright=6):
        n = int(SR * (dur + 0.3))
        t = np.arange(n) / SR
        s = np.zeros(n)
        for m in notes:
            for det in (-0.08, 0.08):
                s += saw(hz(m + det), t, bright)
        e = np.minimum(1, t / 0.4) * np.clip((dur + 0.3 - t) / 0.3, 0, 1)
        return vel * s * e / len(notes)

    def guitar(self, notes, vel=0.12):
        n = int(SR * 0.12)
        t = np.arange(n) / SR
        s = np.zeros(n)
        for m in notes:
            s += saw(hz(m), t, 8)
        return vel * s * np.exp(-t / 0.035) / len(notes)

    def rhodes(self, notes, dur, vel=0.16):
        n = int(SR * (dur + 0.4))
        t = np.arange(n) / SR
        s = np.zeros(n)
        for m in notes:
            f = hz(m)
            s += np.sin(2 * np.pi * f * t + 1.2 * np.exp(-t / 0.25) * np.sin(2 * np.pi * f * t))
            s += 0.2 * np.sin(2 * np.pi * f * 7 * t) * np.exp(-t / 0.02)
        trem = 1 + 0.15 * np.sin(2 * np.pi * 4.5 * t)
        e = np.minimum(1, t / 0.005) * np.exp(-t / 1.2) * np.clip((dur + 0.4 - t) / 0.4, 0, 1)
        return vel * s * e * trem / len(notes)

    def vibes(self, m, vel=0.14):
        n = int(SR * 1.2)
        t = np.arange(n) / SR
        f = hz(m)
        s = np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * f * 4 * t) * np.exp(-t / 0.1)
        return vel * s * np.exp(-t / 0.6) * (1 + 0.2 * np.sin(2 * np.pi * 5 * t))

    def write(self, name, pump_depth=0.55):
        t = (np.arange(self.n) / SR) % self.beat
        pump = 1 - pump_depth * np.exp(-t / 0.09)
        L = self.L + self.mL * pump
        R = self.R + self.mR * pump
        L = reverb(L, seed=1)
        R = reverb(R, seed=2)
        mx = max(np.abs(L).max(), np.abs(R).max())
        L = np.tanh(L / mx * 1.6) / np.tanh(1.6) * 0.9
        R = np.tanh(R / mx * 1.6) / np.tanh(1.6) * 0.9
        pcm = (np.stack([L, R], axis=1) * 32767).astype(np.int16)
        tmp = "/tmp/%s.wav" % name
        with wave.open(tmp, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(pcm.tobytes())
        out = os.path.join(OUT, name + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4", out], check=True)
        print("wrote", out, os.path.getsize(out) // 1024, "KB,", round(self.n / SR, 1), "s")


def reverb(x, secs=1.2, mix=0.16, seed=0):
    r = np.random.default_rng(seed)
    n = int(SR * secs)
    ir = r.standard_normal(n) * np.exp(-np.arange(n) / SR / (secs / 5))
    ir[: int(SR * 0.01)] = 0
    ir /= np.sqrt(np.sum(ir ** 2))
    pad = np.zeros(len(x))
    pad[:n] = ir
    wet = np.real(np.fft.ifft(np.fft.fft(x) * np.fft.fft(pad)))
    return x + mix * wet


def tropical():
    T = Track(104, 32, 21)
    B, b = T.beat, T.bar
    # Em - C - G - D
    prog = [([64, 67, 71], 40), ([64, 67, 72], 36), ([62, 67, 71], 43), ([62, 66, 69], 38)]
    hook = [(0, 76), (0.75, 79), (1.5, 76), (2, 74), (2.75, 71), (3.5, 74),
            (4, 76), (4.75, 79), (5.5, 81), (6, 79), (6.75, 76), (7.5, 74)]
    for bi in range(32):
        t0 = bi * b
        chord, root = prog[bi % 4]
        full = bi >= 4
        for q in range(4):
            T.add(T.kick(0.75, tone=50, decay=0.14), t0 + q * B, gain=0.85)
            for s16 in range(4):
                T.add(T.noise(0.05, 0.012, hp=2, vel=0.035 + 0.025 * (s16 == 2)), t0 + (q + s16 / 4) * B, pan=0.35)
        if full:
            for q in (1, 3):
                T.add(T.clap(0.35), t0 + q * B, gain=0.7)
        # soft syncopated sub bass
        for pos, off in ((0, 0), (1.5, 0), (2.5, 7), (3.25, 12)):
            T.add(T.sub(root + off - 12, B * 0.6, 0.55, grit=0.1), t0 + pos * B, duck=True)
        # warm pad
        T.add(T.pad([m - 12 for m in chord] + [chord[0]], b * 0.95, 0.06, 4), t0, duck=True)
        # marimba chord plucks on the off-beats
        for pos in (0.5, 1.5, 2.25, 3.0, 3.5):
            for m in chord:
                T.add(T.marimba(m, 0.09), t0 + pos * B, pan=-0.25, duck=True)
    for start in (8, 16, 24):
        for rep in range(4):
            for bt, m in hook:
                if start == 16:
                    T.add(T.flute(m, B * 0.6), (start + rep * 2) * b + bt * B, pan=0.15, duck=True)
                else:
                    T.add(T.marimba(m, 0.22), (start + rep * 2) * b + bt * B, pan=0.2, duck=True)
    T.write("music_tropical", 0.45)


def disco():
    T = Track(118, 32, 33)
    B, b = T.beat, T.bar
    # Dm7 - G7 - Cmaj7 - Am7
    prog = [([62, 65, 69, 72], 38), ([62, 65, 67, 71], 43), ([60, 64, 67, 71], 36), ([60, 64, 67, 69], 45)]
    lead = [(0, 81), (0.5, 79), (1, 77), (1.5, 74), (2, 77), (3, 79), (3.5, 81),
            (4, 84), (5, 81), (5.5, 79), (6, 77), (7, 74)]
    for bi in range(32):
        t0 = bi * b
        chord, root = prog[bi % 4]
        full = bi >= 4
        for q in range(4):
            T.add(T.kick(1.0, tone=46), t0 + q * B, gain=0.9)
            T.add(T.noise(0.2, 0.06, hp=3, vel=0.12), t0 + (q + 0.5) * B, pan=0.25)
            for s16 in range(4):
                T.add(T.noise(0.03, 0.006, hp=2, vel=0.04), t0 + (q + s16 / 4) * B, pan=-0.3)
        if full:
            for q in (1, 3):
                T.add(T.clap(0.55), t0 + q * B, gain=0.8)
        # classic disco octave bass in eighths
        for e in range(8):
            T.add(T.sub(root - 12 + (12 if e % 2 else 0), B * 0.4, 0.5, 0.6), t0 + e * 0.5 * B, duck=True)
        # funky muted guitar on the sixteenths
        if full:
            for s16 in range(16):
                if s16 % 4 in (1, 2) or s16 in (6, 14):
                    T.add(T.guitar([m + 12 for m in chord[1:]], 0.11 if s16 % 2 else 0.07), t0 + s16 * B / 4, pan=0.4, duck=True)
        # string swell
        T.add(T.pad([m + 12 for m in chord], b * 0.95, 0.05 if full else 0.08, 7), t0, pan=-0.2, duck=True)
    for start in (8, 24):
        for rep in range(4):
            for bt, m in lead:
                T.add(T.vibes(m, 0.12), (start + rep * 2) * b + bt * B, pan=-0.1, duck=True)
    T.write("music_disco", 0.5)


def lounge():
    T = Track(100, 32, 47)
    B, b = T.beat, T.bar
    sw = 0.66  # swing: the off-beat eighth comes late

    def swing(pos):
        whole = int(pos)
        frac = pos - whole
        return whole + (sw if abs(frac - 0.5) < 1e-6 else frac)

    # Dm9 - G13 - Cmaj9 - A7(b9)
    prog = [([53, 57, 60, 64], [38, 41, 45, 47]), ([53, 57, 59, 64], [43, 47, 50, 49]),
            ([52, 55, 59, 62], [36, 40, 43, 44]), ([55, 58, 61, 64], [45, 44, 43, 40])]
    melody = [(0, 72), (0.5, 74), (1, 76), (2, 77), (2.5, 76), (3, 74),
              (4, 71), (4.5, 72), (5, 74), (6, 72), (7, 69)]
    for bi in range(32):
        t0 = bi * b
        chord, walk = prog[bi % 4]
        for q in range(4):
            if q in (0, 2):
                T.add(T.kick(0.6, tone=52, decay=0.12), t0 + q * B, gain=0.7)
            T.add(T.ride(0.07), t0 + q * B, pan=0.3)
            if q in (1, 3):
                T.add(T.ride(0.05), t0 + swing(q + 0.5) * B, pan=0.3)
                T.add(T.noise(0.2, 0.05, hp=4, vel=0.07), t0 + q * B, pan=-0.15)  # brushed snare
        # walking bass, one note per beat
        for q in range(4):
            T.add(T.sub(walk[q], B * 0.9, 0.5, grit=0.15), t0 + q * B, duck=True)
        # Rhodes comping, a little ahead of the beat
        T.add(T.rhodes(chord, B * 1.4), t0 + swing(0.5) * B, pan=-0.2, duck=True)
        T.add(T.rhodes(chord, B * 1.2, 0.12), t0 + swing(2.5) * B, pan=-0.2, duck=True)
    for start in (8, 16, 24):
        for rep in range(4):
            for bt, m in melody:
                T.add(T.vibes(m, 0.15), (start + rep * 2) * b + swing(bt) * B, pan=0.2, duck=True)
    T.write("music_lounge", 0.2)


if __name__ == "__main__":
    tropical()
    disco()
    lounge()
