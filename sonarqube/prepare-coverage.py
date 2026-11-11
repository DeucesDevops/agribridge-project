#!/usr/bin/env python3
"""Make component-relative LCOV paths resolve from the scanner's project root."""
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def normalize_report(report, component, root=ROOT):
    component_root = (root / component).resolve()
    normalized = []
    sources = 0
    for line in report.splitlines():
        if line.startswith("SF:"):
            source = Path(line[3:])
            if not source.is_absolute():
                source = root / source if source.parts[:1] == (component,) else component_root / source
            source = source.resolve()
            if component_root not in source.parents or not source.is_file():
                raise ValueError(f"Unresolvable {component} LCOV source: {line[3:]}")
            line = "SF:" + source.relative_to(root).as_posix()
            sources += 1
        normalized.append(line)
    if not sources:
        raise ValueError(f"{component} LCOV report has no source records")
    return "\n".join(normalized) + "\n"


def main(root=ROOT):
    reports = []
    for component in ("api", "frontend"):
        path = root / component / "coverage/lcov.info"
        if not path.is_file():
            raise ValueError(f"Missing {path.relative_to(root)}; run both test:coverage scripts first")
        reports.append(normalize_report(path.read_text(), component, root))
    output = root / ".runtime/sonarqube/lcov.info"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("".join(reports))
    print(f"Prepared {output.relative_to(root)} with validated API and frontend source paths.")


if __name__ == "__main__":
    try:
        main()
    except (OSError, ValueError) as error:
        raise SystemExit(str(error))
