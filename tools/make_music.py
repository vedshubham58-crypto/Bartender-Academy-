"""Makes the bar's background music: a warm lounge / bossa groove that loops seamlessly.

Everything is synthesised here (electric piano, upright bass, brushes, vibraphone),
so the game owns its music outright. Writes godot/audio/music_lounge.ogg (needs ffmpeg).

    python3 tools/make_music.py
"""
import os
import subprocess
import wave

import numpy as np

SR = 44100
BPM = 92
BEAT = 60 / BPM
BARS = 16
LEN = int(SR * BEAT * 4 * BARS)
rng = np.random.default_rng(3)

L = np.zeros(LEN)
R = np.zeros(LEN)


def note_hz(n):
    return 440.0 * 2 ** ((n - 69) / 12)


def add(sig, t0, pan=0.0, gain=1.0):
    """Mixes sig in at time t0 (seconds), wrapping round the end so the loop is seamless."""
    i = int(t0 * SR) % LEN
    n = len(sig)
    idx = (np.arange(n) + i) % LEN
    gl = gain * np.cos((pan + 1) * np.pi / 4)
    gr = gain * np.sin((pan + 1) * np.pi / 4)
    np.add.at(L, idx, sig * gl)
    np.add.at(R, idx, sig * gr)


def env(n, a, d):
    t = np.arange(n) / SR
    e = np.minimum(1.0, t / a) * np.exp(-t / d)
    return e


def epiano(midi, dur, vel=0.5):
    """FM electric piano (Rhodes-like bell + warm body)."""
    n = int(SR * (dur + 1.2))
    t = np.arange(n) / SR
    f = note_hz(midi)
    mod_env = np.exp(-t / 0.25)
    mod = (0.8 + 2.0 * mod_env) * np.sin(2 * np.pi * f * 1.0 * t)
    body = np.sin(2 * np.pi * f * t + mod)
    bell = 0.25 * np.exp(-t / 0.12) * np.sin(2 * np.pi * f * 14 * t)
    trem = 1 + 0.12 * np.sin(2 * np.pi * 4.5 * t)
    e = env(n, 0.004, 1.6)
    release = np.clip((dur + 0.4 - t) / 0.4, 0, 1)
    return vel * (body + bell) * e * trem * release


def bass(midi, dur, vel=0.8):
    n = int(SR * (dur + 0.3))
    t = np.arange(n) / SR
    f = note_hz(midi)
    s = np.sin(2 * np.pi * f * t) + 0.35 * np.sin(4 * np.pi * f * t) * np.exp(-t / 0.15) + 0.12 * np.sin(6 * np.pi * f * t) * np.exp(-t / 0.08)
    e = env(n, 0.006, 0.9) * np.clip((dur + 0.1 - t) / 0.1, 0, 1)
    return vel * s * e


def vibes(midi, vel=0.35):
    n = int(SR * 2.2)
    t = np.arange(n) / SR
    f = note_hz(midi)
    s = np.sin(2 * np.pi * f * t) + 0.2 * np.sin(2 * np.pi * f * 4 * t) * np.exp(-t / 0.3)
    return vel * s * env(n, 0.002, 0.9) * (1 + 0.25 * np.sin(2 * np.pi * 5.5 * t))


def kick(vel=0.9):
    n = int(SR * 0.35)
    t = np.arange(n) / SR
    f = 45 + 70 * np.exp(-t / 0.04)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return vel * np.sin(ph) * np.exp(-t / 0.12)


def noise_hit(dur, decay, hp=0.0, vel=0.3):
    n = int(SR * dur)
    s = rng.standard_normal(n)
    if hp:
        s = s - np.convolve(s, np.ones(int(hp)) / hp, mode="same")
    t = np.arange(n) / SR
    return vel * s * np.exp(-t / decay)


def rim(vel=0.35):
    n = int(SR * 0.08)
    t = np.arange(n) / SR
    return vel * (np.sin(2 * np.pi * 1700 * t) * 0.6 + rng.standard_normal(n) * 0.4) * np.exp(-t / 0.012)


# chord progression (midi notes, voiced around middle C), 2 bars each... 16 bars total
D = 50
prog = [
    ([55, 59, 62, 66, 69], 43),  # Gmaj9
    ([54, 57, 61, 64], 42),      # F#m7
    ([52, 55, 59, 62, 66], 40),  # Em9
    ([55, 59, 61, 64, 66], 45),  # A13
    ([55, 59, 62, 66, 69], 43),  # Gmaj9
    ([54, 57, 61, 64], 42),      # F#m7
    ([59, 62, 66, 69, 73], 47),  # Bm9
    ([55, 59, 60, 64, 67], 45),  # A7sus
]
bar = BEAT * 4
for i, (chord, root) in enumerate(prog):
    t0 = i * 2 * bar
    # bossa comping: hits on 1, 2&, 4 of bar 1 and 1&, 3 of bar 2
    hits = [0, 1.5, 3, 4.5, 6, 7]
    lens = [1.2, 1.0, 1.2, 1.2, 1.0, 0.8]
    for h, ln in zip(hits, lens):
        for k, n in enumerate(chord):
            add(epiano(n, ln * BEAT, 0.16 + 0.02 * rng.random()), t0 + h * BEAT + k * 0.006, pan=-0.25 + 0.12 * k, gain=1.0)
    # bass: root - fifth bossa pattern
    pat = [(0, root, 1.4), (1.5, root + 7, 0.45), (2, root + 7, 1.4), (3.5, root, 0.45),
           (4, root, 1.4), (5.5, root + 7, 0.45), (6, root + 7, 1.0), (7, root + 2, 0.9)]
    for b, n, ln in pat:
        add(bass(n - 12 + 12 * (n < 40), ln * BEAT, 0.22), t0 + b * BEAT, pan=0.0)

# drums: soft kick, rim pattern, brushes/shaker on 8ths with swing
for b in range(BARS * 4):
    t = b * BEAT
    if b % 4 in (0, 2):
        add(kick(0.18), t)
    if b % 2 == 1:
        add(noise_hit(0.25, 0.09, hp=6, vel=0.1), t, pan=0.15)  # brush swish on 2 and 4
for clave in [0, 1.5, 3, 5, 6.5]:  # bossa rim clave over 2 bars
    for rep in range(BARS // 2):
        add(rim(0.22), (rep * 8 + clave) * BEAT, pan=0.35)
for e in range(BARS * 8):
    swing = 0.06 * BEAT if e % 2 else 0.0
    add(noise_hit(0.05, 0.012, hp=3, vel=0.08 + 0.04 * (e % 2 == 0)), e * BEAT / 2 + swing, pan=-0.35)

# vibraphone melody in the second half (sparse, so it stays in the background)
mel = [(32, 74), (33.5, 76), (34, 78), (36, 76), (38, 73), (40, 71), (41.5, 73), (42, 74), (44, 76), (46, 69),
       (48, 74), (49, 76), (50, 78), (51.5, 81), (52, 78), (54, 76), (56, 74), (57.5, 73), (58, 71), (60, 69), (62, 66)]
for b, n in mel:
    add(vibes(n, 0.2), b * BEAT, pan=0.3)

# room reverb: convolve with decaying noise (FFT, circular so the tail wraps into the loop start)
def reverb(x, secs=1.6, mix=0.22, seed=0):
    r = np.random.default_rng(seed)
    n = int(SR * secs)
    ir = r.standard_normal(n) * np.exp(-np.arange(n) / SR / (secs / 5))
    ir[: int(SR * 0.012)] = 0
    ir /= np.sqrt(np.sum(ir ** 2))
    pad = np.zeros(len(x))
    pad[:n] = ir
    wet = np.real(np.fft.ifft(np.fft.fft(x) * np.fft.fft(pad)))
    return x + mix * wet

L = reverb(L, seed=1)
R = reverb(R, seed=2)
peak = max(np.abs(L).max(), np.abs(R).max())
L = L / peak * 0.85
R = R / peak * 0.85
st = np.stack([L, R], axis=1)
pcm = (st * 32767).astype(np.int16)

root = os.path.join(os.path.dirname(__file__), "..", "godot", "audio")
tmp = "/tmp/music_lounge.wav"
with wave.open(tmp, "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(pcm.tobytes())
out = os.path.join(root, "music_lounge.ogg")
subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4", out], check=True)
print("wrote", out, os.path.getsize(out) // 1024, "KB,", round(LEN / SR, 1), "s")
