"""Build the results page (HTML + JPG images) from iterations/iterNN/{sheet.png,score.json,notes.md,vfx.png}.

python3 build_report.py <out_dir>
"""
import html, json, os, sys, glob
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
OUT = sys.argv[1]
os.makedirs(os.path.join(OUT, "img"), exist_ok=True)


def jpg(src, name, width):
    if not os.path.exists(src) and os.path.exists(src[:-4] + ".jpg"):
        src = src[:-4] + ".jpg"            # committed iterations keep JPG copies only
    im = Image.open(src).convert("RGB")
    if im.width > width:
        im = im.resize((width, int(im.height * width / im.width)), Image.LANCZOS)
    im.save(os.path.join(OUT, "img", name), quality=84, optimize=True)
    return "img/" + name


iters = []
for d in sorted(glob.glob(os.path.join(ROOT, "iterations", "iter*"))):
    if not os.path.exists(os.path.join(d, "score.json")):
        continue
    n = os.path.basename(d)
    sc = json.load(open(os.path.join(d, "score.json")))
    notes = open(os.path.join(d, "notes.md")).read().split("\n", 2)[-1].strip() if os.path.exists(os.path.join(d, "notes.md")) else sc["note"]
    it = {"name": n, "score": sc, "notes": notes, "sheet": jpg(os.path.join(d, "sheet.png"), f"{n}_sheet.jpg", 2600)}
    if any(os.path.exists(os.path.join(d, "vfx" + e)) for e in (".png", ".jpg")):
        it["vfx"] = jpg(os.path.join(d, "vfx.png"), f"{n}_vfx.jpg", 1600)
    for extra in ("beauty.png", "vfx2.png", "godot.png"):
        if any(os.path.exists(os.path.join(d, extra[:-4] + e)) for e in (".png", ".jpg")):
            it[extra.split(".")[0]] = jpg(os.path.join(d, extra), f"{n}_{extra.split('.')[0]}.jpg", 1600)
    iters.append(it)

faces = []
for d in sorted(glob.glob(os.path.join(ROOT, "iterations", "face_iter*"))):
    if not os.path.exists(os.path.join(d, "face_score.json")):
        continue
    n = os.path.basename(d)
    fs = json.load(open(os.path.join(d, "face_score.json")))
    notes = open(os.path.join(d, "notes.md")).read().split("\n", 2)[-1].strip() if os.path.exists(os.path.join(d, "notes.md")) else fs["note"]
    f = {"name": n, "score": fs, "notes": notes, "sheet": jpg(os.path.join(d, "face_sheet.png"), f"{n}_sheet.jpg", 2600)}
    if any(os.path.exists(os.path.join(d, "face_before_after" + e)) for e in (".png", ".jpg")):
        f["ba"] = jpg(os.path.join(d, "face_before_after.png"), f"{n}_before_after.jpg", 1400)
    if any(os.path.exists(os.path.join(d, "godot" + e)) for e in (".png", ".jpg")):
        f["godot"] = jpg(os.path.join(d, "godot.png"), f"{n}_godot.jpg", 1600)
    faces.append(f)

last = iters[-1]
refs = [("design sheet (canonical)", os.path.join(ROOT, "..", "..", "..", "assets", "protagonist_customization", "바운티헤이븐_주인공_디자인_시트.png")),
        ("Codex turnaround (style target)", os.path.join(ROOT, "concepts", "01_ww_turnaround.png")),
        ("Codex face sheet", os.path.join(ROOT, "concepts", "02_ww_face.png")),
        ("Codex VFX key art", os.path.join(ROOT, "concepts", "06_ww_vfx_keyart.png"))]
ref_imgs = [(lab, jpg(p, f"ref{i}.jpg", 1200)) for i, (lab, p) in enumerate(refs) if os.path.exists(p)]

# chart: mean IoU (higher better) and mean height error (lower better) per iteration
W, H, P = 640, 220, 40
ious = [i["score"]["mean_iou"] for i in iters]
herr = [i["score"]["mean_height_err_pct"] for i in iters]
lo, hi = min(0.6, min(ious) - 0.02), max(0.9, max(ious) + 0.02)
xs = [P + (W - 2 * P) * k / max(1, len(iters) - 1) for k in range(len(iters))]
y_iou = [H - P - (H - 2 * P) * (v - lo) / (hi - lo) for v in ious]
pts = " ".join(f"{x:.1f},{y:.1f}" for x, y in zip(xs, y_iou))
ticks = "".join(f'<line x1="{P}" x2="{W - P}" y1="{H - P - (H - 2 * P) * (t - lo) / (hi - lo):.1f}" y2="{H - P - (H - 2 * P) * (t - lo) / (hi - lo):.1f}" class="grid"/>'
                f'<text x="{P - 6}" y="{H - P - (H - 2 * P) * (t - lo) / (hi - lo) + 4:.1f}" class="tick" text-anchor="end">{t:.2f}</text>'
                for t in [round(lo + (hi - lo) * k / 4, 2) for k in range(5)])
labels = "".join(f'<text x="{x:.1f}" y="{H - P + 18}" class="tick" text-anchor="middle">{k:02d}</text>' for k, x in enumerate(xs))
dots = "".join(f'<circle cx="{x:.1f}" cy="{y:.1f}" r="{5 if k == len(xs) - 1 else 3}" class="dot"/>' for k, (x, y) in enumerate(zip(xs, y_iou)))
chart = f'<svg viewBox="0 0 {W} {H}" role="img" aria-label="mean silhouette IoU per iteration">{ticks}{labels}<polyline points="{pts}" class="line"/>{dots}</svg>'

rows = "".join(
    f'<tr><td>{i["name"]}</td><td>{i["score"]["mean_iou"]:.3f}</td>'
    + "".join(f'<td>{i["score"]["iou"][v]["iou"]:.3f}</td>' for v in ("front", "q34", "side", "back"))
    + f'<td>{i["score"]["mean_height_err_pct"]:.2f}%</td><td>{i["score"]["mean_width_err_pct"]:.1f}%</td></tr>'
    for i in iters)

face_html = ""
if faces:
    f0, f1 = faces[0], faces[-1]
    frows = "".join(
        f'<tr><td>{f["name"].replace("face_iter", "F")}</td><td>{f["score"]["mean_lm_err_pct"]:.1f}%</td><td>{f["score"]["mean_skin_iou"]:.3f}</td>'
        f'<td>{f["score"].get("skin_color_err", 0):.0f}</td>'
        + "".join(f'<td>{f["score"]["views"][v]["mean_lm_err_pct"]:.1f}%</td>' for v in ("front", "q34", "side"))
        + f'<td class="l">{html.escape(f["notes"])}</td></tr>' for f in faces)
    fsecs = "".join(f'''<section class="iter" id="{f["name"]}"><header><h3>{f["name"]}</h3><p class="note">{html.escape(f["notes"])}</p>
  <p class="metrics">landmark error <b>{f["score"]["mean_lm_err_pct"]:.1f}%</b> · outline IoU <b>{f["score"]["mean_skin_iou"]:.3f}</b> · skin colour <b>{f["score"].get("skin_color_err", 0):.0f}</b></p></header>
  <div class="wide"><a href="{f["sheet"]}"><img src="{f["sheet"]}" alt="{f["name"]} face sheet" loading="lazy"></a></div>
  {f'<div class="pair"><figure><img src="{f["godot"]}" alt="Godot capture" loading="lazy"><figcaption>Godot 4.7.1 capture</figcaption></figure></div>' if "godot" in f else ""}
</section>''' for f in reversed(faces))
    ba = f1.get("ba")
    face_html = f'''<section id="face10"><div class="eyebrow">얼굴 10회</div><h2 style="font-size:28px">얼굴만 10회 반복</h2>
<p class="lede">기준은 표정 시트 NEUTRAL(정면), PROFILE(측면), 얼굴 시트 NEUTRAL PORTRAIT(3/4)입니다. 눈·눈썹·코·입·입꼬리·턱·귀 위치를 격자로 재서 기록했습니다. 채점할 때는 두 눈(측면은 눈과 턱)으로 렌더를 일러스트에 정렬하고, 나머지 랜드마크 오차(눈 간격 대비 %), 피부 윤곽 IoU, 피부색 오차를 잽니다. 일러스트마다 머리 각도가 달라서 카메라 각도는 뷰별 허용 범위(정면 ±6°, 3/4 30–66°, 측면 80–100°) 안에서 맞췄습니다. 몸 형태는 바꾸지 않았습니다.</p>
<div class="grid2" style="margin-top:16px">
  <div class="card"><h2>전후 비교</h2>{f'<img src="{ba}" alt="face before and after" style="width:100%;border-radius:4px">' if ba else ""}</div>
  <div class="card"><h2>점수 {f0["name"].replace("face_iter", "F")} → {f1["name"].replace("face_iter", "F")}</h2>
   <p class="metrics">랜드마크 오차 <b>{f0["score"]["mean_lm_err_pct"]:.1f}% → {f1["score"]["mean_lm_err_pct"]:.1f}%</b> · 윤곽 IoU <b>{f0["score"]["mean_skin_iou"]:.3f} → {f1["score"]["mean_skin_iou"]:.3f}</b> · 피부색 오차 <b>{f0["score"].get("skin_color_err", 0):.0f} → {f1["score"].get("skin_color_err", 0):.0f}</b></p>
   <div class="scroll"><table><thead><tr><th>iter</th><th>랜드마크</th><th>IoU</th><th>피부색</th><th>정면</th><th>3/4</th><th>측면</th><th class="l">변경</th></tr></thead><tbody>{frows}</tbody></table></div>
   <h2 style="margin-top:16px">아직 다른 점</h2><ul>
    <li>일러스트 타일끼리도 비율이 다릅니다. 코 높이가 눈~턱 거리 대비 정면 0.41, 측면 0.64, 3/4 0.31이어서, 3D는 세 뷰를 절충했습니다. 측면(18.9%)과 3/4(15.9%) 오차가 남는 주된 이유입니다.</li>
    <li>3/4에서 입이 일러스트보다 먼 쪽에 있습니다. 얼굴 앞면을 둥글게 해 봤지만 점수가 나빠져 되돌렸습니다.</li>
    <li>얼굴 음영은 매끈한 툰 경계에 칠한 형태 그림자를 더한 방식입니다. 일러스트 같은 붓 질감과 볼 주근깨·잡티는 없습니다.</li>
    <li>머리카락과 스카프는 얼굴 반복 범위 밖이라 그대로입니다. 일러스트의 부스스한 머리와 두건형 스카프와는 다릅니다.</li>
   </ul></div>
</div>
<table style="display:none"></table>
</section>
<section><h2>얼굴 반복 기록 (최신순)</h2></section>
{fsecs}'''

sections = []
for i in reversed(iters):
    s = i["score"]
    extra = ""
    for key, lab in (("vfx", "VFX shot"), ("vfx2", "VFX shot 2"), ("beauty", "beauty"), ("godot", "Godot 4.7.1 capture")):
        if key in i:
            extra += f'<figure><img src="{i[key]}" alt="{i["name"]} {lab}" loading="lazy"><figcaption>{lab}</figcaption></figure>'
    werr = ", ".join(f"{k} {v}%" for k, v in s["width_err_pct"].items())
    sections.append(f'''<section class="iter" id="{i["name"]}">
  <header><h3>{i["name"]}</h3><p class="note">{html.escape(i["notes"])}</p>
  <p class="metrics">IoU <b>{s["mean_iou"]:.3f}</b> · height error <b>{s["mean_height_err_pct"]:.2f}% H</b> · width error <b>{s["mean_width_err_pct"]:.1f}%</b> <span>({werr})</span></p></header>
  <div class="wide"><a href="{i["sheet"]}"><img src="{i["sheet"]}" alt="{i["name"]} illustration vs 3D sheet" loading="lazy"></a></div>
  <div class="pair">{extra}</div>
</section>''')

hero = last.get("vfx2") or last.get("vfx") or last["sheet"]
page = f'''<title>BountyHaven 3D 명조풍 주인공</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=IBM+Plex+Sans+KR:wght@400;600&family=IBM+Plex+Mono:wght@400;600&family=Black+Han+Sans&display=swap">
<style>
:root {{ --bg:#eceef0; --panel:#f7f8f9; --ink:#1d2127; --mute:#5c636d; --line:#cfd4da; --rust:#b3452c; --brass:#a87a2c; color-scheme:light; }}
@media (prefers-color-scheme: dark) {{ :root:not([data-theme="light"]) {{ --bg:#14171c; --panel:#1c2027; --ink:#e7e9ec; --mute:#9aa2ad; --line:#2f353e; --rust:#e0714f; --brass:#d9aa55; color-scheme:dark; }} }}
:root[data-theme="dark"] {{ --bg:#14171c; --panel:#1c2027; --ink:#e7e9ec; --mute:#9aa2ad; --line:#2f353e; --rust:#e0714f; --brass:#d9aa55; color-scheme:dark; }}
body {{ background:var(--bg); color:var(--ink); font:15px/1.65 "IBM Plex Sans KR", system-ui, sans-serif; padding-inline:clamp(16px,4vw,48px); padding-block:32px 64px; }}
main {{ max-width:1400px; margin:0 auto; display:flex; flex-direction:column; gap:40px; }}
h1 {{ font-family:"Black Han Sans","IBM Plex Sans KR",sans-serif; font-weight:400; font-size:clamp(30px,5vw,52px); line-height:1.1; margin:0; text-wrap:balance; }}
h2 {{ font-size:20px; margin:0 0 12px; }} h3 {{ font-family:"IBM Plex Mono",monospace; font-size:18px; margin:0; color:var(--rust); }}
.lede {{ max-width:68ch; color:var(--mute); margin:8px 0 0; }}
.eyebrow {{ font:600 12px "IBM Plex Mono",monospace; letter-spacing:.12em; text-transform:uppercase; color:var(--brass); }}
.hero img {{ width:100%; border-radius:6px; display:block; }}
.grid2 {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(min(100%,420px),1fr)); gap:24px; align-items:start; }}
.card {{ background:var(--panel); border:1px solid var(--line); border-radius:6px; padding:18px; }}
table {{ border-collapse:collapse; width:100%; font:13px "IBM Plex Mono",monospace; font-variant-numeric:tabular-nums; }}
th,td {{ padding:5px 8px; border-bottom:1px solid var(--line); text-align:right; }} th:first-child,td:first-child,.l {{ text-align:left; }} td.l {{ font-family:"IBM Plex Sans KR",sans-serif; min-width:260px; }}
th {{ color:var(--mute); font-weight:600; }}
.scroll {{ overflow-x:auto; }}
svg {{ width:100%; height:auto; }} .grid {{ stroke:var(--line); }} .tick {{ fill:var(--mute); font:11px "IBM Plex Mono",monospace; }}
.line {{ fill:none; stroke:var(--rust); stroke-width:2.5; }} .dot {{ fill:var(--rust); }}
.refs {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(min(100%,260px),1fr)); gap:14px; }}
figure {{ margin:0; }} figure img {{ width:100%; border-radius:4px; display:block; }} figcaption {{ font-size:12px; color:var(--mute); margin-top:4px; }}
.iter {{ border-top:1px solid var(--line); padding-top:20px; display:flex; flex-direction:column; gap:12px; }}
.note {{ margin:4px 0; max-width:90ch; }} .metrics {{ margin:0; font:13px "IBM Plex Mono",monospace; color:var(--mute); }} .metrics b {{ color:var(--ink); }}
.wide {{ overflow-x:auto; }} .wide img {{ min-width:1100px; max-width:none; width:100%; display:block; border-radius:4px; }}
.pair {{ display:grid; grid-template-columns:repeat(auto-fit,minmax(min(100%,420px),1fr)); gap:16px; }}
ul {{ margin:0; padding-left:20px; }} li {{ margin:4px 0; }} code {{ font:12px "IBM Plex Mono",monospace; }}
a {{ color:var(--rust); }} a:focus-visible {{ outline:2px solid var(--brass); }}
</style>
<main>
<header>
  <div class="eyebrow">BountyHaven · protagonist_ww3d · Blender 5.2 + Codex(ima2)</div>
  <h1>명조풍 3D 주인공 — 처음부터 만든 툰 모델</h1>
  <p class="lede">바운티헤이븐 주인공 디자인 시트에서 머리·눈·턱·어깨·허리·무릎 높이를 측정해 몸을 로프트로 만들고, 셀 셰이딩·외곽선·레이어드 의상·헤어 락·VFX를 올렸습니다. 이미지(눈·눈썹·입 데칼, 문양, 시질, 천 텍스처, 스타일 타깃)는 Codex(ima2, GPT OAuth)로 생성했습니다. 반복 {len(iters) - 1}회, 최신은 {last["name"]}.</p>
</header>
<section class="hero"><img src="{hero}" alt="latest VFX render"></section>
{face_html}
<section class="grid2">
  <div class="card"><h2>실루엣 IoU (일러스트 vs 3D, 4뷰 평균)</h2>{chart}</div>
  <div class="card scroll"><h2>반복별 점수</h2><table><thead><tr><th>iter</th><th>mean</th><th>front</th><th>3/4</th><th>side</th><th>back</th><th>높이 오차</th><th>폭 오차</th></tr></thead><tbody>{rows}</tbody></table>
  <p class="metrics" style="margin-top:10px">높이 오차: hair top·skull·eye·chin·fingertip·waist·crotch·knee·sole, 전신 높이 대비 %. 폭 오차: face·hair·shoulder·feet span. 모두 Blender의 평가된 메시에서 측정.</p></div>
</section>
<section class="grid2">
  <div class="card"><h2>최종 상태</h2><ul>
    <li>Blender 5.2 헤드리스 스크립트로 처음부터 생성: 측정 로프트 바디, 헤어 락 약 110개, 레이어드 의상, 리그 16본.</li>
    <li>GLB: <code>exports/bountyhaven_hero_ww.glb</code> (Idle, Slash 애니메이션, 망토 바람 모프). Godot 4.7.1 Compatibility에서 툰·외곽선 셰이더, 시질·슬래시 셰이더, GPU 파티클까지 캡처 확인.</li>
    <li>Codex(ima2) 생성물: 스타일 타깃, 얼굴 시트, 눈·눈썹·입 데칼, 문양, 시질, 천 텍스처, VFX 키아트.</li>
  </ul></div>
  <div class="card"><h2>일러스트와 아직 다른 점</h2><ul>
    <li>머리카락이 일러스트보다 덜 부스스하고 가닥 수가 적습니다. 폭은 3% 이내로 맞췄습니다.</li>
    <li>스카프가 매끈한 튜브처럼 보입니다. 천 주름과 매듭 조형이 더 필요합니다.</li>
    <li>재킷 스티치, 금속 리벳, 부츠 버클처럼 작은 장비 디테일이 일러스트보다 적습니다.</li>
    <li>측면 IoU(0.76)가 가장 낮습니다. 일러스트 측면이 약간 돌아간 3/4 구도이고 가방 위치도 다르기 때문입니다.</li>
    <li>얼굴은 데칼 기반이라 표정 세트는 아직 없습니다. 기존 표정 시트로 데칼을 교체하면 됩니다.</li>
  </ul></div>
</section>
<section><h2>참조 이미지</h2><div class="refs">{"".join(f'<figure><img src="{p}" alt="{html.escape(l)}" loading="lazy"><figcaption>{html.escape(l)}</figcaption></figure>' for l, p in ref_imgs)}</div></section>
<section><h2>반복 기록 (최신순)</h2><p class="lede">각 시트: 뷰마다 일러스트 · 3D · 오버레이(분홍 선 = 일러스트 실루엣). 아래 줄은 얼굴 비교와 VFX 샷.</p></section>
{"".join(sections)}
</main>
'''
open(os.path.join(OUT, "index.html"), "w").write(page)
print("report", len(iters), "iterations")
