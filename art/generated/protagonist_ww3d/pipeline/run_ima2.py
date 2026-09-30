"""Sequential ima2 (Codex / GPT OAuth) generation for the WW-style protagonist.

Usage: python3 run_ima2.py [job_name ...]
Each job writes concepts/jobs/<name>-<uuid>/ and the verified result is copied to concepts/<name>.png.
"""
from pathlib import Path
import json, shutil, subprocess, sys, uuid

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent
REPO = ROOT.parents[2]
IMA2 = "/opt/homebrew/bin/ima2"
SERVER = "http://127.0.0.1:3333"

spec = json.loads((HERE / "jobs.json").read_text(encoding="utf-8"))
wanted = set(sys.argv[1:])
for job in spec["jobs"]:
    if wanted and job["name"] not in wanted:
        continue
    final = ROOT / "concepts" / f"{job['name']}.png"
    if final.exists() and not wanted:
        print(f"skip {job['name']}", flush=True)
        continue
    job_dir = ROOT / "concepts" / "jobs" / f"{job['name']}-{uuid.uuid4().hex[:8]}"
    job_dir.mkdir(parents=True)
    out = job_dir / "result.png"
    prompt = f"{job['prompt']}\n\nStyle: {spec['style']}"
    (job_dir / "prompt.txt").write_text(prompt, encoding="utf-8")
    cmd = [IMA2, "gen", "--stdin", "--server", SERVER, "--provider", "oauth", "--model", "gpt-5.5",
           "--mode", "direct", "--no-web-search", "-q", "high", "-s", job.get("size", "1024x1024"),
           "-o", str(out), "--timeout", "600", "--json"]
    for r in job.get("refs", []):
        cmd += ["--ref", str(REPO / r)]
    print(f"run {job['name']}", flush=True)
    with (job_dir / "result.json").open("w") as so, (job_dir / "generate.log").open("w") as se:
        try:
            rc = subprocess.run(cmd, input=prompt, text=True, stdout=so, stderr=se, timeout=900).returncode
        except subprocess.TimeoutExpired:
            print(f"TIMEOUT {job['name']}", flush=True); continue
    if rc == 0 and out.is_file() and out.stat().st_size > 0:
        shutil.copy2(out, final); print(f"ok {job['name']}", flush=True)
    else:
        print(f"FAIL {job['name']} rc={rc} {job_dir}", flush=True)
