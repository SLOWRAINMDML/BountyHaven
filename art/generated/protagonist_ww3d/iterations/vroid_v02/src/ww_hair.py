# VRoid-style hair (exec'd from ww_build.py when face_spec "hair_mode" == "vroid").
# Each group = a guide (root arc on the scalp + flow direction/length/lift/gravity) that spawns N strands spread across
# the arc; strands are tapered ribbons with a crescent cross-section, optional twist and tip curl, plus per-strand
# randomness (VRoid procedural hair: count, cross-section, taper, twist, curl, random). A stray-hair group adds the
# thin flyaways that give the illustration its messy silhouette. No highlight bands (user rule).

rnd = random.Random(21)


def strand(name, theta, phi, length, width, lift0=1.0, lift1=1.2, grav=0.8, flick=0.015, curl=0.0, fwd=None,
           tip_curl=0.0, twist=0.0, bend=0.35, thick=0.28, taper=0.85, steps=12):
    r, d = scalp(theta, phi, lift0)
    f = (r - CROWN)
    f = (f - d * f.dot(d)).normalized() if fwd is None else Vector(fwd).normalized()
    pts = [r]
    p = r
    ds = length / steps
    for i in range(1, steps + 1):
        t = i / steps
        f = (f + Vector((0, 0, -grav * ds * 12))).normalized()
        if curl:
            f = (Matrix.Rotation(curl * ds * 10, 3, d) @ f).normalized()
        if tip_curl and t > 0.65:                     # curl the last third outward/up (VRoid "curl" near the tip)
            out_ = (p - HAIR_C)
            out_.z = 0
            ax = f.cross(out_.normalized() if out_.length > 1e-5 else Vector((0, 0, 1)))
            if ax.length > 1e-5:
                f = (Matrix.Rotation(tip_curl * ds * 14, 3, ax.normalized()) @ f).normalized()
        p = p + f * ds
        p = ell_push(p, lift0 + (lift1 - lift0) * min(1.0, t * 1.2))
        pts.append(p.copy())
    out = (pts[-1] - HAIR_C)
    out.z *= 0.3
    pts[-1] = pts[-1] + out.normalized() * flick
    pts[-2] = pts[-2] + out.normalized() * flick * 0.35
    n_ = len(pts) - 1
    rx = [width * (1 - k / n_) ** taper + 0.0006 for k in range(n_ + 1)]
    ry = [width * thick * (1 - k / n_) ** 0.9 + 0.0005 for k in range(n_ + 1)]
    tw = [twist * (k / n_) for k in range(n_ + 1)] if twist else None
    ob = tube(name, pts, rx, ry, n=10, up=d, twist=tw, caps=(True, False), bend=[bend * w for w in rx])
    finish(ob, HAIR, outline=0.0022)
    hair_objs.append(ob)
    return ob


def group(gname, count, th0, th1, ph0, ph1, length, width, rand=0.25, **kw):
    """Guide = root arc from (th0, ph0) to (th1, ph1); strands spread along it with per-strand randomness."""
    global hi
    for k in range(count):
        u = (k + 0.5) / count
        th = th0 + (th1 - th0) * u + rnd.uniform(-0.5, 0.5) * rand * abs(th1 - th0) / max(count, 1)
        ph = ph0 + (ph1 - ph0) * u + rnd.uniform(-0.06, 0.06) * rand * 4
        ln = length * (1 + rnd.uniform(-rand, rand) * 0.6)
        wd = width * (1 + rnd.uniform(-rand, rand) * 0.5)
        k2 = dict(kw)
        for key in ("curl", "tip_curl", "twist"):
            if key in k2:
                k2[key] = k2[key] * (1 + rnd.uniform(-rand, rand) * 1.5)
        if "fwd_fn" in k2:
            k2["fwd"] = k2.pop("fwd_fn")(th)
        strand(f"Hair{gname}{hi}", th, ph, ln, wd, **k2)
        hi += 1


# crown: rounded mass flowing away from the whorl, two interleaved layers
group("Crown", 22, -math.pi, math.pi, 0.28, 0.3, 0.15, 0.058, rand=0.35, lift0=0.93, lift1=1.06, grav=1.05, flick=0.012,
      curl=0.35, tip_curl=0.6, bend=0.45)
group("Crown2", 18, -math.pi + 0.17, math.pi + 0.17, 0.5, 0.52, 0.13, 0.052, rand=0.35, lift0=0.98, lift1=1.1,
      grav=1.1, flick=0.012, curl=-0.3, tip_curl=0.7, bend=0.45)
# fringe: three guide groups (right, centre, left) falling over the forehead to the brows; centre lock to the eye line
fr = lambda th: (math.sin(th) * 0.35, -0.3, -1.0)
group("FringeR", 4, -1.05, -0.55, 0.62, 0.6, 0.068, 0.04, rand=0.3, lift0=1.0, lift1=1.07, grav=1.4, flick=0.008,
      curl=0.4, tip_curl=0.5, fwd_fn=fr)
group("FringeC", 4, -0.4, 0.25, 0.6, 0.6, 0.078, 0.036, rand=0.3, lift0=1.0, lift1=1.07, grav=1.4, flick=0.008,
      curl=0.1, tip_curl=0.4, fwd_fn=fr)
group("FringeL", 4, 0.4, 1.05, 0.6, 0.62, 0.068, 0.04, rand=0.3, lift0=1.0, lift1=1.07, grav=1.4, flick=0.008,
      curl=-0.4, tip_curl=0.5, fwd_fn=fr)
# sides: over the temples and half the ear, flicking outward
for sx, S in ((-1, "R"), (1, "L")):
    group("Side" + S, 7, sx * 1.0, sx * 2.1, 0.62, 0.85, 0.12, 0.048, rand=0.3, lift0=1.0, lift1=1.14, grav=1.4,
          flick=0.012, curl=sx * 0.4, tip_curl=0.8)
# back: upper layer and longer nape layer with outward flicks
group("Back", 14, math.pi - 1.35, math.pi + 1.35, 0.62, 0.62, 0.13, 0.054, rand=0.3, lift0=1.01, lift1=1.12, grav=1.1,
      flick=0.012, curl=0.2, tip_curl=0.7)
group("Nape", 12, math.pi - 1.05, math.pi + 1.05, 0.9, 0.9, 0.14, 0.05, rand=0.3, lift0=1.0, lift1=1.08, grav=1.1,
      flick=0.008, curl=-0.2, tip_curl=0.9)
# crown tufts (the sheet's messy top): short strands near the whorl that stand up before curling over
group("Tuft", 6, -2.4, 2.4, 0.14, 0.2, 0.016, 0.04, rand=0.3, lift0=1.0, lift1=1.04, grav=0.6, flick=0.012,
      curl=0.8, tip_curl=1.2, bend=0.35, fwd_fn=lambda th: (math.sin(th) * 0.5, -math.cos(th) * 0.5, 1.0))
# stray hair (VRoid "stray hair" group): thin flyaways at the silhouette that curl outward and up
for k in range(10):
    th = rnd.uniform(-math.pi, math.pi)
    strand(f"HairStray{hi}", th, rnd.uniform(0.3, 0.8), rnd.uniform(0.05, 0.08), rnd.uniform(0.012, 0.018),
           lift0=1.02, lift1=rnd.uniform(1.15, 1.25), grav=rnd.uniform(0.6, 1.0), flick=0.012,
           curl=rnd.uniform(-1.2, 1.2), tip_curl=rnd.uniform(1.5, 2.5), bend=0.2, thick=0.35)
    hi += 1


# silhouette envelope (VRoid guides keep the hairstyle inside a designed outline): soft-clamp strand vertices that
# reach past the measured half hair width, compressing the overshoot instead of cutting it
HW = half_hair * 0.97
for ob in hair_objs:
    for v in ob.data.vertices:
        ax = abs(v.co.x)
        if ax > HW * 0.9:
            k = HW * 0.9 + (ax - HW * 0.9) * 0.35
            v.co.x = math.copysign(k, v.co.x)
