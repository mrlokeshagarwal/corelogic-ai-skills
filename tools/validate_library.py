#!/usr/bin/env python3
"""Validate canonical skill layout and frontmatter."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def parse_frontmatter(text: str) -> dict[str, str] | None:
    match = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not match:
        return None
    data: dict[str, str] = {}
    for line in match.group(1).splitlines():
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if ":" not in line:
            return None
        key, value = line.split(":", 1)
        data[key.strip()] = value.strip()
    return data


def main() -> int:
    errors: list[str] = []
    for skill in sorted((ROOT / "skills").iterdir()):
        if not skill.is_dir():
            continue
        md = skill / "SKILL.md"
        manifest = skill / "skill.yaml"
        if not md.exists():
            errors.append(f"{skill.name}: missing SKILL.md")
            continue
        text = md.read_text(encoding="utf-8")
        data = parse_frontmatter(text)
        if data is None:
            errors.append(f"{skill.name}: invalid frontmatter")
        else:
            if set(data) != {"name", "description"}:
                errors.append(
                    f"{skill.name}: frontmatter must contain only name and description"
                )
            if data.get("name") != skill.name:
                errors.append(f"{skill.name}: name mismatch")
        if not manifest.exists():
            errors.append(f"{skill.name}: missing skill.yaml")
        for ref in re.findall(
            r"`((?:references|scripts)/[^` ]+\.(?:md|py))`", text
        ):
            if not (skill / ref).exists():
                errors.append(f"{skill.name}: missing referenced file {ref}")
    if errors:
        print("\n".join(errors))
        return 1
    print("library validation passed")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
