#!/usr/bin/env python3
"""Rewrite the production image repository and tag lines.

The production environment job runs this after approval and commits the
result. Only the api and web blocks are changed. Other keys stay as they are.
"""

import argparse
from pathlib import Path


class ImageUpdateError(Exception):
    pass


def update_images(text, api_repository, web_repository, tag):
    if not tag or not api_repository or not web_repository:
        raise ImageUpdateError("repository and tag are required")
    if any(char.isspace() for char in tag):
        raise ImageUpdateError("tag must be a single token")

    lines = text.splitlines(keepends=True)
    section = None
    found = {"api.repository": False, "api.tag": False, "web.repository": False, "web.tag": False}

    for index, line in enumerate(lines):
        stripped = line.strip()
        indent = line[: len(line) - len(line.lstrip(" "))]
        if indent == "" and stripped.endswith(":") and not stripped.startswith("#"):
            section = stripped[:-1]
            continue

        if section not in ("api", "web") or not indent:
            continue

        key = "repository" if stripped.startswith("repository:") else "tag" if stripped.startswith("tag:") else ""
        if not key:
            continue

        value = api_repository if section == "api" and key == "repository" else None
        if section == "web" and key == "repository":
            value = web_repository
        if key == "tag":
            value = tag
        newline = "\n" if line.endswith("\n") else ""
        lines[index] = f"{indent}{key}: {value}{newline}"
        found[f"{section}.{key}"] = True

    missing = [name for name, seen in found.items() if not seen]
    if missing:
        raise ImageUpdateError("missing production image keys: " + ", ".join(missing))

    return "".join(lines)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--file", required=True, type=Path)
    parser.add_argument("--api-repository", required=True)
    parser.add_argument("--web-repository", required=True)
    parser.add_argument("--tag", required=True)
    args = parser.parse_args()
    original = args.file.read_text(encoding="utf-8")
    updated = update_images(original, args.api_repository, args.web_repository, args.tag)
    if updated != original:
        args.file.write_text(updated, encoding="utf-8")


if __name__ == "__main__":
    main()
