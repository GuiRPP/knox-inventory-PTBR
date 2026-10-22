"""Generate the textured model copies for the Knox inspect window's 3D view.

Bags and clothes have world models without a texture of their own: in the
world the game takes it from the item's clothing item, which the UI 3D scene
can't do. For each such model this writes model scripts with the same mesh and
an explicit texture, one per texture choice of the clothing item, in module
KnoxInspect:
    model <WorldModel>__<ClothingItem>_<index> { texture = ..., mesh = ..., scale = ... }
(media/scripts/knox_inspect_models.txt). Texture paths get the real case of
the files on disk. (Framing needs no data: the Java part measures each model.)

Run after a game update:
    py -I tools/gen_inspect_models.py "<ProjectZomboid folder>" "<mod 42 folder>"
"""

import os
import re
import sys
import xml.etree.ElementTree as ET

BLOCK_RE = re.compile(r"\b(item|model)\s+([A-Za-z0-9_\-\.]+)\s*\{", re.M)


def read(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()


def blocks(text, kind):
    """Yield (name, body) of `kind NAME { ... }` blocks (braces balanced)."""
    for m in BLOCK_RE.finditer(text):
        if m.group(1) != kind:
            continue
        depth, i = 1, m.end()
        while i < len(text) and depth:
            if text[i] == "{":
                depth += 1
            elif text[i] == "}":
                depth -= 1
            i += 1
        yield m.group(2), text[m.end():i - 1]


def props(body):
    """Simple `key = value,` lines of a block body (nested blocks ignored)."""
    out = {}
    depth = 0
    for line in body.splitlines():
        s = line.strip()
        depth += s.count("{") - s.count("}")
        if depth > 0 or "=" not in s:
            continue
        k, v = s.split("=", 1)
        out[k.strip().lower()] = v.strip().rstrip(",").strip()
    return out


def real_case(root, rel):
    """`rel` (a/b/c, no extension) with each part in the case it has on disk
    under `root`; None when not found."""
    cur, out = root, []
    parts = rel.replace("\\", "/").split("/")
    for i, part in enumerate(parts):
        last = i == len(parts) - 1
        try:
            entries = os.listdir(cur)
        except OSError:
            return None
        hit = None
        for e in entries:
            name = os.path.splitext(e)[0] if last else e
            if name.lower() == part.lower() and (not last or e.lower().endswith(".png")):
                hit = e
                break
        if not hit:
            return None
        out.append(os.path.splitext(hit)[0] if last else hit)
        cur = os.path.join(cur, hit)
    return "/".join(out)


def clothing_textures(clothing_dir, textures_dir, name):
    path = os.path.join(clothing_dir, name + ".xml")
    if not os.path.exists(path):
        low = name.lower() + ".xml"
        for f in os.listdir(clothing_dir):
            if f.lower() == low:
                path = os.path.join(clothing_dir, f)
                break
        else:
            return []
    try:
        root = ET.fromstring(read(path))
    except ET.ParseError:
        return []
    choices = [e.text.strip() for e in root.findall("textureChoices") if e.text and e.text.strip()]
    if not choices:
        choices = [e.text.strip() for e in root.findall("m_BaseTextures") if e.text and e.text.strip()]
    out = []
    for c in choices:
        c = c.replace("\\", "/")
        out.append(real_case(textures_dir, c) or c)
    return out


def num(v):
    return "%.5g" % v


def main(game_dir, mod_dir):
    scripts_dir = os.path.join(game_dir, "media", "scripts")
    clothing_dir = os.path.join(game_dir, "media", "clothing", "clothingItems")
    textures_dir = os.path.join(game_dir, "media", "textures")

    items, models = {}, {}
    for root, _, files in os.walk(scripts_dir):
        for f in files:
            if not f.endswith(".txt"):
                continue
            text = read(os.path.join(root, f))
            for name, body in blocks(text, "item"):
                items[name] = props(body)
            for name, body in blocks(text, "model"):
                models[name] = body

    # 1. textured copies of clothing-textured world models, per clothing item:
    #    several items share one world model with different textures (duffel
    #    bags: sports, military camo...), so a copy is named after both:
    #    <WorldModel>__<ClothingItem>_<index>
    out, made = [], 0
    done = set()
    for name, p in sorted(items.items()):
        world = p.get("worldstaticmodel")
        clothing = p.get("clothingitem")
        if not world or not clothing or (world, clothing) in done:
            continue
        body = models.get(world)
        if body is None or "texture" in props(body):
            continue
        textures = clothing_textures(clothing_dir, textures_dir, clothing)
        if not textures:
            continue
        done.add((world, clothing))
        for i, tex in enumerate(textures):
            out.append("    model %s__%s_%d\n    {\n        texture = %s,%s\n    }\n" % (
                world, clothing, i, tex, body.rstrip()))
            made += 1

    target = os.path.join(mod_dir, "media", "scripts", "knox_inspect_models.txt")
    os.makedirs(os.path.dirname(target), exist_ok=True)
    with open(target, "w", encoding="utf-8", newline="\n") as f:
        # PZ script files only know /* */ comments
        f.write("/* Generated by tools/gen_inspect_models.py - textured copies of clothing-textured\n")
        f.write("   world models for the Knox inspect window. Do not edit by hand. */\n\n")
        f.write("module KnoxInspect\n{\n    imports\n    {\n        Base\n    }\n\n")
        f.write("\n".join(out))
        f.write("}\n")
    print("textured copies:", made, "of", len(done), "world models ->", target)



if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
