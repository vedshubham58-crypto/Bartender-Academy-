# Records Bartender: Cocktail Academy Shorts/Reels. The game plays drinks by itself in
# Godot's Movie Maker mode (godot/tests/promo.tscn), and ffmpeg turns the landscape recording
# into a vertical 1080x1920 MP4: blurred bar behind, gameplay in the middle, a hook line on
# top, what the guest says or which step it is under the picture, and a call to action at the
# end. A caption file (.json: title, caption, hashtags) is written next to each clip.
#
# Each clip is one of several formats, so the feed isn't the same video every time:
#   guest      a guest orders, you make it, it slides over ("One Mojito, please!")
#   cinematic  film-style angles: wide rooftop, side of the bar, close-ups of the pour
#   learn      one drink, every step written on screen, the home recipe in the caption
#   pov        the classic first-person view with the game screen
#   mistake    one drink with a deliberate mistake for bartenders to spot (answer in the .json)
#   regulars   comedy: guests every bartender knows
# Without --format the format rotates through that list, one per posting day.
#
# Run from the repo root (needs godot on PATH, ffmpeg, and a display, e.g. xvfb-run):
#   python3 tools/make_shorts.py --out shorts --count 1
# Used by .github/workflows/shorts.yml (Monday, Wednesday and Friday).
import argparse, datetime, json, os, random, subprocess, sys

FORMATS = ["guest", "mistake", "whatif", "cinematic", "regulars", "learn", "pov"]
# Drinks the promo knows a deliberate mistake for (godot/tests/promo.gd MISTAKES).
MISTAKE_DRINKS = ["negroni", "margarita", "espresso_martini", "old_fashioned", "mojito"]
# Drinks with the most to watch (shake, muddle, layers, colour).
SHOW = ["mojito", "margarita", "espresso_martini", "cosmopolitan", "pina_colada", "tequila_sunrise",
        "whisky_sour", "daiquiri", "negroni", "long_island", "moscow_mule", "old_fashioned",
        "white_russian", "bees_knees", "lemon_drop", "sidecar", "gimlet", "manhattan", "bay_breeze",
        "planters_punch", "kamikaze", "gin_fizz", "spritz", "mexican_mule", "frozen_margarita"]
THEMES = ["warm", "blue", "gold"] # the pink lights look too red once blurred behind the clip
SKINS = ["steel", "copper", "gold", "black"]
BARTENDERS = ["remy", "louise"]

# Big line over the first seconds, per format: short, a question or a dare. No numbers.
HOOKS = {
    "guest": ["POV: a guest walks up to your bar", "Your first order of the night",
              "When a guest orders {a_d1}...", "Rooftop bar. Your shift. Go."],
    "cinematic": ["Rooftop bar after sunset", "Satisfying cocktail making",
                  "This is what a bar shift looks like", "Pour, shake, serve"],
    "learn": ["Learn {a_d1}, step by step", "How {a_d1} is really made",
              "Save this {d1} recipe", "Bartender school: the {d1}"],
    "mistake": ["Bartenders: spot the mistake", "Only real bartenders will spot it",
                "One thing is wrong here. What is it?"],
    "whatif": ["What happens if you serve a bad drink?"],
    "regulars": ["Guests every bartender knows", "Tag a bartender who has heard this",
                 "Every bar has this guest"],
    "pov": ["POV: your first shift at a rooftop bar", "Perfect pour or fail?",
            "Only real bartenders get this right", "Which one would you order?"],
}
TITLES = {
    "guest": ["A guest orders {a_d1} at the rooftop bar #shorts", "Making {a_d1} for a guest #shorts"],
    "cinematic": ["Making {a_d1} at a rooftop bar #shorts", "Satisfying cocktail making: {d1} and {d2} #shorts"],
    "learn": ["How to make {a_d1}, step by step #shorts", "Real {d1} recipe in a bartender game #shorts"],
    "mistake": ["Bartenders, spot the mistake in this {d1} #shorts", "What's wrong with this {d1}? #shorts"],
    "regulars": ["Guests every bartender knows #shorts", "Every bar has this guest #shorts"],
    "whatif": ["What happens if you serve a terrible drink? #shorts", "I found the secret ending in this bartender game #shorts"],
    "pov": ["Can you make {a_d1} this fast? #shorts", "Bartender game: {d1} or {d2}? #shorts"],
}
CAPTIONS = {
    "guest": ["Walk into a rooftop bar, take the order, mix it right. {d1} or {d2}, which one would you order?\n\n{cta}",
              "Every guest wants something different. Learn the real recipes behind the bar.\n\n{cta}"],
    "cinematic": ["Walk into a rooftop bar and learn to mix real cocktails, one pour at a time.\n\n{cta}",
                  "Learn cocktail making behind a real-looking bar and upskill like a pro.\n\n{cta}"],
    "learn": ["How to make {a_d1} at home:\n{home}\n\nLearn every recipe behind the bar in Bartender: Cocktail Academy.\n\n{cta}"],
    "mistake": ["One thing in this {d1} is wrong. Bartenders, tell us in the comments. Answer tomorrow.\n\n{cta}",
                "Real bartenders will see it straight away. What's wrong with this {d1}?\n\n{cta}"],
    "whatif": ["Too strong, too weak... and then the secret Legendary Serve. Can you find it?\n\n{cta}",
               "Every guest reacts to what you make. Pour it perfect, fast and from memory for the secret ending.\n\n{cta}"],
    "regulars": ["Tag the bartender who has heard every one of these.\n\n{cta}",
                 "Which guest do you get the most? Tell us in the comments.\n\n{cta}"],
    "pov": ["{d1} or {d2}? Tell us which one you'd order.\n\n{cta}",
            "Learn to mix cocktails behind the bar and upskill like a pro. Comment a cocktail and we'll make it next.\n\n{cta}"],
}
HASHTAGS = ["#bartender", "#cocktails", "#mobilegame", "#bartendergame", "#mixology", "#cocktailrecipe",
            "#androidgames", "#simulator", "#satisfying", "#gaming", "#indiegame", "#drinkresponsibly"]
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
# Inter (apt fonts-inter) looks cleaner; fall back to DejaVu when it isn't installed.
BIG = "/usr/share/fonts/opentype/inter/Inter-ExtraBold.otf"
SMALL = "/usr/share/fonts/opentype/inter/Inter-Bold.otf"
if not os.path.exists(BIG):
    BIG = SMALL = FONT
GOLD = "0xFFC93C"
# Under the opening picture, per format.
TEASE = {"mistake": "Watch closely", "regulars": "Tag a bartender", "guest": "Order up!",
         "learn": "Save it for later", "cinematic": "Sound on", "pov": "Could you do it?",
         "whatif": "Wait for the end"}
# Over the sped-up making: (white line, gold line).
BODY_TOP = {"regulars": ("EVERY BAR HAS THESE GUESTS", "Which one is yours?"),
            "guest": ("ONE {D1}, COMING UP", "Made behind the bar"),
            "pov": ("PERFECT POUR OR FAIL?", "Your shift starts now"),
            "whatif": ("WHAT HAPPENS IF...", "Watch the guest's face")}
# One clean music bed per clip (the game's own sounds are dropped), rotating by day.
MUSIC = ["music_disco", "music_tropical", "music_party", "music_lounge"]
# Big two-line text on the first frames: (white line, gold line). Short, a dare or a question.
OPENERS = {
    "mistake": [("ONLY REAL BARTENDERS", "SPOT THIS MISTAKE"), ("ONE THING IS WRONG", "CAN YOU SEE IT?")],
    "guest": [("YOUR FIRST ORDER", "OF THE NIGHT"), ("A GUEST WALKS UP", "TO YOUR BAR")],
    "cinematic": [("ROOFTOP BAR", "AFTER SUNSET"), ("THIS IS WHAT A", "BAR SHIFT LOOKS LIKE")],
    "learn": [("SAVE THIS", "{D1} RECIPE"), ("HOW A {D1}", "IS REALLY MADE")],
    "regulars": [("GUESTS EVERY", "BARTENDER KNOWS"), ("EVERY BAR", "HAS THIS GUEST")],
    "pov": [("PERFECT POUR", "OR FAIL?"), ("YOUR FIRST SHIFT", "AT A ROOFTOP BAR")],
    "whatif": [("WHAT HAPPENS IF", "YOU MESS UP A DRINK?"), ("SERVE A BAD DRINK", "AND WATCH THIS")],
}


def render(godot, avi, stats, fmt, drinks, theme, skin, bartender):
    cmd = [godot, "--path", "godot", "--rendering-method", "gl_compatibility", "--write-movie", avi,
           "--fixed-fps", "30", "--resolution", "1280x720", "res://tests/promo.tscn", "--",
           f"--format={fmt}", "--drinks=" + ",".join(drinks), f"--theme={theme}", f"--skin={skin}",
           f"--bartender={bartender}", f"--stats={stats}"]
    # a script error leaves Godot running (and recording) forever, so give up after 40 minutes
    # (a long two-drink clip takes over 15 minutes on GitHub's runners)
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL, timeout=2400)
    with open(stats) as f:
        return json.load(f)


def esc(path):
    return path.replace("\\", "\\\\").replace(":", "\\:").replace("'", "\\'")


def speak(lines, work, voice, speaker):
    """Narration for "vo" lines with Piper (offline TTS). Returns [(wav, seconds)] or None when
    no voice model is available, so the clip still gets made, just without a voice."""
    if not voice or not os.path.exists(voice):
        return None
    try:
        import wave
        from piper import PiperVoice
        from piper.config import SynthesisConfig
    except ImportError:
        return None
    v = PiperVoice.load(voice)
    out = []
    for i, line in enumerate(lines):
        path = os.path.join(work, f"vo{i}.wav")
        with wave.open(path, "wb") as w:
            v.synthesize_wav(line, w, syn_config=SynthesisConfig(speaker_id=speaker, length_scale=0.88))
        out.append((path, duration(path)))
    return out


def to_vertical(avi, mp4, work, fmt, opener, d1, cta, seconds, events, music, voice="", speaker=0):
    """Hook-first vertical cut, as Shubham asked on 2026-11-15:
    1. the finished drink, zoomed in, with a big two-line dare (2.2 s)
    2. the making, sped up, with the question on top
    3. (mistake) the drink again: "Did you spot it? Answer in the comments"
    4. end card with the game name and the call to action
    The game's own sounds are dropped for one music track."""
    files = []

    def text(value, size, color, y, font=BIG, enable=""):
        path = os.path.join(work, "t%d.txt" % len(files))
        with open(path, "w") as f:
            f.write(value)
        files.append(path)
        return (f"drawtext=fontfile={font}:textfile='{esc(path)}':fontsize={size}:fontcolor={color}"
                f":borderw=6:bordercolor=black@0.85:x=(w-text_w)/2:y={y}{enable}")

    def fit(value, size):
        # keep one line inside the 1080 px frame (about 0.62 em per capital letter)
        return min(size, int(1000 / (0.62 * max(len(value), 1))))

    # where the finished drink is on screen: the mistake line, else a few seconds before the end
    say = [e for e in events if e.get("kind") == "say"]
    vo = [e for e in events if e.get("kind") == "vo"]
    # (mistake: the "something is wrong" line; others: the drink just finished, a few seconds
    # before the last guest's thank-you, when the glass is in front of the camera)
    if fmt == "whatif" and len(vo) > 2:
        shot = vo[2]["at"] - 0.2 # steam out of the ears
    elif fmt == "mistake" and len(say) > 1:
        shot = say[-1]["at"] + 0.3
    elif len(say) > 1:
        shot = max(say[-1]["at"] - 3.0, 0.0)
    else:
        shot = max(seconds - 7.0, 0.0)
    learn = fmt == "learn"
    # guests' lines are the joke in these formats, so they need time to be read
    speed = 1.0 if learn else (1.25 if fmt in ("regulars", "guest") else (1.4 if fmt == "whatif" else 1.65))
    body_end = shot if fmt == "mistake" else max(seconds - 3.0, 1.0)
    segs = []  # (start, length in output seconds, speed, zoom, [text filters])
    w1, w2 = opener
    # regulars open straight on the guest's line: the joke is the hook
    if fmt != "regulars":
        segs.append((shot, 2.2, 1.0, 1.9, [text(w1, fit(w1, 82), "white", 200), text(w2, fit(w2, 92), GOLD, 300),
                                           text(TEASE.get(fmt, "Watch closely"), 58, "white", 1580, SMALL)]))
    if fmt == "mistake":
        top, sub = f"1 MISTAKE IN THIS {d1.upper()}", "Can you find it?"
    elif learn:
        top, sub = f"HOW TO MAKE {article(d1).upper()}", "Step by step"
    elif fmt in BODY_TOP:
        top, sub = BODY_TOP[fmt]
        top = top.format(D1=d1.upper())
    else:
        top, sub = d1.upper(), "Made behind the bar"
    body = [text(top, fit(top, 66), "white", 230), text(sub, 60, GOLD, 320, SMALL),
            text("Bartender: Cocktail Academy", 44, "white", 1690, SMALL)]
    # what guests say / which step it is, in the sped-up timeline, under the picture
    for e in say + [e for e in events if e.get("kind") == "step"]:
        a, b = (e["at"] - 0.6) / speed, (min(e["end"], body_end) - 0.6) / speed
        if b - a >= 0.4 and e["at"] < body_end:
            b = max(b, a + 2.2)
            for i, line in enumerate(wrap(e["text"], 28).split("\n")[:2]):
                body.append(text(line, 52, "0xFFE7B0", 1490 + i * 66, SMALL,
                                 f":enable='between(t,{max(a, 0):.2f},{b:.2f})'"))
    blen = max((body_end - 0.6) / speed, 3.0)
    segs.append((0.6, blen, speed, 1.45, body))
    if fmt == "mistake":
        segs.append((shot - 0.7, 3.6, 1.0, 1.7, [text("DID YOU SPOT IT?", 92, GOLD, 260),
                                                 text("Answer in the comments", 62, "white", 1580, SMALL)]))
    # the end card sits over the finished drink too, not the guest walking off
    if fmt == "whatif" and len(vo) > 1:
        tail = max(vo[-2]["at"] - 1.6, 0.0) # arms up, confetti
    else:
        tail = max(seconds - 3.0, 0.0) if fmt == "mistake" else max(shot - 0.3, 0.0)
    # narration: each line where it happens in the cut, never two at once
    spoken = speak([e["text"] for e in vo], work, voice, speaker) if vo else None
    end_start = sum(x[1] for x in segs)
    placed = []
    t_free = 0.0
    for k, e in enumerate(vo):
        t = e["at"] if e["at"] < 0.6 else (2.2 + (e["at"] - 0.6) / speed if e["at"] < body_end
                                           else end_start + (e["at"] - body_end))
        t = max(t, t_free)
        secs = spoken[k][1] if spoken else max(1.6, 0.36 * len(e["text"].split()))
        placed.append((t, secs, e["text"]))
        t_free = t + secs + 0.15
    end_len = max(2.8, (t_free - end_start + 0.4) if placed else 0.0)
    segs.append((tail, end_len, 1.0, 1.25, [text("Bartender:", 80, "white", 200), text("Cocktail Academy", 80, GOLD, 295),
                                        text(cta, fit(cta, 58), "white", 1560, SMALL),
                                        text("18+ only. Drink responsibly.", 44, "white", 1650, SMALL)]))
    parts = []
    for i, (start, length, sp, zoom, lines) in enumerate(segs):
        gw, gh = int(1080 * zoom) // 2 * 2, int(608 * zoom) // 2 * 2
        cut = f"trim=start={start:.2f}:duration={length * sp:.2f},setpts=(PTS-STARTPTS)/{sp}"
        vf = (f"[0:v]{cut},split=2[a][b];"
              f"[a]scale=3410:1920,crop=1080:1920,boxblur=30:3,eq=brightness=-0.22:saturation=1.2[bg];"
              f"[b]scale={gw}:{gh},crop=1080:{min(gh, 1000)}[fg];"
              f"[bg][fg]overlay=0:(H-h)/2+50,fps=30," + "".join(l + "," for l in lines) + "format=yuv420p[v]")
        part = os.path.join(work, f"part{i}.mp4")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", avi, "-filter_complex", vf, "-map", "[v]", "-an",
                        "-c:v", "libx264", "-preset", "medium", "-crf", "19", "-r", "30", part], check=True)
        parts.append(part)
    lst = os.path.join(work, "parts.txt")
    with open(lst, "w") as f:
        f.write("".join(f"file '{p}'\n" for p in parts))
    total = sum(s[1] for s in segs)
    # word-by-word captions for the narration: two or three words at a time, big, mid-screen
    caps = []
    for t, secs, line in placed:
        words = line.split()
        chunks = [words[i:i + 3] for i in range(0, len(words), 3)]
        at = t
        for ch in chunks:
            d = secs * len(ch) / len(words)
            word = " ".join(ch).upper()
            caps.append(text(word, fit(word, 84), "white", 1520, BIG, f":enable='between(t,{at:.2f},{at + d:.2f})'"))
            at += d
    inputs = ["-f", "concat", "-safe", "0", "-i", lst, "-ss", "8", "-i", music]
    music_vol = "1.0"
    mix = ""
    if spoken:
        music_vol = "0.32" # under the voice
        for k, (path, _) in enumerate(spoken):
            inputs += ["-i", path]
            ms = int(placed[k][0] * 1000)
            mix += f"[{k + 2}:a]adelay={ms}|{ms},volume=1.6[v{k}];"
        mix += "".join(f"[v{k}]" for k in range(len(spoken)))
    afilter = (f"[1:a]atrim=duration={total:.2f},volume={music_vol},afade=t=in:d=0.2,"
               f"afade=t=out:st={total - 1.2:.2f}:d=1.2[m];")
    if spoken:
        afilter += mix + f"[m]amix=inputs={len(spoken) + 1}:duration=first:normalize=0[mx];[mx]"
    else:
        afilter += "[m]"
    afilter += "loudnorm=I=-14:TP=-1.5[a]"
    vfilter = "[0:v]" + (",".join(caps) if caps else "null") + "[v]"
    subprocess.run(["ffmpeg", "-v", "error", "-y"] + inputs + [
        "-filter_complex", vfilter + ";" + afilter,
        "-map", "[v]", "-map", "[a]", "-c:v", "libx264", "-preset", "medium", "-crf", "20", "-r", "30",
        "-c:a", "aac", "-b:a", "160k", "-ar", "44100", "-t", f"{total:.2f}", "-movflags", "+faststart", mp4], check=True)
    if spoken:
        files.extend(p for p, _ in spoken)
    for k in files + parts + [lst]:
        if os.path.exists(k):
            os.remove(k)


def duration(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path],
                         capture_output=True, text=True).stdout.strip()
    try:
        return float(out)
    except ValueError:
        return 40.0


def wrap(text, width=24):
    lines, cur = [], ""
    for w in text.split():
        if cur and len(cur) + 1 + len(w) > width:
            lines.append(cur)
            cur = w
        else:
            cur = (cur + " " + w).strip()
    lines.append(cur)
    return "\n".join(lines)


def article(name):
    return ("an " if name[:1].lower() in "aeiou" else "a ") + name


def format_for(date):
    # Monday, Wednesday, Friday get the next format in turn, so it never repeats back to back.
    iso = date.isocalendar()
    slot = {0: 0, 2: 1, 4: 2}.get(date.weekday(), date.weekday() % 3)
    return FORMATS[(iso[1] * 3 + slot) % len(FORMATS)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="shorts")
    ap.add_argument("--godot", default="godot")
    ap.add_argument("--count", type=int, default=1)
    ap.add_argument("--format", default="", help="guest, mistake, cinematic, regulars, learn, pov, or all (one of each)")
    ap.add_argument("--cta", default="Coming soon on Google Play")
    ap.add_argument("--date", default=datetime.date.today().isoformat())
    ap.add_argument("--drinks", default="", help="comma-separated drink ids instead of the daily rotation")
    ap.add_argument("--voice", default=os.environ.get("PIPER_VOICE", ""), help="Piper .onnx voice for narrated formats")
    ap.add_argument("--speaker", type=int, default=105, help="speaker id in a multi-speaker Piper voice")
    a = ap.parse_args()
    a.out = os.path.abspath(a.out)
    os.makedirs(a.out, exist_ok=True)
    date = datetime.date.fromisoformat(a.date)
    day = date.toordinal()
    rnd = random.Random(day)
    if a.format == "all":
        formats = FORMATS
    elif a.format:
        formats = [a.format] * a.count
    else:
        first = FORMATS.index(format_for(date))
        formats = [FORMATS[(first + n) % len(FORMATS)] for n in range(a.count)]
    for n, fmt in enumerate(formats, 1):
        # Rotate drinks, looks and bartender day by day so the feed stays varied.
        k = (day * 4 + n) * 2
        drinks = a.drinks.split(",") if a.drinks else [SHOW[k % len(SHOW)], SHOW[(k + 7) % len(SHOW)]]
        if fmt == "mistake" and not a.drinks:
            drinks = [MISTAKE_DRINKS[(day + n) % len(MISTAKE_DRINKS)]]
        if fmt == "whatif" and not a.drinks:
            drinks.append(SHOW[(k + 13) % len(SHOW)])
        theme, skin = THEMES[(day + n) % len(THEMES)], SKINS[(day * 3 + n) % 4]
        bartender = BARTENDERS[(day + n) % 2]
        base = os.path.join(a.out, f"raw-{n}")
        s = render(a.godot, base + ".avi", base + ".json", fmt, drinks, theme, skin, bartender)
        print(f"clip {n} ({fmt}): {s}", flush=True)
        if s.get("fails", 0) or not s["drinks"]:
            print("clip failed, skipping", flush=True)
            continue
        d1 = s["drinks"][0]["name"]
        d2 = s["drinks"][1]["name"] if len(s["drinks"]) > 1 else d1
        home = s["drinks"][0].get("home", [])
        fill = {"d1": d1, "d2": d2, "a_d1": article(d1), "cta": a.cta,
                "home": "\n".join(f"{i}. {h}" for i, h in enumerate(home, 1))}
        hook = rnd.choice(HOOKS[fmt]).format(**fill)
        name = os.path.join(a.out, f"bartender-{a.date}-{n}")
        w1, w2 = rnd.choice(OPENERS[fmt])
        opener = (w1.format(D1=d1.upper()), w2.format(D1=d1.upper()))
        music = os.path.join("godot", "audio", MUSIC[(day + n) % len(MUSIC)] + ".ogg")
        to_vertical(base + ".avi", name + ".mp4", a.out, fmt, opener, d1, a.cta,
                    duration(base + ".avi"), s.get("events", []), os.path.abspath(music), a.voice, a.speaker)
        title = rnd.choice(TITLES[fmt]).format(**fill)[:100]
        tags = HASHTAGS[:4] + rnd.sample(HASHTAGS[4:-1], 4) + ["#drinkresponsibly"]
        caption = rnd.choice(CAPTIONS[fmt]).format(**fill) + "\n\n18+ only. Drink responsibly.\n\n" + " ".join(tags)
        if fmt == "whatif" and a.voice:
            caption += "\n\nVoice: Piper TTS, LibriTTS voice (CC BY 4.0)"
        with open(name + ".json", "w") as f:
            json.dump({"app": "Bartender: Cocktail Academy", "format": fmt, "title": title, "caption": caption,
                       "hashtags": tags, "hook": hook, "drinks": [x["name"] for x in s["drinks"]],
                       "made_for_kids": False, "answer": s.get("answer", ""), "stats": s}, f, indent=2, ensure_ascii=False)
        for ext in (".avi", ".json"):
            if os.path.exists(base + ext):
                os.remove(base + ext)
        print(f"wrote {name}.mp4: {title}", flush=True)


if __name__ == "__main__":
    sys.exit(main())
