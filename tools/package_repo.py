#!/usr/bin/env python3
"""Create a clean source archive of this library without .git or build artifacts."""

from __future__ import annotations

import argparse
import subprocess
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
}
EXCLUDE_FILE_SUFFIXES = {".pyc", ".pyo"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Package a clean repository ZIP (no .git, caches, or dist)."
    )
    parser.add_argument(
        "--output",
        default=str(ROOT / "dist" / "corelogic-ai-skills.zip"),
        help="Output zip path (default: dist/corelogic-ai-skills.zip)",
    )
    parser.add_argument(
        "--prefer-git-archive",
        action="store_true",
        default=True,
        help="Use git archive when this directory is a git work tree (default).",
    )
    parser.add_argument(
        "--no-git-archive",
        action="store_true",
        help="Force a filesystem zip with exclusion filters.",
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


def package_with_git_archive(output: Path) -> Path:
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.exists():
        output.unlink()
    proc = subprocess.run(
        [
            "git",
            "archive",
            "--format=zip",
            f"--output={output}",
            "HEAD",
        ],
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
            # Never nest the archive inside itself if writing under dist/.
            if path.resolve() == output.resolve():
                continue
            archive.write(path, arcname=path.relative_to(ROOT).as_posix())
    return output


def assert_clean_archive(output: Path) -> None:
    names = zipfile.ZipFile(output).namelist()
    forbidden_prefixes = (".git/",)
    forbidden_parts = ("__pycache__/", "dist/")
    for name in names:
        normalized = name.replace("\\", "/")
        if normalized.startswith(forbidden_prefixes) or any(
            part in normalized for part in forbidden_parts
        ):
            raise SystemExit(f"Archive contains excluded path: {normalized}")
        if normalized.endswith(".pyc"):
            raise SystemExit(f"Archive contains excluded file: {normalized}")


def main() -> None:
    args = parse_args()
    output = Path(args.output).expanduser().resolve()

    use_git = args.prefer_git_archive and not args.no_git_archive and is_git_work_tree(ROOT)
    if use_git:
        path = package_with_git_archive(output)
        method = "git-archive"
    else:
        path = package_with_filters(output)
        method = "filtered-zip"

    assert_clean_archive(path)
    print(f"{path} ({method})")


if __name__ == "__main__":
    main()
