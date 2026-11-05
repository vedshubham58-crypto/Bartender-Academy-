# Records Bartender: Cocktail Academy Shorts/Reels. The game makes two drinks by itself
# in Godot's Movie Maker mode (godot/tests/promo.tscn), and ffmpeg turns the landscape
# recording into a vertical 1080x1920 MP4: blurred bar behind, gameplay in the middle,
# a hook line on top and the drink names + call to action below. A caption file
# (.json: title, caption, hashtags) is written next to each clip.
#
# Run from the repo root (needs godot on PATH, ffmpeg, and a display, e.g. xvfb-run):
#   python3 tools/make_shorts.py --out shorts --count 2
# Used every day by .github/workflows/shorts.yml.
import argparse, datetime, json, os, random, subprocess, sys

# Drinks with the most to watch (shake, muddle, layers, colour). Two per clip.
SHOW = ["mojito", "margarita", "espresso_martini", "cosmopolitan", "pina_colada", "tequila_sunrise",
        "whisky_sour", "daiquiri", "negroni", "long_island", "moscow_mule", "old_fashioned",
        "white_russian", "bees_knees", "lemon_drop", "sidecar", "gimlet", "manhattan", "bay_breeze",
        "planters_punch", "kamikaze", "gin_fizz", "spritz", "mexican_mule"]
THEMES = ["warm", "blue", "pink", "gold"]
SKINS = ["steel", "copper", "gold", "black"]
BARTENDERS = ["remy", "louise"]

# Big line over the first seconds: short, a question or a dare.
HOOKS = [
    "Can you make a {d1} in 30 seconds?",
    "POV: your first shift at a rooftop bar",
    "Rate this {d1} 1 to 10",
    "Perfect pour or fail?",
    "2 cocktails. 40 seconds. Go.",
    "Bartender test: {d1} + {d2}",
    "Which one would you order?",
    "Satisfying cocktail making",
    "Only real bartenders get 3 stars",
    "How a {d1} is really made",
]
TITLES = [
    "Making a {d1} and a {d2} behind a rooftop bar #shorts",
    "Can you make a {d1} this fast? #shorts",
    "Satisfying cocktail pour: {d1} #shorts",
    "Bartender game: {d1} vs {d2}. Which one? #shorts",
    "Real {d1} recipe in a bartender game #shorts",
]
CAPTIONS = [
    "{d1} or {d2}? Tell me which one you'd order.\n\nReal recipe, {d1}: {home}\n\n{cta}",
    "Pour, shake, serve. {stars} stars on this shift.\nComment a cocktail and we'll make it next.\n\n{cta}",
    "Learn real cocktails behind a 3D rooftop bar. Today: {d1} and {d2}.\n\n{cta}",
]
HASHTAGS = ["#bartender", "#cocktails", "#mobilegame", "#bartendergame", "#mixology", "#cocktailrecipe",
            "#androidgames", "#simulator", "#satisfying", "#gaming", "#indiegame", "#drinkresponsibly"]
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"


def render(godot, avi, stats, drinks, theme, skin, bartender):
    cmd = [godot, "--path", "godot", "--rendering-method", "gl_compatibility", "--write-movie", avi,
           "--fixed-fps", "30", "--resolution", "1280x720", "res://tests/promo.tscn", "--",
           "--drinks=" + ",".join(drinks), f"--theme={theme}", f"--skin={skin}",
           f"--bartender={bartender}", f"--stats={stats}"]
    subprocess.run(cmd, check=True, stdout=subprocess.DEVNULL)
    with open(stats) as f:
        return json.load(f)


def esc(path):
    return path.replace("\\", "\\\\").replace(":", "\\:").replace("'", "\\'")


def to_vertical(avi, mp4, work, hook, below, cta, seconds):
    # Text goes through files so quotes and colons in it need no escaping.
    files = {}
    for k, v in {"hook": hook, "below": below, "cta": cta}.items():
        files[k] = os.path.join(work, k + ".txt")
        with open(files[k], "w") as f:
            f.write(v)
    end = max(seconds - 3.0, 0)
    box = "box=1:boxcolor=black@0.55:boxborderw=28"
    vf = (
        "[0:v]split=2[a][b];"
        "[a]scale=-2:1920,crop=1080:1920,boxblur=24:2,eq=brightness=-0.18[bg];"
        "[b]scale=1080:-2[fg];"
        "[bg][fg]overlay=0:(H-h)/2-60,"
        f"drawtext=fontfile={FONT}:textfile='{esc(files['hook'])}':fontsize=64:fontcolor=white:{box}:"
        "x=(w-text_w)/2:y=330:line_spacing=12,"
        f"drawtext=fontfile={FONT}:textfile='{esc(files['below'])}':fontsize=46:fontcolor=0xFFD27A:"
        "x=(w-text_w)/2:y=1390,"
        f"drawtext=fontfile={FONT}:textfile='{esc(files['cta'])}':fontsize=52:fontcolor=white:{box}:"
        f"x=(w-text_w)/2:y=1560:enable='gte(t,{end:.2f})',"
        "format=yuv420p[v]"
    )
    subprocess.run([
        "ffmpeg", "-v", "error", "-y", "-i", avi, "-filter_complex", vf, "-map", "[v]", "-map", "0:a?",
        "-c:v", "libx264", "-preset", "medium", "-crf", "21", "-r", "30",
        "-c:a", "aac", "-b:a", "160k", "-ar", "44100", "-af", "loudnorm=I=-14:TP=-1.5",
        "-movflags", "+faststart", mp4], check=True)


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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="shorts")
    ap.add_argument("--godot", default="godot")
    ap.add_argument("--count", type=int, default=2)
    ap.add_argument("--cta", default="Coming soon on Google Play")
    ap.add_argument("--date", default=datetime.date.today().isoformat())
    a = ap.parse_args()
    a.out = os.path.abspath(a.out)
    os.makedirs(a.out, exist_ok=True)
    day = datetime.date.fromisoformat(a.date).toordinal()
    rnd = random.Random(day)
    for n in range(1, a.count + 1):
        # Rotate drinks, looks and bartender day by day so the feed stays varied.
        k = (day * a.count + n) * 2
        drinks = [SHOW[k % len(SHOW)], SHOW[(k + 7) % len(SHOW)]]
        theme, skin = THEMES[(day + n) % 4], SKINS[(day * 3 + n) % 4]
        bartender = BARTENDERS[(day + n) % 2]
        base = os.path.join(a.out, f"raw-{n}")
        s = render(a.godot, base + ".avi", base + ".json", drinks, theme, skin, bartender)
        print(f"clip {n}: {s}", flush=True)
        if s.get("fails", 0) or len(s["drinks"]) < 2:
            print("clip failed, skipping", flush=True)
            continue
        d1, d2 = s["drinks"][0]["name"], s["drinks"][1]["name"]
        stars = s["stars"] / max(1, s["served"])
        fill = {"d1": d1, "d2": d2, "stars": f"{stars:.1f}".rstrip("0").rstrip("."), "cta": a.cta,
                "home": " ".join(s["drinks"][0].get("home", []))}
        hook = HOOKS[(day + n) % len(HOOKS)].format(**fill)
        name = os.path.join(a.out, f"bartender-{a.date}-{n}")
        to_vertical(base + ".avi", name + ".mp4", a.out, wrap(hook), f"{d1}  +  {d2}", a.cta,
                    duration(base + ".avi"))
        title = rnd.choice(TITLES).format(**fill)[:100]
        tags = HASHTAGS[:4] + rnd.sample(HASHTAGS[4:-1], 4) + ["#drinkresponsibly"]
        caption = rnd.choice(CAPTIONS).format(**fill) + "\n\n18+ only. Drink responsibly.\n\n" + " ".join(tags)
        with open(name + ".json", "w") as f:
            json.dump({"app": "Bartender: Cocktail Academy", "title": title, "caption": caption,
                       "hashtags": tags, "hook": hook, "drinks": [d1, d2], "made_for_kids": False,
                       "stats": s}, f, indent=2, ensure_ascii=False)
        for ext in (".avi", ".json"):
            if os.path.exists(base + ext):
                os.remove(base + ext)
        for t in ("hook", "below", "cta"):
            p = os.path.join(a.out, t + ".txt")
            if os.path.exists(p):
                os.remove(p)
        print(f"wrote {name}.mp4: {title}", flush=True)


if __name__ == "__main__":
    sys.exit(main())
