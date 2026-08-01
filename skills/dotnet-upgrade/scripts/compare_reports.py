#!/usr/bin/env python3
"""Compare two inspect_repo JSON reports."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def load(path: str) -> dict:
    return json.loads(Path(path).read_text(encoding="utf-8"))


def frameworks(report: dict) -> list[str]:
    values = set()
    for project in report.get("projects", []):
        if project.get("frameworks"):
            values.update(project["frameworks"])
            continue
        for key in ("TargetFramework", "TargetFrameworks", "TargetFrameworkVersion"):
            values.update(project.get(key, []))
    return sorted(values)


def packages(report: dict) -> dict:
    return {
        (item["project"], item["package"]): item.get("version")
        for item in report.get("package_references", [])
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("before")
    parser.add_argument("after")
    parser.add_argument("--output")
    args = parser.parse_args()

    before = load(args.before)
    after = load(args.after)
    before_packages = packages(before)
    after_packages = packages(after)

    result = {
        "frameworks_before": frameworks(before),
        "frameworks_after": frameworks(after),
        "packages_added": [
            {
                "project": key[0],
                "package": key[1],
                "version": after_packages[key],
            }
            for key in sorted(after_packages.keys() - before_packages.keys())
        ],
        "packages_removed": [
            {
                "project": key[0],
                "package": key[1],
                "version": before_packages[key],
            }
            for key in sorted(before_packages.keys() - after_packages.keys())
        ],
        "packages_changed": [
            {
                "project": key[0],
                "package": key[1],
                "before": before_packages[key],
                "after": after_packages[key],
            }
            for key in sorted(before_packages.keys() & after_packages.keys())
            if before_packages[key] != after_packages[key]
        ],
    }
    payload = json.dumps(result, indent=2)
    if args.output:
        Path(args.output).write_text(payload, encoding="utf-8")
    else:
        print(payload)


if __name__ == "__main__":
    main()
