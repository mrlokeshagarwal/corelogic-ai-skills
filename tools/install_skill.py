#!/usr/bin/env python3
"""Install canonical CoreLogic AI skills for supported agent platforms."""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT_DESTINATIONS = {
    "claude": Path(".claude/skills"),
    "opencode": Path(".opencode/skills"),
    "codex": Path(".agents/skills"),
    "cursor": Path(".cursor/skills"),
}
PLATFORMS = ["claude", "cursor", "opencode", "codex", "chatgpt"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Install one or more CoreLogic AI skills globally or into a project."
    )
    skill_group = parser.add_mutually_exclusive_group(required=True)
    skill_group.add_argument(
        "--skill",
        action="append",
        dest="skills",
        help="Canonical skill name; repeat to install multiple skills",
    )
    skill_group.add_argument(
        "--all",
        dest="all_skills",
        action="store_true",
        help="Install every skill under skills/",
    )
    destination = parser.add_mutually_exclusive_group(required=True)
    destination.add_argument("--target", help="Target project directory")
    destination.add_argument(
        "--global",
        dest="global_install",
        action="store_true",
        help="Install into supported user-level skill directories",
    )
    parser.add_argument(
        "--platform",
        action="append",
        required=True,
        choices=PLATFORMS,
        help="Platform to install for; repeat for multiple platforms",
    )
    return parser.parse_args()


def discover_skills() -> list[str]:
    skills_root = ROOT / "skills"
    if not skills_root.is_dir():
        return []
    names = []
    for path in sorted(skills_root.iterdir()):
        if path.is_dir() and (path / "SKILL.md").exists():
            names.append(path.name)
    return names


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
    # Preserve order while removing duplicates
    seen: set[str] = set()
    ordered: list[str] = []
    for name in skills:
        if name not in seen:
            seen.add(name)
            ordered.append(name)
    return ordered


def replace_tree(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists() or destination.is_symlink():
        if destination.is_dir() and not destination.is_symlink():
            shutil.rmtree(destination)
        else:
            destination.unlink()
    shutil.copytree(source, destination)


def append_once(path: Path, marker: str, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    existing = path.read_text(encoding="utf-8") if path.exists() else ""
    if marker in existing:
        return
    prefix = "" if not existing or existing.endswith("\n") else "\n"
    path.write_text(existing + prefix + content.rstrip() + "\n", encoding="utf-8")


def global_destination(platform: str, home: Path) -> Path | None:
    destinations = {
        "claude": home / ".claude" / "skills",
        "opencode": home / ".config" / "opencode" / "skills",
        "codex": home / ".agents" / "skills",
        "cursor": home / ".cursor" / "skills",
    }
    return destinations.get(platform)


def codex_snippet_path(skill: str) -> Path | None:
    candidate = ROOT / "adapters" / "codex" / f"{skill}.snippet.md"
    if candidate.exists():
        return candidate
    return None


def install_codex_snippet(skill: str, agents_md: Path, *, global_paths: bool) -> None:
    snippet_file = codex_snippet_path(skill)
    if snippet_file is None:
        print(f"No Codex AGENTS snippet found for {skill}; installed skill folder only.")
        return

    snippet = snippet_file.read_text(encoding="utf-8")
    if global_paths:
        snippet = snippet.replace(".agents/skills/", "~/.agents/skills/")

    marker = next(
        (line.strip() for line in snippet.splitlines() if line.startswith("## ")),
        f"## {skill}",
    )
    append_once(agents_md, marker, snippet)


def install_cursor_rule(skill: str, target: Path) -> None:
    adapter = ROOT / "adapters" / "cursor" / f"{skill}.mdc"
    if not adapter.exists():
        print(f"No Cursor rule adapter found for {skill}; installed skill folder only.")
        return
    rules = target / ".cursor" / "rules"
    rules.mkdir(parents=True, exist_ok=True)
    shutil.copy2(adapter, rules / f"{skill}.mdc")


def install_project(source: Path, skill: str, target: Path, platform: str) -> None:
    if platform == "chatgpt":
        print(
            f"ChatGPT uses packaged skill.zip for {skill}; no project install performed."
        )
        return

    if platform not in PROJECT_DESTINATIONS:
        raise SystemExit(f"Unsupported project platform: {platform}")

    destination = target / PROJECT_DESTINATIONS[platform] / skill
    replace_tree(source, destination)

    if platform == "cursor":
        install_cursor_rule(skill, target)

    if platform == "codex":
        install_codex_snippet(skill, target / "AGENTS.md", global_paths=False)

    print(f"Installed {skill} for {platform}: {destination}")


def install_global(source: Path, skill: str, platform: str, home: Path) -> None:
    if platform == "chatgpt":
        print(
            f"ChatGPT global installation is account-based for {skill}. Build "
            f"skill.zip with tools/package_skill.py --skill {skill}, then upload "
            "it from Plugins > Skills > Create > Upload from your computer."
        )
        return

    base = global_destination(platform, home)
    if base is None:
        raise SystemExit(f"Unsupported global platform: {platform}")

    destination = base / skill
    replace_tree(source, destination)

    if platform == "codex":
        install_codex_snippet(
            skill, home / ".agents" / "AGENTS.md", global_paths=True
        )

    print(f"Installed {skill} globally for {platform}: {destination}")


def main() -> None:
    args = parse_args()
    skills = resolve_skills(args.skills, args.all_skills)

    if args.global_install:
        home = Path.home()
        for skill in skills:
            source = ROOT / "skills" / skill
            for platform in args.platform:
                install_global(source, skill, platform, home)
        return

    target = Path(args.target).expanduser().resolve()
    target.mkdir(parents=True, exist_ok=True)
    for skill in skills:
        source = ROOT / "skills" / skill
        for platform in args.platform:
            install_project(source, skill, target, platform)


if __name__ == "__main__":
    main()
