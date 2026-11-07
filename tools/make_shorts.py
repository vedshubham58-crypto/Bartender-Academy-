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
# Without --format the format rotates through that list, one per posting day.
#
# Run from the repo root (needs godot on PATH, ffmpeg, and a display, e.g. xvfb-run):
#   python3 tools/make_shorts.py --out shorts --count 1
# Used by .github/workflows/shorts.yml (Monday, Wednesday and Friday).
import argparse, datetime, json, os, random, subprocess, sys

FORMATS = ["guest", "cinematic", "learn", "pov"]
# Drinks with the most to watch (shake, muddle, layers, colour).
SHOW = ["mojito", "margarita", "espresso_martini", "cosmopolitan", "pina_colada", "tequila_sunrise",
        "whisky_sour", "daiquiri", "negroni", "long_island", "moscow_mule", "old_fashioned",
        "white_russian", "bees_knees", "lemon_drop", "sidecar", "gimlet", "manhattan", "bay_breeze",
        "planters_punch", "kamikaze", "gin_fizz", "spritz", "mexican_mule"]
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
    "pov": ["POV: your first shift at a rooftop bar", "Perfect pour or fail?",
            "Only real bartenders get this right", "Which one would you order?"],
}
TITLES = {
    "guest": ["A guest orders {a_d1} at the rooftop bar #shorts", "Making {a_d1} for a guest #shorts"],
    "cinematic": ["Making {a_d1} at a rooftop bar #shorts", "Satisfying cocktail making: {d1} and {d2} #shorts"],
    "learn": ["How to make {a_d1}, step by step #shorts", "Real {d1} recipe in a bartender game #shorts"],
    "pov": ["Can you make {a_d1} this fast? #shorts", "Bartender game: {d1} or {d2}? #shorts"],
}
CAPTIONS = {
    "guest": ["Walk into a rooftop bar, take the order, mix it right. {d1} or {d2}, which one would you order?\n\n{cta}",
              "Every guest wants something different. Learn the real recipes behind the bar.\n\n{cta}"],
    "cinematic": ["Walk into a rooftop bar and learn to mix real cocktails, one pour at a time.\n\n{cta}",
                  "Learn cocktail making behind a real-looking bar and upskill like a pro.\n\n{cta}"],
    "learn": ["How to make {a_d1} at home:\n{home}\n\nLearn every recipe behind the bar in Bartender: Cocktail Academy.\n\n{cta}"],
    "pov": ["{d1} or {d2}? Tell us which one you'd order.\n\n{cta}",
            "Learn to mix cocktails behind the bar and upskill like a pro. Comment a cocktail and we'll make it next.\n\n{cta}"],
}
HASHTAGS = ["#bartender", "#cocktails", "#mobilegame", "#bartendergame", "#mixology", "#cocktailrecipe",
            "#androidgames", "#simulator", "#satisfying", "#gaming", "#indiegame", "#drinkresponsibly"]
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def render(godot, avi, stats, fmt, drinks, theme, skin, bartender):
    cmd = [godot, "--path", "godot", "--rendering-method", "gl_compatibility", "--write-movie", avi,
           "--fixed-fps", "30", "--resolution", "1280x720", "res://tests/promo.tscn", "--",
           f"--format={fmt}", "--drinks=" + ",".join(drinks), f"--theme={theme}", f"--skin={skin}",
           f"--bartender={bartender}", f"--stats={stats}"]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL)
    with open(stats) as f:
        return json.load(f)


def esc(path):
    return path.replace("\\", "\\\\").replace(":", "\\:").replace("'", "\\'")


def to_vertical(avi, mp4, work, hook, below, cta, seconds, events):
    # Text goes through files so quotes and colons in it need no escaping.
    texts = {"hook": hook, "below": below, "cta": cta}
    for k, e in enumerate(events):
        texts[f"ev{k}"] = wrap(e["text"], 30)
    files = {}
    for k, v in texts.items():
        files[k] = os.path.join(work, k + ".txt")
        with open(files[k], "w") as f:
            f.write(v)
    end = max(seconds - 3.0, 0)
    box = "box=1:boxcolor=black@0.55:boxborderw=28"
    say = "box=1:boxcolor=white@0.94:boxborderw=26"
    lines = []
    for k, e in enumerate(events):
        a, b = max(0.0, e["at"]), min(e["end"], end)
        if b - a < 0.3:
            continue
        col = "0x2A1630" if e["kind"] == "say" else "0x1E1E1E"
        lines.append(f"drawtext=fontfile={FONT}:textfile='{esc(files[f'ev{k}'])}':fontsize=50:fontcolor={col}:{say}:"
                     f"x=(w-text_w)/2:y=1250:line_spacing=10:enable='between(t,{a:.2f},{b:.2f})'")
    vf = (
        "[0:v]split=2[a][b];"
        "[a]scale=-2:1920,crop=1080:1920,boxblur=24:2,eq=brightness=-0.18[bg];"
        "[b]scale=1080:-2[fg];"
        "[bg][fg]overlay=0:(H-h)/2-60,"
        f"drawtext=fontfile={FONT}:textfile='{esc(files['hook'])}':fontsize=64:fontcolor=white:{box}:"
        "x=(w-text_w)/2:y=330:line_spacing=12,"
        + "".join(l + "," for l in lines) +
        f"drawtext=fontfile={FONT}:textfile='{esc(files['below'])}':fontsize=46:fontcolor=0xFFD27A:"
        "x=(w-text_w)/2:y=1450,"
        f"drawtext=fontfile={FONT}:textfile='{esc(files['cta'])}':fontsize=52:fontcolor=white:{box}:"
        f"x=(w-text_w)/2:y=1580:enable='gte(t,{end:.2f})',"
        "format=yuv420p[v]"
    )
    subprocess.run([
        "ffmpeg", "-v", "error", "-y", "-i", avi, "-filter_complex", vf, "-map", "[v]", "-map", "0:a?",
        "-c:v", "libx264", "-preset", "medium", "-crf", "21", "-r", "30",
        "-c:a", "aac", "-b:a", "160k", "-ar", "44100", "-af", "loudnorm=I=-14:TP=-1.5",
        "-movflags", "+faststart", mp4], check=True)
    for k in files.values():
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
    ap.add_argument("--format", default="", help="guest, cinematic, learn, pov, or all (one of each)")
    ap.add_argument("--cta", default="Coming soon on Google Play")
    ap.add_argument("--date", default=datetime.date.today().isoformat())
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
        drinks = [SHOW[k % len(SHOW)], SHOW[(k + 7) % len(SHOW)]]
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
        below = f"How to make {article(d1)}" if fmt == "learn" else (d1 if d1 == d2 else f"{d1}  +  {d2}")
        name = os.path.join(a.out, f"bartender-{a.date}-{n}")
        to_vertical(base + ".avi", name + ".mp4", a.out, wrap(hook), below, a.cta,
                    duration(base + ".avi"), s.get("events", []))
        title = rnd.choice(TITLES[fmt]).format(**fill)[:100]
        tags = HASHTAGS[:4] + rnd.sample(HASHTAGS[4:-1], 4) + ["#drinkresponsibly"]
        caption = rnd.choice(CAPTIONS[fmt]).format(**fill) + "\n\n18+ only. Drink responsibly.\n\n" + " ".join(tags)
        with open(name + ".json", "w") as f:
            json.dump({"app": "Bartender: Cocktail Academy", "format": fmt, "title": title, "caption": caption,
                       "hashtags": tags, "hook": hook, "drinks": [x["name"] for x in s["drinks"]],
                       "made_for_kids": False, "stats": s}, f, indent=2, ensure_ascii=False)
        for ext in (".avi", ".json"):
            if os.path.exists(base + ext):
                os.remove(base + ext)
        print(f"wrote {name}.mp4: {title}", flush=True)


if __name__ == "__main__":
    sys.exit(main())
