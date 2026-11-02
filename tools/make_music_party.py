"""Makes the bar's upbeat music: a bright house groove (122 BPM) that loops seamlessly.

Four-on-the-floor kick, claps, open hats, a pumping chord stab, a bouncy octave
bass and a short pluck hook, all synthesised here so the game owns its music.
Writes godot/audio/music_party.ogg (needs ffmpeg).

    python3 tools/make_music_party.py
"""
import os
import subprocess
import wave

import numpy as np

SR = 44100
BPM = 122
BEAT = 60 / BPM
BARS = 32
LEN = int(SR * BEAT * 4 * BARS)
rng = np.random.default_rng(11)

L = np.zeros(LEN)
R = np.zeros(LEN)
music_L = np.zeros(LEN)  # the melodic parts, ducked by the kick (sidechain pump)
music_R = np.zeros(LEN)


def hz(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def add(sig, t0, pan=0.0, gain=1.0, duck=False):
    i = int(t0 * SR) % LEN
    idx = (np.arange(len(sig)) + i) % LEN
    gl = gain * np.cos((pan + 1) * np.pi / 4)
    gr = gain * np.sin((pan + 1) * np.pi / 4)
    tl, tr = (music_L, music_R) if duck else (L, R)
    np.add.at(tl, idx, sig * gl)
    np.add.at(tr, idx, sig * gr)


def saw(f, t, harm=14):
    s = np.zeros_like(t)
    for k in range(1, harm + 1):
        if f * k > 12000:
            break
        s += ((-1) ** (k + 1)) * np.sin(2 * np.pi * f * k * t) / k
    return s * 0.6


def kick(vel=1.0):
    n = int(SR * 0.4)
    t = np.arange(n) / SR
    f = 48 + 110 * np.exp(-t / 0.03)
    ph = 2 * np.pi * np.cumsum(f) / SR
    click = rng.standard_normal(n) * np.exp(-t / 0.002) * 0.3
    return vel * (np.sin(ph) * np.exp(-t / 0.18) + click)


def noise(dur, decay, hp=1, vel=0.3):
    n = int(SR * dur)
    s = rng.standard_normal(n)
    if hp > 1:
        s = s - np.convolve(s, np.ones(hp) / hp, mode="same")
    t = np.arange(n) / SR
    return vel * s * np.exp(-t / decay)


def clap(vel=0.5):
    out = np.zeros(int(SR * 0.3))
    for k, d in enumerate([0, 0.011, 0.022]):
        b = noise(0.25, 0.012 if k < 2 else 0.07, hp=6, vel=vel)
        i = int(d * SR)
        out[i:i + len(b)] += b[: len(out) - i]
    return out


def stab(notes, dur, vel=0.18):
    n = int(SR * (dur + 0.25))
    t = np.arange(n) / SR
    s = np.zeros(n)
    for m in notes:
        for det in (-0.12, 0.0, 0.12):  # three detuned saws = wide supersaw-ish chord
            s += saw(hz(m + det), t, 10)
    e = np.minimum(1, t / 0.004) * np.exp(-t / 0.22) * np.clip((dur + 0.05 - t) / 0.05, 0, 1)
    return vel * s * e / len(notes)


def bass(m, dur, vel=0.5):
    n = int(SR * (dur + 0.05))
    t = np.arange(n) / SR
    f = hz(m)
    s = np.sin(2 * np.pi * f * t) + 0.5 * saw(f, t, 6) * np.exp(-t / 0.06)
    e = np.minimum(1, t / 0.003) * np.exp(-t / 0.25) * np.clip((dur - t) / 0.02, 0, 1)
    return vel * s * e


def pluck(m, vel=0.22):
    n = int(SR * 0.6)
    t = np.arange(n) / SR
    f = hz(m)
    s = np.sin(2 * np.pi * f * t + 1.5 * np.exp(-t / 0.05) * np.sin(2 * np.pi * f * 2 * t))
    return vel * s * np.exp(-t / 0.18)


bar = BEAT * 4
# Am - F - C - G, one chord per bar
prog = [([57, 60, 64, 69], 45), ([57, 60, 65, 69], 41), ([55, 60, 64, 67], 48), ([55, 59, 62, 67], 43)]

for b in range(BARS):
    t0 = b * bar
    chord, root = prog[b % 4]
    full = b >= 4
    # drums
    for q in range(4):
        add(kick(), t0 + q * BEAT, gain=0.9)
        add(noise(0.18, 0.05, hp=3, vel=0.11), t0 + (q + 0.5) * BEAT, pan=0.25)  # open hat on the off-beat
        for s16 in range(4):
            add(noise(0.04, 0.008, hp=2, vel=0.05 + 0.03 * (s16 % 2)), t0 + (q + s16 / 4) * BEAT, pan=-0.3)
    if full:
        for q in (1, 3):
            add(clap(), t0 + q * BEAT, gain=0.8)
    # bass: off-beat octave bounce
    for e in range(8):
        n = root + (12 if e % 2 else 0) - 12
        add(bass(n, BEAT * 0.45), t0 + (e * 0.5 + 0.25) * BEAT * 1.0, gain=0.9, duck=True)
    # chord stabs on the and-of each beat
    if full:
        for e in (0.5, 1.5, 2.5, 3.25, 3.75):
            add(stab(chord, BEAT * 0.3), t0 + e * BEAT, pan=0.0, gain=1.0, duck=True)

# pluck hook in bars 9-16 and 25-32
hook = [(0, 76), (0.5, 76), (1, 74), (1.5, 72), (2.5, 72), (3, 74), (3.5, 76),
        (4, 77), (4.5, 76), (5, 74), (6, 72), (6.5, 71), (7, 72)]
for start in (8, 24):
    for rep in range(4):
        for bt, m in hook:
            add(pluck(m), (start + rep * 2) * bar + bt * BEAT, pan=0.2 if rep % 2 else -0.2, duck=True)

# sidechain pump: duck the music after each kick
t = (np.arange(LEN) / SR) % BEAT
pump = 1 - 0.65 * np.exp(-t / 0.09)
L += music_L * pump
R += music_R * pump


def reverb(x, secs=1.1, mix=0.14, seed=0):
    r = np.random.default_rng(seed)
    n = int(SR * secs)
    ir = r.standard_normal(n) * np.exp(-np.arange(n) / SR / (secs / 5))
    ir[: int(SR * 0.01)] = 0
    ir /= np.sqrt(np.sum(ir ** 2))
    pad = np.zeros(len(x))
    pad[:n] = ir
    wet = np.real(np.fft.ifft(np.fft.fft(x) * np.fft.fft(pad)))
    return x + mix * wet


L = reverb(L, seed=1)
R = reverb(R, seed=2)
# gentle limiter so it is loud but not clipped
mx = max(np.abs(L).max(), np.abs(R).max())
L = np.tanh(L / mx * 1.6) / np.tanh(1.6) * 0.9
R = np.tanh(R / mx * 1.6) / np.tanh(1.6) * 0.9
pcm = (np.stack([L, R], axis=1) * 32767).astype(np.int16)

root = os.path.join(os.path.dirname(__file__), "..", "godot", "audio")
tmp = "/tmp/music_party.wav"
with wave.open(tmp, "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
out = os.path.join(root, "music_party.ogg")
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4", out], check=True)
print("wrote", out, os.path.getsize(out) // 1024, "KB,", round(LEN / SR, 1), "s")
