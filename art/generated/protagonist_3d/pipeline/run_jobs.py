"""Sequential ima2 concept generation following the shared-server manual.

Usage: python3 concept/run_jobs.py [job_name ...]
Each job writes into its own unique folder concept/jobs/<name>-<uuid>/ and the
verified result is copied to concept/<name>.png. Jobs run one at a time.
"""
from pathlib import Path
import json
import shutil
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parent.parent
IMA2 = "/opt/homebrew/bin/ima2"
SERVER = "http://127.0.0.1:3333"

spec = json.loads((ROOT / "concept" / "jobs.json").read_text(encoding="utf-8"))
wanted = set(sys.argv[1:])
refs = [str(ROOT / r) for r in spec["refs"]]

for job in spec["jobs"]:
    if wanted and job["name"] not in wanted:
        continue
    final = ROOT / "concept" / f"{job['name']}.png"
    if final.exists() and not wanted:
        print(f"skip {job['name']} (exists)", flush=True)
        continue
    job_dir = ROOT / "concept" / "jobs" / f"{job['name']}-{uuid.uuid4().hex[:8]}"
    job_dir.mkdir(parents=True, exist_ok=False)
    out = job_dir / "result.png"
    prompt = f"{job['prompt']}\n\nStyle: {spec['style']}"
    (job_dir / "prompt.txt").write_text(prompt, encoding="utf-8")
    cmd = [IMA2, "gen", "--stdin", "--server", SERVER, "--provider", "oauth",
           "--model", "gpt-5.5", "--mode", "direct", "--no-web-search",
           "-q", "high", "-s", job.get("size", "1024x1024"),
           "-o", str(out), "--timeout", "600", "--json"]
    for r in [str(ROOT / x) for x in job["refs"]] if "refs" in job else refs:
        cmd += ["--ref", r]
    print(f"run {job['name']} -> {job_dir}", flush=True)
    with (job_dir / "result.json").open("w") as so, (job_dir / "generate.log").open("w") as se:
        try:
            rc = subprocess.run(cmd, input=prompt, text=True, stdout=so, stderr=se,
                                timeout=900, check=False).returncode
        except subprocess.TimeoutExpired:
            print(f"TIMEOUT {job['name']} (do not auto-retry; check ima2 ps)", flush=True)
            continue
    try:
        data = json.loads((job_dir / "result.json").read_text())
    except json.JSONDecodeError:
        data = {}
    paths = [Path(i["path"]).resolve() for i in data.get("images", []) if i.get("path")]
    ok = rc == 0 and data.get("ok") and out.resolve() in paths and out.is_file() and out.stat().st_size > 0
    if not ok:
        print(f"FAIL {job['name']} rc={rc} log={job_dir}/generate.log", flush=True)
        continue
    shutil.copy2(out, final)
    print(f"ok {job['name']} {final} {out.stat().st_size} bytes", flush=True)
