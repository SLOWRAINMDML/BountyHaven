"""ima2 paint-over of the orthographic 3D renders (see blender/paint_project.py).

python3 paint/run_paint.py            # all passes not painted yet (2 at a time on the shared server)
python3 paint/run_paint.py body_pilot_front face_neutral   # specific passes (repaint)

Each job: unique folder paint/jobs/<pass>-<id>/ with prompt, json, log; the verified result is
registered onto the render silhouette (bbox fit) and written to paint/painted/<pass>.png.
"""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import json
import subprocess
import sys
import uuid

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PAINT = ROOT / "paint"
IMA2 = "/opt/homebrew/bin/ima2"
SERVER = "http://127.0.0.1:3333"
REPO = ROOT / "refs" / "BountyHaven_repo"
DESIGN = REPO / "assets/protagonist_customization/바운티헤이븐_주인공_디자인_시트.png"
OUTFIT_SHEET = REPO / "assets/protagonist_customization/현상금의_하늘_주인공_의상_시트.png"
HAIR_SHEET = REPO / "assets/protagonist_customization/바운티헤이븐_주인공_헤어_커스터마이징_시트.png"
EXPR_SHEET = REPO / "assets/protagonist_customization/바운티헤이븐_주인공_표정_시트.png"
TURN = ROOT / "concept/01_protagonist_turnaround.png"

STYLE = ("Finished BountyHaven character illustration: fine brown-black ink linework and translucent painterly watercolor and "
         "pigment washes exactly like the attached approved BountyHaven protagonist sheets. Matte weathered canvas, leather and metal, "
         "warm light from the upper left, soft slate-blue shade. Not glossy CGI, not photorealism, not flat vector.")
KEEP = ("CRITICAL: the FIRST attached image is an orthographic 3D render used as a projection template. Keep EXACTLY the same "
        "silhouette, pose, proportions, framing, position and scale as the first image - every outline edge, the arms, legs, head "
        "and each garment boundary must stay where it is so the painting can be projected back onto the 3D model. Only repaint the "
        "surface with illustration detail. Even frontal lighting, no cast shadow, plain pure white background, no text, no labels, "
        "no extra objects.")

OUTFIT_DESC = {
    "pilot": "01 PILOT JACKET: cream weathered canvas pilot jacket with rolled sleeves and a compass shoulder patch, dark navy undershirt, "
             "crossed leather harness straps with brass buckles, belt with pouches, dark grey cargo trousers with leather knee pads, "
             "brown buckled boots, dark leather gloves, rust-red scarf and short ragged rust-red cloak with a cream compass mark, "
             "leather satchel on the right hip",
    "vest": "02 TRAVEL VEST: cream rolled-sleeve undershirt, tan canvas travel vest with pockets, dark leather cross straps, "
            "tan canvas trousers with knee pads, brown buckled boots, rust-red scarf and short cloak",
    "mechanic": "04 MECHANIC JACKET: slate-blue work jacket with navy cuffs, oil stains and patches, cream undershirt, wrench on the belt, "
                "navy work trousers with knee pads, brown boots, rust-red scarf and short cloak",
    "guild": "06 GUILD COAT: long cream guild coat reaching the knees with rust-red cuffs and trim, navy undershirt, crossed harness, "
             "dark grey trousers, brown boots, rust-red scarf and short cloak",
}
HAIR_DESC = {
    "tousled": "01 TOUSLED (BASE) warm brown shaggy hair",
    "windswept": "03 WINDSWEPT warm brown hair swept to one side",
    "tied_low": "07 TIED BACK (LOW) warm brown hair tied in a low short tail",
    "tidy_crop": "02 TIDY CROP short neat warm brown hair",
    "messy_long": "12 MESSY LONG shoulder-length warm brown hair",
    "travel_braid": "09 TRAVEL BRAID tousled warm brown hair with a braid down the back",
}
EXPR_DESC = {
    "focused": "FOCUSED: calm narrowed eyes, level brows, closed mouth",
    "gentle_smile": "GENTLE SMILE: soft eyes, relaxed brows, small warm closed-mouth smile",
    "determined": "DETERMINED: firm lowered brows, steady eyes, set mouth with slightly downturned corners",
    "surprised": "SURPRISED: raised brows, wide open eyes, small open round mouth",
    "battle_ready": "BATTLE-READY: angry lowered brows, fierce eyes, mouth open in a shout",
    "tired": "TIRED: heavy half-closed eyelids, drooping brows, slack mouth",
    "worried": "WORRIED: inner brows raised, uneasy eyes, small downturned mouth",
    "eyes_closed": "EYES CLOSED: both eyes gently closed as when blinking, relaxed brows, neutral mouth",
}


VIEW_DESC = {
    "front": "front view",
    "back": "back view (show the back of the garments; the cloak shows the compass mark)",
    "left": "exact side profile view of the character's LEFT side (the character faces the left edge of the image)",
    "right": "exact side profile view of the character's RIGHT side (the character faces the right edge of the image)",
}


def jobs():
    out = []
    for o, desc in OUTFIT_DESC.items():
        for side in ("front", "back", "left", "right"):
            view = VIEW_DESC[side]
            out.append(dict(name=f"body_{o}_{side}", src=f"body_{o}_{side}", refs=[DESIGN, OUTFIT_SHEET, TURN],
                            prompt=f"{KEEP}\n\nRepaint as the BountyHaven protagonist, full body, {view}, wearing {desc}. "
                                   f"The face should read as in the design sheet (warm brown eyes, tousled brown hair).\n\n{STYLE}"))
    for h, desc in HAIR_DESC.items():
        for side in ("front", "back", "left", "right"):
            out.append(dict(name=f"hair_{h}_{side}", src=f"hair_{h}_{side}", refs=[HAIR_SHEET, DESIGN],
                            prompt=f"{KEEP}\n\nRepaint as a head-and-shoulders {VIEW_DESC[side]} of the BountyHaven protagonist with hairstyle "
                                   f"{desc} from the attached hair customization sheet: individual painted locks, ink strand lines, "
                                   f"warm highlights. Keep the hair mass exactly inside the render's hair silhouette.\n\n{STYLE}"))
    out.append(dict(name="face_neutral", src="head_bare_front", refs=[EXPR_SHEET, DESIGN],
                    prompt=f"{KEEP}\n\nPaint the face of the BountyHaven protagonist, front view, NEUTRAL expression, matching the "
                           f"attached expression sheet: warm brown eyes with dark upper lash lines and small highlights, brown brows, "
                           f"soft nose line, closed mouth, light freckle-free warm skin. The head is intentionally BALD because the hair "
                           f"is a separate 3D part: paint bare skin on the scalp, do NOT add any hair. Keep the scarf and jacket at the "
                           f"bottom as they are.\n\n{STYLE}"))
    for side in ("left", "right"):
        out.append(dict(name=f"head_bare_{side}", src=f"head_bare_{side}", refs=[DESIGN],
                        prompt=f"{KEEP}\n\nPaint the protagonist's BALD head, {VIEW_DESC[side]}, as plain warm skin with one ear and soft "
                               f"watercolor shading only. Do NOT paint any eye, eyebrow, nose, mouth or other facial feature (the face "
                               f"is textured from the front view); the front edge of the silhouette is just smooth skin. Hair is a separate "
                               f"3D part, do NOT add hair. Keep the scarf and collar at the bottom.\n\n{STYLE}"))
    out.append(dict(name="head_bare_back", src="head_bare_back", refs=[DESIGN],
                    prompt=f"{KEEP}\n\nPaint the back of the protagonist's BALD head and neck as bare warm skin with soft watercolor "
                           f"shading (hair is a separate 3D part, do NOT add hair), the scarf and jacket collar at the bottom.\n\n{STYLE}"))
    for e, desc in EXPR_DESC.items():
        out.append(dict(name=f"face_{e}", edit_of="face_neutral", src="head_bare_front", refs=[],
                        prompt=f"Change ONLY the facial expression to {desc}. Keep everything else identical: the same bald head, the "
                               f"same face shape, skin, eye colour, head position and size, the same scarf and collar, the same white "
                               f"background and the same ink and watercolor style."))
    return out


def run_one(job):
    render = PAINT / "renders" / f"{job['src']}.png"
    jd = PAINT / "jobs" / f"{job['name']}-{uuid.uuid4().hex[:8]}"
    jd.mkdir(parents=True, exist_ok=False)
    rgba = Image.open(render).convert("RGBA")
    flat = Image.new("RGB", rgba.size, (255, 255, 255))
    flat.paste(rgba, mask=rgba.split()[3])
    template = jd / "template.png"
    flat.save(template)
    (jd / "prompt.txt").write_text(job["prompt"], encoding="utf-8")
    out = jd / "result.png"
    base = ["--server", SERVER, "--provider", "oauth", "--model", "gpt-5.5", "--mode", "direct",
            "-q", "high", "-s", "1024x1024", "-o", str(out), "--timeout", "600", "--json"]
    if "edit_of" in job:
        cmd = [IMA2, "edit", str(PAINT / "painted" / f"{job['edit_of']}.png"), "--prompt", job["prompt"], "--no-web-search"] + base
    else:
        cmd = [IMA2, "gen", "--stdin", "--no-web-search"] + base + ["--ref", str(template)]
        for r in job["refs"]:
            cmd += ["--ref", str(r)]
    with (jd / "result.json").open("w") as so, (jd / "generate.log").open("w") as se:
        try:
            rc = subprocess.run(cmd, input=job["prompt"] if "edit_of" not in job else None, text=True,
                                stdout=so, stderr=se, timeout=900).returncode
        except subprocess.TimeoutExpired:
            return f"TIMEOUT {job['name']} {jd} (check ima2 ps; do not auto-retry)"
    try:
        data = json.loads((jd / "result.json").read_text())
    except json.JSONDecodeError:
        data = {}
    paths = [Path(i["path"]).resolve() for i in data.get("images", []) if i.get("path")]
    if data.get("path"):
        paths.append(Path(data["path"]).resolve())
    if rc != 0 or not data.get("ok") or out.resolve() not in paths or not out.is_file() or out.stat().st_size == 0:
        return f"FAIL {job['name']} rc={rc} {jd}/generate.log"
    register(out, rgba, PAINT / "painted" / f"{job['name']}.png", edit="edit_of" in job)
    return f"ok {job['name']}"


def bbox_alpha(im):
    return im.split()[3].point(lambda a: 255 if a > 20 else 0).getbbox()


def bbox_ink(im):
    g = im.convert("L").point(lambda v: 255 if v < 238 else 0)
    return g.getbbox()


def register(painted_path, render_rgba, dest, edit=False):
    """Fit the painted figure's bounding box onto the render's silhouette box."""
    dest.parent.mkdir(parents=True, exist_ok=True)
    p = Image.open(painted_path).convert("RGB")
    corners = [p.getpixel(xy) for xy in ((0, 0), (p.width - 1, 0), (0, p.height - 1), (p.width - 1, p.height - 1))]
    pts = ((0, 0), (p.width - 1, 0), (0, p.height - 1), (p.width - 1, p.height - 1), (p.width // 2, 0))
    dark = [xy for xy in pts if max(p.getpixel(xy)) < 40]
    if len(dark) >= 2:  # the model sometimes returns a black backdrop (shoulders may cover some corners)
        from PIL import ImageDraw
        for xy in dark:
            if max(p.getpixel(xy)) < 40:
                ImageDraw.floodfill(p, xy, (255, 255, 255), thresh=70)
    W, H = render_rgba.size
    if edit:  # edits keep the neutral face's registered framing: just match the canvas
        fill_silhouette(p.resize((W, H), Image.LANCZOS), render_rgba).save(dest)
        return
    rb, pb = bbox_alpha(render_rgba), bbox_ink(p)
    if not rb or not pb:
        p.resize((W, H), Image.LANCZOS).save(dest)
        return
    crop = p.crop(pb).resize((rb[2] - rb[0], rb[3] - rb[1]), Image.LANCZOS)
    canvas = Image.new("RGB", (W, H), (255, 255, 255))
    canvas.paste(crop, rb[:2])
    fill_silhouette(canvas, render_rgba).save(dest)


def fill_silhouette(canvas, render_rgba, iters=90, pad=18):
    """Where the 3D silhouette has no paint (painting slimmer than the model), grow the nearest
    painted colour outward so the projection never shows white paper on the mesh."""
    import numpy as np
    c = np.asarray(canvas, dtype=np.float32)
    inside = np.asarray(render_rgba.split()[3]) > 20
    for _ in range(pad):  # grow past the silhouette: side faces sample right at the edge
        inside = inside | np.roll(inside, 1, 0) | np.roll(inside, -1, 0) | np.roll(inside, 1, 1) | np.roll(inside, -1, 1)
    inside[:2, :] = inside[-2:, :] = False  # np.roll wraps around: keep the borders out
    inside[:, :2] = inside[:, -2:] = False
    valid = c.min(axis=2) < 236
    # erode the painted area first: its anti-aliased paper fringe and ink contour must not be
    # smeared outward (they read as white streaks on side faces)
    for _ in range(6):
        valid = valid & np.roll(valid, 1, 0) & np.roll(valid, -1, 0) & np.roll(valid, 1, 1) & np.roll(valid, -1, 1)
    rim = inside & ~valid
    for _ in range(iters):
        todo = inside & ~valid
        if not todo.any():
            break
        acc = np.zeros_like(c)
        cnt = np.zeros(valid.shape, dtype=np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sv = np.roll(valid, (dy, dx), axis=(0, 1)) & inside
            sc = np.roll(c, (dy, dx), axis=(0, 1))
            acc += sc * sv[..., None]
            cnt += sv
        grow = todo & (cnt > 0)
        c[grow] = acc[grow] / cnt[grow][:, None]
        valid = valid | grow
    return Image.fromarray(c.clip(0, 255).astype("uint8"))


def reregister():
    """Re-run registration on the latest finished job of every pass (no new generation)."""
    for job in jobs():
        dirs = sorted((PAINT / "jobs").glob(job["name"] + "-*"), key=lambda d: d.stat().st_mtime)
        dirs = [d for d in dirs if (d / "result.png").exists()]
        if not dirs:
            continue
        render = Image.open(PAINT / "renders" / f"{job['src']}.png").convert("RGBA")
        register(dirs[-1] / "result.png", render, PAINT / "painted" / f"{job['name']}.png", edit="edit_of" in job)
        print("reregistered", job["name"])


if __name__ == "__main__":
    if sys.argv[1:] == ["--reregister"]:
        reregister()
        sys.exit(0)
    wanted = set(sys.argv[1:])
    todo = [j for j in jobs() if (j["name"] in wanted) or (not wanted and not (PAINT / "painted" / f"{j['name']}.png").exists())]
    first = [j for j in todo if "edit_of" not in j]
    later = [j for j in todo if "edit_of" in j]
    with ThreadPoolExecutor(max_workers=2) as ex:
        for msg in ex.map(run_one, first):
            print(msg, flush=True)
        for msg in ex.map(run_one, later):
            print(msg, flush=True)

