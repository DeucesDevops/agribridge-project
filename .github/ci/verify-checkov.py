"""Reject empty scans and parser failures as well as failed policy checks."""
import json
from pathlib import Path
import sys


def validate(report):
    reports = report if isinstance(report, list) else [report]
    if not reports or not sum(item.get("summary", {}).get("passed", 0)
                              + item.get("summary", {}).get("failed", 0) for item in reports):
        raise ValueError("Checkov evaluated no policies; check the scan path and framework")
    for item in reports:
        summary = item.get("summary", {})
        results = item.get("results", {})
        if summary.get("failed", 0) or summary.get("parsing_errors", 0) or results.get("parsing_errors"):
            raise ValueError("Checkov reported failed policies or parsing errors")


if __name__ == "__main__":
    validate(json.loads(Path(sys.argv[1]).read_text()))
    print("Checkov evaluated policies without failures or parser errors.")
