#!/usr/bin/env python3
"""Smoke-test installer destinations, multi-skill CLI, and packaged skill.zip."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import install_skill  # noqa: E402
import package_skill  # noqa: E402


def main() -> int:
    failures: list[str] = []

    discovered = install_skill.discover_skills()
    if "dotnet-upgrade" not in discovered:
        print("FAIL: discover_skills missing dotnet-upgrade")
        failures.append("discover_skills")
    else:
        print("PASS: discover_skills")

    resolved = install_skill.resolve_skills(["dotnet-upgrade", "dotnet-upgrade"], False)
    if resolved != ["dotnet-upgrade"]:
        print("FAIL: resolve_skills dedupe")
        failures.append("resolve_skills_dedupe")
    else:
        print("PASS: resolve_skills dedupe")

    all_skills = install_skill.resolve_skills(None, True)
    if all_skills != discovered:
        print("FAIL: resolve_skills --all")
        failures.append("resolve_skills_all")
    else:
        print("PASS: resolve_skills --all")

    with tempfile.TemporaryDirectory() as td:
        home = Path(td) / "home"
        target = Path(td) / "proj"
        home.mkdir()
        target.mkdir()

        for skill_name in discovered:
            source = ROOT / "skills" / skill_name
            for platform in ["claude", "cursor", "opencode", "codex", "chatgpt"]:
                install_skill.install_global(source, skill_name, platform, home)
                install_skill.install_project(source, skill_name, target, platform)

        for skill_name in discovered:
            checks = {
                f"{skill_name}_claude_global": home
                / f".claude/skills/{skill_name}/SKILL.md",
                f"{skill_name}_cursor_global": home
                / f".cursor/skills/{skill_name}/SKILL.md",
                f"{skill_name}_opencode_global": home
                / f".config/opencode/skills/{skill_name}/SKILL.md",
                f"{skill_name}_codex_global": home
                / f".agents/skills/{skill_name}/SKILL.md",
                f"{skill_name}_claude_project": target
                / f".claude/skills/{skill_name}/SKILL.md",
                f"{skill_name}_cursor_project": target
                / f".cursor/skills/{skill_name}/SKILL.md",
                f"{skill_name}_opencode_project": target
                / f".opencode/skills/{skill_name}/SKILL.md",
                f"{skill_name}_codex_project": target
                / f".agents/skills/{skill_name}/SKILL.md",
            }
            for name, path in checks.items():
                if path.exists():
                    print(f"PASS: {name}")
                else:
                    print(f"FAIL: {name}")
                    failures.append(name)

            cursor_rule = target / f".cursor/rules/{skill_name}.mdc"
            if (ROOT / "adapters" / "cursor" / f"{skill_name}.mdc").exists():
                if cursor_rule.exists() and f".cursor/skills/{skill_name}/SKILL.md" in cursor_rule.read_text(
                    encoding="utf-8"
                ):
                    print(f"PASS: {skill_name} cursor rule")
                else:
                    print(f"FAIL: {skill_name} cursor rule")
                    failures.append(f"{skill_name}_cursor_rule")

            snippet = ROOT / "adapters" / "codex" / f"{skill_name}.snippet.md"
            if snippet.exists():
                marker = next(
                    line.strip()
                    for line in snippet.read_text(encoding="utf-8").splitlines()
                    if line.startswith("## ")
                )
                agents = (home / ".agents/AGENTS.md").read_text(encoding="utf-8")
                if marker in agents:
                    print(f"PASS: {skill_name} codex snippet")
                else:
                    print(f"FAIL: {skill_name} codex snippet")
                    failures.append(f"{skill_name}_codex_snippet")

        # Multi-skill CLI against a fake second skill in a temp library layout is
        # unnecessary; exercise argparse via --help and --all dry-run discovery.
        help_proc = subprocess.run(
            [sys.executable, str(ROOT / "tools" / "install_skill.py"), "--help"],
            capture_output=True,
            text=True,
        )
        if help_proc.returncode == 0 and "--all" in help_proc.stdout:
            print("PASS: install_skill --help shows --all")
        else:
            print("FAIL: install_skill --help")
            failures.append("install_help")

        pkg_help = subprocess.run(
            [sys.executable, str(ROOT / "tools" / "package_skill.py"), "--help"],
            capture_output=True,
            text=True,
        )
        if pkg_help.returncode == 0 and "--all" in pkg_help.stdout:
            print("PASS: package_skill --help shows --all")
        else:
            print("FAIL: package_skill --help")
            failures.append("package_help")

    for skill_name in discovered:
        zip_path = ROOT / "dist" / skill_name / "skill.zip"
        if not zip_path.exists():
            package_skill.package_skill(skill_name, zip_path)
        if not zip_path.exists():
            print(f"FAIL: {skill_name} skill.zip missing")
            failures.append(f"{skill_name}_zip_missing")
            continue
        names = set(zipfile.ZipFile(zip_path).namelist())
        if "SKILL.md" in names:
            print(f"PASS: {skill_name} zip contains SKILL.md")
        else:
            print(f"FAIL: {skill_name} zip missing SKILL.md")
            failures.append(f"{skill_name}_zip_skill_md")

    # Keep a stronger check for the known first skill.
    zip_path = ROOT / "dist/dotnet-upgrade/skill.zip"
    if zip_path.exists():
        names = set(zipfile.ZipFile(zip_path).namelist())
        for required in [
            "SKILL.md",
            "skill.yaml",
            "agents/openai.yaml",
            "scripts/inspect_repo.py",
            "references/upgrade-strategy.md",
            "references/netfx-to-sdk.md",
        ]:
            if required in names:
                print(f"PASS: zip contains {required}")
            else:
                print(f"FAIL: zip missing {required}")
                failures.append(required)

    if failures:
        print("smoke failed:", ", ".join(failures))
        return 1
    print("installer smoke ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
