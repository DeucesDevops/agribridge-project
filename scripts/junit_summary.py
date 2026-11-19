#!/usr/bin/env python3
"""Write a Markdown summary of JUnit XML files for the GitHub Actions job summary."""

import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def junit_files(paths):
    found = []
    for raw in paths:
        path = Path(raw)
        if path.is_dir():
            found.extend(sorted(path.glob("junit*.xml")))
        elif path.is_file():
            found.append(path)
    unique = []
    seen = set()
    for path in found:
        key = path.resolve()
        if key not in seen:
            seen.add(key)
            unique.append(path)
    return unique


def load_suite(path):
    root = ET.parse(path).getroot()
    suites = root.findall("testsuite") if root.tag == "testsuites" else [root]
    cases = []
    for suite in suites:
        for case in suite.findall("testcase"):
            failure = case.find("failure")
            error = case.find("error")
            skipped = case.find("skipped")
            cases.append({
                "name": case.get("name") or "unnamed",
                "classname": case.get("classname") or suite.get("name") or path.stem,
                "failure": failure.get("message") if failure is not None else None,
                "error": error.get("message") if error is not None else None,
                "skipped": skipped is not None,
            })
    return cases


def render(paths):
    files = junit_files(paths)
    lines = ["## Test results", ""]
    if not files:
        lines.append("No JUnit files were produced.")
        return "\n".join(lines) + "\n"

    rows = []
    failures = []
    for path in files:
        cases = load_suite(path)
        failed = [case for case in cases if case["failure"] or case["error"]]
        skipped = sum(1 for case in cases if case["skipped"])
        rows.append((str(path), len(cases), len(failed), skipped))
        for case in failed:
            detail = case["failure"] or case["error"]
            failures.append(f"- `{case['classname']} {case['name']}` — {detail}")

    lines.append("| Report | Tests | Failed | Skipped |")
    lines.append("| --- | ---: | ---: | ---: |")
    for name, tests, failed, skipped in rows:
        lines.append(f"| `{name}` | {tests} | {failed} | {skipped} |")
    lines.append("")
    if failures:
        lines.append("### Failures")
        lines.append("")
        lines.extend(failures)
    else:
        lines.append("All published tests passed.")
    lines.append("")
    return "\n".join(lines)


def main(argv):
    sys.stdout.write(render(argv[1:] or ["."]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
