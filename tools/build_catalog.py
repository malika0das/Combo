#!/usr/bin/env python3
"""Build assets/data/catalog.json from the plain-text source lists in tools/raw/.

Source format
-------------
Combo / glass / CC board / case files: one group per line, comma separated
models. Trailing descriptive fragments ("Punch Hole LCD Screen", "Notch
Combo", "Side Flex", ...) are detected and moved into the group note instead
of being treated as phone models.

Battery files: `Battery code|Model, Model, Model` per line.

`models_current.txt`: one verified recent phone name per line. These names are
kept in a separate directory so a newly released phone can be searchable before
workshop-tested part compatibility is available. Lines beginning with `#` are
source notes and are ignored.

Usage: python3 tools/build_catalog.py
"""
from __future__ import annotations

import json
import re
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "tools" / "raw"
OUT = ROOT / "assets" / "data" / "catalog.json"

# Words that mark a fragment as a descriptive note rather than a phone model.
NOTE_WORDS = {
    "punch", "hole", "notch", "flex", "lcd", "combo", "display", "screen",
    "folder", "curved", "universal", "compatible", "glass", "camera", "side",
    "single", "double", "dual", "version", "update", "protector", "board",
    "sub", "cc", "best", "old", "new", "uv", "cu", "try", "ok", "all",
}
# A fragment is a note when every alphabetic word is a note word.
BRAND_HINTS = (
    "samsung", "xiaomi", "redmi", "poco", "mi ", "vivo", "iqoo", "oppo",
    "realme", "oneplus", "iphone", "motorola", "moto", "infinix", "tecno",
    "itel", "lava", "benco", "huawei", "honor", "zte", "nothing", "google",
    "pixel", "micromax", "tcl", "cubot", "oukitel", "sharp", "blackview",
    "m horse", "m-horse", "ai plus", "sm-", "narzo",
)


def is_note_fragment(text: str) -> bool:
    low = text.lower()
    if any(h in low for h in BRAND_HINTS):
        return False
    words = re.findall(r"[a-z]+", low)
    if not words:
        return False
    return all(w in NOTE_WORDS for w in words)


# The source pages spell the same phone both ways ("Xiaomi Redmi 9A" and
# "Redmi 9A"). Dropping the redundant parent-brand prefix makes one model name
# resolve to every part that fits it.
REDUNDANT_PREFIXES = [
    ("xiaomi", "redmi"), ("xiaomi", "poco"), ("xiaomi", "mi"),
    ("vivo", "iqoo"), ("huawei", "honor"), ("oppo", "realme"),
    ("oppo", "oneplus"), ("realme", "narzo"), ("samsung", "galaxy"),
    ("motorola", "moto"), ("lava", "benco"),
]


def canonical_model(name: str) -> str:
    """Strip a redundant parent-brand prefix: 'Xiaomi Redmi 9A' -> 'Redmi 9A'."""
    words = name.split()
    changed = True
    while changed and len(words) > 2:
        changed = False
        for parent, child in REDUNDANT_PREFIXES:
            if words[0].lower() == parent and words[1].lower().strip("(,") == child:
                words = words[1:]
                changed = True
                break

    # Samsung's retail family is Galaxy. Older workshop sheets often wrote
    # "Samsung A55" while newer sheets wrote "Samsung Galaxy A55"; resolving
    # both to one display name prevents the model directory from splitting the
    # same phone into two searchable entries.
    if words and words[0].lower() == "samsung" and len(words) > 1:
        if words[1].lower() == "galaxy":
            words = words[1:]
        else:
            words = ["Galaxy", *words[1:]]
    return " ".join(words)


def split_line(line: str) -> tuple[list[str], str]:
    """Return (models, note) for one raw line."""
    parts = [p.strip() for p in line.split(",")]
    parts = [p for p in parts if p]
    models: list[str] = []
    notes: list[str] = []
    for part in parts:
        if is_note_fragment(part):
            notes.append(part)
        else:
            models.append(canonical_model(part))
    # De-duplicate models, preserving order and ignoring case.
    seen: set[str] = set()
    unique: list[str] = []
    for m in models:
        key = m.lower()
        if key not in seen:
            seen.add(key)
            unique.append(m)
    return unique, ", ".join(notes)


def read_lines(name: str) -> list[str]:
    path = RAW / name
    if not path.exists():
        return []
    out = []
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if (not line or line.startswith("#") or
                line.lower().startswith("coming soon")):
            continue
        out.append(line)
    return out


def read_model_directory() -> list[str]:
    """Read and normalize one de-duplicated name for every recent phone."""
    names: list[str] = []
    seen: set[str] = set()
    for line in read_lines("models_current.txt"):
        # Unlike part-list rows, directory rows are deliberately one model per
        # line. A comma here is almost certainly accidental source formatting;
        # retaining it would make an unusable model name, so split it safely.
        for raw in line.split(","):
            model = canonical_model(raw.strip())
            key = model.casefold()
            if model and key not in seen:
                seen.add(key)
                names.append(model)
    return names


def build_simple_brand(prefix: str, file_key: str, brand_id: str, brand_name: str,
                       quality: str) -> dict | None:
    """Groups from a comma-separated file (combo / glass / cc / case)."""
    lines = read_lines(f"{prefix}_{file_key}.txt")
    if not lines:
        return None
    groups = []
    for i, line in enumerate(lines, start=1):
        models, note = split_line(line)
        if not models:
            continue
        code = f"{prefix.upper()}-{brand_id.upper()}-{i:03d}"
        title = models[0] if len(models) == 1 else f"{models[0]} + {len(models) - 1} more"
        groups.append({
            "code": code,
            "title": title,
            "quality": quality,
            "models": models,
            "note": note,
        })
    return {"id": brand_id, "name": brand_name, "groups": groups}


def build_battery_brand(file_key: str, brand_id: str, brand_name: str) -> dict | None:
    """Groups from a `code|models` battery file."""
    lines = read_lines(f"battery_{file_key}.txt")
    if not lines:
        return None
    groups = []
    for i, line in enumerate(lines, start=1):
        if "|" not in line:
            continue
        code_text, model_text = line.split("|", 1)
        models, note = split_line(model_text)
        if not models:
            continue
        capacity = ""
        m = re.search(r"(\d{3,5})\s*mAh", code_text, re.IGNORECASE)
        if m:
            capacity = f"{m.group(1)} mAh"
        groups.append({
            "code": f"BAT-{brand_id.upper()}-{i:03d}",
            "title": code_text.strip(),
            "quality": capacity or "Battery",
            "models": models,
            "note": note,
        })
    return {"id": brand_id, "name": brand_name, "groups": groups}


COMBO_BRANDS = [
    ("xiaomi", "Xiaomi, Redmi, Poco, Mi"),
    ("vivo", "Vivo, iQOO"),
    ("samsung", "Samsung"),
    ("realme", "Realme, Oppo, OnePlus"),
    ("transsion", "Infinix, Tecno, Itel"),
    ("motorola", "Motorola"),
    ("huawei", "Huawei, Honor"),
    ("lava", "Lava, Benco, Micromax"),
    ("zte", "ZTE"),
    ("iphone", "iPhone"),
]

BATTERY_BRANDS = [
    ("xiaomi", "Xiaomi, Redmi, Poco"),
    ("vivo", "Vivo, iQOO"),
    ("samsung", "Samsung"),
    ("realme", "Realme, Oppo, OnePlus"),
    ("transsion", "Infinix, Tecno, Itel"),
    ("motorola", "Motorola"),
    ("huawei", "Huawei, Honor"),
]

CC_BRANDS = [
    ("vivo", "Vivo, iQOO"),
    ("xiaomi", "Xiaomi, Redmi, Poco"),
    ("realme", "Realme, Oppo, OnePlus"),
    ("samsung", "Samsung"),
]


def main() -> None:
    categories = []

    combo_brands = [b for b in (
        build_simple_brand("combo", key, key, name, "Display / Combo / Folder")
        for key, name in COMBO_BRANDS) if b]
    categories.append({
        "id": "combo",
        "name": "Folder / Display / Combo",
        "icon": "display",
        "brands": combo_brands,
    })

    battery_brands = [b for b in (
        build_battery_brand(key, key, name) for key, name in BATTERY_BRANDS) if b]
    categories.append({
        "id": "battery",
        "name": "Battery List",
        "icon": "battery",
        "brands": battery_brands,
    })

    glass_brands = []
    normal = build_simple_brand("glass", "normal", "normal", "Normal Tempered Glass",
                                "2.5D Full Glue Tempered Glass")
    curved = build_simple_brand("glass", "curved", "curved", "UV / Curved Glass",
                                "UV Curved Tempered Glass")
    glass_brands = [b for b in (normal, curved) if b]
    categories.append({
        "id": "tempered",
        "name": "Tempered / Screen Guard",
        "icon": "glass",
        "brands": glass_brands,
    })

    cc_brands = [b for b in (
        build_simple_brand("cc", key, key, name, "CC / Sub Board")
        for key, name in CC_BRANDS) if b]
    categories.append({
        "id": "ccboard",
        "name": "CC / Sub Board",
        "icon": "board",
        "brands": cc_brands,
    })

    case = build_simple_brand("case", "all", "all", "All Brands", "Back Cover / Case")
    if case:
        categories.append({
            "id": "case",
            "name": "Mobile Cover / Case",
            "icon": "case",
            "brands": [case],
        })

    # A model already covered by a compatibility group is searchable through
    # that group. Keep only directory-only names here so the generated schema
    # cannot introduce a second copy of an existing model under a different
    # section. Multiple groups may still reference one model legitimately.
    compatibility_keys = {
        re.sub(r"[^a-z0-9+]", "", canonical_model(model).lower())
        for category in categories
        for brand in category["brands"]
        for group in brand["groups"]
        for model in group["models"]
    }
    known_models = [
        model for model in read_model_directory()
        if re.sub(r"[^a-z0-9+]", "", canonical_model(model).lower())
        not in compatibility_keys
    ]

    catalog = {
        "version": 3,
        "updatedAt": date.today().isoformat(),
        "source": (
            "Compatibility lists are compiled by Makund Mobile from its own parts "
            "listings and workshop testing; the recent model directory is checked "
            "against official manufacturer product pages."
        ),
        "notice": (
            "Compatibility data is community contributed. Always physically verify "
            "connector, flex length and frame fit before fitting a part."
        ),
        # Directory names are intentionally separate from compatibility groups:
        # listing a newly released phone must never imply that a part has been
        # tested for it.
        "knownModels": known_models,
        "categories": categories,
    }

    OUT.parent.mkdir(parents=True, exist_ok=True)
    # Keep the bundled asset compact; the plain-text sources remain the
    # human-editable form and this saves a meaningful amount of APK size.
    OUT.write_text(
        json.dumps(catalog, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )

    total_groups = sum(len(b["groups"]) for c in categories for b in c["brands"])
    total_models = sum(len(g["models"]) for c in categories for b in c["brands"]
                       for g in b["groups"])
    print(f"categories : {len(categories)}")
    print(f"brands     : {sum(len(c['brands']) for c in categories)}")
    print(f"groups     : {total_groups}")
    print(f"models     : {total_models}")
    print(f"written    : {OUT.relative_to(ROOT)} "
          f"({OUT.stat().st_size / 1024:.0f} KB)")


if __name__ == "__main__":
    main()
