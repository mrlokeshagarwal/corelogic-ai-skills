#!/usr/bin/env python3
"""Install canonical CoreLogic AI skills for supported agent platforms."""

from __future__ import annotations

import argparse
import re
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
    seen: set[str] = set()
    ordered: list[str] = []
    for name in skills:
        if name not in seen:
            seen.add(name)
            ordered.append(name)
    return ordered


def replace_tree(source: Path, destination: Path) -> None:
    """Replace an installed skill tree. User config must live outside this folder."""
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.exists() or destination.is_symlink():
        if destination.is_dir() and not destination.is_symlink():
            shutil.rmtree(destination)
        else:
            destination.unlink()
    shutil.copytree(source, destination)


def upsert_managed_block(path: Path, skill: str, content: str) -> None:
    """Insert or replace a managed Codex AGENTS.md block for a skill."""
    start = f"<!-- corelogic-ai-skills:start:{skill} -->"
    end = f"<!-- corelogic-ai-skills:end:{skill} -->"
    block = f"{start}\n{content.rstrip()}\n{end}"

    existing = path.read_text(encoding="utf-8") if path.exists() else ""
    existing = remove_legacy_unmanaged_section(existing, content)

    pattern = re.compile(
        rf"{re.escape(start)}.*?{re.escape(end)}",
        re.DOTALL,
    )
    if pattern.search(existing):
        updated = pattern.sub(block, existing)
    else:
        separator = "" if not existing or existing.endswith("\n") else "\n"
        if existing and not existing.endswith("\n\n"):
            separator = "\n" if existing.endswith("\n") else "\n\n"
        updated = existing + separator + block + "\n"

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(updated, encoding="utf-8")


def remove_legacy_unmanaged_section(text: str, snippet: str) -> str:
    """Remove a pre-marker heading section that matches the snippet's first H2."""
    heading = next(
        (line.strip() for line in snippet.splitlines() if line.startswith("## ")),
        None,
    )
    if not heading or heading not in text:
        return text

    start_token = "<!-- corelogic-ai-skills:start:"
    lines = text.splitlines(keepends=True)
    out: list[str] = []
    i = 0
    while i < len(lines):
        stripped = lines[i].strip()
        if stripped == heading:
            # Keep if this heading is inside a managed block.
            preceding = "".join(out)
            if start_token in preceding and preceding.rfind(start_token) > preceding.rfind(
                "<!-- corelogic-ai-skills:end:"
            ):
                out.append(lines[i])
                i += 1
                continue
            i += 1
            while i < len(lines):
                nxt = lines[i].strip()
                if nxt.startswith("## ") or nxt.startswith("<!-- corelogic-ai-skills:"):
                    break
                i += 1
            # Drop one trailing blank line after the removed section.
            if out and out[-1].strip() == "":
                out.pop()
            continue
        out.append(lines[i])
        i += 1
    return "".join(out)


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

    upsert_managed_block(agents_md, skill, snippet)


def install_cursor_rule(skill: str, target: Path) -> None:
    adapter = ROOT / "adapters" / "cursor" / f"{skill}.mdc"
    if not adapter.exists():
        print(f"No Cursor rule adapter found for {skill}; installed skill folder only.")
        return
    rules = target / ".cursor" / "rules"
    rules.mkdir(parents=True, exist_ok=True)
    shutil.copy2(adapter, rules / f"{skill}.mdc")


def config_hint(skill: str) -> None:
    if skill != "start-story":
        return
    print(
        "Note: start-story user config belongs outside the skill folder "
        "(survives updates). Prefer:"
    )
    print("  Windows: %USERPROFILE%\\.corelogic-ai-skills\\start-story\\config.json")
    print("  macOS/Linux: ~/.config/corelogic-ai-skills/start-story/config.json")
    print("  Project: <repo>/.corelogic-ai-skills/start-story/config.json")


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
            config_hint(skill)
        return

    target = Path(args.target).expanduser().resolve()
    target.mkdir(parents=True, exist_ok=True)
    for skill in skills:
        source = ROOT / "skills" / skill
        for platform in args.platform:
            install_project(source, skill, target, platform)
        config_hint(skill)


if __name__ == "__main__":
    main()
