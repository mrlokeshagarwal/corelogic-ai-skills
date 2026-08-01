#!/usr/bin/env python3
"""Create a clean, complete source archive of this library for release."""

from __future__ import annotations

import argparse
import subprocess
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXCLUDE_DIR_NAMES = {
    ".git",
    "__pycache__",
    ".venv",
    "venv",
    "dist",
    ".pytest_cache",
    ".mypy_cache",
    ".ruff_cache",
    "node_modules",
    ".vs",
    ".idea",
    ".corelogic-ai-skills",
}
EXCLUDE_FILE_SUFFIXES = {".pyc", ".pyo"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Package a clean, complete repository ZIP for release. "
            "Default is a filtered working-tree archive (not git archive), "
            "so uncommitted skill scripts are included."
        )
    )
    parser.add_argument(
        "--output",
        default=str(ROOT / "dist" / "corelogic-ai-skills.zip"),
        help="Output zip path (default: dist/corelogic-ai-skills.zip)",
    )
    parser.add_argument(
        "--git-archive",
        action="store_true",
        help=(
            "Use git archive HEAD instead of the working tree. "
            "Requires a clean working tree and still runs completeness checks."
        ),
    )
    return parser.parse_args()


def is_git_work_tree(path: Path) -> bool:
    try:
        proc = subprocess.run(
            ["git", "rev-parse", "--is-inside-work-tree"],
            cwd=path,
            capture_output=True,
            text=True,
            check=False,
        )
    except OSError:
        return False
    return proc.returncode == 0 and proc.stdout.strip() == "true"


def assert_clean_git_worktree() -> None:
    proc = subprocess.run(
        ["git", "status", "--porcelain"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        raise SystemExit(proc.stderr.strip() or "git status failed")
    if proc.stdout.strip():
        raise SystemExit(
            "Refusing --git-archive with a dirty working tree. "
            "Commit or stash changes, or omit --git-archive to package the "
            "working tree with filters."
        )


def package_with_git_archive(output: Path) -> Path:
    assert_clean_git_worktree()
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()
    proc = subprocess.run(
        ["git", "archive", "--format=zip", f"--output={output}", "HEAD"],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        raise SystemExit(proc.stderr.strip() or "git archive failed")
    return output


def should_skip(path: Path) -> bool:
    rel_parts = path.relative_to(ROOT).parts
    if any(part in EXCLUDE_DIR_NAMES for part in rel_parts):
        return True
    if path.suffix in EXCLUDE_FILE_SUFFIXES:
        return True
    return False


def package_with_filters(output: Path) -> Path:
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()

    with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for path in sorted(ROOT.rglob("*")):
            if not path.is_file():
                continue
            if should_skip(path):
                continue
            if path.resolve() == output.resolve():
                continue
            archive.write(path, arcname=path.relative_to(ROOT).as_posix())
    return output


def normalize_name(name: str) -> str:
    return name.replace("\\", "/").lstrip("./")


def archive_names(output: Path) -> set[str]:
    return {normalize_name(name) for name in zipfile.ZipFile(output).namelist()}


def required_release_paths() -> list[str]:
    """Paths that must be present for a publishable release archive."""
    required = [
        "README.md",
        "LICENSE",
        "tools/install_skill.py",
        "tools/package_skill.py",
        "tools/package_repo.py",
        "tools/validate_library.py",
    ]
    skills_root = ROOT / "skills"
    if skills_root.is_dir():
        for skill_dir in sorted(p for p in skills_root.iterdir() if p.is_dir()):
            required.append(f"skills/{skill_dir.name}/SKILL.md")
            required.append(f"skills/{skill_dir.name}/skill.yaml")
            scripts = skill_dir / "scripts"
            if scripts.is_dir():
                for script in sorted(scripts.rglob("*")):
                    if script.is_file() and not should_skip(script):
                        required.append(script.relative_to(ROOT).as_posix())
    return required


def assert_clean_archive(output: Path) -> None:
    names = archive_names(output)
    for name in sorted(names):
        if name.startswith(".git/") or name.endswith(".pyc"):
            raise SystemExit(f"Archive contains excluded path: {name}")
        if "__pycache__/" in name or name.startswith("dist/"):
            raise SystemExit(f"Archive contains excluded path: {name}")


def assert_complete_archive(output: Path) -> None:
    names = archive_names(output)
    missing = [path for path in required_release_paths() if path not in names]
    if missing:
        preview = "\n".join(f"  - {path}" for path in missing[:30])
        more = "" if len(missing) <= 30 else f"\n  ... and {len(missing) - 30} more"
        raise SystemExit(
            "Release ZIP is incomplete and must not be published.\n"
            "Missing required paths:\n"
            f"{preview}{more}\n"
            "Package the working tree with: python tools/package_repo.py\n"
            "Or commit all skill files before using --git-archive."
        )


def main() -> int:
    args = parse_args()
    output = Path(args.output).expanduser().resolve()

    if args.git_archive:
        if not is_git_work_tree(ROOT):
            raise SystemExit("--git-archive requires a git work tree")
        path = package_with_git_archive(output)
        method = "git-archive"
    else:
        path = package_with_filters(output)
        method = "filtered-working-tree"

    assert_clean_archive(path)
    assert_complete_archive(path)
    print(f"{path} ({method})")
    print("Release ZIP completeness checks passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
