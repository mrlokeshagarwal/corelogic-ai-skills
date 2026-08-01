#!/usr/bin/env python3
"""Tests for inspect_repo.py inventory behavior."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "inspect_repo.py"


def run_inspect(root: Path, output: Path, extra_args: list[str] | None = None) -> dict:
    cmd = [
        sys.executable,
        str(SCRIPT),
        "--root",
        str(root),
        "--output",
        str(output),
        "--skip-commands",
        *(extra_args or []),
    ]
    proc = subprocess.run(cmd, capture_output=True, text=True)
    assert proc.returncode == 0, proc.stderr
    return json.loads(output.read_text(encoding="utf-8"))


def test_attribute_version_and_framework() -> None:
    with tempfile.TemporaryDirectory() as td:
        root = Path(td) / "repo"
        root.mkdir()
        out = Path(td) / "report.json"
        (root / "Sample.csproj").write_text(
            """
            <Project Sdk="Microsoft.NET.Sdk">
              <PropertyGroup>
                <TargetFramework>net8.0</TargetFramework>
              </PropertyGroup>
              <ItemGroup>
                <PackageReference Include="Example.Package" Version="1.2.3" />
              </ItemGroup>
            </Project>
            """.strip(),
            encoding="utf-8",
        )
        data = run_inspect(root, out)
        assert data["projects"][0]["TargetFramework"] == ["net8.0"]
        assert data["projects"][0]["frameworks"] == ["net8.0"]
        assert data["package_references"][0]["package"] == "Example.Package"
        assert data["package_references"][0]["version"] == "1.2.3"


def test_child_version_element() -> None:
    with tempfile.TemporaryDirectory() as td:
        root = Path(td) / "repo"
        root.mkdir()
        out = Path(td) / "report.json"
        (root / "Sample.csproj").write_text(
            """
            <Project Sdk="Microsoft.NET.Sdk">
              <PropertyGroup>
                <TargetFramework>net8.0</TargetFramework>
              </PropertyGroup>
              <ItemGroup>
                <PackageReference Include="Child.Version.Package">
                  <Version>9.8.7</Version>
                </PackageReference>
              </ItemGroup>
            </Project>
            """.strip(),
            encoding="utf-8",
        )
        data = run_inspect(root, out)
        assert data["package_references"][0]["version"] == "9.8.7"


def test_cpm_package_version_resolution() -> None:
    with tempfile.TemporaryDirectory() as td:
        root = Path(td) / "repo"
        root.mkdir()
        out = Path(td) / "report.json"
        (root / "Directory.Packages.props").write_text(
            """
            <Project>
              <ItemGroup>
                <PackageVersion Include="Cpm.Package" Version="4.5.6" />
              </ItemGroup>
            </Project>
            """.strip(),
            encoding="utf-8",
        )
        (root / "Sample.csproj").write_text(
            """
            <Project Sdk="Microsoft.NET.Sdk">
              <PropertyGroup>
                <TargetFramework>net8.0</TargetFramework>
              </PropertyGroup>
              <ItemGroup>
                <PackageReference Include="Cpm.Package" />
              </ItemGroup>
            </Project>
            """.strip(),
            encoding="utf-8",
        )
        data = run_inspect(root, out)
        assert data["central_package_versions"]["Cpm.Package"] == "4.5.6"
        assert data["package_references"][0]["version"] == "4.5.6"
        assert data["package_references"][0]["version_source"] == "Directory.Packages.props"


def test_target_framework_version_and_packages_config() -> None:
    with tempfile.TemporaryDirectory() as td:
        root = Path(td) / "repo"
        root.mkdir()
        out = Path(td) / "report.json"
        (root / "Legacy.csproj").write_text(
            """
            <Project ToolsVersion="15.0">
              <PropertyGroup>
                <TargetFrameworkVersion>v4.8</TargetFrameworkVersion>
              </PropertyGroup>
            </Project>
            """.strip(),
            encoding="utf-8",
        )
        (root / "packages.config").write_text(
            """
            <?xml version="1.0" encoding="utf-8"?>
            <packages>
              <package id="Newtonsoft.Json" version="13.0.1" targetFramework="net48" />
            </packages>
            """.strip(),
            encoding="utf-8",
        )
        data = run_inspect(root, out)
        assert data["projects"][0]["TargetFrameworkVersion"] == ["v4.8"]
        assert "v4.8" in data["projects"][0]["frameworks"]
        pkg = next(p for p in data["package_references"] if p["source"] == "packages.config")
        assert pkg["package"] == "Newtonsoft.Json"
        assert pkg["version"] == "13.0.1"


def test_refuses_output_inside_repo_without_flag() -> None:
    with tempfile.TemporaryDirectory() as td:
        root = Path(td) / "repo"
        root.mkdir()
        (root / "Sample.csproj").write_text(
            '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup></Project>',
            encoding="utf-8",
        )
        inside = root / "report.json"
        proc = subprocess.run(
            [
                sys.executable,
                str(SCRIPT),
                "--root",
                str(root),
                "--output",
                str(inside),
            ],
            capture_output=True,
            text=True,
        )
        assert proc.returncode == 2
        assert "Refusing to write" in proc.stderr


def test_allows_inside_repo_with_flag() -> None:
    with tempfile.TemporaryDirectory() as td:
        root = Path(td) / "repo"
        root.mkdir()
        out = root / ".dotnet-upgrade" / "report.json"
        (root / "Sample.csproj").write_text(
            '<Project Sdk="Microsoft.NET.Sdk"><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup></Project>',
            encoding="utf-8",
        )
        data = run_inspect(root, out, extra_args=["--inside-repo"])
        assert data["projects"][0]["path"] == "Sample.csproj"


if __name__ == "__main__":
    test_attribute_version_and_framework()
    test_child_version_element()
    test_cpm_package_version_resolution()
    test_target_framework_version_and_packages_config()
    test_refuses_output_inside_repo_without_flag()
    test_allows_inside_repo_with_flag()
    print("ok")
