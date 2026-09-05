#!/usr/bin/env python3
"""Inventory Kotlin copy without mistaking comments or interpolation expressions for text."""
import json
import sys
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HANGUL = re.compile(r"[가-힣]")
FORMAT = re.compile(r"%(?:\d+\$)?[-+0-9,]*(?:\.\d+)?(?:lld|llu|ld|lu|@|s|d|u|f)")


def normalize(value):
    return FORMAT.sub("{}", value).replace("%%", "%")


def scan(source):
    found = []

    def quoted(at):
        start = at
        triple = source.startswith('"""', at)
        terminator = '"""' if triple else '"'
        at += len(terminator)
        parts = []
        args = []
        while at < len(source):
            if source.startswith(terminator, at):
                value = "".join(parts)
                if HANGUL.search(value):
                    found.append((start, value, args))
                return at + len(terminator)
            if not triple and source[at] == "\\" and at + 1 < len(source):
                escaped = source[at + 1]
                parts.append({"n": "\n", "r": "\r", "t": "\t"}.get(escaped, escaped))
                at += 2
                continue
            if source.startswith("${", at):
                begin = at + 2
                at = expression(begin)
                args.append(source[begin:at - 1])
                parts.append(f"%{len(args)}$s")
                continue
            if source[at] == "$":
                match = re.match(r"\$([A-Za-z_][A-Za-z_0-9]*)", source[at:])
                if match:
                    args.append(match.group(1))
                    parts.append(f"%{len(args)}$s")
                    at += len(match.group(0))
                    continue
            parts.append(source[at])
            at += 1
        return at

    def expression(at):
        depth = 1
        while at < len(source) and depth:
            if source[at] == '"':
                at = quoted(at)
                continue
            if source[at] == "{":
                depth += 1
            elif source[at] == "}":
                depth -= 1
            at += 1
        return at

    at = 0
    while at < len(source):
        if source.startswith("//", at):
            end = source.find("\n", at)
            at = len(source) if end < 0 else end + 1
        elif source.startswith("/*", at):
            depth = 1
            at += 2
            while at < len(source) and depth:
                if source.startswith("/*", at):
                    depth += 1
                    at += 2
                elif source.startswith("*/", at):
                    depth -= 1
                    at += 2
                else:
                    at += 1
        elif source[at] == '"':
            at = quoted(at)
        else:
            at += 1
    return found


catalogue = json.loads((ROOT / "apps/android/game-application/src/main/resources/localization/game-copy.json").read_text())
known = {normalize(key) for key in catalogue["legacySourceIndex"]}
inventory = {}
for module in ["app", "game-application", "game-core", "platform"]:
    for path in (ROOT / "apps/android" / module / "src/main").rglob("*.kt"):
        # Matcher regexes and field-classification constants are implementation, not copy.
        if path.name in {"GameCopy.kt", "LocalizedScreenProjection.kt"}:
            continue
        text = path.read_text()
        for offset, value, arguments in scan(text):
            key = normalize(value)
            entry = inventory.setdefault(key, {"ko": value, "hasTranslation": key in known, "sources": []})
            entry["sources"].append({"path": str(path.relative_to(ROOT)), "line": text.count("\n", 0, offset) + 1})
missing = sorted((value for value in inventory.values() if not value["hasTranslation"]), key=lambda value: value["ko"])
output = {"schemaVersion": 1, "uniqueTemplates": len(inventory), "covered": len(inventory) - len(missing), "missingCount": len(missing), "missing": missing}
if "--check" not in sys.argv:
    (ROOT / "docs/localization/android-copy-inventory.json").write_text(json.dumps(output, ensure_ascii=False, indent=2) + "\n")
print(f"Kotlin copy templates: {len(inventory)}, mapped: {output['covered']}, need review: {len(missing)}")

if "--check" in sys.argv and missing:
    raise SystemExit(1)
