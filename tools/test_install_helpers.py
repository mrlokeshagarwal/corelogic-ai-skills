#!/usr/bin/env python3
"""unittest suite for installer helper behavior."""

from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import install_skill  # noqa: E402


class InstallHelperTests(unittest.TestCase):
    def test_upsert_replaces_managed_block(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "AGENTS.md"
            install_skill.upsert_managed_block(
                path,
                "start-story",
                "## Start Story workflow\n\nVersion one.",
            )
            first = path.read_text(encoding="utf-8")
            self.assertIn("<!-- corelogic-ai-skills:start:start-story -->", first)
            self.assertIn("Version one.", first)

            install_skill.upsert_managed_block(
                path,
                "start-story",
                "## Start Story workflow\n\nVersion two.",
            )
            second = path.read_text(encoding="utf-8")
            self.assertIn("Version two.", second)
            self.assertNotIn("Version one.", second)
            self.assertEqual(
                second.count("<!-- corelogic-ai-skills:start:start-story -->"), 1
            )

    def test_upsert_migrates_legacy_unmanaged_heading(self) -> None:
        with tempfile.TemporaryDirectory() as td:
            path = Path(td) / "AGENTS.md"
            path.write_text(
                "## Start Story workflow\n\nLegacy text that should be replaced.\n",
                encoding="utf-8",
            )
            install_skill.upsert_managed_block(
                path,
                "start-story",
                "## Start Story workflow\n\nManaged text.",
            )
            text = path.read_text(encoding="utf-8")
            self.assertIn("Managed text.", text)
            self.assertNotIn("Legacy text that should be replaced.", text)
            self.assertIn("<!-- corelogic-ai-skills:end:start-story -->", text)


if __name__ == "__main__":
    unittest.main()
