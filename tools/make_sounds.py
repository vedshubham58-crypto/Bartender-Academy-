"""Makes the game's sound effects from scratch (no outside sound files).
Run: python3 tools/make_sounds.py  -> godot/audio/*.wav"""
import math, random, struct, wave, os

SR = 22050
OUT = os.path.join(os.path.dirname(__file__), "..", "godot", "audio")
random.seed(3)


def save(name, samples):
    os.makedirs(OUT, exist_ok=True)
    peak = max(1e-6, max(abs(s) for s in samples))
    with wave.open(os.path.join(OUT, name + ".wav"), "w") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s / peak * 0.9)) * 32767)) for s in samples))


def env(i, n, a=0.005, r=0.3):
    t = i / SR; dur = n / SR
    return min(1.0, t / a) * max(0.0, 1 - max(0.0, t - (dur - r)) / r)


def lowpass(x, k):
    y, out = 0.0, []
    for s in x:
        y += k * (s - y); out.append(y)
    return out


def noise(n):
    return [random.uniform(-1, 1) for _ in range(n)]


def tone(f, dur, decay=6.0, harm=(1, 0.5, 0.25)):
    n = int(SR * dur)
    return [sum(a * math.sin(2 * math.pi * f * (h + 1) * i / SR) for h, a in enumerate(harm)) * math.exp(-decay * i / SR) for i in range(n)]


# glass clink: bright inharmonic ring
def clink():
    n = int(SR * 0.6)
    fs = [2350, 3710, 5120, 6830]
    return [sum(math.sin(2 * math.pi * f * i / SR) * math.exp(-(7 + k * 3) * i / SR) / (k + 1) for k, f in enumerate(fs)) for i in range(n)]

save("clink", clink())

# ice: several short clinks + crunch
def ice():
    n = int(SR * 0.7); out = [0.0] * n
    for _ in range(9):
        st = random.randint(0, n - 4000); f = random.uniform(1800, 4200)
        for i in range(3500):
            out[st + i] += math.sin(2 * math.pi * f * i / SR) * math.exp(-28 * i / SR) * random.uniform(.4, 1)
    cr = lowpass(noise(n), .4)
    return [o + c * .25 * math.exp(-5 * i / SR) for i, (o, c) in enumerate(zip(out, cr))]

save("ice", ice())

# pour: gurgling filtered noise, loopable 2 s
def pour():
    n = SR * 2; x = lowpass(noise(n), .18)
    return [s * (0.7 + 0.3 * math.sin(2 * math.pi * 7.3 * i / SR) * math.sin(2 * math.pi * 1.7 * i / SR)) for i, s in enumerate(x)]

save("pour", pour())

# shake: ice rattling in a tin, loopable 1 s (two hits per second each way)
def shake():
    n = SR; out = [0.0] * n
    for hit in range(4):
        st = int(hit * n / 4)
        for _ in range(14):
            o = st + random.randint(0, 1200); f = random.uniform(2500, 6000)
            for i in range(min(1600, n - o)):
                out[o + i] += math.sin(2 * math.pi * f * i / SR) * math.exp(-40 * i / SR) * .5
        nz = noise(2500)
        for i in range(min(2500, n - st)):
            out[st + i] += nz[i] * .35 * math.exp(-12 * i / SR)
    return out

save("shake", shake())

# coin / tip: two bright bell notes
save("tip", [a + b for a, b in zip(tone(1318, .5, 7), [0.0] * 2400 + tone(1760, .5 - 2400 / SR, 7))])
# click
save("click", [s * math.exp(-60 * i / SR) for i, s in enumerate(tone(900, .06, 0))])
# good: rising arpeggio
good = []
for f in (523, 659, 784, 1046):
    good += tone(f, .12, 10)
save("good", good + tone(1318, .4, 6))
# bad: soft low double buzz
save("bad", [math.copysign(1, math.sin(2 * math.pi * 140 * i / SR)) * .3 * env(i, 4000, .01, .05) for i in range(4000)] + [0.0] * 1500 + [math.copysign(1, math.sin(2 * math.pi * 110 * i / SR)) * .3 * env(i, 5000, .01, .08) for i in range(5000)])
# slide: glass sliding on wood
sl = lowpass(noise(int(SR * .7)), .08)
save("slide", [s * math.sin(math.pi * i / len(sl)) for i, s in enumerate(sl)])
# muddle: dull thud
save("muddle", [s * math.exp(-25 * i / SR) for i, s in enumerate(lowpass(noise(5000), .05))])

# bar crowd ambience: murmur + soft clinks, loopable 8 s
def crowd():
    n = SR * 8; base = lowpass(lowpass(noise(n), .06), .3)
    out = [b * (0.6 + 0.4 * math.sin(2 * math.pi * .37 * i / SR) * math.sin(2 * math.pi * 1.9 * i / SR)) for i, b in enumerate(base)]
    for _ in range(6):
        st = random.randint(0, n - SR); f = random.uniform(2000, 4000)
        for i in range(8000):
            out[st + i] += math.sin(2 * math.pi * f * i / SR) * math.exp(-12 * i / SR) * .15
    return out

save("crowd", crowd())
print("done")
