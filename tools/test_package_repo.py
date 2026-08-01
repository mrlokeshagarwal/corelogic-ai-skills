#!/usr/bin/env python3
"""unittest suite for clean repository packaging."""

from __future__ import annotations

import sys
import tempfile
import unittest
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import package_repo  # noqa: E402


class PackageRepoTests(unittest.TestCase):
    def test_filtered_zip_excludes_git_dist_and_caches(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            root = Path(td) / "repo"
            (root / "skills" / "demo").mkdir(parents=True)
            (root / "skills" / "demo" / "SKILL.md").write_text("x", encoding="utf-8")
            (root / "skills" / "demo" / "skill.yaml").write_text("name: demo\n", encoding="utf-8")
            (root / "skills" / "demo" / "scripts").mkdir()
            (root / "skills" / "demo" / "scripts" / "helper.py").write_text(
                "print(1)\n", encoding="utf-8"
            )
            (root / "tools").mkdir()
            for name in (
                "install_skill.py",
                "package_skill.py",
                "package_repo.py",
                "validate_library.py",
            ):
                (root / "tools" / name).write_text("#\n", encoding="utf-8")
            (root / "README.md").write_text("readme\n", encoding="utf-8")
            (root / "LICENSE").write_text("mit\n", encoding="utf-8")
            (root / ".git" / "objects").mkdir(parents=True)
            (root / ".git" / "config").write_text("bad", encoding="utf-8")
            (root / "dist" / "junk.txt").parent.mkdir(parents=True)
            (root / "dist" / "junk.txt").write_text("bad", encoding="utf-8")
            cache = root / "tools" / "__pycache__"
            cache.mkdir(parents=True)
            (cache / "x.pyc").write_bytes(b"bad")

            original_root = package_repo.ROOT
            try:
                package_repo.ROOT = root
                output = Path(td) / "out.zip"
                package_repo.package_with_filters(output)
                package_repo.assert_clean_archive(output)
                package_repo.assert_complete_archive(output)
                names = set(zipfile.ZipFile(output).namelist())
                self.assertIn("skills/demo/scripts/helper.py", names)
                self.assertFalse(any(name.startswith(".git/") for name in names))
                self.assertFalse(any("__pycache__" in name for name in names))
                self.assertFalse(any(name.startswith("dist/") for name in names))
            finally:
                package_repo.ROOT = original_root

    def test_incomplete_archive_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            output = Path(td) / "bad.zip"
            with zipfile.ZipFile(output, "w") as archive:
                archive.writestr("README.md", "incomplete\n")
            with self.assertRaises(SystemExit) as ctx:
                package_repo.assert_complete_archive(output)
            self.assertIn("must not be published", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
