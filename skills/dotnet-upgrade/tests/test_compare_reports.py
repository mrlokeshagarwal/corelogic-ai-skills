#!/usr/bin/env python3
"""Tests for compare_reports.py."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

COMPARE = Path(__file__).resolve().parents[1] / "scripts" / "compare_reports.py"
INSPECT = Path(__file__).resolve().parents[1] / "scripts" / "inspect_repo.py"


def test_detects_framework_and_version_changes() -> None:
    with tempfile.TemporaryDirectory() as td:
        root = Path(td) / "repo"
        root.mkdir()
        before = Path(td) / "before.json"
        after = Path(td) / "after.json"

        (root / "A.csproj").write_text(
            """
            <Project Sdk="Microsoft.NET.Sdk">
              <PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup>
              <ItemGroup>
                <PackageReference Include="Example.Package" Version="1.0.0" />
              </ItemGroup>
            </Project>
            """.strip(),
            encoding="utf-8",
        )
        assert (
            subprocess.run(
                [
                    sys.executable,
                    str(INSPECT),
                    "--root",
                    str(root),
                    "--output",
                    str(before),
                    "--skip-commands",
                ],
                capture_output=True,
                text=True,
            ).returncode
            == 0
        )

        (root / "A.csproj").write_text(
            """
            <Project Sdk="Microsoft.NET.Sdk">
              <PropertyGroup><TargetFramework>net9.0</TargetFramework></PropertyGroup>
              <ItemGroup>
                <PackageReference Include="Example.Package" Version="2.0.0" />
              </ItemGroup>
            </Project>
            """.strip(),
            encoding="utf-8",
        )
        assert (
            subprocess.run(
                [
                    sys.executable,
                    str(INSPECT),
                    "--root",
                    str(root),
                    "--output",
                    str(after),
                    "--skip-commands",
                ],
                capture_output=True,
                text=True,
            ).returncode
            == 0
        )

        proc = subprocess.run(
            [sys.executable, str(COMPARE), str(before), str(after)],
            capture_output=True,
            text=True,
        )
        assert proc.returncode == 0, proc.stderr
        data = json.loads(proc.stdout)
        assert data["frameworks_before"] == ["net8.0"]
        assert data["frameworks_after"] == ["net9.0"]
        assert data["packages_changed"] == [
            {
                "project": "A.csproj",
                "package": "Example.Package",
                "before": "1.0.0",
                "after": "2.0.0",
            }
        ]


if __name__ == "__main__":
    test_detects_framework_and_version_changes()
    print("ok")
