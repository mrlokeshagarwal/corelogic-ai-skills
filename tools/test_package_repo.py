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
                names = zipfile.ZipFile(output).namelist()
                self.assertTrue(any(name.endswith("SKILL.md") for name in names))
                self.assertFalse(any(name.startswith(".git/") for name in names))
                self.assertFalse(any("__pycache__" in name for name in names))
                self.assertFalse(any(name.startswith("dist/") for name in names))
            finally:
                package_repo.ROOT = original_root


if __name__ == "__main__":
    unittest.main()
