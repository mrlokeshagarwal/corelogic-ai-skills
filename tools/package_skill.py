#!/usr/bin/env python3
"""Package canonical skill folders into skill.zip for ChatGPT / Claude Desktop upload."""

from __future__ import annotations

import argparse
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Package one or more skills into skill.zip archives"
    )
    skill_group = parser.add_mutually_exclusive_group(required=True)
    skill_group.add_argument(
        "--skill",
        action="append",
        dest="skills",
        help="Canonical skill name; repeat to package multiple skills",
    )
    skill_group.add_argument(
        "--all",
        dest="all_skills",
        action="store_true",
        help="Package every skill under skills/",
    )
    parser.add_argument(
        "--output",
        help="Output zip path (only valid when packaging a single skill)",
    )
    return parser.parse_args()


def discover_skills() -> list[str]:
    skills_root = ROOT / "skills"
    if not skills_root.is_dir():
        return []
    return sorted(
        path.name
        for path in skills_root.iterdir()
        if path.is_dir() and (path / "SKILL.md").exists()
    )


def resolve_skills(skills: list[str] | None, all_skills: bool) -> list[str]:
    if all_skills:
        names = discover_skills()
        if not names:
            raise SystemExit("No skills found under skills/")
        return names

    assert skills is not None
    unknown = [name for name in skills if not (ROOT / "skills" / name).is_dir()]
    if unknown:
        raise SystemExit(f"Unknown skill(s): {', '.join(unknown)}")
    seen: set[str] = set()
    ordered: list[str] = []
    for name in skills:
        if name not in seen:
            seen.add(name)
            ordered.append(name)
    return ordered


def package_skill(skill: str, output: Path) -> Path:
    source = ROOT / "skills" / skill
    if not source.is_dir():
        raise SystemExit(f"Unknown skill: {skill}")
    if not (source / "SKILL.md").exists():
        raise SystemExit(f"Missing SKILL.md in {source}")

    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()

    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(source.rglob("*")):
            if not path.is_file():
                continue
            if any(part in {".git", "__pycache__"} for part in path.parts):
                continue
            if path.suffix == ".pyc":
                continue
            archive.write(path, arcname=path.relative_to(source).as_posix())

    return output


def main() -> None:
    args = parse_args()
    skills = resolve_skills(args.skills, args.all_skills)

    if args.output and len(skills) != 1:
        raise SystemExit("--output can only be used when packaging a single skill")

    for skill in skills:
        output = (
            Path(args.output).expanduser().resolve()
            if args.output
            else ROOT / "dist" / skill / "skill.zip"
        )
        path = package_skill(skill, output)
        print(path)


if __name__ == "__main__":
    main()
