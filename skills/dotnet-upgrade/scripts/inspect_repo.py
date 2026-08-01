#!/usr/bin/env python3
"""Inventory a local .NET repository without changing it."""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

IGNORE = {".git", ".vs", ".idea", "bin", "obj", "node_modules", "packages"}
PROJECT_SUFFIXES = {".csproj", ".fsproj", ".vbproj"}
SOLUTION_SUFFIXES = {".sln", ".slnx"}
CONFIG_NAMES = {
    "nuget.config",
    "directory.packages.props",
    "directory.build.props",
    "directory.build.targets",
    "global.json",
    "packages.lock.json",
    "packages.config",
}
TFM_TAGS = {
    "TargetFramework",
    "TargetFrameworks",
    "TargetFrameworkVersion",
    "RuntimeIdentifier",
    "RuntimeIdentifiers",
    "LangVersion",
    "Nullable",
}
SECRET_PATTERNS = [
    re.compile(r"(?i)(password|pwd|secret|token|apikey|api_key|access_key)\s*[=:]\s*\S+"),
    re.compile(r"(?i)(bearer\s+)[a-z0-9._\-]+"),
    re.compile(r"(?i)(authorization:\s*)\S+"),
]
DOTNET_LIST_TIMEOUT = 180


def local_name(tag: str) -> str:
    return tag.split("}")[-1]


def redact(text: str) -> str:
    redacted = text
    for pattern in SECRET_PATTERNS:
        redacted = pattern.sub(r"\1***", redacted)
    return redacted


def run(cmd: list[str], cwd: Path, timeout: int = 60) -> dict:
    try:
        proc = subprocess.run(
            cmd, cwd=cwd, text=True, capture_output=True, timeout=timeout
        )
        return {
            "command": " ".join(cmd),
            "exit_code": proc.returncode,
            "stdout": redact(proc.stdout[-12000:]),
            "stderr": redact(proc.stderr[-12000:]),
        }
    except (OSError, subprocess.TimeoutExpired) as exc:
        return {"command": " ".join(cmd), "exit_code": None, "error": str(exc)}


def walk_files(root: Path):
    for base, dirs, files in os.walk(root):
        dirs[:] = [d for d in dirs if d not in IGNORE]
        for name in files:
            yield Path(base) / name


def xml_values(path: Path, tags: set[str]) -> dict[str, list[str]]:
    values = {tag: [] for tag in tags}
    try:
        tree = ET.parse(path)
        for elem in tree.iter():
            tag = local_name(elem.tag)
            if tag in values and elem.text and elem.text.strip():
                values[tag].append(elem.text.strip())
    except (ET.ParseError, OSError):
        pass
    return values


def package_version_from_element(elem: ET.Element) -> str | None:
    version = elem.get("Version")
    if version and version.strip():
        return version.strip()
    for child in elem:
        if local_name(child.tag) == "Version" and child.text and child.text.strip():
            return child.text.strip()
    return None


def package_references_from_project(path: Path, rel: str) -> list[dict]:
    refs = []
    try:
        tree = ET.parse(path)
    except (ET.ParseError, OSError):
        return refs
    for elem in tree.iter():
        if local_name(elem.tag) != "PackageReference":
            continue
        include = elem.get("Include") or elem.get("Update")
        if not include:
            continue
        refs.append(
            {
                "project": rel,
                "package": include,
                "version": package_version_from_element(elem),
                "source": "PackageReference",
            }
        )
    return refs


def packages_from_packages_config(path: Path, rel: str) -> list[dict]:
    refs = []
    try:
        tree = ET.parse(path)
    except (ET.ParseError, OSError):
        return refs
    for elem in tree.iter():
        if local_name(elem.tag) != "package":
            continue
        package_id = elem.get("id")
        if not package_id:
            continue
        version = elem.get("version")
        refs.append(
            {
                "project": rel,
                "package": package_id,
                "version": version.strip() if version else None,
                "source": "packages.config",
            }
        )
    return refs


def cpm_package_versions(path: Path) -> dict[str, str]:
    versions: dict[str, str] = {}
    try:
        tree = ET.parse(path)
    except (ET.ParseError, OSError):
        return versions
    for elem in tree.iter():
        if local_name(elem.tag) != "PackageVersion":
            continue
        include = elem.get("Include") or elem.get("Update")
        if not include:
            continue
        version = package_version_from_element(elem)
        if version:
            versions[include] = version
    return versions


def resolve_cpm_versions(package_refs: list[dict], cpm: dict[str, str]) -> None:
    for ref in package_refs:
        if ref.get("version") is None and ref.get("package") in cpm:
            ref["version"] = cpm[ref["package"]]
            ref["version_source"] = "Directory.Packages.props"


def framework_targets(vals: dict[str, list[str]]) -> list[str]:
    targets: list[str] = []
    for key in ("TargetFramework", "TargetFrameworks", "TargetFrameworkVersion"):
        for value in vals.get(key, []):
            for part in re.split(r"[;\s]+", value):
                if part:
                    targets.append(part)
    return targets


def list_command_targets(root: Path, solutions: list[str], projects: list[dict]) -> list[str]:
    if solutions:
        return solutions
    return [p["path"] for p in projects[:20]]


def run_package_lists(root: Path, targets: list[str]) -> dict:
    if not targets:
        return {
            "package_vulnerabilities": {
                "command": "dotnet list package --vulnerable --include-transitive",
                "exit_code": None,
                "error": "No solution or project found to inspect",
            },
            "package_outdated": {
                "command": "dotnet list package --outdated --include-transitive",
                "exit_code": None,
                "error": "No solution or project found to inspect",
            },
        }

    vuln_results = []
    outdated_results = []
    for target in targets:
        vuln_results.append(
            run(
                [
                    "dotnet",
                    "list",
                    target,
                    "package",
                    "--vulnerable",
                    "--include-transitive",
                ],
                root,
                timeout=DOTNET_LIST_TIMEOUT,
            )
        )
        outdated_results.append(
            run(
                [
                    "dotnet",
                    "list",
                    target,
                    "package",
                    "--outdated",
                    "--include-transitive",
                ],
                root,
                timeout=DOTNET_LIST_TIMEOUT,
            )
        )

    if len(targets) == 1:
        return {
            "package_vulnerabilities": vuln_results[0],
            "package_outdated": outdated_results[0],
        }
    return {
        "package_vulnerabilities": {"targets": vuln_results},
        "package_outdated": {"targets": outdated_results},
    }


def inspect(root: Path, *, skip_commands: bool = False) -> dict:
    files = list(walk_files(root))
    projects: list[dict] = []
    configs: list[str] = []
    pipelines: list[str] = []
    docker: list[str] = []
    tools: list[str] = []
    package_refs: list[dict] = []
    cpm: dict[str, str] = {}

    for path in files:
        rel = path.relative_to(root).as_posix()
        low = path.name.lower()

        if path.suffix.lower() in PROJECT_SUFFIXES:
            vals = xml_values(path, TFM_TAGS)
            package_refs.extend(package_references_from_project(path, rel))
            projects.append(
                {
                    "path": rel,
                    "frameworks": framework_targets(vals),
                    **vals,
                }
            )

        if low == "packages.config":
            package_refs.extend(packages_from_packages_config(path, rel))
            configs.append(rel)

        if low == "directory.packages.props":
            cpm.update(cpm_package_versions(path))
            configs.append(rel)
        elif low in CONFIG_NAMES:
            configs.append(rel)

        if low in {"dockerfile", "docker-compose.yml", "docker-compose.yaml"} or low.endswith(
            ".dockerfile"
        ):
            docker.append(rel)

        if (
            rel.startswith(".github/workflows/")
            or low
            in {
                "azure-pipelines.yml",
                "azure-pipelines.yaml",
                "bitbucket-pipelines.yml",
                ".gitlab-ci.yml",
                "jenkinsfile",
            }
        ):
            pipelines.append(rel)

        if rel.endswith(".config/dotnet-tools.json") or low == "dotnet-tools.json":
            tools.append(rel)

    resolve_cpm_versions(package_refs, cpm)

    solutions = sorted(
        f.relative_to(root).as_posix()
        for f in files
        if f.suffix.lower() in SOLUTION_SUFFIXES
    )
    commands: dict
    if skip_commands:
        commands = {"skipped": True}
    else:
        targets = list_command_targets(root, solutions, projects)
        package_commands = run_package_lists(root, targets)
        commands = {
            "dotnet_info": run(["dotnet", "--info"], root),
            "git_status": run(["git", "status", "--short"], root),
            **package_commands,
        }

    return {
        "root": str(root),
        "solutions": solutions,
        "projects": projects,
        "package_references": package_refs,
        "central_package_versions": cpm,
        "configuration_files": sorted(set(configs)),
        "pipeline_files": sorted(pipelines),
        "docker_files": sorted(docker),
        "tool_manifests": sorted(tools),
        "commands": commands,
    }


def default_output_path(root: Path) -> Path:
    return Path(tempfile.gettempdir()) / "dotnet-upgrade" / f"{root.name}-inspect.json"


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Inventory a local .NET repository without changing it."
    )
    parser.add_argument("--root", default=".")
    parser.add_argument(
        "--output",
        help=(
            "Write JSON report to this path. Prefer a path outside the repository "
            "or a gitignored location so feed URLs and restore diagnostics are not committed."
        ),
    )
    parser.add_argument(
        "--inside-repo",
        action="store_true",
        help="Allow --output to point inside the repository root.",
    )
    parser.add_argument(
        "--skip-commands",
        action="store_true",
        help="Skip dotnet/git command probes; inventory files only.",
    )
    args = parser.parse_args()

    root = Path(args.root).resolve()
    if not root.is_dir():
        print(f"Not a directory: {root}", file=sys.stderr)
        return 2

    output = Path(args.output).expanduser() if args.output else default_output_path(root)
    if not output.is_absolute():
        output = (Path.cwd() / output).resolve()
    else:
        output = output.resolve()

    try:
        output.relative_to(root)
        inside_repo = True
    except ValueError:
        inside_repo = False

    if inside_repo and not args.inside_repo:
        print(
            "Refusing to write the inspection report inside the repository. "
            "Use a path outside the repo, or pass --inside-repo for a gitignored location.",
            file=sys.stderr,
        )
        return 2

    data = inspect(root, skip_commands=args.skip_commands)
    payload = json.dumps(data, indent=2)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(payload, encoding="utf-8")
    print(output)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
