#!/usr/bin/env python3
# gallery.py builds the screenshot gallery for one qakit QA plan.
#
# The QA plan is the single source. The script reads each `### TC-…` case, the
# indented `- [ ]` checkpoints under its steps (the judge questions), and the
# `screenshots:` lines that name its captures. It then groups the images in the
# run's screenshot folder by case. Images that no case names go to
# "Other captures". Names a case lists with no file are reported as missing.
#
# The capture commit comes from the plan's Environment line (or its header
# stamp). When HEAD in the plan's repo has moved past it, the page carries a
# stale warning, computed when the page is built.
#
# Needs: Python 3. Pillow is optional: with it, images are converted to WebP;
# without it, index.html embeds the original files and inline.html references
# them by path.
#
# Usage:
#   gallery.py <plan.md>                 # -> <shots>/index.html, one self-contained file
#   gallery.py <plan.md> --inline        # -> <shots>/inline.html + <shots>/web/, for a host's inline HTML renderer
#   gallery.py <plan.md> --dry-run       # -> print the case-to-screenshot map, write nothing
#   options: --shots DIR (default ~/qakit/<plan file name without .md>), --out DIR (default: the shots dir)
import argparse
import base64
import datetime
import html
import io
import os
import re
import struct
import subprocess
import sys

try:
    from PIL import Image
except ImportError:
    Image = None

IMAGE_EXT = (".png", ".jpg", ".jpeg", ".webp")
MIME = {".png": "image/png", ".jpg": "image/jpeg", ".jpeg": "image/jpeg", ".webp": "image/webp"}
INLINE_LIMIT = 512 * 1024  # T3 Code's html_render cap
HEX = re.compile(r"`([0-9a-f]{7,40})`")


# ---- parse the plan ---------------------------------------------------------

def parse_plan(path):
    lines, fenced = [], False
    with open(path, encoding="utf-8") as f:
        for line in f.read().splitlines():
            if line.lstrip().startswith("```"):
                fenced = not fenced
                continue
            if not fenced:
                lines.append(line)

    plan = {"title": "", "sha": "", "cases": []}
    section, case, goal_next = "", None, False
    for line in lines:
        if line.startswith("# ") and not plan["title"]:
            plan["title"] = re.sub(r"^QA Plan:\s*", "", line[2:].strip())
        elif line.startswith("_Generated") and not plan["sha"]:
            m = HEX.search(line)
            plan["sha"] = m.group(1) if m else ""
        if re.match(r"^#{1,3} ", line):
            case = None
            section = line.lstrip("#").strip().lower()
            m = re.match(r"^###\s+(TC-[\w.]+):\s*(.+?)\s*$", line)
            if m:
                case = new_case(m.group(1), m.group(2))
                plan["cases"].append(case)
            continue
        # The Environment line about screenshots names the capture commit and wins over the stamp.
        if section == "environment" and "screenshot" in line.lower():
            m = HEX.search(line)
            if m:
                plan["sha"] = m.group(1)
        if case is None:
            continue
        if line.startswith("**Goal.**"):
            case["checks"] += [c for c in re.findall(r"\bC\d+\b", line) if c not in case["checks"]]
        m = re.match(r"^\s*- screenshots?:\s*(.*)$", line)
        if m:
            case["names"] += [n for n in screenshot_tokens(m.group(1)) if n not in case["names"]]
            continue
        m = re.match(r"^\s+- \[[ xX]\]\s+(.*)$", line)
        if m:
            case["questions"].append(m.group(1).strip())
    return plan


def new_case(case_id, rest):
    parts = re.split(r"\s+·\s+", rest)
    prio = ""
    if len(parts) > 1 and re.search(r"critical|normal|low", parts[-1], re.I):
        prio = re.sub(r"[^A-Za-z]", "", parts.pop())
    title = " · ".join(parts)
    checks = re.findall(r"\bC\d+\b", title)
    return {"id": case_id, "title": title, "prio": prio, "checks": checks, "questions": [], "names": []}


def screenshot_tokens(text):
    # Names sit in backticks. An older plan wrote absolute paths and `…-light-1440.png`
    # short forms; keep the basename without its extension, and keep a leading … so
    # resolve() can expand it against the folder.
    raw = re.findall(r"`([^`]+)`", text) or re.split(r"\s*[·,]\s*", text)
    out = []
    for tok in raw:
        tok = os.path.basename(tok.strip())
        for ext in IMAGE_EXT:
            if tok.lower().endswith(ext):
                tok = tok[: -len(ext)]
        if tok:
            out.append(tok)
    return out


def resolve(cases, files):
    # Expand short forms (`…-light-1440`) to the file sharing the longest prefix with the previous name.
    for case in cases:
        resolved, prev = [], ""
        for name in case["names"]:
            if name.startswith(("…", "...")):
                tail = name.lstrip("….")
                hits = [f for f in files if f.endswith(tail)]
                if hits:
                    name = max(hits, key=lambda f: len(os.path.commonprefix([f, prev])))
            if name not in resolved:
                resolved.append(name)
            prev = name
        case["names"] = resolved


# ---- git --------------------------------------------------------------------

def git(cwd, *args):
    try:
        r = subprocess.run(["git", "-C", cwd, *args], capture_output=True, text=True, timeout=10)
    except (OSError, subprocess.SubprocessError):
        return None
    return r.stdout.strip() if r.returncode == 0 else None


def staleness(plan_path, sha):
    # Returns (head, commits past the capture or None, note).
    if not sha:
        return None, None, "the plan names no capture commit"
    cwd = os.path.dirname(os.path.abspath(plan_path))
    head = git(cwd, "rev-parse", "HEAD")
    if head is None:
        return None, None, "no git repo at the plan, stale check skipped"
    if head.startswith(sha):
        return head, 0, ""
    count = git(cwd, "rev-list", "--count", f"{sha}..HEAD")
    return head, int(count) if count and count.isdigit() else None, ""


# ---- images -----------------------------------------------------------------

def label(name):
    m = re.search(r"(?:^|-)(dark|light)(?=-|$)", name)
    theme = m.group(1) if m else ""
    m = re.search(r"-(\d{3,4})$", name)
    width = m.group(1) if m else ""
    text = re.sub(r"-(\d{3,4})$", "", name)
    text = re.sub(r"(?:^|-)(dark|light)(?=-|$)", "", text)
    return text or name, theme, width


def png_size(path):
    with open(path, "rb") as f:
        head = f.read(24)
    if head[:8] == b"\x89PNG\r\n\x1a\n":
        return struct.unpack(">II", head[16:24])
    return None


def encode(path, inline, webdir):
    # Returns ((w, h) or None, src).
    name, ext = os.path.splitext(os.path.basename(path))
    if Image is None:
        if inline:
            return png_size(path), path
        with open(path, "rb") as f:
            data = base64.b64encode(f.read()).decode()
        return png_size(path), f"data:{MIME[ext.lower()]};base64,{data}"
    im = Image.open(path).convert("RGB")
    if inline:
        if im.width > 1000:
            im = im.resize((1000, round(im.height * 1000 / im.width)), Image.LANCZOS)
        out = os.path.join(webdir, name + ".webp")
        im.save(out, "WEBP", quality=72, method=6)
        return im.size, out
    buf = io.BytesIO()
    im.save(buf, "WEBP", quality=82, method=6)
    return im.size, "data:image/webp;base64," + base64.b64encode(buf.getvalue()).decode()


# ---- page -------------------------------------------------------------------

def md_inline(text):
    return re.sub(r"`([^`]+)`", r"<code>\1</code>", html.escape(text))


STYLE_FILE = """
:root{color-scheme:dark;--bg:#0e1013;--panel:#171a1f;--line:#2a2f37;--fg:#e6e8eb;--mute:#9aa3ad;--acc:#c7f25c;--bad:#ff8a80;--warn:#ffd166}
*{box-sizing:border-box}body{margin:0;font:14px/1.5 system-ui,sans-serif;background:var(--bg);color:var(--fg)}code{font-size:.92em;background:var(--panel);border:1px solid var(--line);border-radius:4px;padding:0 4px}
.top{position:sticky;top:0;z-index:5;background:rgba(14,16,19,.92);backdrop-filter:blur(6px);border-bottom:1px solid var(--line);padding:10px 20px;display:flex;gap:16px;align-items:center;flex-wrap:wrap}
.top h1{font-size:15px;margin:0}.top .meta{color:var(--mute);font-size:12px}.stale{width:100%;color:var(--warn);font-size:12px}
.top nav{display:flex;gap:6px;flex-wrap:wrap}.top nav a{color:var(--fg);text-decoration:none;border:1px solid var(--line);border-radius:999px;padding:2px 10px;font-size:12px}.top nav a span{color:var(--mute)}
.filters{margin-left:auto;display:flex;gap:4px}.filters button{background:var(--panel);color:var(--fg);border:1px solid var(--line);border-radius:6px;padding:3px 10px;cursor:pointer}.filters button[aria-pressed=true]{border-color:var(--acc);color:var(--acc)}
main{padding:20px;max-width:1600px;margin:auto}section{margin:0 0 36px}section header{display:flex;gap:10px;align-items:center;flex-wrap:wrap}h2{font-size:17px;margin:0}
.prio,.checks,.tag{font-size:11px;border:1px solid var(--line);border-radius:999px;padding:1px 8px;color:var(--mute)}.prio.critical{color:var(--bad);border-color:#5c2b2b}.missing{color:var(--bad);font-size:12px;margin:8px 0}.foot{color:var(--mute);font-size:12px}
.q{background:var(--panel);border:1px solid var(--line);border-radius:10px;padding:10px 14px;margin:12px 0}.q h3{margin:0 0 6px;font-size:12px;text-transform:uppercase;letter-spacing:.06em;color:var(--mute)}.q label{display:block;padding:3px 0;cursor:pointer}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(420px,1fr));gap:14px}
figure{margin:0;background:var(--panel);border:1px solid var(--line);border-radius:10px;overflow:hidden;cursor:zoom-in}figure img{display:block;width:100%;height:auto;max-height:420px;object-fit:cover;object-position:top}
figcaption{display:flex;gap:6px;align-items:center;padding:8px 10px;font-size:12px}figcaption b{font-weight:500;flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.tag.light{color:var(--warn)}
#lb{position:fixed;inset:0;background:rgba(0,0,0,.92);display:none;z-index:10;flex-direction:column}#lb.on{display:flex}#lb .bar{display:flex;gap:12px;align-items:center;padding:8px 16px;color:var(--mute);font-size:13px}#lb .bar b{color:var(--fg);flex:1}
#lb .view{flex:1;overflow:auto;display:flex;justify-content:center;align-items:flex-start;padding:0 16px 16px}#lb img{max-width:100%;height:auto;cursor:zoom-in}#lb img.full{max-width:none;cursor:zoom-out}#lb button{background:#222;color:#eee;border:1px solid #444;border-radius:6px;padding:3px 10px;cursor:pointer}
"""

# The inline variant takes the host's theme variables, sets no page background, and uses no vh units.
STYLE_INLINE = """
*{box-sizing:border-box}body{margin:0}code{font-size:.92em;background:var(--muted);border-radius:4px;padding:0 4px}
.top{display:flex;gap:10px;align-items:center;flex-wrap:wrap;padding:0 0 12px}
.top h1{display:none}.top .meta{color:var(--muted-foreground);font-size:12px;width:100%}.stale{width:100%;color:var(--warning);font-size:12px}
.top nav{display:flex;gap:6px;flex-wrap:wrap}.top nav a{color:var(--foreground);text-decoration:none;border:1px solid var(--border);border-radius:999px;padding:1px 9px;font-size:12px}.top nav a span{display:none}
.filters{display:flex;gap:4px;margin-left:auto}.filters button{background:var(--secondary);color:var(--secondary-foreground);border:1px solid var(--border);border-radius:6px;padding:2px 9px;font:inherit;font-size:12px;cursor:pointer}.filters button[aria-pressed=true]{border-color:var(--ring);color:var(--primary)}
main{padding:0}section{margin:0 0 26px}section header{display:flex;gap:8px;align-items:center;flex-wrap:wrap}h2{font-size:15px;margin:0}
.prio,.checks,.tag{font-size:11px;border:1px solid var(--border);border-radius:999px;padding:0 7px;color:var(--muted-foreground)}.prio.critical{color:var(--destructive)}.missing{color:var(--destructive);font-size:12px;margin:6px 0}.foot{color:var(--muted-foreground);font-size:12px}
.q{background:var(--card);border:1px solid var(--border);border-radius:var(--radius);padding:16px;margin:10px 0}.q h3{margin:0 0 4px;font-size:11px;text-transform:uppercase;letter-spacing:.06em;color:var(--muted-foreground)}.q label{display:block;padding:2px 0;cursor:pointer;font-size:13px}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(300px,1fr));gap:10px}
figure{margin:0;background:var(--card);border:1px solid var(--border);border-radius:var(--radius);overflow:hidden;cursor:zoom-in}figure img{display:block;width:100%;height:190px;object-fit:cover;object-position:top}
figcaption{display:flex;gap:6px;align-items:center;padding:6px 8px;font-size:11px}figcaption b{font-weight:500;flex:1;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.tag.light{color:var(--warning)}
#lb{position:fixed;inset:0;background:rgba(0,0,0,.94);display:none;z-index:10;flex-direction:column}#lb.on{display:flex}#lb .bar{display:flex;gap:8px;align-items:center;padding:6px 10px;color:#aaa;font-size:12px}#lb .bar b{color:#eee;flex:1;font-weight:500;overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
#lb .view{flex:1;overflow:auto;padding:0 10px 10px}#lb img{width:100%;height:auto}#lb button{background:#222;color:#eee;border:1px solid #444;border-radius:6px;padding:2px 8px;font-size:12px;cursor:pointer}
"""

SCRIPT = """
const figs=[...document.querySelectorAll('figure')];let cur=-1;const lb=document.getElementById('lb'),li=document.getElementById('lbi');
const vis=()=>figs.filter(f=>f.style.display!=='none');
function open(f){const v=vis();cur=v.indexOf(f);const i=f.querySelector('img');li.src=i.src;li.classList.remove('full');document.getElementById('lbt').textContent=i.alt;document.getElementById('lbn').textContent=(cur+1)+' / '+v.length;lb.classList.add('on')}
function step(d){const v=vis();if(!v.length)return;open(v[(cur+d+v.length)%v.length])}
figs.forEach(f=>f.onclick=()=>open(f));li.onclick=()=>li.classList.toggle('full');
document.getElementById('prev').onclick=()=>step(-1);document.getElementById('next').onclick=()=>step(1);document.getElementById('close').onclick=()=>lb.classList.remove('on');
addEventListener('keydown',e=>{if(!lb.classList.contains('on'))return;if(e.key==='Escape')lb.classList.remove('on');if(e.key==='ArrowRight')step(1);if(e.key==='ArrowLeft')step(-1)});
document.querySelectorAll('.filters button').forEach(b=>b.onclick=()=>{document.querySelectorAll('.filters button').forEach(x=>x.setAttribute('aria-pressed',x===b));const f=b.dataset.f;figs.forEach(g=>g.style.display=(f==='all'||g.dataset.theme===f)?'':'none')});
const KEY=document.body.dataset.key;let store={};try{store=JSON.parse(localStorage.getItem(KEY)||'{}')}catch(e){}
document.querySelectorAll('.q input').forEach(c=>{c.checked=!!store[c.dataset.k];c.onchange=()=>{store[c.dataset.k]=c.checked;try{localStorage.setItem(KEY,JSON.stringify(store))}catch(e){}}});
"""


def build_page(plan, stem, groups, shots, inline, webdir, stale_line, unshot):
    serial = stem.split("-", 1)[0] if stem[:4].isdigit() else ""
    title = f"QA {serial} · {plan['title']}".strip(" ·")
    cards, nav, idx = [], [], 0
    for g in groups:
        nav.append(f'<a href="#{html.escape(g["id"])}">{html.escape(g["id"])} <span>{html.escape(g["title"])}</span></a>')
        qs = "".join(
            f'<label><input type="checkbox" data-k="{html.escape(g["id"])}-{i}"> {md_inline(q)}</label>'
            for i, q in enumerate(g["questions"])
        )
        figs = []
        for name in g["names"]:
            if name not in shots:
                continue
            size, src = encode(shots[name], inline, webdir)
            text, theme, width = label(name)
            dims = f' width="{size[0]}" height="{size[1]}"' if size else ""
            figs.append(
                f'<figure data-theme="{theme}"><img loading="lazy" src="{html.escape(src)}"{dims} alt="{html.escape(name)}">'
                f'<figcaption><b>{html.escape(text)}</b><span class="tag {theme}">{theme or "-"}</span>'
                f'<span class="tag">{width or "-"}</span></figcaption></figure>'
            )
            idx += 1
        missing = [n for n in g["names"] if n not in shots]
        miss = f'<p class="missing">No file for: {html.escape(", ".join(missing))}</p>' if missing else ""
        prio = f'<span class="prio {g["prio"].lower()}">{html.escape(g["prio"])}</span>' if g["prio"] else ""
        checks = f'<span class="checks">{html.escape(" · ".join(g["checks"]))}</span>' if g["checks"] else ""
        judge = f'<div class="q"><h3>Judge</h3>{qs}</div>' if qs else ""
        head = f'{html.escape(g["id"])}: {html.escape(g["title"])}' if g["id"] != "Other" else html.escape(g["title"])
        cards.append(
            f'<section id="{html.escape(g["id"])}"><header><h2>{head}</h2>{prio}{checks}</header>'
            f'{judge}{miss}<div class="grid">{"".join(figs)}</div></section>'
        )
    foot = f'<p class="foot">Cases with no screenshots: {html.escape(", ".join(unshot))}</p>' if unshot else ""
    captured = f"captured at {html.escape(plan['sha'])}" if plan["sha"] else "capture commit unknown"
    built = datetime.date.today().isoformat()
    stale = f'<span class="stale">{html.escape(stale_line)}</span>' if stale_line else ""
    return f"""<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>{html.escape(title)} · screenshots</title><style>{STYLE_INLINE if inline else STYLE_FILE}</style></head><body data-key="qakit:{html.escape(stem)}">
<div class="top"><h1>{html.escape(title)}</h1><span class="meta">{captured} · {idx} screenshots · built {built} · local to this run, not committed</span>{stale}<nav>{"".join(nav)}</nav>
<div class="filters" role="group" aria-label="Theme"><button data-f="all" aria-pressed="true">All</button><button data-f="dark" aria-pressed="false">Dark</button><button data-f="light" aria-pressed="false">Light</button></div></div>
<main>{"".join(cards)}{foot}</main>
<div id="lb" role="dialog" aria-modal="true"><div class="bar"><b id="lbt"></b><span id="lbn"></span><button id="prev">← Prev</button><button id="next">Next →</button><button id="close">Close (Esc)</button></div><div class="view"><img id="lbi" alt=""></div></div>
<script>{SCRIPT}</script></body></html>""", idx


# ---- main -------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description="Build the screenshot gallery for a qakit QA plan.")
    ap.add_argument("plan", help="the QA plan, docs/qa/NNNN-qa-<slug>-YYYY-MM-DD.md")
    ap.add_argument("--shots", help="screenshot folder (default ~/qakit/<plan file name without .md>)")
    ap.add_argument("--out", help="output folder (default: the screenshot folder)")
    ap.add_argument("--inline", action="store_true", help="write inline.html for a host's inline HTML renderer")
    ap.add_argument("--dry-run", action="store_true", help="print the case-to-screenshot map and write nothing")
    a = ap.parse_args()

    if not os.path.isfile(a.plan):
        sys.exit(f"gallery: no plan at {a.plan}")
    stem = os.path.splitext(os.path.basename(a.plan))[0]
    shots_dir = os.path.abspath(os.path.expanduser(a.shots or os.path.join("~", "qakit", stem)))
    out_dir = os.path.abspath(os.path.expanduser(a.out or shots_dir))
    if not os.path.isdir(shots_dir):
        sys.exit(f"gallery: no screenshot folder at {shots_dir}")

    shots = {}
    for f in sorted(os.listdir(shots_dir)):
        base, ext = os.path.splitext(f)
        if ext.lower() in IMAGE_EXT and os.path.isfile(os.path.join(shots_dir, f)):
            shots.setdefault(base, os.path.join(shots_dir, f))

    plan = parse_plan(a.plan)
    resolve(plan["cases"], list(shots))
    groups = [c for c in plan["cases"] if c["names"]]
    unshot = [c["id"] for c in plan["cases"] if not c["names"]]
    named = {n for c in groups for n in c["names"]}
    missing = [(c["id"], n) for c in groups for n in c["names"] if n not in shots]
    other = [n for n in shots if n not in named]
    if other:
        groups.append({"id": "Other", "title": "Other captures", "prio": "", "checks": [], "questions": [], "names": other})

    head, past, note = staleness(a.plan, plan["sha"])
    stale_line = ""
    if past:
        stale_line = f"Stale: HEAD {head[:7]} is {past} commit{'s' if past != 1 else ''} past {plan['sha']}. Re-run qakit to capture the current code."
    elif past is None and head and plan["sha"]:
        stale_line = f"Stale: HEAD {head[:7]} is not {plan['sha']}. Re-run qakit to capture the current code."

    target = os.path.join(out_dir, "inline.html" if a.inline else "index.html")
    if a.dry_run:
        print(f"plan:      {a.plan}")
        print(f"shots:     {shots_dir} ({len(shots)} images)")
        print(f"captured:  {plan['sha'] or 'unknown'}" + (f" ({note})" if note else ""))
        print(f"stale:     {stale_line or 'no'}")
        for g in groups:
            meta = " · ".join(x for x in (g["prio"], " ".join(g["checks"])) if x)
            print(f"\n{g['id']}  {g['title']}" + (f"  [{meta}]" if meta else ""))
            for q in g["questions"]:
                print(f"  judge  {q}")
            for n in g["names"]:
                print(f"  {'shot ' if n in shots else 'MISSING'}  {n}")
        print(f"\nmissing:   {len(missing)}" + "".join(f"\n  {cid}  {n}" for cid, n in missing))
        print(f"other:     {len(other)}")
        print(f"no shots:  {', '.join(unshot) or 'none'}")
        print(f"pillow:    {'yes, WebP' if Image else 'no, original files'}")
        print(f"would write {target}")
        return

    webdir = os.path.join(out_dir, "web")
    os.makedirs(webdir if a.inline and Image else out_dir, exist_ok=True)
    page, count = build_page(plan, stem, groups, shots, a.inline, webdir, stale_line, unshot)
    with open(target, "w", encoding="utf-8") as f:
        f.write(page)
    size = os.path.getsize(target)
    print(f"wrote {target}: {count} images, {size / 1e6:.2f} MB, {'WebP' if Image else 'original files, Pillow not found'}")
    if missing:
        print(f"missing: {len(missing)} names with no file: " + ", ".join(n for _, n in missing))
    if stale_line:
        print(stale_line)
    if a.inline and size > INLINE_LIMIT:
        print(f"warning: {size} bytes is over the {INLINE_LIMIT}-byte inline render limit")


if __name__ == "__main__":
    main()
